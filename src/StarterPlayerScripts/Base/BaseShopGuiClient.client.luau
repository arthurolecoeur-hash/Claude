--[[
	BaseShopGuiClient (v3, style "Plot skins")
	-------------------------------------------
	Stand Workspace.BaseStand : base miniature qui tourne + disque rose.
	Marcher sur le disque ouvre la liste des skins (cartes).
	Deblocage : Index (BaseSkinShared.REQUIRED_RATIO) ou achat Robux (productId).
	Anciennes versions : ServerStorage.BaseShopGuiClient_BackupV2 / _Backup.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local BaseSkinShared = require(ReplicatedStorage:WaitForChild("BaseSkinShared"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local remotes = ReplicatedStorage:WaitForChild("BaseSkinRemotes")
local getState = remotes:WaitForChild("GetBaseSkins") :: RemoteFunction
local equipEvent = remotes:WaitForChild("EquipBaseSkin") :: RemoteEvent
local changedEvent = remotes:WaitForChild("BaseSkinsChanged") :: RemoteEvent
local studioBuyEvent = remotes:WaitForChild("StudioBuyBaseSkin") :: RemoteEvent
local previewSource = ReplicatedStorage:WaitForChild("BasePreview")

local IS_STUDIO = RunService:IsStudio()
local ROBUX = utf8.char(0xE002)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local STUDS_ID = "rbxassetid://10509831729"
local CASH_ICON = "rbxassetid://83913793858763"

local BASE_W, BASE_H = 900, 600
local HEADER_H = 86
local CARD_H = 220

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local INK = Color3.fromRGB(12, 10, 24)
local PURPLE = Color3.fromRGB(200, 95, 255)
local BODY = Color3.fromRGB(40, 30, 66)
local RED = Color3.fromRGB(235, 45, 60)
local ROBUX_COL = Color3.fromRGB(175, 45, 255)
local COLOR_EQUIP = Color3.fromRGB(80, 210, 60)
local COLOR_EQUIPPED = Color3.fromRGB(55, 150, 255)
local COLOR_LOCKED = Color3.fromRGB(150, 150, 165)
local PROGRESS_COL = Color3.fromRGB(255, 165, 20)

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 40, 40)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 0)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(40, 235, 70)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 170, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 50, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 40, 40)),
})
local RAINBOW_LIGHT = (function()
	local kps = {}
	for _, kp in ipairs(RAINBOW.Keypoints) do
		table.insert(kps, ColorSequenceKeypoint.new(kp.Time, kp.Value:Lerp(WHITE, 0.6)))
	end
	return ColorSequence.new(kps)
end)()

local function darker(c: Color3, f: number): Color3
	return c:Lerp(BLACK, f)
end

local function lighter(c: Color3, f: number): Color3
	return c:Lerp(WHITE, f)
end

local function fmtMult(mult: number): string
	return ((("%.2f"):format(mult)):gsub("0+$", ""):gsub("%.$", ""))
end

