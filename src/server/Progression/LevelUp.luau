--!strict
-- Selección de mejora. Es el dueño del ciclo "ofrezco cartas → el jugador elige una
-- → la aplico". El estado de partida y el reloj los lleva Match; aquí solo se sabe
-- qué carta está pendiente y qué hay que aplicarle al jugador.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("Registry"))
local UpgradeOffers = require(Shared:WaitForChild("UpgradeOffers"))
local Types = require(Shared:WaitForChild("Types"))
local Run = require(script.Parent.Parent.Run)
local Stats = require(script.Parent.Parent.Stats)

type UpgradeOffer = Types.UpgradeOffer

local LevelUp = {}

local queued: { [Player]: number } = {}
local pending: { [Player]: { UpgradeOffer } } = {}

function LevelUp.queuedLevels(player: Player): number
	return queued[player] or 0
end

function LevelUp.awardLevels(player: Player, count: number)
	queued[player] = (queued[player] or 0) + count
end

function LevelUp.pendingFor(player: Player): { UpgradeOffer }?
	return pending[player]
end

function LevelUp.begin(player: Player, offerCount: number): { UpgradeOffer }
	local luck = Stats.get(player).Luck or 1
	local offers = UpgradeOffers.generate(Run.view(player), luck, math.random, offerCount)
	queued[player] = 0
	pending[player] = offers
	return offers
end

local function apply(player: Player, offer: UpgradeOffer)
	local run = Run.get(player)
	local definition = Registry.Upgrades[offer.Id]

	run.upgradeLevels[offer.Id] = (run.upgradeLevels[offer.Id] or 0) + 1

	if offer.Kind == "NewWeapon" then
		local weaponId = offer.TargetId
		if weaponId then
			run.weaponLevels[weaponId] = math.max(1, run.weaponLevels[weaponId] or 0)
		end
	elseif offer.TargetId == nil then
		-- Las mejoras globales entran en el sistema de estadísticas, que es el único
		-- que escribe sobre los valores base.
		for _, modifier in definition.Modifiers do
			Stats.add(player, modifier)
		end
	end
	-- Las mejoras dirigidas a un arma no se registran aquí: WeaponRuntime las lee
	-- desde run.upgradeLevels y las aplica sobre las estadísticas de ese arma.
end

-- Consume la carta elegida. Devolver false significa "no era una oferta vigente":
-- el motivo concreto no le interesa al servidor, solo que no se aplicó nada.
function LevelUp.consume(player: Player, upgradeId: string): boolean
	local offers = pending[player]
	if not offers then
		return false
	end

	local chosen: UpgradeOffer? = nil
	for _, offer in offers do
		if offer.Id == upgradeId then
			chosen = offer
			break
		end
	end
	if not chosen then
		return false
	end

	pending[player] = nil
	apply(player, chosen)
	return true
end

function LevelUp.clear(player: Player)
	queued[player] = nil
	pending[player] = nil
end

return LevelUp
