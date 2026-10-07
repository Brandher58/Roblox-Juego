--!strict
-- Panel de selección de misión. Presentación pura: pinta los resúmenes que envía el
-- servidor y manda una petición al pulsar. Nunca cambia el estado ni concede nada.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local UIKit = require(script.Parent.UIKit)

type MissionSummary = Types.MissionSummary

local PANEL_BG = Color3.fromRGB(14, 16, 22)
local CARD_BG = Color3.fromRGB(22, 25, 33)
local MUTED = Color3.fromRGB(158, 165, 178)

local STATE_COLORS = {
	Available = Color3.fromRGB(255, 214, 92),
	Completed = Color3.fromRGB(108, 214, 122),
	Locked = Color3.fromRGB(120, 126, 138),
}

local STATE_TEXT = {
	Available = "DISPONIBLE",
	Completed = "COMPLETADA",
	Locked = "BLOQUEADA",
}

local gui: ScreenGui? = nil
local list: ScrollingFrame? = nil
local onStart: ((string) -> ())? = nil
local missions: { MissionSummary } = {}
local visible = false

local MissionPanel = {}

local function buildRewardText(mission: MissionSummary): string
	local parts: { string } = {}
	if mission.Rewards.Currency > 0 then
		table.insert(parts, `+{mission.Rewards.Currency} moneda`)
	end
	for _, unlocked in mission.Rewards.Missions do
		table.insert(parts, `Desbloquea {unlocked}`)
	end
	for _, unlocked in mission.Rewards.Maps do
		table.insert(parts, `Nuevo mapa: {unlocked}`)
	end
	if #parts == 0 then
		return ""
	end
	return "Recompensas: " .. table.concat(parts, "  ·  ")
end

local function buildCard(mission: MissionSummary, index: number)
	if not list then
		return
	end

	local objectives: { string } = {}
	for _, objective in mission.Objectives do
		table.insert(objectives, `• {objective.Label} ({objective.Required})`)
	end

	local height = 96 + math.max(1, #objectives) * 18
	local card = UIKit.frame(
		list,
		`Mission_{mission.Id}`,
		UDim2.new(1, -14, 0, height),
		UDim2.new(0, 0, 0, 0),
		nil,
		CARD_BG
	)
	card.LayoutOrder = index

	local accent = STATE_COLORS[mission.State] or MUTED
	local strip = UIKit.frame(card, "Strip", UDim2.new(0, 5, 1, 0), UDim2.new(0, 0, 0, 0), nil, accent)
	strip.BackgroundTransparency = 0

	local title = UIKit.label(
		card,
		"Title",
		mission.DisplayName,
		UDim2.new(1, -180, 0, 26),
		UDim2.new(0, 16, 0, 8),
		nil,
		Color3.fromRGB(240, 243, 250),
		true
	)
	title.TextSize = 18

	local meta = UIKit.label(
		card,
		"Meta",
		`{mission.MapName}  ·  {mission.Duration > 0 and ("objetivo " .. mission.Duration .. "s") or "jefe"}`,
		UDim2.new(1, -180, 0, 18),
		UDim2.new(0, 16, 0, 32),
		nil,
		MUTED
	)
	meta.TextSize = 13

	local stateLabel = UIKit.label(
		card,
		"State",
		STATE_TEXT[mission.State] or mission.State,
		UDim2.new(0, 150, 0, 20),
		UDim2.new(1, -160, 0, 12),
		nil,
		accent,
		true
	)
	stateLabel.TextSize = 13

	local objectiveLabel = UIKit.label(
		card,
		"Objectives",
		table.concat(objectives, "\n"),
		UDim2.new(1, -180, 0, #objectives * 18),
		UDim2.new(0, 16, 0, 54),
		nil,
		Color3.fromRGB(198, 204, 216)
	)
	objectiveLabel.TextSize = 13

	local description = UIKit.label(
		card,
		"Description",
		mission.Description,
		UDim2.new(1, -180, 1, -70),
		UDim2.new(0, 16, 0, 54 + #objectives * 18),
		nil,
		MUTED
	)
	description.TextSize = 12

	local rewards = UIKit.label(
		card,
		"Rewards",
		buildRewardText(mission),
		UDim2.new(1, -32, 0, 16),
		UDim2.new(0, 16, 1, -22),
		nil,
		Color3.fromRGB(214, 186, 122)
	)
	rewards.TextSize = 12

	if mission.State == "Available" then
		local button = Instance.new("TextButton")
		button.Name = "Start"
		button.Size = UDim2.new(0, 130, 0, 34)
		button.Position = UDim2.new(1, -150, 1, -46)
		button.BackgroundColor3 = accent
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		button.Font = Enum.Font.GothamBold
		button.Text = "EMPEZAR"
		button.TextColor3 = Color3.fromRGB(18, 20, 26)
		button.TextSize = 14
		button.Parent = card
		UIKit.corner(button, UDim.new(0, 8))
		button.Activated:Connect(function()
			if onStart then
				onStart(mission.Id)
			end
		end)
	end
end

local function rebuild()
	if not list then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for index, mission in missions do
		buildCard(mission, index)
	end
end

function MissionPanel.build(startHandler: (string) -> ())
	onStart = startHandler

	gui = UIKit.screen("MissionPanel", 25)
	gui.Enabled = false

	local dim =
		UIKit.frame(gui, "Dim", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), nil, Color3.fromRGB(7, 8, 12))
	dim.BackgroundTransparency = 0.4

	local panel = UIKit.frame(
		gui,
		"Panel",
		UDim2.new(0, 720, 0, 560),
		UDim2.new(0.5, 0, 0.5, 0),
		Vector2.new(0.5, 0.5),
		PANEL_BG
	)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(360, 300)
	constraint.MaxSize = Vector2.new(820, 640)
	constraint.Parent = panel

	local title = UIKit.label(
		panel,
		"Title",
		"SELECCIONA MISIÓN",
		UDim2.new(1, 0, 0, 40),
		UDim2.new(0, 0, 0, 14),
		nil,
		Color3.fromRGB(240, 243, 250),
		true
	)
	title.TextSize = 28
	title.TextXAlignment = Enum.TextXAlignment.Center

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Size = UDim2.new(1, -20, 1, -76)
	list.Position = UDim2.new(0, 10, 0, 64)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Name = "Layout"
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = list

	rebuild()
end

function MissionPanel.setMissions(nextMissions: { MissionSummary })
	missions = nextMissions
	rebuild()
	if gui then
		gui.Enabled = visible and #missions > 0
	end
end

function MissionPanel.setVisible(next: boolean)
	visible = next
	if gui then
		gui.Enabled = visible and #missions > 0
	end
end

return MissionPanel
