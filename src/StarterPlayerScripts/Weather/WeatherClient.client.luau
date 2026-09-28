--[[
	WeatherClient
	-------------
	LocalScript (StarterPlayerScripts.Weather).
	UI des meteos (style studs) : banniere en haut + barre de temps +
	annonce au centre. Les effets du monde et les sons : WeatherFX.
	Icones : WeatherShared.LIST[].icon (sinon WeatherShared.DEFAULT_ICON).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local WeatherShared = require(ReplicatedStorage:WaitForChild("WeatherShared"))
local WeatherFX = require(script.Parent:WaitForChild("WeatherFX"))

local player = Players.LocalPlayer

local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local STUDS_ID = "rbxassetid://10509831729"
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local INK = Color3.fromRGB(12, 10, 24)
local GOLD = Color3.fromRGB(255, 224, 48)
local RED = Color3.fromRGB(255, 60, 70)
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 40, 40)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 0)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(40, 235, 70)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 170, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 50, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 40, 40)),
})

local BANNER_W, BANNER_H = 460, 100

--== Helpers ==--
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
	return c
end

local function stroke(p, th, col)
	local s = Instance.new("UIStroke")
	s.Thickness = th
	s.Color = col or INK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = p:IsA("TextLabel") and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

local function gradient(p, seq, rot)
	local g = Instance.new("UIGradient")
	g.Color = seq
	g.Rotation = rot or 90
	g.Parent = p
	return g
end

local function studs(p, r, transp)
	local img = Instance.new("ImageLabel")
	img.Name = "StudsTexture"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = STUDS_ID
	img.ScaleType = Enum.ScaleType.Tile
	img.TileSize = UDim2.fromOffset(30, 30)
	img.ImageTransparency = transp or 0.8
	img.ZIndex = p.ZIndex
	img.Parent = p
	corner(img, r)
	return img
end

local function frame(parent, name, size, pos, col, z)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos or UDim2.new()
	f.BackgroundColor3 = col or WHITE
	f.BorderSizePixel = 0
	f.ZIndex = z or 1
	f.Parent = parent
	return f
end

local function text(parent, name, size, pos, th, z)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.FontFace = FONT
	l.TextScaled = true
	l.RichText = true
	l.TextColor3 = WHITE
	l.Size = size
	l.Position = pos
	l.ZIndex = z or 1
	l.Parent = parent
	stroke(l, th or 2.5)
	return l
end

local function tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function seqFor(w)
	if w.rainbow then
		return RAINBOW
	end
	return ColorSequence.new(w.color:Lerp(WHITE, 0.25), w.color:Lerp(BLACK, 0.35))
end

--== Construction ==--
local gui = Instance.new("ScreenGui")
gui.Name = "WeatherGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 4
gui.Parent = player:WaitForChild("PlayerGui")

local flash = frame(gui, "Flash", UDim2.fromScale(1, 1), nil, WHITE, 1)
flash.BackgroundTransparency = 1

-- Banniere
local holder = frame(gui, "BannerHolder", UDim2.fromOffset(BANNER_W, BANNER_H + 22), UDim2.new(0.5, 0, 0, -160), WHITE, 5)
holder.AnchorPoint = Vector2.new(0.5, 0)
holder.BackgroundTransparency = 1
holder.Visible = false
local fitScale = Instance.new("UIScale")
fitScale.Parent = holder

local glow = frame(holder, "Glow", UDim2.new(1, 18, 0, BANNER_H + 18), UDim2.fromOffset(-9, -9), WHITE, 4)
corner(glow, 28)
glow.BackgroundTransparency = 0.6

local banner = frame(holder, "Banner", UDim2.new(1, 0, 0, BANNER_H), nil, WHITE, 5)
corner(banner, 20)
stroke(banner, 4)
local bannerGrad = gradient(banner, RAINBOW, 90)
studs(banner, 20, 0.78)
local wobble = Instance.new("UIScale")
wobble.Parent = banner

local shine = frame(banner, "Shine", UDim2.fromScale(1, 1), nil, WHITE, 6)
corner(shine, 20)
local shineGrad = Instance.new("UIGradient")
shineGrad.Rotation = 20
shineGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.42, 1),
	NumberSequenceKeypoint.new(0.5, 0.55),
	NumberSequenceKeypoint.new(0.58, 1),
	NumberSequenceKeypoint.new(1, 1),
})
shineGrad.Offset = Vector2.new(-1, 0)
shineGrad.Parent = shine

