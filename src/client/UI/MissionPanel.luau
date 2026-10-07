--!strict
-- Panel de selección de misión. Presentación pura: pinta los resúmenes que envía el
-- servidor y manda una petición al pulsar. Nunca cambia el estado ni concede nada.
--
-- Layout: cada tarjeta calcula su altura en píxeles fila a fila (título, meta,
-- objetivos, descripción, recompensas y pie con el botón). Nada usa tamaños en
-- porcentaje dentro de la tarjeta, así no hay texto que se pise ni que se salga.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local UIKit = require(script.Parent.UIKit)

type MissionSummary = Types.MissionSummary

local PANEL_BG = Color3.fromRGB(16, 18, 25)
local CARD_BG = Color3.fromRGB(21, 24, 32)
local CARD_BG_HOVER = Color3.fromRGB(29, 33, 43)
local DIVIDER = Color3.fromRGB(40, 44, 56)
local MUTED = Color3.fromRGB(158, 165, 178)
local TEXT_MAIN = Color3.fromRGB(240, 243, 250)
local OBJ_TEXT = Color3.fromRGB(200, 206, 218)
local GOLD_SOFT = Color3.fromRGB(214, 186, 122)
local GOLD = Color3.fromRGB(255, 214, 92)
local GREEN = Color3.fromRGB(108, 214, 122)

local STATE_COLORS = {
	Available = GOLD,
	Completed = GREEN,
	Locked = Color3.fromRGB(120, 126, 138),
}

local STATE_TEXT = {
	Available = "DISPONIBLE",
	Completed = "COMPLETADA",
	Locked = "BLOQUEADA",
}

local STATE_HINTS = {
	Available = "Pulsa EMPEZAR y entra al mapa",
	Completed = "Repetible · tu progreso queda guardado",
	Locked = "Completa la misión anterior para desbloquear",
}

-- Métricas de fila de la tarjeta (píxeles, apiladas sin ambigüedad).
local TOP = 14
local HEAD_H = 30
local META_H = 18
local GAP = 6
local OBJ_LINE = 18
local DESC_H = 36
local REWARD_H = 16
local FOOTER_H = 40
local PAD_BOTTOM = 14

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

local function missionNumber(mission: MissionSummary): string
	local part = mission.Id:match("_(%d+)$")
	return if part then `MISIÓN {part}` else "MISIÓN"
end

