--[[
	TraitMachineClient
	------------------
	UI de la Trait Machine (prompt "TraitMachinePrompt" de
	Workspace.TraitMachine, panneau INFO : "TraitInfoPrompt") + animation
	du modele dans le monde (rouleaux de l'ecran, levier, tableau ODDS).
	Logique serveur : ServerScriptService.Traits.TraitService.

	Disposition :
	  - gauche : la "machine" = 4 rouleaux (un par brainrot choisi) au-dessus
	    des cartes, puis AUTO / ROLL (+ cout) / CLEAR et FILL BEST ;
	  - droite : onglets ODDS (chances, barres) et LUCK (achat 10x Luck) ;
	  - le choix des brainrots se fait dans un tiroir qui monte du bas
	    (plusieurs a la suite, re-cliquer retire).
	Telephone : tout s'adapte a l'ecran. Manette : D-pad, A valider, B
	fermer, X ROLL, Y AUTO.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local TraitShared = require(ReplicatedStorage:WaitForChild("Traits"):WaitForChild("TraitShared"))
local Inv = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("InventoryShared"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local UI = require(ReplicatedStorage:WaitForChild("UIKit"))
local remote = ReplicatedStorage.Traits:WaitForChild("TraitRemote") :: RemoteFunction
local event = ReplicatedStorage.Traits:WaitForChild("TraitEvent") :: RemoteEvent

local C = UI.C
local WHITE, BLACK = C.white, C.black
local FONT_TITLE, FONT = UI.FONT_TITLE, UI.FONT
local ROBUX = UI.ROBUX

local GOLD = Color3.fromRGB(255, 205, 40)
local LUCK_GREEN = Color3.fromRGB(120, 255, 120)
local GREY = Color3.fromRGB(180, 180, 190)

local MUTATION_COLORS = {
	Gold = Color3.fromRGB(255, 205, 40), Diamond = Color3.fromRGB(80, 210, 255), Ruby = Color3.fromRGB(255, 50, 90),
	Lava = Color3.fromRGB(255, 110, 20), Galaxy = Color3.fromRGB(170, 100, 255), Hacker = Color3.fromRGB(40, 240, 90),
	Rainbow = Color3.fromRGB(255, 120, 220), Admin = Color3.fromRGB(255, 45, 60),
}

local W, H = 1260, 760
local LEFT_W = 880
local SLOT_W, REEL_H, CARD_H = 184, 100, 240
local ICON_H = REEL_H

--== Petits constructeurs ==--
local function frame(parent: Instance, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = WHITE
	f.ZIndex = (parent:IsA("GuiObject") and parent.ZIndex or 1) + 1
	for k, v in pairs(props or {}) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

local function fancyButton(parent: Instance, label: string, color: Color3, textSize: number?)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = WHITE
	b.ZIndex = (parent:IsA("GuiObject") and parent.ZIndex or 1) + 1
	b.Parent = parent
	UI.corner(b, 12)
	UI.stroke(b, 4, BLACK)
	local g = UI.gradient(b, color:Lerp(WHITE, 0.2), color:Lerp(BLACK, 0.3))
	g.Name = "Fill"
	UI.studs(b, 26, 0.62, 12)
	local l = UI.text(b, label, textSize or 30, WHITE, FONT_TITLE, 3)
	l.Name = "Label"
	l.Size = UDim2.new(1, -12, 1, -8)
	l.Position = UDim2.fromOffset(6, 4)
	l.ZIndex = b.ZIndex + 3
	UI.pressable(b)
	return b
end

local function recolor(b: GuiObject, color: Color3)
	local g = b:FindFirstChild("Fill")
	if g then
		g.Color = ColorSequence.new(color:Lerp(WHITE, 0.2), color:Lerp(BLACK, 0.3))
	end
end

-- Icone d'un trait (image si dispo, sinon emoji).
local function traitIcon(parent: Instance, t, z: number?): GuiObject
	local img = TraitShared.Image(t)
	if img ~= "" then
		local i = Instance.new("ImageLabel")
		i.Name = "TraitIcon"
		i.BackgroundTransparency = 1
		i.ScaleType = Enum.ScaleType.Fit
		i.Image = img
		i.ZIndex = z or ((parent:IsA("GuiObject") and parent.ZIndex or 1) + 1)
		i.Parent = parent
		return i
	end
	local l = UI.text(parent, t.emoji, 60, WHITE, FONT, 3)
	l.Name = "TraitIcon"
	if z then
		l.ZIndex = z
	end
	return l
end

--== ScreenGui ==--
local gui = Instance.new("ScreenGui")
gui.Name = "TraitMachineGui"
-- Animations deja gerees ici (UIKit) : UIJuice ne doit pas ajouter les siennes.
gui:SetAttribute("NoJuice", true)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 12
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local dim = Instance.new("TextButton")
dim.Name = "Dim"
dim.Text = ""
dim.AutoButtonColor = false
dim.Selectable = false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(10, 6, 20)
dim.BackgroundTransparency = 1
dim.Parent = gui

local root = Instance.new("Frame")
root.Name = "Root"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.52)
root.Size = UDim2.fromOffset(W, H)
root.BackgroundTransparency = 1
root.Parent = gui
local rootScale = Instance.new("UIScale")
rootScale.Parent = root
local fitScale = 1

-- Cadre principal : carrosserie doree de la machine.
local shell = frame(root, { Name = "Shell", Size = UDim2.fromScale(1, 1), ZIndex = 1 })
UI.corner(shell, 22)
UI.stroke(shell, 6, BLACK)
UI.gradient(shell, Color3.fromRGB(255, 226, 90), Color3.fromRGB(226, 146, 10))
UI.studs(shell, 40, 0.58, 22)
shell.Active = true

-- En-tete
local header = frame(shell, { Name = "Header", Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 76), BackgroundColor3 = Color3.fromRGB(40, 20, 60) })
UI.corner(header, 14)
UI.stroke(header, 4, BLACK)
UI.gradient(header, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 140, 170))
UI.studs(header, 28, 0.78, 14, WHITE)
header.BackgroundColor3 = Color3.fromRGB(70, 30, 120)

local title = UI.text(header, "TRAIT MACHINE", 54, WHITE, FONT_TITLE, 5)
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.5)
title.Size = UDim2.fromOffset(470, 62)
title.ZIndex = header.ZIndex + 3

local starIcon = UI.text(header, "⭐", 50, WHITE, FONT, 3)
starIcon.AnchorPoint = Vector2.new(1, 0.5)
starIcon.Position = UDim2.new(0.5, -240, 0.5, 0)
starIcon.Size = UDim2.fromOffset(62, 62)
starIcon.ZIndex = header.ZIndex + 3
local starIcon2 = UI.text(header, "⭐", 50, WHITE, FONT, 3)
starIcon2.AnchorPoint = Vector2.new(0, 0.5)
starIcon2.Position = UDim2.new(0.5, 240, 0.5, 0)
starIcon2.Size = UDim2.fromOffset(62, 62)
starIcon2.ZIndex = header.ZIndex + 3
local titleGrad = UI.gradient(title, ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 200)),
	ColorSequenceKeypoint.new(0.5, GOLD),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 250, 200)),
}), nil, 0)
UI.shine(header, 3.5, 0.1)

local luckPill = frame(header, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(200, 50), BackgroundColor3 = Color3.fromRGB(20, 60, 25) })
UI.round(luckPill)
UI.stroke(luckPill, 3, BLACK)
UI.gradient(luckPill, Color3.fromRGB(90, 220, 90), Color3.fromRGB(20, 120, 40))
local luckPillText = UI.text(luckPill, "🍀 0 ROLLS", 24, WHITE, FONT_TITLE, 3)
luckPillText.Size = UDim2.new(1, -16, 1, -8)
luckPillText.Position = UDim2.fromOffset(8, 4)
luckPillText.ZIndex = luckPill.ZIndex + 2

local infoButton = fancyButton(header, "?", C.blue, 36)
infoButton.AnchorPoint = Vector2.new(1, 0.5)
infoButton.Position = UDim2.new(1, -82, 0.5, 0)
infoButton.Size = UDim2.fromOffset(60, 56)

local closeButton = fancyButton(header, "X", C.red, 38)
closeButton.AnchorPoint = Vector2.new(1, 0.5)
closeButton.Position = UDim2.new(1, -12, 0.5, 0)
closeButton.Size = UDim2.fromOffset(60, 56)

--== Zone machine (gauche) ==--
local machine = frame(shell, { Name = "Machine", Position = UDim2.fromOffset(14, 100), Size = UDim2.new(0, LEFT_W, 1, -114), BackgroundColor3 = Color3.fromRGB(28, 18, 40), ClipsDescendants = true })
UI.corner(machine, 16)
UI.stroke(machine, 4, BLACK)
UI.gradient(machine, Color3.fromRGB(255, 255, 255), Color3.fromRGB(130, 120, 150))
UI.studs(machine, 36, 0.8, 16, WHITE)

