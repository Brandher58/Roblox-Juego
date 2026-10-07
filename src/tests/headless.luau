--!strict
-- Pruebas headless de la lógica pura (sin Roblox). Se ejecutan con:
--   lune run src/tests/headless.luau
-- Cubren lo que no se puede comprobar a ojo: curvas, orden de modificadores y las
-- garantías anti-frustración del sorteo de mejoras.
local Progression = require("../shared/Progression")
local StatMath = require("../shared/StatMath")
local Rarity = require("../shared/Rarity")
local Registry = require("../shared/Registry")
local UpgradeOffers = require("../shared/UpgradeOffers")
local Fs = require("@lune/fs")

local failures = 0
local checks = 0

local function check(condition: boolean, message: string)
	checks += 1
	if not condition then
		failures += 1
		print(`FAIL: {message}`)
	end
end

local function near(actual: number, expected: number, tolerance: number, message: string)
	check(math.abs(actual - expected) <= tolerance, `{message} (esperado {expected}, obtenido {actual})`)
end

-- Generador determinista: LCG, para que un fallo siempre se pueda reproducir.
local function seeded(seed: number): () -> number
	local state = seed
	return function()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
end

do
	-- PROGRESION
	local previous = 0
	for level = 1, 25 do
		local needed = Progression.xpForNext(level)
		check(needed > previous, `xpForNext({level}) debe crecer`)
		previous = needed
	end
	check(Progression.xpForNext(1) == 6, "el primer nivel cuesta 6 XP")

	local level, xp, gained = Progression.addXp(1, 0, Progression.xpForNext(1))
	check(level == 2 and xp == 0 and gained == 1, "justo el XP de un nivel sube exactamente un nivel")

	level, xp, gained = Progression.addXp(1, 0, 1000)
	check(gained > 1, "una gota grande puede dar varios niveles")
	check(xp < Progression.xpForNext(level), "la XP sobrante queda dentro del nivel actual")

	level, xp = Progression.addXp(1, 0, 0)
	check(level == 1 and xp == 0, "XP cero o negativa no progresa")
end

do
	-- STATMATH: los Add se resuelven antes que los Multiply y el orden no importa
	local base = { Damage = 10, MaxHealth = 100 }
	local a = StatMath.resolve(base, {
		{ stat = "Damage", kind = "Multiply", value = 2, source = "x", duration = nil },
		{ stat = "Damage", kind = "Add", value = 5, source = "y", duration = nil },
	})
	local b = StatMath.resolve(base, {
		{ stat = "Damage", kind = "Add", value = 5, source = "y", duration = nil },
		{ stat = "Damage", kind = "Multiply", value = 2, source = "x", duration = nil },
	})
	near(a.Damage, 30, 0.0001, "(10 + 5) * 2 = 30")
	check(a.Damage == b.Damage, "el resultado no depende del orden de los modificadores")
	check(base.Damage == 10, "resolve no muta el bloque base")

	-- STATMATH: pipeline de arma (base + scaling + mejoras x multiplicadores globales)
	local weapon = {
		Id = "test",
		Name = "Test",
		Description = "",
		Icon = "",
		MaxLevel = 4,
		Behavior = "Projectile",
		BaseStats = { Damage = 10, AttackSpeed = 1, ProjectileCount = 1, Pellets = 1, Spread = 0 },
		Scaling = {
			[2] = { { stat = "Damage", kind = "Add", value = 5, source = "s" } },
			[3] = {
				{ stat = "Damage", kind = "Add", value = 5, source = "s" },
				{ stat = "Pellets", kind = "Add", value = 1, source = "s" },
			},
		},
		Tags = {},
	}

	local level1 = StatMath.weapon(weapon, 1, {}, { Damage = 1, AttackSpeed = 1 })
	near(level1.Damage, 10, 0.0001, "nivel 1 sin scaling")

	local level3 = StatMath.weapon(weapon, 3, {}, { Damage = 1, AttackSpeed = 1 })
	near(level3.Damage, 20, 0.0001, "nivel 3 acumula el scaling de los niveles 2 y 3")
	near(level3.Pellets, 2, 0.0001, "el scaling también suma perdigones")

	local upgraded = StatMath.weapon(
		weapon,
		1,
		{ { stat = "Damage", kind = "Add", value = 7, source = "u" } },
		{ Damage = 1, AttackSpeed = 1 }
	)
	near(upgraded.Damage, 17, 0.0001, "una mejora de arma suma sobre la base")

	local global = StatMath.weapon(weapon, 1, {}, { Damage = 2, ProjectileCount = 2 })
	near(global.Damage, 20, 0.0001, "el multiplicador global de daño escala el arma")
	near(global.ProjectileCount, 3, 0.0001, "ProjectileCount global es aditivo")
