--!strict

local definition = {
	Id = "vitality",
	Kind = "Stat",
	Rarity = "Common",
	Name = "Field Plating",
	Description = "+25 de salud máxima.",
	Icon = "❤️",
	MaxLevel = 5,
	Weight = 85,
	Modifiers = {
		{ stat = "MaxHealth", kind = "Add", value = 25, source = "vitality" },
	},
}

return definition