local hint = UI.text(machine, "SELECT UP TO 4 BRAINROTS", 30, WHITE, FONT_TITLE, 3)
hint.Position = UDim2.fromOffset(0, 16)
hint.Size = UDim2.new(1, 0, 0, 36)

local slotsRow = frame(machine, { Name = "Slots", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, REEL_H + CARD_H + 16) })
UI.list(slotsRow, Enum.FillDirection.Horizontal, 24, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)

local controls = frame(machine, { Name = "Controls", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -22), Size = UDim2.new(1, -44, 0, 116) })

local autoButton = fancyButton(controls, "", C.purple, 26)
autoButton.Position = UDim2.fromOffset(0, 4)
autoButton.Size = UDim2.fromOffset(200, 72)
autoButton.Label.Text = "AUTO"
autoButton.Label.Size = UDim2.new(1, -12, 0, 30)
autoButton.Label.Position = UDim2.fromOffset(6, 5)
local switch = frame(autoButton, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(82, 28), BackgroundColor3 = Color3.fromRGB(40, 20, 60) })
switch.ZIndex = autoButton.ZIndex + 3
UI.round(switch)
UI.stroke(switch, 3, BLACK)
local knob = frame(switch, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = C.red })
UI.round(knob)
local knobText = UI.text(switch, "OFF", 16, WHITE, FONT_TITLE, 2)
knobText.AnchorPoint = Vector2.new(1, 0.5)
knobText.Position = UDim2.new(1, -8, 0.5, 0)
knobText.Size = UDim2.fromOffset(44, 20)
knobText.ZIndex = switch.ZIndex + 2

-- AUTO s'arrete (et retire le brainrot) quand ce trait ou mieux est obtenu.
local stopAtRank = #TraitShared.TRAITS
local stopButton = fancyButton(controls, "", Color3.fromRGB(70, 50, 100), 17)
stopButton.Position = UDim2.fromOffset(0, 80)
stopButton.Size = UDim2.fromOffset(200, 34)
local function refreshStopAt()
	local t = TraitShared.TRAITS[stopAtRank]
	stopButton.Label.Text = ("STOP AT: %s+"):format(string.upper(t.name))
	stopButton.Label.TextColor3 = t.color:Lerp(WHITE, 0.3)
end
refreshStopAt()
stopButton.Activated:Connect(function()
	stopAtRank = stopAtRank % #TraitShared.TRAITS + 1
	if stopAtRank == 1 then
		stopAtRank = 2
	end
	UISounds.Play("Tab")
	refreshStopAt()
end)

local rollButton = fancyButton(controls, "ROLL", C.green, 56)
rollButton.AnchorPoint = Vector2.new(0.5, 0)
rollButton.Position = UDim2.new(0.5, 0, 0, 6)
rollButton.Size = UDim2.fromOffset(320, 108)
rollButton.Label.Size = UDim2.new(1, -12, 0, 58)
rollButton.Label.Position = UDim2.fromOffset(6, 8)
local costLabel = UI.text(rollButton, "", 24, Color3.fromRGB(230, 255, 170), FONT_TITLE, 3)
costLabel.Position = UDim2.fromOffset(6, 66)
costLabel.Size = UDim2.new(1, -12, 0, 28)
costLabel.ZIndex = rollButton.ZIndex + 3
local rollKey = UI.text(rollButton, "", 20, WHITE, FONT_TITLE, 2)
rollKey.AnchorPoint = Vector2.new(0, 0)
rollKey.Position = UDim2.fromOffset(10, 6)
rollKey.Size = UDim2.fromOffset(40, 24)
rollKey.ZIndex = rollButton.ZIndex + 4
UI.shine(rollButton, 2.2)

local clearButton = fancyButton(controls, "CLEAR", C.red, 26)
clearButton.AnchorPoint = Vector2.new(1, 0)
clearButton.Position = UDim2.new(1, 0, 0, 22)
clearButton.Size = UDim2.fromOffset(200, 38)
local fillButton = fancyButton(controls, "✨ FILL BEST", C.blue, 22)
fillButton.AnchorPoint = Vector2.new(1, 0)
fillButton.Position = UDim2.new(1, 0, 0, 64)
fillButton.Size = UDim2.fromOffset(200, 38)

--== Colonne droite : onglets ODDS / LUCK ==--
local side = frame(shell, { Name = "Side", Position = UDim2.fromOffset(LEFT_W + 28, 100), Size = UDim2.new(1, -(LEFT_W + 42), 1, -114), BackgroundColor3 = Color3.fromRGB(28, 18, 40) })
UI.corner(side, 16)
UI.stroke(side, 4, BLACK)
UI.gradient(side, Color3.fromRGB(255, 255, 255), Color3.fromRGB(130, 120, 150))
UI.studs(side, 36, 0.8, 16, WHITE)

local tabs = frame(side, { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 50) })
local tabGrid = Instance.new("UIGridLayout")
tabGrid.CellSize = UDim2.new(0.5, -5, 1, 0)
tabGrid.CellPadding = UDim2.fromOffset(10, 0)
tabGrid.SortOrder = Enum.SortOrder.LayoutOrder
tabGrid.Parent = tabs
local oddsTab = fancyButton(tabs, "ODDS", GOLD, 26)
oddsTab.LayoutOrder = 1
local luckTab = fancyButton(tabs, "🍀 LUCK", C.green, 26)
luckTab.LayoutOrder = 2

local pages = frame(side, { BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(10, 70), Size = UDim2.new(1, -20, 1, -80) })
local oddsPage = frame(pages, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
local luckPage = frame(pages, { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })

-- ODDS
local luckTag = UI.text(oddsPage, "", 18, LUCK_GREEN, FONT_TITLE, 2)
luckTag.Size = UDim2.new(1, 0, 0, 22)
local oddsList = frame(oddsPage, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26) })
UI.list(oddsList, Enum.FillDirection.Vertical, 10)
local oddsRows = {}
local maxLog = math.log(TraitShared.TRAITS[#TraitShared.TRAITS].odds + 1)
for i, t in ipairs(TraitShared.TRAITS) do
	local row = frame(oddsList, { LayoutOrder = i, Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = Color3.fromRGB(16, 10, 26), BackgroundTransparency = 0.25 })
	UI.corner(row, 10)
	UI.stroke(row, 2.5, t.color:Lerp(BLACK, 0.3))
	local icon = traitIcon(row, t)
	icon.Position = UDim2.fromOffset(4, 5)
	icon.Size = UDim2.fromOffset(46, 46)
	local name = UI.text(row, ("%s <font color=\"#%s\">%s</font>"):format(string.upper(t.name), t.color:ToHex(), TraitShared.FormatMult(t.mult)), 20, WHITE, FONT_TITLE, 2)
	name.Position = UDim2.fromOffset(54, 6)
	name.Size = UDim2.new(1, -150, 0, 24)
	name.TextXAlignment = Enum.TextXAlignment.Left
	local odd = UI.text(row, "1/" .. t.odds, 22, WHITE, FONT_TITLE, 2)
	odd.AnchorPoint = Vector2.new(1, 0)
	odd.Position = UDim2.new(1, -8, 0, 6)
	odd.Size = UDim2.fromOffset(100, 24)
	odd.TextXAlignment = Enum.TextXAlignment.Right
	local barBg = frame(row, { Position = UDim2.fromOffset(54, 38), Size = UDim2.new(1, -64, 0, 12), BackgroundColor3 = Color3.fromRGB(50, 40, 64) })
	UI.round(barBg)
	local bar = frame(barBg, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = t.color })
	UI.round(bar)
	UI.gradient(bar, t.color:Lerp(WHITE, 0.35), t.color)
	oddsRows[t.key] = { odd = odd, bar = bar, row = row, t = t }
end

-- LUCK
local luckHead = UI.text(luckPage, ("%dx LUCK"):format(TraitShared.LUCK_MULT), 40, WHITE, FONT_TITLE, 4)
luckHead.Size = UDim2.new(1, 0, 0, 44)
UI.gradient(luckHead, Color3.fromRGB(200, 255, 170), Color3.fromRGB(60, 220, 60))
local luckSub = UI.text(luckPage, "Every trait 10x more likely on your next rolls!", 16, GREY, FONT, 2)
luckSub.Position = UDim2.fromOffset(0, 44)
luckSub.Size = UDim2.new(1, 0, 0, 36)
luckSub.TextWrapped = true
local packsHolder = frame(luckPage, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 290) })
UI.list(packsHolder, Enum.FillDirection.Vertical, 10)
local rainbowGrads = {}
local PACK_COLORS = { Color3.fromRGB(80, 220, 60), Color3.fromRGB(180, 70, 255), "rainbow" }