--== Helpers ==--
local function corner(p: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function stroke(p: GuiObject, th: number, col: Color3?)
	local s = Instance.new("UIStroke")
	s.Thickness = th
	s.Color = col or INK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = if p:IsA("TextLabel") or p:IsA("TextButton") and (p :: TextButton).Text ~= "" then Enum.ApplyStrokeMode.Contextual else Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function gradient(p: GuiObject, seq: ColorSequence, rot: number?)
	local g = Instance.new("UIGradient")
	g.Color = seq
	g.Rotation = rot or 90
	g.Parent = p
	return g
end

local function studs(p: GuiObject, r: number, transp: number?)
	local img = Instance.new("ImageLabel")
	img.Name = "StudsTexture"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = STUDS_ID
	img.ScaleType = Enum.ScaleType.Tile
	img.TileSize = UDim2.fromOffset(30, 30)
	img.ImageTransparency = transp or 0.82
	img.ZIndex = p.ZIndex
	img.Parent = p
	corner(img, r)
	return img
end

local function text(parent: Instance, str: string, size: UDim2, pos: UDim2, col: Color3?, th: number?, maxSize: number?, align: Enum.TextXAlignment?)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.Text = str
	l.TextColor3 = col or WHITE
	l.TextScaled = true
	l.RichText = true
	l.Size = size
	l.Position = pos
	l.TextXAlignment = align or Enum.TextXAlignment.Center
	l.Parent = parent
	stroke(l, th or 2, INK)
	if maxSize then
		local c = Instance.new("UITextSizeConstraint")
		c.MaxTextSize = maxSize
		c.Parent = l
	end
	return l
end

local function button(parent: Instance, name: string, size: UDim2, pos: UDim2, col: Color3)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = col
	b.Size = size
	b.Position = pos
	b.Parent = parent
	corner(b, 14)
	stroke(b, 4, INK)
	studs(b, 14, 0.75)
	local sc = Instance.new("UIScale")
	sc.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1.05 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.05 }):Play()
	end)
	return b, sc
end

local function recolorButton(b: GuiObject, col: Color3)
	b.BackgroundColor3 = col
	local s = b:FindFirstChildOfClass("UIStroke")
	local g = s and s:FindFirstChild("StrokeGrad")
	if g then
		(g :: UIGradient).Color = ColorSequence.new(lighter(col, 0.4), darker(col, 0.5))
	end
end

local function shake(gui: GuiObject)
	local base = gui.Position
	task.spawn(function()
		for i = 1, 6 do
			gui.Position = base + UDim2.fromOffset(((i % 2 == 0) and 6 or -6) * (1 - i / 7), 0)
			task.wait(0.03)
		end
		gui.Position = base
	end)
end

--== Apercus 3D ==--
local PREVIEW_FOV = 36
local previews = {}

local function buildPreview(vf: ViewportFrame, skinKey: string, phase: number, speed: number)
	local model = previewSource:Clone()
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p:GetAttribute("PreviewPaint") then
			local origMat = Enum.Material[p:GetAttribute("SkinOrigMaterial")] or Enum.Material.Plastic
			BaseSkinShared.Paint(p, skinKey, p:GetAttribute("SkinOrigColor"), origMat)
		end
	end
	local wm = Instance.new("WorldModel")
	wm.Parent = vf
	model.Parent = wm
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = PREVIEW_FOV
	cam.Parent = vf
	vf.CurrentCamera = cam
	local entry = {
		cam = cam,
		center = cf.Position,
		dist = (size.Magnitude / 2) / math.sin(math.rad(PREVIEW_FOV / 2)) * 1.02,
		phase = phase,
		speed = speed,
	}
	table.insert(previews, entry)
	return entry
end

local function updatePreview(p, t: number)
	local a = p.phase + t * p.speed
	local dir = Vector3.new(math.cos(a), 0.7, math.sin(a)).Unit
	p.cam.CFrame = CFrame.lookAt(p.center + dir * p.dist, p.center)
end

--== Construction ==--
local old = playerGui:FindFirstChild("BaseShopGui")
if old then
	old:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BaseShopGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 5
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = BLACK
overlay.BackgroundTransparency = 1
overlay.Active = true
overlay.Visible = false
overlay.Parent = screenGui

local main = Instance.new("Frame")
main.Name = "Main"
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.Size = UDim2.fromOffset(BASE_W, BASE_H)
main.BackgroundColor3 = BODY
main.Parent = overlay
corner(main, 22)
stroke(main, 6, INK)
studs(main, 22, 0.9)
local fitScale = Instance.new("UIScale")
fitScale.Name = "FitScale"
fitScale.Scale = 0
fitScale.Parent = main

