--[[
	PlatformSupport
	---------------
	Rend tout le jeu jouable sur console et telephone, sans toucher aux
	scripts de chaque UI :

	CONSOLE (manette)
	  - Fenetre ouverte (shop, index, rebirth, sac, settings...) : curseur
	    virtuel de la manette (stick gauche + A pour cliquer). Les fenetres
	    UIKit (Trait Machine, Admin) utilisent deja la navigation D-pad.
	  - LB / RB : objet precedent / suivant de la hotbar.
	  - D-pad haut : ouvre / ferme le sac (BackpackClient).
	TELEPHONE
	  - Les fenetres UIKit s'adaptent a l'ecran, les autres UIs avaient deja
	    leur propre mise a l'echelle.
	TOUS
	  - Ouverture d'une fenetre : reflet qui balaie + etincelles aux coins
	    (pas de zoom : l'ancien effet de cascade etait trop genant).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GamepadService = game:GetService("GamepadService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UI = require(ReplicatedStorage:WaitForChild("UIKit"))
local Inv = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("InventoryShared"))

local WINDOW_NAMES = {
	Modal = true, Window = true, Panel = true, Inventory = true, Backpack = true, Main = true,
}
local SKIP_GUIS = {
	JuiceFX = true, PlatformFX = true, TouchGui = true, Freecam = true, BubbleChat = true, Chat = true,
	TraitMachineGui = true, AdminGui = true, LuckyBlockOpenUI = true, LoadingScreen = true,
}

--== Fenetres "classiques" ouvertes ==--
local candidates = {} -- GuiObject -> true
local wasOpen = {}

local function screenGuiOf(obj: Instance): ScreenGui?
	local sg = obj:FindFirstAncestorWhichIsA("ScreenGui")
	if not sg or SKIP_GUIS[sg.Name] or sg.Name:sub(1, 7) == "Weather" or sg:GetAttribute("NoPlatform") then
		return nil
	end
	return sg
end

local function isShown(obj: GuiObject): boolean
	local sg = obj:FindFirstAncestorWhichIsA("ScreenGui")
	if not sg or not sg.Enabled then
		return false
	end
	local a: Instance? = obj
	while a and a ~= sg do
		if a:IsA("GuiObject") and not a.Visible then
			return false
		end
		a = a.Parent
	end
	return true
end

local function isBigWindow(obj: GuiObject): boolean
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local s = obj.AbsoluteSize
	return s.X * s.Y >= vp.X * vp.Y * 0.18 and obj.BackgroundTransparency < 1
end

local function consider(d: Instance)
	if d:IsA("GuiObject") and WINDOW_NAMES[d.Name] and screenGuiOf(d) then
		candidates[d] = true
	end
end

for _, d in ipairs(playerGui:GetDescendants()) do
	consider(d)
end
playerGui.DescendantAdded:Connect(consider)
playerGui.DescendantRemoving:Connect(function(d)
	candidates[d] = nil
	wasOpen[d] = nil
end)

--== Effet d'ouverture (reflet + etincelles) ==--
local fxGui = Instance.new("ScreenGui")
fxGui.Name = "PlatformFX"
fxGui.IgnoreGuiInset = true
fxGui.DisplayOrder = 240
fxGui.ResetOnSpawn = false
fxGui:SetAttribute("NoJuice", true)
fxGui.Parent = playerGui

local function openFlourish(window: GuiObject)
	local pos, size = window.AbsolutePosition, window.AbsoluteSize
	local inset = game:GetService("GuiService"):GetGuiInset()
	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Position = UDim2.fromOffset(pos.X, pos.Y + inset.Y)
	frame.Size = UDim2.fromOffset(size.X, size.Y)
	frame.ClipsDescendants = true
	frame.Parent = fxGui
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = Color3.new(1, 1, 1)
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Position = UDim2.fromScale(-0.2, 0.5)
	bar.Size = UDim2.new(0.12, 0, 2, 0)
	bar.Rotation = 18
	bar.Parent = frame
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = bar
	TweenService:Create(bar, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Position = UDim2.fromScale(1.2, 0.5) }):Play()
	local colors = { Color3.fromRGB(255, 230, 90), Color3.new(1, 1, 1), Color3.fromRGB(120, 220, 255) }
	for _, c in ipairs({ Vector2.new(0, 0), Vector2.new(1, 0), Vector2.new(0, 1), Vector2.new(1, 1) }) do
		UI.burst(fxGui, UDim2.fromOffset(pos.X + size.X * c.X, pos.Y + inset.Y + size.Y * c.Y), colors, 6, 60, 10)
	end
	task.delay(0.6, function()
		frame:Destroy()
	end)
end

--== Curseur virtuel manette ==--
local cursorOn = false
local function setCursor(on: boolean, window: GuiObject?)
	if on == cursorOn then
		return
	end
	cursorOn = on
	pcall(function()
		if on then
			GamepadService:EnableGamepadCursor(window)
		else
			GamepadService:DisableGamepadCursor()
		end
	end)
end

task.spawn(function()
	while true do
		task.wait(0.25)
		local open: GuiObject? = nil
		for obj in pairs(candidates) do
			local shown = obj.Parent ~= nil and isShown(obj) and isBigWindow(obj)
			if shown and not wasOpen[obj] then
				wasOpen[obj] = true
				task.spawn(openFlourish, obj)
			elseif not shown then
				wasOpen[obj] = nil
			end
			if shown then
				open = obj
			end
		end
		local gamepad = UI.IsGamepad()
		setCursor(gamepad and open ~= nil and not UI.IsModalOpen(), open)
	end
end)

UserInputService.LastInputTypeChanged:Connect(function()
	if not UI.IsGamepad() then
		setCursor(false)
	end
end)

--== Hotbar a la manette : LB / RB ==--
local function hotbarTools(): { Tool }
	local list = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	local char = player.Character
	local bag = (backpack and backpack:FindFirstChild("PunchingBag")) or (char and char:FindFirstChild("PunchingBag"))
	if bag and bag:IsA("Tool") then
		table.insert(list, bag)
	end
	local slotted = {}
	for _, tool in ipairs(Inv.GetItems(player)) do
		local slot = tool:GetAttribute("HotbarSlot")
		if type(slot) == "number" and slot >= Inv.HOTBAR_FIRST and slot <= Inv.HOTBAR_LAST then
			table.insert(slotted, tool)
		end
	end
	table.sort(slotted, function(a, b)
		return (a:GetAttribute("HotbarSlot") or 0) < (b:GetAttribute("HotbarSlot") or 0)
	end)
	for _, t in ipairs(slotted) do
		table.insert(list, t)
	end
	return list
end

local function cycle(dir: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local list = hotbarTools()
	if #list == 0 then
		return
	end
	local current = char:FindFirstChildOfClass("Tool")
	local idx = current and table.find(list, current) or 0
	local nextIdx = idx + dir
	if nextIdx < 1 or nextIdx > #list then
		hum:UnequipTools()
		return
	end
	hum:EquipTool(list[nextIdx])
end

ContextActionService:BindAction("PlatformHotbar", function(_, state, input)
	if state ~= Enum.UserInputState.Begin or UI.IsModalOpen() or cursorOn then
		return Enum.ContextActionResult.Pass
	end
	cycle(input.KeyCode == Enum.KeyCode.ButtonR1 and 1 or -1)
	return Enum.ContextActionResult.Sink
end, false, Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonR1)
