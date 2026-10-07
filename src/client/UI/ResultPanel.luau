--!strict
-- Fin de partida: derrota o victoria, con el resultado de misión si lo hay. Solo pinta
-- lo que recibe del servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Utilities"):WaitForChild("Format"))
local UIKit = require(script.Parent.UIKit)

type MissionResult = Types.MissionResult

local gui: ScreenGui? = nil
local title: TextLabel? = nil
local subtitle: TextLabel? = nil
local detail: TextLabel? = nil

local ResultPanel = {}

local function rewardText(result: MissionResult): string
	local parts: { string } = {}
	if result.Currency > 0 then
		table.insert(parts, `+{result.Currency} moneda`)
	end
	for _, unlocked in result.UnlockedMissions do
		table.insert(parts, `Nueva misión: {unlocked}`)
	end
	for _, unlocked in result.UnlockedMaps do
		table.insert(parts, `Nuevo mapa: {unlocked}`)
	end
	return table.concat(parts, "   ·   ")
end

function ResultPanel.build()
	gui = UIKit.screen("ResultPanel", 40)
	gui.Enabled = false

	local dim =
		UIKit.frame(gui, "Dim", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), nil, Color3.fromRGB(10, 6, 8))
	dim.BackgroundTransparency = 0.45

	title = UIKit.label(
		gui,
		"Title",
		"",
		UDim2.new(1, 0, 0, 60),
		UDim2.new(0, 0, 0.32, 0),
		nil,
		Color3.fromRGB(240, 240, 245),
		true
	)
	title.TextSize = 52
	title.TextXAlignment = Enum.TextXAlignment.Center

	subtitle = UIKit.label(
		gui,
		"Subtitle",
		"",
		UDim2.new(1, 0, 0, 28),
		UDim2.new(0, 0, 0.32, 0) + UDim2.new(0, 66, 0, 0)
	)
	subtitle.TextSize = 20
	subtitle.TextColor3 = Color3.fromRGB(206, 210, 220)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center

	detail = UIKit.label(
		gui,
		"Detail",
		"",
		UDim2.new(1, -80, 0, 44),
		UDim2.new(0.5, 0, 0.32, 0) + UDim2.new(0, 104, 0, 0),
		Vector2.new(0.5, 0),
		Color3.fromRGB(255, 214, 92),
		true
	)
	detail.TextSize = 17
	detail.TextXAlignment = Enum.TextXAlignment.Center
end

function ResultPanel.show(state: string, elapsed: number, level: number, result: MissionResult?)
	if not gui or not title or not subtitle or not detail then
		return
	end

	if state == "Victory" then
		title.Text = "VICTORIA"
		title.TextColor3 = Color3.fromRGB(255, 214, 92)
		if result then
			subtitle.Text = `{result.DisplayName}  ·  Nivel {level}  ·  {Format.clock(elapsed)}`
			detail.Text = rewardText(result)
		else
			subtitle.Text = `Nivel {level}  ·  {Format.clock(elapsed)} sobrevividos`
			detail.Text = ""
		end
		gui.Enabled = true
	elseif state == "Defeat" then
		title.Text = "DERROTA"
		title.TextColor3 = Color3.fromRGB(238, 116, 116)
		if result and result.Outcome == "Failed" then
			subtitle.Text = `{result.DisplayName} fallida  ·  Nivel {level}  ·  {Format.clock(elapsed)}`
			detail.Text = "Sin recompensas. La misión sigue disponible para reintentar."
		else
			subtitle.Text = `Nivel {level}  ·  {Format.clock(elapsed)} sobrevividos  ·  reiniciando...`
			detail.Text = ""
		end
		gui.Enabled = true
	else
		gui.Enabled = false
	end
end

function ResultPanel.hide()
	if gui then
		gui.Enabled = false
	end
end

return ResultPanel
