--[[
	StatsHudClient
	--------------
	Nouveau HUD bas-gauche (remplace CashGui + ForceHudGui) : une carte
	avec 3 lignes animees
	  - CASH    (compteur qui glisse, "+$..." qui s'envole a chaque gain)
	  - FORCE   (+ pastille du bonus de skin, ex "x4")
	  - MASTERY (+ bouton SKINS qui ouvre la boutique de skins old Roblox)
	S'adapte aux petits ecrans (telephone).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local UI = require(ReplicatedStorage:WaitForChild("UIKit"))
local MasteryShared = require(ReplicatedStorage:WaitForChild("Mastery"):WaitForChild("MasteryShared"))

local C = UI.C
local WHITE, BLACK = C.white, C.black
local CASH_ICON = "rbxassetid://83913793858763"
local ARM_ICON = "rbxassetid://82155203498709"

-- Ancien HUD : on le cache (il est recree au respawn, d'ou le ChildAdded).
local OLD = { CashGui = true, ForceHudGui = true }
local function hideOld(g: Instance)
	if OLD[g.Name] and g:IsA("ScreenGui") then
		g.Enabled = false
	end
end
for _, g in ipairs(playerGui:GetChildren()) do
	hideOld(g)
end
playerGui.ChildAdded:Connect(hideOld)

local gui = Instance.new("ScreenGui")
gui.Name = "StatsHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 5
gui:SetAttribute("NoJuice", true)
gui:SetAttribute("NoPlatform", true)
gui.Parent = playerGui

local W, ROW = 270, 50

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0, 1)
card.Position = UDim2.new(0, 10, 1, -10)
card.Size = UDim2.fromOffset(W, ROW * 3 + 20)
card.BackgroundTransparency = 1
card.Parent = gui
local cardScale = Instance.new("UIScale")
cardScale.Parent = card

-- Telephone : le joystick tactile est en bas a gauche -> HUD en haut a gauche.
local function placeCard()
	if UI.IsTouch() then
		card.AnchorPoint = Vector2.new(0, 0)
		card.Position = UDim2.new(0, 10, 0, 64)
	else
		card.AnchorPoint = Vector2.new(0, 1)
		card.Position = UDim2.new(0, 10, 1, -10)
	end
end
placeCard()
game:GetService("UserInputService").LastInputTypeChanged:Connect(placeCard)
UI.bindFit(1280, 720, function(s)
	cardScale.Scale = math.clamp(s, 0.72, 1)
end, 0, 0)

local rows = Instance.new("Frame")
rows.BackgroundTransparency = 1
rows.Position = UDim2.fromOffset(10, 10)
rows.Size = UDim2.new(1, -20, 1, -20)
rows.Parent = card
UI.list(rows, Enum.FillDirection.Vertical, 0)

local function makeRow(order: number, color: Color3, iconImage: string?, iconEmoji: string?)
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, ROW)
	row.Parent = rows

	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0, 0.5)
	pill.Position = UDim2.new(0, 0, 0.5, 0)
	pill.Size = UDim2.new(1, 0, 0, ROW - 8)
	pill.BackgroundTransparency = 1
	pill.Parent = row

	local iconHolder = Instance.new("Frame")
	iconHolder.AnchorPoint = Vector2.new(0, 0.5)
	iconHolder.Position = UDim2.new(0, -4, 0.5, 0)
	iconHolder.Size = UDim2.fromOffset(ROW, ROW)
	iconHolder.BackgroundColor3 = WHITE
	iconHolder.ZIndex = 3
	iconHolder.Parent = row
	UI.round(iconHolder)
	UI.stroke(iconHolder, 3, BLACK)
	UI.gradient(iconHolder, color:Lerp(WHITE, 0.4), color:Lerp(BLACK, 0.2))
	local icon
	if iconImage then
		icon = Instance.new("ImageLabel")
		icon.BackgroundTransparency = 1
		icon.Image = iconImage
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Parent = iconHolder
	else
		icon = UI.text(iconHolder, iconEmoji or "", 40, WHITE)
	end
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.78, 0.78)
	icon.ZIndex = 4

	local value = UI.text(pill, "0", 32, WHITE, UI.FONT_TITLE, 3.5)
	value.AnchorPoint = Vector2.new(0, 0.5)
	value.Position = UDim2.new(0, ROW + 4, 0.5, 1)
	value.Size = UDim2.new(1, -(ROW + 12), 0, 32)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.ZIndex = 3
	UI.gradient(value, WHITE, color:Lerp(WHITE, 0.35))
	return row, value, iconHolder, pill
