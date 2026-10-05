--!strict

local definition = {
	Id = "bomb_damage",
	Kind = "WeaponUpgrade",
	Rarity = "Uncommon",
	Name = "Carga Extra",
	Description = "Cada nivel añade daño plano y ensancha la explosión.",
	Icon = "💣",
	MaxLevel = 5,
	Weight = 90,
	TargetId = "bomb",
	Modifiers = {
		{ stat = "Damage", kind = "Add", value = 6, source = "bomb_damage" },
		{ stat = "BlastRadius", kind = "Add", value = 1.5, source = "bomb_damage" },
	},
}

return definition
