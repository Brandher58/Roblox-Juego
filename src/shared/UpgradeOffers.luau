--!strict
-- Generación de las ofertas de subida de nivel.
--
-- Es una función pura a propósito: el servidor la llama, pero se puede probar sin
-- Studio. Además del peso por rareza hay garantías explícitas, porque el diseño
-- pide que ninguna partida se vuelva frustrante por mala suerte.
-- Import dual (ver StatMath.luau): el vecino se resuelve por `script` en Roblox y por
-- ruta relativa en las pruebas headless con Lune.
local Types = require(script and script.Parent.Types or "./Types")
local Registry = require(script and script.Parent.Registry or "./Registry")
local Rarity = require(script and script.Parent.Rarity or "./Rarity")

type RunView = Types.RunView
type UpgradeDefinition = Types.UpgradeDefinition
type UpgradeOffer = Types.UpgradeOffer

-- Orden estable para que las pruebas y el reparto de pesos sean deterministas.
local UPGRADE_IDS: { string } = {}
for id in Registry.Upgrades do
	table.insert(UPGRADE_IDS, id)
end
table.sort(UPGRADE_IDS)

local function ownsWeapon(run: RunView, weaponId: string?): boolean
	return weaponId ~= nil and (run.weaponLevels[weaponId] or 0) > 0
end

local function isEligible(definition: UpgradeDefinition, run: RunView): boolean
	local current = run.upgradeLevels[definition.Id] or 0
	if current >= definition.MaxLevel then
		return false
	end
	-- Una mejora de arma solo tiene sentido si esa arma ya se posee: no se puede
	-- comprar "Filo Afilado" (cuchillas) antes de tener las cuchillas.
	if definition.Kind == "WeaponUpgrade" and not ownsWeapon(run, definition.TargetId) then
		return false
	end
	return if definition.Requires then definition.Requires(run) else true
end

local function rarityWeight(definition: UpgradeDefinition, luck: number): number
	return definition.Weight * Rarity.weightOf(definition.Rarity, luck)
end

local function weightedPick(
	candidates: { UpgradeDefinition },
	luck: number,
	rand: () -> number
): UpgradeDefinition?
	local weights = table.create(#candidates)
	local total = 0
	for index, definition in candidates do
		weights[index] = rarityWeight(definition, luck)
		total += weights[index]
	end
	if total <= 0 then
		return nil
	end

	local target = rand() * total
	local accumulated = 0
	for index, definition in candidates do
		accumulated += weights[index]
		if target <= accumulated then
			return definition
		end
	end
	return candidates[#candidates]
end

local function remaining(
	candidates: { UpgradeDefinition },
	taken: { [string]: boolean },
	predicate: ((UpgradeDefinition) -> boolean)?
): { UpgradeDefinition }
	local pool = {}
	for _, definition in candidates do
		if not taken[definition.Id] and (not predicate or predicate(definition)) then
			table.insert(pool, definition)
		end
	end
	return pool
end

local Offers = {}

function Offers.generate(run: RunView, luck: number, rand: () -> number, count: number?): { UpgradeOffer }
	local wanted = count or 3
	local luckValue = math.max(0.05, luck)

	local eligible: { UpgradeDefinition } = {}
	for _, id in UPGRADE_IDS do
		local definition = Registry.Upgrades[id]
		if isEligible(definition, run) then
			table.insert(eligible, definition)
		end
	end

	local chosen: { UpgradeDefinition } = {}
	local taken: { [string]: boolean } = {}

	local ownedWeapons = 0
	for _, level in run.weaponLevels do
		if level > 0 then
			ownedWeapons += 1
		end
	end

	local function isNewWeapon(definition: UpgradeDefinition): boolean
		return definition.Kind == "NewWeapon"
	end

	local function isOwnedWeaponUpgrade(definition: UpgradeDefinition): boolean
		return definition.Kind == "WeaponUpgrade" and ownsWeapon(run, definition.TargetId)
	end

	-- Garantía 1: con una sola arma siempre hay una carta de arma nueva, para que
	-- la build pueda diversificar aunque el sorteo sea pobre.
	if ownedWeapons < 2 and #chosen < wanted then
		local definition = weightedPick(remaining(eligible, taken, isNewWeapon), luckValue, rand)
		if definition then
			table.insert(chosen, definition)
			taken[definition.Id] = true
		end
	end

	-- Garantía 2: siempre incluir la mejora de un arma que el jugador ya lleva, para
	-- que exista una elección segura.
	local hasOwnedUpgrade = false
	for _, definition in chosen do
		if isOwnedWeaponUpgrade(definition) then
			hasOwnedUpgrade = true
			break
		end
	end
	if not hasOwnedUpgrade and #chosen < wanted then
		local definition = weightedPick(remaining(eligible, taken, isOwnedWeaponUpgrade), luckValue, rand)
		if definition then
			table.insert(chosen, definition)
			taken[definition.Id] = true
		end
	end

	while #chosen < wanted do
		local definition = weightedPick(remaining(eligible, taken, nil), luckValue, rand)
		if not definition then
			break
		end
		table.insert(chosen, definition)
		taken[definition.Id] = true
	end

	local offers: { UpgradeOffer } = {}
	for index, definition in chosen do
		local current = run.upgradeLevels[definition.Id] or 0
		local isUnlock = definition.Kind == "NewWeapon"
		offers[index] = {
			Id = definition.Id,
			Kind = definition.Kind,
			Rarity = definition.Rarity,
			Name = definition.Name,
			Description = definition.Description,
			Icon = definition.Icon,
			TargetId = definition.TargetId,
			CurrentLevel = if isUnlock then 0 else current,
			NextLevel = if isUnlock then 1 else current + 1,
			MaxLevel = definition.MaxLevel,
		}
	end

	return offers
end

return Offers
