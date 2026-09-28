--[[
	TraitMachineClient
	------------------
	UI de la Trait Machine (prompt "TraitMachinePrompt" de
	Workspace.TraitMachine) + animation des rouleaux / tableau ODDS du
	modele dans le monde. Logique serveur : ServerScriptService.Traits.TraitService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local TraitShared = require(ReplicatedStorage:WaitForChild("Traits"):WaitForChild("TraitShared"))
local Inv = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("InventoryShared"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local remote = ReplicatedStorage.Traits:WaitForChild("TraitRemote") :: RemoteFunction
local event = ReplicatedStorage.Traits:WaitForChild("TraitEvent") :: RemoteEvent

local FONT_TITLE = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local ROBUX = utf8.char(0xE002)
local STUDS = "rbxassetid://6372755229"

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local YELLOW = Color3.fromRGB(255, 222, 40)
local GREEN = Color3.fromRGB(60, 230, 60)
local RED = Color3.fromRGB(235, 70, 70)
local PURPLE = Color3.fromRGB(190, 70, 255)

local RARITY_NAMES = Inv.RARITY

local MUTATION_COLORS = {
	Gold = Color3.fromRGB(255, 205, 40), Diamond = Color3.fromRGB(80, 210, 255), Ruby = Color3.fromRGB(255, 50, 90),
	Lava = Color3.fromRGB(255, 110, 20), Galaxy = Color3.fromRGB(170, 100, 255), Hacker = Color3.fromRGB(40, 240, 90),
	Rainbow = Color3.fromRGB(255, 120, 220), Admin = Color3.fromRGB(80, 80, 88),
}

--== Helpers ==--
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
	return c
end
local function stroke(p, t, color, mode)
	local s = Instance.new("UIStroke")
	s.Thickness = t
	s.Color = color or BLACK
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = p
	return s
end
local function textStroke(p, t)
	return stroke(p, t, BLACK, Enum.ApplyStrokeMode.Contextual)
end
local function gradient(p, a, b, rot)
	local g = Instance.new("UIGradient")
	g.Color = typeof(a) == "ColorSequence" and a or ColorSequence.new(a, b)
	g.Rotation = rot or 90
	g.Parent = p
	return g
end
local function tween(i, t, props, style, dir)
	local tw = TweenService:Create(i, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function studs(p, radius, tile, transp)
	local img = Instance.new("ImageLabel")
	img.Name = "Studs"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = STUDS
	img.ScaleType = Enum.ScaleType.Tile
	img.TileSize = UDim2.fromOffset(tile or 40, tile or 40)
	img.ImageColor3 = BLACK
	img.ImageTransparency = transp or 0.8
	img.ZIndex = p.ZIndex
	img.Parent = p
	corner(img, radius)
	return img
end
local function text(parent, str, size, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font or FONT
	l.Text = str
	l.TextSize = size
	l.TextColor3 = color or WHITE
	l.ZIndex = (parent:IsA("GuiObject") and parent.ZIndex or 1) + 1
	l.Parent = parent
	textStroke(l, math.max(1.5, size / 11))
	return l
end
local function pressable(b: GuiButton, hover)
	local s = Instance.new("UIScale")
	s.Parent = b
	local h = hover or 1.05
	local over = false
	b.MouseEnter:Connect(function() over = true tween(s, 0.12, { Scale = h }) end)
	b.MouseLeave:Connect(function() over = false tween(s, 0.12, { Scale = 1 }) end)
	b.MouseButton1Down:Connect(function() tween(s, 0.07, { Scale = h * 0.92 }) end)
	b.MouseButton1Up:Connect(function() tween(s, 0.12, { Scale = over and h or 1 }) end)
	return s
end
local function bigButton(parent, label, color, size)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = WHITE
	b.ZIndex = (parent.ZIndex or 1) + 1
	b.Parent = parent
	corner(b, 10)
	stroke(b, 4)
	gradient(b, color:Lerp(WHITE, 0.15), color:Lerp(BLACK, 0.3))
	studs(b, 10, 26, 0.82)
	local l = text(b, label, size or 30, WHITE, FONT_TITLE)
	l.Name = "Label"
	l.Size = UDim2.fromScale(1, 1)
	l.ZIndex = b.ZIndex + 2
	pressable(b)
	return b, l
end
local function traitIconText(t)
	return t.emoji
end

--== ScreenGui ==--
local gui = Instance.new("ScreenGui")
gui.Name = "TraitMachineGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 12
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = BLACK
overlay.BackgroundTransparency = 1
overlay.Parent = gui

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.52)
root.Size = UDim2.fromOffset(1250, 640)
root.BackgroundTransparency = 1
root.Parent = gui
local rootScale = Instance.new("UIScale")
rootScale.Parent = root


local MAIN_W, MAIN_H = 1000, 640
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(MAIN_W, MAIN_H)
main.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
main.BackgroundTransparency = 0.18
main.Active = true
main.Parent = root
corner(main, 14)
stroke(main, 5)
studs(main, 14, 48, 0.86)

local header = Instance.new("Frame")
header.Name = "Header"
header.Position = UDim2.fromOffset(8, 8)
header.Size = UDim2.new(1, -16, 0, 86)
header.BackgroundColor3 = WHITE
header.ZIndex = 2
header.Parent = main
corner(header, 10)
stroke(header, 4)
gradient(header, Color3.fromRGB(255, 238, 70), Color3.fromRGB(255, 196, 0))
studs(header, 10, 30, 0.8)

local star = text(header, "⭐", 56, WHITE)
star.Position = UDim2.fromOffset(14, 0)
star.Size = UDim2.fromOffset(80, 86)
star.ZIndex = 4
local titleLabel = text(header, "TRAIT MACHINE", 62, WHITE, FONT_TITLE)
titleLabel.Position = UDim2.fromOffset(100, 4)
titleLabel.Size = UDim2.new(1, -200, 1, 0)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 4
titleLabel:FindFirstChildOfClass("UIStroke").Thickness = 5

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -12, 0.5, 0)
closeButton.Size = UDim2.fromOffset(66, 62)
closeButton.BackgroundColor3 = WHITE
closeButton.Text = ""
closeButton.AutoButtonColor = false
closeButton.ZIndex = 4
closeButton.Parent = header
corner(closeButton, 8)
stroke(closeButton, 4)
gradient(closeButton, Color3.fromRGB(255, 120, 120), Color3.fromRGB(210, 40, 40))
local cx = text(closeButton, "X", 44, WHITE, FONT_TITLE)
cx.Size = UDim2.fromScale(1, 1)
cx.ZIndex = 6
pressable(closeButton, 1.08)

local selectTitle = text(main, "SELECT UP TO 4 BRAINROTS:", 44, WHITE, FONT_TITLE)
selectTitle.Position = UDim2.fromOffset(0, 104)
selectTitle.Size = UDim2.new(1, 0, 0, 50)
selectTitle.ZIndex = 3

local slotsBox = Instance.new("Frame")
slotsBox.Name = "Slots"
slotsBox.Position = UDim2.fromOffset(50, 164)
slotsBox.Size = UDim2.new(1, -100, 0, 300)
slotsBox.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
slotsBox.BackgroundTransparency = 0.35
slotsBox.ZIndex = 2
slotsBox.Parent = main
corner(slotsBox, 10)
stroke(slotsBox, 4)
local slotsLayout = Instance.new("UIListLayout")
slotsLayout.FillDirection = Enum.FillDirection.Horizontal
slotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
slotsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
slotsLayout.Padding = UDim.new(0, 18)
slotsLayout.SortOrder = Enum.SortOrder.LayoutOrder
slotsLayout.Parent = slotsBox

local costLabel = text(main, "COST: $0", 34, Color3.fromRGB(190, 255, 60), FONT_TITLE)
costLabel.AnchorPoint = Vector2.new(0.5, 1)
costLabel.Position = UDim2.new(0.5, 0, 0, 512)
costLabel.Size = UDim2.fromOffset(420, 40)
costLabel.ZIndex = 6

local removeAll = bigButton(main, "REMOVE ALL", Color3.fromRGB(235, 60, 70), 28)
removeAll.AnchorPoint = Vector2.new(0.5, 0)
removeAll.Position = UDim2.new(0.5, -300, 0, 520)
removeAll.Size = UDim2.fromOffset(250, 84)

local rollButton, rollLabel = bigButton(main, "ROLL", Color3.fromRGB(80, 240, 40), 58)
rollButton.AnchorPoint = Vector2.new(0.5, 0)
rollButton.Position = UDim2.new(0.5, 0, 0, 512)
rollButton.Size = UDim2.fromOffset(310, 100)

local autoButton = bigButton(main, "AUTO", PURPLE, 44)
autoButton.AnchorPoint = Vector2.new(0.5, 0)
autoButton.Position = UDim2.new(0.5, 300, 0, 520)
autoButton.Size = UDim2.fromOffset(250, 84)
local autoTag = text(autoButton, "OFF", 34, RED, FONT_TITLE)
autoTag.AnchorPoint = Vector2.new(1, 0.5)
autoTag.Position = UDim2.new(1, 12, 0, -2)
autoTag.Size = UDim2.fromOffset(90, 40)
autoTag.Rotation = 8
autoTag.ZIndex = autoButton.ZIndex + 4

local toast = text(main, "", 28, WHITE, FONT_TITLE)
toast.AnchorPoint = Vector2.new(0.5, 0.5)
toast.Position = UDim2.new(0.5, 0, 0, 314)
toast.Size = UDim2.fromOffset(620, 54)
toast.ZIndex = 40
toast.BackgroundColor3 = BLACK
toast.BackgroundTransparency = 0.25
toast.Visible = false
corner(toast, 12)
local toastToken = 0
local function showToast(msg, color)
	toastToken += 1
	local my = toastToken
	toast.Text = msg
	toast.TextColor3 = color or WHITE
	toast.Visible = true
	toast.TextTransparency = 0
	local s = toast:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	s.Parent = toast
	s.Scale = 0.7
	tween(s, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(2, function()
		if my == toastToken then
			toast.Visible = false
		end
	end)
end

--== Colonne droite : ODDS + LUCK ==--
local side = Instance.new("Frame")
side.Name = "Side"
side.Position = UDim2.fromOffset(MAIN_W + 12, 0)
side.Size = UDim2.fromOffset(238, MAIN_H)
side.BackgroundTransparency = 1
side.Parent = root

local odds = Instance.new("Frame")
odds.Name = "Odds"
odds.Size = UDim2.fromOffset(238, 300)
odds.BackgroundColor3 = Color3.fromRGB(28, 28, 32)
odds.BackgroundTransparency = 0.1
odds.Active = true
odds.Parent = side
corner(odds, 10)
stroke(odds, 4)
local oddsTitle = text(odds, "ODDS:", 30, WHITE, FONT_TITLE)
oddsTitle.Size = UDim2.new(1, 0, 0, 40)
oddsTitle.Position = UDim2.fromOffset(0, 4)
local oddsList = Instance.new("Frame")
oddsList.BackgroundTransparency = 1
oddsList.Position = UDim2.fromOffset(10, 44)
oddsList.Size = UDim2.new(1, -20, 1, -50)
oddsList.Parent = odds
local ol = Instance.new("UIListLayout")
ol.SortOrder = Enum.SortOrder.LayoutOrder
ol.Padding = UDim.new(0, 2)
ol.Parent = oddsList
local oddsRows = {}
for i, t in ipairs(TraitShared.TRAITS) do
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.LayoutOrder = i
	row.Size = UDim2.new(1, 0, 0, 30)
	row.Parent = oddsList
	local ic = text(row, traitIconText(t), 24, WHITE)
	ic.Size = UDim2.fromOffset(34, 34)
	local m = text(row, TraitShared.FormatMult(t.mult), 26, t.color, FONT_TITLE)
	m.Position = UDim2.fromOffset(38, 0)
	m.Size = UDim2.fromOffset(70, 34)
	m.TextXAlignment = Enum.TextXAlignment.Left
	local o = text(row, "1/" .. t.odds, 24, WHITE, FONT_TITLE)
	o.AnchorPoint = Vector2.new(1, 0)
	o.Position = UDim2.new(1, 0, 0, 0)
	o.Size = UDim2.fromOffset(110, 34)
	o.TextXAlignment = Enum.TextXAlignment.Right
	oddsRows[t.key] = o
end

odds.Size = UDim2.fromOffset(238, 268)
local luckPanel = Instance.new("Frame")
luckPanel.Name = "Luck"
luckPanel.Active = true
luckPanel.Position = UDim2.fromOffset(0, 278)
luckPanel.Size = UDim2.fromOffset(238, 362)
luckPanel.BackgroundColor3 = WHITE
luckPanel.Parent = side
corner(luckPanel, 10)
stroke(luckPanel, 4)
gradient(luckPanel, Color3.fromRGB(255, 238, 70), Color3.fromRGB(255, 190, 0))
studs(luckPanel, 10, 28, 0.82)
local luckTitle = text(luckPanel, ("%dx LUCK"):format(TraitShared.LUCK_MULT), 40, WHITE, FONT_TITLE)
luckTitle.Position = UDim2.fromOffset(0, 6)
luckTitle.Size = UDim2.new(1, 0, 0, 46)
luckTitle.ZIndex = 3

local PACK_COLORS = {
	{ Color3.fromRGB(120, 255, 60), Color3.fromRGB(40, 190, 30) },
	{ Color3.fromRGB(215, 120, 255), Color3.fromRGB(150, 40, 220) },
	"rainbow",
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(60, 230, 90)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 150, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 70, 255)),
})
local rainbowGrads = {}
for i, p in ipairs(TraitShared.LUCK_PRODUCTS) do
	local b = Instance.new("TextButton")
	b.Name = "Pack" .. p.rolls
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = WHITE
	b.Position = UDim2.fromOffset(12, 56 + (i - 1) * 76)
	b.Size = UDim2.new(1, -24, 0, 66)
	b.ZIndex = 3
	b.Parent = luckPanel
	corner(b, 8)
	stroke(b, 3.5)
	local c = PACK_COLORS[i]
	if c == "rainbow" then
		table.insert(rainbowGrads, gradient(b, RAINBOW, nil, 0))
	else
		gradient(b, c[1], c[2])
	end
	local price = text(b, ROBUX .. " " .. p.price, 34, WHITE, FONT_TITLE)
	price.Name = "Price"
	price.Size = UDim2.new(1, 0, 0, 40)
	price.Position = UDim2.fromOffset(0, 2)
	price.ZIndex = 5
	local sub = text(b, ("x%d Roll%s"):format(p.rolls, p.rolls > 1 and "s" or ""), 22, Color3.fromRGB(255, 70, 70), FONT_TITLE)
	sub.Position = UDim2.fromOffset(0, 38)
	sub.Size = UDim2.new(1, 0, 0, 24)
	sub.ZIndex = 5
	pressable(b, 1.04)
	if p.id ~= 0 then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(p.id, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				price.Text = ROBUX .. " " .. info.PriceInRobux
			end
		end)
	end
	b.MouseButton1Click:Connect(function()
		UISounds.Play("Click")
		local ok = remote:InvokeServer("BuyLuck", p.rolls)
		if not ok then
			UISounds.Play("BuyFail")
			showToast("COMING SOON!", YELLOW)
		end
	end)
end

local luckInfo = text(luckPanel, "", 20, WHITE, FONT_TITLE)
luckInfo.AnchorPoint = Vector2.new(0.5, 1)
luckInfo.Position = UDim2.new(0.5, 0, 1, -6)
luckInfo.Size = UDim2.new(1, -16, 0, 26)
luckInfo.ZIndex = 4

local useLuckButton = Instance.new("TextButton")
useLuckButton.Name = "UseLuck"
useLuckButton.AutoButtonColor = false
useLuckButton.Text = ""
useLuckButton.AnchorPoint = Vector2.new(0.5, 1)
useLuckButton.Position = UDim2.new(0.5, 0, 1, -36)
useLuckButton.Size = UDim2.new(1, -24, 0, 30)
useLuckButton.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
useLuckButton.ZIndex = 4
useLuckButton.Parent = luckPanel
corner(useLuckButton, 8)
stroke(useLuckButton, 3)
local useLuckLabel = text(useLuckButton, "", 18, WHITE, FONT_TITLE)
useLuckLabel.Size = UDim2.fromScale(1, 1)
useLuckLabel.ZIndex = 6
pressable(useLuckButton, 1.04)

--== Picker ==--
local picker = Instance.new("Frame")
picker.Name = "Picker"
picker.AnchorPoint = Vector2.new(0.5, 0.5)
picker.Position = UDim2.fromScale(0.5, 0.5)
picker.Size = UDim2.fromOffset(820, 470)
picker.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
picker.Visible = false
picker.Active = true
picker.ZIndex = 50
picker.Parent = main
corner(picker, 12)
stroke(picker, 5)
studs(picker, 12, 40, 0.85)
local pickTitle = text(picker, "CHOOSE A BRAINROT", 38, YELLOW, FONT_TITLE)
pickTitle.Position = UDim2.fromOffset(20, 8)
pickTitle.Size = UDim2.new(1, -110, 0, 50)
pickTitle.TextXAlignment = Enum.TextXAlignment.Left
pickTitle.ZIndex = 52
local pickClose = Instance.new("TextButton")
pickClose.AnchorPoint = Vector2.new(1, 0)
pickClose.Position = UDim2.new(1, -12, 0, 12)
pickClose.Size = UDim2.fromOffset(50, 46)
pickClose.BackgroundColor3 = WHITE
pickClose.Text = ""
pickClose.AutoButtonColor = false
pickClose.ZIndex = 52
pickClose.Parent = picker
corner(pickClose, 8)
stroke(pickClose, 3.5)
gradient(pickClose, Color3.fromRGB(255, 120, 120), Color3.fromRGB(210, 40, 40))
local pcx = text(pickClose, "X", 32, WHITE, FONT_TITLE)
pcx.Size = UDim2.fromScale(1, 1)
pcx.ZIndex = 54
pressable(pickClose, 1.08)
local pickEmpty = text(picker, "No brainrots in your inventory!", 26, Color3.fromRGB(200, 200, 205), FONT_TITLE)
pickEmpty.AnchorPoint = Vector2.new(0.5, 0.5)
pickEmpty.Position = UDim2.fromScale(0.5, 0.55)
pickEmpty.Size = UDim2.new(1, -40, 0, 40)
pickEmpty.ZIndex = 52
pickEmpty.Visible = false
local pickGrid = Instance.new("ScrollingFrame")
pickGrid.Position = UDim2.fromOffset(14, 66)
pickGrid.Size = UDim2.new(1, -28, 1, -80)
pickGrid.BackgroundTransparency = 1
pickGrid.BorderSizePixel = 0
pickGrid.ScrollBarThickness = 8
pickGrid.ScrollBarImageColor3 = BLACK
pickGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
pickGrid.CanvasSize = UDim2.new()
pickGrid.ZIndex = 52
pickGrid.Parent = picker
local pgl = Instance.new("UIGridLayout")
pgl.CellSize = UDim2.fromOffset(142, 176)
pgl.CellPadding = UDim2.fromOffset(12, 12)
pgl.HorizontalAlignment = Enum.HorizontalAlignment.Center
pgl.SortOrder = Enum.SortOrder.LayoutOrder
pgl.Parent = pickGrid
local pgp = Instance.new("UIPadding")
pgp.PaddingTop = UDim.new(0, 6)
pgp.PaddingBottom = UDim.new(0, 6)
pgp.Parent = pickGrid

--== Cartes ==--
local function incomeOf(tool: Tool): number
	return tool:GetAttribute("Income") or 0
end

local function buildCard(parent: Instance, tool: Tool, z: number, size: UDim2)
	local handle = tool:FindFirstChild("Handle")
	local rarity = Inv.GetRarity(tool)
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.Size = size
	card.BackgroundColor3 = WHITE
	card.ZIndex = z
	card.Parent = parent
	corner(card, 10)
	local cs = stroke(card, 4, rarity.color:Lerp(WHITE, 0.25))
	gradient(card, rarity.color:Lerp(BLACK, 0.2), rarity.color:Lerp(BLACK, 0.7))
	studs(card, 10, 24, 0.82)

	local mutation = handle and handle:GetAttribute("Mutation")
	local rarityText = text(card, rarity.name or "", 17, rarity.color:Lerp(WHITE, 0.35), FONT_TITLE)
	rarityText.Position = UDim2.fromOffset(8, 4)
	rarityText.Size = UDim2.new(1, -60, 0, 20)
	rarityText.TextXAlignment = Enum.TextXAlignment.Left
	rarityText.ZIndex = z + 3
	if type(mutation) == "string" then
		local m = text(card, mutation, 16, MUTATION_COLORS[mutation] or WHITE, FONT_TITLE)
		m.Position = UDim2.fromOffset(8, 22)
		m.Size = UDim2.new(1, -60, 0, 18)
		m.TextXAlignment = Enum.TextXAlignment.Left
		m.ZIndex = z + 3
	end
	local lvl = text(card, "LVL\n" .. tostring(handle and handle:GetAttribute("Level") or 1), 15, WHITE, FONT_TITLE)
	lvl.AnchorPoint = Vector2.new(1, 0)
	lvl.Position = UDim2.new(1, -6, 0, 4)
	lvl.Size = UDim2.fromOffset(50, 34)
	lvl.TextXAlignment = Enum.TextXAlignment.Right
	lvl.ZIndex = z + 3

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(6, 38)
	holder.Size = UDim2.new(1, -12, 1, -106)
	holder.ZIndex = z + 1
	holder.Parent = card
	local vp = Inv.CreateViewport(tool, holder)
	if vp then
		vp.ZIndex = z + 1
	end

	local traitRow = text(card, "", 22, WHITE, FONT_TITLE)
	traitRow.Name = "Trait"
	traitRow.AnchorPoint = Vector2.new(0.5, 1)
	traitRow.Position = UDim2.new(0.5, 0, 1, -44)
	traitRow.Size = UDim2.new(1, -10, 0, 24)
	traitRow.ZIndex = z + 3

	local inc = text(card, "", 18, Color3.fromRGB(150, 255, 70), FONT_TITLE)
	inc.Name = "Income"
	inc.AnchorPoint = Vector2.new(0.5, 1)
	inc.Position = UDim2.new(0.5, 0, 1, -22)
	inc.Size = UDim2.new(1, -10, 0, 20)
	inc.ZIndex = z + 3

	local nm = text(card, Inv.GetDisplayName(tool), 15, WHITE, FONT)
	nm.AnchorPoint = Vector2.new(0.5, 1)
	nm.Position = UDim2.new(0.5, 0, 1, -4)
	nm.Size = UDim2.new(1, -8, 0, 18)
	nm.TextTruncate = Enum.TextTruncate.AtEnd
	nm.ZIndex = z + 3

	local function refresh()
		local t = TraitShared.GetTrait(tool)
		if t then
			traitRow.Text = ("%s %s"):format(t.emoji, TraitShared.FormatMult(t.mult))
			traitRow.TextColor3 = t.color
			cs.Color = t.color
		else
			traitRow.Text = "NO TRAIT"
			traitRow.TextColor3 = Color3.fromRGB(190, 190, 195)
			cs.Color = rarity.color:Lerp(WHITE, 0.25)
		end
		inc.Text = "+$" .. NumberFormat.Format(incomeOf(tool)) .. "/s"
	end
	refresh()
	return card, refresh, traitRow
end

--== Etat ==--
local isOpen = false
local selected: { Tool } = {}
local slotFrames = {}
local auto = false
local rolling = false
local useLuck = true
local costToken = 0
local lastCost = 0

local refreshSlots

local function isSelected(tool)
	return table.find(selected, tool) ~= nil
end

local function validTools()
	local out = {}
	for _, tool in ipairs(Inv.GetItems(player)) do
		if Inv.GetItemType(tool) == Inv.TYPE_BRAINROT then
			table.insert(out, tool)
		end
	end
	table.sort(out, function(a, b)
		return incomeOf(a) > incomeOf(b)
	end)
	return out
end

local function updateLuck()
	local n = player:GetAttribute("TraitLuck") or 0
	luckInfo.Text = ("LUCKY ROLLS: %d"):format(n)
	if n > 0 then
		useLuckLabel.Text = useLuck and "🍀 USE LUCK: ON" or "USE LUCK: OFF"
		useLuckButton.BackgroundColor3 = useLuck and Color3.fromRGB(40, 190, 70) or Color3.fromRGB(60, 60, 66)
	else
		useLuckLabel.Text = "BUY LUCKY ROLLS ↑"
		useLuckButton.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
	end
	local mult = (n > 0 and useLuck) and TraitShared.LUCK_MULT or 1
	for _, t in ipairs(TraitShared.TRAITS) do
		local o = oddsRows[t.key]
		local n2 = math.max(1, math.floor(t.odds / mult + 0.5))
		o.Text = "1/" .. n2
		o.TextColor3 = mult > 1 and Color3.fromRGB(120, 255, 120) or WHITE
	end
end
player:GetAttributeChangedSignal("TraitLuck"):Connect(updateLuck)
useLuckButton.MouseButton1Click:Connect(function()
	UISounds.Play("Tab")
	useLuck = not useLuck
	updateLuck()
end)

local function updateCost()
	costToken += 1
	local my = costToken
	if #selected == 0 then
		costLabel.Text = "SELECT A BRAINROT"
		costLabel.TextColor3 = Color3.fromRGB(200, 200, 205)
		lastCost = 0
		return
	end
	task.spawn(function()
		local cost = remote:InvokeServer("GetCost", selected)
		if my ~= costToken then
			return
		end
		lastCost = tonumber(cost) or 0
		costLabel.Text = "COST: $" .. NumberFormat.Format(lastCost)
		costLabel.TextColor3 = Color3.fromRGB(190, 255, 60)
	end)
end

local function setAuto(on: boolean)
	auto = on
	autoTag.Text = on and "ON" or "OFF"
	autoTag.TextColor3 = on and Color3.fromRGB(90, 255, 90) or RED
end

local openPicker

local function makeEmptySlot(i)
	local slot = Instance.new("TextButton")
	slot.Name = "Empty"
	slot.Text = ""
	slot.AutoButtonColor = false
	slot.LayoutOrder = i
	slot.Size = UDim2.fromOffset(190, 250)
	slot.BackgroundColor3 = Color3.fromRGB(255, 225, 30)
	slot.BackgroundTransparency = 0.55
	slot.ZIndex = 4
	slot.Parent = slotsBox
	corner(slot, 8)
	stroke(slot, 4, Color3.fromRGB(255, 230, 40))
	local plus = Instance.new("Frame")
	plus.AnchorPoint = Vector2.new(0.5, 0.5)
	plus.Position = UDim2.fromScale(0.5, 0.5)
	plus.Size = UDim2.fromOffset(96, 96)
	plus.BackgroundColor3 = WHITE
	plus.ZIndex = 5
	plus.Parent = slot
	corner(plus, 8)
	stroke(plus, 4, Color3.fromRGB(20, 110, 20))
	gradient(plus, Color3.fromRGB(140, 255, 110), Color3.fromRGB(40, 190, 40))
	studs(plus, 8, 24, 0.8)
	local pl = text(plus, "+", 80, WHITE, FONT_TITLE)
	pl.Size = UDim2.fromScale(1, 1)
	pl.Position = UDim2.fromOffset(0, 6)
	pl.ZIndex = 7
	local s = pressable(slot, 1.04)
	slot.MouseButton1Click:Connect(function()
		if rolling then
			return
		end
		UISounds.Play("Click")
		openPicker()
	end)
	return slot
end

local function makeFilledSlot(i, tool)
	local holder = Instance.new("Frame")
	holder.Name = "Filled"
	holder.LayoutOrder = i
	holder.Size = UDim2.fromOffset(190, 250)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 4
	holder.Parent = slotsBox
	local card, refresh, traitRow = buildCard(holder, tool, 5, UDim2.fromScale(1, 1))
	local x = Instance.new("TextButton")
	x.AnchorPoint = Vector2.new(0.5, 0.5)
	x.Position = UDim2.new(0.5, 0, 0, -4)
	x.Size = UDim2.fromOffset(46, 42)
	x.BackgroundColor3 = WHITE
	x.Text = ""
	x.AutoButtonColor = false
	x.ZIndex = 20
	x.Parent = holder
	corner(x, 6)
	stroke(x, 3)
	gradient(x, Color3.fromRGB(255, 130, 130), Color3.fromRGB(215, 45, 45))
	local xl = text(x, "X", 30, WHITE, FONT_TITLE)
	xl.Size = UDim2.fromScale(1, 1)
	xl.ZIndex = 22
	pressable(x, 1.1)
	x.MouseButton1Click:Connect(function()
		if rolling then
			return
		end
		local idx = table.find(selected, tool)
		if idx then
			table.remove(selected, idx)
		end
		UISounds.Play("Delete")
		refreshSlots()
	end)

	local reel = Instance.new("TextLabel")
	reel.Name = "Reel"
	reel.AnchorPoint = Vector2.new(0.5, 0.5)
	reel.Position = UDim2.fromScale(0.5, 0.42)
	reel.Size = UDim2.fromOffset(120, 120)
	reel.BackgroundColor3 = BLACK
	reel.BackgroundTransparency = 1
	reel.TextScaled = true
	reel.Text = ""
	reel.ZIndex = 30
	reel.Parent = holder
	corner(reel, 60)
	local rs = Instance.new("UIScale")
	rs.Parent = reel

	local badge = text(holder, "", 26, YELLOW, FONT_TITLE)
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.5, 0.15)
	badge.Size = UDim2.new(1, 0, 0, 30)
	badge.ZIndex = 32
	badge.Visible = false

	return { holder = holder, card = card, refresh = refresh, reel = reel, reelScale = rs, badge = badge, tool = tool }