local header = Instance.new("Frame")
header.Name = "Header"
header.BackgroundColor3 = PURPLE
header.Size = UDim2.new(1, 0, 0, HEADER_H)
header.ZIndex = 2
header.Parent = main
corner(header, 22)
stroke(header, 5, INK)
studs(header, 22, 0.72)
gradient(header, ColorSequence.new(Color3.fromRGB(235, 150, 255), Color3.fromRGB(170, 60, 240)))

local iconVf = Instance.new("ViewportFrame")
iconVf.Name = "Icon"
iconVf.BackgroundTransparency = 1
iconVf.Size = UDim2.fromOffset(78, 78)
iconVf.Position = UDim2.fromOffset(14, 4)
iconVf.Ambient = Color3.fromRGB(200, 200, 200)
iconVf.LightDirection = Vector3.new(-1, -2, -1)
iconVf.ZIndex = 3
iconVf.Parent = header
local iconPreview = buildPreview(iconVf, "Normal", 0.6, 0)
updatePreview(iconPreview, 0)

local title = text(header, "Base skins", UDim2.new(1, -220, 0, 62), UDim2.fromOffset(104, 12), WHITE, 4, nil, Enum.TextXAlignment.Left)
title.ZIndex = 3

local closeBtn = button(header, "CloseButton", UDim2.fromOffset(64, 64), UDim2.new(1, -78, 0, 11), RED)
closeBtn.ZIndex = 3
local closeX = text(closeBtn, "X", UDim2.new(1, -14, 1, -14), UDim2.fromOffset(7, 7), WHITE, 3)
closeX.ZIndex = 4

local list = Instance.new("ScrollingFrame")
list.Name = "List"
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.Position = UDim2.fromOffset(12, HEADER_H + 10)
list.Size = UDim2.new(1, -24, 1, -(HEADER_H + 22))
list.ScrollBarThickness = 8
list.ScrollBarImageColor3 = PURPLE
list.ScrollingDirection = Enum.ScrollingDirection.Y
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.CanvasSize = UDim2.new()
list.Parent = main
local ll = Instance.new("UIListLayout")
ll.Padding = UDim.new(0, 14)
ll.SortOrder = Enum.SortOrder.LayoutOrder
ll.HorizontalAlignment = Enum.HorizontalAlignment.Center
ll.Parent = list
local lp = Instance.new("UIPadding")
lp.PaddingTop = UDim.new(0, 6)
lp.PaddingBottom = UDim.new(0, 10)
lp.PaddingRight = UDim.new(0, 12)
lp.Parent = list

--== Cartes ==--
local state = nil
local cards = {}
local rainbowGrads = {}

local function statusOf(key: string)
	local info = state and state.skins[key]
	if state and state.equipped == key then
		return "equipped", info
	elseif key == "Normal" or (info and info.unlocked) then
		return "unlocked", info
	end
	return "locked", info
end

local function fetchPrice(skin, apply: (string) -> ())
	apply(ROBUX .. " " .. tostring(skin.price or 0))
	if not skin.productId or skin.productId == 0 then
		return
	end
	task.spawn(function()
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(skin.productId, Enum.InfoType.Product)
		end)
		if ok and info and info.PriceInRobux then
			apply(ROBUX .. " " .. tostring(info.PriceInRobux))
		end
	end)
end

local function showToast(msg: string, col: Color3)
	local existing = screenGui:FindFirstChild("ShopBanner")
	if existing then
		existing:Destroy()
	end
	local banner = text(screenGui, msg, UDim2.new(0.6, 0, 0, 56), UDim2.new(0.5, 0, 1, -24), col, 3)
	banner.Name = "ShopBanner"
	banner.AnchorPoint = Vector2.new(0.5, 1)
	banner.ZIndex = 100
	local sc = Instance.new("UIScale")
	sc.Scale = 1.3
	sc.Parent = banner
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(1.6, function()
		if banner.Parent then
			banner:Destroy()
		end
	end)
end

local refresh

