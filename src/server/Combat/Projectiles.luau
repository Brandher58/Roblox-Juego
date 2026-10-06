--!strict
-- Proyectiles pooled y autoritativos. El servidor decide los impactos; el cliente
-- solo ve la posición replicada de la partícula.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local GameAssets = require(Shared:WaitForChild("GameAssets"))
local Pool = require(script.Parent.Parent.Utility.Pool)
local EnemyRegistry = require(script.Parent.Parent.Enemies.EnemyRegistry)

-- Sub-pasos para que un frame lento no haga que el proyectil atraviese al enemigo
-- sin comprobar el impacto.
local MAX_STEP_DISTANCE = 2

local Projectiles = {}

type Projectile = {
	Part: BasePart,
	Position: Vector3,
	Velocity: Vector3,
	Damage: number,
	IsCrit: boolean,
	Owner: Player,
	Life: number,
	-- Radio de explosión. 0 = proyectil simple que se devuelve al pool al impactar.
	BlastRadius: number,
	-- Gravedad vertical. 0 = vuelo recto; > 0 = parábola que acaba detonando.
	Gravity: number,
	Slot: number,
	Lease: any,
}

local projectiles: { Projectile } = {}
local container: Folder = nil
local pool: Pool.Pooled = nil

local function buildTemplate(): Part
	-- Los visuales de proyectil son modulares: si hay un modelo con nombre "Projectile"
	-- en Shared/Assets, ese modelo se usa; si no, un Part neon básico.
	local fromAssets = GameAssets.findPart("Projectile")
	if fromAssets then
		return fromAssets:Clone()
	end

	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(0.7, 0.7, 0.7)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

function Projectiles.init()
	if container then
		return
	end
	container = Instance.new("Folder")
	container.Name = "Projectiles"
	container.Parent = workspace
	pool = Pool.new(buildTemplate(), 96)
end

function Projectiles.count(): number
	return #projectiles
end

-- Camino común de los dos tipos de proyectil. La única diferencia entre una bala y
-- una bomba son los dos ultimos parametros, de modo que el pool, el array y la
-- simulacion viven en un solo sitio.
local function launch(
	origin: Vector3,
	direction: Vector3,
	damage: number,
	speed: number,
	lifetime: number,
	owner: Player,
	isCrit: boolean,
	blastRadius: number,
	gravity: number
)
	if not pool or direction.Magnitude < 0.01 then
		return
	end

	local explosive = blastRadius > 0
	local radius = if explosive then Config.Projectile.BombRadius else Config.Projectile.Radius
	local color = if explosive
		then Color3.fromRGB(255, 164, 68)
		elseif isCrit then Color3.fromRGB(255, 200, 60)
		else Color3.fromRGB(255, 240, 200)

	local acquired, lease = pool:Get(function(instance)
		local part = instance :: Part
		part.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
		part.Color = color
		part.Material = Enum.Material.Neon
		part.Transparency = 0.1
		part.CFrame = CFrame.new(origin)
		part.Parent = container
	end)

	table.insert(projectiles, {
		Part = acquired :: Part,
		Position = origin,
		Velocity = direction.Unit * math.max(speed, Config.Projectile.SpeedFloor),
		Damage = damage,
		IsCrit = isCrit,
		Owner = owner,
		Life = math.min(lifetime, Config.Projectile.MaxLifetime),
		BlastRadius = blastRadius,
		Gravity = gravity,
		Slot = #projectiles + 1,
		Lease = lease,
	})
end

-- Bala simple: un impacto y desaparece.
function Projectiles.spawn(
	origin: Vector3,
	direction: Vector3,
	damage: number,
	speed: number,
	lifetime: number,
	owner: Player,
	isCrit: boolean
)
	launch(origin, direction, damage, speed, lifetime, owner, isCrit, 0, 0)
end

