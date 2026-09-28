--[[
	BackpackClient (rework)
	-----------------------
	Inventaire : bouton sac (barre du haut) ou touche `.
	  - onglets Favorites / Brainrots / Lucky Blocks (compteurs)
	  - tri revenu (haut/bas) ou rarete, recherche
	  - cartes : rarete, mutation, trait, niveau, revenu, favori
	  - fiche detaillee au survol
	  - clic = hotbar, glisser-deposer vers / depuis la hotbar
	  - clic droit / appui long = favori
	  - EQUIP BEST : pose les meilleurs sur la base
	Etat = attributs des Tools (InventoryShared) ; actions -> InventoryService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Shared = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("InventoryShared"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local TraitShared = require(ReplicatedStorage:WaitForChild("Traits"):WaitForChild("TraitShared"))
local remote = ReplicatedStorage.Inventory:WaitForChild("InventoryAction")

--== Style ==--
local ICON_IMAGE = "rbxthumb://type=Asset&id=105265480737430&w=150&h=150"
local STUDS_IMAGE = "rbxassetid://6372755229"

local C = {
	body = Color3.fromRGB(22, 24, 30),
	bodyTop = Color3.fromRGB(38, 42, 52),
	panel = Color3.fromRGB(30, 33, 41),
	headerTop = Color3.fromRGB(120, 235, 70),
	headerBottom = Color3.fromRGB(40, 170, 40),
	tab = Color3.fromRGB(46, 50, 62),
	tabOn = Color3.fromRGB(95, 215, 60),
	border = Color3.fromRGB(0, 0, 0),
	green = Color3.fromRGB(120, 255, 90),
	gold = Color3.fromRGB(255, 215, 60),
	white = Color3.new(1, 1, 1),
	muted = Color3.fromRGB(175, 180, 195),
	red = Color3.fromRGB(240, 70, 75),
	pink = Color3.fromRGB(255, 120, 170),
}

local MUTATION_COLORS = {
	Gold = Color3.fromRGB(255, 205, 40), Diamond = Color3.fromRGB(80, 210, 255), Ruby = Color3.fromRGB(255, 50, 90),
	Lava = Color3.fromRGB(255, 110, 20), Galaxy = Color3.fromRGB(170, 100, 255), Hacker = Color3.fromRGB(40, 240, 90),
	Rainbow = Color3.fromRGB(255, 120, 220), Admin = Color3.fromRGB(255, 45, 60),
}

local FONT_TITLE = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local FONT_BOLD = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)

local TWEEN_FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, thickness: number, color: Color3?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = color or C.border
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function textStroke(parent: Instance, thickness: number)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness
	s.Color = C.border
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

local function studs(parent: GuiObject, radius: number, tile: number?, transparency: number?)
	local img = Instance.new("ImageLabel")
	img.Name = "Studs"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = STUDS_IMAGE
	img.ScaleType = Enum.ScaleType.Tile
	img.TileSize = UDim2.fromOffset(tile or 40, tile or 40)
	img.ImageColor3 = Color3.new(0, 0, 0)
	img.ImageTransparency = transparency or 0.82
	img.ZIndex = parent.ZIndex
	img.Parent = parent
	corner(img, radius)
	return img
end

local function darken(color: Color3, f: number): Color3
	return Color3.new(color.R * f, color.G * f, color.B * f)
end

local function label(parent: Instance, text: string, size: number, color: Color3?, font: Font?)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font or FONT_BOLD
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color or C.white
	l.ZIndex = (parent:IsA("GuiObject") and parent.ZIndex or 1) + 1
	l.Parent = parent
	textStroke(l, math.max(1.5, size / 10))
	return l
end

local function addPressFeedback(button: GuiButton, hover: number?)
	local scale = Instance.new("UIScale")
	scale.Parent = button
	local h = hover or 1.05
	local hovering = false
	button.MouseEnter:Connect(function()
		hovering = true
		TweenService:Create(scale, TWEEN_FAST, { Scale = h }):Play()
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		TweenService:Create(scale, TWEEN_FAST, { Scale = 1 }):Play()
	end)
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TWEEN_FAST, { Scale = h * 0.92 }):Play()
	end)
	button.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TWEEN_FAST, { Scale = hovering and h or 1 }):Play()
	end)
	return scale
end

--== ScreenGui ==--
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BackpackGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ScreenInsets = Enum.ScreenInsets.None
screenGui.DisplayOrder = 5
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player:WaitForChild("PlayerGui")

--== Bouton de la barre du haut ==--
local ICON_SIZE = 44

local iconButton = Instance.new("ImageButton")
iconButton.Name = "BackpackButton"
iconButton.Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE)
iconButton.BackgroundColor3 = Color3.fromRGB(18, 18, 21)
iconButton.BackgroundTransparency = 0.3
iconButton.AutoButtonColor = false
iconButton.Image = ""
iconButton.Parent = screenGui
corner(iconButton, ICON_SIZE)
addPressFeedback(iconButton, 1.08)

local iconImage = Instance.new("ImageLabel")
iconImage.Name = "Icon"
iconImage.AnchorPoint = Vector2.new(0.5, 0.5)
iconImage.Position = UDim2.fromScale(0.5, 0.5)
iconImage.Size = UDim2.fromScale(0.62, 0.62)
iconImage.BackgroundTransparency = 1
iconImage.Image = ICON_IMAGE
iconImage.ScaleType = Enum.ScaleType.Fit
iconImage.Parent = iconButton

local newBadge = Instance.new("Frame")
newBadge.Name = "NewBadge"
newBadge.AnchorPoint = Vector2.new(1, 0)
newBadge.Position = UDim2.new(1, 3, 0, -3)
newBadge.Size = UDim2.fromOffset(14, 14)
newBadge.BackgroundColor3 = C.red
newBadge.Visible = false
newBadge.Parent = iconButton
corner(newBadge, 7)
stroke(newBadge, 2)

local function placeIcon()
	local inset = GuiService.TopbarInset
	local height = inset.Height > 0 and inset.Height or 58
	local x = inset.Min.X > 0 and inset.Min.X or 16 + 44 + 12
	iconButton.Position = UDim2.fromOffset(x, inset.Min.Y + math.floor((height - ICON_SIZE) / 2))
end
placeIcon()
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeIcon)

--== Fenetre ==--
local PANEL_W, PANEL_H = 700, 450
local TAB_W, TAB_GAP = 84, 10
local HEADER_H = 64
local FOOTER_H = 58
local SIDE_W = TAB_W + TAB_GAP

local root = Instance.new("Frame")
root.Name = "Window"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(PANEL_W, PANEL_H + HEADER_H)
root.BackgroundTransparency = 1
root.Visible = false
root.Parent = screenGui

local uiScale = Instance.new("UIScale")
uiScale.Parent = root
local function fitScale(): number
	local cam = workspace.CurrentCamera
	if not cam then
		return 1
	end
	local vp = cam.ViewportSize
	local w = root.Size.X.Offset + SIDE_W * 2
	return math.max(0.42, math.min(1, (vp.X - 24) / w, (vp.Y - 110) / root.Size.Y.Offset))
end

local shadowFrame = Instance.new("Frame")
shadowFrame.Name = "Shadow"
shadowFrame.Position = UDim2.fromOffset(0, 8)
shadowFrame.Size = UDim2.fromScale(1, 1)
shadowFrame.BackgroundColor3 = Color3.new(0, 0, 0)
shadowFrame.BackgroundTransparency = 0.55
shadowFrame.Parent = root
corner(shadowFrame, 16)

local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, HEADER_H)
header.BackgroundColor3 = C.white
header.ZIndex = 3
header.Parent = root
corner(header, 14)
stroke(header, 4)
gradient(header, C.headerTop, C.headerBottom)
studs(header, 14, 30, 0.8)

local titleIcon = label(header, "🎒", 36)
titleIcon.Position = UDim2.fromOffset(12, 0)
titleIcon.Size = UDim2.fromOffset(44, HEADER_H)
titleIcon.ZIndex = 5

local title = label(header, "INVENTORY", 38, C.white, FONT_TITLE)
title.Name = "Title"
title.Position = UDim2.fromOffset(60, 3)
title.Size = UDim2.new(0, 230, 1, 0)
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 5
title:FindFirstChildOfClass("UIStroke").Thickness = 4

local countLabel = label(header, "", 18, Color3.fromRGB(235, 255, 225))
countLabel.Name = "Count"
countLabel.Position = UDim2.fromOffset(60, 0)
countLabel.Size = UDim2.new(0, 140, 1, 0)
countLabel.TextXAlignment = Enum.TextXAlignment.Left
countLabel.ZIndex = 5

local closeButton = Instance.new("TextButton")
closeButton.Name = "Close"
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -10, 0.5, 0)
closeButton.Size = UDim2.fromOffset(48, 46)
closeButton.BackgroundColor3 = C.white
closeButton.Text = ""
closeButton.AutoButtonColor = false
closeButton.ZIndex = 5
closeButton.Parent = header
corner(closeButton, 10)
stroke(closeButton, 3.5)
gradient(closeButton, Color3.fromRGB(255, 120, 120), Color3.fromRGB(210, 40, 45))
local closeX = label(closeButton, "X", 32, C.white, FONT_TITLE)
closeX.Size = UDim2.fromScale(1, 1)
closeX.Position = UDim2.fromOffset(0, 2)
closeX.ZIndex = 7
addPressFeedback(closeButton, 1.1)

local search = Instance.new("TextBox")
search.Name = "Search"
search.AnchorPoint = Vector2.new(1, 0.5)
search.Position = UDim2.new(1, -70, 0.5, 0)
search.Size = UDim2.fromOffset(190, 40)
search.BackgroundColor3 = Color3.fromRGB(20, 45, 18)
search.BackgroundTransparency = 0.25
search.FontFace = FONT_BOLD
search.TextSize = 18
search.TextColor3 = C.white
search.PlaceholderText = "Search..."
search.PlaceholderColor3 = Color3.fromRGB(180, 215, 170)
search.Text = ""
search.ClearTextOnFocus = false
search.TextXAlignment = Enum.TextXAlignment.Left
search.TextTruncate = Enum.TextTruncate.AtEnd
search.ZIndex = 5
search.Parent = header
corner(search, 10)
local searchStroke = stroke(search, 3)
local searchPad = Instance.new("UIPadding")
searchPad.PaddingLeft = UDim.new(0, 34)
searchPad.PaddingRight = UDim.new(0, 8)
searchPad.Parent = search
local searchIcon = label(search, "🔍", 18)
searchIcon.Position = UDim2.fromOffset(-28, 0)
searchIcon.Size = UDim2.fromOffset(24, 40)
searchIcon.ZIndex = 6
search.Focused:Connect(function()
	searchStroke.Color = C.white
	UISounds.Play("SmallClick")
end)
search.FocusLost:Connect(function()
	searchStroke.Color = C.border
end)

local SORTS = {
	{ key = "desc", text = "$▼" },
	{ key = "asc", text = "$▲" },
	{ key = "rarity", text = "★" },
}
local sortBox = Instance.new("Frame")
sortBox.Name = "Sort"
sortBox.AnchorPoint = Vector2.new(1, 0.5)
sortBox.Position = UDim2.new(1, -270, 0.5, 0)
sortBox.Size = UDim2.fromOffset(150, 40)
sortBox.BackgroundColor3 = Color3.fromRGB(20, 45, 18)
sortBox.BackgroundTransparency = 0.25
sortBox.ZIndex = 5
sortBox.Parent = header
corner(sortBox, 10)
stroke(sortBox, 3)
local sortLayout = Instance.new("UIListLayout")
sortLayout.FillDirection = Enum.FillDirection.Horizontal
sortLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sortLayout.VerticalAlignment = Enum.VerticalAlignment.Center
sortLayout.Padding = UDim.new(0, 3)
sortLayout.Parent = sortBox
local sortButtons = {}
local sortMode = "desc"
local refresh
for i, s in ipairs(SORTS) do
	local b = Instance.new("TextButton")
	b.LayoutOrder = i
	b.Size = UDim2.fromOffset(46, 32)
	b.BackgroundColor3 = C.tabOn
	b.BackgroundTransparency = 1
	b.FontFace = FONT_TITLE
	b.Text = s.text
	b.TextSize = 20
	b.TextColor3 = C.white
	b.AutoButtonColor = false
	b.ZIndex = 6
	b.Parent = sortBox
	corner(b, 7)
	textStroke(b, 2)
	addPressFeedback(b, 1.1)
	sortButtons[s.key] = b
	b.MouseButton1Click:Connect(function()
		if sortMode ~= s.key then
			sortMode = s.key
			UISounds.Play("Tab", 1.1)
			refresh()
		end
	end)
end

local body = Instance.new("Frame")
body.Name = "Body"
body.Position = UDim2.fromOffset(0, HEADER_H + 8)
body.Size = UDim2.fromOffset(PANEL_W, PANEL_H - 8)
body.BackgroundColor3 = C.white
body.BackgroundTransparency = 0.04
body.ZIndex = 2
body.Parent = root
corner(body, 14)
stroke(body, 4)
gradient(body, C.bodyTop, C.body)
studs(body, 14, 46, 0.86)
shadowFrame.Size = UDim2.new(1, 0, 1, 0)

local tabsFrame = Instance.new("Frame")
tabsFrame.Name = "Tabs"
tabsFrame.Position = UDim2.fromOffset(-SIDE_W, HEADER_H + 8)
tabsFrame.Size = UDim2.fromOffset(TAB_W, PANEL_H)
tabsFrame.BackgroundTransparency = 1
tabsFrame.ZIndex = 2
tabsFrame.Parent = root
local tabsLayout = Instance.new("UIListLayout")
tabsLayout.Padding = UDim.new(0, 10)
tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabsLayout.Parent = tabsFrame

local grid = Instance.new("ScrollingFrame")
grid.Name = "Grid"
grid.Position = UDim2.fromOffset(10, 10)
grid.Size = UDim2.new(1, -20, 1, -(FOOTER_H + 18))
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 7
grid.ScrollBarImageColor3 = Color3.fromRGB(120, 235, 70)
grid.ScrollBarImageTransparency = 0.2
grid.CanvasSize = UDim2.new()
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.ScrollingDirection = Enum.ScrollingDirection.Y
grid.ZIndex = 3
grid.Parent = body

local gridPad = Instance.new("UIPadding")
gridPad.PaddingTop = UDim.new(0, 8)
gridPad.PaddingLeft = UDim.new(0, 4)
gridPad.PaddingRight = UDim.new(0, 10)
gridPad.PaddingBottom = UDim.new(0, 8)
gridPad.Parent = grid

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(102, 128)
gridLayout.CellPadding = UDim2.fromOffset(9, 10)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid

local emptyLabel = label(body, "", 24, C.muted, FONT_TITLE)
emptyLabel.Name = "Empty"
emptyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
emptyLabel.Position = UDim2.fromScale(0.5, 0.45)
emptyLabel.Size = UDim2.new(1, -60, 0, 80)
emptyLabel.TextWrapped = true
emptyLabel.Visible = false
emptyLabel.ZIndex = 4

--== Pied ==--
local footer = Instance.new("Frame")
footer.Name = "Footer"
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.new(0, 10, 1, -10)
footer.Size = UDim2.new(1, -20, 0, FOOTER_H)
footer.BackgroundColor3 = Color3.fromRGB(14, 15, 20)
footer.BackgroundTransparency = 0.35
footer.ZIndex = 3
footer.Parent = body
corner(footer, 10)

local totalLabel = label(footer, "", 20, C.green, FONT_TITLE)
totalLabel.Position = UDim2.fromOffset(14, 0)
totalLabel.Size = UDim2.new(0.5, 0, 1, 0)
totalLabel.TextXAlignment = Enum.TextXAlignment.Left
totalLabel.ZIndex = 5

local hintLabel = label(footer, "Click = hotbar • Right-click = ❤", 14, C.muted)
hintLabel.AnchorPoint = Vector2.new(0.5, 0.5)
hintLabel.Position = UDim2.new(0.5, 30, 0.5, 0)
hintLabel.Size = UDim2.fromOffset(220, 20)
hintLabel.ZIndex = 5

local bestButton = Instance.new("TextButton")
bestButton.Name = "BestButton"
bestButton.AnchorPoint = Vector2.new(1, 0.5)
bestButton.Position = UDim2.new(1, -8, 0.5, 0)
bestButton.Size = UDim2.fromOffset(190, 44)
bestButton.BackgroundColor3 = C.white
bestButton.Text = ""
bestButton.AutoButtonColor = false
bestButton.ZIndex = 5
bestButton.Parent = footer
corner(bestButton, 10)
stroke(bestButton, 3.5)
gradient(bestButton, Color3.fromRGB(255, 230, 70), Color3.fromRGB(255, 160, 0))
studs(bestButton, 10, 24, 0.8)
local bestText = label(bestButton, "⚡ EQUIP BEST", 24, C.white, FONT_TITLE)
bestText.Size = UDim2.fromScale(1, 1)
bestText.Position = UDim2.fromOffset(0, 2)
bestText.ZIndex = 7
addPressFeedback(bestButton, 1.05)

--== Toast ==--
local toast = label(root, "", 20, C.white, FONT_TITLE)
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Position = UDim2.new(0.5, 0, 1, 10)
toast.Size = UDim2.fromOffset(460, 40)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
toast.BackgroundTransparency = 0.1
toast.Visible = false
toast.ZIndex = 20
corner(toast, 10)
stroke(toast, 3)
local toastScale = Instance.new("UIScale")
toastScale.Parent = toast
local toastToken = 0
local function showToast(text: string, color: Color3?, sound: string?)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.TextColor3 = color or C.white
	toast.Visible = true
	toastScale.Scale = 0.7
	TweenService:Create(toastScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if sound then
		UISounds.Play(sound)
	end
	task.delay(1.8, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

--== Onglets ==--
local TABS = {
	{ key = "Favorites", icon = "❤️", label = "Favorites", title = "FAVORITES" },
	{ key = Shared.TYPE_BRAINROT, icon = "🧠", label = "Brainrots", title = "BRAINROTS" },
	{ key = Shared.TYPE_LUCKY, icon = "🍓", label = "Lucky", title = "LUCKY BLOCKS" },
}
local currentTab = Shared.TYPE_BRAINROT
local isOpen = false
local tabButtons = {}

for i, tab in ipairs(TABS) do
	local b = Instance.new("TextButton")
	b.Name = tab.key
	b.LayoutOrder = i
	b.Size = UDim2.fromOffset(TAB_W, 84)
	b.BackgroundColor3 = C.white
	b.Text = ""
	b.AutoButtonColor = false
	b.ZIndex = 2
	b.Parent = tabsFrame
	corner(b, 12)
	local s = stroke(b, 4)
	local g = gradient(b, C.tab, darken(C.tab, 0.6))
	studs(b, 12, 24, 0.8)
	addPressFeedback(b, 1.06)

	local icon = Instance.new("TextLabel")
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(0, 8)
	icon.Size = UDim2.new(1, 0, 0, 34)
	icon.TextScaled = true
	icon.Text = tab.icon
	icon.ZIndex = 4
	icon.Parent = b

	local l = label(b, tab.label, 15, C.white, FONT_TITLE)
	l.AnchorPoint = Vector2.new(0.5, 1)
	l.Position = UDim2.new(0.5, 0, 1, -8)
	l.Size = UDim2.new(1, -6, 0, 22)
	l.ZIndex = 4

	local badge = label(b, "0", 14, C.white, FONT_TITLE)
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 8, 0, -8)
	badge.Size = UDim2.fromOffset(30, 24)
	badge.BackgroundColor3 = C.red
	badge.BackgroundTransparency = 0
	badge.ZIndex = 6
	corner(badge, 12)
	stroke(badge, 2.5)

	tabButtons[tab.key] = { button = b, stroke = s, gradient = g, tab = tab, badge = badge }

	b.MouseButton1Click:Connect(function()
		if currentTab ~= tab.key then
			currentTab = tab.key
			UISounds.Play("Tab")
			grid.CanvasPosition = Vector2.zero
			refresh()
		end
	end)
end

local function updateHeader()
	for key, data in pairs(tabButtons) do
		local selected = key == currentTab
		data.stroke.Color = selected and C.white or C.border
		local base = selected and C.tabOn or C.tab
		data.gradient.Color = ColorSequence.new(base:Lerp(C.white, 0.1), darken(base, 0.6))
		if selected then
			title.Text = data.tab.title
		end
	end
	for key, b in pairs(sortButtons) do
		b.BackgroundTransparency = key == sortMode and 0 or 1
	end
end

--== Fiche detaillee (survol) ==--
local tip = Instance.new("Frame")
tip.Name = "DetailTip"
tip.AnchorPoint = Vector2.new(0.5, 1)
tip.Size = UDim2.fromOffset(0, 0)
tip.AutomaticSize = Enum.AutomaticSize.XY
tip.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
tip.BackgroundTransparency = 0.04
tip.Visible = false
tip.ZIndex = 30
tip.Parent = screenGui
corner(tip, 10)
local tipStroke = stroke(tip, 3)
local tipPad = Instance.new("UIPadding")
tipPad.PaddingLeft = UDim.new(0, 14)
tipPad.PaddingRight = UDim.new(0, 14)
tipPad.PaddingTop = UDim.new(0, 8)
tipPad.PaddingBottom = UDim.new(0, 8)
tipPad.Parent = tip
local tipLayout = Instance.new("UIListLayout")
tipLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tipLayout.SortOrder = Enum.SortOrder.LayoutOrder
tipLayout.Padding = UDim.new(0, 1)
tipLayout.Parent = tip

local function tipLine(order: number, size: number, font: Font?)
	local l = Instance.new("TextLabel")
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromOffset(0, size + 4)
	l.AutomaticSize = Enum.AutomaticSize.X
	l.FontFace = font or FONT_TITLE
	l.TextSize = size
	l.TextColor3 = C.white
	l.RichText = true
	l.ZIndex = 31
	l.Parent = tip
	textStroke(l, 2.2)
	return l
end
local tipName = tipLine(1, 22)
local tipRarity = tipLine(2, 16)
local tipMutation = tipLine(3, 16)
local tipTrait = tipLine(4, 16)
local tipLevel = tipLine(5, 15, FONT_BOLD)
local tipIncome = tipLine(6, 18)

local tipOwner: GuiObject? = nil
local ghost: Frame? = nil
local function hideTip(owner: GuiObject?)
	if owner == nil or tipOwner == owner then
		tipOwner = nil
		tip.Visible = false
	end
end
local function showTip(cell: GuiObject, tool: Tool)
	if ghost then
		return
	end
	local handle = tool:FindFirstChild("Handle")
	local rarity = Shared.GetRarity(tool)
	local isLucky = Shared.GetItemType(tool) == Shared.TYPE_LUCKY
	tipOwner = cell
	tipName.Text = Shared.GetDisplayName(tool)
	tipRarity.Text = isLucky and "LUCKY BLOCK" or string.upper(rarity.name or "")
	tipRarity.TextColor3 = isLucky and C.pink or rarity.color
	local mutation = handle and handle:GetAttribute("Mutation")
	tipMutation.Visible = type(mutation) == "string"
	if tipMutation.Visible then
		tipMutation.Text = "✨ " .. string.upper(mutation)
		tipMutation.TextColor3 = MUTATION_COLORS[mutation] or C.white
	end
	local trait = TraitShared.GetTrait(tool)
	tipTrait.Visible = trait ~= nil
	if trait then
		tipTrait.Text = ("%s %s TRAIT • %s"):format(trait.emoji, string.upper(trait.name), TraitShared.FormatMult(trait.mult))
		tipTrait.TextColor3 = trait.color
	end
	local level = handle and handle:GetAttribute("Level")
	tipLevel.Visible = not isLucky
	tipLevel.Text = "Level " .. tostring(level or 1)
	tipLevel.TextColor3 = Color3.fromRGB(255, 225, 120)
	if isLucky then
		tipIncome.Text = ("x%d • hold it & click to open"):format(tool:GetAttribute("Count") or 1)
		tipIncome.TextColor3 = C.pink
	else
		tipIncome.Text = "$" .. NumberFormat.Format(tool:GetAttribute("Income") or 0) .. "/s"
		tipIncome.TextColor3 = C.green
	end
	tipStroke.Color = trait and trait.color or (isLucky and C.pink or rarity.color)
	local p, s = cell.AbsolutePosition, cell.AbsoluteSize
	local inset = screenGui.AbsolutePosition
	tip.Position = UDim2.fromOffset(p.X - inset.X + s.X / 2, p.Y - inset.Y - 6)
	tip.Visible = true
	task.defer(function()
		if tipOwner ~= cell then
			return
		end
		local vw = screenGui.AbsoluteSize.X
		local half = tip.AbsoluteSize.X / 2
		local x = math.clamp(tip.Position.X.Offset, half + 8, vw - half - 8)
		local y = tip.Position.Y.Offset
		if y - tip.AbsoluteSize.Y < 8 then
			y = p.Y - inset.Y + s.Y + tip.AbsoluteSize.Y + 6
		end
		tip.Position = UDim2.fromOffset(x, y)
	end)
end
grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
	hideTip(nil)
end)

--== Glisser-deposer ==--
local DRAG_THRESHOLD = 8

local dragGui = Instance.new("ScreenGui")
dragGui.Name = "BackpackDragGui"
dragGui.ResetOnSpawn = false
dragGui.IgnoreGuiInset = false
dragGui.DisplayOrder = 50
dragGui.Parent = player:WaitForChild("PlayerGui")

local press = nil

local function hotbarSlotFrames(): { [number]: GuiObject }
	local frames = {}
	local gui = player.PlayerGui:FindFirstChild("CustomHotbarGui")
	local container = gui and gui:FindFirstChild("HotbarContainer")
	if container then
		for i = Shared.HOTBAR_FIRST, Shared.HOTBAR_LAST do
			local f = container:FindFirstChild("Slot" .. i)
			if f then
				frames[i] = f
			end
		end
	end
	return frames
end

local function isOver(gui: GuiObject, pos: Vector2): boolean
	local p, s = gui.AbsolutePosition, gui.AbsoluteSize
	return pos.X >= p.X and pos.X <= p.X + s.X and pos.Y >= p.Y and pos.Y <= p.Y + s.Y
end

local function hotbarSlotAt(pos: Vector2): number?
	for i, f in pairs(hotbarSlotFrames()) do
		if isOver(f, pos) then
			return i
		end
	end
	return nil
end

local lastHighlight = nil
local function highlightSlots(target: number?)
	if ghost and target ~= lastHighlight and target ~= nil then
		UISounds.Play("SmallClick", 1.25)
	end
	lastHighlight = target
	for i, f in pairs(hotbarSlotFrames()) do
		local s = f:FindFirstChild("SlotStroke")
		if s then
			if ghost then
				s.Color = i == target and C.green or C.white
				s.Transparency = i == target and 0 or 0.35
				s.Thickness = i == target and 3 or 1.5
			else
				s.Color = C.white
			end
		end
	end
end

local function hotbarUsedCount(): number
	local used = 0
	for _, t in ipairs(Shared.GetItems(player)) do
		if (t:GetAttribute("HotbarSlot") or 0) ~= 0 then
			used += 1
		end
	end
	return used
end

local function beginPress(input: InputObject, tool: Tool, source: string, fromSlot: number?)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	if press or not tool.Parent then
		return
	end
	press = { tool = tool, source = source, fromSlot = fromSlot, start = Vector2.new(input.Position.X, input.Position.Y), input = input }
end

local function startGhost(tool: Tool, pos: Vector2)
	local rarity = Shared.GetRarity(tool)
	local g = Instance.new("Frame")
	g.Name = "Ghost"
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Size = UDim2.fromOffset(78, 78)
	g.BackgroundColor3 = C.white
	g.BackgroundTransparency = 0.05
	g.Position = UDim2.fromOffset(pos.X, pos.Y)
	g.Rotation = -6
	g.Parent = dragGui
	corner(g, 12)
	stroke(g, 3, C.white)
	gradient(g, darken(rarity.color, 0.85), darken(rarity.color, 0.35))
	Shared.CreateViewport(tool, g)
	local sc = Instance.new("UIScale")
	sc.Scale = 0.6
	sc.Parent = g
	TweenService:Create(sc, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	ghost = g
	hideTip(nil)
	UISounds.Play("SmallClick", 0.9)
end

local function endDrag()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	press = nil
	highlightSlots(nil)
end

UserInputService.InputChanged:Connect(function(input)
	if not press then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	if not ghost then
		if (pos - press.start).Magnitude < DRAG_THRESHOLD then
			return
		end
		if not press.tool.Parent then
			endDrag()
			return
		end
		startGhost(press.tool, pos)
	end
	ghost.Position = UDim2.fromOffset(pos.X, pos.Y)
	highlightSlots(hotbarSlotAt(pos))
end)

UserInputService.InputEnded:Connect(function(input)
	if not press then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local p = press
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	local wasDrag = ghost ~= nil
	endDrag()

	local tool = p.tool
	if not tool.Parent then
		return
	end

	if not wasDrag then
		if p.source == "bag" then
			if hotbarUsedCount() >= Shared.HOTBAR_LAST - Shared.HOTBAR_FIRST + 1 then
				showToast("HOTBAR FULL! DRAG ONTO A SLOT TO SWAP", C.gold, "BuyFail")
			else
				UISounds.Play("Pop", 1.05)
				remote:FireServer("ToggleHotbar", tool)
			end
		end
		return
	end

	local hb = player.PlayerGui:FindFirstChild("CustomHotbarGui")
	if hb then
		hb:SetAttribute("DragEndedAt", os.clock())
	end

	local target = hotbarSlotAt(pos)
	if target then
		UISounds.Play("Pop")
		remote:FireServer("SetHotbar", tool, target)
	elseif p.source == "hotbar" and root.Visible and (isOver(body, pos) or isOver(tabsFrame, pos)) then
		UISounds.Play("Pop", 0.85)
		remote:FireServer("SetHotbar", tool, 0)
	else
		UISounds.Play("Swoosh", 1.2)
	end
end)

local hookedSlots = setmetatable({}, { __mode = "k" })
local function hookHotbar()
	for i, f in pairs(hotbarSlotFrames()) do
		if not hookedSlots[f] then
			hookedSlots[f] = true
			f.InputBegan:Connect(function(input)
				if not isOpen then
					return
				end
				for _, t in ipairs(Shared.GetItems(player)) do
					if t:GetAttribute("HotbarSlot") == i then
						beginPress(input, t, "hotbar", i)
						break
					end
				end
			end)
		end
	end
end
task.spawn(function()
	player.PlayerGui:WaitForChild("CustomHotbarGui", 30)
	hookHotbar()
end)

--== Cartes ==--
local cells = setmetatable({}, { __mode = "k" })

local function formatIncome(n: number): string
	return "$" .. NumberFormat.Format(n) .. "/s"
end

local function createCell(tool: Tool)
	local rarity = Shared.GetRarity(tool)
	local isLucky = Shared.GetItemType(tool) == Shared.TYPE_LUCKY
	local accent = isLucky and C.pink or rarity.color

	local cell = Instance.new("TextButton")
	cell.Name = "Item"
	cell.Text = ""
	cell.AutoButtonColor = false
	cell.BackgroundColor3 = C.white
	cell.ZIndex = 4
	cell.Parent = grid
	corner(cell, 12)
	local cellStroke = stroke(cell, 3.5, accent:Lerp(C.white, 0.2))
	gradient(cell, accent:Lerp(C.white, 0.05):Lerp(Color3.new(0, 0, 0), 0.15), darken(accent, 0.28))
	studs(cell, 12, 22, 0.82)
	local scale = addPressFeedback(cell, 1.07)

	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Size = UDim2.new(1, 0, 0.45, 0)
	shine.BackgroundColor3 = C.white
	shine.BackgroundTransparency = 0.88
	shine.ZIndex = 4
	shine.Parent = cell
	corner(shine, 12)

	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.45)
	glow.Size = UDim2.fromScale(0.8, 0.6)
	glow.BackgroundColor3 = accent:Lerp(C.white, 0.4)
	glow.BackgroundTransparency = 0.75
	glow.ZIndex = 4
	glow.Parent = cell
	corner(glow, 60)

	local holder = Instance.new("Frame")
	holder.Name = "PreviewHolder"
	holder.BackgroundTransparency = 1
	holder.Position = UDim2.fromOffset(4, 16)
	holder.Size = UDim2.new(1, -8, 1, -54)
	holder.ZIndex = 5
	holder.Parent = cell
	local vp = Shared.CreateViewport(tool, holder)
	if vp then
		vp.ZIndex = 5
	end

	local handle = tool:FindFirstChild("Handle")
	local mutation = handle and handle:GetAttribute("Mutation")
	local tag = nil
	if type(mutation) == "string" then
		tag = label(cell, string.upper(mutation), 12, MUTATION_COLORS[mutation] or C.white, FONT_TITLE)
		tag.Position = UDim2.fromOffset(6, 3)
		tag.Size = UDim2.new(1, -36, 0, 15)
		tag.TextXAlignment = Enum.TextXAlignment.Left
		tag.ZIndex = 8
	end

	local traitBadge = label(cell, "", 16, C.white)
	traitBadge.Name = "Trait"
	traitBadge.AnchorPoint = Vector2.new(1, 0)
	traitBadge.Position = UDim2.new(1, -3, 0, 2)
	traitBadge.Size = UDim2.fromOffset(26, 22)
	traitBadge.ZIndex = 8

	local name = label(cell, Shared.GetDisplayName(tool), 12, C.white, FONT_BOLD)
	name.Name = "ItemName"
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.new(0.5, 0, 1, -22)
	name.Size = UDim2.new(1, -8, 0, 15)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.ZIndex = 8

	local incomeBar = Instance.new("Frame")
	incomeBar.Name = "IncomeBar"
	incomeBar.AnchorPoint = Vector2.new(0.5, 1)
	incomeBar.Position = UDim2.new(0.5, 0, 1, -4)
	incomeBar.Size = UDim2.new(1, -8, 0, 18)
	incomeBar.BackgroundColor3 = Color3.new(0, 0, 0)
	incomeBar.BackgroundTransparency = 0.45
	incomeBar.ZIndex = 7
	incomeBar.Parent = cell
	corner(incomeBar, 6)

	local income = label(incomeBar, "", 13, C.green, FONT_TITLE)
	income.Name = "Income"
	income.Size = UDim2.new(1, -4, 1, 0)
	income.Position = UDim2.fromOffset(2, 1)
	income.ZIndex = 8

	local heart = Instance.new("TextLabel")
	heart.Name = "Favorite"
	heart.AnchorPoint = Vector2.new(1, 1)
	heart.Position = UDim2.new(1, -3, 1, -38)
	heart.Size = UDim2.fromOffset(20, 20)
	heart.BackgroundTransparency = 1
	heart.TextScaled = true
	heart.Text = "❤️"
	heart.ZIndex = 8
	heart.Parent = cell
	local heartScale = Instance.new("UIScale")
	heartScale.Parent = heart

	cell.MouseEnter:Connect(function()
		showTip(cell, tool)
		TweenService:Create(shine, TWEEN_FAST, { BackgroundTransparency = 0.8 }):Play()
	end)
	cell.MouseLeave:Connect(function()
		hideTip(cell)
		TweenService:Create(shine, TWEEN_FAST, { BackgroundTransparency = 0.88 }):Play()
	end)
	cell.Destroying:Connect(function()
		hideTip(cell)
	end)
	cell:GetPropertyChangedSignal("Visible"):Connect(function()
		if not cell.Visible then
			hideTip(cell)
		end
	end)

	cell.InputBegan:Connect(function(input)
		beginPress(input, tool, "bag", nil)
	end)
	local function toggleFav()
		if tool.Parent then
			local fav = tool:GetAttribute("Favorite") == true
			UISounds.Play(fav and "SmallClick" or "Pop", fav and 0.9 or 1.3)
			remote:FireServer("ToggleFavorite", tool)
		end
	end
	cell.MouseButton2Click:Connect(toggleFav)
	cell.TouchLongPress:Connect(function(_, state)
		if state == Enum.UserInputState.Begin then
			toggleFav()
		end
	end)

	local data = {
		frame = cell, heart = heart, heartScale = heartScale, income = income, trait = traitBadge,
		stroke = cellStroke, accent = accent, scale = scale, wasFav = tool:GetAttribute("Favorite") == true, isNew = true,
	}
	cells[tool] = data
	return data
end

local function matchesTab(tool: Tool): boolean
	if currentTab == "Favorites" then
		return tool:GetAttribute("Favorite") == true
	end
	return Shared.GetItemType(tool) == currentTab
end

local function rarityOrder(tool: Tool): number
	return Shared.GetRarity(tool).order or 0
end

local seen = setmetatable({}, { __mode = "k" })
local primed = false
local startClock = os.clock()

refresh = function()
	updateHeader()

	local items = Shared.GetItems(player)
	local alive = {}
	local counts = { Favorites = 0, [Shared.TYPE_BRAINROT] = 0, [Shared.TYPE_LUCKY] = 0 }
	local hasNew = false
	for _, tool in ipairs(items) do
		alive[tool] = true
		local inBag = (tool:GetAttribute("HotbarSlot") or 0) == 0
		if inBag then
			local t = Shared.GetItemType(tool)
			counts[t] = (counts[t] or 0) + (t == Shared.TYPE_LUCKY and (tool:GetAttribute("Count") or 1) or 1)
			if tool:GetAttribute("Favorite") == true then
				counts.Favorites += 1
			end
		end
		if not seen[tool] then
			seen[tool] = true
			if primed and not isOpen and os.clock() - startClock > 10 then
				hasNew = true
			end
		end
	end
	primed = true
	if hasNew then
		newBadge.Visible = true
	end
	for key, data in pairs(tabButtons) do
		local n = counts[key] or 0
		data.badge.Text = n > 99 and "99+" or tostring(n)
		data.badge.Visible = n > 0
	end

	for tool, data in pairs(cells) do
		if not alive[tool] then
			data.frame:Destroy()
			cells[tool] = nil
		end
	end

	if not isOpen then
		return
	end

	local query = string.lower(search.Text)
	local shown = {}
	for _, tool in ipairs(items) do
		local visible = (tool:GetAttribute("HotbarSlot") or 0) == 0 and matchesTab(tool)
		if visible and query ~= "" then
			visible = string.find(string.lower(Shared.GetDisplayName(tool)), query, 1, true) ~= nil
		end
		if visible then
			table.insert(shown, tool)
		elseif cells[tool] then
			cells[tool].frame.Visible = false
		end
	end

	table.sort(shown, function(a, b)
		if sortMode == "rarity" then
			local ra, rb = rarityOrder(a), rarityOrder(b)
			if ra ~= rb then
				return ra > rb
			end
		end
		local ia, ib = a:GetAttribute("Income") or 0, b:GetAttribute("Income") or 0
		if ia ~= ib then
			if sortMode == "asc" then
				return ia < ib
			end
			return ia > ib
		end
		return Shared.GetDisplayName(a) < Shared.GetDisplayName(b)
	end)

	local total = 0
	for order, tool in ipairs(shown) do
		local data = cells[tool] or createCell(tool)
		data.frame.Visible = true
		data.frame.LayoutOrder = order
		if data.isNew then
			data.isNew = false
			data.scale.Scale = 0.6
			TweenService:Create(data.scale, TweenInfo.new(0.25 + math.min(order, 18) * 0.012, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end

		local fav = tool:GetAttribute("Favorite") == true
		data.heart.Visible = fav
		if fav and not data.wasFav then
			data.heartScale.Scale = 1.8
			TweenService:Create(data.heartScale, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
		data.wasFav = fav

		local trait = TraitShared.GetTrait(tool)
		data.trait.Text = trait and trait.emoji or ""
		data.stroke.Color = trait and trait.color or data.accent:Lerp(C.white, 0.2)

		if Shared.GetItemType(tool) == Shared.TYPE_LUCKY then
			data.income.Text = ("x%d • OPEN"):format(tool:GetAttribute("Count") or 1)
			data.income.TextColor3 = C.pink
		else
			local inc = tool:GetAttribute("Income") or 0
			total += inc
			data.income.Text = formatIncome(inc)
			data.income.TextColor3 = C.green
		end
	end

	title.Size = UDim2.new(0, title.TextBounds.X + 4, 1, 0)
	countLabel.Position = UDim2.fromOffset(60 + title.TextBounds.X + 10, 4)
	countLabel.Text = "(" .. #shown .. ")"
	totalLabel.Text = currentTab == Shared.TYPE_LUCKY and "🍓 OPEN THEM IN HAND!" or ("TOTAL: " .. formatIncome(total))

	if #shown == 0 then
		emptyLabel.Visible = true
		if query ~= "" then
			emptyLabel.Text = "NO RESULTS"
		elseif currentTab == "Favorites" then
			emptyLabel.Text = "RIGHT-CLICK A BRAINROT TO ADD IT TO YOUR FAVORITES ❤️"
		elseif currentTab == Shared.TYPE_LUCKY then
			emptyLabel.Text = "NO LUCKY BLOCKS YET: GET SOME IN THE SHOP! 🍓"
		else
			emptyLabel.Text = "NO BRAINROTS YET: GO CATCH SOME!"
		end
	else
		emptyLabel.Visible = false
	end
end

--== Ouverture / fermeture ==--
local openToken = 0
local function setOpen(open: boolean)
	if open == isOpen then
		return
	end
	isOpen = open
	openToken += 1
	local my = openToken
	iconButton.BackgroundColor3 = open and Color3.fromRGB(70, 150, 60) or Color3.fromRGB(18, 18, 21)
	if open then
		newBadge.Visible = false
		UISounds.Play("Open")
		root.Visible = true
		local target = fitScale()
		uiScale.Scale = target * 0.82
		root.Position = UDim2.new(0.5, 0, 0.5, 30)
		TweenService:Create(uiScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = target }):Play()
		TweenService:Create(root, TweenInfo.new(0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) }):Play()
		refresh()
	else
		UISounds.Play("Swoosh")
		search:ReleaseFocus()
		hideTip(nil)
		local target = uiScale.Scale
		TweenService:Create(uiScale, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = target * 0.85 }):Play()
		TweenService:Create(root, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.new(0.5, 0, 0.5, 30) }):Play()
		task.delay(0.14, function()
			if openToken == my then
				root.Visible = false
			end
		end)
	end
end

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if isOpen then
			uiScale.Scale = fitScale()
		end
	end)
end

iconButton.MouseButton1Click:Connect(function()
	setOpen(not isOpen)
end)
closeButton.MouseButton1Click:Connect(function()
	setOpen(false)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.Backquote or input.KeyCode == Enum.KeyCode.DPadUp then
		setOpen(not isOpen)
	elseif input.KeyCode == Enum.KeyCode.ButtonB and isOpen then
		setOpen(false)
	end
end)

search:GetPropertyChangedSignal("Text"):Connect(function()
	refresh()
end)
bestButton.MouseButton1Click:Connect(function()
	UISounds.Play("Click")
	remote:FireServer("EquipBest")
end)

remote.OnClientEvent:Connect(function(kind, placed, err)
	if kind ~= "BestResult" then
		return
	end
	if err then
		showToast(string.upper(err), C.red, "BuyFail")
	elseif placed and placed > 0 then
		showToast(placed .. " BRAINROT" .. (placed > 1 and "S" or "") .. " PLACED ON YOUR BASE!", C.green, "Success")
	else
		showToast("YOUR BEST BRAINROTS ARE ALREADY PLACED", C.gold, "SmallClick")
	end
end)

local pulse = 0
RunService.RenderStepped:Connect(function(dt)
	if newBadge.Visible then
		pulse += dt
		local s = newBadge:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		s.Parent = newBadge
		s.Scale = 1 + math.abs(math.sin(pulse * 4)) * 0.25
	end
end)

Shared.WatchInventory(player, refresh)
