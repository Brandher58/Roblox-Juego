--!strict
-- Panel de subida de nivel. Es presentacion pura: muestra las ofertas que envia el
-- servidor y devuelve el identificador elegido. La carta se aplica en el servidor.
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Types = require(Shared:WaitForChild("Types"))
local UIKit = require(script.Parent.UIKit)

type UpgradeOffer = Types.UpgradeOffer

local GAP = Config.UI.CardGap
local MIN_CARD_WIDTH = 150
local SIDE_MARGIN = 24

local CARD_BG = Color3.fromRGB(19, 21, 28)
local MUTED = Color3.fromRGB(158, 165, 178)

local gui: ScreenGui? = nil
local row: Frame? = nil
local onChoose: ((string) -> ())? = nil
local current: { UpgradeOffer } = {}

local function viewport(): Vector2
	local camera = workspace.CurrentCamera
	return if camera then camera.ViewportSize else Vector2.new(1280, 720)
end

local function clearCards()
	if not row then
		return
	end
	for _, child in row:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- Tarjeta de una oferta. El hueco y el centrado los pone un UIListLayout, no una
-- cuenta de posiciones: asi el grupo queda centrado para cualquier numero de cartas
-- y en cualquier viewport sin tocar la aritmetica.
local function buildCard(offer: UpgradeOffer, size: UDim2, index: number): TextButton
	local color = UIKit.rarityColor(offer.Rarity)

	local card = UIKit.frame(row :: Instance, "Card", size, UDim2.new(0, 0, 0, 0), Vector2.new(0, 0), CARD_BG)
	card.LayoutOrder = index
	local stroke = UIKit.stroke(card, color, 2)

	-- Tinte de raton/mando. Se crea antes que las etiquetas para quedar detras de ellas.
	local hover = UIKit.frame(card, "Hover", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), nil, color)
	hover.BackgroundTransparency = 1

	local button = Instance.new("TextButton")
	button.Name = "Pick"
	button.Size = UDim2.new(1, 0, 1, 0)
	button.BackgroundTransparency = 1
	button.Text = ""
	button.AutoButtonColor = false
	button.Parent = card

	local strip = UIKit.frame(card, "Rarity", UDim2.new(1, 0, 0, 5), UDim2.new(0, 0, 0, 0), nil, color)
	strip.BackgroundTransparency = 0

	local icon = UIKit.label(card, "Icon", offer.Icon, UDim2.new(1, 0, 0, 74), UDim2.new(0, 0, 0, 16))
	icon.TextSize = 46
	icon.TextXAlignment = Enum.TextXAlignment.Center

	local name = UIKit.label(card, "Name", offer.Name, UDim2.new(1, -16, 0, 28), UDim2.new(0, 8, 0, 92))
	name.TextSize = 21
	name.TextXAlignment = Enum.TextXAlignment.Center

	local levelText = if offer.Kind == "NewWeapon"
		then "NUEVA ARMA"
		else `{offer.CurrentLevel}  >  {offer.NextLevel}`
	local levelLabel = UIKit.label(
		card,
		"Level",
		levelText,
		UDim2.new(1, -16, 0, 20),
		UDim2.new(0, 8, 0, 122),
		nil,
		color,
		true
	)
	levelLabel.TextSize = 14
	levelLabel.TextXAlignment = Enum.TextXAlignment.Center

	local rarityLabel = UIKit.label(
		card,
		"Rarity",
		string.upper(offer.Rarity),
		UDim2.new(1, -16, 0, 16),
		UDim2.new(0, 8, 0, 144),
		nil,
		MUTED
	)
	rarityLabel.TextSize = 11
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Center

	local description = UIKit.label(
		card,
		"Description",
		offer.Description,
		UDim2.new(1, -22, 1, -212),
		UDim2.new(0, 11, 0, 168)
	)
	description.TextSize = 14
	description.TextColor3 = Color3.fromRGB(186, 192, 204)
	description.TextXAlignment = Enum.TextXAlignment.Center

	-- Atajo de teclado: en PC es la forma mas rapida de elegir, y el numero coincide con
	-- la posicion de la carta.
	local badge = UIKit.frame(
		card,
		"Badge",
		UDim2.fromOffset(24, 24),
		UDim2.new(1, -34, 1, -34),
		Vector2.new(0, 0),
		Color3.fromRGB(32, 35, 44)
	)
	local badgeLabel =
		UIKit.label(badge, "Text", tostring(index), UDim2.new(1, 0, 1, 0), nil, nil, color, true)
	badgeLabel.TextSize = 13
	badgeLabel.TextXAlignment = Enum.TextXAlignment.Center

	local function choose()
		if onChoose then
			onChoose(offer.Id)
		end
	end

	local function setHover(entered: boolean)
		hover.BackgroundTransparency = if entered then 0.88 else 1
		stroke.Thickness = if entered then 3 else 2
	end

	button.Activated:Connect(choose)
	button.MouseEnter:Connect(function()
		setHover(true)
	end)
	button.MouseLeave:Connect(function()
		setHover(false)
	end)
	button.MouseButton1Down:Connect(function()
		setHover(true)
	end)
	button.Selectable = true
	return button
