--!strict
-- Cálculo de estadísticas. Todo puro, sin Roblox: se puede probar headless.
--
-- Pipeline de jugador:
--   base (Config.PlayerBaseStats)
--   + modificadores Add
--   x modificadores Multiply
--   = stats finales
--
-- Pipeline de arma:
--   base de la definición
--   + scaling por nivel
--   + modificadores de mejoras dirigidas a esa arma
--   x multiplicadores globales del jugador
--   = stats del arma
-- Import dual: en Roblox se resuelve el ModuleScript vecino; fuera de Studio (las
-- pruebas headless con Lune) cae a la ruta relativa, porque Lune no expone `script`.
local Types = require(script and script.Parent.Types or "./Types")

type StatModifier = Types.StatModifier
type StatBlock = Types.StatBlock
type WeaponDefinition = Types.WeaponDefinition

local StatMath = {}

function StatMath.apply(stats: StatBlock, modifier: StatModifier)
	local current = stats[modifier.stat] or 0
	if modifier.kind == "Add" then
		stats[modifier.stat] = current + modifier.value
	else
		stats[modifier.stat] = current * modifier.value
	end
end

-- Los "Add" se resuelven antes que los "Multiply" para que el resultado no dependa
-- del orden en el que se registraron los modificadores.
function StatMath.resolve(base: StatBlock, modifiers: { StatModifier }): StatBlock
	local stats = table.clone(base)
	for _, modifier in modifiers do
		if modifier.kind == "Add" then
			StatMath.apply(stats, modifier)
		end
	end
	for _, modifier in modifiers do
		if modifier.kind == "Multiply" then
			StatMath.apply(stats, modifier)
		end
	end
	return stats
end

-- Las estadísticas globales del jugador son multiplicadores por diseño:
-- Config.PlayerBaseStats deja Damage/AttackSpeed/Range/ProjectileSpeed en 1 y
-- ProjectileCount/Pellets/Spread en 0, así que añadir una mejora global nunca
-- pisa el valor propio del arma.
local GLOBAL_MULTIPLIERS: { Types.StatKey } = { "Damage", "AttackSpeed", "Range", "ProjectileSpeed" }
local GLOBAL_ADDITIONS: { Types.StatKey } = { "ProjectileCount", "Pellets", "Spread" }

function StatMath.weapon(
	definition: WeaponDefinition,
	level: number,
	upgrades: { StatModifier },
	playerStats: StatBlock
): StatBlock
	local stats = table.clone(definition.BaseStats)

	for step = 2, level do
		local modifiers = definition.Scaling[step]
		if modifiers then
			for _, modifier in modifiers do
				StatMath.apply(stats, modifier)
			end
		end
	end

	for _, modifier in upgrades do
		StatMath.apply(stats, modifier)
	end

	for _, stat in GLOBAL_MULTIPLIERS do
		stats[stat] = (stats[stat] or 0) * (playerStats[stat] or 1)
	end
	for _, stat in GLOBAL_ADDITIONS do
		stats[stat] = (stats[stat] or 0) + (playerStats[stat] or 0)
	end

	return stats
end

return StatMath
