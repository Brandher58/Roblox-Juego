--!strict

local definition = {
	Id = "nova_damage",
	Kind = "WeaponUpgrade",
	Rarity = "Common",
	Name = "Resonancia",
	Description = "Cada nivel añade daño plano y ensancha el pulso.",
	Icon = "🌊",
	MaxLevel = 5,
	Weight = 90,
	TargetId = "nova",
	Modifiers = {
		{ stat = "Damage", kind = "Add", value = 3, source = "nova_damage" },
		{ stat = "Radius", kind = "Add", value = 1.2, source = "nova_damage" },
		{ stat = "Range", kind = "Add", value = 1.2, source = "nova_damage" },
	},
}

return definition
