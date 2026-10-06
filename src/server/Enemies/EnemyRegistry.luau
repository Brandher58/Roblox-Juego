--!strict
-- Dueño de los enemigos: instanciación pooled, vida, muerte y recompensa.
-- No decide comportamiento (eso es EnemyAI) ni dificultad (eso es Difficulty).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Registry = require(Shared:WaitForChild("Registry"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local GameAssets = require(Shared:WaitForChild("GameAssets"))
local Pool = require(script.Parent.Parent.Utility.Pool)
local Grid = require(script.Parent.SpatialGrid)
local XPPickups = require(script.Parent.Parent.Pickups.XPPickups)
local ProceduralEnemies = require(script.Parent.ProceduralEnemies)

type EnemyDefinition = Types.EnemyDefinition

export type Enemy = {
	Id: number,
	Slot: number,
	Definition: EnemyDefinition,
	Model: Model,
	Root: BasePart,
	Body: BasePart,
	Health: number,
	MaxHealth: number,
	Speed: number,
	Damage: number,
	AttackInterval: number,
	AttackRange: number,
	Position: Vector3,
	NextAttackAt: number,
	-- Instante en el que este enemigo vuelve a ser vulnerable a contacto. Lo usan las
	-- armas que cortan por contacto (cuchillas orbitando) para no golpear cada frame.
	HitLockUntil: number,
	Alive: boolean,
	-- El visual de este enemigo no es la esfera de reserva, sino un modelo cargado de
	-- Creator Store. IsAsset reemplaza al Body en la colocación física.
	IsAsset: boolean,
	Target: Player?,
	Lease: any,
}

export type Scaling = {
	health: number,
	speed: number,
	damage: number,
}

local container: Folder = nil
local pool: Pool.Pooled = nil
local grid: Grid.Grid = nil
local enemies: { Enemy } = {}
local nextId = 0

local BasicDefinition: Types.EnemyDefinition? = nil
pcall(function()
	BasicDefinition = Registry.Enemies["basic"]
end)

-- Proxy seguro: si el archivo de definición no existe devuelve un definition de basic.
local function DefinitionBasicProxy(): Types.EnemyDefinition
	if BasicDefinition then
		return BasicDefinition
	end
	return {
		Id = "basic",
		Name = "Crawler",
		Health = 34,
		Speed = 10.5,
		Damage = 6,
		AttackInterval = 1,
		AttackRange = 3.4,
		XPReward = 4,
		Size = 2.6,
		AttackType = "Contact",
		Tags = { "melee" },
	}
end

local function buildTemplate(): Model
	-- Plantilla por defecto: se basa en el id del enemigo si está definido, y si no
	-- en una esfera de tamaño medio y rojo oscuro.
	return ProceduralEnemies.make(DefinitionBasicProxy())
end

-- Prepara el modelo que vive en Shared/Assets para este tipo de enemigo. El nombre
-- del asset debe coincidir con el id de la definición: basic → "basic.rbx", tank →
-- "tank.rbx", etc. Si no existe ese nombre, se devuelve nile y se usa la esfera de
-- reserva sin tocar nada.
local function buildAssetTemplate(assetName: string): Model?
	local part = GameAssets.findPart(assetName)
	if not part then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = "Enemy"

	local body = part:Clone()
	body.Name = "Body"
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.Parent = model

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(2, 2, 2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.Massless = true
	root.Parent = model

	model.PrimaryPart = root
	return model
end

local EnemyRegistry = {}

function EnemyRegistry.init()
	if container then
		return
	end
	container = Instance.new("Folder")
	container.Name = "Enemies"
	container.Parent = workspace
	pool = Pool.new(buildTemplate(), 48)
	grid = Grid.new(8)
end

-- Versión de pool para los enemigos que llevan asset: se crea perezoso y sigue
-- existiendo todo lo que dure la sesión.
local poolForByDef: { [string]: Pool.Pooled } = {}

local function poolFor(definitionId: string): Pool.Pooled
	if poolForByDef[definitionId] then
		return poolForByDef[definitionId]
	end
	local template = buildAssetTemplate(definitionId)
	if not template then
		return pool
	end
	local cached = Pool.new(template, 12)
	poolForByDef[definitionId] = cached
	return cached
end

function EnemyRegistry.count(): number
	return #enemies
end

function EnemyRegistry.all(): { Enemy }
	return enemies
end

-- El índice espacial se reconstruye una vez por frame, después de que la IA haya
-- movido a los enemigos.
function EnemyRegistry.rebuildGrid()
	grid:clear()
	for _, enemy in enemies do
		grid:insert(enemy, enemy.Position)
	end
end

function EnemyRegistry.queryRadius(position: Vector3, radius: number): { Enemy }
	return grid:queryRadius(position, radius)
end

-- Enemigo vivo más cercano dentro del rango. Consume el scratch del grid, así que
-- el resultado no debe guardarse.
function EnemyRegistry.closest(position: Vector3, maxDistance: number): Enemy?
	local best: Enemy? = nil
	local bestDistance = maxDistance * maxDistance
	for _, enemy in grid:queryRadius(position, maxDistance) do
		local dx = enemy.Position.X - position.X
		local dz = enemy.Position.Z - position.Z
		local distance = dx * dx + dz * dz
		if distance <= bestDistance then
			bestDistance = distance
			best = enemy
		end
	end
	return best
end

function EnemyRegistry.spawn(definitionId: string, position: Vector3, scaling: Scaling): Enemy?
	local definition = Registry.Enemies[definitionId]
	if not definition or not pool then
		return nil
	end

	local half = Config.Arena.HalfExtent
	local clamped = Vector3.new(
		math.clamp(position.X, -half, half),
		Config.Arena.FloorY,
		math.clamp(position.Z, -half, half)
	)

	local visuals = Config.EnemyVisuals[definitionId] or {}
	local size = definition.Size
	local health = definition.Health * scaling.health
	local assetPool = poolFor(definitionId)
	local useAsset = assetPool ~= pool

	local acquired, lease = assetPool:Get(function(instance)
		local model = instance :: Model
		model.Name = `Enemy_{definitionId}`
		if useAsset then
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") then
					part.Anchored = true
					part.CanCollide = false
					part.CanQuery = false
					part.CanTouch = false
					part.Massless = true
				end
			end
			model:PivotTo(CFrame.new(clamped + Vector3.new(0, visuals.OffsetY or size, 0)))
		else
			local body = model.Body :: BasePart
			body.Size = Vector3.new(size, size, size)
			body.Color = visuals.Color or Color3.fromRGB(200, 200, 200)
			body.CFrame = CFrame.new(clamped + Vector3.new(0, visuals.OffsetY or size * 0.5, 0))
		end
		if not useAsset then
			local root = model.Root :: BasePart
			root.Size = Vector3.new(2, 2, 2)
			root.CFrame = CFrame.new(clamped + Vector3.new(0, 1, 0))
		end
		model.Parent = container
	end)

	local model = acquired :: Model
	local root = model.Root :: BasePart
	local body: BasePart = if useAsset then model.PrimaryPart else model.Body :: BasePart

	nextId += 1
	local enemy: Enemy = {
		Id = nextId,
		Slot = 0,
		Definition = definition,
		Model = model,
		Root = root,
		Body = body,
		Health = health,
		MaxHealth = health,
		Speed = definition.Speed * scaling.speed,
		Damage = definition.Damage * scaling.damage,
		AttackInterval = definition.AttackInterval,
		AttackRange = definition.AttackRange,
		Position = clamped,
		NextAttackAt = 0,
		HitLockUntil = 0,
		Alive = true,
		IsAsset = useAsset,
		Target = nil,
		Lease = lease,
	}

	table.insert(enemies, enemy)
	enemy.Slot = #enemies
	return enemy
end

-- Único punto por el que un enemigo pierde vida. La muerte suelta la recompensa y
-- devuelve el modelo al pool.
function EnemyRegistry.damage(enemy: Enemy, amount: number, isCrit: boolean?): boolean
	if not enemy.Alive or amount <= 0 then
		return false
	end

	enemy.Health -= amount
	local center = enemy.Position + Vector3.new(0, 1, 0)
	Remotes.CombatEffect:FireAllClients("hit", center, if isCrit then 2 else 1)

	-- Flash de daño: cambia el color del cuerpo a blanco y lo restaura en unos
	-- frames. Si no hay fire al recibir hit, no hay confirmación visual de daño.
	local bodyColor = enemy.Body.Color
	enemy.Body.Color = Color3.fromRGB(255, 255, 255)
	task.delay(0.08, function()
		if enemy.Body then
			enemy.Body.Color = bodyColor
		end
	end)

	if enemy.Health > 0 then
		return false
	end

	enemy.Alive = false
	Remotes.CombatEffect:FireAllClients("death", center, 1)

	local slot = enemy.Slot
	local last = enemies[#enemies]
	enemies[slot] = last
	last.Slot = slot
	table.remove(enemies)
	if enemy.IsAsset then
		poolFor(enemy.Definition.Id):Release(enemy.Model, enemy.Lease)
	else
		pool:Release(enemy.Model, enemy.Lease)
	end
	XPPickups.spawn(enemy.Position, enemy.Definition.XPReward)
	return true
end

function EnemyRegistry.clearAll()
	for index = #enemies, 1, -1 do
		local enemy = enemies[index]
		enemy.Alive = false
		if enemy.IsAsset then
			poolFor(enemy.Definition.Id):Release(enemy.Model, enemy.Lease)
		else
			pool:Release(enemy.Model, enemy.Lease)
		end
		table.remove(enemies, index)
	end
end

return EnemyRegistry
