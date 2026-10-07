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

local ROW = 28
local GAP = 4
local TITLE_HEIGHT = 34
local MAIN_BUTTONS = 4
local PANEL_WIDTH = 310
local PANEL_HEIGHT = 560

local weaponLevelLabels: { [string]: TextLabel } = {}
local upgradeLevelLabels: { [string]: TextLabel } = {}

local function mainButton(parent: Frame, y: number, text: string, command: string, value: unknown?)
	local row = Instance.new("TextButton")
	row.Name = command
	row.Size = UDim2.new(1, -16, 0, ROW)
	row.Position = UDim2.new(0, 8, 0, y)
	row.BackgroundColor3 = Color3.fromRGB(38, 44, 58)
	row.BackgroundTransparency = 0.08
	row.BorderSizePixel = 0
	row.Text = text
	row.TextColor3 = Color3.fromRGB(230, 235, 245)
	row.TextSize = 14
	row.Font = Enum.Font.GothamBold
	row.AutoButtonColor = true
	row.Parent = parent
	UIKit.corner(row, UDim.new(0, 8))
	row.Activated:Connect(function()
		Remotes.AdminCommand:FireServer(command, value)
	end)
end

--Header within the scrolling list: small, muted, uppercase.
local function section(parent: Instance, text: string)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -16, 0, 18)
	label.BackgroundTransparency = 1
	label.Text = "—— " .. string.upper(text) .. " ——"
	label.TextColor3 = Color3.fromRGB(114, 124, 148)
	label.TextSize = 10
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = parent
end

-- Row inside the scrolling list: name on the left, current level in the middle,
-- and a "+1" button that asks the server for exactly one more level.
local function itemRow(parent: Instance, name: string, command: string, id: string)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -4, 0, ROW)
	row.BackgroundColor3 = Color3.fromRGB(34, 40, 54)
	row.BackgroundTransparency = 0.12
	row.BorderSizePixel = 0
	row.Parent = parent
	UIKit.corner(row, UDim.new(0, 6))

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
	nameLabel.Position = UDim2.new(0, 10, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = name
	nameLabel.TextColor3 = Color3.fromRGB(228, 232, 240)
	nameLabel.TextSize = 13
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local lvl = Instance.new("TextLabel")
	lvl.Size = UDim2.new(0.2, 0, 1, 0)
	lvl.Position = UDim2.new(0.58, 0, 0, 0)
	lvl.BackgroundTransparency = 1
	lvl.Text = "0"
	lvl.TextColor3 = Color3.fromRGB(155, 165, 190)
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
	btn.Size = UDim2.new(0.18, 0, 0.7, 0)
	btn.Position = UDim2.new(0.8, 0, 0.15, 0)
	btn.BackgroundColor3 = Color3.fromRGB(58, 118, 215)
	btn.BorderSizePixel = 0
	btn.Text = "+1"
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.TextSize = 13
	btn.Font = Enum.Font.GothamBold
	btn.AutoButtonColor = true
	btn.Parent = row
	UIKit.corner(btn, UDim.new(0, 6))
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
	UIKit.corner(bar, UDim.new(0, 10))
	UIKit.stroke(bar, Color3.fromRGB(255, 214, 92), 1)

	-- Título de la barra
	UIKit.label(
		bar,
		"Title",
		"DEV · ADMIN",
		UDim2.new(1, -16, 0, 20),
		UDim2.new(0, 12, 0, 7),
		nil,
		Color3.fromRGB(255, 214, 92),
		true
	)

	UIKit.label(
		bar,
		"Subtitle",
		"+1 por arma / mejora · F2 para ocultar",
		UDim2.new(1, -16, 0, 14),
		UDim2.new(0, 12, 0, 24),
		nil,
		Color3.fromRGB(140, 150, 170),
		false
	)

	mainButton(bar, TITLE_HEIGHT, "Desbloquear todo", "unlock_all")
	mainButton(bar, TITLE_HEIGHT + (ROW + GAP), "Armas y mejoras al tope", "max_all")
	mainButton(bar, TITLE_HEIGHT + (ROW + GAP) * 2, "+500 XP", "grant_xp", 500)
	mainButton(bar, TITLE_HEIGHT + (ROW + GAP) * 3, "Curar", "heal")

	-- Lista desplazable de armas y mejoras.
	local list = Instance.new("ScrollingFrame")
	list.Name = "WeaponList"
	list.Size = UDim2.new(1, -24, 1, -TITLE_HEIGHT - 20 - MAIN_BUTTONS * (ROW + GAP) - GAP)
	list.Position = UDim2.new(0, 12, 0, TITLE_HEIGHT + 20 + MAIN_BUTTONS * (ROW + GAP))
	list.BackgroundColor3 = Color3.fromRGB(11, 13, 19)
	list.BackgroundTransparency = 0.35
	list.BorderSizePixel = 0
	list.CanvasSize = UDim2.new(0, 0, 0, 0)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 8
	list.Parent = bar
	UIKit.corner(list, UDim.new(0, 6))

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = list

	section(list, "Armas")
	for weaponId, weapon in pairs(Registry.Weapons) do
		itemRow(list, weapon.Name, "level_up", weaponId)
	end

	section(list, "Mejoras")
	for upgradeId, upgrade in pairs(Registry.Upgrades) do
		if upgrade.Kind == "NewWeapon" then
			continue
		end
		itemRow(list, upgrade.Name, "upgrade_level_up", upgradeId)
	end

	-- Refresca el nivel actual de cada fila cuando el servidor empuja un
	-- snapshot nuevo.
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
