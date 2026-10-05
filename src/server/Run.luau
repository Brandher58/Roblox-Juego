--!strict
-- Estado de partida de un jugador: nivel, XP, armas y mejoras. Es memoria volátil;
-- al terminar la partida se descarta. Nada de esto se guarda (eso es MetaData).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("Registry"))
local Progression = require(Shared:WaitForChild("Progression"))
local Types = require(Shared:WaitForChild("Types"))

type RunView = Types.RunView

export type Run = {
	player: Player,
	level: number,
	xp: number,
	alive: boolean,
	weaponLevels: { [string]: number },
	upgradeLevels: { [string]: number },
}

local runs: { [Player]: Run } = {}

local function create(player: Player): Run
	local run: Run = {
		player = player,
		level = 1,
		xp = 0,
		alive = true,
		weaponLevels = { [Registry.StartingWeaponId] = 1 },
		upgradeLevels = {},
	}
	runs[player] = run
	return run
end

local Run = {}

function Run.get(player: Player): Run
	return runs[player] or create(player)
end

function Run.release(player: Player)
	runs[player] = nil
end

function Run.reset(player: Player)
	create(player)
end

function Run.addXp(player: Player, amount: number): number
	local run = runs[player]
	if not run or amount <= 0 then
		return 0
	end
	local level, xp, gained = Progression.addXp(run.level, run.xp, amount)
	run.level = level
	run.xp = xp
	return gained
end

function Run.view(player: Player): RunView
	local run = Run.get(player)
	return {
		level = run.level,
		weaponLevels = run.weaponLevels,
		upgradeLevels = run.upgradeLevels,
	}
end

function Run.xpToNext(player: Player): number
	local run = Run.get(player)
	return Progression.xpForNext(run.level)
end

return Run
