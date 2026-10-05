--!strict
-- Cuchillas orbitando al jugador. Es el unico arma que no dispara por cadencia: son
-- piezas persistentes que giran alrededor del personaje y cortan por contacto.
--
-- El ritmo de corte lo lleva un enfriamiento POR ENEMIGO guardado en el propio
-- enemigo, no en un mapa aparte: asi no hay nada que limpiar y el recorte es gratis
-- cuando la horda se vacia.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Pool = require(script.Parent.Parent.Utility.Pool)
local EnemyRegistry = require(script.Parent.Parent.Enemies.EnemyRegistry)
local PlayerAvatar = require(script.Parent.Parent.PlayerAvatar)

type Blade = {
	Part: Part,
	Lease: any,
}

type Orbit = {
	Blades: { Blade },
	Damage: number,
	IsCrit: boolean,
	Radius: number,
	Speed: number,
	Cooldown: number,
	Angle: number,
}

-- Margen que se anade al radio de contacto al pedir celdas a la rejilla, para
-- incluir el cuerpo completo de un enemigo grande sin conocer su tamano antes.
local QUERY_PAD = 8

local sets: { [Player]: Orbit } = {}
local container: Folder = nil
local pool: Pool.Pooled = nil

local function buildTemplate(): Part
	local part = Instance.new("Part")
	part.Name = "Blade"
	part.Size = Config.Orbit.BladeSize
	part.Color = Config.Orbit.BladeColor
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	return part
end

local OrbitBlades = {}

function OrbitBlades.init()
	if container then
		return
	end
	container = Instance.new("Folder")
	container.Name = "OrbitBlades"
	container.Parent = workspace
	pool = Pool.new(buildTemplate(), Config.Orbit.MaxBlades * 4)
end

function OrbitBlades.reset(player: Player)
	local orbit = sets[player]
	if not orbit or not pool then
		return
	end
	for _, blade in orbit.Blades do
		pool:Release(blade.Part, blade.Lease)
	end
	sets[player] = nil
end

function OrbitBlades.clearAll()
	local players = table.create(0)
	for player in sets do
		table.insert(players, player)
	end
	for _, player in players do
		OrbitBlades.reset(player)
	end
end

-- Reconcilia el juego de cuchillas de un jugador con sus estadisticas actuales. Lo
-- llama el comportamiento del arma a su propia cadencia, asi que subir de nivel o
-- comprar una mejora se refleja en el siguiente disparo sin tocar nada mas.
function OrbitBlades.configure(player: Player, stats: { [string]: number }, damage: number, isCrit: boolean)
	if not pool then
		return
	end

	local wanted = math.clamp(math.round(stats.BladeCount or 0), 0, Config.Orbit.MaxBlades)
	if wanted <= 0 then
		OrbitBlades.reset(player)
		return
	end

	local orbit = sets[player]
	if not orbit then
		orbit = {
			Blades = {},
			Damage = damage,
			IsCrit = isCrit,
			Radius = 6,
			Speed = 2.5,
			Cooldown = 0.45,
			Angle = 0,
		}
		sets[player] = orbit
	end

	orbit.Damage = damage
	orbit.IsCrit = isCrit
	orbit.Radius = math.max(2, stats.OrbitRadius or 6)
	orbit.Speed = math.max(0.2, stats.OrbitSpeed or 2.5)
	orbit.Cooldown = math.max(Config.Orbit.HitCooldownFloor, stats.HitCooldown or 0.45)

	while #orbit.Blades > wanted do
		local blade = table.remove(orbit.Blades)
		pool:Release(blade.Part, blade.Lease)
	end
	while #orbit.Blades < wanted do
		local acquired, lease = pool:Get(function(instance)
			local part = instance :: Part
			part.Size = Config.Orbit.BladeSize
			part.Color = Config.Orbit.BladeColor
			part.Parent = container
		end)
		table.insert(orbit.Blades, { Part = acquired :: Part, Lease = lease })
	end
end

local function cut(position: Vector3, orbit: Orbit, now: number)
	local contact = Config.Orbit.ContactRadius
	for _, enemy in EnemyRegistry.queryRadius(position, contact + QUERY_PAD) do
		if enemy.HitLockUntil <= now then
			local dx = enemy.Position.X - position.X
			local dz = enemy.Position.Z - position.Z
			local reach = enemy.Definition.Size * 0.5 + contact
			local distance = dx * dx + dz * dz
			if distance <= reach * reach then
				enemy.HitLockUntil = now + orbit.Cooldown
				EnemyRegistry.damage(enemy, orbit.Damage, orbit.IsCrit)
			end
		end
	end
end

function OrbitBlades.update(dt: number, now: number)
	for player, orbit in sets do
		local root = PlayerAvatar.root(player)
		-- Sin personaje no hay centro orbital: se recoge el juego entero en vez de
		-- dejar las cuchillas colgadas en el aire.
		if not root or not player.Parent then
			OrbitBlades.reset(player)
			continue
		end

		orbit.Angle += orbit.Speed * dt
		local count = #orbit.Blades
		if count == 0 then
			continue
		end

		-- A la altura del cuerpo de los enemigos, no a la del jugador: asi el barrido
		-- se ve pasar por la horda en vez de flotar por encima de ella.
		local center = Vector3.new(root.Position.X, Config.Arena.FloorY + 1.2, root.Position.Z)
		local spacing = math.pi * 2 / count

		for index, blade in orbit.Blades do
			local angle = orbit.Angle + spacing * index
			local cos, sin = math.cos(angle), math.sin(angle)
			local position = center + Vector3.new(cos, 0, sin) * orbit.Radius
			-- Orientada tangente al giro, que es como se lee una cuchilla girando.
			blade.Part.CFrame = CFrame.lookAt(position, position + Vector3.new(-sin, 0, cos))
			cut(position, orbit, now)
		end
	end
end

return OrbitBlades
