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
local MissionPanel = require(script.Parent.UI.MissionPanel)
local MissionHud = require(script.Parent.UI.MissionHud)
local CombatFeedback = require(script.Parent.VFX.CombatFeedback)
local AdminMenu = require(script.Parent.Admin.AdminMenu)

type MatchState = Types.MatchState
type RunSnapshot = Types.RunSnapshot
type UpgradeOffer = Types.UpgradeOffer
type MissionSummary = Types.MissionSummary
type MissionSnapshot = Types.MissionSnapshot
type MissionResult = Types.MissionResult

Hud.build()
LevelUpPanel.build(function(upgradeId: string)
	Remotes.RequestUpgrade:FireServer(upgradeId)
end)
ResultPanel.build()
MissionPanel.build(function(missionId: string)
	Remotes.RequestMission:FireServer(missionId)
end)
MissionHud.build()
CombatFeedback.build()
AdminMenu.build()
TopDownCamera.start()

local lastLevel = 1
local lastElapsed = 0
local lastResult: MissionResult? = nil
local lastResultState: MatchState? = nil
local currentState: MatchState = "Lobby"

Remotes.RunSnapshot.OnClientEvent:Connect(function(snapshot: RunSnapshot)
	lastLevel = snapshot.Level
	Hud.apply(snapshot)
end)

Remotes.MatchStateChanged.OnClientEvent:Connect(
	function(state: MatchState, elapsed: number, offers: { UpgradeOffer }?)
		currentState = state
		-- Los estados "Event" y "Boss" también simulan: la partida sigue viva, así que el
		-- jugador mantiene el control. En "MissionSelect" el panel de misión manda.
		local simulated = state == "Playing" or state == "Event" or state == "Boss"
		RunInput.setEnabled(simulated)

		if state == "LevelUp" and offers and #offers > 0 then
			LevelUpPanel.show(offers)
		else
			LevelUpPanel.hide()
		end

		if state == "Defeat" or state == "Victory" then
			lastElapsed = elapsed
			lastResultState = state
			ResultPanel.show(state, elapsed, lastLevel, lastResult)
		else
			lastResultState = nil
			ResultPanel.hide()
		end

		MissionPanel.setVisible(state == "MissionSelect")
		if state == "MissionSelect" then
			lastResult = nil
		end
	end
)

-- Lista de misiones con el estado de ESTE jugador. El panel solo es visible en el
-- estado de selección; si la lista llega antes, ya se pinta para cuando toque.
Remotes.MissionList.OnClientEvent:Connect(function(missions: { MissionSummary })
	MissionPanel.setMissions(missions)
	MissionPanel.setVisible(currentState == "MissionSelect")
end)

Remotes.MissionUpdate.OnClientEvent:Connect(function(snapshot: MissionSnapshot?)
	MissionHud.apply(snapshot)
end)

-- Resultado final: se guarda para que la pantalla de resultado lo muestre cuando
-- llegue el estado Victory/Defeat (viaja en el mismo frame, antes que el estado).
Remotes.MissionFinished.OnClientEvent:Connect(function(result: MissionResult)
	lastResult = result
	-- Si el estado Victory/Defeat llegó antes, se repinta con el resultado ya presente.
	if lastResultState then
		ResultPanel.show(lastResultState, lastElapsed, lastLevel, lastResult)
	end
end)

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
