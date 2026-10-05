--!strict

-- El único arma que no dispara por cadencia: son piezas persistentes que giran y
-- muelen por contacto. Por eso no necesita un enemigo al que apuntar, y por eso
-- AttackSpeed es la frecuencia con la que se refrescan sus parámetros, no un
-- intervalo de daño (ese ritmo lo lleva HitCooldown, por enemigo).
local bladeGrowth = {
	{ stat = "Damage", kind = "Add", value = 2, source = "orbit_scaling" },
}

local levels = {
	[2] = bladeGrowth,
	[3] = {
		{ stat = "Damage", kind = "Add", value = 2, source = "orbit_scaling" },
		{ stat = "BladeCount", kind = "Add", value = 1, source = "orbit_scaling" },
	},
	[4] = bladeGrowth,
	[5] = {
		{ stat = "Damage", kind = "Add", value = 2, source = "orbit_scaling" },
		{ stat = "BladeCount", kind = "Add", value = 1, source = "orbit_scaling" },
		{ stat = "OrbitSpeed", kind = "Multiply", value = 1.15, source = "orbit_scaling" },
	},
	[6] = bladeGrowth,
	[7] = {
		{ stat = "Damage", kind = "Multiply", value = 1.2, source = "orbit_scaling" },
		{ stat = "HitCooldown", kind = "Multiply", value = 0.85, source = "orbit_scaling" },
	},
	[8] = bladeGrowth,
}

local definition = {
	Id = "orbit",
	Name = "Cuchillas",
	Description = "Cuchillas orbitando: cortan por contacto una y otra vez.",
	Icon = "🗡",
	MaxLevel = 8,
	Behavior = "Orbit",
	BaseStats = {
		Damage = 6,
		AttackSpeed = 2,
		BladeCount = 2,
		OrbitRadius = 6.5,
		OrbitSpeed = 2.6,
		HitCooldown = 0.45,
	},
	RequiresTarget = false,
	Scaling = levels,
	Tags = { "orbit", "contact", "no_target" },
}

return definition
