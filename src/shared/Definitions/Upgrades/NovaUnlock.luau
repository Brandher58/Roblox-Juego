--!strict

local definition = {
	Id = "nova_unlock",
	Kind = "NewWeapon",
	Rarity = "Rare",
	Name = "Pulso Nova",
	Description = "Nueva arma: una onda de daño a tu alrededor.",
	Icon = "🌊",
	MaxLevel = 1,
	Weight = 40,
	TargetId = "nova",
	Modifiers = {},
	Requires = function(run)
		return (run.weaponLevels.nova or 0) < 1
	end,
}

return definition