end

do
	-- RARITY: la curva base es Mayoritaria y Luck desplaza peso hacia arriba
	local rand = seeded(20260905)
	local counts: { [string]: number } = {}
	local total = 20000
	for _ = 1, total do
		local rarity = Rarity.roll(rand, 1)
		counts[rarity] = (counts[rarity] or 0) + 1
	end
	check((counts.Common or 0) > (counts.Legendary or 0), "Common sale mas que Legendary")
	check((counts.Common or 0) / total > 0.4, "Common domina con Luck 1")

	local lowHigh = 0
	local highHigh = 0
	for _ = 1, total do
		local rarity = Rarity.roll(rand, 1)
		if rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" then
			lowHigh += 1
		end
	end
	for _ = 1, total do
		local rarity = Rarity.roll(rand, 3)
		if rarity == "Rare" or rarity == "Epic" or rarity == "Legendary" then
			highHigh += 1
		end
	end
	check(highHigh > lowHigh, "Luck alto reparte mas rarezas altas")
	near(
		Rarity.weightOf("Common", 3),
		Rarity.weightOf("Common", 1),
		0.0001,
		"Luck no cambia el peso de Common"
	)
	near(
		Rarity.weightOf("Rare", 2),
		Rarity.BaseWeight.Rare * 4,
		0.0001,
		"Luck escala al cuadrado en Rare (indice 2) y no en Common"
	)
end