for i, skin in ipairs(BaseSkinShared.SKINS) do
	local isRainbow = skin.key == "Rainbow"
	local accent = isRainbow and Color3.fromRGB(170, 60, 255) or skin.color

	local card = Instance.new("Frame")
	card.Name = "Card_" .. skin.key
	card.LayoutOrder = i
	card.Size = UDim2.new(1, -8, 0, CARD_H)
	card.BackgroundColor3 = isRainbow and WHITE or lighter(skin.color, 0.55)
	card.Parent = list
	corner(card, 18)
	local cs = Instance.new("UIStroke")
	cs.Thickness = 6
	cs.Color = WHITE
	cs.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	cs.Parent = card
	if isRainbow then
		table.insert(rainbowGrads, gradient(card, RAINBOW_LIGHT, 0))
		table.insert(rainbowGrads, gradient(cs, RAINBOW, 0))
	else
		gradient(card, ColorSequence.new(lighter(skin.color, 0.72), lighter(skin.color, 0.35)))
		gradient(cs, ColorSequence.new(skin.color, darker(skin.color, 0.35)))
	end
	studs(card, 18, 0.8)

	local name = text(card, skin.name, UDim2.new(0.46, 0, 0, 58), UDim2.fromOffset(22, 12), WHITE, 3.5, nil, Enum.TextXAlignment.Left)
	if isRainbow then
		table.insert(rainbowGrads, gradient(name, RAINBOW, 0))
	else
		gradient(name, ColorSequence.new(lighter(skin.color, 0.55), skin.color))
	end
	name.UIStroke.Color = darker(accent, 0.6)

	local req = text(card, "", UDim2.new(0.44, 0, 0, 46), UDim2.fromOffset(22, 72), WHITE, 2, 22, Enum.TextXAlignment.Left)
	req.TextWrapped = true

	local progress = text(card, "", UDim2.new(0.44, 0, 0, 34), UDim2.fromOffset(22, 120), PROGRESS_COL, 2.5, 30, Enum.TextXAlignment.Left)
	progress.UIStroke.Color = Color3.fromRGB(90, 40, 0)

	local multRow = Instance.new("Frame")
	multRow.Name = "Mult"
	multRow.BackgroundTransparency = 1
	multRow.Size = UDim2.new(0.46, 0, 0, 52)
	multRow.Position = UDim2.fromOffset(18, 158)
	multRow.Parent = card
	local cashIcon = Instance.new("ImageLabel")
	cashIcon.BackgroundTransparency = 1
	cashIcon.Image = CASH_ICON
	cashIcon.Size = UDim2.fromOffset(52, 52)
	cashIcon.Parent = multRow
	local multText = text(multRow, ("x%s money"):format(fmtMult(skin.mult)), UDim2.new(1, -60, 1, -4), UDim2.fromOffset(60, 2), WHITE, 3, 40, Enum.TextXAlignment.Left)
	gradient(multText, ColorSequence.new(Color3.fromRGB(200, 255, 80), Color3.fromRGB(60, 205, 40)))
	multText.UIStroke.Color = Color3.fromRGB(15, 60, 10)

	local vf = Instance.new("ViewportFrame")
	vf.Name = "Preview"
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.new(0.27, 0, 1, -16)
	vf.Position = UDim2.new(0.48, 0, 0, 8)
	vf.Ambient = Color3.fromRGB(200, 200, 200)
	vf.LightDirection = Vector3.new(-1, -2, -1)
	vf.Parent = card
	local prev = buildPreview(vf, skin.key, i * 0.8, 0.5)
	updatePreview(prev, 0)

	local statusBtn = button(card, "StatusButton", UDim2.fromOffset(200, 70), UDim2.new(1, -222, 0, 24), COLOR_LOCKED)
	local statusText = text(statusBtn, "Locked", UDim2.new(1, -20, 1, -18), UDim2.fromOffset(10, 9), WHITE, 3)

	local robuxBtn, priceText
	if skin.key ~= "Normal" then
		robuxBtn = button(card, "RobuxButton", UDim2.fromOffset(200, 70), UDim2.new(1, -222, 0, 118), ROBUX_COL)
		gradient(robuxBtn, ColorSequence.new(Color3.fromRGB(215, 120, 255), Color3.fromRGB(140, 20, 230)))
		priceText = text(robuxBtn, "", UDim2.new(1, -20, 1, -18), UDim2.fromOffset(10, 9), WHITE, 3)
		fetchPrice(skin, function(t)
			priceText.Text = t
		end)
		robuxBtn.MouseButton1Click:Connect(function()
			local status = statusOf(skin.key)
			if status ~= "locked" then
				return
			end
			if skin.productId and skin.productId ~= 0 then
				MarketplaceService:PromptProductPurchase(player, skin.productId)
			elseif IS_STUDIO then
				UISounds.Play("Buy")
				studioBuyEvent:FireServer(skin.key)
			else
				UISounds.Play("BuyFail")
				showToast("Coming soon!", Color3.fromRGB(255, 215, 60))
			end
		end)
	end

	statusBtn.MouseButton1Click:Connect(function()
		if not state then
			return
		end
		local status, info = statusOf(skin.key)
		if status == "equipped" then
			return
		end
		if status == "locked" then
			UISounds.Play("BuyFail")
			shake(statusBtn)
			local missing = info and math.max(info.required - info.count, 0) or 0
			showToast(("Discover %d more %s brainrots!"):format(missing, skin.key), Color3.fromRGB(255, 110, 110))
			return
		end
		equipEvent:FireServer(skin.key)
	end)

	cards[skin.key] = {
		skin = skin,
		req = req,
		progress = progress,
		statusBtn = statusBtn,
		statusText = statusText,
		robuxBtn = robuxBtn,
	}