end

refreshSlots = function()
	for i = #selected, 1, -1 do
		local t = selected[i]
		if not t.Parent or not (t.Parent == player:FindFirstChildOfClass("Backpack") or t.Parent == player.Character) then
			table.remove(selected, i)
		end
	end
	for _, f in ipairs(slotFrames) do
		f.holder:Destroy()
	end
	table.clear(slotFrames)
	for i = 1, TraitShared.MAX_SELECTED do
		local tool = selected[i]
		if tool then
			slotFrames[i] = makeFilledSlot(i, tool)
		else
			slotFrames[i] = { holder = makeEmptySlot(i) }
		end
	end
	updateCost()
end

local function closePicker()
	if not picker.Visible then
		return
	end
	UISounds.Play("Swoosh")
	picker.Visible = false
end

openPicker = function()
	for _, c in ipairs(pickGrid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local list = {}
	for _, tool in ipairs(validTools()) do
		if not isSelected(tool) then
			table.insert(list, tool)
		end
	end
	pickEmpty.Visible = #list == 0
	for order, tool in ipairs(list) do
		local b = Instance.new("TextButton")
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.LayoutOrder = order
		b.ZIndex = 53
		b.Parent = pickGrid
		buildCard(b, tool, 54, UDim2.fromScale(1, 1))
		pressable(b, 1.05)
		b.MouseButton1Click:Connect(function()
			if #selected >= TraitShared.MAX_SELECTED or isSelected(tool) or not tool.Parent then
				return
			end
			table.insert(selected, tool)
			UISounds.Play("Pop")
			picker.Visible = false
			refreshSlots()
		end)
	end
	picker.Visible = true
	local s = picker:FindFirstChild("OpenScale") or Instance.new("UIScale")
	s.Name = "OpenScale"
	s.Parent = picker
	s.Scale = 0.85
	tween(s, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
	UISounds.Play("Open")
end
pickClose.MouseButton1Click:Connect(closePicker)

removeAll.MouseButton1Click:Connect(function()
	if rolling or #selected == 0 then
		return
	end
	UISounds.Play("Delete")
	table.clear(selected)
	setAuto(false)
	refreshSlots()
end)

--== Roll ==--
local TRAIT_EMOJIS = {}
for _, t in ipairs(TraitShared.TRAITS) do
	table.insert(TRAIT_EMOJIS, t.emoji)
end

local function spinReel(slot, result, delay)
	local reel, rs = slot.reel, slot.reelScale
	reel.BackgroundTransparency = 0.35
	reel.Text = TRAIT_EMOJIS[1]
	local steps = 12 + delay * 4
	for i = 1, steps do
		reel.Text = TRAIT_EMOJIS[math.random(1, #TRAIT_EMOJIS)]
		rs.Scale = 0.85
		tween(rs, 0.05, { Scale = 1 })
		if i % 2 == 0 then
			UISounds.PlayOverlap("SmallClick", 1 + i / steps * 0.6, 0.25)
		end
		task.wait(0.035 + (i / steps) ^ 2 * 0.09)
	end
	local rolled = TraitShared.Get(result.rolled)
	reel.Text = rolled and rolled.emoji or "?"
	rs.Scale = 1.5
	tween(rs, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	slot.badge.Visible = true
	if result.improved then
		slot.badge.Text = "NEW! " .. (rolled and TraitShared.FormatMult(rolled.mult) or "")
		slot.badge.TextColor3 = rolled and rolled.color or YELLOW
		UISounds.PlayOverlap(rolled and rolled.rank >= 4 and "Success" or "Pop", rolled and (0.9 + rolled.rank * 0.05) or 1)
		local flash = Instance.new("Frame")
		flash.Size = UDim2.fromScale(1, 1)
		flash.BackgroundColor3 = rolled and rolled.color or WHITE
		flash.BackgroundTransparency = 0.2
		flash.ZIndex = 28
		flash.Parent = slot.holder
		corner(flash, 10)
		tween(flash, 0.5, { BackgroundTransparency = 1 }).Completed:Connect(function()
			flash:Destroy()
		end)
	else
		local kept = TraitShared.Get(result.trait)
		slot.badge.Text = "KEPT " .. (kept and TraitShared.FormatMult(kept.mult) or "")
		slot.badge.TextColor3 = Color3.fromRGB(200, 200, 205)
		UISounds.PlayOverlap("SmallClick", 0.8, 0.4)
	end
	slot.refresh()
	task.delay(0.9, function()
		if reel.Parent then
			tween(reel, 0.25, { BackgroundTransparency = 1, TextTransparency = 1 }).Completed:Connect(function()
				reel.Text = ""
				reel.TextTransparency = 0
			end)
			slot.badge.Visible = false
		end
	end)
end

local function allMaxed(): boolean
	local maxRank = #TraitShared.TRAITS
	for _, tool in ipairs(selected) do
		if TraitShared.GetRank(tool) < maxRank then
			return false
		end
	end
	return #selected > 0
end

local function doRoll(): boolean
	if rolling then
		return false
	end
	if #selected == 0 then
		UISounds.Play("BuyFail")
		showToast("SELECT A BRAINROT FIRST!", RED)
		return false
	end
	if allMaxed() then
		showToast("ALREADY MAX TRAIT!", YELLOW)
		return false
	end
	rolling = true
	local luckOn = useLuck and (player:GetAttribute("TraitLuck") or 0) > 0
	local result = remote:InvokeServer("Roll", selected, luckOn)
	if type(result) ~= "table" or not result.ok then
		rolling = false
		if type(result) == "table" and result.silent then
			return true
		end
		UISounds.Play("BuyFail")
		showToast(type(result) == "table" and string.upper(result.err or "ERROR") or "ERROR", RED)
		return false
	end
	UISounds.Play("Sweep")
	tween(rollButton:FindFirstChildOfClass("UIScale"), 0.08, { Scale = 0.9 })
	task.delay(0.08, function()
		tween(rollButton:FindFirstChildOfClass("UIScale"), 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	if result.lucky then
		showToast("🍀 10x LUCKY ROLL!", Color3.fromRGB(120, 255, 120))
	end
	local pending = 0
	for i, r in ipairs(result.results) do
		local slot
		for _, s in ipairs(slotFrames) do
			if s.tool == r.tool then
				slot = s
			end
		end
		if slot and slot.reel then
			pending += 1
			task.spawn(function()
				spinReel(slot, r, i - 1)
				pending -= 1
			end)
		end
	end
	local t0 = os.clock()
	while pending > 0 and os.clock() - t0 < 4 do
		task.wait()
	end
	rolling = false
	updateCost()
	return true
end

rollButton.MouseButton1Click:Connect(function()
	if auto then
		setAuto(false)
	end
	doRoll()
end)

autoButton.MouseButton1Click:Connect(function()
	UISounds.Play("Tab")
	setAuto(not auto)
	if auto then
		task.spawn(function()
			while auto and isOpen do
				if not rolling then
					if allMaxed() then
						showToast("ALL MAX TRAIT! AUTO STOPPED", YELLOW)
						setAuto(false)
						break
					end
					if not doRoll() then
						setAuto(false)
						break
					end
				end
				task.wait(TraitShared.AUTO_DELAY)
			end
			setAuto(false)
		end)
	end
end)

--== Ouverture ==--
local function fit()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	return math.clamp(math.min((vp.X - 24) / root.Size.X.Offset, (vp.Y - 70) / root.Size.Y.Offset), 0.3, 1)
end

local function setOpen(open: boolean)
	if open == isOpen then
		return
	end
	isOpen = open
	if open then
		gui.Enabled = true
		picker.Visible = false
		refreshSlots()
		updateLuck()
		UISounds.Play("Popup")
		overlay.BackgroundTransparency = 1
		tween(overlay, 0.2, { BackgroundTransparency = 0.5 })
		local target = fit()
		rootScale.Scale = target * 0.6
		tween(rootScale, 0.32, { Scale = target }, Enum.EasingStyle.Back)
	else
		setAuto(false)
		UISounds.Play("Close")
		tween(overlay, 0.15, { BackgroundTransparency = 1 })
		tween(rootScale, 0.15, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
			if not isOpen then
				gui.Enabled = false
			end
		end)
	end
end

closeButton.MouseButton1Click:Connect(function()
	setOpen(false)
end)
local lastPointer = Vector2.zero
game:GetService("UserInputService").InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		lastPointer = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

local function pointerInside(frame: GuiObject): boolean
	local m = lastPointer
	local p, s = frame.AbsolutePosition, frame.AbsoluteSize
	return m.X >= p.X and m.X <= p.X + s.X and m.Y >= p.Y and m.Y <= p.Y + s.Y
end

overlay.MouseButton1Click:Connect(function()
	if pointerInside(main) or pointerInside(side) then
		return
	end
	if picker.Visible then
		closePicker()
	else
		setOpen(false)
	end
end)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if isOpen then
			rootScale.Scale = fit()
		end
	end)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "TraitMachinePrompt" then
		setOpen(true)
	end
end)

local openRequest = Instance.new("BindableEvent")
openRequest.Name = "OpenTraitMachine"
openRequest.Parent = ReplicatedStorage.Traits
openRequest.Event:Connect(function()
	setOpen(true)
end)

event.OnClientEvent:Connect(function(kind, data)
	if kind == "LuckGranted" and type(data) == "table" then
		UISounds.Play("Buy")
		useLuck = true
		updateLuck()
		showToast(("+%d LUCKY ROLL%s!"):format(data.rolls or 1, (data.rolls or 1) > 1 and "S" or ""), Color3.fromRGB(120, 255, 120))
	end
end)

Inv.WatchInventory(player, function()
	if isOpen and not rolling then
		local changed = false
		for _, t in ipairs(selected) do
			if not t.Parent then
				changed = true
			end
		end
		if changed then
			refreshSlots()
		else
			for _, s in ipairs(slotFrames) do
				if s.refresh then
					s.refresh()
				end
			end
		end
	end
end)

--== Modele dans le monde ==--
local clock = 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	for _, g in ipairs(rainbowGrads) do
		g.Offset = Vector2.new(math.sin(clock * 1.5) * 0.3, 0)
	end
	if isOpen then
		local s = star:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		s.Parent = star
		s.Scale = 1 + math.sin(clock * 3) * 0.08
		star.Rotation = math.sin(clock * 2) * 10
	end
end)

task.spawn(function()
	local machine = workspace:WaitForChild("TraitMachine", 60)
	if not machine then
		return
	end
	local oddsBoard = machine:WaitForChild("OddsBoard", 60)
	local osg = oddsBoard and oddsBoard:WaitForChild("Odds", 10)
	if osg then
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, 56)
		t.FontFace = FONT_TITLE
		t.Text = "ODDS"
		t.TextScaled = true
		t.TextColor3 = WHITE
		t.Parent = osg
		textStroke(t, 3)
		for i, tr in ipairs(TraitShared.TRAITS) do
			local row = Instance.new("TextLabel")
			row.BackgroundTransparency = 1
			row.Position = UDim2.fromOffset(8, 56 + (i - 1) * 42)
			row.Size = UDim2.new(1, -16, 0, 40)
			row.FontFace = FONT_TITLE
			row.RichText = true
			row.TextScaled = true
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextColor3 = WHITE
			row.Text = ("%s <font color=\"#%s\">%s</font>  1/%d"):format(tr.emoji, tr.color:ToHex(), TraitShared.FormatMult(tr.mult), tr.odds)
			row.Parent = osg
			textStroke(row, 2)
		end
	end
	local screen = machine:WaitForChild("Screen", 30)
	local reels = screen and screen:WaitForChild("Reels", 10)
	if not reels then
		return
	end
	local symbols = {}
	for i = 1, 4 do
		local r = reels:FindFirstChild("Reel" .. i)
		local s = r and r:FindFirstChild("Symbol")
		if s then
			table.insert(symbols, s)
		end
	end
	while true do
		local char = player.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		if rootPart and (rootPart.Position - screen.Position).Magnitude < 90 then
			for i, s in ipairs(symbols) do
				task.delay((i - 1) * 0.12, function()
					for _ = 1, 6 do
						s.Text = TRAIT_EMOJIS[math.random(1, #TRAIT_EMOJIS)]
						task.wait(0.06)
					end
				end)
			end
			task.wait(2.4)
		else
			task.wait(1)
		end
	end
end)