end

local cashRow, cashValue, cashIcon = makeRow(1, Color3.fromRGB(60, 210, 80), CASH_ICON)
local _, forceValue, forceIcon, forcePill = makeRow(2, Color3.fromRGB(255, 170, 40), ARM_ICON)
local masteryRow, masteryValue, masteryIcon, masteryPill = makeRow(3, Color3.fromRGB(170, 90, 255), nil, MasteryShared.ICON)

-- Pastille du bonus de skin (Force).
local boost = Instance.new("Frame")
boost.AnchorPoint = Vector2.new(1, 0.5)
boost.Position = UDim2.new(1, -8, 0.5, 0)
boost.Size = UDim2.fromOffset(58, 28)
boost.BackgroundColor3 = WHITE
boost.ZIndex = 4
boost.Visible = false
boost.Parent = forcePill
UI.round(boost)
UI.stroke(boost, 2, BLACK)
UI.gradient(boost, Color3.fromRGB(255, 230, 120), Color3.fromRGB(230, 140, 0))
local boostText = UI.text(boost, "x1", 18, WHITE, UI.FONT_TITLE, 2)
boostText.Size = UDim2.new(1, -6, 1, -4)
boostText.Position = UDim2.fromOffset(3, 2)
boostText.ZIndex = 5

-- Bouton SKINS (Mastery).
local skinsButton = Instance.new("TextButton")
skinsButton.Name = "SkinsButton"
skinsButton.AutoButtonColor = false
skinsButton.Text = ""
skinsButton.AnchorPoint = Vector2.new(1, 0.5)
skinsButton.Position = UDim2.new(1, -5, 0.5, 0)
skinsButton.Size = UDim2.fromOffset(84, 32)
skinsButton.BackgroundColor3 = WHITE
skinsButton.ZIndex = 4
skinsButton.Parent = masteryPill
UI.round(skinsButton)
UI.stroke(skinsButton, 2.5, BLACK)
UI.gradient(skinsButton, Color3.fromRGB(120, 240, 90), Color3.fromRGB(30, 170, 50))
local skinsLabel = UI.text(skinsButton, "SKINS", 20, WHITE, UI.FONT_TITLE, 2)
skinsLabel.Size = UDim2.new(1, -8, 1, -4)
skinsLabel.Position = UDim2.fromOffset(4, 2)
skinsLabel.ZIndex = 5
UI.pressable(skinsButton, 1.08)
UI.shine(skinsButton, 3)
local newDot = Instance.new("Frame")
newDot.AnchorPoint = Vector2.new(0.5, 0.5)
newDot.Position = UDim2.new(1, -2, 0, 2)
newDot.Size = UDim2.fromOffset(16, 16)
newDot.BackgroundColor3 = C.red
newDot.ZIndex = 6
newDot.Visible = false
newDot.Parent = skinsButton
UI.round(newDot)
UI.stroke(newDot, 2, BLACK)

skinsButton.Activated:Connect(function()
	UISounds.Play("Click")
	local open = ReplicatedStorage.Mastery:FindFirstChild("OpenSkins")
	if open and open:IsA("BindableEvent") then
		open:Fire()
	end
end)

--== Valeurs animees ==--
local function pop(obj: GuiObject, amount: number?)
	local s = UI.scaleOf(obj)
	s.Scale = amount or 1.18
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