end

refresh = function()
	for key, c in pairs(cards) do
		local skin = c.skin
		local status, info = statusOf(key)
		if key == "Normal" then
			c.req.Text = "Your classic base, always yours."
			c.progress.Text = "Default skin"
		elseif info then
			if info.bought then
				c.req.Text = "Bought with Robux. Thanks!"
			else
				c.req.Text = ("Discover %d %s brainrots to claim."):format(info.required, skin.key)
			end
			c.progress.Text = ("You have %d out of %d"):format(math.min(info.count, info.required), info.required)
		else
			c.req.Text = "..."
			c.progress.Text = ""
		end

		if status == "equipped" then
			recolorButton(c.statusBtn, COLOR_EQUIPPED)
			c.statusText.Text = "Equipped"
		elseif status == "unlocked" then
			recolorButton(c.statusBtn, COLOR_EQUIP)
			c.statusText.Text = "Equip"
		else
			recolorButton(c.statusBtn, COLOR_LOCKED)
			c.statusText.Text = "Locked"
		end

		local showRobux = c.robuxBtn ~= nil and status == "locked"
		if c.robuxBtn then
			c.robuxBtn.Visible = showRobux
		end
		c.statusBtn.Position = showRobux and UDim2.new(1, -222, 0, 24) or UDim2.new(1, -222, 0.5, -35)
	end
end
refresh()

--== Etat serveur ==--
local lastUnlocked = {}

local function loadState()
	local ok, result = pcall(function()
		return getState:InvokeServer()
	end)
	if ok and result then
		state = result
		for key, info in pairs(state.skins) do
			if lastUnlocked[key] == nil then
				lastUnlocked[key] = info.unlocked
			end
		end
		refresh()
	end
end

changedEvent.OnClientEvent:Connect(function(newState)
	if state then
		for key, info in pairs(newState.skins) do
			if info.unlocked and lastUnlocked[key] == false and key ~= "Normal" then
				local skin = BaseSkinShared.Get(key)
				showToast((skin and skin.name or key) .. " unlocked!", Color3.fromRGB(110, 255, 110))
				UISounds.Play("Buy")
			end
		end
	end
	for key, info in pairs(newState.skins) do
		lastUnlocked[key] = info.unlocked
	end
	state = newState
	refresh()
end)

