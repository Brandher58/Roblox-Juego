--!strict
-- La dificultad es una función pura del tiempo jugado. Todos los números viven en
-- Config: ningún sistema multiplica su propia copia de "cuánto escala".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

export type Profile = {
	health: number,
	speed: number,
	damage: number,
	spawnInterval: number,
	batchSize: number,
	maxAlive: number,
}

local Difficulty = {}

-- Evaluate difficulty with optional mission missionMultipliers The default config is a
-- straight function of elapsed time; a mission can ease that curve or boost
-- particular stats. The returned profile is the single channel between
-- difficulty and spawners.
function Difficulty.evaluate(
	elapsedSeconds: number,
	multipliers: {
		EnemyHealthMultiplier: number?,
		EnemyDamageMultiplier: number?,
		EnemySpawnRateMultiplier: number?,
	}?
): Profile
	local minutes = math.max(0, elapsedSeconds) / 60
	local settings = multipliers or {}
	-- `EnemySpawnRateMultiplier > 1` = más presión: el intervalo BAJA y la tanda y el
	-- tope de vivos SUBEN. No toca la velocidad: una misión no debe volver a los
	-- enemigos más rápidos por el simple hecho de spawnear más.
	local rate = math.max(0.05, settings.EnemySpawnRateMultiplier or 1)
	local baseInterval = Config.Spawn.BaseInterval - minutes * Config.Spawn.IntervalDecayPerMinute
	local baseAlive = Config.Spawn.BaseMaxAlive + minutes * Config.Spawn.MaxAlivePerMinute
	return {
		health = (1 + minutes * Config.Scaling.HealthPerMinute) * (settings.EnemyHealthMultiplier or 1),
		speed = math.min(Config.Scaling.MaxSpeedMultiplier, 1 + minutes * Config.Scaling.SpeedPerMinute),
		damage = (1 + minutes * Config.Scaling.DamagePerMinute) * (settings.EnemyDamageMultiplier or 1),
		spawnInterval = math.max(Config.Spawn.MinInterval, baseInterval / rate),
		batchSize = math.max(
			1,
			math.floor((Config.Spawn.BaseBatch + minutes * Config.Spawn.BatchPerMinute) * rate)
		),
		maxAlive = math.max(Config.Spawn.BaseMaxAlive, math.floor(baseAlive * rate)),
	}
end

return Difficulty
