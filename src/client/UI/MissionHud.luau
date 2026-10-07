--!strict
-- HUD de misión: objetivos en curso y barra del jefe. Presentación pura: solo pinta
-- la instantánea que envía el servidor.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared:WaitForChild("Types"))
local Format = require(Shared:WaitForChild("Utilities"):WaitForChild("Format"))
local UIKit = require(script.Parent.UIKit)

type MissionSnapshot = Types.MissionSnapshot

local PANEL_BG = Color3.fromRGB(14, 16, 22)
local MUTED = Color3.fromRGB(158, 165, 178)

local gui: ScreenGui? = nil
local title: TextLabel? = nil
local clock: TextLabel? = nil
local objectiveLabel: TextLabel? = nil
local bossRoot: Frame? = nil
local bossName: TextLabel? = nil
local bossBar: { Root: Frame, Fill: Frame }? = nil
local bossHp: TextLabel? = nil

local MissionHud = {}

function MissionHud.build()
	gui = UIKit.screen("MissionHud", 11)
	gui.Enabled = false

	local panel =
		UIKit.frame(gui, "Objectives", UDim2.new(0, 300, 0, 110), UDim2.new(0, 20, 0, 100), nil, PANEL_BG)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = Vector2.new(220, 90)
	constraint.MaxSize = Vector2.new(380, 220)
	constraint.Parent = panel

	title = UIKit.label(
		panel,
		"Title",
		"",
		UDim2.new(1, -20, 0, 24),
		UDim2.new(0, 10, 0, 8),
		nil,
		Color3.fromRGB(255, 214, 92),
		true
	)
	title.TextSize = 16

	clock = UIKit.label(panel, "Clock", "", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 30), nil, MUTED)
	clock.TextSize = 13

	objectiveLabel = UIKit.label(
		panel,
		"Lines",
		"",
		UDim2.new(1, -20, 1, -58),
		UDim2.new(0, 10, 0, 50),
		nil,
		Color3.fromRGB(214, 219, 228)
	)
	objectiveLabel.TextSize = 14
	objectiveLabel.TextYAlignment = Enum.TextYAlignment.Top

	-- Barra del jefe: solo aparece cuando hay jefe activo.
	bossRoot = UIKit.frame(
		gui,
		"Boss",
		UDim2.new(0, 460, 0, 54),
		UDim2.new(0.5, 0, 1, -120),
		Vector2.new(0.5, 0),
		PANEL_BG
	)
	bossRoot.Visible = false

	bossName = UIKit.label(
		bossRoot,
		"Name",
		"",
		UDim2.new(1, -20, 0, 20),
		UDim2.new(0, 10, 0, 6),
		nil,
		Color3.fromRGB(238, 116, 116),
		true
	)
	bossName.TextSize = 15

	bossBar = UIKit.bar(bossRoot, "BossBar", 14, Color3.fromRGB(226, 84, 96))
	bossBar.Root.Position = UDim2.new(0, 10, 0, 28)
	bossBar.Root.Size = UDim2.new(1, -20, 0, 14)

	bossHp = UIKit.label(bossRoot, "Hp", "", UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 40), nil, MUTED)
	bossHp.TextSize = 11
	bossHp.TextXAlignment = Enum.TextXAlignment.Right
end

function MissionHud.apply(snapshot: MissionSnapshot?)
	if
		not gui
		or not title
		or not clock
		or not objectiveLabel
		or not bossRoot
		or not bossBar
		or not bossName
		or not bossHp
	then
		return
	end

	if not snapshot then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	title.Text = snapshot.DisplayName
	clock.Text = if snapshot.Remaining
		then `{Format.clock(snapshot.Elapsed)}  ·  quedan {Format.clock(snapshot.Remaining)}`
		else Format.clock(snapshot.Elapsed)

	local lines: { string } = {}
	for _, objective in snapshot.Objectives do
		local mark = if objective.Complete then "✔" else "•"
		local progress = `{math.floor(objective.Current)}/{objective.Required}`
		table.insert(lines, `{mark} {objective.Label}   {progress}`)
	end
	objectiveLabel.Text = table.concat(lines, "\n")

	local boss = snapshot.Boss
	if boss and boss.Active then
		bossRoot.Visible = true
		bossName.Text = boss.Name
		local ratio = if boss.MaxHealth > 0 then boss.Health / boss.MaxHealth else 0
		bossBar.Fill.Size = UDim2.new(math.clamp(ratio, 0, 1), 0, 1, 0)
		bossHp.Text = `{math.ceil(boss.Health)} / {math.ceil(boss.MaxHealth)}`
	else
		bossRoot.Visible = false
	end
end

return MissionHud
