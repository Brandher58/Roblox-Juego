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

-- El servidor no emite nada por evento hasta que el cliente confirma que ya tiene
-- sus listeners registrados: asi una carta de nivel que llega durante el arranque no
-- se pierde.
Remotes.ClientReady.OnServerEvent:Connect(function(player: Player)
	Match.sendTo(player)
end)

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

	-- El vertical slice no tiene lobby jugable: en cuanto hay alguien, arranca la
	-- partida. El estado "Lobby" ya existe para que la Fase 4 añada la sala sin tocar
	-- los sistemas de juego.
	if Match.getState() == "Lobby" then
		Match.startRun(os.clock())
	end
end

-- La partida es dueña del ciclo de vida del personaje: con el auto-respawn de Roblox
-- apagado, un jugador que cae vuelve a entrar por Match y no por el motor. Es una
-- propiedad del servicio Players, no del jugador, asi que se fija una sola vez aqui.
Players.CharacterAutoLoads = false

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	Match.releasePlayer(player)
end)

GameLoop.start()

-- Cubre a quien ya estaba conectado antes de que este script cargara.
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