local function floatGain(row: Frame, text: string, color: Color3)
	local l = UI.text(gui, text, 26, color, UI.FONT_TITLE, 3)
	local p = row.AbsolutePosition
	l.AnchorPoint = Vector2.new(0, 1)
	l.Position = UDim2.fromOffset(p.X + row.AbsoluteSize.X + 6, p.Y + row.AbsoluteSize.Y * 0.8)
	l.Size = UDim2.fromOffset(200, 30)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.ZIndex = 20
	UI.pop(l, 0, 0.5)
	TweenService:Create(l, TweenInfo.new(1.1, Enum.EasingStyle.Quad), { Position = l.Position - UDim2.fromOffset(0, 46), TextTransparency = 1 }):Play()
	local st = l:FindFirstChildOfClass("UIStroke")
	if st then
		TweenService:Create(st, TweenInfo.new(1.1), { Transparency = 1 }):Play()
	end
	task.delay(1.2, function()
		l:Destroy()
	end)
end

local function bindCounter(label: TextLabel, fmt: (number) -> string, onGain: ((number) -> ())?)
	local shown = Instance.new("NumberValue")
	local tween: Tween? = nil
	local last: number? = nil
	shown.Changed:Connect(function(v)
		label.Text = fmt(math.floor(v + 0.5))
	end)
	return function(v: number)
		if last == nil then
			shown.Value = v
			label.Text = fmt(v)
		else
			if tween then
				tween:Cancel()
			end
			local tw = TweenService:Create(shown, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Value = v })
			tween = tw
			tw:Play()
			if v > last and onGain then
				onGain(v - last)
			end
		end
		last = v
	end
end

-- Le cash monte chaque seconde (generateurs) : on regroupe les gains pour
-- ne pas faire pleuvoir les "+$" en continu.
local pendingCash, cashFlushAt = 0, 0
local setCash = bindCounter(cashValue, NumberFormat.FormatPrice, function(d)
	pendingCash += d
	local now = os.clock()
	if now < cashFlushAt then
		return
	end
	cashFlushAt = now + 1.6
	pop(cashIcon, 1.1)
	floatGain(cashRow, "+" .. NumberFormat.FormatPrice(math.floor(pendingCash + 0.5)), Color3.fromRGB(120, 255, 110))
	pendingCash = 0
end)
local setForce = bindCounter(forceValue, NumberFormat.Format, function()
	pop(forceIcon, 1.12)
end)
local setMastery = bindCounter(masteryValue, NumberFormat.Format, function(d)
	pop(masteryIcon)
	floatGain(masteryRow, ("+%s %s"):format(NumberFormat.Format(d), MasteryShared.ICON), Color3.fromRGB(215, 160, 255))
end)

local function watchValue(parent: Instance, name: string, setter: (number) -> ())
	local v = parent:WaitForChild(name, 60)
	if v and v:IsA("ValueBase") then
		setter(tonumber((v :: any).Value) or 0)
		v.Changed:Connect(function()
			setter(tonumber((v :: any).Value) or 0)
		end)
	end
end

task.spawn(function()
	local ls = player:WaitForChild("leaderstats", 60)
	if ls then
		task.spawn(watchValue, ls, "Cash", setCash)
		task.spawn(watchValue, ls, "Force", setForce)
	end
end)

-- Point rouge : un skin est achetable.
local function refreshMastery()
	local pts = tonumber(player:GetAttribute("Mastery")) or 0
	setMastery(pts)
	local canBuy = false
	local ownedPower = tonumber(player:GetAttribute("SkinPower")) or 1
	for _, s in ipairs(MasteryShared.SKINS) do
		if s.mult > ownedPower and pts >= s.cost then
			canBuy = true
		end
	end
	newDot.Visible = canBuy
end
local function refreshBoost()
	local m = tonumber(player:GetAttribute("SkinPower")) or 1
	boost.Visible = m > 1
	boostText.Text = MasteryShared.FormatMult(m)
	if m > 1 then
		pop(boost, 1.3)
	end
	refreshMastery()
end
player:GetAttributeChangedSignal("Mastery"):Connect(refreshMastery)
player:GetAttributeChangedSignal("SkinPower"):Connect(refreshBoost)
refreshMastery()
refreshBoost()

-- Point rouge qui pulse.
task.spawn(function()
	local t = 0
	while true do
		t += task.wait()
		if newDot.Visible then
			UI.scaleOf(newDot).Scale = 1 + math.abs(math.sin(t * 4)) * 0.3
		end
	end
end)
