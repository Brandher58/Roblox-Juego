--!strict

local pelletGrowth = {
	{ stat = "Damage", kind = "Add", value = 1.5, source = "shotgun_scaling" },
	{ stat = "Pellets", kind = "Add", value = 1, source = "shotgun_scaling" },
}

local levels = {
	[2] = pelletGrowth,
	[3] = pelletGrowth,
	[4] = {
		{ stat = "Damage", kind = "Add", value = 1.5, source = "shotgun_scaling" },
		{ stat = "Pellets", kind = "Add", value = 1, source = "shotgun_scaling" },
		{ stat = "AttackSpeed", kind = "Multiply", value = 1.08, source = "shotgun_scaling" },
	},
	[5] = pelletGrowth,
	[6] = pelletGrowth,
	[7] = {
		{ stat = "Damage", kind = "Multiply", value = 1.18, source = "shotgun_scaling" },
		{ stat = "Spread", kind = "Add", value = -4, source = "shotgun_scaling" },
	},
	[8] = pelletGrowth,
}

local definition = {
	Id = "shotgun",
	Name = "Breacher",
	Description = "Ráfaga de perdigones en cono a corta distancia.",
	Icon = "💥",
	MaxLevel = 8,
	Behavior = "Projectile",
	BaseStats = {
		Damage = 5,
		AttackSpeed = 1.1,
		Range = 32,
		ProjectileSpeed = 78,
		ProjectileCount = 1,
		Pellets = 6,
		Spread = 32,
	},
	Scaling = levels,
	Tags = { "projectile", "spread", "close" },
}

return definition
