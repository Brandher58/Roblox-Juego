--!strict

local definition = {
	Id = "gun_haste",
	Kind = "WeaponUpgrade",
	Rarity = "Common",
	Name = "Rapid Cycling",
	Description = "Disparas un 12% más rápido con este arma.",
	Icon = "⚡",
	MaxLevel = 5,
	Weight = 90,
	TargetId = "gun",
	Modifiers = {
		{ stat = "AttackSpeed", kind = "Multiply", value = 1.12, source = "gun_haste" },
	},
}

return definition
