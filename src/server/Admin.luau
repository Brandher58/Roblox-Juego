--!strict
-- Menú de administración SOLO en Studio: otorga armas, sube mejoras a tope, da XP
-- y cura, para poder playtestear el arsenal sin depender del sorteo de cartas.
--
-- El remote existe también en builds de producción (el árbol de ReplicatedStorage
-- no difiere), pero "un botón no es autoridad": fuera de Studio no hay handler, así
-- que FireServer no tiene ningún efecto. Y aunque un cliente llegara a usarlo en un
-- servidor de Studio, los comandos son una lista fija con tipos validados.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("Registry"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Run = require(script.Parent.Run)
local Stats = require(script.Parent.Stats)
local PlayerAvatar = require(script.Parent.PlayerAvatar)
local Match = require(script.Parent.Match)
local WeaponRuntime = require(script.Parent.Combat.WeaponRuntime)

type RunState = Run.Run

local Admin = {}

local function heal(player: Player)
	local humanoid = PlayerAvatar.humanoid(player)
	local stats = Stats.get(player)
	if humanoid then
		humanoid.Health = math.min(humanoid.MaxHealth, stats.MaxHealth or 100)
	end
end

-- Refresca la proyección al avatar, reinicia los relojes de armas (para que
-- disparen ya con las stats nuevas) y empuja un snapshot al HUD.
local function commit(player: Player)
	PlayerAvatar.applyStats(player, Stats.get(player))
	WeaponRuntime.reset(player)
	Match.pushSnapshot(player)
end

local function handle(player: Player, command: unknown, value: unknown): boolean
	if typeof(command) ~= "string" then
		return false
	end

	local state = Run.get(player)
	if command == "unlock_all" then
		for weaponId, _weapon in Registry.Weapons do
			state.weaponLevels[weaponId] = math.max(1, state.weaponLevels[weaponId] or 0)
		end
	elseif command == "max_all" then
		for weaponId, weapon in Registry.Weapons do
			state.weaponLevels[weaponId] = weapon.MaxLevel
		end
		for upgradeId, upgrade in Registry.Upgrades do
			if upgrade.Kind ~= "NewWeapon" then
				state.upgradeLevels[upgradeId] = upgrade.MaxLevel
			end
		end
	elseif command == "grant_xp" then
		if typeof(value) ~= "number" then
			return false
		end
		Match.grantXp(player, value)
		return true
	elseif command == "heal" then
		heal(player)
	else
		return false
	end

	commit(player)
	return true
end

function Admin.init()
	if not RunService:IsStudio() then
		return
	end
	Remotes.AdminCommand.OnServerEvent:Connect(function(player: Player, command: unknown, value: unknown)
		if not handle(player, command, value) then
			warn(`[Admin] comando rechazado de {player.Name}`)
		end
	end)
end

return Admin
