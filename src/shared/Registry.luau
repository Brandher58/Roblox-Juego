--!strict
-- Registro de contenido: indexa y valida las definiciones de armas, enemigos y
-- mejoras. Servidor y cliente cargan este mismo registro, así que un error de
-- contenido (id duplicado, stat inexistente, rareza inválida) revienta al cargar en
-- los dos lados, en lugar de aparecer a mitad de una partida.
-- Import dual (ver StatMath.luau): el módulo vecino se resuelve por `script` en Roblox y
-- por ruta relativa en las pruebas headless con Lune.
local Types = require(script and script.Parent.Types or "./Types")
local Rarity = require(script and script.Parent.Rarity or "./Rarity")

local weaponList = {
	require(script and script.Parent.Definitions.Weapons.Gun or "./Definitions/Weapons/Gun"),
	require(script and script.Parent.Definitions.Weapons.Shotgun or "./Definitions/Weapons/Shotgun"),
	require(script and script.Parent.Definitions.Weapons.Chain or "./Definitions/Weapons/Chain"),
	require(script and script.Parent.Definitions.Weapons.Nova or "./Definitions/Weapons/Nova"),
	require(script and script.Parent.Definitions.Weapons.Bomb or "./Definitions/Weapons/Bomb"),
	require(script and script.Parent.Definitions.Weapons.Orbit or "./Definitions/Weapons/Orbit"),
}

local enemyList = {
	require(script and script.Parent.Definitions.Enemies.Basic or "./Definitions/Enemies/Basic"),
}

local upgradeList = {
	require(script and script.Parent.Definitions.Upgrades.GunDamage or "./Definitions/Upgrades/GunDamage"),
	require(
		script and script.Parent.Definitions.Upgrades.GunAttackSpeed
			or "./Definitions/Upgrades/GunAttackSpeed"
	),
	require(
		script and script.Parent.Definitions.Upgrades.ShotgunUnlock or "./Definitions/Upgrades/ShotgunUnlock"
	),
	require(
		script and script.Parent.Definitions.Upgrades.ShotgunDamage or "./Definitions/Upgrades/ShotgunDamage"
	),
	require(
		script and script.Parent.Definitions.Upgrades.ChainUnlock or "./Definitions/Upgrades/ChainUnlock"
	),
	require(
		script and script.Parent.Definitions.Upgrades.ChainDamage or "./Definitions/Upgrades/ChainDamage"
	),
	require(script and script.Parent.Definitions.Upgrades.NovaUnlock or "./Definitions/Upgrades/NovaUnlock"),
	require(script and script.Parent.Definitions.Upgrades.NovaDamage or "./Definitions/Upgrades/NovaDamage"),
	require(script and script.Parent.Definitions.Upgrades.BombUnlock or "./Definitions/Upgrades/BombUnlock"),
	require(script and script.Parent.Definitions.Upgrades.BombDamage or "./Definitions/Upgrades/BombDamage"),
	require(
		script and script.Parent.Definitions.Upgrades.OrbitUnlock or "./Definitions/Upgrades/OrbitUnlock"
	),
	require(
		script and script.Parent.Definitions.Upgrades.OrbitDamage or "./Definitions/Upgrades/OrbitDamage"
	),
	require(script and script.Parent.Definitions.Upgrades.Vitality or "./Definitions/Upgrades/Vitality"),
}

local VALID_STATS: { [string]: boolean } = {
	MaxHealth = true,
	Armor = true,
	MoveSpeed = true,
	Damage = true,
	AttackSpeed = true,
	CriticalChance = true,
	CriticalDamage = true,
	Range = true,
	ProjectileSpeed = true,
	ProjectileCount = true,
	Pellets = true,
	Spread = true,
	PickupRadius = true,
	XPModifier = true,
	Luck = true,
	-- Stats de los comportamientos de area, cadena y contacto.
	Radius = true,
	BlastRadius = true,
	Arc = true,
	ChainCount = true,
	ChainRange = true,
	ChainFalloff = true,
	BladeCount = true,
	OrbitRadius = true,
	OrbitSpeed = true,
	HitCooldown = true,
}

local STARTING_WEAPON_ID = "gun"

local function indexById<T>(list: { T }, kind: string): { [string]: T }
	local byId = {}
	for _, entry in list do
		local id = entry.Id :: string
		if byId[id] then
			error(`[Registry] id duplicado en {kind}: {id}`)
		end
		byId[id] = entry
	end
	return byId
end

local function validateModifiers(source: string, modifiers: { Types.StatModifier })
	for _, modifier in modifiers do
		if not VALID_STATS[modifier.stat] then
			error(`[Registry] stat desconocido "{tostring(modifier.stat)}" en {source}`)
		end
		if modifier.kind ~= "Add" and modifier.kind ~= "Multiply" then
			error(`[Registry] tipo de modificador inválido en {source}`)
		end
	end
end

local Weapons = indexById(weaponList, "Weapons")
local Enemies = indexById(enemyList, "Enemies")
local Upgrades = indexById(upgradeList, "Upgrades")

for _, weapon in weaponList do
	if weapon.MaxLevel < 1 then
		error(`[Registry] arma {weapon.Id} con MaxLevel inválido`)
	end
	for level, modifiers in weapon.Scaling do
		if level < 2 or level > weapon.MaxLevel then
			error(`[Registry] arma {weapon.Id} escala en nivel {level}, fuera de 2..{weapon.MaxLevel}`)
		end
		validateModifiers(weapon.Id, modifiers)
	end
	local base = weapon.BaseStats
	if (base.Damage or 0) <= 0 or (base.AttackSpeed or 0) <= 0 then
		error(`[Registry] arma {weapon.Id} necesita Damage y AttackSpeed base`)
	end
end

for _, enemy in enemyList do
	if enemy.Health <= 0 or enemy.Speed <= 0 then
		error(`[Registry] enemigo {enemy.Id} con Health o Speed inválidos`)
	end
end

for _, upgrade in upgradeList do
	if upgrade.MaxLevel < 1 or upgrade.Weight <= 0 then
		error(`[Registry] mejora {upgrade.Id} con MaxLevel o Weight inválidos`)
	end
	if not Rarity.BaseWeight[upgrade.Rarity] then
		error(`[Registry] mejora {upgrade.Id} con rareza desconocida {tostring(upgrade.Rarity)}`)
	end
	if upgrade.TargetId and not Weapons[upgrade.TargetId] then
		error(`[Registry] mejora {upgrade.Id} apunta al arma inexistente {upgrade.TargetId}`)
	end
	if upgrade.Kind == "NewWeapon" and not upgrade.Requires then
		error(`[Registry] mejora {upgrade.Id} de tipo NewWeapon necesita Requires`)
	end
	validateModifiers(upgrade.Id, upgrade.Modifiers)
end

-- Un arma que ni es la inicial ni tiene una carta que la desbloquee es contenido
-- muerto: existe en el registro pero nunca puede aparecer en una partida.
local unlockable: { [string]: boolean } = { [STARTING_WEAPON_ID] = true }
for _, upgrade in upgradeList do
	if upgrade.Kind == "NewWeapon" and upgrade.TargetId then
		unlockable[upgrade.TargetId] = true
	end
end
for _, weapon in weaponList do
	if not unlockable[weapon.Id] then
		error(`[Registry] el arma {weapon.Id} no tiene mejora que la desbloquee`)
	end
end

return {
	Weapons = Weapons,
	Enemies = Enemies,
	Upgrades = Upgrades,
	StartingWeaponId = STARTING_WEAPON_ID,
}