-- Bomba: vuela en parbola y detona al tocar el suelo, al tocar un enemigo o al
-- agotar su tiempo de vuelo.
function Projectiles.spawnBomb(
	origin: Vector3,
	direction: Vector3,
	damage: number,
	speed: number,
	lifetime: number,
	owner: Player,
	isCrit: boolean,
	blastRadius: number
)
	launch(
		origin,
		direction,
		damage,
		speed,
		lifetime,
		owner,
		isCrit,
		math.max(blastRadius, 1),
		Config.Projectile.Gravity
	)
end

local function release(index: number)
	local projectile = projectiles[index]
	local slot = projectile.Slot
	local last = projectiles[#projectiles]
	projectiles[slot] = last
	last.Slot = slot
	table.remove(projectiles)
	pool:Release(projectile.Part, projectile.Lease)
end

local function hitAt(position: Vector3): EnemyRegistry.Enemy?
	local best: EnemyRegistry.Enemy? = nil
	local bestDistance = math.huge
	for _, enemy in EnemyRegistry.queryRadius(position, Config.Projectile.Radius * 2) do
		local dx = enemy.Position.X - position.X
		local dz = enemy.Position.Z - position.Z
		local reach = enemy.Definition.Size * 0.5 + Config.Projectile.Radius
		local distance = dx * dx + dz * dz
		if distance <= reach * reach and distance < bestDistance then
			bestDistance = distance
			best = enemy
		end
	end
	return best
end

-- Detonacion: daña a todo lo que haya dentro del radio. Recorrer la tabla de la
-- rejilla mientras se mata es seguro: damage() saca el enemigo de la lista principal,
-- no de esa copia, y un enemigo ya muerto se ignora por su propio Alive.
local function explode(position: Vector3, damage: number, isCrit: boolean, radius: number)
	for _, enemy in EnemyRegistry.queryRadius(position, radius) do
		local dx = enemy.Position.X - position.X
		local dz = enemy.Position.Z - position.Z
		local reach = enemy.Definition.Size * 0.5 + radius
		local distance = dx * dx + dz * dz
		if distance <= reach * reach then
			EnemyRegistry.damage(enemy, damage, isCrit)
		end
	end
	Remotes.CombatEffect:FireAllClients("explosion", position, radius)
end

-- El final del vuelo: una bomba estalla a ras de suelo, una bala simple solo vuelve
-- al pool.
local function detonate(index: number)
	local projectile = projectiles[index]
	if projectile.BlastRadius > 0 then
		local position = Vector3.new(projectile.Position.X, Config.Arena.FloorY, projectile.Position.Z)
		explode(position, projectile.Damage, projectile.IsCrit, projectile.BlastRadius)
	end
	release(index)
end

local function step(index: number, dt: number)
	local projectile = projectiles[index]

	if projectile.Gravity > 0 then
		projectile.Velocity += Vector3.new(0, -projectile.Gravity * dt, 0)
	end

	local travel = projectile.Velocity * dt
	local distance = travel.Magnitude
	local steps = math.clamp(math.ceil(distance / MAX_STEP_DISTANCE), 1, 8)

	for _ = 1, steps do
		projectile.Position += travel / steps
		if projectile.Position.Y <= Config.Arena.FloorY then
			detonate(index)
			return
		end
		local enemy = hitAt(projectile.Position)
		if enemy then
			-- Una bomba no golpea dos veces al impacto: la detonacion ya incluye al
			-- enemigo que ha tocado, asi que solo se cuenta el radio.
			if projectile.BlastRadius > 0 then
				explode(projectile.Position, projectile.Damage, projectile.IsCrit, projectile.BlastRadius)
			else
				EnemyRegistry.damage(enemy, projectile.Damage, projectile.IsCrit)
			end
			release(index)
			return
		end
	end

	projectile.Life -= dt
	if projectile.Life <= 0 then
		detonate(index)
		return
	end
	projectile.Part.CFrame = CFrame.new(projectile.Position)
end

function Projectiles.update(dt: number)
	for index = #projectiles, 1, -1 do
		step(index, dt)
	end
end

function Projectiles.clearAll()
	for index = #projectiles, 1, -1 do
		release(index)
	end
end

return Projectiles
