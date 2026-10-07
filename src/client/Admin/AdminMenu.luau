--!strict
-- Menú de administración del cliente, SOLO en Studio. Botones de playtest que
-- envían comandos al servidor; el servidor valida cada uno (Admin.luau), el menú
-- solo pide. Se alterna con F2 y no se construye en builds de producción.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Registry = require(Shared:WaitForChild("Registry"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))
local UIKit = require(script.Parent.Parent.UI.UIKit)

type RunSnapshot = Types.RunSnapshot

local AdminMenu = {}

local ROW = 30
local GAP = 4
local TITLE_HEIGHT = 32
local MAIN_BUTTONS = 4
local PANEL_WIDTH = 300
local PANEL_HEIGHT = 560

local weaponLevelLabels: { [string]: TextLabel } = {}
local upgradeLevelLabels: { [string]: TextLabel } = {}

local function mainButton(parent: Frame, y: number, text: string, command: string, value: unknown?)
	local row = Instance.new("TextButton")
	row.Name = command
	row.Size = UDim2.new(1, -16, 0, ROW)
	row.Position = UDim2.new(0, 8, 0, y)
	row.BackgroundColor3 = Color3.fromRGB(40, 46, 60)
	row.BackgroundTransparency = 0.1
	row.BorderSizePixel = 0
	row.Text = text
	row.TextColor3 = Color3.fromRGB(235, 238, 245)
	row.TextSize = 14
	row.Font = Enum.Font.GothamBold
	row.AutoButtonColor = true
	row.Parent = parent
	UIKit.corner(row, UDim.new(0, 6))
	row.Activated:Connect(function()
		Remotes.AdminCommand:FireServer(command, value)
	end)
end

local function section(parent: Instance, text: string)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 0, 16)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(120, 132, 152)
	label.TextSize = 12
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
end

-- Enlivened row inside the scrolling list: name on the left, current level
-- (from the live snapshot) in the middle, and a "+1" that asks the server for
-- exactly one more level of that weapon/upgrade.
local function itemRow(parent: Instance, name: string, command: string, id: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -4, 0, ROW)
	row.BackgroundColor3 = Color3.fromRGB(32, 38, 52)
	row.BackgroundTransparency = 0.1
	row.BorderSizePixel = 0
	row.Parent = parent

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.58, 0, 1, 0)
	nameLabel.Position = UDim2.new(0, 8, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = name
	nameLabel.TextColor3 = Color3.fromRGB(228, 232, 240)
	nameLabel.TextSize = 13
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local lvl = Instance.new("TextLabel")
	lvl.Size = UDim2.new(0.2, 0, 1, 0)
	lvl.Position = UDim2.new(0.6, 0, 0, 0)
	lvl.BackgroundTransparency = 1
	lvl.Text = "0"
	lvl.TextColor3 = Color3.fromRGB(150, 160, 180)
	lvl.TextSize = 12
	lvl.Font = Enum.Font.GothamBold
	lvl.TextXAlignment = Enum.TextXAlignment.Right
	lvl.Parent = row
	if command == "level_up" then
		weaponLevelLabels[id] = lvl
	else
		upgradeLevelLabels[id] = lvl
	end

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.18, 0, 0.64, 0)
	btn.Position = UDim2.new(0.8, 0, 0.18, 0)
	btn.BackgroundColor3 = Color3.fromRGB(60, 120, 220)
	btn.BorderSizePixel = 0
	btn.Text = "+1"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 14
	btn.Font = Enum.Font.GothamBold
	btn.AutoButtonColor = true
	btn.Parent = row
	btn.Activated:Connect(function()
		Remotes.AdminCommand:FireServer(command, id)
	end)
end

function AdminMenu.build()
	if not RunService:IsStudio() then
		return
	end

	local gui = UIKit.screen("AdminMenu", 60)
	local bar = UIKit.frame(
		gui,
		"Bar",
		UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT),
		UDim2.new(0, 12, 0, 12),
		Vector2.new(0, 0),
		Color3.fromRGB(14, 16, 22)
	)
	UIKit.stroke(bar, Color3.fromRGB(255, 214, 92), 1)
	UIKit.label(
		bar,
		"Title",
		"DEV · ADMIN",
		UDim2.new(1, -16, 0, 18),
		UDim2.new(0, 10, 0, 7),
		nil,
		Color3.fromRGB(255, 214, 92),
		true
	)

	mainButton(bar, TITLE_HEIGHT, "Desbloquear todo", "unlock_all")
	mainButton(bar, TITLE_HEIGHT + (ROW + GAP), "Armas y mejoras al tope", "max_all")
	mainButton(bar, TITLE_HEIGHT + (ROW + GAP) * 2, "+500 XP", "grant_xp", 500)
	mainButton(bar, TITLE_HEIGHT + (ROW + GAP) * 3, "Curar", "heal")

	-- Lista desplazable de armas y mejoras individuales con su nivel actual
	-- y un botón "+1". El HUD ya muestra la build al completo.
	local list = Instance.new("ScrollingFrame")
	list.Name = "WeaponList"
	list.Size = UDim2.new(1, -24, 1, -TITLE_HEIGHT - MAIN_BUTTONS * (ROW + GAP) - GAP)
	list.Position = UDim2.new(0, 12, 0, TITLE_HEIGHT + MAIN_BUTTONS * (ROW + GAP))
	list.BackgroundColor3 = Color3.fromRGB(11, 13, 19)
	list.BackgroundTransparency = 0.35
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 8
	list.Parent = bar

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = list

	section(list, "ARMAS")
	for weaponId, weapon in pairs(Registry.Weapons) do
		itemRow(list, weapon.Name, "level_up", weaponId)
	end

	section(list, "MEJORAS")
	for upgradeId, upgrade in pairs(Registry.Upgrades) do
		if upgrade.Kind ~= "NewWeapon" then
			itemRow(list, upgrade.Name, "upgrade_level_up", upgradeId)
		end
	end

	-- Refresca el nivel actual de cada fila cuando el servidor empuja un
	-- snapshot nuevo (cada armadura/mejora que cambió o cada tick).
	Remotes.RunSnapshot.OnClientEvent:Connect(function(snapshot: RunSnapshot)
		for _, weapon in snapshot.Weapons do
			local lab = weaponLevelLabels[weapon.Id]
			if lab then
				lab.Text = `${weapon.Level}/${weapon.MaxLevel}`
			end
		end
		for _, passive in snapshot.Passives do
			local lab = upgradeLevelLabels[passive.Id]
			if lab then
				lab.Text = `${passive.Level}/${passive.MaxLevel}`
			end
		end
	end)

	-- F2 para apartarlo o volverlo a traer durante la prueba.
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F2 then
			gui.Enabled = not gui.Enabled
		end
	end)
end

return AdminMenu
