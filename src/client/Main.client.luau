--!strict
-- Arranque del cliente: construye la UI, conecta los listeners y avisa de que está
-- listo. Nada de aquí concede nada; el cliente pide y el servidor decide.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local TopDownCamera = require(script.Parent.Camera.TopDownCamera)
local RunInput = require(script.Parent.Input.RunInput)
local Hud = require(script.Parent.UI.Hud)
local LevelUpPanel = require(script.Parent.UI.LevelUpPanel)
local ResultPanel = require(script.Parent.UI.ResultPanel)
local CombatFeedback = require(script.Parent.VFX.CombatFeedback)
local AdminMenu = require(script.Parent.Admin.AdminMenu)

type MatchState = Types.MatchState
type RunSnapshot = Types.RunSnapshot
type UpgradeOffer = Types.UpgradeOffer

Hud.build()
LevelUpPanel.build(function(upgradeId: string)
	Remotes.RequestUpgrade:FireServer(upgradeId)
end)
ResultPanel.build()
CombatFeedback.build()
AdminMenu.build()
TopDownCamera.start()

local lastLevel = 1

Remotes.RunSnapshot.OnClientEvent:Connect(function(snapshot: RunSnapshot)
	lastLevel = snapshot.Level
	Hud.apply(snapshot)
end)

Remotes.MatchStateChanged.OnClientEvent:Connect(
	function(state: MatchState, elapsed: number, offers: { UpgradeOffer }?)
		-- Los estados "Event" y "Boss" también simulan: la partida sigue viva, así que el
		-- jugador mantiene el control.
		local simulated = state == "Playing" or state == "Event" or state == "Boss"
		RunInput.setEnabled(simulated)

		if state == "LevelUp" and offers and #offers > 0 then
			LevelUpPanel.show(offers)
		else
			LevelUpPanel.hide()
		end

		if state == "Defeat" or state == "Victory" then
			ResultPanel.show(state, elapsed, lastLevel)
		else
			ResultPanel.hide()
		end
	end
)

Remotes.UpgradeChosen.OnClientEvent:Connect(function(_upgradeId: string)
	LevelUpPanel.hide()
end)

Remotes.CombatEffect.OnClientEvent:Connect(
	function(kind: string, position: Vector3, magnitude: number, target: Vector3?)
		CombatFeedback.play(kind, position, magnitude, target)
	end
)

-- Todos los listeners estan registrados: ahora si el servidor puede enviar el estado.
Remotes.ClientReady:FireServer()
