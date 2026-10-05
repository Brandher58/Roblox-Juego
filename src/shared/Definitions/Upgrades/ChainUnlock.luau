--!strict

local definition = {
	Id = "chain_unlock",
	Kind = "NewWeapon",
	Rarity = "Rare",
	Name = "Relámpago",
	Description = "Nueva arma: el relámpago salta entre enemigos.",
	Icon = "⚡",
	MaxLevel = 1,
	Weight = 40,
	TargetId = "chain",
	Modifiers = {},
	-- Solo aparece si el jugador todavia no la tiene: evita ofrecer un duplicado.
	Requires = function(run)
		return (run.weaponLevels.chain or 0) < 1
	end,
}

return definition
