--!strict

local definition = {
	Id = "orbit_damage",
	Kind = "WeaponUpgrade",
	Rarity = "Common",
	Name = "Filo Afilado",
	Description = "Cada nivel añade daño plano y una cuchilla más.",
	Icon = "🗡",
	MaxLevel = 5,
	Weight = 90,
	TargetId = "orbit",
	Modifiers = {
		{ stat = "Damage", kind = "Add", value = 2.5, source = "orbit_damage" },
		{ stat = "BladeCount", kind = "Add", value = 0.5, source = "orbit_damage" },
	},
}

return definition
