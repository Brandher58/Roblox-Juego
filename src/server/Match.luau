--!strict
-- Propietario del flujo de una partida: estado, reloj, subida de nivel y limpieza.
--
-- Es el módulo de más arriba del servidor. Ningún otro cambia el estado de la
-- partida: el bucle pregunta si se está simulando, el spawner pregunta por el tiempo
-- transcurrido y el HUD recibe el snapshot desde aquí.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Registry = require(Shared:WaitForChild("Registry"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local Run = require(script.Parent.Run)
local Stats = require(script.Parent.Stats)
local PlayerAvatar = require(script.Parent.PlayerAvatar)
local EnemyRegistry = require(script.Parent.Enemies.EnemyRegistry)
local EnemySpawner = require(script.Parent.Spawning.EnemySpawner)
local WeaponRuntime = require(script.Parent.Combat.WeaponRuntime)
local Projectiles = require(script.Parent.Combat.Projectiles)
local OrbitBlades = require(script.Parent.Combat.OrbitBlades)
local XPPickups = require(script.Parent.Pickups.XPPickups)
local LevelUp = require(script.Parent.Progression.LevelUp)

type MatchState = Types.MatchState
type RunSnapshot = Types.RunSnapshot

local Match = {}

local OFFER_COUNT = 3
local SNAPSHOT_INTERVAL = 0.2
local CHOICE_COOLDOWN = 0.2

local state: MatchState = "Lobby"
local elapsed = 0
local snapshotClock = 0
local levelUpClock = 0
local resultsEndsAt = 0
local lastChoiceAt: { [Player]: number } = {}
-- En la Fase 1 sobrevivir `TargetDuration` daba la victoria. Con misiones, quien
-- decide el final es el MissionManager; este interruptor preserva el comportamiento
-- antiguo cuando no hay misión activa (lobby/solo).
local autoVictory = true
local stateListeners: { (MatchState) -> () } = {}

-- "Event", "Boss" y "Victory" están reservados: añadir un evento de partida no
-- requiere tocar el HUD ni los clientes.
local SIMULATED: { [MatchState]: boolean } = {
	Lobby = false,
	Starting = false,
	Playing = true,
	LevelUp = false,
	Event = true,
	Boss = true,
	MissionSelect = false,
	Victory = false,
	Defeat = false,
}

function Match.getState(): MatchState
	return state
end

function Match.getElapsed(): number
	return elapsed
end

function Match.isSimulating(): boolean
	return SIMULATED[state] == true
end

function Match.setState(next: MatchState)
	if state == next then
		return
	end
	state = next
	for _, listener in stateListeners do
		listener(next)
	end
	Match.broadcast()
end

-- Observadores de transición (p. ej. MissionManager). Devuelve una función para
-- darse de baja. `Match` no conoce a sus observadores: solo avisa.
function Match.onStateChanged(listener: (MatchState) -> ()): () -> ()
	table.insert(stateListeners, listener)
	return function()
		local index = table.find(stateListeners, listener)
		if index then
			table.remove(stateListeners, index)
		end
	end
end

function Match.setAutoVictory(enabled: boolean)
	autoVictory = enabled
end

-- Dev (playtest): adelanta el reloj de partida sin tocar el estado. El spawner y
-- las misiones ven el nuevo `elapsed` al instante (más presión, boss antes).
function Match.advanceTime(seconds: number)
	elapsed += seconds
	Match.broadcast()
end

local function clearWorld()
	EnemyRegistry.clearAll()
	Projectiles.clearAll()
	OrbitBlades.clearAll()
	XPPickups.clearAll()
end

local function snapshotFor(player: Player, now: number): RunSnapshot
	local run = Run.get(player)
	local stats = Stats.get(player, now)
	local humanoid = PlayerAvatar.humanoid(player)

	local weapons: { Types.WeaponView } = {}
	for weaponId, level in run.weaponLevels do
		local definition = Registry.Weapons[weaponId]
		if definition then
			table.insert(weapons, {
				Id = weaponId,
				Name = definition.Name,
				Icon = definition.Icon,
				Level = level,
				MaxLevel = definition.MaxLevel,
			})
		end
	end
	table.sort(weapons, function(a, b)
		return a.Id < b.Id
	end)

	local upgradeIds: { string } = {}
	for upgradeId, level in run.upgradeLevels do
		if level > 0 then
			table.insert(upgradeIds, upgradeId)
		end
	end
	table.sort(upgradeIds)

	local passives: { Types.PassiveView } = {}
	for _, upgradeId in upgradeIds do
		local definition = Registry.Upgrades[upgradeId]
		if definition then
			table.insert(passives, {
				Id = upgradeId,
				Name = definition.Name,
				Icon = definition.Icon,
				Level = run.upgradeLevels[upgradeId],
				MaxLevel = definition.MaxLevel,
			})
		end
	end

	return {
		State = state,
		Elapsed = elapsed,
		Health = if humanoid then humanoid.Health else 0,
		MaxHealth = stats.MaxHealth or 100,
		Level = run.level,
		XP = run.xp,
		XPToNext = Run.xpToNext(player),
		Weapons = weapons,
		Passives = passives,
		Buffs = Stats.buffTimers(player, now),
		MoveSpeed = stats.MoveSpeed or 16,
		PickupRadius = stats.PickupRadius or 0,
	}
end

function Match.pushSnapshot(player: Player)
	Remotes.RunSnapshot:FireClient(player, snapshotFor(player, os.clock()))
end

-- Único canal de estado: cada cliente recibe su estado y, si tiene una elección
-- pendiente, sus propias cartas.
function Match.sendTo(player: Player)
	local now = os.clock()
	Remotes.MatchStateChanged:FireClient(player, state, elapsed, LevelUp.pendingFor(player))
	Remotes.RunSnapshot:FireClient(player, snapshotFor(player, now))
end

function Match.broadcast()
	for _, player in Players:GetPlayers() do
		Match.sendTo(player)
	end
end

function Match.startRun(now: number)
	clearWorld()
	elapsed = 0
	snapshotClock = 0
	levelUpClock = 0
	resultsEndsAt = 0

	for _, player in Players:GetPlayers() do
		Run.reset(player)
		Stats.clear(player)
		LevelUp.clear(player)
		WeaponRuntime.reset(player)
		lastChoiceAt[player] = 0
		-- Base stats del jugador recien llegado. Puede no tener avatar todavia: el
		-- personaje se carga unas lineas mas abajo.
		PlayerAvatar.applyStats(player, Stats.get(player, now))

		task.spawn(function()
			local ok, problem = pcall(player.LoadCharacterAsync, player)
			if not ok then
				warn(`[Match] no se pudo cargar el personaje de {player.Name}: {problem}`)
			end
		end)
	end

	EnemySpawner.reset(now)
	Match.setState("Playing")
end

function Match.stopRun(final: MatchState, now: number)
	clearWorld()
	if final == "Defeat" or final == "Victory" then
		local duration = if final == "Victory" then Config.Run.VictoryDuration else Config.Run.DefeatDuration
		resultsEndsAt = now + duration
	end
	Match.setState(final)
end

-- Vuelta al lobby tras una partida. Deja a los jugadores vivos y con personaje para
-- que la selección de misión no aparezca sobre nadie muerto. `MissionManager` escucha
-- este estado y suelta la ejecución, de modo que la misión se puede reintentar.
function Match.returnToSelect(now: number)
	clearWorld()
	elapsed = 0
	snapshotClock = 0
	levelUpClock = 0
	resultsEndsAt = 0

	for _, player in Players:GetPlayers() do
		PlayerAvatar.applyStats(player, Stats.get(player, now))
		if not PlayerAvatar.isAlive(player) then
			task.spawn(function()
				local ok, problem = pcall(player.LoadCharacterAsync, player)
				if not ok then
					warn(`[Match] no se pudo recargar el personaje de {player.Name}: {problem}`)
					return
				end
				PlayerAvatar.applyStats(player, Stats.get(player, now))
			end)
		end
	end

	Match.setState("MissionSelect")
end

-- Un jugador "tiene elección pendiente" cuando hay cartas sin elegir. Los niveles
-- sin cartas posibles ya se descartaron dentro de `LevelUp.begin`.
local function hasPendingChoices(): boolean
	for _, player in Players:GetPlayers() do
		local offers = LevelUp.pendingFor(player)
		if offers and #offers > 0 then
			return true
		end
	end
	return false
end

function Match.beginLevelUp()
	for _, player in Players:GetPlayers() do
		if LevelUp.queuedLevels(player) > 0 then
			LevelUp.begin(player, OFFER_COUNT)
		end
	end
	levelUpClock = 0

	-- Sin cartas que ofrecer (p. ej. todo maxeado en modo dev) no hay motivo para
	-- congelar el reloj: la partida sigue sin interrupción.
	if not hasPendingChoices() then
		if state == "LevelUp" then
			Match.setState("Playing")
			EnemySpawner.reset(os.clock())
		end
		return
	end

	Match.setState("LevelUp")
end

function Match.grantXp(player: Player, amount: number)
	if not Match.isSimulating() then
		return
	end
	-- XPModifier vive en las estadísticas del jugador (base 1) para que cualquier
	-- pasiva futura pueda tocarlo sin que este sistema conozca la mejora.
	local modifier = Stats.get(player).XPModifier or 1
	local gained = Run.addXp(player, amount * modifier)
	if gained <= 0 then
		return
	end

	LevelUp.awardLevels(player, gained)
	Match.pushSnapshot(player)
	if state == "Playing" then
		Match.beginLevelUp()
	end
end

-- Petición del cliente. El servidor no confía en nada: la carta tiene que estar en
-- el conjunto pendiente y cada pendiente se consume una sola vez.
function Match.handleUpgradeRequest(player: Player, upgradeId: unknown): (boolean, string?)
	if state ~= "LevelUp" then
		return false, "run not paused"
	end
	if typeof(upgradeId) ~= "string" or #upgradeId > 40 then
		return false, "bad upgrade id"
	end

	local now = os.clock()
	if now - (lastChoiceAt[player] or 0) < CHOICE_COOLDOWN then
		return false, "too fast"
	end
	lastChoiceAt[player] = now

	if not LevelUp.consume(player, upgradeId :: string) then
		return false, "upgrade not offered"
	end

	Remotes.UpgradeChosen:FireClient(player, upgradeId)
	PlayerAvatar.applyStats(player, Stats.get(player, now))
	Match.pushSnapshot(player)

	-- Una sola gota puede dar varios niveles: se encadena otra carta sin volver a
	-- congelar el reloj. Si la generación ya no encuentra nada (todo maxeado), el
	-- nivel sobrante se descarta y se sigue con la comprobación de abajo.
	if LevelUp.queuedLevels(player) > 0 then
		local offers = LevelUp.begin(player, OFFER_COUNT)
		if #offers > 0 then
			Match.broadcast()
			return true, nil
		end
	end

	if not hasPendingChoices() then
		levelUpClock = 0
		Match.setState("Playing")
		EnemySpawner.reset(now)
	end
	return true, nil
end

function Match.onPlayerDied(player: Player)
	local run = Run.get(player)
	run.alive = false
	if state == "Victory" or state == "Defeat" or state == "Lobby" then
		return
	end
	if #PlayerAvatar.alivePlayers() > 0 then
		return
	end
	Match.stopRun("Defeat", os.clock())
end

function Match.releasePlayer(player: Player)
	lastChoiceAt[player] = nil
	Run.release(player)
	Stats.clear(player)
	LevelUp.clear(player)
	WeaponRuntime.reset(player)
	OrbitBlades.reset(player)
end

function Match.update(dt: number, now: number)
	if state == "Playing" then
		elapsed += dt
		snapshotClock += dt
		if snapshotClock >= SNAPSHOT_INTERVAL then
			snapshotClock = 0
			for _, player in Players:GetPlayers() do
				Match.pushSnapshot(player)
			end
		end
		-- Objetivo de la Fase 1 (sin misión). Con misión activa, `autoVictory` está
		-- apagado y es el MissionManager quien cierra la partida.
		if autoVictory and elapsed >= Config.Run.TargetDuration then
			Match.stopRun("Victory", now)
		end
		return
	end

	if state == "LevelUp" then
		levelUpClock += dt
		if levelUpClock >= Config.Run.LevelUpTimeout then
			-- Autoelección: una partida nunca queda bloqueada por un jugador ausente.
			-- Se elige la primera carta y es el servidor quien aplica la mejora.
			for _, player in Players:GetPlayers() do
				local offers = LevelUp.pendingFor(player)
				if offers and #offers > 0 then
					Match.handleUpgradeRequest(player, offers[1].Id)
				end
			end
			if state == "LevelUp" and not hasPendingChoices() then
				levelUpClock = 0
				Match.setState("Playing")
				EnemySpawner.reset(now)
			end
		end
		return
	end

	if (state == "Defeat" or state == "Victory") and now >= resultsEndsAt then
		if #Players:GetPlayers() > 0 then
			Match.returnToSelect(now)
		else
			state = "Lobby"
		end
	end
end

return Match
