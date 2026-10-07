--!strict
-- Progresión permanente del jugador. Frontera Run/Meta: memoria de sesión más una
-- copia persistente en DataStore con reconciliación contra el contenido (solo se
-- aceptan misiones/mapas que existan en `Registry`) y escrituras diferidas con
-- debounce.
--
-- La autoridad sigue siendo del servidor: `RewardSystem`/`UnlockSystem` son los
-- únicos que escriben y ambos corren aquí. Nada de lo leído se cree a ciegas.
--
-- En Studio el DataStore funciona solo con "Studio Access to API Services" activado
-- (Game Settings → Security); si está apagado, este módulo degrada a sesión y avisa.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("Registry"))

local STORE_NAME = "MissionProgress"
local STORE_SCOPE = "v1"
local SAVE_DELAY = 4
local MAX_CURRENCY = 10 ^ 9

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
local loaded: { [Player]: boolean } = {}
local dirty: { [Player]: boolean } = {}
local saveScheduled: { [Player]: boolean } = {}
local loadListeners: { (Player) -> () } = {}
local store: DataStore? = nil

local function getStore(): DataStore?
	if store then
		return store
	end
	local ok, problem = pcall(function()
		store = DataStoreService:GetDataStore(STORE_NAME, STORE_SCOPE)
	end)
	if not ok then
		warn(
			`[Profile] DataStore no disponible (¿falta "Studio Access to API Services"?): {problem}. Progreso solo de sesión.`
		)
		store = nil
	end
	return store
end

local function encodedKeys(values: { [string]: boolean }): { string }
	local ids: { string } = {}
	for id in values do
		table.insert(ids, id)
	end
	return ids
end

local function encode(profile: Profile): string
	return HttpService:JSONEncode({
		v = 1,
		currency = profile.Currency,
		missions = encodedKeys(profile.UnlockedMissions),
		maps = encodedKeys(profile.UnlockedMaps),
		completed = encodedKeys(profile.CompletedMissions),
	})
end

local function sanitizeCurrency(value: unknown): number
	local number = tonumber(value)
	if number == nil or number ~= number then
		return 0
	end
	return math.clamp(math.floor(number), 0, MAX_CURRENCY)
end

local function sanitizeIds(raw: unknown, known: { [string]: any }): { [string]: boolean }
	local out: { [string]: boolean } = {}
	if type(raw) ~= "table" then
		return out
	end
	for _, id in raw do
		if type(id) == "string" and known[id] then
			out[id] = true
		end
	end
	return out
end

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

-- Carga asíncrona: se fusiona sobre los defaults de sesión y avisa a los
-- listeners cuando termina (Main.server reenvía la lista de misiones al jugador).
function Profile.load(player: Player)
	task.spawn(function()
		if loaded[player] then
			return
		end
		loaded[player] = true

		local datastore = getStore()
		if not datastore then
			return
		end

		local ok, raw = pcall(function()
			return datastore:GetAsync(tostring(player.UserId))
		end)
		if not ok then
			warn(`[Profile] no se pudo cargar el progreso de {player.Name}: {raw}`)
			return
		end
		if raw == nil then
			return
		end

		local stored: any = raw
		if type(raw) == "string" then
			local decoded, value = pcall(HttpService.JSONDecode, HttpService, raw)
			stored = if decoded then value else nil
		end

		local profile = Profile.get(player)
		if type(stored) == "table" then
			local currency = sanitizeCurrency(stored.currency)
			if currency > 0 then
				profile.Currency = currency
			end
			local missions = sanitizeIds(stored.missions, Registry.Missions)
			for id in missions do
				profile.UnlockedMissions[id] = true
			end
			local maps = sanitizeIds(stored.maps, Registry.Maps)
			for id in maps do
				profile.UnlockedMaps[id] = true
			end
			local completed = sanitizeIds(stored.completed, Registry.Missions)
			for id in completed do
				profile.CompletedMissions[id] = true
			end
		end

		for _, listener in loadListeners do
			listener(player)
		end
	end)
end

function Profile.save(player: Player)
	if not dirty[player] then
		return
	end
	dirty[player] = nil
	saveScheduled[player] = nil

	local profile = profiles[player]
	if not profile then
		return
	end

	local datastore = getStore()
	if not datastore then
		return
	end

	local profileData = profile
	local ok, problem = pcall(function()
		datastore:SetAsync(tostring(player.UserId), encode(profileData))
	end)
	if not ok then
		warn(`[Profile] no se pudo guardar el progreso de {player.Name}: {problem}`)
	end
end

-- Marca el perfil como pendiente de guardar y programa una escritura diferida.
function Profile.markDirty(player: Player)
	dirty[player] = true
	if saveScheduled[player] then
		return
	end
	saveScheduled[player] = true
	task.delay(SAVE_DELAY, function()
		saveScheduled[player] = nil
		Profile.save(player)
	end)
end

function Profile.onLoaded(listener: (Player) -> ()): () -> ()
	table.insert(loadListeners, listener)
	return function()
		table.remove(loadListeners, table.find(loadListeners, listener))
	end
end

-- Guarda antes de soltar la memoria: al salir el perfil sigue siendo del jugador
-- y el servidor todavía puede escribir.
function Profile.release(player: Player)
	Profile.save(player)
	profiles[player] = nil
	loaded[player] = nil
	dirty[player] = nil
	saveScheduled[player] = nil
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
	Profile.markDirty(player)
	return true
end

function Profile.unlockMap(player: Player, mapId: string): boolean
	local profile = Profile.get(player)
	if profile.UnlockedMaps[mapId] then
		return false
	end
	profile.UnlockedMaps[mapId] = true
	Profile.markDirty(player)
	return true
end

function Profile.completeMission(player: Player, missionId: string): boolean
	local profile = Profile.get(player)
	if profile.CompletedMissions[missionId] then
		return false
	end
	profile.CompletedMissions[missionId] = true
	Profile.markDirty(player)
	return true
end

function Profile.addCurrency(player: Player, amount: number): number
	if amount <= 0 then
		return 0
	end
	local profile = Profile.get(player)
	profile.Currency = math.min(MAX_CURRENCY, profile.Currency + amount)
	Profile.markDirty(player)
	return amount
end

-- Red de seguridad al cerrar el servidor: vuelca lo pendiente aunque nadie haya
-- pasado por PlayerRemoving. Mejor esfuerzo: dentro de BindToClose las escrituras
-- pueden fallar y se ignoran.
game:BindToClose(function()
	local datastore = getStore()
	if not datastore then
		return
	end
	for player in profiles do
		if dirty[player] then
			local profile = profiles[player]
			pcall(function()
				datastore:SetAsync(tostring(player.UserId), encode(profile))
			end)
		end
	end
end)

return Profile