local badge = frame(banner, "IconBadge", UDim2.fromOffset(80, 80), UDim2.new(0, 10, 0.5, 0), WHITE, 7)
badge.AnchorPoint = Vector2.new(0, 0.5)
corner(badge, 18)
stroke(badge, 3)
local badgeGrad = gradient(badge, RAINBOW, 90)
studs(badge, 18, 0.7)
local icon = Instance.new("ImageLabel")
icon.Name = "Icon"
icon.BackgroundTransparency = 1
icon.AnchorPoint = Vector2.new(0.5, 0.5)
icon.Position = UDim2.fromScale(0.5, 0.5)
icon.Size = UDim2.fromScale(0.86, 0.86)
icon.ScaleType = Enum.ScaleType.Fit
icon.ZIndex = 8
icon.Parent = badge
-- Icone dessinee (emoji) si la meteo n'a pas d'image : WeatherShared.LIST[].emoji.
local iconEmoji = Instance.new("TextLabel")
iconEmoji.Name = "IconEmoji"
iconEmoji.BackgroundTransparency = 1
iconEmoji.AnchorPoint = Vector2.new(0.5, 0.5)
iconEmoji.Position = UDim2.fromScale(0.5, 0.52)
iconEmoji.Size = UDim2.fromScale(0.8, 0.8)
iconEmoji.TextScaled = true
iconEmoji.ZIndex = 9
iconEmoji.Visible = false
iconEmoji.Parent = badge

local title = text(banner, "Title", UDim2.new(1, -112, 0, 40), UDim2.fromOffset(102, 8), 3, 8)
title.TextXAlignment = Enum.TextXAlignment.Left
local titleGrad = gradient(title, ColorSequence.new(WHITE), 90)

local subPill = frame(banner, "SubPill", UDim2.new(1, -214, 0, 34), UDim2.fromOffset(102, 56), INK, 7)
subPill.BackgroundTransparency = 0.25
corner(subPill, 12)
local sub = text(subPill, "Sub", UDim2.new(1, -16, 1, -8), UDim2.fromOffset(8, 4), 2, 8)

local timerPill = frame(banner, "TimerPill", UDim2.fromOffset(94, 34), UDim2.new(1, -104, 0, 56), INK, 7)
timerPill.BackgroundTransparency = 0.25
corner(timerPill, 12)
local timerStroke = stroke(timerPill, 2, GOLD)
local timer = text(timerPill, "Timer", UDim2.new(1, -12, 1, -8), UDim2.fromOffset(6, 4), 2, 8)
local timerScale = Instance.new("UIScale")
timerScale.Parent = timerPill

local bar = frame(holder, "TimeBar", UDim2.new(1, -40, 0, 14), UDim2.new(0, 20, 0, BANNER_H + 4), INK, 4)
corner(bar, 7)
stroke(bar, 3)
local fill = frame(bar, "Fill", UDim2.fromScale(1, 1), nil, WHITE, 5)
corner(fill, 7)
local fillGrad = gradient(fill, RAINBOW, 0)
studs(fill, 7, 0.75)

local sparkleLayer = frame(holder, "Sparkles", UDim2.fromScale(1, 1), nil, WHITE, 9)
sparkleLayer.BackgroundTransparency = 1

-- Annonce centrale
local splash = frame(gui, "Splash", UDim2.fromOffset(640, 190), UDim2.fromScale(0.5, 0.38), WHITE, 20)
splash.AnchorPoint = Vector2.new(0.5, 0.5)
splash.BackgroundTransparency = 1
splash.Visible = false
local splashScale = Instance.new("UIScale")
splashScale.Parent = splash

local ribbon = frame(splash, "Ribbon", UDim2.new(1, 0, 0, 120), UDim2.fromScale(0.5, 0.4), WHITE, 21)
ribbon.AnchorPoint = Vector2.new(0.5, 0.5)
corner(ribbon, 24)
local ribbonStroke = stroke(ribbon, 5)
local ribbonGrad = gradient(ribbon, RAINBOW, 90)
local ribbonStuds = studs(ribbon, 24, 0.75)
local splashTitle = text(ribbon, "Title", UDim2.new(1, -40, 1, -24), UDim2.fromOffset(20, 12), 5, 23)
local splashTitleGrad = gradient(splashTitle, ColorSequence.new(WHITE), 90)

local splashPill = frame(splash, "Pill", UDim2.fromOffset(380, 48), UDim2.new(0.5, 0, 0.4, 78), INK, 22)
splashPill.AnchorPoint = Vector2.new(0.5, 0)
corner(splashPill, 16)
local splashPillStroke = stroke(splashPill, 3, GOLD)
local splashSub = text(splashPill, "Sub", UDim2.new(1, -20, 1, -12), UDim2.fromOffset(10, 6), 2.5, 23)

--== Animations ==--
local current = nil
local clock = 0

