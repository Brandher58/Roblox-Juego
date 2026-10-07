--!strict
-- Núcleo del sistema de misiones. Es el dueño de la verdad de la misión en curso:
-- estado, objetivos, jefe invocado, completion/failure, recompensas y desbloqueos.
--
-- No contiene ramas por misión/objetivo/jefe: todo sale de `Registry.Missions` y de
-- los registros modulares (`ObjectiveSystem`, `BossSystem`). Toda la autoridad es
-- servidor; el cliente solo recibe instantáneas y pide empezar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("Registry"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local Match = require(script.Parent.Parent.Match)
local Profile = require(script.Parent.Parent.Data.Profile)
local Difficulty = require(script.Parent.Parent.Spawning.Difficulty)
local EnemySpawner = require(script.Parent.Parent.Spawning.EnemySpawner)
local EnemyRegistry = require(script.Parent.Parent.Enemies.EnemyRegistry)
local ObjectiveSystem = require(script.Parent.ObjectiveSystem)
local BossSystem = require(script.Parent.BossSystem)
local RewardSystem = require(script.Parent.RewardSystem)
local UnlockSystem = require(script.Parent.UnlockSystem)

type MissionDefinition = Types.MissionDefinition
type MissionState = Types.MissionState
type MissionResult = Types.MissionResult

export type Execution = {
	definition: MissionDefinition,
	state: MissionState,
	objectives: { ObjectiveSystem.Runtime },
	bossSpawned: boolean,
	bossDefeated: boolean,
	rewarded: boolean,
}

local current: Execution? = nil
local lastResult: MissionResult? = nil

-- La HUD de misión se refresca con la misma cadencia que el HUD general: reloj,
-- objetivos y jefe no pueden quedarse congelados en la instantánea inicial.
local SNAPSHOT_INTERVAL = 0.2
local snapshotClock = 0

local MissionManager = {}

-- El evento de muerte llega una sola vez para todos: se reenvía a los objetivos de la
-- misión activa y se marca la caída del jefe. Ni el combate ni el spawner conocen a
-- las misiones; solo existe este canal de datos.
EnemyRegistry.onKilled(function(enemy)
	local execution = current
	if not execution or execution.state ~= "Active" then
		return
	end
	if table.find(enemy.Definition.Tags, "boss") then
		execution.bossDefeated = true
	end
	ObjectiveSystem.dispatch(execution.objectives, { Kind = "Kill", Enemy = enemy.Definition })
end)

local function summarizeObjectives(objectives: { ObjectiveSystem.Runtime }): { Types.MissionObjectiveState }
	local views: { Types.MissionObjectiveState } = {}
	for _, runtime in objectives do
		table.insert(views, ObjectiveSystem.view(runtime))
	end
	return views
end

local function remainingSeconds(execution: Execution): number?
	local remaining: number? = nil
	for _, runtime in execution.objectives do
		if runtime.Definition.Type == "Survive" then
			local left = math.max(0, runtime.Required - runtime.Current)
			if remaining == nil or left < remaining then
				remaining = left
			end
		end
	end
	return remaining
end

function MissionManager.snapshot(): Types.MissionSnapshot?
	local execution = current
	if not execution then
		return nil
	end

	local boss: Types.MissionBossView? = nil
	local bossDefinition = execution.definition.Boss
	if bossDefinition then
		local enemy = BossSystem.getActive()
		local definition = Registry.Enemies[bossDefinition.Id]
		boss = {
			Id = bossDefinition.Id,
			Name = if definition then definition.Name else bossDefinition.Id,
			Active = enemy ~= nil,
			Health = if enemy then enemy.Health else 0,
			MaxHealth = if enemy then enemy.MaxHealth else 0,
		}
	end

	return {
		MissionId = execution.definition.Id,
		DisplayName = execution.definition.DisplayName,
		MapId = execution.definition.MapId,
		State = execution.state,
		Elapsed = Match.getElapsed(),
		Remaining = remainingSeconds(execution),
		Objectives = summarizeObjectives(execution.objectives),
		Boss = boss,
	}
end

function MissionManager.broadcastUpdate()
	Remotes.MissionUpdate:FireAllClients(MissionManager.snapshot())
end

function MissionManager.sendUpdate(player: Player)
	Remotes.MissionUpdate:FireClient(player, MissionManager.snapshot())
end

local function summarizeObjectivesFor(definitions: { Types.MissionObjective })
	local list = {}
	for _, definition in definitions do
		table.insert(list, ObjectiveSystem.staticView(definition))
	end
	return list
end

function MissionManager.buildSummaries(player: Player): { Types.MissionSummary }
	local summaries: { Types.MissionSummary } = {}
	for id, mission in Registry.Missions do
		local state: MissionState = "Locked"
		if Profile.isMissionCompleted(player, id) then
			state = "Completed"
		elseif Profile.isMissionUnlocked(player, id) then
			state = "Available"
		end
		local map = Registry.Maps[mission.MapId]
		table.insert(summaries, {
			Id = id,
			MapId = mission.MapId,
			MapName = if map then map.DisplayName else mission.MapId,
			DisplayName = mission.DisplayName,
			Description = mission.Description,
			Duration = mission.Duration,
			State = state,
			Objectives = summarizeObjectivesFor(mission.Objectives),
			Rewards = {
				Currency = mission.Rewards.Currency,
				Missions = mission.Rewards.MissionUnlocks,
				Maps = mission.Rewards.MapUnlocks,
			},
		})
	end
	table.sort(summaries, function(a, b)
		return a.Id < b.Id
	end)
	return summaries
end

function MissionManager.sendList(player: Player)
	Remotes.MissionList:FireClient(player, MissionManager.buildSummaries(player))
end

function MissionManager.broadcastList()
	for _, player in Players:GetPlayers() do
		MissionManager.sendList(player)
	end
end

local function buildResult(execution: Execution, outcome: "Completed" | "Failed"): MissionResult
	return {
		MissionId = execution.definition.Id,
		DisplayName = execution.definition.DisplayName,
		Outcome = outcome,
		Duration = Match.getElapsed(),
		BossDefeated = execution.bossDefeated,
		Currency = 0,
		UnlockedMissions = {},
		UnlockedMaps = {},
	}
end

-- Cierre por éxito. Se llama una sola vez: el estado pasa a "Completing" antes de
-- repartir nada, así una segunda detección no duplica recompensas.
function MissionManager.complete(now: number)
	local execution = current
	if not execution or execution.state ~= "Active" then
		return
	end
	execution.state = "Completing"
	EnemySpawner.clearConfiguration()

	local players = Players:GetPlayers()
	local rewards = execution.definition.Rewards
	local result = buildResult(execution, "Completed")

	if not execution.rewarded then
		execution.rewarded = true
		RewardSystem.grant(rewards, players)
		local unlocked = UnlockSystem.apply(rewards, players)
		result.Currency = rewards.Currency
		result.UnlockedMissions = unlocked.Missions
		result.UnlockedMaps = unlocked.Maps
		for _, player in players do
			Profile.completeMission(player, execution.definition.Id)
		end
	end

	lastResult = result
	execution.state = "Completed"
	MissionManager.broadcastUpdate()
	Remotes.MissionFinished:FireAllClients(result)
	MissionManager.broadcastList()

	-- El fin de partida existente se reutiliza tal cual: limpia el mundo, muestra la
	-- pantalla de resultado y, tras la pausa, vuelve a la selección de misión.
	Match.stopRun("Victory", now)
end

-- Cierre por fallo. No reparte nada y deja la misión en Available para reintentar.
function MissionManager.fail()
	local execution = current
	if not execution or (execution.state ~= "Active" and execution.state ~= "Preparing") then
		return
	end
	execution.state = "Failed"
	EnemySpawner.clearConfiguration()
	BossSystem.reset()

	local result = buildResult(execution, "Failed")
	lastResult = result
	MissionManager.broadcastUpdate()
	Remotes.MissionFinished:FireAllClients(result)
end

function MissionManager.onMatchState(state: Types.MatchState)
	if state == "Defeat" then
		-- El fallo lo decide `Match` (todos muertos). La misión solo reacciona.
		MissionManager.fail()
	elseif state == "MissionSelect" or state == "Lobby" then
		-- Vuelta al lobby: se suelta la ejecución para poder reintentar la misión.
		current = nil
		lastResult = nil
		EnemySpawner.clearConfiguration()
		BossSystem.reset()
		Match.setAutoVictory(true)
	end
end

-- Validación autoritativa. Nada del cliente se cree: existencia, mapa, desbloqueo y
-- estado de partida se comprueban aquí.
function MissionManager.requestStart(player: Player, missionId: unknown): (boolean, string?)
	if typeof(missionId) ~= "string" or #missionId == 0 or #missionId > 60 then
		return false, "bad mission id"
	end
	local definition = Registry.Missions[missionId]
	if not definition then
		return false, "unknown mission"
	end
	if not Registry.Maps[definition.MapId] then
		return false, "unknown map"
	end
	if not Profile.isMissionUnlocked(player, missionId) then
		return false, "mission locked"
	end
	if
		current
		and (current.state == "Active" or current.state == "Preparing" or current.state == "Completing")
	then
		return false, "mission already running"
	end

	local state = Match.getState()
	if state ~= "MissionSelect" and state ~= "Lobby" then
		return false, "not in mission select"
	end

	local execution: Execution = {
		definition = definition,
		state = "Preparing",
		objectives = ObjectiveSystem.createAll(definition.Objectives),
		bossSpawned = false,
		bossDefeated = false,
		rewarded = false,
	}
	current = execution
	lastResult = nil
	snapshotClock = 0

	-- La configuración llega al spawner antes de que arranque la partida, para que la
	-- primera oleada ya sea la de la misión.
	Match.setAutoVictory(false)
	EnemySpawner.setConfiguration(definition.EnemyConfiguration, definition.DifficultyMultipliers)
	Match.startRun(os.clock())

	execution.state = "Active"
	MissionManager.broadcastUpdate()
	MissionManager.broadcastList()
	return true, nil
end

function MissionManager.update(dt: number, now: number)
	local execution = current
	if not execution or execution.state ~= "Active" or not Match.isSimulating() then
		return
	end

	snapshotClock += dt
	local elapsed = Match.getElapsed()
	ObjectiveSystem.update(execution.objectives, dt)

	local boss = execution.definition.Boss
	if boss and not execution.bossSpawned and elapsed >= (boss.SpawnAt or 0) then
		execution.bossSpawned = true
		BossSystem.spawn(boss.Id, Difficulty.evaluate(elapsed, execution.definition.DifficultyMultipliers))
		MissionManager.broadcastUpdate()
	end

	-- Actualización periódica: el reloj y los objetivos avanzan en el servidor y la
	-- HUD tiene que reflejarlo, no solo la instantánea del arranque.
	if snapshotClock >= SNAPSHOT_INTERVAL then
		snapshotClock = 0
		MissionManager.broadcastUpdate()
	end

	if ObjectiveSystem.allComplete(execution.objectives) then
		MissionManager.complete(now)
	end
end

-- Dev (playtest): adelanta los objetivos que corren por reloj (Survive) para probar
-- fases tardías sin esperar. `Match.advanceTime` hace lo mismo con el reloj de
-- partida; este método es un accesorio del admin, no parte del contrato definitivo.
function MissionManager.skipTime(seconds: number): boolean
	local execution = current
	if not execution or execution.state ~= "Active" then
		return false
	end
	for _, runtime in execution.objectives do
		if runtime.Definition.Type == "Survive" then
			local next = math.min(runtime.Required, runtime.Current + seconds)
			runtime.Current = next
			runtime.Complete = next >= runtime.Required
		end
	end
	MissionManager.broadcastUpdate()
	return true
end

function MissionManager.isActive(): boolean
	return current ~= nil and current.state == "Active"
end

function MissionManager.getState(): MissionState?
	return if current then current.state else nil
end

function MissionManager.getCurrentId(): string?
	return if current then current.definition.Id else nil
end

function MissionManager.lastResult(): MissionResult?
	return lastResult
end

return MissionManager