do
	-- UPGRADEOFFERS: garantias anti-frustracion
	local rand = seeded(7)
	for iteration = 1, 200 do
		local offers = UpgradeOffers.generate({
			level = iteration,
			weaponLevels = { gun = 1 },
			upgradeLevels = {},
		}, 1, rand)

		check(#offers == 3, `una subida de nivel ofrece 3 cartas (iteracion {iteration})`)

		local seen: { [string]: boolean } = {}
		local hasNewWeapon = false
		local hasOwnedUpgrade = false
		for _, offer in offers do
			check(not seen[offer.Id], `no se repite la carta {offer.Id}`)
			seen[offer.Id] = true
			check(offer.Name ~= "" and offer.Description ~= "", "la carta trae nombre y descripcion")
			if offer.Kind == "NewWeapon" then
				hasNewWeapon = true
			end
			if offer.Kind == "WeaponUpgrade" and offer.TargetId == "gun" then
				hasOwnedUpgrade = true
			end
		end
		check(hasNewWeapon, "con una sola arma siempre se ofrece un arma nueva")
		check(hasOwnedUpgrade, "siempre hay una mejora del arma que ya llevas")
	end

	-- Con dos armas ya no se fuerza el arma nueva, y una mejora al maximo desaparece.
	local offers = UpgradeOffers.generate({
		level = 6,
		weaponLevels = { gun = 3, shotgun = 2 },
		upgradeLevels = { vitality = 5, gun_damage = 5, gun_haste = 2, shotgun_damage = 1 },
	}, 1, rand)
	local ids: { [string]: boolean } = {}
	for _, offer in offers do
		check(not ids[offer.Id], "sin duplicados")
		ids[offer.Id] = true
		check(offer.Id ~= "vitality" and offer.Id ~= "gun_damage", "no ofrece mejoras al maximo")
		check(offer.Id ~= "shotgun_unlock", "no ofrece un arma que ya se tiene")
	end

	-- Con todo al maximo no queda ninguna carta: el sistema no debe fallar. El estado
	-- se deriva del registro en vez de escribirse a mano, para que anadir armas y
	-- mejoras nuevas no rompa esta comprobacion.
	local maxedWeapons: { [string]: number } = {}
	local maxedUpgrades: { [string]: number } = {}
	for id, weapon in Registry.Weapons do
		maxedWeapons[id] = weapon.MaxLevel
	end
	for id, upgrade in Registry.Upgrades do
		maxedUpgrades[id] = upgrade.MaxLevel
	end

	local empty = UpgradeOffers.generate({
		level = 30,
		weaponLevels = maxedWeapons,
		upgradeLevels = maxedUpgrades,
	}, 1, rand)
	check(#empty == 0, "sin mejoras disponibles devuelve cero cartas en vez de fallar")

	-- Requisitos: un arma nueva deja de ser elegible en cuanto se posee.
	local afterUnlock = UpgradeOffers.generate({
		level = 4,
		weaponLevels = { gun = 1, shotgun = 1 },
		upgradeLevels = { shotgun_unlock = 1 },
	}, 1, rand)
	for _, offer in afterUnlock do
		check(offer.Id ~= "shotgun_unlock", "el requisito de la mejora de arma se respeta")
	end
end

do
	-- CONTENIDO DE ARMAS: las relaciones entre stats que sostienen a los comportamientos
	-- de area, cadena y contacto. El Registry ya revienta al cargar si un id, una
	-- rareza o una stat no cuadran; esto comprueba lo que el Registry no puede ver: que
	-- las stats que dependen entre si siguen siendo coherentes en todos los niveles.
	local NEUTRAL: { [string]: number } = {
		Damage = 1,
		AttackSpeed = 1,
		Range = 1,
		ProjectileSpeed = 1,
		ProjectileCount = 0,
	}

	local function statsAt(weaponId: string, level: number)
		return StatMath.weapon(Registry.Weapons[weaponId], level, {}, NEUTRAL)
	end

	-- El pulso decide si se dispara por Range y golpea por Radius: si se separaran,
	-- el arma empezaria a pulsar en el vacio.
	for level = 1, Registry.Weapons.nova.MaxLevel do
		local stats = statsAt("nova", level)
		check(stats.Range == stats.Radius, `nova nivel {level}: Range y Radius siguen siendo iguales`)
		check(stats.Radius > 0, `nova nivel {level}: el radio es positivo`)
	end

	-- Ningun arma se queda plana: subir de nivel tiene que notarse en el daño.
	for weaponId, weapon in Registry.Weapons do
		local base = statsAt(weaponId, 1)
		local top = statsAt(weaponId, weapon.MaxLevel)
		check(top.Damage > base.Damage, `{weaponId}: el daño crece de nivel 1 a nivel maximo`)
		check(base.Damage > 0, `{weaponId}: el daño base es positivo`)
		check((base.AttackSpeed or 0) > 0, `{weaponId}: la cadencia base es positiva`)
	end

	-- La cadena crece en saltos, nunca pierde potencia por salto y no se dispara en
	-- cadena infinita: con ChainFalloff <= 1 el total de daño es finito.
	for level = 1, Registry.Weapons.chain.MaxLevel do
		local stats = statsAt("chain", level)
		check(stats.ChainCount >= 1, `chain nivel {level}: hay al menos un salto`)
		check(
			stats.ChainFalloff > 0 and stats.ChainFalloff <= 1,
			`chain nivel {level}: la caida por salto es valida`
		)
		check(stats.ChainRange > 0, `chain nivel {level}: el alcance del salto es positivo`)
	end
	check(
		statsAt("chain", Registry.Weapons.chain.MaxLevel).ChainCount > statsAt("chain", 1).ChainCount,
		"chain: subir de nivel anade saltos"
	)

	-- La bomba lanza mas y mas lejos, y siempre con algo de arco.
	for level = 1, Registry.Weapons.bomb.MaxLevel do
		local stats = statsAt("bomb", level)
		check(stats.BlastRadius > 0, `bomb nivel {level}: la explosion tiene radio`)
		check(stats.Arc > 0, `bomb nivel {level}: la bomba describe un arco`)
	end
	check(
		statsAt("bomb", Registry.Weapons.bomb.MaxLevel).BlastRadius > statsAt("bomb", 1).BlastRadius,
		"bomb: subir de nivel ensancha la explosion"
	)

	-- Las cuchillas no dependen de un objetivo y siempre giran con algo alrededor.
	check(Registry.Weapons.orbit.RequiresTarget == false, "orbit no necesita un enemigo al que apuntar")
	for level = 1, Registry.Weapons.orbit.MaxLevel do
		local stats = statsAt("orbit", level)
		check(stats.BladeCount >= 1, `orbit nivel {level}: hay al menos una cuchilla`)
		check(stats.BladeCount <= 12, `orbit nivel {level}: las cuchillas no superan el tope del pool`)
		check(stats.OrbitRadius > 0, `orbit nivel {level}: el radio de orbita es positivo`)
		check(stats.OrbitSpeed > 0, `orbit nivel {level}: las cuchillas giran`)
		check(stats.HitCooldown >= 0.2, `orbit nivel {level}: el enfriamiento por enemigo no baja del suelo`)
	end
	check(
		statsAt("orbit", Registry.Weapons.orbit.MaxLevel).BladeCount > statsAt("orbit", 1).BladeCount,
		"orbit: subir de nivel anade cuchillas"
	)

	-- Toda arma nueva es alcanzable: el Registry lo exige al cargar, pero se comprueba
	-- aqui que las garantias anti-frustracion siguen pudiendo ofrecerla.
	local unlockable: { [string]: boolean } = { [Registry.StartingWeaponId] = true }
	for _, upgrade in Registry.Upgrades do
		if upgrade.Kind == "NewWeapon" and upgrade.TargetId then
			unlockable[upgrade.TargetId] = true
		end
	end
	for weaponId in Registry.Weapons do
		check(unlockable[weaponId] == true, `el arma {weaponId} tiene forma de desbloquearse`)
	end
end

do
	-- CONTENIDO DE MISIONES: el Registry ya valida referencias cruzadas al cargar;
	-- aquí se comprueba la forma del contenido que sostiene la progresión.
	local missionCount = 0
	for id, mission in Registry.Missions do
		missionCount += 1
		check(Registry.Maps[mission.MapId] ~= nil, `la misión {id} apunta a un mapa existente`)
		check(#mission.Objectives >= 1, `la misión {id} define al menos un objetivo`)
		check(mission.Rewards.Currency >= 0, `la misión {id} tiene recompensa válida`)
	end
	check(missionCount >= 4, `hay al menos 4 misiones definidas ({missionCount})`)

	local bossMission = Registry.Missions["AbandonedMine_Boss"]
	check(bossMission ~= nil, "existe la misión de jefe")
	if bossMission then
		check(
			bossMission.Boss ~= nil and Registry.Enemies[bossMission.Boss.Id] ~= nil,
			"la misión de jefe invoca un jefe existente"
		)
		local hasDefeatBoss = false
		for _, objective in bossMission.Objectives do
			if objective.Type == "DefeatBoss" then
				hasDefeatBoss = true
			end
		end
		check(hasDefeatBoss, "la misión de jefe exige derrotar al jefe")
		check(#bossMission.Rewards.MapUnlocks >= 1, "derrotar al jefe desbloquea un mapa")
	end
end

do
	-- OBJETIVOS: módulos puros, sin Roblox. Se prueban con un runtime sintético igual
	-- al que construye ObjectiveSystem en el servidor.
	local Survive = require("../server/Missions/Objectives/Survive")
	local KillEnemy = require("../server/Missions/Objectives/KillEnemy")
	local KillElite = require("../server/Missions/Objectives/KillElite")
	local DefeatBoss = require("../server/Missions/Objectives/DefeatBoss")

	local function make(module, definition)
		return {
			Definition = definition,
			Required = module.Required(definition),
			Current = 0,
			Complete = false,
		}
	end

	local surviveDef = { Type = "Survive", Duration = 5 }
	local survive = make(Survive, surviveDef)
	Survive.Update(survive, 2)
	check(
		not survive.Complete and survive.Current == 2,
		"Survive acumula tiempo pero no completa antes de tiempo"
	)
	Survive.Update(survive, 10)
	check(survive.Complete and survive.Current == survive.Required, "Survive completa y no se pasa del total")
	check(Survive.Label(surviveDef) ~= "", "Survive tiene etiqueta")

	local killEnemyDef = { Type = "KillEnemy", Amount = 2 }
	local killEnemy = make(KillEnemy, killEnemyDef)
	KillEnemy.HandleEvent(killEnemy, { Kind = "Kill", Enemy = { Id = "basic", Tags = {} } })
	check(killEnemy.Current == 1 and not killEnemy.Complete, "KillEnemy cuenta una baja")
	KillEnemy.HandleEvent(killEnemy, { Kind = "BossDefeated", BossId = "mine_guardian" })
	check(killEnemy.Current == 1, "KillEnemy ignora eventos que no son bajas")
	KillEnemy.HandleEvent(killEnemy, { Kind = "Kill", Enemy = { Id = "basic", Tags = {} } })
	check(killEnemy.Complete, "KillEnemy completa al llegar al total")

	local eliteDef = { Type = "KillElite", Amount = 1 }
	local elite = make(KillElite, eliteDef)
	KillElite.HandleEvent(elite, { Kind = "Kill", Enemy = { Id = "basic", Tags = {} } })
	check(not elite.Complete, "KillElite no cuenta enemigos normales")
	KillElite.HandleEvent(elite, { Kind = "Kill", Enemy = { Id = "elite", Tags = { "melee", "elite" } } })
	check(elite.Complete, "KillElite completa con una élite")

	local bossDef = { Type = "DefeatBoss", TargetId = "mine_guardian" }
	local boss = make(DefeatBoss, bossDef)
	DefeatBoss.HandleEvent(boss, { Kind = "Kill", Enemy = { Id = "basic", Tags = {} } })
	check(not boss.Complete, "DefeatBoss ignora a los enemigos normales")
	DefeatBoss.HandleEvent(boss, { Kind = "Kill", Enemy = { Id = "tank", Tags = { "boss" } } })
	check(not boss.Complete, "DefeatBoss ignora a otro jefe distinto de TargetId")
	DefeatBoss.HandleEvent(boss, { Kind = "Kill", Enemy = { Id = "mine_guardian", Tags = { "boss" } } })
	check(boss.Complete, "DefeatBoss completa al caer el jefe indicado")
end

do
	-- REQUIRES RELATIVOS
	-- En Roblox `script.Hermano` no existe: dentro de un ModuleScript, `script` es el
	-- propio modulo, asi que `script.SpatialGrid` busca un *hijo* del modulo y falla con
	-- "SpatialGrid is not a valid member of ...". El hermano es `script.Parent.SpatialGrid`,
	-- y desde una subcarpeta hace falta un `Parent` mas. Ni selene ni rojo build lo ven:
	-- solo revienta en un Play, y el mensaje parece un fallo de sincronizacion. Aqui se
	-- resuelven todos los requires relativos contra el arbol real de ficheros.
	local function collectLua(directory: string, out: { string })
		for _, name in Fs.readDir(directory) do
			local path = `{directory}/{name}`
			if Fs.isDir(path) then
				collectLua(path, out)
			elseif name:sub(-5) == ".luau" then
				table.insert(out, path)
			end
		end
	end

	-- Resuelve `script.A.B` desde la posicion del modulo, con `Parent` subiendo un nivel.
	local function resolve(from: { string }, segments: { string }): (boolean, string)
		local current = table.clone(from)
		for index, segment in segments do
			if segment == "Parent" then
				if #current == 0 then
					return false, "sube por encima de la raiz"
				end
				table.remove(current)
			else
				local candidate = table.clone(current)
				table.insert(candidate, segment)
				local asDirectory = table.concat(candidate, "/")
				local asModule = `{asDirectory}.luau`
				if Fs.isDir(asDirectory) then
					current = candidate
				elseif Fs.isFile(asModule) then
					if index < #segments then
						return false, "un ModuleScript no contiene instancias"
					end
					current = candidate
				else
					return false, `no existe {asDirectory}`
				end
			end
		end
		return true, ""
	end

	local sources: { string } = {}
	collectLua("src", sources)
	check(#sources > 20, "se han encontrado los modulos del proyecto")

	local pattern = "require%((script[%.%w_]+)%)"
	local resolved = 0
	for _, source in sources do
		local text = Fs.readFile(source)
		for capture in text:gmatch(pattern) do
			local segments = {}
			for segment in capture:gmatch("[^%.]+") do
				table.insert(segments, segment)
			end
			table.remove(segments, 1) -- el propio `script`

			local position = {}
			for piece in source:gmatch("[^/]+") do
				table.insert(position, piece)
			end
			position[#position] = position[#position]:sub(1, -6) -- sin la extension .luau

			local ok, reason = resolve(position, segments)
			check(ok, `require({capture}) en {source}: {reason}`)
			if ok then
				resolved += 1
			end
		end
	end
	check(resolved >= 56, `se han resuelto los requires relativos del proyecto ({resolved})`)
end

print(`{checks - failures}/{checks} comprobaciones correctas`)
if failures > 0 then
	error(`{failures} comprobaciones fallidas`)
end
