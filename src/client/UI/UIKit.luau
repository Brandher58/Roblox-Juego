--!strict
-- Fábrica mínima de widgets. Solo crea instancias y aplica propiedades: no guarda
-- estado de juego ni decide qué se muestra. Quien lo usa (Hud, LevelUpPanel) es
-- dueño de sus referencias y de su limpieza.
local Players = game:GetService("Players")

local UIKit = {}

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local FONT_BOLD = Enum.Font.GothamBold
local FONT = Enum.Font.Gotham

local RARITY_COLORS = {
	Common = Color3.fromRGB(198, 205, 214),
	Uncommon = Color3.fromRGB(108, 214, 122),
	Rare = Color3.fromRGB(96, 168, 255),
	Epic = Color3.fromRGB(196, 116, 255),
	Legendary = Color3.fromRGB(255, 186, 66),
}

function UIKit.rarityColor(rarity: string): Color3
	return RARITY_COLORS[rarity] or RARITY_COLORS.Common
end

function UIKit.screen(name: string, displayOrder: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = displayOrder
	gui.Parent = playerGui
	return gui
end

function UIKit.frame(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2,
	anchor: Vector2?,
	color: Color3?
): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.AnchorPoint = anchor or Vector2.new(0, 0)
	frame.BackgroundColor3 = color or Color3.fromRGB(16, 18, 24)
	frame.BackgroundTransparency = if color then 0 else 0.35
	frame.BorderSizePixel = 0
	frame.Parent = parent
	UIKit.corner(frame, UDim.new(0, 10))
	return frame
end

function UIKit.corner(frame: Frame, radius: UDim)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius
	corner.Parent = frame
	return corner
end

function UIKit.stroke(frame: Frame, color: Color3, thickness: number)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = 0.35
	stroke.Parent = frame
	return stroke
end

function UIKit.label(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	color: Color3?,
	bold: boolean?,
	alignment: Enum.TextXAlignment?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position or UDim2.new(0, 0, 0, 0)
	label.AnchorPoint = anchor or Vector2.new(0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(235, 238, 245)
	label.TextSize = 18
	label.Font = if bold then FONT_BOLD else FONT
	label.TextXAlignment = alignment or Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextWrapped = true
	label.Parent = parent
	return label
end

-- Barra con relleno: devuelve el frame raíz y el relleno para poder actualizarlo sin
-- volver a buscar por nombre en cada frame.
function UIKit.bar(
	parent: Instance,
	name: string,
	height: number,
	color: Color3
): { Root: Frame, Fill: Frame }
	local root = UIKit.frame(
		parent,
		name,
		UDim2.new(1, 0, 0, height),
		UDim2.new(0, 0, 0, 0),
		nil,
		Color3.fromRGB(30, 32, 40)
	)
	UIKit.corner(root, UDim.new(1, 0))

	local fill = UIKit.frame(root, "Fill", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), nil, color)
	UIKit.corner(fill, UDim.new(1, 0))
	return { Root = root, Fill = fill }
end

return UIKit