end

local LevelUpPanel = {}

function LevelUpPanel.build(chooseHandler: (string) -> ())
	onChoose = chooseHandler

	gui = UIKit.screen("LevelUpPanel", 20)
	gui.Enabled = false

	local dim =
		UIKit.frame(gui, "Dim", UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), nil, Color3.fromRGB(7, 8, 12))
	dim.BackgroundTransparency = 0.45

	local title = UIKit.label(
		gui,
		"Title",
		"NIVEL SUPERADO",
		UDim2.new(1, 0, 0, 46),
		UDim2.new(0, 0, 0.2, 0),
		nil,
		Config.UI.Accent,
		true
	)
	title.TextSize = 34
	title.TextXAlignment = Enum.TextXAlignment.Center

	local subtitle = UIKit.label(
		gui,
		"Subtitle",
		"Elige una mejora",
		UDim2.new(1, 0, 0, 22),
		UDim2.new(0, 0, 0.2, 46),
		nil,
		MUTED
	)
	subtitle.TextSize = 16
	subtitle.TextXAlignment = Enum.TextXAlignment.Center

	row = UIKit.frame(
		gui,
		"Row",
		UDim2.new(1, -SIDE_MARGIN * 2, 0.5, 0),
		UDim2.new(0.5, 0, 0.55, 0),
		Vector2.new(0.5, 0.5)
	)
	row.BackgroundTransparency = 1

	-- El centrado lo hace el layout, no la posicion de cada carta: asi el grupo queda
	-- centrado con 3 o con 4 ofertas y en cualquier resolucion sin aritmetica.
	local layout = Instance.new("UIListLayout")
	layout.Name = "Layout"
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, GAP)
	layout.Parent = row

	-- En movil y consola las cartas cambian de tamano; reconstruirlas es mas barato
	-- que mantener un layout manual sincronizado con el viewport.
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if #current > 0 then
				LevelUpPanel.show(current)
			end
		end)
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed or #current == 0 then
			return
		end
		local index = if input.KeyCode == Enum.KeyCode.One
			then 1
			elseif input.KeyCode == Enum.KeyCode.Two then 2
			elseif input.KeyCode == Enum.KeyCode.Three then 3
			elseif input.KeyCode == Enum.KeyCode.Four then 4
			else nil
		if index and current[index] then
			onChoose(current[index].Id)
		end
	end)
end

function LevelUpPanel.show(offers: { UpgradeOffer })
	if not gui or not row then
		return
	end

	current = offers
	clearCards()

	local size = viewport()
	local count = math.max(1, #offers)
	local available = size.X - SIDE_MARGIN * 2 - GAP * (count - 1)
	local width = math.clamp(available / count, MIN_CARD_WIDTH, Config.UI.CardWidth)
	local height = math.min(Config.UI.CardHeight, size.Y * 0.55)
	local cardSize = UDim2.fromOffset(width, height)

	local firstButton: TextButton? = nil
	for index, offer in offers do
		local button = buildCard(offer, cardSize, index)
		firstButton = firstButton or button
	end

	gui.Enabled = true
	GuiService.SelectedObject = firstButton
end

function LevelUpPanel.hide()
	if not gui then
		return
	end
	current = {}
	gui.Enabled = false
	GuiService.SelectedObject = nil
	clearCards()
end

return LevelUpPanel
