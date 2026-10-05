--!strict
-- Spawner independiente del GameManager. Decide qué aparece, cuándo y dónde, pero
-- no sabe nada de comportamiento ni de daño: solo llama a EnemyRegistry.spawn.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local PlayerAvatar = require(script.Parent.Parent.PlayerAvatar)
local Difficulty = require(script.Parent.Difficulty)
local EnemyRegistry = require(script.Parent.Parent.Enemies.EnemyRegistry)

-- Lista de contenido: añadir un enemigo nuevo es añadir una línea aquí.
local GROUPS: { { enemyId: string, firstAt: number, weight: number } } = {
	{ enemyId = "basic", firstAt = 0, weight = 1 },
}

local nextSpawnAt = 0

local EnemySpawner = {}

function EnemySpawner.reset(now: number)
	nextSpawnAt = now + Config.Run.EnemySpawnGrace
end

local function pickEnemyId(elapsed: number): string?
	local candidates = {}
	local total = 0
	for _, group in GROUPS do
		if elapsed >= group.firstAt then
			table.insert(candidates, group)
			total += group.weight
		end
	end
	if #candidates == 0 then
		return nil
	end

	local target = math.random() * total
	local accumulated = 0
	for _, group in candidates do
		accumulated += group.weight
		if target <= accumulated then
			return group.enemyId
		end
	end
	return candidates[#candidates].enemyId
end

local function randomSpawnPoint(): Vector3?
	local players = PlayerAvatar.alivePlayers()
	if #players == 0 then
		return nil
	end
	local anchor = PlayerAvatar.root(players[math.random(1, #players)])
	if not anchor then
		return nil
	end

	-- Nace en un anillo alrededor de un jugador, nunca encima: así el jugador
	-- siempre tiene salida y el spawner no depende de un punto fijo del mapa.
	local angle = math.random() * math.pi * 2
	local distance = Config.Arena.SpawnRadiusMin
		+ math.random() * (Config.Arena.SpawnRadiusMax - Config.Arena.SpawnRadiusMin)
	return anchor.Position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
end

function EnemySpawner.update(now: number, elapsed: number)
	if now < nextSpawnAt then
		return
	end

	local profile = Difficulty.evaluate(elapsed)
	nextSpawnAt = now + profile.spawnInterval

	for _ = 1, profile.batchSize do
		if EnemyRegistry.count() >= profile.maxAlive then
			return
		end
		local enemyId = pickEnemyId(elapsed)
		local position = randomSpawnPoint()
		if enemyId and position then
			EnemyRegistry.spawn(enemyId, position, profile)
		end
	end
end

return EnemySpawner
