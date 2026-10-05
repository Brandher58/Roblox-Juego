--!strict
-- Estadísticas por jugador. Es el único dueño de los modificadores de una partida:
-- nadie más escribe en Config.PlayerBaseStats, así que las pasivas y los buffs
-- temporales se acumulan aquí y se resuelven con el módulo puro StatMath.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local StatMath = require(Shared:WaitForChild("StatMath"))
local Types = require(Shared:WaitForChild("Types"))

type StatBlock = Types.StatBlock
type StatModifier = Types.StatModifier

type Entry = {
	modifier: StatModifier,
	expiresAt: number?,
}

local entries: { [Player]: { Entry } } = {}
local cache: { [Player]: StatBlock } = {}
local nextExpiry: { [Player]: number? } = {}

local function listFor(player: Player): { Entry }
	local list = entries[player]
	if not list then
		list = {}
		entries[player] = list
	end
	return list
end

local function prune(player: Player, now: number): { StatModifier }
	-- listFor y no entries[player]: un get() legitimo puede llegar sin modificadores
	-- todavia (jugador recien limpiado al arrancar la partida), y un jugador sin
	-- modificadores debe resolver simplemente las estadisticas base.
	local list = listFor(player)
	local modifiers: { StatModifier } = {}
	local kept: { Entry } = {}
	local soonest: number? = nil

	for _, entry in list do
		if entry.expiresAt then
			if entry.expiresAt <= now then
				continue
			end
			if soonest == nil or entry.expiresAt < soonest then
				soonest = entry.expiresAt
			end
		end
		table.insert(kept, entry)
		table.insert(modifiers, entry.modifier)
	end

	entries[player] = kept
	nextExpiry[player] = soonest
	return modifiers
end

local Stats = {}

function Stats.add(player: Player, modifier: StatModifier)
	local entry: Entry = { modifier = modifier }
	if modifier.duration then
		entry.expiresAt = os.clock() + modifier.duration
	end
	table.insert(listFor(player), entry)
	cache[player] = nil
end

-- Quita todos los modificadores de una fuente concreta: al mejorar un arma se
-- reemplaza su lista en lugar de sumar encima de la anterior.
function Stats.removeSource(player: Player, source: string)
	local list = entries[player]
	if not list then
		return
	end
	local kept = {}
	for _, entry in list do
		if entry.modifier.source ~= source then
			table.insert(kept, entry)
		end
	end
	entries[player] = kept
	cache[player] = nil
end

function Stats.clear(player: Player)
	entries[player] = nil
	cache[player] = nil
	nextExpiry[player] = nil
end

-- Se recalcula solo cuando cambia algo o cuando vence un buff temporal, para que
-- llamarlo en cada frame no genere basura.
function Stats.get(player: Player, now: number?): StatBlock
	local clock = now or os.clock()
	local cached = cache[player]
	local due = nextExpiry[player]
	if cached and (due == nil or clock < due) then
		return cached
	end

	local modifiers = prune(player, clock)
	local stats = StatMath.resolve(Config.PlayerBaseStats, modifiers)
	cache[player] = stats
	return stats
end

-- Segundos restantes de los buffs temporales, para el HUD.
function Stats.buffTimers(player: Player, now: number?): { { Name: string, Remaining: number } }
	local clock = now or os.clock()
	local list = entries[player]
	local timers = {}
	if not list then
		return timers
	end
	for _, entry in list do
		if entry.expiresAt and entry.expiresAt > clock then
			table.insert(timers, {
				Name = entry.modifier.source,
				Remaining = entry.expiresAt - clock,
			})
		end
	end
	return timers
end

return Stats