local useLuckButton = fancyButton(luckPage, "", Color3.fromRGB(60, 60, 70), 22)
useLuckButton.AnchorPoint = Vector2.new(0, 1)
useLuckButton.Position = UDim2.new(0, 0, 1, 0)
useLuckButton.Size = UDim2.new(1, 0, 0, 56)

--== Tiroir de selection ==--
local drawer = frame(machine, { Name = "Drawer", Position = UDim2.new(0, 0, 1, 10), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(22, 14, 34), Visible = false, ZIndex = 60 })
drawer.Active = true
UI.corner(drawer, 16)
UI.stroke(drawer, 4, GOLD)
UI.studs(drawer, 36, 0.8, 16, WHITE)
local drawerTitle = UI.text(drawer, "CHOOSE BRAINROTS", 34, GOLD, FONT_TITLE, 3)
drawerTitle.AnchorPoint = Vector2.new(0.5, 0)
drawerTitle.Position = UDim2.new(0.5, -60, 0, 12)
drawerTitle.Size = UDim2.new(0.5, 0, 0, 40)
local drawerCount = UI.text(drawer, "0/4", 28, WHITE, FONT_TITLE, 3)
drawerCount.AnchorPoint = Vector2.new(1, 0)
drawerCount.Position = UDim2.new(1, -170, 0, 16)
drawerCount.Size = UDim2.fromOffset(100, 34)
local drawerDone = fancyButton(drawer, "DONE", C.green, 28)
drawerDone.AnchorPoint = Vector2.new(1, 0)
drawerDone.Position = UDim2.new(1, -14, 0, 10)
drawerDone.Size = UDim2.fromOffset(140, 48)
drawerDone.ZIndex = drawer.ZIndex + 2
local drawerEmpty = UI.text(drawer, "No brainrots in your inventory!", 26, GREY, FONT_TITLE, 2)
drawerEmpty.AnchorPoint = Vector2.new(0.5, 0.5)
drawerEmpty.Position = UDim2.fromScale(0.5, 0.5)
drawerEmpty.Size = UDim2.new(1, -40, 0, 40)
drawerEmpty.Visible = false
local grid = Instance.new("ScrollingFrame")
grid.Position = UDim2.fromOffset(14, 112)
grid.Size = UDim2.new(1, -28, 1, -124)
grid.BackgroundTransparency = 1
grid.BorderSizePixel = 0
grid.ScrollBarThickness = 8
grid.ScrollBarImageColor3 = GOLD
grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
grid.CanvasSize = UDim2.new()
grid.ZIndex = drawer.ZIndex + 1
grid.Parent = drawer
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromOffset(170, 206)
gridLayout.CellPadding = UDim2.fromOffset(14, 14)
gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = grid
UI.padding(grid, 6)

-- Filtres du tiroir.
local drawerFilter = "ALL"
local filterButtons = {}
local filterRow = frame(drawer, { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 0, 40), ZIndex = drawer.ZIndex + 1 })
UI.list(filterRow, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
local FILTERS = { { "ALL", "ALL" }, { "NOTRAIT", "NO TRAIT" }, { "UPGRADE", "CAN UPGRADE" } }
local fillDrawer
for i, f in ipairs(FILTERS) do
	local b = fancyButton(filterRow, f[2], Color3.fromRGB(80, 70, 95), 18)
	b.LayoutOrder = i
	b.Size = UDim2.fromOffset(i == 3 and 170 or 130, 38)
	b.ZIndex = drawer.ZIndex + 2
	filterButtons[f[1]] = b
	b.Activated:Connect(function()
		if drawerFilter == f[1] then
			return
		end
		drawerFilter = f[1]
		UISounds.Play("Tab")
		for k, fb in pairs(filterButtons) do
			recolor(fb, k == drawerFilter and GOLD or Color3.fromRGB(80, 70, 95))
		end
		fillDrawer()
	end)
end
recolor(filterButtons.ALL, GOLD)

--== Panneau INFO ==--
local info = frame(shell, { Name = "Info", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(640, 440), BackgroundColor3 = Color3.fromRGB(24, 40, 90), Visible = false, ZIndex = 90 })
info.Active = true
UI.corner(info, 18)
UI.stroke(info, 5, BLACK)
UI.gradient(info, Color3.fromRGB(90, 170, 255), Color3.fromRGB(30, 70, 190))
UI.studs(info, 34, 0.62, 18)
local infoTitle = UI.text(info, "ℹ HOW IT WORKS", 40, WHITE, FONT_TITLE, 4)
infoTitle.Position = UDim2.fromOffset(0, 16)
infoTitle.Size = UDim2.new(1, 0, 0, 46)
local infoBody = UI.text(info, table.concat({
	"1. Pick up to <b>4 brainrots</b> from your inventory.",
	"2. Press <b>ROLL</b>: each one rolls a random trait.",
	("3. Cost = <b>%ds</b> of their income."):format(TraitShared.COST_SECONDS),
	"4. A trait is only replaced by a <b>BETTER</b> one!",
	"5. Traits multiply the brainrot's income (up to <b>7x</b>).",
	("6. <font color=\"#78ff78\">%dx LUCK</font> makes every trait %dx more likely."):format(TraitShared.LUCK_MULT, TraitShared.LUCK_MULT),
}, "\n"), 26, WHITE, FONT, 2)
infoBody.Position = UDim2.fromOffset(30, 76)
infoBody.Size = UDim2.new(1, -60, 0, 270)
infoBody.TextWrapped = true
infoBody.TextYAlignment = Enum.TextYAlignment.Top
local infoOk = fancyButton(info, "GOT IT!", C.green, 30)
infoOk.AnchorPoint = Vector2.new(0.5, 1)
infoOk.Position = UDim2.new(0.5, 0, 1, -18)
infoOk.Size = UDim2.fromOffset(240, 62)

--== Toast / Banniere ==--
local toast = UI.text(shell, "", 30, WHITE, FONT_TITLE, 3)
toast.AnchorPoint = Vector2.new(0.5, 0.5)
toast.Position = UDim2.new(0, 14 + LEFT_W / 2, 0, 370)
toast.Size = UDim2.fromOffset(640, 56)
toast.BackgroundColor3 = BLACK
toast.BackgroundTransparency = 0.25
toast.ZIndex = 120
toast.Visible = false
UI.corner(toast, 14)
local toastToken = 0
local function showToast(msg: string, color: Color3?)
	toastToken += 1
	local my = toastToken
	toast.Text = msg
	toast.TextColor3 = color or WHITE
	toast.Visible = true
	UI.pop(toast, 0, 0.6)
	task.delay(2, function()
		if my == toastToken then
			toast.Visible = false
		end
	end)
end

local flash = frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 200 })
flash.Active = false
local bigBanner = UI.text(gui, "", 96, WHITE, FONT_TITLE, 6)
bigBanner.AnchorPoint = Vector2.new(0.5, 0.5)
bigBanner.Position = UDim2.fromScale(0.5, 0.3)
bigBanner.Size = UDim2.fromOffset(900, 110)
bigBanner.ZIndex = 210
bigBanner.Visible = false
local bannerIcon = Instance.new("ImageLabel")
bannerIcon.BackgroundTransparency = 1
bannerIcon.ScaleType = Enum.ScaleType.Fit
bannerIcon.AnchorPoint = Vector2.new(0.5, 1)
bannerIcon.Position = UDim2.new(0.5, 0, 0.3, -50)
bannerIcon.Size = UDim2.fromOffset(150, 150)
bannerIcon.ZIndex = 211
bannerIcon.Visible = false
bannerIcon.Parent = gui

--== Etat ==--
local isOpen = false
local selected: { Tool } = {}
local slots = {}
local auto = false
local rolling = false
local useLuck = true
local costToken = 0
local lastCost = 0
local currentTab = "ODDS"

local function incomeOf(tool: Tool): number
	return tonumber(tool:GetAttribute("Income")) or 0
end

local function isSelected(tool: Tool): boolean
	return table.find(selected, tool) ~= nil
end

local function stillOwned(tool: Tool): boolean
	local parent = tool.Parent
	return parent ~= nil and (parent == player:FindFirstChildOfClass("Backpack") or parent == player.Character)
end

local function validTools(): { Tool }
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

local function luckCount(): number
	return tonumber(player:GetAttribute("TraitLuck")) or 0
end

local function luckActive(): boolean
	return useLuck and luckCount() > 0
end

