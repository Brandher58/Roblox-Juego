--!strict
-- La dificultad es una función pura del tiempo jugado. Todos los números viven en
-- Config: ningún sistema multiplica su propia copia de "cuánto escala".
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))

export type Profile = {
	health: number,
	speed: number,
	spawnInterval: number,
	batchSize: number,
	maxAlive: number,
}

local Difficulty = {}

function Difficulty.evaluate(elapsedSeconds: number): Profile
	local minutes = math.max(0, elapsedSeconds) / 60
	return {
		health = 1 + minutes * Config.Scaling.HealthPerMinute,
		speed = math.min(Config.Scaling.MaxSpeedMultiplier, 1 + minutes * Config.Scaling.SpeedPerMinute),
		spawnInterval = math.max(
			Config.Spawn.MinInterval,
			Config.Spawn.BaseInterval - minutes * Config.Spawn.IntervalDecayPerMinute
		),
		batchSize = math.max(1, math.floor(Config.Spawn.BaseBatch + minutes * Config.Spawn.BatchPerMinute)),
		maxAlive = math.max(
			Config.Spawn.BaseMaxAlive,
			math.floor(Config.Spawn.BaseMaxAlive + minutes * Config.Spawn.MaxAlivePerMinute)
		),
	}
end

return Difficulty