local function buildCard(mission: MissionSummary, index: number)
	if not list then
		return
	end

	local objectives: { string } = {}
	for _, objective in mission.Objectives do
		table.insert(objectives, `• {objective.Label} ({objective.Required})`)
	end

	local objectiveLines = math.max(1, #objectives)
	local rewardsText = buildRewardText(mission)
	local hasRewards = #rewardsText > 0

	local headY = TOP
	local metaY = headY + HEAD_H + GAP
	local objY = metaY + META_H + GAP
	local objH = objectiveLines * OBJ_LINE
	local descY = objY + objH + GAP
	local dividerY = descY + DESC_H + 3
	local rewardsY = dividerY + 1 + GAP
	local footerY = rewardsY + (if hasRewards then REWARD_H + GAP else 0)
	local height = footerY + FOOTER_H + PAD_BOTTOM

	local accent = STATE_COLORS[mission.State] or MUTED
	local isLocked = mission.State == "Locked"
	-- Cualquier misión no bloqueada es jugable: superadas se pueden repetir.
	local isPlayable = mission.State ~= "Locked"
	local actionText = if mission.State == "Completed" then "REPETIR" else "EMPEZAR"

	local card = UIKit.frame(
		list,
		`Mission_{mission.Id}`,
		UDim2.new(1, -14, 0, height),
		UDim2.new(0, 0, 0, 0),
		nil,
		CARD_BG
	)
	card.LayoutOrder = index
	card.ClipsDescendants = true

	local stroke = UIKit.stroke(card, accent, 1)
	stroke.Transparency = if isPlayable then 0.25 else 0.55

	-- Barra de acento superior (centrada, sutil).
	local strip = UIKit.frame(card, "Strip", UDim2.new(1, -32, 0, 3), UDim2.new(0, 16, 0, 0), nil, accent)
	strip.BackgroundTransparency = 0

	local title = UIKit.label(
		card,
		"Title",
		mission.DisplayName,
		UDim2.new(1, -190, 0, 26),
		UDim2.new(0, 16, 0, headY),
		nil,
		TEXT_MAIN,
		true
	)
	title.TextSize = 18

	-- Píldora de estado a la derecha, con fondo tintado y texto en contraste.
	local badge = UIKit.label(
		card,
		"State",
		STATE_TEXT[mission.State] or mission.State,
		UDim2.new(0, 130, 0, 24),
		UDim2.new(1, -146, 0, headY + 3),
		nil,
		if isLocked then MUTED else Color3.fromRGB(15, 17, 23),
		true,
		Enum.TextXAlignment.Center
	)
	badge.TextSize = 12
	badge.BackgroundTransparency = if isLocked then 0.6 else 0
	badge.BackgroundColor3 = accent
	UIKit.corner(badge, UDim.new(1, 0))

	local durationText = if mission.Duration > 0 then `objetivo {mission.Duration} s` else "jefe"
	local meta = UIKit.label(
		card,
		"Meta",
		`{missionNumber(mission)}  ·  {mission.MapName}  ·  {durationText}`,
		UDim2.new(1, -32, 0, META_H),
		UDim2.new(0, 16, 0, metaY),
		nil,
		MUTED
	)
	meta.TextSize = 13

	local objectiveLabel = UIKit.label(
		card,
		"Objectives",
		table.concat(objectives, "\n"),
		UDim2.new(1, -32, 0, objH),
		UDim2.new(0, 16, 0, objY),
		nil,
		OBJ_TEXT
	)
	objectiveLabel.TextSize = 13

	local description = UIKit.label(
		card,
		"Description",
		mission.Description,
		UDim2.new(1, -32, 0, DESC_H),
		UDim2.new(0, 16, 0, descY),
		nil,
		MUTED
	)
	description.TextSize = 12

	local divider =
		UIKit.frame(card, "Divider", UDim2.new(1, -32, 0, 1), UDim2.new(0, 16, 0, dividerY), nil, DIVIDER)
	divider.BackgroundTransparency = 0

	if hasRewards then
		local rewards = UIKit.label(
			card,
			"Rewards",
			rewardsText,
			UDim2.new(1, -32, 0, REWARD_H),
			UDim2.new(0, 16, 0, rewardsY),
			nil,
			GOLD_SOFT
		)
		rewards.TextSize = 12
	end

	-- Pie: botón de acción o pista según el estado. La fila está dedicada, así el
	-- botón nunca toca el texto de recompensas.
	if isPlayable then
		local button = Instance.new("TextButton")
		button.Name = "Start"
		button.Size = UDim2.new(0, 130, 0, 34)
		button.Position = UDim2.new(1, -150, 0, footerY + 3)
		button.BackgroundColor3 = accent
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		button.Font = Enum.Font.GothamBold
		button.Text = actionText
		button.TextColor3 = Color3.fromRGB(15, 17, 23)
		button.TextSize = 14
		button.Parent = card
		UIKit.corner(button, UDim.new(0, 8))
		button.Activated:Connect(function()
			if onStart then
				onStart(mission.Id)
			end
		end)

		-- Resalte al pasar el ratón (solo misiones jugables).
		card.MouseEnter:Connect(function()
			card.BackgroundColor3 = CARD_BG_HOVER
		end)
		card.MouseLeave:Connect(function()
			card.BackgroundColor3 = CARD_BG
		end)
	end

	local hint = UIKit.label(
		card,
		"Hint",
		STATE_HINTS[mission.State] or "",
		UDim2.new(1, -32, 0, FOOTER_H),
		UDim2.new(0, 16, 0, footerY),
		nil,
		if mission.State == "Completed" then GREEN else MUTED
	)
	hint.TextSize = 12
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
		UDim2.new(0, 760, 0, 600),
		UDim2.new(0.5, 0, 0.5, 0),
		Vector2.new(0.5, 0.5),
		PANEL_BG
	)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new(Color3.fromRGB(26, 29, 39), Color3.fromRGB(12, 13, 19))
	gradient.Parent = panel

	local panelStroke = UIKit.stroke(panel, GOLD, 1)
	panelStroke.Transparency = 0.45

	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(380, 320)
	constraint.MaxSize = Vector2.new(820, 680)
	constraint.Parent = panel

	local title = UIKit.label(
		panel,
		"Title",
		"SELECCIONA MISIÓN",
		UDim2.new(1, 0, 0, 40),
		UDim2.new(0, 0, 0, 12),
		nil,
		TEXT_MAIN,
		true,
		Enum.TextXAlignment.Center
	)
	title.TextSize = 28

	local underline =
		UIKit.frame(panel, "Underline", UDim2.new(0, 120, 0, 3), UDim2.new(0.5, -60, 0, 54), nil, GOLD)
	underline.BackgroundTransparency = 0

	list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.Size = UDim2.new(1, -20, 1, -78)
	list.Position = UDim2.new(0, 10, 0, 68)
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
