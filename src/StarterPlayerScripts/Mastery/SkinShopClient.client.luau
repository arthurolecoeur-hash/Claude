--[[
	SkinShopClient
	--------------
	Boutique des skins old Roblox (bouton SKINS du HUD bas-gauche, ou
	ReplicatedStorage.Mastery.OpenSkins:Fire()). Achat en points de
	Mastery (gagnes en YEETANT). Bonus de force = meilleur skin possede ;
	le skin porte est au choix (ou son propre avatar).
	Serveur : ServerScriptService.Mastery.MasteryService.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local folder = ReplicatedStorage:WaitForChild("Mastery")
local MasteryShared = require(folder:WaitForChild("MasteryShared"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local UI = require(ReplicatedStorage:WaitForChild("UIKit"))
local remote = folder:WaitForChild("MasteryRemote") :: RemoteFunction
local event = folder:WaitForChild("MasteryEvent") :: RemoteEvent

local C = UI.C
local WHITE, BLACK = C.white, C.black
local PURPLE = Color3.fromRGB(170, 90, 255)
local STAR = MasteryShared.ICON

local W, H = 980, 640

local state = { points = 0, total = 0, owned = {}, equipped = nil }

local gui = Instance.new("ScreenGui")
gui.Name = "SkinShopGui"
gui:SetAttribute("NoJuice", true)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 14
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local dim = Instance.new("TextButton")
dim.Text = ""
dim.AutoButtonColor = false
dim.Selectable = false
dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.fromRGB(10, 6, 20)
dim.BackgroundTransparency = 1
dim.Parent = gui

local root = Instance.new("Frame")
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.52)
root.Size = UDim2.fromOffset(W, H)
root.BackgroundColor3 = WHITE
root.Active = true
root.Parent = gui
UI.corner(root, 22)
UI.stroke(root, 6, BLACK)
UI.gradient(root, Color3.fromRGB(200, 130, 255), Color3.fromRGB(95, 35, 190))
UI.studs(root, 40, 0.72, 22)
local rootScale = Instance.new("UIScale")
rootScale.Parent = root
local fitScale = 1

local function button(parent: Instance, label: string, color: Color3, size: number?)
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
	UI.studs(b, 24, 0.75, 12)
	local l = UI.text(b, label, size or 26, WHITE, UI.FONT_TITLE, 3)
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

--== En-tete ==--
local header = Instance.new("Frame")
header.Position = UDim2.fromOffset(14, 12)
header.Size = UDim2.new(1, -28, 0, 78)
header.BackgroundColor3 = WHITE
header.ZIndex = 2
header.Parent = root
UI.corner(header, 14)
UI.stroke(header, 4, BLACK)
UI.gradient(header, Color3.fromRGB(255, 225, 90), Color3.fromRGB(235, 140, 10))
UI.studs(header, 28, 0.72, 14)
UI.shine(header, 3.5, 0.1)
local title = UI.text(header, "OLD ROBLOX SKINS", 50, WHITE, UI.FONT_TITLE, 5)
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Position = UDim2.fromScale(0.5, 0.5)
title.Size = UDim2.fromOffset(520, 58)
title.ZIndex = 5

local balance = Instance.new("Frame")
balance.AnchorPoint = Vector2.new(0, 0.5)
balance.Position = UDim2.new(0, 12, 0.5, 0)
balance.Size = UDim2.fromOffset(170, 52)
balance.BackgroundColor3 = WHITE
balance.ZIndex = 4
balance.Parent = header
UI.round(balance)
UI.stroke(balance, 3, BLACK)
UI.gradient(balance, Color3.fromRGB(200, 140, 255), Color3.fromRGB(110, 40, 210))
local balanceText = UI.text(balance, STAR .. " 0", 28, WHITE, UI.FONT_TITLE, 3)
balanceText.Size = UDim2.new(1, -12, 1, -8)
balanceText.Position = UDim2.fromOffset(6, 4)
balanceText.ZIndex = 5

local close = button(header, "X", C.red, 36)
close.AnchorPoint = Vector2.new(1, 0.5)
close.Position = UDim2.new(1, -12, 0.5, 0)
close.Size = UDim2.fromOffset(62, 58)

--== Infos ==--
local powerLine = UI.text(root, "", 26, WHITE, UI.FONT_TITLE, 3)
powerLine.Position = UDim2.fromOffset(0, 98)
powerLine.Size = UDim2.new(1, 0, 0, 30)
local hint = UI.text(root, "Earn " .. STAR .. " MASTERY by YEETING! Farther throw = more Mastery.", 20, Color3.fromRGB(245, 235, 255), UI.FONT, 2)
hint.Position = UDim2.fromOffset(0, 128)
hint.Size = UDim2.new(1, 0, 0, 24)

--== Grille ==--
local grid = Instance.new("Frame")
grid.BackgroundTransparency = 1
grid.Position = UDim2.fromOffset(24, 160)
grid.Size = UDim2.new(1, -48, 1, -250)
grid.Parent = root
local gl = Instance.new("UIGridLayout")
gl.CellSize = UDim2.new(1 / 3, -14, 0.5, -8)
gl.CellPadding = UDim2.fromOffset(20, 16)
gl.SortOrder = Enum.SortOrder.LayoutOrder
gl.HorizontalAlignment = Enum.HorizontalAlignment.Center
gl.Parent = grid

local ownAvatar = button(root, "👤 WEAR MY OWN AVATAR", Color3.fromRGB(80, 80, 110), 24)
ownAvatar.AnchorPoint = Vector2.new(0.5, 1)
ownAvatar.Position = UDim2.new(0.5, 0, 1, -16)
ownAvatar.Size = UDim2.fromOffset(420, 60)

local toast = UI.text(root, "", 28, WHITE, UI.FONT_TITLE, 3)
toast.AnchorPoint = Vector2.new(0.5, 0.5)
toast.Position = UDim2.fromScale(0.5, 0.5)
toast.Size = UDim2.fromOffset(560, 56)
toast.BackgroundColor3 = BLACK
toast.BackgroundTransparency = 0.25
toast.ZIndex = 80
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
	task.delay(1.8, function()
		if my == toastToken then
			toast.Visible = false
		end
	end)
end

-- Petit perso blocky dessine (Noob / Guest).
local function drawBlocky(parent: Instance, colors, z: number)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(120, 150)
	holder.BackgroundTransparency = 1
	holder.ZIndex = z
	holder.Parent = parent
	local function block(x, y, w, h, color)
		local f = Instance.new("Frame")
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.BackgroundColor3 = color
		f.ZIndex = z + 1
		f.Parent = holder
		UI.corner(f, 4)
		UI.stroke(f, 2.5, BLACK)
		return f
	end
	local head = block(42, 0, 36, 34, colors.head)
	block(30, 36, 60, 56, colors.torso)
	block(6, 36, 22, 56, colors.arms)
	block(92, 36, 22, 56, colors.arms)
	block(30, 94, 29, 54, colors.legs)
	block(61, 94, 29, 54, colors.legs)
	local face = UI.text(head, ":)", 22, BLACK, UI.FONT_TITLE, 0)
	face.Size = UDim2.fromScale(1, 1)
	face.Rotation = 90
	face.ZIndex = z + 2
	local st = face:FindFirstChildOfClass("UIStroke")
	if st then
		st:Destroy()
	end
	return holder
end

local cards = {}

local function bestMult(): number
	return MasteryShared.BestMult(state.owned)
end

local function refresh()
	balanceText.Text = STAR .. " " .. NumberFormat.Format(state.points)
	local m = bestMult()
	powerLine.Text = m > 1 and ("💪 POWER BONUS: <font color=\"#FFD23C\">%s</font>"):format(MasteryShared.FormatMult(m)) or "💪 POWER BONUS: <font color=\"#cccccc\">NONE YET</font>"
	for _, s in ipairs(MasteryShared.SKINS) do
		local c = cards[s.key]
		if c then
			local owned = state.owned[s.key] == true
			local wearing = state.equipped == s.key
			if wearing then
				c.action.Label.Text = "✔ WEARING"
				recolor(c.action, Color3.fromRGB(90, 90, 110))
			elseif owned then
				c.action.Label.Text = "WEAR"
				recolor(c.action, C.green)
			else
				c.action.Label.Text = STAR .. " " .. NumberFormat.Format(s.cost)
				recolor(c.action, state.points >= s.cost and C.blue or Color3.fromRGB(150, 70, 70))
			end
			c.lock.Visible = not owned
			local ratio = math.clamp(state.points / s.cost, 0, 1)
			c.bar.Size = UDim2.fromScale(owned and 1 or ratio, 1)
			c.barText.Text = owned and "OWNED" or ("%s / %s"):format(NumberFormat.Format(state.points), NumberFormat.Format(s.cost))
			c.best.Visible = owned and s.mult == bestMult()
		end
	end
	recolor(ownAvatar, state.equipped == nil and Color3.fromRGB(90, 90, 110) or Color3.fromRGB(80, 120, 200))
	ownAvatar.Label.Text = state.equipped == nil and "✔ WEARING MY OWN AVATAR" or "👤 WEAR MY OWN AVATAR"
end

for i, s in ipairs(MasteryShared.SKINS) do
	local card = Instance.new("Frame")
	card.LayoutOrder = i
	card.BackgroundColor3 = WHITE
	card.ZIndex = 3
	card.Parent = grid
	UI.corner(card, 14)
	UI.stroke(card, 4, BLACK)
	UI.gradient(card, s.color:Lerp(BLACK, 0.2), s.color:Lerp(BLACK, 0.7))
	UI.studs(card, 24, 0.8, 14)

	local name = UI.text(card, string.upper(s.name), 24, WHITE, UI.FONT_TITLE, 3)
	name.Position = UDim2.fromOffset(0, 6)
	name.Size = UDim2.new(1, 0, 0, 28)
	name.ZIndex = 6

	local mult = Instance.new("Frame")
	mult.AnchorPoint = Vector2.new(1, 0)
	mult.Position = UDim2.new(1, 6, 0, -8)
	mult.Size = UDim2.fromOffset(66, 30)
	mult.BackgroundColor3 = WHITE
	mult.Rotation = 8
	mult.ZIndex = 8
	mult.Parent = card
	UI.round(mult)
	UI.stroke(mult, 2.5, BLACK)
	UI.gradient(mult, Color3.fromRGB(255, 235, 120), Color3.fromRGB(235, 140, 0))
	local mt = UI.text(mult, MasteryShared.FormatMult(s.mult), 20, WHITE, UI.FONT_TITLE, 2)
	mt.Size = UDim2.new(1, -6, 1, -4)
	mt.Position = UDim2.fromOffset(3, 2)
	mt.ZIndex = 9

	local preview = Instance.new("Frame")
	preview.BackgroundTransparency = 1
	preview.Position = UDim2.fromOffset(8, 34)
	preview.Size = UDim2.new(1, -16, 1, -112)
	preview.ZIndex = 4
	preview.Parent = card
	if s.userId then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = ("rbxthumb://type=Avatar&id=%d&w=420&h=420"):format(s.userId)
		img.ZIndex = 5
		img.Parent = preview
	else
		local fig = drawBlocky(preview, s.colors, 5)
		local sc = Instance.new("UIScale")
		sc.Scale = 0.8
		sc.Parent = fig
	end

	local lock = UI.text(preview, "🔒", 40, WHITE)
	lock.AnchorPoint = Vector2.new(1, 1)
	lock.Position = UDim2.fromScale(1, 1)
	lock.Size = UDim2.fromOffset(44, 44)
	lock.ZIndex = 7

	local best = UI.text(card, "ACTIVE BONUS", 16, Color3.fromRGB(255, 230, 120), UI.FONT_TITLE, 2)
	best.AnchorPoint = Vector2.new(0, 0)
	best.Position = UDim2.fromOffset(8, 34)
	best.Size = UDim2.fromOffset(120, 18)
	best.TextXAlignment = Enum.TextXAlignment.Left
	best.ZIndex = 8
	best.Visible = false

	local barBg = Instance.new("Frame")
	barBg.AnchorPoint = Vector2.new(0.5, 1)
	barBg.Position = UDim2.new(0.5, 0, 1, -62)
	barBg.Size = UDim2.new(1, -24, 0, 14)
	barBg.BackgroundColor3 = Color3.fromRGB(25, 15, 40)
	barBg.ZIndex = 5
	barBg.Parent = card
	UI.round(barBg)
	UI.stroke(barBg, 2, BLACK)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = WHITE
	bar.ZIndex = 6
	bar.Parent = barBg
	UI.round(bar)
	UI.gradient(bar, Color3.fromRGB(220, 170, 255), PURPLE)
	local barText = UI.text(barBg, "", 12, WHITE, UI.FONT_TITLE, 1.5)
	barText.Size = UDim2.fromScale(1, 1)
	barText.ZIndex = 7

	local action = button(card, "", C.blue, 24)
	action.AnchorPoint = Vector2.new(0.5, 1)
	action.Position = UDim2.new(0.5, 0, 1, -10)
	action.Size = UDim2.new(1, -24, 0, 44)
	action.ZIndex = 6
	action.Activated:Connect(function()
		if state.equipped == s.key then
			return
		end
		if state.owned[s.key] then
			local r = remote:InvokeServer("Equip", s.key)
			if type(r) == "table" and r.ok then
				UISounds.Play("Success")
				showToast("NOW WEARING " .. string.upper(s.name) .. "!", C.green)
			end
			return
		end
		if state.points < s.cost then
			UISounds.Play("BuyFail")
			UI.shake(action)
			showToast(("NEED %s MORE %s"):format(NumberFormat.Format(s.cost - state.points), STAR), C.red)
			return
		end
		local r = remote:InvokeServer("Buy", s.key)
		if type(r) == "table" and r.ok then
			UISounds.Play("Buy")
			local p = card.AbsolutePosition + card.AbsoluteSize / 2 - root.AbsolutePosition
			UI.burst(root, UDim2.fromOffset(p.X / rootScale.Scale, p.Y / rootScale.Scale), { s.color, C.gold, WHITE }, 30, 200, 90)
			showToast(("%s UNLOCKED! POWER %s"):format(string.upper(s.name), MasteryShared.FormatMult(s.mult)), C.gold)
		else
			UISounds.Play("BuyFail")
			showToast(type(r) == "table" and string.upper(r.err or "ERROR") or "ERROR", C.red)
		end
	end)

	cards[s.key] = { card = card, action = action, lock = lock, bar = bar, barText = barText, best = best }
end

ownAvatar.Activated:Connect(function()
	if state.equipped == nil then
		return
	end
	local r = remote:InvokeServer("Equip", nil)
	if type(r) == "table" and r.ok then
		UISounds.Play("Success")
		showToast("WEARING YOUR AVATAR (BONUS KEPT!)", C.green)
	end
end)

--== Ouverture ==--
local isOpen = false
local function setOpen(open: boolean)
	if open == isOpen then
		return
	end
	isOpen = open
	if open then
		gui.Enabled = true
		local s = remote:InvokeServer("GetState")
		if type(s) == "table" then
			state = s
		end
		refresh()
		UISounds.Play("Popup")
		dim.BackgroundTransparency = 1
		UI.tween(dim, 0.25, { BackgroundTransparency = 0.45 })
		rootScale.Scale = fitScale * 0.5
		root.Rotation = -3
		UI.tween(rootScale, 0.4, { Scale = fitScale }, Enum.EasingStyle.Back)
		UI.tween(root, 0.4, { Rotation = 0 }, Enum.EasingStyle.Back)
		for i, sk in ipairs(MasteryShared.SKINS) do
			UI.pop(cards[sk.key].card, 0.05 + i * 0.05, 0.5)
		end
		UI.PushModal("SkinShop", function()
			setOpen(false)
		end, cards[MasteryShared.SKINS[1].key].action)
	else
		UISounds.Play("Close")
		UI.PopModal("SkinShop")
		UI.tween(dim, 0.18, { BackgroundTransparency = 1 })
		UI.tween(rootScale, 0.18, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In).Completed:Connect(function()
			if not isOpen then
				gui.Enabled = false
			end
		end)
	end
end

close.Activated:Connect(function()
	setOpen(false)
end)
dim.Activated:Connect(function()
	setOpen(false)
end)

UI.bindFit(W, H, function(s)
	fitScale = s
	if isOpen then
		rootScale.Scale = s
	end
end)

local open = Instance.new("BindableEvent")
open.Name = "OpenSkins"
open.Parent = folder
open.Event:Connect(function()
	setOpen(not isOpen)
end)

event.OnClientEvent:Connect(function(kind, data)
	if kind == "State" and type(data) == "table" then
		state = data
		if isOpen then
			refresh()
		end
	elseif kind == "Gained" and type(data) == "table" then
		UISounds.PlayOverlap("Pop", 1.2, 0.5)
	end
end)

-- Degrade anime du titre.
local g = UI.gradient(title, ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 200)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 205, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 250, 200)),
}), nil, 0)
local clock = 0
RunService.RenderStepped:Connect(function(dt)
	if isOpen then
		clock += dt
		g.Offset = Vector2.new(math.sin(clock * 1.2) * 0.6, 0)
	end
end)
