--!strict
-- Dueño del jefe vivo. Es independiente de las misiones: una misión solo pide
-- `spawn(bossId)` y BossSystem decide dónde nace y cuándo ha caído. No tiene ninguna
-- rama por jefe concreto: cualquier definición etiquetada "boss" sirve.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Registry = require(Shared:WaitForChild("Registry"))
local PlayerAvatar = require(script.Parent.Parent.PlayerAvatar)
local EnemyRegistry = require(script.Parent.Parent.Enemies.EnemyRegistry)

export type Scaling = { health: number, speed: number, damage: number }
export type DefeatListener = (bossId: string) -> ()

local active: EnemyRegistry.Enemy? = nil
local activeId: string? = nil
local defeatListeners: { DefeatListener } = {}
local listenConnection: (() -> ())? = nil

local BossSystem = {}

local function ensureKillListener()
	if listenConnection then
		return
	end
	-- El jefe se identifica por referencia: es el enemigo exacto que devolvió spawn.
	-- Así dos jefes del mismo tipo en el futuro no se confunden.
	listenConnection = EnemyRegistry.onKilled(function(enemy)
		if not active or enemy ~= active then
			return
		end
		local bossId = activeId or enemy.Definition.Id
		active = nil
		activeId = nil
		for _, listener in defeatListeners do
			listener(bossId)
		end
	end)
end

local function randomSpawnPoint(): Vector3
	local players = PlayerAvatar.alivePlayers()
	if #players > 0 then
		local anchor = PlayerAvatar.root(players[math.random(1, #players)])
		if anchor then
			local angle = math.random() * math.pi * 2
			local distance = (Config.Arena.SpawnRadiusMin + Config.Arena.SpawnRadiusMax) * 0.5
			return anchor.Position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		end
	end
	return Vector3.zero
end

function BossSystem.spawn(bossId: string, scaling: Scaling): EnemyRegistry.Enemy?
	if active then
		return active
	end
	local definition = Registry.Enemies[bossId]
	if not definition or not table.find(definition.Tags, "boss") then
		warn(`[BossSystem] {bossId} no es un jefe válido`)
		return nil
	end
	ensureKillListener()

	local enemy = EnemyRegistry.spawn(bossId, randomSpawnPoint(), scaling)
	if not enemy then
		return nil
	end
	active = enemy
	activeId = bossId
	return enemy
end

function BossSystem.isActive(): boolean
	return active ~= nil
end

function BossSystem.getActive(): EnemyRegistry.Enemy?
	return active
end

function BossSystem.getActiveId(): string?
	return activeId
end

function BossSystem.onDefeated(listener: DefeatListener): () -> ()
	table.insert(defeatListeners, listener)
	return function()
		local index = table.find(defeatListeners, listener)
		if index then
			table.remove(defeatListeners, index)
		end
	end
end

function BossSystem.reset()
	active = nil
	activeId = nil
end

return BossSystem
