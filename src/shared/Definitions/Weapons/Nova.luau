--!strict

-- Range (cuándo se activa el pulso) y Radius (a quién golpea) se suben siempre juntos
-- en la misma clave: si se separaran, el arma empezaría a pulsar en el vacío.
local areaGrowth = {
	{ stat = "Radius", kind = "Add", value = 1.5, source = "nova_scaling" },
	{ stat = "Range", kind = "Add", value = 1.5, source = "nova_scaling" },
}

local damageGrowth = {
	{ stat = "Damage", kind = "Add", value = 2, source = "nova_scaling" },
}

local levels = {
	[2] = damageGrowth,
	[3] = areaGrowth,
	[4] = {
		{ stat = "Damage", kind = "Add", value = 2, source = "nova_scaling" },
		{ stat = "Radius", kind = "Add", value = 1.5, source = "nova_scaling" },
		{ stat = "Range", kind = "Add", value = 1.5, source = "nova_scaling" },
	},
	[5] = damageGrowth,
	[6] = {
		{ stat = "Damage", kind = "Add", value = 2, source = "nova_scaling" },
		{ stat = "AttackSpeed", kind = "Multiply", value = 1.12, source = "nova_scaling" },
	},
	[7] = areaGrowth,
	[8] = {
		{ stat = "Damage", kind = "Multiply", value = 1.25, source = "nova_scaling" },
		{ stat = "Radius", kind = "Add", value = 2, source = "nova_scaling" },
		{ stat = "Range", kind = "Add", value = 2, source = "nova_scaling" },
	},
}

local definition = {
	Id = "nova",
	Name = "Pulso Nova",
	Description = "Estalla a tu alrededor y daña a todo lo que tengas encima.",
	Icon = "🌊",
	MaxLevel = 8,
	Behavior = "Nova",
	BaseStats = {
		Damage = 8,
		AttackSpeed = 1.15,
		Range = 9,
		Radius = 9,
		ProjectileSpeed = 1,
		ProjectileCount = 0,
	},
	Scaling = levels,
	Tags = { "area", "self", "no_target" },
}

return definition
