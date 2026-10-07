--!strict
-- Registro de comportamientos de ataque. WeaponRuntime decide cuándo dispara; aquí
-- vive únicamente cómo se ejecuta cada ataque. Añadir un arma con un patrón nuevo
-- es añadir una entrada en este mapa, sin tocar el bucle de armas ni el pool.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(script.Parent.Parent.Stats)
local EnemyRegistry = require(script.Parent.Parent.Enemies.EnemyRegistry)
local Projectiles = require(script.Parent.Projectiles)
local OrbitBlades = require(script.Parent.OrbitBlades)

type StatBlock = { [string]: number }

export type Context = {
	player: Player,
	weaponId: string,
	stats: StatBlock,
	origin: Vector3,
	target: Vector3?,
	lookDirection: Vector3,
	now: number,
}

local function rotateY(direction: Vector3, radians: number): Vector3
	local cos, sin = math.cos(radians), math.sin(radians)
	return Vector3.new(
		direction.X * cos - direction.Z * sin,
		direction.Y,
		direction.X * sin + direction.Z * cos
	)
end

local function rollCrit(player: Player, stats: StatBlock, now: number): (number, boolean)
	local playerStats = Stats.get(player, now)
	local chance = playerStats.CriticalChance or 0
	if math.random() >= chance then
		return stats.Damage, false
	end
	return stats.Damage * (playerStats.CriticalDamage or 1.5), true
end

-- Daño a todo lo que quede dentro de un radio, en el suelo. La comparte el pulso y
-- cualquier otra fuente de área.
local function damageArea(
	position: Vector3,
	radius: number,
	damage: number,
	isCrit: boolean,
	effect: string
): number
	local hits = 0
	for _, enemy in EnemyRegistry.queryRadius(position, radius) do
		local dx = enemy.Position.X - position.X
		local dz = enemy.Position.Z - position.Z
		local reach = enemy.Definition.Size * 0.5 + radius
		local distance = dx * dx + dz * dz
		if distance <= reach * reach then
			EnemyRegistry.damage(enemy, damage, isCrit)
			hits += 1
		end
	end
	Remotes.CombatEffect:FireAllClients(effect, position, radius)
	return hits
end

-- Enemigo vivo más cercano alrededor de un punto, saltando los que ya han sido
-- tocados. Cierra la tabla de la rejilla antes de devolver, porque el llamante
-- vuelve a consultarla en el siguiente salto.
local function nearestUntouched(
	position: Vector3,
	radius: number,
	alreadyHit: { [number]: boolean }
): EnemyRegistry.Enemy?
	local best: EnemyRegistry.Enemy? = nil
	local bestDistance = radius * radius
	for _, enemy in EnemyRegistry.queryRadius(position, radius) do
		if not alreadyHit[enemy.Id] then
			local dx = enemy.Position.X - position.X
			local dz = enemy.Position.Z - position.Z
			local distance = dx * dx + dz * dz
			if distance <= bestDistance then
				bestDistance = distance
				best = enemy
			end
		end
	end
	return best
end

-- Dispara uno o varios proyectiles hacia el objetivo. Con más de una bala se
-- reparten en el cono; con una sola, van directa.
local function fireProjectiles(context: Context)
	if not context.target then
		return
	end

	local aim = (context.target - context.origin)
	if aim.Magnitude < 0.01 then
		return
	end
	aim = aim.Unit

	local muzzle = context.origin + Vector3.new(0, 1.4, 0)
	local pellets = math.max(1, math.round(context.stats.Pellets or 1))
	local spread = math.rad(context.stats.Spread or 0)
	local speed = math.max(Config.Projectile.SpeedFloor, context.stats.ProjectileSpeed or 60)
	local range = math.max(4, context.stats.Range or 40)
	local lifetime = range / speed + 0.15

	for index = 0, pellets - 1 do
		local offset = 0
		if pellets > 1 and spread > 0 then
			offset = (index / (pellets - 1) - 0.5) * spread + (math.random() - 0.5) * spread * 0.25
		end
		local direction = rotateY(aim, offset)
		local damage, isCrit = rollCrit(context.player, context.stats, context.now)
		Projectiles.spawn(muzzle, direction, damage, speed, lifetime, context.player, isCrit)
	end
end

-- Onda de daño a tu alrededor. El objetivo solo sirve para decidir si el pulso se
-- dispara: el área es el radio, y se calcula en el suelo.
local function fireNova(context: Context)
	local damage, isCrit = rollCrit(context.player, context.stats, context.now)
	local radius = math.max(2, context.stats.Radius or 8)
	local center = Vector3.new(context.origin.X, Config.Arena.FloorY, context.origin.Z)
	damageArea(center, radius, damage, isCrit, "nova")
