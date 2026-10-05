--!strict
-- Rareza de las mejoras. El peso base sigue la curva estándar 55/27/12/5/1; la
-- estadística Luck multiplica el peso de las rarezas altas, de modo que un jugador
-- con Luck = 2 ve casi el doble de Rare y el doble de Legendario.
local Rarity = {}

export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

Rarity.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

Rarity.BaseWeight = {
	Common = 55,
	Uncommon = 27,
	Rare = 12,
	Epic = 5,
	Legendary = 1,
}

function Rarity.indexOf(rarity: RarityId): number
	for index, id in Rarity.Order do
		if id == rarity then
			return index - 1
		end
	end
	error(`[Rarity] rareza desconocida: {tostring(rarity)}`)
end

function Rarity.weightOf(rarity: RarityId, luck: number): number
	local factor = luck ^ Rarity.indexOf(rarity)
	return Rarity.BaseWeight[rarity] * factor
end

-- Sortea una rareza. El generador se inyecta para poder probar la curva sin Roblox.
function Rarity.roll(rand: () -> number, luck: number): RarityId
	local total = 0
	local weights: { number } = {}
	for index, rarity in Rarity.Order do
		local weight = Rarity.weightOf(rarity, luck)
		weights[index] = weight
		total += weight
	end

	local target = rand() * total
	local accumulated = 0
	for index, rarity in Rarity.Order do
		accumulated += weights[index]
		if target <= accumulated then
			return rarity
		end
	end
	return "Legendary"
end

return Rarity
