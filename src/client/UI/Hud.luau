--!strict
-- HUD de la partida: reloj, nivel y XP, vida, y el resumen de la build (armas y
-- mejoras). Solo pinta el snapshot que envía el servidor: un botón del HUD nunca
-- concede nada, así que aquí no hay ninguna autoridad.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local Utilities = Shared:WaitForChild("Utilities")
local Format = require(Utilities:WaitForChild("Format"))
local UIKit = require(script.Parent.UIKit)

type RunSnapshot = Types.RunSnapshot
type WeaponView = Types.WeaponView
type PassiveView = Types.PassiveView

local ROWS = 12
local PANEL_BG = Color3.fromRGB(14, 16, 22)

local timerLabel: TextLabel
local levelLabel: TextLabel
local xpBar: { Root: Frame, Fill: Frame }
local hpBar: { Root: Frame, Fill: Frame }
local hpLabel: TextLabel
local buffLabel: TextLabel
local rows: { { Root: Frame, Icon: TextLabel, Name: TextLabel, Level: TextLabel } } = {}

local function clampSize(frame: Frame, minimum: Vector2, maximum: Vector2)
	local constraint = Instance.new("UISizeConstraint")
	constraint.MinSize = minimum
	constraint.MaxSize = maximum
	constraint.Parent = frame
end

local Hud = {}

function Hud.build()
	local gui = UIKit.screen("Hud", 10)

	-- TOP: reloj + nivel + barra de XP
	local top =
		UIKit.frame(gui, "Top", UDim2.new(0.36, 0, 0, 74), UDim2.new(0.5, 0, 0, 10), Vector2.new(0.5, 0))
	clampSize(top, Vector2.new(220, 74), Vector2.new(420, 74))

	timerLabel = UIKit.label(
		top,
		"Timer",
		"0:00",
		UDim2.new(1, 0, 0, 34),
		nil,
		nil,
		Color3.fromRGB(245, 247, 252),
		true
	)
	timerLabel.TextXAlignment = Enum.TextXAlignment.Center
	timerLabel.TextSize = 26

	xpBar = UIKit.bar(top, "XPBar", 14, Color3.fromRGB(255, 214, 92))
	xpBar.Root.Position = UDim2.new(0, 0, 0, 40)

	levelLabel = UIKit.label(
		xpBar.Root,
		"Level",
		"NIV 1",
		UDim2.new(1, -12, 1, 0),
		UDim2.new(0, 6, 0, 0),
		nil,
		Color3.fromRGB(18, 20, 26),
		true
	)
	levelLabel.TextSize = 11

	-- Debajo del reloj: buffs temporales con su cuenta atrás. Se oculta solo cuando no
	-- hay ninguno, así que no ocupa sitio en el 99% de la partida.
	buffLabel = UIKit.label(
		gui,
		"Buffs",
		"",
		UDim2.new(0.7, 0, 0, 22),
		UDim2.new(0.5, 0, 0, 92),
		Vector2.new(0.5, 0),
		Config.UI.Accent,
		true
	)
	buffLabel.TextSize = 14
	buffLabel.TextXAlignment = Enum.TextXAlignment.Center

	-- ABAJO IZQUIERDA: vida
	local health = UIKit.frame(
		gui,
		"Health",
		UDim2.new(0.22, 0, 0, 46),
		UDim2.new(0, 20, 1, -20),
		Vector2.new(0, 1),
		PANEL_BG
	)
	clampSize(health, Vector2.new(190, 46), Vector2.new(330, 46))

	hpBar = UIKit.bar(health, "HPBar", 14, Color3.fromRGB(226, 84, 96))
	hpBar.Root.Position = UDim2.new(0, 10, 0, 8)
	hpBar.Root.Size = UDim2.new(1, -20, 0, 14)

	hpLabel = UIKit.label(
		health,
		"HPText",
		"100 / 100",
		UDim2.new(1, 0, 0, 16),
		UDim2.new(0, 0, 0, 26),
		nil,
		Color3.fromRGB(214, 219, 228)
	)
	hpLabel.TextSize = 13

	-- ABAJO DERECHA: armas y mejoras
	local build = UIKit.frame(
		gui,
		"Build",
		UDim2.new(0.2, 0, 0, 26 + ROWS * 26),
		UDim2.new(1, -20, 1, -20),
		Vector2.new(1, 1),
		PANEL_BG
	)
	clampSize(build, Vector2.new(180, 120), Vector2.new(300, 340))

	for index = 1, ROWS do
		local row = UIKit.frame(
			build,
			`Row{index}`,
			UDim2.new(1, -16, 0, 22),
			UDim2.new(0, 8, 0, 6 + (index - 1) * 26),
			nil,
			Color3.fromRGB(24, 27, 35)
		)
		local icon = UIKit.label(row, "Icon", "", UDim2.new(0, 24, 1, 0))
		icon.TextSize = 15
		local name = UIKit.label(row, "Name", "", UDim2.new(1, -66, 1, 0), UDim2.new(0, 26, 0, 0))
		name.TextSize = 13
		local level = UIKit.label(
			row,
			"Level",
			"",
			UDim2.new(0, 44, 1, 0),
			UDim2.new(1, -6, 0, 0),
			nil,
			Color3.fromRGB(168, 175, 188)
		)
		level.TextSize = 12
		level.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(rows, { Root = row, Icon = icon, Name = name, Level = level })
	end
end

function Hud.apply(snapshot: RunSnapshot)
	timerLabel.Text = Format.clock(snapshot.Elapsed)

	local xpRatio = if snapshot.XPToNext > 0 then snapshot.XP / snapshot.XPToNext else 0
	xpBar.Fill.Size = UDim2.new(math.clamp(xpRatio, 0, 1), 0, 1, 0)
	levelLabel.Text = `NIV {snapshot.Level}`

	local healthRatio = if snapshot.MaxHealth > 0 then snapshot.Health / snapshot.MaxHealth else 0
	hpBar.Fill.Size = UDim2.new(math.clamp(healthRatio, 0, 1), 0, 1, 0)
	hpLabel.Text = `{math.ceil(snapshot.Health)} / {math.ceil(snapshot.MaxHealth)}`

	if #snapshot.Buffs > 0 then
		local active = {}
		for _, buff in snapshot.Buffs do
			table.insert(active, `{buff.Name} {math.ceil(buff.Remaining)}s`)
		end
		buffLabel.Text = table.concat(active, "   ")
		buffLabel.Visible = true
	else
		buffLabel.Visible = false
	end

	local index = 1
	local overflow = 0
	local function place(icon: string, name: string, level: number, maxLevel: number)
		if index > ROWS then
			overflow += 1
			return
		end
		local row = rows[index]
		row.Icon.Text = icon
		row.Name.Text = name
		row.Level.Text = `{level}/{maxLevel}`
		row.Root.Visible = true
		index += 1
	end

	for _, weapon in snapshot.Weapons do
		place(weapon.Icon, weapon.Name, weapon.Level, weapon.MaxLevel)
	end
	for _, passive in snapshot.Passives do
		place(passive.Icon, passive.Name, passive.Level, passive.MaxLevel)
	end
	for slot = index, ROWS do
		rows[slot].Root.Visible = false
	end

	-- Una build larga no puede esconder entradas sin avisar: la ultima fila tella
	-- cuantas quedan fuera en vez de dejar al jugador creyendo que se las comio.
	if overflow > 0 then
		local row = rows[ROWS]
		row.Icon.Text = "+"
		row.Name.Text = `{overflow} mas`
		row.Level.Text = ""
		row.Root.Visible = true
	end
end

return Hud