--== Carte brainrot ==--
local function buildCard(parent: Instance, tool: Tool, z: number)
	local handle = tool:FindFirstChild("Handle")
	local rarity = Inv.GetRarity(tool)
	local card = frame(parent, { Name = "Card", Size = UDim2.fromScale(1, 1), ZIndex = z })
	UI.corner(card, 12)
	local cs = UI.stroke(card, 4, rarity.color)
	UI.gradient(card, rarity.color:Lerp(BLACK, 0.15), rarity.color:Lerp(BLACK, 0.72))
	UI.studs(card, 24, 0.7, 12)

	local rar = UI.text(card, string.upper(rarity.name or ""), 16, rarity.color:Lerp(WHITE, 0.45), FONT_TITLE, 2)
	rar.Position = UDim2.fromOffset(8, 6)
	rar.Size = UDim2.new(1, -64, 0, 18)
	rar.TextXAlignment = Enum.TextXAlignment.Left
	rar.ZIndex = z + 3
	local mutation = handle and handle:GetAttribute("Mutation")
	if type(mutation) == "string" then
		local m = UI.text(card, string.upper(mutation), 15, MUTATION_COLORS[mutation] or WHITE, FONT_TITLE, 2)
		m.Position = UDim2.fromOffset(8, 24)
		m.Size = UDim2.new(1, -64, 0, 16)
		m.TextXAlignment = Enum.TextXAlignment.Left
		m.ZIndex = z + 3
	end
	local lvl = UI.text(card, "LVL " .. tostring(handle and handle:GetAttribute("Level") or 1), 15, WHITE, FONT_TITLE, 2)
	lvl.AnchorPoint = Vector2.new(1, 0)
	lvl.Position = UDim2.new(1, -8, 0, 6)
	lvl.Size = UDim2.fromOffset(60, 18)
	lvl.TextXAlignment = Enum.TextXAlignment.Right
	lvl.ZIndex = z + 3

	local holder = frame(card, { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 40), Size = UDim2.new(1, -12, 1, -112), ZIndex = z + 1 })
	local vp = Inv.CreateViewport(tool, holder)
	if vp then
		vp.ZIndex = z + 1
	end

	local traitPill = frame(card, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -48), Size = UDim2.new(1, -18, 0, 26), BackgroundColor3 = BLACK, BackgroundTransparency = 0.35, ZIndex = z + 2 })
	UI.round(traitPill)
	local traitText = UI.text(traitPill, "", 18, WHITE, FONT_TITLE, 2)
	traitText.Size = UDim2.new(1, -34, 1, -4)
	traitText.Position = UDim2.fromOffset(28, 2)
	traitText.ZIndex = z + 3
	local traitImg = Instance.new("ImageLabel")
	traitImg.BackgroundTransparency = 1
	traitImg.ScaleType = Enum.ScaleType.Fit
	traitImg.AnchorPoint = Vector2.new(0, 0.5)
	traitImg.Position = UDim2.new(0, 2, 0.5, 0)
	traitImg.Size = UDim2.fromOffset(28, 28)
	traitImg.ZIndex = z + 4
	traitImg.Parent = traitPill

	local inc = UI.text(card, "", 18, Color3.fromRGB(150, 255, 70), FONT_TITLE, 2)
	inc.AnchorPoint = Vector2.new(0.5, 1)
	inc.Position = UDim2.new(0.5, 0, 1, -24)
	inc.Size = UDim2.new(1, -10, 0, 20)
	inc.ZIndex = z + 3
	local nm = UI.text(card, Inv.GetDisplayName(tool), 15, WHITE, FONT, 2)
	nm.AnchorPoint = Vector2.new(0.5, 1)
	nm.Position = UDim2.new(0.5, 0, 1, -5)
	nm.Size = UDim2.new(1, -10, 0, 17)
	nm.TextTruncate = Enum.TextTruncate.AtEnd
	nm.ZIndex = z + 3

	local function refresh()
		local t = TraitShared.GetTrait(tool)
		if t then
			traitImg.Image = TraitShared.Image(t)
			traitImg.Visible = true
			traitText.Text = ("%s %s"):format(string.upper(t.name), TraitShared.FormatMult(t.mult))
			traitText.TextColor3 = t.color
			cs.Color = t.color
			traitPill.BackgroundColor3 = t.color:Lerp(BLACK, 0.75)
		else
			traitImg.Visible = false
			traitText.Text = "NO TRAIT"
			traitText.TextColor3 = GREY
			cs.Color = rarity.color
			traitPill.BackgroundColor3 = BLACK
		end
		inc.Text = "+$" .. NumberFormat.Format(incomeOf(tool)) .. "/s"
	end
	refresh()
	return card, refresh, cs
end

--== Rouleaux ==--
local TRAIT_ICONS = {}
for _, t in ipairs(TraitShared.TRAITS) do
	table.insert(TRAIT_ICONS, t)
end

local function randomTrait()
	-- Les rares apparaissent moins souvent sur le rouleau (effet "presque !").
	local r = math.random()
	if r < 0.35 then
		return TRAIT_ICONS[1]
	elseif r < 0.6 then
		return TRAIT_ICONS[2]
	end
	return TRAIT_ICONS[math.random(1, #TRAIT_ICONS)]
end

local function reelIcon(parent: Instance, t, index: number, z: number)
	local l = traitIcon(parent, t, z)
	l.Position = UDim2.fromOffset(0, (index - 1) * ICON_H + 8)
	l.Size = UDim2.new(1, 0, 0, ICON_H - 16)
	return l
end

local function buildReel(parent: Instance, z: number)
	local reel = frame(parent, { Name = "Reel", Size = UDim2.new(1, 0, 0, REEL_H), BackgroundColor3 = Color3.fromRGB(255, 250, 235), ClipsDescendants = true, ZIndex = z })
	UI.corner(reel, 12)
	UI.stroke(reel, 4, BLACK)
	UI.gradient(reel, Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 195, 185))
	local strip = frame(reel, { Name = "Strip", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ICON_H), ZIndex = z + 1 })
	reelIcon(strip, TRAIT_ICONS[math.random(1, #TRAIT_ICONS)], 1, z + 2)
	-- Ombres haut / bas : effet de cylindre.
	local shade = frame(reel, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, ZIndex = z + 4 })
	shade.BackgroundTransparency = 0
	local sg = Instance.new("UIGradient")
	sg.Rotation = 90
	sg.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(0.28, 1),
		NumberSequenceKeypoint.new(0.72, 1),
		NumberSequenceKeypoint.new(1, 0.45),
	})
	sg.Parent = shade
	local line = frame(reel, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 2), BackgroundColor3 = C.red, BackgroundTransparency = 0.5, ZIndex = z + 5 })
	line.Name = "Payline"
	return reel, strip
end

-- Fait tourner un rouleau et s'arrete sur `final`. Bloquant.
local function spin(strip: Frame, final, duration: number, z: number, onTick: ((number) -> ())?)
	for _, c in ipairs(strip:GetChildren()) do
		c:Destroy()
	end
	local count = 18 + math.floor(duration * 10)
	for i = 1, count do
		reelIcon(strip, randomTrait(), i, z)
	end
	reelIcon(strip, final, count + 1, z)
	strip.Size = UDim2.new(1, 0, 0, (count + 1) * ICON_H)
	strip.Position = UDim2.fromOffset(0, 0)
	local target = -count * ICON_H
	local tw = TweenService:Create(strip, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromOffset(0, target) })
	local lastIndex = 0
	local conn = RunService.RenderStepped:Connect(function()
		local idx = math.floor(-strip.Position.Y.Offset / ICON_H)
		if idx ~= lastIndex then
			lastIndex = idx
			if onTick then
				onTick(idx / count)
			end
		end
	end)
	tw:Play()
	tw.Completed:Wait()
	conn:Disconnect()
	-- Petit rebond d'arret.
	strip.Position = UDim2.fromOffset(0, target + 10)
	UI.tween(strip, 0.18, { Position = UDim2.fromOffset(0, target) }, Enum.EasingStyle.Back)
end

--== Slots ==--
local refreshSlots
local openDrawer

local function clearSlots()
	for _, s in ipairs(slots) do
		s.frame:Destroy()
	end
	table.clear(slots)
end

