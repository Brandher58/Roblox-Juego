--!strict
-- Spawner independiente del GameManager. Decide qué aparece, cuándo y dónde, pero
-- no sabe nada de comportamiento ni de daño: solo llama a EnemyRegistry.spawn.
--
-- La configuración de enemigos llega desde la misión (`setConfiguration`) y es el
-- único canal entre contenido y spawn: añadir una misión no toca este archivo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Registry = require(Shared:WaitForChild("Registry"))
local Types = require(Shared:WaitForChild("Types"))
local PlayerAvatar = require(script.Parent.Parent.PlayerAvatar)
local Difficulty = require(script.Parent.Difficulty)
local EnemyRegistry = require(script.Parent.Parent.Enemies.EnemyRegistry)

type Group = { enemyId: string, weight: number }

-- Lista por defecto cuando no hay misión activa (Fase 1): un único enemigo básico.
local DEFAULT_GROUPS: { Group } = {
	{ enemyId = "basic", weight = 1 },
}

local activeGroups: { Group }? = nil
local activeMultipliers: Types.MissionDifficulty? = nil
local nextSpawnAt = 0

local EnemySpawner = {}

function EnemySpawner.reset(now: number)
	nextSpawnAt = now + Config.Run.EnemySpawnGrace
end

-- Traduce la configuración de la misión a la lista ponderada que usa el spawner.
-- Deshabilitar un enemigo o darle peso 0 lo saca del sorteo; `EliteChance` es un
-- multiplicador de peso sobre los enemigos etiquetados "elite".
function EnemySpawner.setConfiguration(
	enemyConfiguration: Types.EnemyConfiguration,
	multipliers: Types.MissionDifficulty
)
	local groups: { Group } = {}
	for enemyId, entry in enemyConfiguration do
		if entry.Enabled and entry.Weight > 0 then
			local definition = Registry.Enemies[enemyId]
			local weight = entry.Weight
			if multipliers.EliteChance and definition and table.find(definition.Tags, "elite") then
				weight *= 1 + multipliers.EliteChance
			end
			table.insert(groups, { enemyId = enemyId, weight = weight })
		end
	end
	table.sort(groups, function(a, b)
		return a.enemyId < b.enemyId
	end)
	activeGroups = groups
	activeMultipliers = multipliers
end

function EnemySpawner.clearConfiguration()
	activeGroups = nil
	activeMultipliers = nil
end

function EnemySpawner.hasConfiguration(): boolean
	return activeGroups ~= nil
end

local function pickEnemyId(groups: { Group }): string?
	local total = 0
	for _, group in groups do
		total += group.weight
	end
	if total <= 0 then
		return nil
	end

	local target = math.random() * total
	local accumulated = 0
	for _, group in groups do
		accumulated += group.weight
		if target <= accumulated then
			return group.enemyId
		end
	end
	return groups[#groups].enemyId
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

	local groups = activeGroups or DEFAULT_GROUPS
	local profile = Difficulty.evaluate(elapsed, activeMultipliers)
	nextSpawnAt = now + profile.spawnInterval

	for _ = 1, profile.batchSize do
		if EnemyRegistry.count() >= profile.maxAlive then
			return
		end
		local enemyId = pickEnemyId(groups)
		local position = randomSpawnPoint()
		if enemyId and position then
			EnemyRegistry.spawn(enemyId, position, profile)
		end
	end
end

return EnemySpawner
