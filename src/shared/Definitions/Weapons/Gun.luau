--!strict

local damageGrowth = {
	{ stat = "Damage", kind = "Add", value = 3, source = "gun_scaling" },
}

local levels = {
	[2] = damageGrowth,
	[3] = damageGrowth,
	[4] = {
		{ stat = "Damage", kind = "Add", value = 3, source = "gun_scaling" },
		{ stat = "ProjectileCount", kind = "Add", value = 1, source = "gun_scaling" },
	},
	[5] = damageGrowth,
	[6] = {
		{ stat = "Damage", kind = "Add", value = 3, source = "gun_scaling" },
		{ stat = "AttackSpeed", kind = "Multiply", value = 1.12, source = "gun_scaling" },
	},
	[7] = damageGrowth,
	[8] = {
		{ stat = "Damage", kind = "Multiply", value = 1.25, source = "gun_scaling" },
		{ stat = "AttackSpeed", kind = "Multiply", value = 1.1, source = "gun_scaling" },
	},
}

local definition = {
	Id = "gun",
	Name = "Pulse Gun",
	Description = "Dispara automáticamente al enemigo válido más cercano.",
	Icon = "🔫",
	MaxLevel = 8,
	Behavior = "Projectile",
	BaseStats = {
		Damage = 11,
		AttackSpeed = 1.7,
		Range = 55,
		ProjectileSpeed = 95,
		ProjectileCount = 1,
		Pellets = 1,
		Spread = 0,
	},
	Scaling = levels,
	Tags = { "projectile", "starting" },
}

return definition
