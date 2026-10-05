--!strict

local definition = {
	Id = "shotgun_unlock",
	Kind = "NewWeapon",
	Rarity = "Rare",
	Name = "Breacher",
	Description = "Nueva arma: ráfaga de perdigones en cono.",
	Icon = "💥",
	MaxLevel = 1,
	Weight = 45,
	TargetId = "shotgun",
	Modifiers = {},
	-- Solo aparece si el jugador todavía no la tiene: evita ofrecer un duplicado.
	Requires = function(run)
		return (run.weaponLevels.shotgun or 0) < 1
	end,
}

return definition
