--!strict
-- Tipos compartidos entre servidor y cliente.
-- Regla: este módulo no toca la API de Roblox, para que los módulos puros que lo
-- consumen (definiciones, progresión, rareza) se puedan probar fuera de Studio.

export type StatKey =
	| "MaxHealth"
	| "Armor"
	| "MoveSpeed"
	| "Damage"
	| "AttackSpeed"
	| "CriticalChance"
	| "CriticalDamage"
	| "Range"
	| "ProjectileSpeed"
	| "ProjectileCount"
	| "Pellets"
	| "Spread"
	| "PickupRadius"
	| "XPModifier"
	| "Luck"
	| "Radius"
	| "BlastRadius"
	| "Arc"
	| "ChainCount"
	| "ChainRange"
	| "ChainFalloff"
	| "BladeCount"
	| "OrbitRadius"
	| "OrbitSpeed"
	| "HitCooldown"

-- "Add" suma el valor, "Multiply" escala el acumulado. Se aplican en ese orden
-- sobre el bloque base para que el resultado sea intuitivo de leer.
export type ModifierKind = "Add" | "Multiply"

export type StatModifier = {
	stat: StatKey,
	kind: ModifierKind,
	value: number,
	source: string,
	-- Duración en segundos. nil = permanente durante la partida.
	duration: number?,
}

export type StatBlock = { [StatKey]: number }

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

-- Identificador de comportamiento de ataque. Un comportamiento nuevo se registra
-- en Server/Combat/WeaponBehaviors.luau sin tocar WeaponRuntime ni las definiciones.
export type WeaponBehaviorId = "Projectile" | "Nova" | "Chain" | "Bomb" | "Orbit"

export type WeaponDefinition = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	MaxLevel: number,
	Behavior: WeaponBehaviorId,
	BaseStats: StatBlock,
	-- Clave = nivel mínimo en el que se aplican sus modificadores.
	Scaling: { [number]: { StatModifier } },
	Tags: { string },
	-- false = el arma no necesita un enemigo al que apuntar, así que WeaponRuntime se
	-- ahorra la búsqueda del objetivo más cercano. Por defecto true.
	RequiresTarget: boolean?,
}

export type EnemyAttackType = "Contact" | "Projectile" | "None"

export type EnemyDefinition = {
	Id: string,
	Name: string,
	Health: number,
	Speed: number,
	Damage: number,
	AttackInterval: number,
	AttackRange: number,
	XPReward: number,
	Size: number,
	AttackType: EnemyAttackType,
	Tags: { string },
}

export type UpgradeKind = "NewWeapon" | "WeaponUpgrade" | "Stat" | "Passive"

-- Vista de la partida que las definiciones consultan para requisitos y evolución.
export type RunView = {
	level: number,
	weaponLevels: { [string]: number },
	upgradeLevels: { [string]: number },
}

export type UpgradeDefinition = {
	Id: string,
	Kind: UpgradeKind,
	Rarity: Rarity,
	Name: string,
	Description: string,
	Icon: string,
	MaxLevel: number,
	Weight: number,
	-- Arma a la que aplica: "NewWeapon" y "WeaponUpgrade" lo requieren.
	TargetId: string?,
	Modifiers: { StatModifier },
	-- Punto de extensión para evoluciones: sin requisitos devuelve nil.
	Requires: ((run: RunView) -> boolean)?,
}

-- Payload que el cliente pinta en las cartas de subida de nivel.
export type UpgradeOffer = {
	Id: string,
	Kind: UpgradeKind,
	Rarity: Rarity,
	Name: string,
	Description: string,
	Icon: string,
	TargetId: string?,
	CurrentLevel: number,
	NextLevel: number,
	MaxLevel: number,
}

export type WeaponView = {
	Id: string,
	Name: string,
	Icon: string,
	Level: number,
	MaxLevel: number,
}

export type PassiveView = {
	Id: string,
	Name: string,
	Icon: string,
	Level: number,
	MaxLevel: number,
}

export type BuffView = {
	Name: string,
	Remaining: number,
}

