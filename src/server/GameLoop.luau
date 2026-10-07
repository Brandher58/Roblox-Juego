--!strict
-- Un solo Heartbeat para todo el servidor, con el orden explícito de los sistemas.
-- Así nadie más abre una conexión por frame y el coste por enemigo está medible.
local RunService = game:GetService("RunService")
local Match = require(script.Parent.Match)
local EnemyRegistry = require(script.Parent.Enemies.EnemyRegistry)
local EnemyAI = require(script.Parent.Enemies.EnemyAI)
local EnemySpawner = require(script.Parent.Spawning.EnemySpawner)
local Projectiles = require(script.Parent.Combat.Projectiles)
local OrbitBlades = require(script.Parent.Combat.OrbitBlades)
local WeaponRuntime = require(script.Parent.Combat.WeaponRuntime)
local XPPickups = require(script.Parent.Pickups.XPPickups)
local MissionManager = require(script.Parent.Missions.MissionManager)

-- Tras un tirón largo, un dt enorme teletransportaría enemigos y proyectiles.
local MAX_STEP = 0.1

local connection: RBXScriptConnection? = nil

local GameLoop = {}

function GameLoop.start()
	if connection then
		return
	end

	connection = RunService.Heartbeat:Connect(function(rawDt)
		local dt = math.min(rawDt, MAX_STEP)
		local now = os.clock()

		-- El reloj de partida va primero: si el estado cambia, el resto de sistemas ya
		-- ven el estado nuevo en este mismo frame.
		Match.update(dt, now)

		if not Match.isSimulating() then
			return
		end

		EnemyAI.update(dt, now)
		EnemyRegistry.rebuildGrid()
		Projectiles.update(dt)
		XPPickups.update(dt)
		-- Las cuchillas se mueven y cortan despues de mover a los enemigos, para que el
		-- corte use la posicion de este frame y no la del anterior.
		OrbitBlades.update(dt, now)
		WeaponRuntime.update(now)
		EnemySpawner.update(now, Match.getElapsed())
		-- La misión se evalúa al final del frame: los eventos de muerte de este frame
		-- ya han llegado a sus objetivos, así que una baja no se pierde hasta el
		-- siguiente. `Match` no conoce a `MissionManager`; los une este bucle.
		MissionManager.update(dt, now)
	end)
end

function GameLoop.stop()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return GameLoop
