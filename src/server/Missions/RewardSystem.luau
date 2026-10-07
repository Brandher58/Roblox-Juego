--!strict
-- Aplica las recompensas de una misión completada. Solo corre en el servidor y solo
-- desde `MissionManager` tras una victoria real: no existe ninguna ruta por la que
-- el cliente pueda pedir recompensas.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Profile = require(script.Parent.Parent.Data.Profile)

local RewardSystem = {}

-- Devuelve la moneda total repartida (0 si `rewards.Currency <= 0`).
function RewardSystem.grant(rewards: Types.MissionRewards, players: { Player }?): number
	local recipients = players or Players:GetPlayers()
	local total = 0
	for _, player in recipients do
		total += Profile.addCurrency(player, rewards.Currency)
	end
	return total
end

return RewardSystem