local function makeSlot(i: number, tool: Tool?)
	local col = frame(slotsRow, { Name = "Slot" .. i, LayoutOrder = i, BackgroundTransparency = 1, Size = UDim2.fromOffset(SLOT_W, REEL_H + CARD_H + 12), ZIndex = 5 })
	local reel, strip = buildReel(col, 6)
	local slot = { frame = col, reel = reel, strip = strip, tool = tool }

	local lamp = frame(col, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, REEL_H + 6), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = Color3.fromRGB(90, 60, 30), ZIndex = 14 })
	UI.round(lamp)
	UI.stroke(lamp, 2.5, BLACK)
	slot.lamp = lamp

	local body = frame(col, { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, REEL_H + 12), Size = UDim2.fromOffset(SLOT_W, CARD_H), ZIndex = 6 })
	slot.body = body

	if tool then
		local card, refresh, cs = buildCard(body, tool, 7)
		slot.refresh = refresh
		slot.card = card
		slot.cardStroke = cs
		local x = fancyButton(body, "X", C.red, 22)
		x.AnchorPoint = Vector2.new(0.5, 0.5)
		x.Position = UDim2.new(1, -6, 0, 6)
		x.Size = UDim2.fromOffset(38, 36)
		x.ZIndex = 30
		x.Activated:Connect(function()
			if rolling then
				return
			end
			local idx = table.find(selected, tool)
			if idx then
				table.remove(selected, idx)
			end
			UISounds.Play("Delete")
			refreshSlots(true)
		end)
		local badge = UI.text(col, "", 30, GOLD, FONT_TITLE, 4)
		badge.AnchorPoint = Vector2.new(0.5, 0.5)
		badge.Position = UDim2.new(0.5, 0, 0, REEL_H + 40)
		badge.Size = UDim2.new(1, 20, 0, 36)
		badge.Rotation = -8
		badge.ZIndex = 40
		badge.Visible = false
		slot.badge = badge
	else
		local empty = Instance.new("TextButton")
		empty.Name = "Add"
		empty.Text = ""
		empty.AutoButtonColor = false
		empty.Size = UDim2.fromScale(1, 1)
		empty.BackgroundColor3 = GOLD
		empty.BackgroundTransparency = 0.7
		empty.ZIndex = 7
		empty.Parent = body
		UI.corner(empty, 12)
		local es = UI.stroke(empty, 4, GOLD)
		es.Transparency = 0.1
		local plus = frame(empty, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(92, 92), ZIndex = 8 })
		UI.corner(plus, 14)
		UI.stroke(plus, 4, Color3.fromRGB(20, 110, 20))
		UI.gradient(plus, Color3.fromRGB(150, 255, 110), Color3.fromRGB(40, 190, 40))
		UI.studs(plus, 22, 0.62, 14)
		-- "+" dessine avec 2 barres : parfaitement centre (le "+" de la police ne l'est pas).
		for _, sz in ipairs({ UDim2.fromOffset(52, 14), UDim2.fromOffset(14, 52) }) do
			local bar = frame(plus, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = sz, BackgroundColor3 = WHITE, ZIndex = 10 })
			UI.corner(bar, 4)
			UI.stroke(bar, 3, Color3.fromRGB(20, 110, 20))
		end
		local add = UI.text(empty, "ADD", 24, WHITE, FONT_TITLE, 3)
		add.AnchorPoint = Vector2.new(0.5, 1)
		add.Position = UDim2.new(0.5, 0, 1, -14)
		add.Size = UDim2.new(1, 0, 0, 28)
		add.ZIndex = 9
		UI.pressable(empty, 1.04)
		empty.Activated:Connect(function()
			if rolling then
				return
			end
			UISounds.Play("Click")
			openDrawer()
		end)
		slot.add = empty
		task.spawn(function()
			local t0 = os.clock() + i * 0.3
			while plus.Parent do
				local s = UI.scaleOf(plus)
				s.Scale = 1 + math.sin((os.clock() - t0) * 3) * 0.05
				RunService.RenderStepped:Wait()
			end
		end)
	end
	return slot
end

local updateCost
local refreshAfford

refreshSlots = function(animate: boolean?)
	for i = #selected, 1, -1 do
		if not stillOwned(selected[i]) then
			table.remove(selected, i)
		end
	end
	clearSlots()
	for i = 1, TraitShared.MAX_SELECTED do
		local slot = makeSlot(i, selected[i])
		slots[i] = slot
		if animate then
			UI.pop(slot.body, (i - 1) * 0.05, 0.7)
		end
	end
	hint.Text = #selected == 0 and "SELECT UP TO 4 BRAINROTS" or ("%d/%d SELECTED"):format(#selected, TraitShared.MAX_SELECTED)
	updateCost()
end

--== Cout / luck ==--
local function cash(): number
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild("Cash")
	return v and v:IsA("ValueBase") and tonumber((v :: any).Value) or 0
end

