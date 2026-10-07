--!strict
-- Menú de administración del cliente, SOLO en Studio. Botones de playtest que
-- envían comandos al servidor; el servidor valida cada uno (Admin.luau), el menú
-- solo pide. Se alterna con F2 y no se construye en builds de producción.
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local UIKit = require(script.Parent.Parent.UI.UIKit)

local AdminMenu = {}

local ROW_HEIGHT = 34
local GAP = 6
local TITLE_HEIGHT = 32

local function button(parent: Frame, y: number, text: string, command: string, value: unknown?)
	local row = Instance.new("TextButton")
	row.Name = command
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.Position = UDim2.new(0, 0, 0, y)
	row.AnchorPoint = Vector2.new(0, 0)
	row.BackgroundColor3 = Color3.fromRGB(40, 46, 60)
	row.BackgroundTransparency = 0.1
	row.BorderSizePixel = 0
	row.Text = text
	row.TextColor3 = Color3.fromRGB(235, 238, 245)
	row.TextSize = 15
	row.Font = Enum.Font.GothamBold
	row.AutoButtonColor = true
	row.Parent = parent
	UIKit.corner(row, UDim.new(0, 6))
	row.Activated:Connect(function()
		Remotes.AdminCommand:FireServer(command, value)
	end)
end

function AdminMenu.build()
	if not RunService:IsStudio() then
		return
	end

	local width = 230
	local height = TITLE_HEIGHT + ROW_HEIGHT * 4 + GAP * 3
	local gui = UIKit.screen("AdminMenu", 60)
	local bar = UIKit.frame(
		gui,
		"Bar",
		UDim2.new(0, width, 0, height),
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

	button(bar, TITLE_HEIGHT, "Desbloquear todo", "unlock_all")
	button(bar, TITLE_HEIGHT + (ROW_HEIGHT + GAP) * 1, "Armas y mejoras al tope", "max_all")
	button(bar, TITLE_HEIGHT + (ROW_HEIGHT + GAP) * 2, "+500 XP", "grant_xp", 500)
	button(bar, TITLE_HEIGHT + (ROW_HEIGHT + GAP) * 3, "Curar", "heal")

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
