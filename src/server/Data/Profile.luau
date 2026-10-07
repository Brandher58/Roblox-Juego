--!strict
-- Progresión permanente del jugador. Hoy es memoria de sesión: existe para que la
-- frontera Run/Meta y la autoridad del servidor queden marcadas desde el principio.
--
-- Persistencia (DataStore) pendiente. Cuando se active:
--   - UpdateAsync con bloqueo de sesión (nunca GetAsync + SetAsync).
--   - Guardar en PlayerRemoving y BindToClose, no solo al salir.
--   - Reconciliar contra los defaults y validar números antes de escribir.
--
-- Nada de aquí concede nada al cliente: `RewardSystem`/`UnlockSystem` son los únicos
-- que escriben, y ambos corren en el servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("Registry"))

export type Profile = {
	Currency: number,
	UnlockedMissions: { [string]: boolean },
	UnlockedMaps: { [string]: boolean },
	CompletedMissions: { [string]: boolean },
}

-- Las misiones iniciales se derivan del contenido: una misión que nadie desbloquea
-- está disponible desde el principio. Así añadir contenido no toca este módulo.
local function isUnlockedByMission(missionId: string): boolean
	for _, mission in Registry.Missions do
		for _, unlocked in mission.Rewards.MissionUnlocks do
			if unlocked == missionId then
				return true
			end
		end
	end
	return false
end

local function isUnlockedByMissionReward(mapId: string): boolean
	for _, mission in Registry.Missions do
		for _, unlocked in mission.Rewards.MapUnlocks do
			if unlocked == mapId then
				return true
			end
		end
	end
	return false
end

local STARTING_MISSIONS: { string } = {}
for id in Registry.Missions do
	if not isUnlockedByMission(id) then
		table.insert(STARTING_MISSIONS, id)
	end
end
table.sort(STARTING_MISSIONS)

local STARTING_MAPS: { [string]: boolean } = {}
for _, id in STARTING_MISSIONS do
	STARTING_MAPS[Registry.Missions[id].MapId] = true
end
for id in Registry.Maps do
	if not isUnlockedByMissionReward(id) then
		STARTING_MAPS[id] = true
	end
end

local profiles: { [Player]: Profile } = {}

local Profile = {}

function Profile.get(player: Player): Profile
	local profile = profiles[player]
	if profile then
		return profile
	end
	profile = {
		Currency = 0,
		UnlockedMissions = {},
		UnlockedMaps = {},
		CompletedMissions = {},
	}
	for _, id in STARTING_MISSIONS do
		profile.UnlockedMissions[id] = true
	end
	for id in STARTING_MAPS do
		profile.UnlockedMaps[id] = true
	end
	profiles[player] = profile
	return profile
end

function Profile.release(player: Player)
	profiles[player] = nil
end

function Profile.isMissionUnlocked(player: Player, missionId: string): boolean
	return Profile.get(player).UnlockedMissions[missionId] == true
end

function Profile.isMissionCompleted(player: Player, missionId: string): boolean
	return Profile.get(player).CompletedMissions[missionId] == true
end

-- Devuelve true solo la primera vez: permite informar al cliente de un desbloqueo
-- real sin duplicar el aviso en reintentos.
function Profile.unlockMission(player: Player, missionId: string): boolean
	local profile = Profile.get(player)
	if profile.UnlockedMissions[missionId] then
		return false
	end
	profile.UnlockedMissions[missionId] = true
	return true
end

function Profile.unlockMap(player: Player, mapId: string): boolean
	local profile = Profile.get(player)
	if profile.UnlockedMaps[mapId] then
		return false
	end
	profile.UnlockedMaps[mapId] = true
	return true
end

function Profile.completeMission(player: Player, missionId: string): boolean
	local profile = Profile.get(player)
	if profile.CompletedMissions[missionId] then
		return false
	end
	profile.CompletedMissions[missionId] = true
	return true
end

function Profile.addCurrency(player: Player, amount: number): number
	if amount <= 0 then
		return 0
	end
	local profile = Profile.get(player)
	profile.Currency += amount
	return amount
end

return Profile
