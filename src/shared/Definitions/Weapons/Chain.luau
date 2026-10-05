--!strict

local damageGrowth = {
	{ stat = "Damage", kind = "Add", value = 2.5, source = "chain_scaling" },
}

local levels = {
	[2] = damageGrowth,
	[3] = {
		{ stat = "Damage", kind = "Add", value = 2.5, source = "chain_scaling" },
		{ stat = "ChainCount", kind = "Add", value = 1, source = "chain_scaling" },
	},
	[4] = damageGrowth,
	[5] = {
		{ stat = "Damage", kind = "Add", value = 2.5, source = "chain_scaling" },
		{ stat = "ChainRange", kind = "Add", value = 3, source = "chain_scaling" },
	},
	[6] = damageGrowth,
	[7] = {
		{ stat = "Damage", kind = "Multiply", value = 1.2, source = "chain_scaling" },
		{ stat = "ChainCount", kind = "Add", value = 1, source = "chain_scaling" },
	},
	[8] = damageGrowth,
}

local definition = {
	Id = "chain",
	Name = "Relámpago",
	Description = "Golpea al enemigo más cercano y salta a los que estén alrededor.",
	Icon = "⚡",
	MaxLevel = 8,
	Behavior = "Chain",
	BaseStats = {
		Damage = 7,
		AttackSpeed = 1.3,
		Range = 40,
		ChainCount = 3,
		ChainRange = 20,
		ChainFalloff = 0.85,
		ProjectileSpeed = 1,
		ProjectileCount = 0,
	},
	Scaling = levels,
	Tags = { "chain", "area", "ranged" },
}

return definition
