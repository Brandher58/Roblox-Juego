--!strict
-- Bucle de armas: un único recorrido por jugador y arma para decidir cuándo dispara.
-- No sabe cómo se ejecuta el ataque (eso es WeaponBehaviors) ni qué rutas de daño
-- existen (eso es EnemyRegistry).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("Registry"))
local StatMath = require(Shared:WaitForChild("StatMath"))
local Types = require(Shared:WaitForChild("Types"))
local Run = require(script.Parent.Parent.Run)
local Stats = require(script.Parent.Parent.Stats)
local PlayerAvatar = require(script.Parent.Parent.PlayerAvatar)
local EnemyRegistry = require(script.Parent.Parent.Enemies.EnemyRegistry)
local Behaviors = require(script.Parent.WeaponBehaviors)

type StatBlock = Types.StatBlock
type StatModifier = Types.StatModifier
type Context = Behaviors.Context

local cooldowns: { [Player]: { [string]: number } } = {}

-- Los modificadores de una mejora de arma se vuelven a aplicar una vez por nivel
-- comprado: subir Gun Damage tres veces da tres veces el bonus.
local function upgradeModifiers(player: Player, weaponId: string): { StatModifier }
	local modifiers: { StatModifier } = {}
	local run = Run.get(player)
	for upgradeId, count in run.upgradeLevels do
		local definition = Registry.Upgrades[upgradeId]
		if definition and definition.TargetId == weaponId then
			for _ = 1, count do
				for _, modifier in definition.Modifiers do
					table.insert(modifiers, {
						stat = modifier.stat,
						kind = modifier.kind,
						value = modifier.value,
						source = upgradeId,
					})
				end
			end
		end
	end
	return modifiers
end

local WeaponRuntime = {}

function WeaponRuntime.statsFor(player: Player, weaponId: string): StatBlock
	local definition = Registry.Weapons[weaponId]
	local run = Run.get(player)
	local level = run.weaponLevels[weaponId] or 0
	return StatMath.weapon(definition, level, upgradeModifiers(player, weaponId), Stats.get(player))
end

function WeaponRuntime.reset(player: Player)
	cooldowns[player] = {}
end

local function fire(player: Player, weaponId: string, now: number)
	local root = PlayerAvatar.root(player)
	if not root then
		return
	end

	local definition = Registry.Weapons[weaponId]
	local behavior = Behaviors[definition.Behavior]
	if not behavior then
		return
	end

	local stats = WeaponRuntime.statsFor(player, weaponId)

	-- Regla única de objetivo: un arma que lo necesita no dispara si no hay a nadie a
	-- tiro, y un arma que no lo necesita (cuchillas orbitando) se ahorra la búsqueda.
	local target: Vector3? = nil
	if definition.RequiresTarget ~= false then
		local enemy = EnemyRegistry.closest(root.Position, math.max(4, stats.Range or 40))
		if not enemy then
			return
		end
		target = enemy.Position + Vector3.new(0, 1, 0)
	end

	local context: Context = {
		player = player,
		weaponId = weaponId,
		stats = stats,
		origin = root.Position,
		target = target,
		lookDirection = root.CFrame.LookVector,
		now = now,
	}

	behavior(context)
end

function WeaponRuntime.update(now: number)
	for _, player in PlayerAvatar.alivePlayers() do
		local perWeapon = cooldowns[player]
		if not perWeapon then
			perWeapon = {}
			cooldowns[player] = perWeapon
		end

		local run = Run.get(player)
		for weaponId, level in run.weaponLevels do
			if level > 0 then
				local readyAt = perWeapon[weaponId] or 0
				if now >= readyAt then
					local stats = WeaponRuntime.statsFor(player, weaponId)
					local attackSpeed = math.max(0.1, stats.AttackSpeed or 1)
					perWeapon[weaponId] = now + 1 / attackSpeed
					fire(player, weaponId, now)
				end
			end
		end
	end
end

return WeaponRuntime
