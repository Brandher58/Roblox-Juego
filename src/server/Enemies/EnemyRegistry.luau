--!strict
-- Dueño de los enemigos: instanciación pooled, vida, muerte y recompensa.
-- No decide comportamiento (eso es EnemyAI) ni dificultad (eso es Difficulty).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Registry = require(Shared:WaitForChild("Registry"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local Pool = require(script.Parent.Parent.Utility.Pool)
local Grid = require(script.Parent.SpatialGrid)
local XPPickups = require(script.Parent.Parent.Pickups.XPPickups)
local InsertService = game:GetService("InsertService")

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
}

local container: Folder = nil
local pool: Pool.Pooled = nil
local assetPools: { [number]: Pool.Pooled } = {}
local grid: Grid.Grid = nil
local enemies: { Enemy } = {}
local nextId = 0

local function buildTemplate(): Model
	local model = Instance.new("Model")
	model.Name = "Enemy"

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

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Parent = model

	model.PrimaryPart = root
	return model
end

-- Prepara un modelo del Store como template del pool: anclado, sin colisiones y
-- con un PrimaryPart uniforme. Si no se puede cargar, devuelve la esfera de reserva.
local function buildAssetTemplate(assetId: number): Model
	local ok, asset = pcall(function()
		return InsertService:LoadAsset(assetId)
	end)
	if not ok or not asset then
		warn(`[EnemyRegistry] no se pudo cargar el asset {assetId}: {asset}`)
		return buildTemplate()
	end

	local source = asset:FindFirstChildWhichIsA("Model") or asset
	local model = source:Clone()
	model.Name = "Enemy"
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			child.Anchored = true
			child.CanCollide = false
			child.CanQuery = false
			child.CanTouch = false
			child.CastShadow = false
			child.Massless = true
		elseif child:IsA("Script") or child:IsA("LocalScript") then
			child:Destroy()
		end
	end

	local root = model:FindFirstChild("Root") or model:FindFirstChild("HumanoidRootPart")
	if not root then
		root = Instance.new("Part")
		root.Size = Vector3.new(2, 2, 2)
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = false
		root.CanTouch = false
		root.Massless = true
	end
	root.Name = "Root"
	(root :: Instance).Parent = model
	model.PrimaryPart = root :: BasePart
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
local function poolFor(definitionId: string): Pool.Pooled
	local visuals = Config.EnemyVisuals[definitionId]
	if not visuals or not visuals.AssetId then
		return pool
	end
	local cached = assetPools[visuals.AssetId]
	if cached then
		return cached
	end
	cached = Pool.new(buildAssetTemplate(visuals.AssetId), 12)
	assetPools[visuals.AssetId] = cached
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
	local useAsset = visuals.AssetId ~= nil
	local assetPool = poolFor(definitionId)

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
		Damage = definition.Damage,
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
		local assetPool = assetPools[Config.EnemyVisuals[enemy.Definition.Id].AssetId]
		if assetPool then
			assetPool:Release(enemy.Model, enemy.Lease)
		else
			pool:Release(enemy.Model, enemy.Lease)
		end
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
			local assetPool = assetPools[Config.EnemyVisuals[enemy.Definition.Id].AssetId]
			if assetPool then
				assetPool:Release(enemy.Model, enemy.Lease)
			else
				pool:Release(enemy.Model, enemy.Lease)
			end
		else
			pool:Release(enemy.Model, enemy.Lease)
		end
		table.remove(enemies, index)
	end
end

return EnemyRegistry
