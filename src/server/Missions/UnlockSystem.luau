--!strict
-- Aplica los desbloqueos de una misión completada. Separado de RewardSystem para que
-- `MissionManager` no acumule la responsabilidad de toda la progresión.
--
-- Devuelve solo lo desbloqueado de verdad (primera vez), para informar al cliente sin
-- repetir avisos en reintentos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Profile = require(script.Parent.Parent.Data.Profile)

export type Applied = {
	Missions: { string },
	Maps: { string },
}

local UnlockSystem = {}

function UnlockSystem.apply(rewards: Types.MissionRewards, players: { Player }?): Applied
	local recipients = players or Players:GetPlayers()
	local missions: { [string]: boolean } = {}
	local maps: { [string]: boolean } = {}

	for _, player in recipients do
		for _, missionId in rewards.MissionUnlocks do
			if Profile.unlockMission(player, missionId) then
				missions[missionId] = true
			end
		end
		for _, mapId in rewards.MapUnlocks do
			if Profile.unlockMap(player, mapId) then
				maps[mapId] = true
			end
		end
	end

	local unlockedMissions: { string } = {}
	for id in missions do
		table.insert(unlockedMissions, id)
	end
	table.sort(unlockedMissions)

	local unlockedMaps: { string } = {}
	for id in maps do
		table.insert(unlockedMaps, id)
	end
	table.sort(unlockedMaps)

	return { Missions = unlockedMissions, Maps = unlockedMaps }
end

return UnlockSystem
