--!strict

local definition = {
	Id = "bomb_unlock",
	Kind = "NewWeapon",
	Rarity = "Epic",
	Name = "Meteorito",
	Description = "Nueva arma: bombas que caen y estallan en área.",
	Icon = "☄️",
	MaxLevel = 1,
	Weight = 30,
	TargetId = "bomb",
	Modifiers = {},
	Requires = function(run)
		return (run.weaponLevels.bomb or 0) < 1
	end,
}

return definition