local function spawnSparkle(layer, color, fromCenter)
	local s = Instance.new("TextLabel")
	s.BackgroundTransparency = 1
	s.Text = math.random() < 0.7 and "\u{2726}" or "\u{2727}"
	s.FontFace = FONT
	s.TextScaled = true
	s.TextColor3 = math.random() < 0.5 and color:Lerp(WHITE, 0.5) or WHITE
	local size = math.random(14, 26)
	s.Size = UDim2.fromOffset(size, size)
	s.AnchorPoint = Vector2.new(0.5, 0.5)
	s.ZIndex = layer.ZIndex + 1
	stroke(s, 1.5)
	s.Parent = layer
	local t = math.random(9, 16) / 10
	if fromCenter then
		local a = math.random() * math.pi * 2
		s.Position = UDim2.fromScale(0.5, 0.45)
		tween(s, t, {
			Position = UDim2.new(0.5, math.cos(a) * math.random(180, 380), 0.45, math.sin(a) * math.random(90, 200)),
			TextTransparency = 1,
			Rotation = math.random(-180, 180),
		}, Enum.EasingStyle.Quint)
	else
		s.Position = UDim2.new(math.random(), 0, math.random() < 0.5 and 0 or 0.85, 0)
		tween(s, t, {
			Position = s.Position + UDim2.fromOffset(math.random(-20, 20), math.random(-40, -20)),
			TextTransparency = 1,
			Rotation = math.random(-90, 90),
		}, Enum.EasingStyle.Sine)
	end
	local st = s:FindFirstChildOfClass("UIStroke")
	if st then
		tween(st, t, { Transparency = 1 })
	end
	task.delay(t, function()
		s:Destroy()
	end)
end

local function updateFit()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	fitScale.Scale = math.clamp((vp.X - 24) / (BANNER_W + 20), 0.55, 1)
	splashScale:SetAttribute("Fit", math.clamp((vp.X - 24) / 660, 0.5, 1))
end
updateFit()
local function bindCam()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(updateFit)
	end
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCam)
bindCam()