-- Rouge + bouton grise si le joueur n'a pas assez de cash.
refreshAfford = function()
	if rolling then
		return
	end
	local ok = #selected > 0 and cash() >= lastCost
	costLabel.TextColor3 = (#selected == 0 or ok) and Color3.fromRGB(230, 255, 170) or Color3.fromRGB(255, 110, 110)
	recolor(rollButton, (#selected == 0 or ok) and C.green or Color3.fromRGB(150, 70, 70))
end
task.spawn(function()
	local ls = player:WaitForChild("leaderstats", 60)
	local v = ls and ls:WaitForChild("Cash", 30)
	if v and v:IsA("ValueBase") then
		v.Changed:Connect(function()
			if isOpen then
				refreshAfford()
			end
		end)
	end
end)

updateCost = function()
	costToken += 1
	local my = costToken
	if #selected == 0 then
		costLabel.Text = "SELECT A BRAINROT"
		lastCost = 0
		refreshAfford()
		return
	end
	task.spawn(function()
		local cost = remote:InvokeServer("GetCost", selected)
		if my ~= costToken then
			return
		end
		local from = lastCost
		lastCost = tonumber(cost) or 0
		UI.countUp(costLabel, from, lastCost, function(v)
			return "COST: $" .. NumberFormat.Format(math.floor(v))
		end, 0.35)
		refreshAfford()
	end)
end

local function updateLuck()
	local n = luckCount()
	luckPillText.Text = ("🍀 %d ROLL%s"):format(n, n == 1 and "" or "S")
	local active = luckActive()
	if n > 0 then
		useLuckButton.Label.Text = active and "🍀 USE LUCK: ON" or "USE LUCK: OFF"
		recolor(useLuckButton, active and Color3.fromRGB(50, 200, 70) or Color3.fromRGB(80, 80, 90))
	else
		useLuckButton.Label.Text = "NO LUCKY ROLLS"
		recolor(useLuckButton, Color3.fromRGB(80, 80, 90))
	end
	luckTag.Text = active and ("🍀 %dx LUCK ACTIVE!"):format(TraitShared.LUCK_MULT) or ""
	local mult = active and TraitShared.LUCK_MULT or 1
	for _, r in pairs(oddsRows) do
		local n2 = math.max(1, math.floor(r.t.odds / mult + 0.5))
		r.odd.Text = "1/" .. NumberFormat.Format(n2)
		r.odd.TextColor3 = mult > 1 and LUCK_GREEN or WHITE
		local ratio = 1 - math.log(n2 + 1) / maxLog
		UI.tween(r.bar, 0.4, { Size = UDim2.fromScale(math.clamp(0.08 + ratio * 0.92, 0.08, 1), 1) }, Enum.EasingStyle.Quart)
	end
end
player:GetAttributeChangedSignal("TraitLuck"):Connect(updateLuck)
useLuckButton.Activated:Connect(function()
	if luckCount() <= 0 then
		UISounds.Play("BuyFail")
		UI.shake(useLuckButton)
		return
	end
	UISounds.Play("Tab")
	useLuck = not useLuck
	updateLuck()
end)

for i, p in ipairs(TraitShared.LUCK_PRODUCTS) do
	local col = PACK_COLORS[i]
	local b = fancyButton(packsHolder, "", typeof(col) == "Color3" and col or Color3.fromRGB(255, 255, 255), 30)
	b.LayoutOrder = i
	b.Size = UDim2.new(1, 0, 0, 86)
	if col == "rainbow" then
		b.Fill.Color = UI.RAINBOW
		b.Fill.Rotation = 0
		table.insert(rainbowGrads, b.Fill)
		UI.shine(b, 1.6)
	end
	b.Label.Text = ROBUX .. " " .. p.price
	b.Label.Size = UDim2.new(1, -12, 0, 44)
	b.Label.Position = UDim2.fromOffset(6, 6)
	local sub = UI.text(b, ("x%d LUCKY ROLL%s"):format(p.rolls, p.rolls > 1 and "S" or ""), 20, Color3.fromRGB(255, 255, 255), FONT_TITLE, 2)
	sub.Position = UDim2.fromOffset(6, 52)
	sub.Size = UDim2.new(1, -12, 0, 24)
	sub.ZIndex = b.ZIndex + 4
	if p.rolls >= 25 then
		local deal = UI.text(b, p.rolls >= 100 and "BEST DEAL!" or "POPULAR", 16, GOLD, FONT_TITLE, 2)
		deal.AnchorPoint = Vector2.new(1, 0)
		deal.Position = UDim2.new(1, 6, 0, -10)
		deal.Size = UDim2.fromOffset(110, 22)
		deal.Rotation = 8
		deal.ZIndex = b.ZIndex + 6
	end
	if p.id ~= 0 then
		task.spawn(function()
			local ok, infoData = pcall(function()
				return MarketplaceService:GetProductInfo(p.id, Enum.InfoType.Product)
			end)
			if ok and infoData and infoData.PriceInRobux then
				b.Label.Text = ROBUX .. " " .. infoData.PriceInRobux
			end
		end)
	end
	b.Activated:Connect(function()
		UISounds.Play("Click")
		local ok = remote:InvokeServer("BuyLuck", p.rolls)
		if not ok then
			UISounds.Play("BuyFail")
			showToast("COMING SOON!", GOLD)
		end
	end)
end

--== Onglets ==--
local function showTab(key: string)
	if currentTab == key then
		return
	end
	local goingRight = key == "LUCK"
	local show, hide = goingRight and luckPage or oddsPage, goingRight and oddsPage or luckPage
	show.Visible = true
	show.Position = UDim2.fromScale(goingRight and 1 or -1, 0)
	UI.tween(show, 0.3, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back)
	UI.tween(hide, 0.2, { Position = UDim2.fromScale(goingRight and -1 or 1, 0) }).Completed:Connect(function()
		if currentTab == key then
			hide.Visible = false
		end
	end)
	currentTab = key
	recolor(oddsTab, key == "ODDS" and GOLD or Color3.fromRGB(80, 70, 95))
	recolor(luckTab, key == "LUCK" and C.green or Color3.fromRGB(80, 70, 95))
	UISounds.Play("Tab")
end
oddsTab.Activated:Connect(function()
	showTab("ODDS")
end)
luckTab.Activated:Connect(function()
	showTab("LUCK")
end)
recolor(luckTab, Color3.fromRGB(80, 70, 95))

--== Tiroir ==--
local drawerOpen = false

local function closeDrawer()
	if not drawerOpen then
		return
	end
	drawerOpen = false
	UISounds.Play("Swoosh")
	UI.PopModal("TraitDrawer")
	UI.tween(drawer, 0.22, { Position = UDim2.new(0, 0, 1, 10) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
		if not drawerOpen then
			drawer.Visible = false
		end
	end)
	refreshSlots(true)
end

fillDrawer = function()
	for _, c in ipairs(grid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local list = {}
	local maxRank = #TraitShared.TRAITS
	for _, tool in ipairs(validTools()) do
		local rank = TraitShared.GetRank(tool)
		if drawerFilter == "ALL" or isSelected(tool)
			or (drawerFilter == "NOTRAIT" and rank == 0)
			or (drawerFilter == "UPGRADE" and rank < maxRank) then
			table.insert(list, tool)
		end
	end
	drawerEmpty.Visible = #list == 0
	drawerCount.Text = ("%d/%d"):format(#selected, TraitShared.MAX_SELECTED)
	local first
	for order, tool in ipairs(list) do
		local b = Instance.new("TextButton")
		b.Text = ""
		b.AutoButtonColor = false
		b.BackgroundTransparency = 1
		b.LayoutOrder = order
		b.ZIndex = drawer.ZIndex + 2
		b.Parent = grid
		buildCard(b, tool, drawer.ZIndex + 3)
		UI.pressable(b, 1.05)
		first = first or b
		local check = frame(b, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(74, 74), BackgroundColor3 = C.green, ZIndex = drawer.ZIndex + 12, Visible = isSelected(tool) })
		UI.round(check)
		UI.stroke(check, 4, BLACK)
		local ct = UI.text(check, "✓", 56, WHITE, FONT_TITLE, 3)
		ct.Size = UDim2.fromScale(1, 1)
		ct.ZIndex = drawer.ZIndex + 13
		local veil = frame(b, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.5, ZIndex = drawer.ZIndex + 11, Visible = isSelected(tool) })
		UI.corner(veil, 12)
		b.Activated:Connect(function()
			if not stillOwned(tool) then
				return
			end
			local idx = table.find(selected, tool)
			if idx then
				table.remove(selected, idx)
				UISounds.Play("Delete")
			elseif #selected < TraitShared.MAX_SELECTED then
				table.insert(selected, tool)
				UISounds.Play("Pop")
				UI.pop(check, 0, 0.3)
			else
				UISounds.Play("BuyFail")
				UI.shake(drawerCount)
				return
			end
			check.Visible = isSelected(tool)
			veil.Visible = check.Visible
			drawerCount.Text = ("%d/%d"):format(#selected, TraitShared.MAX_SELECTED)
			UI.pop(drawerCount, 0, 0.7)
			if #selected >= TraitShared.MAX_SELECTED then
				task.delay(0.25, closeDrawer)
			end
		end)
		if order <= 12 then
			UI.pop(b, (order - 1) * 0.025, 0.6)
		end
	end
	return first
end

openDrawer = function()
	if drawerOpen then
		return
	end
	drawerOpen = true
	local first = fillDrawer()
	drawer.Visible = true
	drawer.Position = UDim2.new(0, 0, 1, 10)
	UI.tween(drawer, 0.35, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back)
	UISounds.Play("Open")
	UI.PushModal("TraitDrawer", closeDrawer, first or drawerDone)
end
drawerDone.Activated:Connect(closeDrawer)

local function fillBest()
	if rolling then
		return
	end
	local maxRank = #TraitShared.TRAITS
	table.clear(selected)
	for _, tool in ipairs(validTools()) do
		if #selected >= TraitShared.MAX_SELECTED then
			break
		end
		if TraitShared.GetRank(tool) < maxRank then
			table.insert(selected, tool)
		end
	end
	if #selected == 0 then
		UISounds.Play("BuyFail")
		showToast("NO BRAINROT TO UPGRADE!", C.red)
	else
		UISounds.Play("Success")
	end
	refreshSlots(true)
end
fillButton.Activated:Connect(fillBest)

clearButton.Activated:Connect(function()
	if rolling or #selected == 0 then
		return
	end
	UISounds.Play("Delete")
	table.clear(selected)
	refreshSlots(true)
end)

--== Auto ==--
local function setAuto(on: boolean)
	auto = on
	knobText.Text = on and "ON" or "OFF"
	knobText.AnchorPoint = on and Vector2.new(0, 0.5) or Vector2.new(1, 0.5)
	knobText.Position = on and UDim2.new(0, 8, 0.5, 0) or UDim2.new(1, -8, 0.5, 0)
	UI.tween(knob, 0.2, {
		Position = on and UDim2.new(1, -27, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		BackgroundColor3 = on and C.green or C.red,
	}, Enum.EasingStyle.Back)
end

--== Roll ==--
local worldReels = {}
local pullLever

local function allMaxed(): boolean
	local maxRank = #TraitShared.TRAITS
	for _, tool in ipairs(selected) do
		if TraitShared.GetRank(tool) < maxRank then
			return false
		end
	end
	return #selected > 0
end

local function celebrate(rolled)
	flash.BackgroundColor3 = rolled.color
	flash.BackgroundTransparency = 0.35
	UI.tween(flash, 0.6, { BackgroundTransparency = 1 })
	bigBanner.Text = ("%s! %s"):format(string.upper(rolled.name), TraitShared.FormatMult(rolled.mult))
	bannerIcon.Image = TraitShared.Image(rolled)
	bannerIcon.Visible = true
	UI.pop(bannerIcon, 0, 0.1)
	bannerIcon.Rotation = -20
	UI.tween(bannerIcon, 0.6, { Rotation = 0 }, Enum.EasingStyle.Back)
	task.delay(1.8, function()
		UI.tween(UI.scaleOf(bannerIcon), 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end)
	bigBanner.TextColor3 = rolled.color
	bigBanner.Visible = true
	local s = UI.scaleOf(bigBanner)
	s.Scale = 0.2
	bigBanner.Rotation = -6
	UI.tween(s, 0.45, { Scale = math.min(1, fitScale * 1.1) }, Enum.EasingStyle.Back)
	UI.tween(bigBanner, 0.45, { Rotation = 0 }, Enum.EasingStyle.Back)
	UI.burst(gui, UDim2.fromScale(0.5, 0.3), { rolled.color, GOLD, WHITE, rolled.color:Lerp(WHITE, 0.5) }, 50, 420, 220)
	UISounds.PlayOverlap("Success", 0.8)
	task.delay(1.8, function()
		UI.tween(s, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Wait()
		bigBanner.Visible = false
	end)
	UI.shake(root, 3)
end

local function spinSlot(slot, result, index: number)
	local rolled = TraitShared.Get(result.rolled) or TRAIT_ICONS[1]
	slot.lamp.BackgroundColor3 = GOLD
	local lampTween = TweenService:Create(slot.lamp, TweenInfo.new(0.12, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), { BackgroundColor3 = Color3.fromRGB(255, 250, 200) })
	lampTween:Play()
	spin(slot.strip, rolled, 1.1 + index * 0.35, 8, function(progress)
		if math.random() < 0.6 then
			UISounds.PlayOverlap("SmallClick", 1 + progress * 0.6, 0.2)
		end
	end)
	lampTween:Cancel()
	slot.lamp.BackgroundColor3 = result.improved and rolled.color or Color3.fromRGB(90, 60, 30)
	if worldReels[index] then
		worldReels[index](rolled)
	end
	if not slot.frame.Parent then
		return
	end
	local badge = slot.badge
	if result.improved then
		badge.Text = "NEW! " .. TraitShared.FormatMult(rolled.mult)
		badge.TextColor3 = rolled.color
		UISounds.PlayOverlap(rolled.rank >= 4 and "Success" or "Pop", 0.9 + rolled.rank * 0.05)
		local p = slot.frame.AbsolutePosition + slot.frame.AbsoluteSize / 2 - root.AbsolutePosition
		local s = rootScale.Scale
		UI.burst(root, UDim2.fromOffset(p.X / s, p.Y / s), { rolled.color, GOLD, WHITE }, 16 + rolled.rank * 4, 140 + rolled.rank * 20, 150)
		UI.ripple(slot.frame, UDim2.fromOffset(SLOT_W / 2, REEL_H / 2), rolled.color, 260, 45)
		if slot.cardStroke then
			slot.cardStroke.Thickness = 8
			UI.tween(slot.cardStroke, 0.5, { Thickness = 4 })
		end
		if rolled.rank >= 5 then
			celebrate(rolled)
		end
	else
		local kept = TraitShared.Get(result.trait)
		badge.Text = "KEPT " .. (kept and TraitShared.FormatMult(kept.mult) or "")
		badge.TextColor3 = GREY
		UISounds.PlayOverlap("SmallClick", 0.8, 0.4)
	end
	badge.Visible = true
	UI.pop(badge, 0, 0.2)
	if slot.refresh then
		slot.refresh()
	end
	task.delay(1.1, function()
		if badge.Parent then
			UI.tween(UI.scaleOf(badge), 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Connect(function()
				badge.Visible = false
			end)
		end
	end)
end

local function setRollingVisual(on: boolean)
	recolor(rollButton, on and Color3.fromRGB(120, 120, 130) or C.green)
	rollButton.Label.Text = on and "ROLLING..." or "ROLL"
	if not on then
		refreshAfford()
	end
end

local function doRoll(): boolean
	if rolling then
		return false
	end
	if #selected == 0 then
		UISounds.Play("BuyFail")
		showToast("SELECT A BRAINROT FIRST!", C.red)
		UI.shake(rollButton)
		return false
	end
	if allMaxed() then
		showToast("ALREADY MAX TRAIT!", GOLD)
		return false
	end
	rolling = true
	setRollingVisual(true)
	local luckOn = luckActive()
	local result = remote:InvokeServer("Roll", selected, luckOn)
	if type(result) ~= "table" or not result.ok then
		rolling = false
		setRollingVisual(false)
		if type(result) == "table" and result.silent then
			return true
		end
		UISounds.Play("BuyFail")
		UI.shake(rollButton)
		showToast(type(result) == "table" and string.upper(result.err or "ERROR") or "ERROR", C.red)
		return false
	end
	UISounds.Play("Sweep")
	if pullLever then
		task.spawn(pullLever)
	end
	if result.lucky then
		showToast(("🍀 %dx LUCKY ROLL!"):format(TraitShared.LUCK_MULT), LUCK_GREEN)
	end
	local pending = 0
	for _, r in ipairs(result.results) do
		for i, s in ipairs(slots) do
			if s.tool == r.tool then
				pending += 1
				task.spawn(function()
					spinSlot(s, r, i)
					pending -= 1
				end)
			end
		end
	end
	local t0 = os.clock()
	while pending > 0 and os.clock() - t0 < 6 do
		task.wait()
	end
	rolling = false
	setRollingVisual(false)
	updateCost()
	return true
end

local function toggleAuto()
	UISounds.Play("Tab")
	setAuto(not auto)
	if auto then
		task.spawn(function()
			while auto and isOpen do
				if not rolling then
					-- Retire ceux qui ont atteint l'objectif (on ne paie plus pour eux).
					local removed = 0
					for i = #selected, 1, -1 do
						if TraitShared.GetRank(selected[i]) >= stopAtRank then
							table.remove(selected, i)
							removed += 1
						end
					end
					if removed > 0 then
						UISounds.Play("Success")
						refreshSlots(true)
					end
					if #selected == 0 then
						showToast("TARGET REACHED! AUTO STOPPED", GOLD)
						break
					end
					if allMaxed() then
						showToast("ALL MAX TRAIT! AUTO STOPPED", GOLD)
						break
					end
					local cost = tonumber(remote:InvokeServer("GetCost", selected)) or lastCost
					if cash() < cost then
						showToast("NOT ENOUGH CASH! AUTO STOPPED", C.red)
						break
					end
					if not doRoll() then
						break
					end
				end
				task.wait(TraitShared.AUTO_DELAY)
			end
			setAuto(false)
		end)
	end
end

rollButton.Activated:Connect(function()
	if auto then
		setAuto(false)
	end
	doRoll()
end)
autoButton.Activated:Connect(toggleAuto)

--== Info ==--
local function setInfo(open: boolean)
	if open == info.Visible then
		return
	end
	if open then
		info.Visible = true
		UI.pop(info, 0, 0.6)
		UISounds.Play("Open")
		UI.PushModal("TraitInfo", function()
			setInfo(false)
		end, infoOk)
	else
		UISounds.Play("Swoosh")
		UI.PopModal("TraitInfo")
		UI.tween(UI.scaleOf(info), 0.15, { Scale = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
			info.Visible = false
		end)
	end
end
infoButton.Activated:Connect(function()
	setInfo(true)
end)
infoOk.Activated:Connect(function()
	setInfo(false)
end)

--== Ouverture ==--
local function bindShortcuts(on: boolean)
	if on then
		ContextActionService:BindAction("TraitRoll", function(_, state)
			if state == Enum.UserInputState.Begin and not drawerOpen and not info.Visible then
				if auto then
					setAuto(false)
				end
				task.spawn(doRoll)
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.ButtonX, Enum.KeyCode.R)
		ContextActionService:BindAction("TraitAuto", function(_, state)
			if state == Enum.UserInputState.Begin and not drawerOpen and not info.Visible then
				toggleAuto()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.ButtonY)
	else
		ContextActionService:UnbindAction("TraitRoll")
		ContextActionService:UnbindAction("TraitAuto")
	end
end

local setOpen
setOpen = function(open: boolean)
	if open == isOpen then
		return
	end
	isOpen = open
	if open then
		gui.Enabled = true
		drawer.Visible = false
		drawerOpen = false
		info.Visible = false
		refreshSlots(true)
		updateLuck()
		rollKey.Text = UI.KeyHint("X", "R")
		UISounds.Play("Popup")
		dim.BackgroundTransparency = 1
		UI.tween(dim, 0.25, { BackgroundTransparency = 0.45 })
		rootScale.Scale = fitScale * 0.5
		root.Position = UDim2.fromScale(0.5, 0.62)
		root.Rotation = -3
		UI.tween(rootScale, 0.4, { Scale = fitScale }, Enum.EasingStyle.Back)
		UI.tween(root, 0.4, { Position = UDim2.fromScale(0.5, 0.52), Rotation = 0 }, Enum.EasingStyle.Back)
		side.Position = UDim2.fromOffset(LEFT_W + 80, 100)
		UI.tween(side, 0.45, { Position = UDim2.fromOffset(LEFT_W + 28, 100) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.08)
		bindShortcuts(true)
		UI.PushModal("TraitMachine", function()
			setOpen(false)
		end, rollButton)
	else
		setAuto(false)
		bindShortcuts(false)
		UI.PopModal("TraitDrawer")
		UI.PopModal("TraitInfo")
		UI.PopModal("TraitMachine")
		UISounds.Play("Close")
		UI.tween(dim, 0.18, { BackgroundTransparency = 1 })
		UI.tween(root, 0.18, { Position = UDim2.fromScale(0.5, 0.58) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		UI.tween(rootScale, 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Connect(function()
			if not isOpen then
				gui.Enabled = false
			end
		end)
	end
end

closeButton.Activated:Connect(function()
	setOpen(false)
end)
dim.Activated:Connect(function()
	if rolling then
		return
	end
	if drawerOpen then
		closeDrawer()
	elseif info.Visible then
		setInfo(false)
	else
		setOpen(false)
	end
end)

UI.bindFit(W, H, function(s)
	fitScale = s
	if isOpen then
		rootScale.Scale = s
	end
end, 16, 20)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "TraitMachinePrompt" then
		setOpen(true)
	elseif prompt.Name == "TraitInfoPrompt" then
		setOpen(true)
		task.delay(0.3, setInfo, true)
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
		showToast(("+%d LUCKY ROLL%s!"):format(data.rolls or 1, (data.rolls or 1) > 1 and "S" or ""), LUCK_GREEN)
		UI.burst(luckPill, UDim2.fromScale(0.5, 0.5), { LUCK_GREEN, GOLD, WHITE }, 24, 120, 60)
	end
end)

Inv.WatchInventory(player, function()
	if not isOpen or rolling then
		return
	end
	local changed = false
	for _, t in ipairs(selected) do
		if not stillOwned(t) then
			changed = true
		end
	end
	if changed then
		refreshSlots(false)
	else
		for _, s in ipairs(slots) do
			if s.refresh then
				s.refresh()
			end
		end
	end
	if drawerOpen then
		fillDrawer()
	end
end)

--== Animations de l'UI ==--
local clock = 0
RunService.RenderStepped:Connect(function(dt)
	if not isOpen then
		return
	end
	clock += dt
	for _, g in ipairs(rainbowGrads) do
		g.Offset = Vector2.new(math.sin(clock * 1.5) * 0.3, 0)
	end
	titleGrad.Offset = Vector2.new(math.sin(clock * 1.2) * 0.6, 0)
	UI.scaleOf(starIcon).Scale = 1 + math.sin(clock * 3) * 0.1
	starIcon.Rotation = math.sin(clock * 2) * 12
	UI.scaleOf(starIcon2).Scale = 1 + math.sin(clock * 3 + 1.5) * 0.1
	starIcon2.Rotation = -math.sin(clock * 2) * 12
	if luckActive() then
		UI.scaleOf(luckPill).Scale = 1 + math.abs(math.sin(clock * 3)) * 0.05
	end
end)

--== Modele dans le monde ==--
task.spawn(function()
	local model = workspace:WaitForChild("TraitMachine", 60)
	if not model then
		return
	end

	local oddsBoard = model:WaitForChild("OddsBoard", 30)
	local osg = oddsBoard and oddsBoard:WaitForChild("Odds", 10)
	if osg then
		for _, c in ipairs(osg:GetChildren()) do
			if c:IsA("GuiObject") and c.Name ~= "Bg" then
				c:Destroy()
			end
		end
		local head = Instance.new("TextLabel")
		head.BackgroundTransparency = 1
		head.Size = UDim2.new(1, 0, 0, 70)
		head.FontFace = FONT_TITLE
		head.Text = "ODDS"
		head.TextScaled = true
		head.TextColor3 = WHITE
		head.Parent = osg
		UI.stroke(head, 4, BLACK, true)
		for i, tr in ipairs(TraitShared.TRAITS) do
			local row = Instance.new("TextLabel")
			row.BackgroundTransparency = 1
			row.Position = UDim2.fromOffset(14, 72 + (i - 1) * 54)
			row.Size = UDim2.new(1, -28, 0, 50)
			row.FontFace = FONT_TITLE
			row.RichText = true
			row.TextScaled = true
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.TextColor3 = WHITE
			row.Text = ("<font color=\"#%s\">%s</font>   1/%s"):format(tr.color:ToHex(), TraitShared.FormatMult(tr.mult), NumberFormat.Format(tr.odds))
			row.Parent = osg
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 56)
			pad.Parent = row
			local ic = traitIcon(row, tr)
			ic.AnchorPoint = Vector2.new(0, 0.5)
			ic.Position = UDim2.new(0, -54, 0.5, 0)
			ic.Size = UDim2.fromOffset(46, 46)
			UI.stroke(row, 3, BLACK, true)
		end
	end

	-- Rouleaux de l'ecran du modele : une bande par ReelN.
	local screen = model:WaitForChild("Screen", 30)
	local reels = screen and screen:WaitForChild("Reels", 10)
	local strips = {}
	if reels then
		for i = 1, 4 do
			local r = reels:FindFirstChild("Reel" .. i)
			if r then
				for _, c in ipairs(r:GetChildren()) do
					if c:IsA("TextLabel") or c.Name == "Strip" then
						c:Destroy()
					end
				end
				r.ClipsDescendants = true
				local strip = Instance.new("Frame")
				strip.Name = "Strip"
				strip.BackgroundTransparency = 1
				strip.Size = UDim2.fromScale(1, 1)
				strip.Parent = r
				local l = traitIcon(strip, TRAIT_ICONS[math.random(1, #TRAIT_ICONS)])
				l.Size = UDim2.fromScale(1, 1)
				strips[i] = { reel = r, strip = strip }
			end
		end
	end

	local function worldSpin(i: number, final, duration: number)
		local s = strips[i]
		if not s then
			return
		end
		local h = s.reel.AbsoluteSize.Y
		if h <= 0 then
			h = 100
		end
		for _, c in ipairs(s.strip:GetChildren()) do
			c:Destroy()
		end
		local n = 10
		for k = 1, n + 1 do
			local l = traitIcon(s.strip, k == n + 1 and final or randomTrait())
			l.Position = UDim2.new(0.1, 0, k - 1 + 0.1, 0)
			l.Size = UDim2.fromScale(0.8, 0.8)
		end
		s.strip.Position = UDim2.fromScale(0, 0)
		local tw = TweenService:Create(s.strip, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0, -n) })
		tw:Play()
	end

	for i = 1, 4 do
		worldReels[i] = function(final)
			worldSpin(i, final, 0.35)
		end
	end

	local lever = model:FindFirstChild("Lever", true)
	local leverBall = model:FindFirstChild("LeverBall", true)
	pullLever = function()
		for i = 1, 4 do
			worldSpin(i, randomTrait(), 1.2 + i * 0.3)
		end
		if not (lever and lever:IsA("BasePart")) then
			return
		end
		local pivot = lever:GetAttribute("PivotCF")
		local base: CFrame = typeof(pivot) == "CFrame" and pivot or (lever.CFrame * CFrame.new(0, -lever.Size.Y / 2, 0))
		local parts = { lever }
		if leverBall and leverBall:IsA("BasePart") then
			table.insert(parts, leverBall)
		end
		local offsets = {}
		for _, p in ipairs(parts) do
			offsets[p] = base:ToObjectSpace(p.CFrame)
		end
		local angle = Instance.new("NumberValue")
		angle.Changed:Connect(function(v)
			for _, p in ipairs(parts) do
				p.CFrame = base * CFrame.Angles(math.rad(v), 0, 0) * offsets[p]
			end
		end)
		local down = TweenService:Create(angle, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 55 })
		down:Play()
		down.Completed:Wait()
		local up = TweenService:Create(angle, TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Value = 0 })
		up:Play()
		up.Completed:Wait()
		angle:Destroy()
	end

	-- Ampoules de la marquee qui chenillent + socle qui respire.
	local bulbs = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Bulb" then
			table.insert(bulbs, d)
		end
	end
	table.sort(bulbs, function(a, b)
		return a.Position.X < b.Position.X
	end)
	local padGlow = model:FindFirstChild("PadGlow")
	local BULB_COLORS = { Color3.fromRGB(255, 240, 60), Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 255, 255) }
	local bulbClock = 0
	RunService.Heartbeat:Connect(function(dt)
		bulbClock += dt
		local step = math.floor(bulbClock * (rolling and 14 or 5))
		for i, b in ipairs(bulbs) do
			b.Color = BULB_COLORS[((i + step) % #BULB_COLORS) + 1]
		end
		if padGlow and padGlow:IsA("BasePart") then
			padGlow.Transparency = 0.3 + math.sin(bulbClock * 2) * 0.12
		end
	end)

	-- Animation d'attente : les rouleaux tournent quand on est proche.
	while true do
		local char = player.Character
		local rootPart = char and char:FindFirstChild("HumanoidRootPart")
		if not rolling and screen and rootPart and (rootPart.Position - screen.Position).Magnitude < 90 then
			for i = 1, 4 do
				worldSpin(i, randomTrait(), 0.8 + i * 0.2)
			end
			task.wait(3)
		else
			task.wait(1)
		end
	end
end)
