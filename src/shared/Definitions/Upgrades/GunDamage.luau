--!strict

local definition = {
	Id = "gun_damage",
	Kind = "WeaponUpgrade",
	Rarity = "Common",
	Name = "Overcharged Coils",
	Description = "Cada nivel añade daño plano al arma.",
	Icon = "💥",
	MaxLevel = 5,
	Weight = 100,
	TargetId = "gun",
	Modifiers = {
		{ stat = "Damage", kind = "Add", value = 3, source = "gun_damage" },
	},
}

return definition
