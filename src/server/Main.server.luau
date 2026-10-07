--!strict
-- Arranque del servidor. Aquí se cablean las piezas en un orden explícito y se
-- instala la una y única conexión de red entrante: nada más en el servidor escucha
-- peticiones del cliente.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Stats = require(script.Parent.Stats)
local PlayerAvatar = require(script.Parent.PlayerAvatar)
local Match = require(script.Parent.Match)
local GameLoop = require(script.Parent.GameLoop)
local EnemyRegistry = require(script.Parent.Enemies.EnemyRegistry)
local XPPickups = require(script.Parent.Pickups.XPPickups)
local Projectiles = require(script.Parent.Combat.Projectiles)
local OrbitBlades = require(script.Parent.Combat.OrbitBlades)
local Admin = require(script.Parent.Admin)
local Profile = require(script.Parent.Data.Profile)
local MissionManager = require(script.Parent.Missions.MissionManager)

-- Pools y carpetas de mundo antes de que nada pueda instanciar.
EnemyRegistry.init()
XPPickups.init()
Projectiles.init()
OrbitBlades.init()
Admin.init()

-- El propietario de la partida decide qué significa recoger XP. Inyectarlo aquí
-- mantiene la dirección de dependencias en un solo sentido.
XPPickups.onCollect(Match.grantXp)

Remotes.RequestUpgrade.OnServerEvent:Connect(function(player: Player, upgradeId: unknown)
	local ok, reason = Match.handleUpgradeRequest(player, upgradeId)
	if not ok then
		warn(`[Server] elección rechazada de {player.Name}: {reason}`)
	end
end)

-- Petición de misión. El servidor valida existencia, desbloqueo y estado de partida;
-- el cliente nunca cambia de estado por su cuenta.
Remotes.RequestMission.OnServerEvent:Connect(function(player: Player, missionId: unknown)
	local ok, reason = MissionManager.requestStart(player, missionId)
	if not ok then
		warn(`[Server] misión rechazada de {player.Name}: {reason}`)
	end
end)

-- La misión observa las transiciones de `Match` sin que `Match` la conozca: reacciona
-- al fallo y suelta la ejecución al volver al lobby.
Match.onStateChanged(function(state)
	MissionManager.onMatchState(state)
	if state == "MissionSelect" then
		MissionManager.broadcastList()
		MissionManager.broadcastUpdate()
	end
end)

-- El servidor no emite nada por evento hasta que el cliente confirma que ya tiene
-- sus listeners registrados: asi una carta de nivel que llega durante el arranque no
-- se pierde.
Remotes.ClientReady.OnServerEvent:Connect(function(player: Player)
	Match.sendTo(player)
	MissionManager.sendList(player)
	MissionManager.sendUpdate(player)
end)

-- Carga el personaje de un jugador que no está vivo (el auto-respawn está apagado).
local function ensureCharacter(player: Player, now: number)
	if PlayerAvatar.isAlive(player) then
		return
	end
	task.spawn(function()
		local ok, problem = pcall(player.LoadCharacterAsync, player)
		if not ok then
			warn(`[Server] no se pudo cargar el personaje de {player.Name}: {problem}`)
			return
		end
		PlayerAvatar.applyStats(player, Stats.get(player, now))
	end)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	PlayerAvatar.applyStats(player, Stats.get(player))

	humanoid.Died:Once(function()
		Match.onPlayerDied(player)
	end)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end

	-- Lobby jugable: el primer jugador mete la partida en selección de misión (y
	-- recarga personajes); los que entran después se unen al estado existente. Solo
	-- el servidor decide el estado; el cliente pide empezar una misión.
	if Match.getState() == "Lobby" then
		Match.returnToSelect(os.clock())
	else
		ensureCharacter(player, os.clock())
	end
	MissionManager.sendList(player)
	MissionManager.sendUpdate(player)
end

-- La partida es dueña del ciclo de vida del personaje: con el auto-respawn de Roblox
-- apagado, un jugador que cae vuelve a entrar por Match y no por el motor. Es una
-- propiedad del servicio Players, no del jugador, asi que se fija una sola vez aqui.
Players.CharacterAutoLoads = false

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	Match.releasePlayer(player)
	Profile.release(player)
end)

GameLoop.start()

-- Cubre a quien ya estaba conectado antes de que este script cargara.
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
