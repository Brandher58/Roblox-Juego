--!strict

local definition = {
	Id = "chain_damage",
	Kind = "WeaponUpgrade",
	Rarity = "Common",
	Name = "Conductores",
	Description = "Cada nivel añade daño plano y un salto más de cadena.",
	Icon = "⚡",
	MaxLevel = 5,
	Weight = 90,
	TargetId = "chain",
	Modifiers = {
		{ stat = "Damage", kind = "Add", value = 3, source = "chain_damage" },
		{ stat = "ChainCount", kind = "Add", value = 0.5, source = "chain_damage" },
	},
}

return definition