export type RunSnapshot = {
	State: MatchState,
	Elapsed: number,
	Health: number,
	MaxHealth: number,
	Level: number,
	XP: number,
	XPToNext: number,
	Weapons: { WeaponView },
	Passives: { PassiveView },
	Buffs: { BuffView },
	MoveSpeed: number,
	PickupRadius: number,
}

export type MatchState =
	"Lobby"
	| "Starting"
	| "Playing"
	| "LevelUp"
	| "Event"
	| "Boss"
	| "MissionSelect"
	| "Victory"
	| "Defeat"

-- Un mapa es geometría + puntos de interés declarados con números planos, para que
-- el registro de contenido se pueda validar headless (sin la API de Roblox).
export type MapDefinition = {
	Id: string,
	DisplayName: string,
	Description: string?,
	Arena: { HalfExtent: number, FloorY: number },
	PlayerSpawn: { X: number, Y: number, Z: number },
	SpawnZones: { { Name: string, X: number, Y: number, Z: number, Radius: number } },
}

export type MissionObjectiveType = "Survive" | "KillEnemy" | "KillElite" | "DefeatBoss"

export type MissionObjective = {
	Type: MissionObjectiveType,
	Duration: number?,
	TargetId: string?,
	Amount: number?,
}

export type MissionState =
	"Locked"
	| "Available"
	| "Preparing"
	| "Active"
	| "Completing"
	| "Completed"
	| "Failed"

export type EnemyConfiguration = {
	[string]: { Enabled: boolean, Weight: number },
}

-- Global difficulty traits specific to a mission. The Spawner uses them.
export type MissionDifficulty = {
	EnemyHealthMultiplier: number,
	EnemyDamageMultiplier: number,
	EnemySpawnRateMultiplier: number,
	EliteChance: number?,
}

export type MissionRewards = {
	Currency: number,
	MissionUnlocks: { string },
	MapUnlocks: { string },
}

export type MissionDefinition = {
	Id: string,
	MapId: string,
	DisplayName: string,
	Description: string,
	Duration: number,
	Objectives: { MissionObjective },
	EnemyConfiguration: EnemyConfiguration,
	Boss: { Id: string, SpawnAt: number? }?,
	Rewards: MissionRewards,
	DifficultyMultipliers: MissionDifficulty,
}

export type MapDefinitions = { [string]: MapDefinition }
export type MissionDefinitions = { [string]: MissionDefinition }

-- Vista de un objetivo concreto durante una misión. `Required` es siempre el total
-- normalizado (1 para objetivos booleanos como derrotar al jefe), para que la UI no
-- tenga que conocer la forma de cada tipo de objetivo.
export type MissionObjectiveState = {
	Type: MissionObjectiveType,
	Label: string,
	Current: number,
	Required: number,
	Complete: boolean,
}

export type MissionBossView = {
	Id: string,
	Name: string,
	Active: boolean,
	Health: number,
	MaxHealth: number,
}

-- Instantánea autoritativa que el servidor envía al cliente mientras hay misión.
export type MissionSnapshot = {
	MissionId: string,
	DisplayName: string,
	MapId: string,
	State: MissionState,
	Elapsed: number,
	Remaining: number?,
	Objectives: { MissionObjectiveState },
	Boss: MissionBossView?,
}

-- Resumen de misión para el panel de selección (estado por jugador incluido).
export type MissionSummary = {
	Id: string,
	MapId: string,
	MapName: string,
	DisplayName: string,
	Description: string,
	Duration: number,
	State: MissionState,
	Objectives: { { Type: MissionObjectiveType, Label: string, Required: number } },
	Rewards: { Currency: number, Missions: { string }, Maps: { string } },
}

export type MissionResult = {
	MissionId: string,
	DisplayName: string,
	Outcome: "Completed" | "Failed",
	Duration: number,
	BossDefeated: boolean,
	Currency: number,
	UnlockedMissions: { string },
	UnlockedMaps: { string },
}

-- Este módulo solo exporta tipos. La tabla vacía evita que el require devuelva nil y
-- que el analizador de Studio marque los usos `Types.Algo` como acceso a nil.
return {}
