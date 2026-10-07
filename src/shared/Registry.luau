--!strict
-- Registro de contenido: indexa y valida las definiciones de armas, enemigos y
-- mejoras. Servidor y cliente cargan este mismo registro, así que un error de
-- contenido (id duplicado, stat inexistente, rareza inválida) revienta al cargar en
-- los dos lados, en lugar de aparecer a mitad de una partida.
-- Import dual (ver StatMath.luau): el módulo vecino se resuelve por `script` en Roblox y
-- por ruta relativa en las pruebas headless con Lune.
local Types = require(script and script.Parent.Types or "./Types")
local Rarity = require(script and script.Parent.Rarity or "./Rarity")
local MapList = require(script and script.Parent.Definitions.Maps or "./Definitions/Maps")
local MissionList = require(script and script.Parent.Definitions.Missions or "./Definitions/Missions")

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
	require(script and script.Parent.Definitions.Enemies.Fast or "./Definitions/Enemies/Fast"),
	require(script and script.Parent.Definitions.Enemies.Tank or "./Definitions/Enemies/Tank"),
	require(script and script.Parent.Definitions.Enemies.Elite or "./Definitions/Enemies/Elite"),
	require(
		script and script.Parent.Definitions.Enemies.MineGuardian or "./Definitions/Enemies/MineGuardian"
	),
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

local VALID_UPGRADE_KINDS: { [string]: boolean } = {
	NewWeapon = true,
	WeaponUpgrade = true,
	Stat = true,
	Passive = true,
}

local VALID_BEHAVIORS: { [string]: boolean } = {
	Projectile = true,
	Nova = true,
	Chain = true,
	Bomb = true,
	Orbit = true,
}

local VALID_OBJECTIVE_TYPES: { [string]: boolean } = {
	Survive = true,
	KillEnemy = true,
	KillElite = true,
	DefeatBoss = true,
}

local Weapons = indexById(weaponList, "Weapons")
local Enemies = indexById(enemyList, "Enemies")
local Upgrades = indexById(upgradeList, "Upgrades")

-- Mapas y misiones se indexan desde diccionarios ya claveados por id. La clave y
-- `Id` deben coincidir; si no, el contenido se busca por una y se encuentra por otra.
local Maps: { [string]: Types.MapDefinition } = {}
for id, map in MapList do
	if Maps[id] then
		error(`[Registry] id duplicado en Maps: {id}`)
	end
	if map.Id ~= id then
		error(`[Registry] el mapa {id} declara Id "{map.Id}"`)
	end
	if map.Arena.HalfExtent <= 0 or map.Arena.FloorY ~= map.Arena.FloorY then
		error(`[Registry] el mapa {id} tiene un arena inválido`)
	end
	if #map.SpawnZones == 0 then
		error(`[Registry] el mapa {id} no declara ninguna zona de spawn`)
	end
	Maps[id] = map
end

local Missions: { [string]: Types.MissionDefinition } = {}
for id, mission in MissionList do
	if Missions[id] then
		error(`[Registry] id duplicado en Missions: {id}`)
	end
	if mission.Id ~= id then
		error(`[Registry] la misión {id} declara Id "{mission.Id}"`)
	end
	if mission.Duration < 0 then
		error(`[Registry] la misión {id} tiene Duration negativa`)
	end
	if #mission.Objectives == 0 then
		error(`[Registry] la misión {id} no declara objetivos`)
	end
	Missions[id] = mission
end

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
	if not VALID_BEHAVIORS[weapon.Behavior] then
		error(`[Registry] arma {weapon.Id} tiene un comportamiento desconocido {weapon.Behavior}`)
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
	if not VALID_UPGRADE_KINDS[upgrade.Kind] then
		error(`[Registry] mejora {upgrade.Id} con Kind inválido {tostring(upgrade.Kind)}`)
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

-- Validación cruzada de misiones: toda referencia (mapa, enemigo, jefe, desbloqueo)
-- tiene que existir. Un contenido roto revienta al cargar en servidor y cliente, no
-- a mitad de una partida.
for id, mission in Missions do
	if not Maps[mission.MapId] then
		error(`[Registry] la misión {id} apunta al mapa inexistente {mission.MapId}`)
	end

	for index, objective in mission.Objectives do
		if not VALID_OBJECTIVE_TYPES[objective.Type] then
			error(`[Registry] la misión {id} tiene un objetivo desconocido {tostring(objective.Type)}`)
		end
		if objective.Type == "Survive" then
			if (objective.Duration or 0) <= 0 then
				error(`[Registry] la misión {id} objetivo {index}: Survive necesita Duration > 0`)
			end
		elseif objective.Type == "KillEnemy" or objective.Type == "KillElite" then
			if (objective.Amount or 0) < 1 then
				error(`[Registry] la misión {id} objetivo {index}: {objective.Type} necesita Amount >= 1`)
			end
			if objective.Type == "KillEnemy" and objective.TargetId and not Enemies[objective.TargetId] then
				error(`[Registry] la misión {id} objetivo {index}: enemigo inexistente {objective.TargetId}`)
			end
		elseif objective.Type == "DefeatBoss" then
			local boss = objective.TargetId and Enemies[objective.TargetId]
			if not boss then
				error(`[Registry] la misión {id} objetivo {index}: jefe inexistente`)
			end
			if not table.find(boss.Tags, "boss") then
				error(`[Registry] la misión {id} objetivo {index}: {boss.Id} no está etiquetado como boss`)
			end
		end
	end

	for enemyId, entry in mission.EnemyConfiguration do
		if not Enemies[enemyId] then
			error(`[Registry] la misión {id} configura el enemigo inexistente {enemyId}`)
		end
		if typeof(entry.Enabled) ~= "boolean" or entry.Weight < 0 then
			error(`[Registry] la misión {id} tiene una entrada inválida para {enemyId}`)
		end
	end

	if mission.Boss then
		local boss = Enemies[mission.Boss.Id]
		if not boss or not table.find(boss.Tags, "boss") then
			error(`[Registry] la misión {id} invoca un jefe inexistente {mission.Boss.Id}`)
		end
		if (mission.Boss.SpawnAt or 0) < 0 then
			error(`[Registry] la misión {id} tiene un SpawnAt negativo`)
		end
	end

	for _, unlocked in mission.Rewards.MissionUnlocks do
		if not Missions[unlocked] then
			error(`[Registry] la misión {id} desbloquea la misión inexistente {unlocked}`)
		end
	end
	for _, unlocked in mission.Rewards.MapUnlocks do
		if not Maps[unlocked] then
			error(`[Registry] la misión {id} desbloquea el mapa inexistente {unlocked}`)
		end
	end
end

return {
	Weapons = Weapons,
	Enemies = Enemies,
	Upgrades = Upgrades,
	Maps = Maps,
	Missions = Missions,
	StartingWeaponId = STARTING_WEAPON_ID,
}