local splashToken = 0
local function playSplash(w)
	splashToken += 1
	local my = splashToken
	local fit = splashScale:GetAttribute("Fit") or 1
	local seq = seqFor(w)

	ribbonGrad.Color = seq
	splashTitleGrad.Color = w.rainbow and RAINBOW or ColorSequence.new(WHITE, w.color:Lerp(WHITE, 0.55))
	splashTitleGrad.Rotation = w.rainbow and 0 or 90
	splashTitle.Text = string.upper(w.name) .. "!"
	splashSub.Text = ('%s MUTATION <font color="#FFE030">x%d</font> CHANCE!'):format(string.upper(w.key), w.boost or WeatherShared.BOOST)
	splashPillStroke.Color = w.rainbow and GOLD or w.color:Lerp(WHITE, 0.3)

	for _, o in ipairs({ splashTitle, splashSub }) do
		o.TextTransparency = 0
		o:FindFirstChildOfClass("UIStroke").Transparency = 0
	end
	ribbon.BackgroundTransparency = 0
	ribbonStroke.Transparency = 0
	ribbonStuds.ImageTransparency = 0.75
	splashPill.BackgroundTransparency = 0
	splashPillStroke.Transparency = 0
	splash.Position = UDim2.fromScale(0.5, 0.38)
	splash.Rotation = -8
	splashScale.Scale = 0
	splash.Visible = true

	tween(splashScale, 0.55, { Scale = fit }, Enum.EasingStyle.Back)
	tween(splash, 0.55, { Rotation = -3 }, Enum.EasingStyle.Back)
	flash.BackgroundColor3 = w.color:Lerp(WHITE, 0.45)
	flash.BackgroundTransparency = 0.25
	tween(flash, 0.9, { BackgroundTransparency = 1 })
	for _ = 1, 16 do
		spawnSparkle(splash, w.color, true)
	end

	task.spawn(function()
		local t0 = os.clock()
		while my == splashToken and os.clock() - t0 < 2.6 do
			local t = os.clock() - t0
			splash.Rotation = -3 + math.sin(t * 6) * 1.5
			if w.rainbow then
				ribbonGrad.Offset = Vector2.new(0, math.sin(t * 2) * 0.4)
				splashTitleGrad.Offset = Vector2.new(math.sin(t * 2.4) * 0.5, 0)
			end
			task.wait()
		end
		if my ~= splashToken then
			return
		end
		local out = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		TweenService:Create(splash, out, { Position = UDim2.new(0.5, 0, 0, 30), Rotation = 0 }):Play()
		TweenService:Create(splashScale, out, { Scale = 0.15 }):Play()
		task.wait(0.35)
		for _, o in ipairs({ splashTitle, splashSub }) do
			tween(o, 0.15, { TextTransparency = 1 })
			tween(o:FindFirstChildOfClass("UIStroke"), 0.15, { Transparency = 1 })
		end
		tween(ribbon, 0.15, { BackgroundTransparency = 1 })
		tween(ribbonStroke, 0.15, { Transparency = 1 })
		tween(ribbonStuds, 0.15, { ImageTransparency = 1 })
		tween(splashPill, 0.15, { BackgroundTransparency = 1 })
		tween(splashPillStroke, 0.15, { Transparency = 1 })
		task.wait(0.2)
		if my == splashToken then
			splash.Visible = false
			wobble.Scale = 1.12
			tween(wobble, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		end
	end)
end

local function show(w)
	current = w
	local seq = seqFor(w)
	bannerGrad.Color = seq
	fillGrad.Color = w.rainbow and RAINBOW or ColorSequence.new(w.color:Lerp(WHITE, 0.35), w.color)
	badgeGrad.Color = w.rainbow and RAINBOW or ColorSequence.new(WHITE, w.color:Lerp(WHITE, 0.55))
	glow.BackgroundColor3 = w.rainbow and WHITE or w.color
	titleGrad.Color = w.rainbow and RAINBOW or ColorSequence.new(WHITE, w.color:Lerp(WHITE, 0.6))
	titleGrad.Rotation = w.rainbow and 0 or 90
	title.Text = string.upper(w.name)
	sub.Text = ('%s MUTATION <font color="#FFE030">x%d</font>'):format(string.upper(w.key), w.boost or WeatherShared.BOOST)
	local hasImage = w.icon ~= nil and w.icon ~= ""
	local useEmoji = not hasImage and w.emoji ~= nil
	icon.Image = hasImage and w.icon or (useEmoji and "" or WeatherShared.DEFAULT_ICON or "")
	iconEmoji.Visible = useEmoji
	iconEmoji.Text = w.emoji or ""

	holder.Visible = true
	holder.Position = UDim2.new(0.5, 0, 0, -160)
	tween(holder, 0.7, { Position = UDim2.new(0.5, 0, 0, 12) }, Enum.EasingStyle.Back)
	playSplash(w)
	WeatherFX.Start(w.key)
end

local function hide()
	current = nil
	WeatherFX.Stop(false)
	local tw = tween(holder, 0.35, { Position = UDim2.new(0.5, 0, 0, -160) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tw.Completed:Connect(function()
		if not current then
			holder.Visible = false
		end
	end)
end

local function refresh()
	local w = WeatherShared.GetCurrent()
	if w and w ~= current then
		show(w)
	elseif not w and current then
		hide()
	end
end

workspace:GetAttributeChangedSignal("Weather"):Connect(refresh)
workspace:GetAttributeChangedSignal("WeatherEndsAt"):Connect(refresh)

local acc = 0
local sparkleTimer = 0
local shineTimer = 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	if not current then
		return
	end
	glow.BackgroundTransparency = 0.62 + math.sin(clock * 3) * 0.12
	badge.Rotation = math.sin(clock * 2.2) * 6
	icon.Position = UDim2.new(0.5, 0, 0.5, math.sin(clock * 3) * 3)

	shineTimer += dt
	local cycle = shineTimer % 3
	shineGrad.Offset = Vector2.new(cycle < 0.9 and (-1 + cycle / 0.9 * 2) or 1, 0)

	if current.rainbow then
		bannerGrad.Offset = Vector2.new(0, math.sin(clock * 1.5) * 0.4)
		titleGrad.Offset = Vector2.new(math.sin(clock * 1.8) * 0.5, 0)
		fillGrad.Offset = Vector2.new(math.sin(clock * 2) * 0.3, 0)
		badgeGrad.Rotation = (clock * 90) % 360
		glow.BackgroundColor3 = Color3.fromHSV((clock * 0.2) % 1, 0.6, 1)
	end

	sparkleTimer += dt
	if sparkleTimer >= 0.3 then
		sparkleTimer = 0
		spawnSparkle(sparkleLayer, current.rainbow and Color3.fromHSV(math.random(), 0.7, 1) or current.color, false)
	end

	acc += dt
	if acc >= 0.1 then
		acc = 0
		local _, left = WeatherShared.GetCurrent()
		if left <= 0 then
			refresh()
			return
		end
		local s = math.ceil(left)
		timer.Text = ("\u{23F1} %d:%02d"):format(s // 60, s % 60)
		fill.Size = UDim2.fromScale(math.clamp(left / WeatherShared.DURATION, 0, 1), 1)
		local urgent = left <= 10
		timerStroke.Color = urgent and RED or GOLD
		timer.TextColor3 = urgent and Color3.fromRGB(255, 120, 120) or WHITE
	end
	timerScale.Scale = (timer.TextColor3 ~= WHITE) and (1 + math.abs(math.sin(clock * 6)) * 0.1) or 1
end)

refresh()
