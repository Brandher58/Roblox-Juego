--!strict
-- Un único lugar para números de balance. Ningún sistema debe inventar su propia
-- constante de dificultad, cooldown o tamaño: se leen de aquí.
local Config = {}

local function deepFreeze<T>(value: T): T
	if type(value) ~= "table" then
		return value
	end
	for _, child in value :: any do
		deepFreeze(child)
	end
	return table.freeze(value)
end

--Geometría de la arena del vertical slice.
Config.Arena = {
	HalfExtent = 110,
	FloorY = 0.5,
	SpawnRadiusMin = 34,
	SpawnRadiusMax = 52,
}

--Estadísticas base de cualquier jugador al empezar una partida. Damage y
--AttackSpeed valen 1 a propósito: son multiplicadores globales que escalan cada arma.
Config.PlayerBaseStats = {
	MaxHealth = 100,
	Armor = 0,
	MoveSpeed = 16,
	Damage = 1,
	AttackSpeed = 1,
	CriticalChance = 0.05,
	CriticalDamage = 1.5,
	Range = 1,
	ProjectileSpeed = 1,
	ProjectileCount = 0,
	PickupRadius = 9,
	XPModifier = 1,
	Luck = 1,
}

--Ritmo de la partida y pausas automáticas.
Config.Run = {
	LevelUpTimeout = 15,
	DefeatDuration = 6,
	EnemySpawnGrace = 1,
	-- Objetivo de la Fase 1: sobrevivir este tiempo da la victoria. En la Fase 2 este
	-- mismo reloj pasa a ser el disparador del jefe, así que el final de partida ya
	-- está probado antes de que exista el jefe.
	TargetDuration = 360,
}

--Gotas de experiencia en el suelo. El tope no es un recorte de experiencia: cuando
--se supera, la gota nueva se funde con la más cercana, así que la recompensa se
--mantiene entera y además se ve más grande.
Config.Pickups = {
	MaxActive = 220,
	MergeRadius = 14,
}

--Progresión vertical del spawner. La dificultad es una función del tiempo jugado.
Config.Spawn = {
	BaseInterval = 1.5,
	IntervalDecayPerMinute = 0.45,
	MinInterval = 0.35,
	BaseBatch = 1,
	BatchPerMinute = 0.6,
	BaseMaxAlive = 24,
	MaxAlivePerMinute = 8,
}

--Escalado por minuto de los enemigos.
Config.Scaling = {
	HealthPerMinute = 0.55,
	SpeedPerMinute = 0.035,
	MaxSpeedMultiplier = 1.45,
}

--Proyectiles del vertical slice.
Config.Projectile = {
	Radius = 0.6,
	SpeedFloor = 25,
	MaxLifetime = 2.5,
	-- Gravedad de los proyectiles que describen un arco (bombas). Los proyectiles
	-- rectos la tienen a cero y no cambian de dirección.
	Gravity = 46,
	-- Un proyectil explosivo es más grande para que se vea venir.
	BombRadius = 1.1,
}

--Cuchillas orbitando al jugador. Son piezas persistentes, no disparos: giran y
--muelen por contacto con su propio ritmo, independiente del ataque por cadencia.
Config.Orbit = {
	MaxBlades = 12,
	BladeSize = Vector3.new(0.5, 0.5, 2),
	BladeColor = Color3.fromRGB(178, 216, 255),
	-- Radio de contacto de cada cuchilla al buscar enemigos en la rejilla.
	ContactRadius = 1.4,
	-- Segundos que un enemigo queda protegido tras recibir un corte. Sin esto una
	-- cuchilla dañaría cada frame.
	HitCooldownFloor = 0.2,
}

--Cámara top-down isométrica ligera.
Config.Camera = {
	Offset = Vector3.new(0, 34, 20),
	FieldOfView = 62,
	Smoothing = 9,
}

--Presentación por enemigo (fuera de EnemyDefinition para que las definiciones
--no dependan de la API de Roblox y sigan siendo testeables headless).
Config.EnemyVisuals = {
	basic = {
		Color = Color3.fromRGB(214, 79, 79),
		OffsetY = 1.6,
		-- Asset de Creator Store que sustituye a la esfera roja por el modelo del NPC.
		-- El id 4446576906 devuelve permiso denegado en runtime; de momento se
		-- devuelve a la esfera. Descomentar cuando se suba el modelo a tu cuenta.
		-- AssetId = 4446576906,
	},
}

Config.UI = {
	Accent = Color3.fromRGB(255, 214, 92),
	CardWidth = 250,
	CardHeight = 320,
	CardGap = 18,
}

deepFreeze(Config)
return Config
