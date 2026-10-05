--!strict

local definition = {
	Id = "shotgun_damage",
	Kind = "WeaponUpgrade",
	Rarity = "Uncommon",
	Name = "Breach Rounds",
	Description = "+1.5 de daño por perdigón y un perdigón extra.",
	Icon = "🎯",
	MaxLevel = 5,
	Weight = 80,
	TargetId = "shotgun",
	Modifiers = {
		{ stat = "Damage", kind = "Add", value = 1.5, source = "shotgun_damage" },
		{ stat = "Pellets", kind = "Add", value = 1, source = "shotgun_damage" },
	},
}

return definition
