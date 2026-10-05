--!strict

local definition = {
	Id = "orbit_unlock",
	Kind = "NewWeapon",
	Rarity = "Rare",
	Name = "Cuchillas",
	Description = "Nueva arma: cuchillas orbitando que cortan por contacto.",
	Icon = "🗡",
	MaxLevel = 1,
	Weight = 40,
	TargetId = "orbit",
	Modifiers = {},
	Requires = function(run)
		return (run.weaponLevels.orbit or 0) < 1
	end,
}

return definition
