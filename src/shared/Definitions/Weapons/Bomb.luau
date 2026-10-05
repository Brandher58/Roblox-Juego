--!strict

local blastGrowth = {
	{ stat = "Damage", kind = "Add", value = 5, source = "bomb_scaling" },
	{ stat = "BlastRadius", kind = "Add", value = 1.5, source = "bomb_scaling" },
}

local levels = {
	[2] = blastGrowth,
	[3] = {
		{ stat = "Damage", kind = "Add", value = 5, source = "bomb_scaling" },
		{ stat = "ProjectileCount", kind = "Add", value = 1, source = "bomb_scaling" },
	},
	[4] = blastGrowth,
	[5] = {
		{ stat = "Damage", kind = "Add", value = 5, source = "bomb_scaling" },
		{ stat = "BlastRadius", kind = "Add", value = 1.5, source = "bomb_scaling" },
		{ stat = "AttackSpeed", kind = "Multiply", value = 1.15, source = "bomb_scaling" },
	},
	[6] = blastGrowth,
	[7] = {
		{ stat = "Damage", kind = "Multiply", value = 1.2, source = "bomb_scaling" },
		{ stat = "BlastRadius", kind = "Add", value = 2, source = "bomb_scaling" },
	},
	[8] = blastGrowth,
}

local definition = {
	Id = "bomb",
	Name = "Meteorito",
	Description = "Lanza una bomba en parábola que estalla al tocar el suelo o al impacto.",
	Icon = "☄️",
	MaxLevel = 8,
	Behavior = "Bomb",
	BaseStats = {
		Damage = 15,
		AttackSpeed = 0.8,
		Range = 34,
		BlastRadius = 10,
		-- Elevación de la dirección de tiro: define hasta dónde sube antes de caer.
		Arc = 0.45,
		ProjectileSpeed = 44,
		ProjectileCount = 1,
	},
	Scaling = levels,
	Tags = { "area", "lobbed", "ranged" },
}

return definition