end

-- Impacta al más cercano y salta a los siguientes, cada vez con menos daño. El
-- salto se dibuja como un segmento entre el impacto anterior y el nuevo.
local function fireChain(context: Context)
	if not context.target then
		return
	end

	local damage, isCrit = rollCrit(context.player, context.stats, context.now)
	local jumps = math.max(1, math.round(context.stats.ChainCount or 2))
	local jumpRange = math.max(4, context.stats.ChainRange or 18)
	local falloff = math.clamp(context.stats.ChainFalloff or 0.85, 0.1, 1)

	-- El primer salto nace en el arma del jugador con su propio offset Y, no en el
	-- punto apuntado: así el rayo de apertura siempre tiene longitud, y por tanto
	-- siempre se dibuja, aunque el primer objetivo esté justo delante.
	local hitY = Config.Arena.FloorY + 1
	local source = Vector3.new(context.origin.X, hitY, context.origin.Z)

	local alreadyHit: { [number]: boolean } = {}
	local current: EnemyRegistry.Enemy? =
		nearestUntouched(Vector3.new(context.target.X, hitY, context.target.Z), 1, alreadyHit)
	local from = source

	for _ = 1, jumps do
		if not current then
			break
		end
		EnemyRegistry.damage(current, damage, isCrit)
		alreadyHit[current.Id] = true

		local position = Vector3.new(current.Position.X, hitY, current.Position.Z)
		Remotes.CombatEffect:FireAllClients("chain", from, jumpRange, position)

		from = position
		current = nearestUntouched(position, jumpRange, alreadyHit)
		damage *= falloff
	end
end

-- Lanza bombas con un arco real: sube y cae. La detonación y el daño en área los
-- lleva el propio proyectil, no esta función: aquí solo se construye la velocidad
-- de lanzamiento desde el lob deseado.
local function fireBomb(context: Context)
	if not context.target then
		return
	end

	local muzzle = context.origin + Vector3.new(0, 1.4, 0)
	local flat = Vector3.new(context.target.X - muzzle.X, 0, context.target.Z - muzzle.Z)
	local flatDistance = flat.Magnitude
	if flatDistance < 0.2 then
		return
	end
	flat = flat / flatDistance

	local blast = math.max(1, context.stats.BlastRadius or 8)
	local arc = math.clamp(context.stats.Arc or 0.45, 0, 1.5)
	local speed = math.max(Config.Projectile.SpeedFloor, context.stats.ProjectileSpeed or 44)
	local count = math.max(1, math.round(context.stats.ProjectileCount or 1))

	-- La altura pico crece con la distancia al objetivo y con la stat Arc, y la
	-- velocidad vertical sale de la conservación (v² = 2·g·h): la altura es exacta
	-- y no depende del frame ni del giro del mundo.
	local gravity = Config.Projectile.Gravity
	local rise = math.clamp(
		flatDistance * 0.28 + arc * 6,
		Config.Projectile.LobHeightMin,
		Config.Projectile.LobHeightMax
	)
	local verticalSpeed = math.sqrt(2 * gravity * rise)
	local flightTime = 2 * verticalSpeed / gravity
	-- Velocidad horizontal suficiente para alcanzar al objetivo antes de caer.
	local horizontalSpeed = math.max(speed, flatDistance / math.max(flightTime, 0.01) + 1)
	local lifetime = flightTime + 0.5

	for _ = 1, count do
		-- La dispersión solo rota la orientación horizontal: todas las bombas de la
		-- andanada comparten altura y así el arco se sigue leyendo como una sola
		-- parábola.
		local scatter = (math.random() - 0.5) * math.rad(9)
		local scattered = rotateY(flat, scatter)
		local velocity = scattered * horizontalSpeed + Vector3.new(0, verticalSpeed, 0)
		local damage, isCrit = rollCrit(context.player, context.stats, context.now)
		Projectiles.spawnBomb(muzzle, velocity, damage, lifetime, context.player, isCrit, blast)
	end
end

-- Las cuchillas no son un disparo: el comportamiento solo deja el juego de piezas
-- sincronizado con las estadísticas actuales, y el movimiento y el corte por contacto
-- los lleva OrbitBlades en su propio paso del bucle.
local function sustainOrbit(context: Context)
	local damage, isCrit = rollCrit(context.player, context.stats, context.now)
	OrbitBlades.configure(context.player, context.stats, damage, isCrit)
end

return {
	Projectile = fireProjectiles,
	Nova = fireNova,
	Chain = fireChain,
	Bomb = fireBomb,
	Orbit = sustainOrbit,
}