task.spawn(loadState)

MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, _productId, purchased)
	if userId == player.UserId and not purchased and overlay.Visible then
		UISounds.Play("BuyFail")
	end
end)

--== Ouverture / fermeture ==--
local isOpen = false

local function targetScale(): number
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	return math.clamp(math.min(vp.X * 0.94 / BASE_W, vp.Y * 0.88 / BASE_H), 0.35, 1.1)
end

local function openShop()
	if isOpen then
		return
	end
	isOpen = true
	UISounds.Play("Popup")
	task.spawn(loadState)
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	fitScale.Scale = 0
	list.CanvasPosition = Vector2.zero
	TweenService:Create(overlay, TweenInfo.new(0.18), { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(fitScale, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = targetScale() }):Play()
end

local function closeShop()
	if not isOpen then
		return
	end
	isOpen = false
	UISounds.Play("Close")
	TweenService:Create(fitScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }):Play()
	local fade = TweenService:Create(overlay, TweenInfo.new(0.15), { BackgroundTransparency = 1 })
	fade:Play()
	fade.Completed:Once(function()
		if not isOpen then
			overlay.Visible = false
		end
	end)
end

closeBtn.MouseButton1Click:Connect(closeShop)

task.spawn(function()
	while not workspace.CurrentCamera do
		task.wait()
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if isOpen then
			fitScale.Scale = targetScale()
		end
	end)
end)

--== Stand : base qui tourne ==--
local stand = workspace:WaitForChild("BaseStand")
local portalPart = stand:WaitForChild("Cylinder"):WaitForChild("LowerPart") :: BasePart
local portalRadius = math.max(portalPart.Size.Y, portalPart.Size.Z) / 2
local portalCenter = portalPart.Position
local spinBase = stand:WaitForChild("SkinDisplay"):WaitForChild("SpinBase") :: Model
local spinOrigin = spinBase:GetPivot()
local spinCenter = spinBase:GetBoundingBox().Position
local spinOffset = spinCenter - spinOrigin.Position

local clock = 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	local cam = workspace.CurrentCamera
	if cam and (cam.CFrame.Position - spinCenter).Magnitude < 250 then
		local rot = CFrame.Angles(0, clock * 0.8, 0)
		spinBase:PivotTo(CFrame.new(spinCenter) * rot * CFrame.new(-spinOffset) * (spinOrigin - spinOrigin.Position))
	end
	if not isOpen then
		return
	end
	local off = Vector2.new(math.sin(clock * 1.5) * 0.5, 0)
	for _, g in ipairs(rainbowGrads) do
		g.Offset = off
	end
	for _, p in ipairs(previews) do
		if p.speed ~= 0 then
			updatePreview(p, clock)
		end
	end
end)

--== Zone d'ouverture ==--
local rootPart: BasePart? = nil
local function bindCharacter(character: Model)
	rootPart = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
end
if player.Character then
	task.spawn(bindCharacter, player.Character)
end
player.CharacterAdded:Connect(bindCharacter)
player.CharacterRemoving:Connect(function()
	rootPart = nil
end)

task.spawn(function()
	local wasInside = false
	while true do
		task.wait(0.1)
		local hrp = rootPart
		local inside = false
		if hrp and hrp.Parent then
			local p = hrp.Position
			local dx, dz = p.X - portalCenter.X, p.Z - portalCenter.Z
			inside = dx * dx + dz * dz <= portalRadius * portalRadius and math.abs(p.Y - portalCenter.Y) < 12
		end
		if inside and not wasInside then
			openShop()
		elseif not inside and wasInside then
			closeShop()
		end
		wasInside = inside
	end
end)
