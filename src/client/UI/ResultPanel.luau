--!strict
-- Fin de partida: derrota o victoria. Solo pinta el estado que recibe del servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Utilities"):WaitForChild("Format"))
local UIKit = require(script.Parent.UIKit)

local gui: ScreenGui? = nil
local title: TextLabel? = nil
local subtitle: TextLabel? = nil

local ResultPanel = {}

function ResultPanel.build()
	gui = UIKit.screen("ResultPanel", 30)
	gui.Enabled = false

	local dim =
		UIKit.frame(gui, "Dim", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), nil, Color3.fromRGB(10, 6, 8))
	dim.BackgroundTransparency = 0.45

	title = UIKit.label(
		gui,
		"Title",
		"",
		UDim2.new(1, 0, 0, 60),
		UDim2.new(0, 0, 0.34, 0),
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
		UDim2.new(0, 0, 0.34, 0) + UDim2.new(0, 66, 0, 0)
	)
	subtitle.TextSize = 20
	subtitle.TextColor3 = Color3.fromRGB(206, 210, 220)
	subtitle.TextXAlignment = Enum.TextXAlignment.Center
end

function ResultPanel.show(state: string, elapsed: number, level: number)
	if not gui or not title or not subtitle then
		return
	end

	if state == "Defeat" then
		title.Text = "DERROTA"
		title.TextColor3 = Color3.fromRGB(238, 116, 116)
		subtitle.Text = `Nivel {level}  ·  {Format.clock(elapsed)} sobrevividos  ·  reiniciando...`
		gui.Enabled = true
	elseif state == "Victory" then
		title.Text = "VICTORIA"
		title.TextColor3 = Color3.fromRGB(255, 214, 92)
		subtitle.Text = `Nivel {level}  ·  {Format.clock(elapsed)} sobrevividos`
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
