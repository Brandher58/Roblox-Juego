--!strict

-- Definiciones de misiones. Cada misión es una configuración concreta de un mapa:
-- duración, objetivos, spawners, enemigos, boss, diff y rewards. No tiene lógica de
-- gameplay: el sistema central de misiones la interpreta.
local Missions: {
	[string]: {
		Id: string,
		MapId: string,
		DisplayName: string,
		Description: string,
		Duration: number,
		Objectives: {
			{
				Type: "Survive" | "KillEnemy" | "KillElite" | "DefeatBoss",
				Duration: number?,
				TargetId: string?,
				Amount: number?,
			}
		},
		EnemyConfiguration: { [string]: { Enabled: boolean, Weight: number } },
		Boss: { Id: string, SpawnAt: number? }?,
		Rewards: { Currency: number, MissionUnlocks: { string }, MapUnlocks: { string } },
		DifficultyMultipliers: {
			EnemyHealthMultiplier: number,
			EnemyDamageMultiplier: number,
			EnemySpawnRateMultiplier: number,
			EliteChance: number?,
		},
	},
} =
	{}

Missions["AbandonedMine_01"] = {
	Id = "AbandonedMine_01",
	MapId = "AbandonedMine",
	DisplayName = "First Descent",
	Description = "Sobrevive 5 minutos en la mina.",
	Duration = 300,
	Objectives = {
		{ Type = "Survive", Duration = 300 },
	},
	EnemyConfiguration = {
		basic = { Enabled = true, Weight = 80 },
		fast = { Enabled = true, Weight = 20 },
		tank = { Enabled = false, Weight = 0 },
		elite = { Enabled = false, Weight = 0 },
	},
	Boss = nil,
	Rewards = { Currency = 100, MissionUnlocks = { "AbandonedMine_02" }, MapUnlocks = {} },
	DifficultyMultipliers = {
		EnemyHealthMultiplier = 1,
		EnemyDamageMultiplier = 1,
		EnemySpawnRateMultiplier = 1,
		EliteChance = 0,
	},
}

Missions["AbandonedMine_02"] = {
	Id = "AbandonedMine_02",
	MapId = "AbandonedMine",
	DisplayName = "Something Is Down There",
	Description = "Sobrevive 6 minutos y elimina al menos un enemigo de élite.",
	Duration = 360,
	Objectives = {
		{ Type = "Survive", Duration = 360 },
		{ Type = "KillElite", Amount = 1 },
	},
	EnemyConfiguration = {
		basic = { Enabled = true, Weight = 70 },
		fast = { Enabled = true, Weight = 15 },
		tank = { Enabled = true, Weight = 10 },
		elite = { Enabled = true, Weight = 5 },
	},
	Boss = nil,
	Rewards = { Currency = 200, MissionUnlocks = { "AbandonedMine_03" }, MapUnlocks = {} },
	DifficultyMultipliers = {
		EnemyHealthMultiplier = 1.2,
		EnemyDamageMultiplier = 1.1,
		EnemySpawnRateMultiplier = 1.3,
		EliteChance = 0.15,
	},
}

Missions["AbandonedMine_03"] = {
	Id = "AbandonedMine_03",
	MapId = "AbandonedMine",
	DisplayName = "Deep Extraction",
	Description = "Sobrevive 8 minutos mientras aumentan las oleadas.",
	Duration = 480,
	Objectives = {
		{ Type = "Survive", Duration = 480 },
	},
	EnemyConfiguration = {
		basic = { Enabled = true, Weight = 55 },
		fast = { Enabled = true, Weight = 20 },
		tank = { Enabled = true, Weight = 15 },
		elite = { Enabled = true, Weight = 10 },
	},
	Boss = nil,
	Rewards = { Currency = 250, MissionUnlocks = { "AbandonedMine_Boss" }, MapUnlocks = {} },
	DifficultyMultipliers = {
		EnemyHealthMultiplier = 1.4,
		EnemyDamageMultiplier = 1.2,
		EnemySpawnRateMultiplier = 1.4,
		EliteChance = 0.25,
	},
}

Missions["AbandonedMine_Boss"] = {
	Id = "AbandonedMine_Boss",
	MapId = "AbandonedMine",
	DisplayName = "Guardian of the Mine",
	Description = "Sobrevive las oleadas de apertura y derrota al MineGuardian.",
	Duration = 0,
	Objectives = {
		{ Type = "Survive", Duration = 60 },
		{ Type = "DefeatBoss", TargetId = "mine_guardian" },
	},
	EnemyConfiguration = {
		basic = { Enabled = true, Weight = 60 },
		fast = { Enabled = true, Weight = 25 },
		tank = { Enabled = true, Weight = 10 },
		elite = { Enabled = true, Weight = 5 },
	},
	Boss = { Id = "mine_guardian", SpawnAt = 60 },
	Rewards = { Currency = 500, MissionUnlocks = {}, MapUnlocks = { "AbandonedFactory" } },
	DifficultyMultipliers = {
		EnemyHealthMultiplier = 1.5,
		EnemyDamageMultiplier = 1.3,
		EnemySpawnRateMultiplier = 1.5,
		EliteChance = 0.2,
	},
}

return Missions
