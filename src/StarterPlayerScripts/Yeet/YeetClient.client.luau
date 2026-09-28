--[[
	YeetClient (v2)
	---------------
	LocalScript dans StarterPlayerScripts.Yeet.

	Deroule d'un yeet (vu par TOUS les joueurs, synchro GetServerTimeNow) :
	  1. PRISE  : un noob apparait (pop) derriere le joueur, qui se retourne,
	              l'attrape et le souleve au-dessus de sa tete (Shared.PICKUP).
	  2. CHARGE : barre de puissance ; le joueur arme de plus en plus fort,
	              le noob tremble, aura + disque au sol aux couleurs de la barre.
	  3. TIR    : grosse prise d'elan (Shared.WINDUP) puis fouette : onde de
	              choc, le noob part en vrille avec trainee + briques studs.
	  4. IMPACT : ondes, fumee, briques, nom de la zone + distance.

	Anim du perso : Transform des joints reecrit apres l'Animator
	(PreSimulation). Noob : parties placees a la main (BulkMoveTo).
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local YeetFolder = ReplicatedStorage:WaitForChild("Yeet")
local Shared = require(YeetFolder:WaitForChild("YeetShared"))
local YeetEvent = YeetFolder:WaitForChild("YeetEvent")
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))

local function playUI(name)
	pcall(UISounds.Play, name)
end

local function serverNow()
	return Workspace:GetServerTimeNow()
end

local PICKUP = Shared.PICKUP or 0.9
local WINDUP = Shared.WINDUP
local PERFECT_V = (Shared.PERFECT_MULT - Shared.MIN_MULT) / (Shared.MAX_MULT - Shared.MIN_MULT)
local SEND_TIMEOUT = 1.5

--== Palette ==--
local FONT = Enum.Font.LuckiestGuy
local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(10, 10, 20)
local GOLD = Color3.fromRGB(255, 190, 0)
local RED = Color3.fromRGB(255, 35, 50)
local YELLOW = Color3.fromRGB(255, 220, 0)
local GREEN = Color3.fromRGB(30, 230, 70)
local ORANGE = Color3.fromRGB(255, 120, 0)
local BLUE = Color3.fromRGB(0, 140, 255)
local PANEL = Color3.fromRGB(140, 40, 255)
local PANEL_DARK = Color3.fromRGB(20, 22, 36)
local PLATE_OFF = Color3.fromRGB(86, 91, 114)
local SUBTEXT = Color3.fromRGB(255, 255, 255)

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local function colorForV(v: number): Color3
	if v >= PERFECT_V - 1e-6 then
		return GOLD
	elseif v < 0.5 then
		return RED:Lerp(YELLOW, v * 2)
	end
	return YELLOW:Lerp(GREEN, (v - 0.5) * 2)
end

--== Controles (on fige le joueur pendant la prise / la barre) ==--
local controls = nil
task.spawn(function()
	local ps = player:WaitForChild("PlayerScripts")
	local pmModule = ps:WaitForChild("PlayerModule", 5)
	if pmModule then
		local ok, pm = pcall(require, pmModule)
		if ok and pm then
			controls = pm:GetControls()
		end
	end
end)

local frozenRoot = nil
local function setControls(enabled: boolean)
	if controls then
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end
	if enabled then
		if frozenRoot and frozenRoot.Parent and not player:GetAttribute("Yeeting") then
			frozenRoot.Anchored = false
		end
		frozenRoot = nil
	else
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
			root.Anchored = true
			frozenRoot = root
		end
	end
end

local fxFolder = Instance.new("Folder")
fxFolder.Name = "YeetFxLocal"
fxFolder.Parent = Workspace

--==================================================================
--== Kit UI (briques / studs, coins arrondis) ==--
--==================================================================
local function shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

local function corner(parent: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = r and UDim.new(0, r) or UDim.new(1, 0)
	c.Parent = parent
	return c
end

local function stroke(parent: Instance, thickness: number, color: Color3?, contextual: boolean?)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = contextual and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	s.Color = color or INK
	s.Thickness = thickness
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end

local function gradient(parent: Instance, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = parent
	return g
end

local function frame(parent: Instance, props)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		f[k] = v
	end
	f.Parent = parent
	return f
end

-- Un stud vu de face : flanc fonce + dessus clair + reflet.
local function makeStud(parent: Instance, size: number, color: Color3)
	local stud = frame(parent, { Name = "Stud", Size = UDim2.fromOffset(size, size), BackgroundColor3 = shade(color, 0.68) })
	corner(stud)
	stroke(stud, math.max(1.5, size / 9))
	local top = frame(stud, {
		Name = "Top",
		Size = UDim2.new(1, 0, 1, -math.max(2, math.floor(size * 0.22))),
		BackgroundColor3 = color,
	})
	corner(top)
	gradient(top, WHITE, Color3.fromRGB(212, 212, 212))
	local shine = frame(top, {
		Size = UDim2.fromScale(0.34, 0.3),
		Position = UDim2.fromScale(0.18, 0.14),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.35,
	})
	corner(shine)
	return { frame = stud, top = top }
end

--[[
	Plaque au style du jeu (comme RebirthUI / IndexUI) : couleur pleine +
	degrade, texture studs en mosaique, ombre en bas, contour sombre.
]]
local STUDS_IMAGE = "rbxassetid://10509831729"

local function studsTexture(parent: Instance, tile: number, transparency: number, radius: number?)
	local img = Instance.new("ImageLabel")
	img.Name = "StudsTexture"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = STUDS_IMAGE
	img.ImageTransparency = transparency
	img.ScaleType = Enum.ScaleType.Tile
	img.TileSize = UDim2.fromOffset(tile, tile)
	img.ZIndex = 2
	img.Parent = parent
	corner(img, radius)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Transparency = NumberSequence.new(0, 0.35)
	g.Parent = img
	return img
end

local function makeBrick(parent: Instance, w: number, h: number, color: Color3, opt)
	opt = opt or {}
	local radius = opt.radius or 14
	local plate = frame(parent, { Name = "Plate", Size = UDim2.fromOffset(w, h), BackgroundColor3 = color, ZIndex = 1 })
	corner(plate, radius)
	local outline = stroke(plate, opt.strokeT or (h >= 60 and 4 or 3))
	gradient(plate, WHITE, Color3.fromRGB(215, 215, 215))
	local tile = opt.tile or math.clamp(math.floor(math.min(w, h) * 0.26), 8, 24)
	studsTexture(plate, tile, opt.studsT or 0.62, radius)
	return { brick = plate, face = plate, studs = {}, stroke = outline, color = color }
end

local function setBrickColor(b, color: Color3)
	if b.color == color then
		return
	end
	b.color = color
	b.brick.BackgroundColor3 = color
end

local function makeText(parent: Instance, str: string, size: UDim2, pos: UDim2, anchor: Vector2?, strokeT: number?, color: Color3?)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.Text = str
	l.TextColor3 = color or WHITE
	l.TextScaled = true
	l.Size = size
	l.Position = pos
	l.AnchorPoint = anchor or Vector2.zero
	l.ZIndex = 6
	l.Parent = parent
	local s = stroke(l, strokeT or 3, INK, true)
	return l, s
end

-- Tete de noob (bloc jaune + stud + visage).
local function noobIcon(parent: Instance, size: number)
	local nub = frame(parent, {
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(math.floor(size * 0.42), math.floor(size * 0.22)),
		BackgroundColor3 = Shared.NOOB_YELLOW,
		ZIndex = 4,
	})
	corner(nub, 4)
	stroke(nub, 2)
	local head = frame(parent, { Name = "NoobIcon", Size = UDim2.fromOffset(size, size), BackgroundColor3 = Shared.NOOB_YELLOW, ZIndex = 5 })
	corner(head, math.floor(size * 0.22))
	stroke(head, 3)
	gradient(head, WHITE, Color3.fromRGB(214, 214, 214))
	studsTexture(head, 10, 0.62, math.floor(size * 0.22))
	local face = Instance.new("ImageLabel")
	face.BackgroundTransparency = 1
	face.Image = "rbxasset://textures/face.png"
	face.Size = UDim2.fromScale(1, 1)
	face.ZIndex = 6
	face.Parent = head
	-- Le "nub" suit la tete.
	local function sync()
		nub.Position = UDim2.new(head.Position.X.Scale, head.Position.X.Offset + (0.5 - head.AnchorPoint.X) * size,
			head.Position.Y.Scale, head.Position.Y.Offset - head.AnchorPoint.Y * size + 4)
		nub.Rotation = head.Rotation
	end
	head:GetPropertyChangedSignal("Position"):Connect(sync)
	head:GetPropertyChangedSignal("AnchorPoint"):Connect(sync)
	head:GetPropertyChangedSignal("Rotation"):Connect(sync)
	sync()
	return head
end

--==================================================================
--== GUI ==--
--==================================================================
local gui = Instance.new("ScreenGui")
gui.Name = "YeetGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 15
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local uiScale = Instance.new("UIScale")
uiScale.Parent = gui
local function refreshScale()
	local vp = Workspace.CurrentCamera.ViewportSize
	uiScale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 820), 0.55, 1.15)
end
refreshScale()
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)

--== Bouton YEET ==--
local BTN_W, BTN_H, BTN_DEPTH, BTN_STUD = 290, 94, 10, 24
local BTN_PAD = math.ceil(BTN_STUD * 0.55)

local buttonHolder = frame(gui, {
	Name = "YeetButton",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -34),
	Size = UDim2.fromOffset(BTN_W, BTN_H + BTN_PAD),
	BackgroundTransparency = 1,
	Visible = false,
})
local buttonScale = Instance.new("UIScale")
buttonScale.Scale = 0
buttonScale.Parent = buttonHolder

local btn = makeBrick(buttonHolder, BTN_W, BTN_H, ORANGE, { studs = 6, studSize = BTN_STUD, depth = BTN_DEPTH, radius = 18, pattern = true })
local BTN_REST = UDim2.fromOffset(0, BTN_PAD)
btn.brick.Position = BTN_REST
local btnPulse = Instance.new("UIScale")
btnPulse.Parent = btn.brick

local btnIcon = noobIcon(btn.face, 54)
btnIcon.AnchorPoint = Vector2.new(0, 0.5)
btnIcon.Position = UDim2.new(0, 18, 0.5, 2)
btnIcon.Rotation = -8

local btnTitle = makeText(btn.face, "YEET!", UDim2.new(1, -112, 0.56, 0), UDim2.new(0, 86, 0.08, 0), nil, 4)
btnTitle.TextXAlignment = Enum.TextXAlignment.Left
local btnSub = makeText(btn.face, "Throw the noob", UDim2.new(1, -118, 0.24, 0), UDim2.new(0, 88, 0.9, 0), Vector2.new(0, 1), 2, SUBTEXT)
btnSub.TextXAlignment = Enum.TextXAlignment.Left

local keyChip = makeBrick(btn.brick, 44, 40, PANEL_DARK, { studs = 1, studSize = 12, depth = 6, radius = 10 })
keyChip.brick.AnchorPoint = Vector2.new(0.5, 0.5)
keyChip.brick.Position = UDim2.new(1, -12, 1, -10)
keyChip.brick.ZIndex = 8
makeText(keyChip.face, "F", UDim2.fromScale(0.62, 0.78), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 2)
keyChip.brick.Visible = not UserInputService.TouchEnabled

local button = Instance.new("TextButton")
button.Name = "Hitbox"
button.Size = UDim2.fromScale(1, 1)
button.BackgroundTransparency = 1
button.Text = ""
button.ZIndex = 20
button.Parent = buttonHolder

local MODES = {
	yeet = { color = ORANGE, title = "YEET!", sub = "Throw the noob" },
	grab = { color = BLUE, title = "GRAB!", sub = "Picking up the noob..." },
	throw = { color = GREEN, title = "THROW!", sub = "Stop the power bar!" },
}
local buttonMode = "yeet"
local hovering = false

local function refreshButton()
	local m = MODES[buttonMode]
	setBrickColor(btn, hovering and m.color:Lerp(WHITE, 0.15) or m.color)
end

local function setButtonMode(mode: string)
	if buttonMode == mode then
		return
	end
	buttonMode = mode
	local m = MODES[mode]
	btnTitle.Text = m.title
	btnSub.Text = m.sub
	refreshButton()
	btn.brick.Position = BTN_REST - UDim2.fromOffset(0, 8)
	TweenService:Create(btn.brick, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = BTN_REST }):Play()
end

button.MouseEnter:Connect(function()
	hovering = true
	refreshButton()
end)
button.MouseLeave:Connect(function()
	hovering = false
	refreshButton()
	btn.brick.Position = BTN_REST
end)
button.MouseButton1Down:Connect(function()
	btn.brick.Position = BTN_REST + UDim2.fromOffset(0, BTN_DEPTH - 3)
end)
button.MouseButton1Up:Connect(function()
	TweenService:Create(btn.brick, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = BTN_REST }):Play()
end)

local buttonShown = false
local function setButtonShown(show: boolean)
	if show == buttonShown then
		return
	end
	buttonShown = show
	if show then
		buttonHolder.Visible = true
		TweenService:Create(buttonScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	else
		local tw = TweenService:Create(buttonScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		tw:Play()
		tw.Completed:Once(function()
			if not buttonShown then
				buttonHolder.Visible = false
			end
		end)
	end
end

--== Barre de puissance (jauge verticale, style MiniBar du Rebirth) ==--
local M = {}
M.ROOT_W = 150
M.HEADER_H = 78
M.TRACK_W = 50
M.TRACK_H = 330
M.GAP_Y = 16
M.INNER = 6
M.TRACK_Y = M.HEADER_H + M.GAP_Y
M.TRACK_X = math.floor((M.ROOT_W - M.TRACK_W) / 2)
M.INNER_H = M.TRACK_H - M.INNER * 2
M.ROOT_H = M.TRACK_Y + M.TRACK_H
M.METER_SHOWN = UDim2.new(1, -24, 0.5, 0)
M.METER_HIDDEN = UDim2.new(1, 220, 0.5, 0)
M.ZONE_Y = 0.2
M.BANNER_SHOWN = UDim2.new(0.5, 0, 0, 10)
M.BANNER_HIDDEN = UDim2.new(0.5, 0, 0, -170)

local meter = frame(gui, {
	Name = "Meter",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = M.METER_HIDDEN,
	Size = UDim2.fromOffset(M.ROOT_W, M.ROOT_H),
	BackgroundTransparency = 1,
	Visible = false,
})
local meterScale = Instance.new("UIScale")
meterScale.Parent = meter

local header = makeBrick(meter, M.ROOT_W, M.HEADER_H, PANEL, { radius = 18 })
local headerPulse = Instance.new("UIScale")
headerPulse.Parent = header.brick
local multText, multStroke = makeText(header.face, "x1.00", UDim2.new(1, -20, 0.58, 0), UDim2.new(0.5, 0, 0.1, 0), Vector2.new(0.5, 0), 4)
makeText(header.face, "POWER", UDim2.new(1, -20, 0.24, 0), UDim2.new(0.5, 0, 0.9, 0), Vector2.new(0.5, 1), 2, SUBTEXT)

-- Rail sombre (comme la MiniBar).
local track = frame(meter, {
	Name = "Track",
	Position = UDim2.fromOffset(M.TRACK_X, M.TRACK_Y),
	Size = UDim2.fromOffset(M.TRACK_W, M.TRACK_H),
	BackgroundColor3 = Color3.fromRGB(20, 22, 36),
	ZIndex = 1,
})
corner(track)
stroke(track, 3)
studsTexture(track, 10, 0.75)

local inner = frame(track, {
	Name = "Inner",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, -M.INNER * 2, 1, -M.INNER * 2),
	BackgroundTransparency = 1,
	ZIndex = 3,
})

-- Remplissage colore.
local fill = frame(inner, {
	Name = "Fill",
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.fromScale(0, 1),
	Size = UDim2.fromScale(1, 0),
	BackgroundColor3 = RED,
	ZIndex = 4,
	Visible = false,
})
corner(fill)
studsTexture(fill, 8, 0.62)
local fillShine = frame(fill, {
	Position = UDim2.new(0, 6, 0, 8),
	Size = UDim2.new(0, 6, 1, -16),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.55,
	ZIndex = 5,
})
corner(fillShine)

-- Graduations.
local function tick(str: string, v: number, color: Color3)
	local t = makeText(meter, str, UDim2.fromOffset(44, 20), UDim2.fromOffset(M.TRACK_X - 6, M.TRACK_Y + M.INNER + (1 - v) * M.INNER_H), Vector2.new(1, 0.5), 2, color)
	t.TextXAlignment = Enum.TextXAlignment.Right
end
tick("x" .. Shared.MAX_MULT, 1, GOLD)
tick("x1", (1 - Shared.MIN_MULT) / (Shared.MAX_MULT - Shared.MIN_MULT), SUBTEXT)
tick("x" .. Shared.MIN_MULT, 0, SUBTEXT)

-- Curseur.
local pointer = makeBrick(meter, 30, 26, WHITE, { radius = 8, strokeT = 3 })
pointer.brick.AnchorPoint = Vector2.new(0, 0.5)
pointer.brick.ZIndex = 8
local pointerArrow = makeText(pointer.face, "<", UDim2.fromScale(0.8, 0.9), UDim2.fromScale(0.5, 0.55), Vector2.new(0.5, 0.5), 0, INK)
pointerArrow.ZIndex = 8

--== PERFECT! ==--
local perfectHolder = frame(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.42),
	Size = UDim2.fromOffset(350, 96),
	BackgroundTransparency = 1,
	Visible = false,
})
local perfectScale = Instance.new("UIScale")
perfectScale.Parent = perfectHolder
local perfectBrick = makeBrick(perfectHolder, 350, 84, GOLD, { studs = 8, studSize = 20, depth = 10, radius = 20, pattern = true })
perfectBrick.brick.Position = UDim2.fromOffset(0, 12)
makeText(perfectBrick.face, "PERFECT!", UDim2.new(1, -40, 0.8, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 4)

--== Carte d'atterrissage ==--
local zoneHolder = frame(gui, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, M.ZONE_Y),
	Size = UDim2.fromOffset(470, 176),
	BackgroundTransparency = 1,
	Visible = false,
})
local zoneScale = Instance.new("UIScale")
zoneScale.Parent = zoneHolder
local zoneBrick = makeBrick(zoneHolder, 440, 98, GREEN, { studs = 10, studSize = 18, depth = 10, radius = 22, pattern = true, patternSize = 14, patternGap = 12 })
zoneBrick.brick.Position = UDim2.fromOffset(15, 14)
local zoneLabel, zoneLabelStroke = makeText(zoneBrick.face, "FARM!", UDim2.new(1, -40, 0.82, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 5)
local distChip = makeBrick(zoneHolder, 240, 58, PANEL_DARK, { studs = 5, studSize = 14, depth = 7, radius = 16 })
distChip.brick.AnchorPoint = Vector2.new(0.5, 0)
distChip.brick.Position = UDim2.new(0.5, 0, 0, 14 + 98 + 4)
local distLabel = makeText(distChip.face, "0 studs", UDim2.new(1, -28, 0.76, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 3)
local multBadge = makeBrick(zoneHolder, 104, 46, ORANGE, { studs = 3, studSize = 12, depth = 6, radius = 14 })
multBadge.brick.AnchorPoint = Vector2.new(0.5, 0.5)
multBadge.brick.Position = UDim2.fromOffset(440, 18)
multBadge.brick.Rotation = 10
local badgeScale = Instance.new("UIScale")
badgeScale.Parent = multBadge.brick
local badgeText = makeText(multBadge.face, "x1.00", UDim2.new(1, -16, 0.78, 0), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5), 3)

--== Bandeau "YOU'RE THE NOOB!" ==--
local banner = frame(gui, {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = M.BANNER_HIDDEN,
	Size = UDim2.fromOffset(560, 100),
	BackgroundTransparency = 1,
	Visible = false,
})
local bannerScale = Instance.new("UIScale")
bannerScale.Scale = 0.65
bannerScale.Parent = banner
local bannerBrick = makeBrick(banner, 560, 88, Shared.NOOB_BLUE, { studs = 10, studSize = 16, depth = 9, radius = 20, pattern = true })
bannerBrick.brick.Position = UDim2.fromOffset(0, 12)
local bannerIcon = noobIcon(bannerBrick.face, 54)
bannerIcon.AnchorPoint = Vector2.new(0, 0.5)
bannerIcon.Position = UDim2.new(0, 16, 0.5, 2)
local bannerTitle = makeText(bannerBrick.face, "YOU'RE THE NOOB!", UDim2.new(1, -100, 0.52, 0), UDim2.new(0, 84, 0.08, 0), nil, 3, Shared.NOOB_YELLOW)
bannerTitle.TextXAlignment = Enum.TextXAlignment.Left
local bannerSub = makeText(bannerBrick.face, "Grab a brainrot and run back to the SAFE ZONE", UDim2.new(1, -104, 0.3, 0), UDim2.new(0, 86, 0.9, 0), Vector2.new(0, 1), 2)
bannerSub.TextXAlignment = Enum.TextXAlignment.Left

--== Flash ecran ==--
local flashFrame = frame(gui, {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 1,
	ZIndex = 50,
	Active = false,
})

--==================================================================
--== Logique UI ==--
--==================================================================
local function updateMeter(v: number)
	v = math.clamp(v, 0, 1)
	local c = colorForV(v)
	fill.Size = UDim2.fromScale(1, v)
	fill.Visible = v > 0.02
	fill.BackgroundColor3 = c
	pointer.brick.Position = UDim2.fromOffset(M.TRACK_X + M.TRACK_W + 4, M.TRACK_Y + M.INNER + (1 - v) * M.INNER_H)
	setBrickColor(pointer, c)

	local mult = Shared.MultFromPower(v)
	local perfect = mult >= Shared.PERFECT_MULT
	multText.Text = ("x%.2f"):format(mult)
	multText.TextColor3 = WHITE
	multStroke.Color = perfect and shade(GOLD, 0.3) or INK
	setBrickColor(header, perfect and GOLD or PANEL)
	header.stroke.Color = perfect and GOLD or INK
	headerPulse.Scale = perfect and 1 + math.sin(os.clock() * 30) * 0.03 or 1
end

local meterShown = false
local function showMeter()
	meterShown = true
	meter.Visible = true
	meter.Position = M.METER_HIDDEN
	meterScale.Scale = 0.8
	TweenService:Create(meter, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = M.METER_SHOWN }):Play()
	TweenService:Create(meterScale, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function hideMeter()
	if not meterShown then
		return
	end
	meterShown = false
	local tw = TweenService:Create(meter, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = M.METER_HIDDEN })
	tw:Play()
	tw.Completed:Once(function()
		if not meterShown then
			meter.Visible = false
		end
	end)
end

local function flash(alpha: number, color: Color3?)
	flashFrame.BackgroundColor3 = color or WHITE
	flashFrame.BackgroundTransparency = 1 - alpha
	TweenService:Create(flashFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
end

local perfectToken = 0
local function popPerfect()
	perfectToken += 1
	local token = perfectToken
	perfectHolder.Visible = true
	perfectHolder.Position = UDim2.fromScale(0.5, 0.42)
	perfectHolder.Rotation = -14
	perfectScale.Scale = 2.3
	TweenService:Create(perfectScale, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(perfectHolder, TweenInfo.new(0.38, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 4 }):Play()
	task.delay(0.95, function()
		if token ~= perfectToken then
			return
		end
		TweenService:Create(perfectHolder, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 0.34) }):Play()
		local tw = TweenService:Create(perfectScale, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 })
		tw:Play()
		tw.Completed:Once(function()
			if token == perfectToken then
				perfectHolder.Visible = false
			end
		end)
	end)
end

local zoneToken = 0
local function showZone(zoneText: string, color: Color3, dist: number, mult: number)
	do
		local h, sat = color:ToHSV()
		color = Color3.fromHSV(h, math.max(sat, 0.85), 1)
	end
	zoneToken += 1
	local token = zoneToken
	zoneLabel.Text = zoneText .. "!"
	zoneLabelStroke.Color = shade(color, 0.3)
	setBrickColor(zoneBrick, color)
	badgeText.Text = ("x%.2f"):format(mult)
	setBrickColor(multBadge, mult >= Shared.PERFECT_MULT and GOLD or ORANGE)
	distLabel.Text = "0 studs"

	zoneHolder.Visible = true
	zoneHolder.Position = UDim2.new(0.5, 0, M.ZONE_Y, -90)
	zoneHolder.Rotation = -8
	zoneScale.Scale = 0.4
	badgeScale.Scale = 0
	TweenService:Create(zoneScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 0.8 }):Play()
	TweenService:Create(zoneHolder, TweenInfo.new(0.6, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
		Position = UDim2.fromScale(0.5, M.ZONE_Y),
		Rotation = 0,
	}):Play()
	task.delay(0.35, function()
		if token == zoneToken then
			TweenService:Create(badgeScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)

	task.spawn(function()
		local t0 = os.clock()
		while token == zoneToken do
			local a = math.min((os.clock() - t0) / 0.8, 1)
			distLabel.Text = ("%d studs"):format(math.floor(dist * (1 - (1 - a) ^ 3) + 0.5))
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)

	task.delay(2.5, function()
		if token ~= zoneToken then
			return
		end
		TweenService:Create(zoneHolder, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, M.ZONE_Y, -60),
		}):Play()
		local tw = TweenService:Create(zoneScale, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Scale = 0 })
		tw:Play()
		tw.Completed:Once(function()
			if token == zoneToken then
				zoneHolder.Visible = false
			end
		end)
	end)
end

local bannerShown = false
local function setBannerShown(show: boolean)
	if show == bannerShown then
		return
	end
	bannerShown = show
	if show then
		banner.Visible = true
		TweenService:Create(banner, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = M.BANNER_SHOWN }):Play()
	else
		local tw = TweenService:Create(banner, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.In), { Position = M.BANNER_HIDDEN })
		tw:Play()
		tw.Completed:Once(function()
			if not bannerShown then
				banner.Visible = false
			end
		end)
	end
end

--==================================================================
--== VFX ==--
--==================================================================
local function fxPart(size: Vector3, color: Color3, material, cf: CFrame, shape)
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = fxFolder
	return p
end

local function playSoundAt(pos: Vector3, id: string, volume: number, speed: number?)
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = Workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed or 1
	s.RollOffMaxDistance = 300
	s.Parent = att
	s:Play()
	Debris:AddItem(att, 3)
end

local function emitAt(pos: Vector3, cfg, count: number)
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = Workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = cfg.texture
	e.Color = ColorSequence.new(cfg.color or WHITE)
	e.Size = cfg.size
	e.Transparency = cfg.transparency or NumberSequence.new(0.15, 1)
	e.Lifetime = cfg.lifetime
	e.Speed = cfg.speed
	e.SpreadAngle = cfg.spread or Vector2.new(180, 180)
	e.Acceleration = cfg.accel or Vector3.zero
	e.Drag = cfg.drag or 0
	e.LightEmission = cfg.light or 0
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-140, 140)
	e.Rate = 0
	e.Parent = att
	e:Emit(count)
	Debris:AddItem(att, cfg.lifetime.Max + 0.3)
end

local function smokePuff(pos: Vector3, color: Color3, count: number, size: number)
	emitAt(pos, {
		texture = SMOKE,
		color = color,
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.5), NumberSequenceKeypoint.new(1, size * 1.6) }),
		transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
		lifetime = NumberRange.new(0.5, 0.9),
		speed = NumberRange.new(6, 14),
		drag = 5,
		accel = Vector3.new(0, 4, 0),
	}, count)
end

local function sparkles(pos: Vector3, color: Color3, count: number, speed: number?)
	emitAt(pos, {
		texture = SPARK,
		color = color,
		size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0) }),
		lifetime = NumberRange.new(0.4, 0.8),
		speed = NumberRange.new((speed or 16) * 0.5, speed or 16),
		drag = 3,
		light = 1,
	}, count)
end

-- Anneau d'onde de choc (cylindre plat, axe = X local du cf).
local function shockRing(cf: CFrame, color: Color3, from: number, to: number, dur: number, thick: number?)
	local th = thick or 0.3
	local ring = fxPart(Vector3.new(th, from, from), color, Enum.Material.Neon, cf, Enum.PartType.Cylinder)
	ring.Transparency = 0.15
	TweenService:Create(ring, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(th * 0.4, to, to),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, dur + 0.05)
end

local function groundRing(pos: Vector3, color: Color3, from: number, to: number, dur: number)
	shockRing(CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, from, to, dur, 0.25)
end

-- Briques studs qui volent.
local function chunks(pos: Vector3, colors, n: number, spd: number, up: number)
	local rng = Random.new()
	for i = 1, n do
		local s = rng:NextNumber(0.6, 1.3)
		local c = fxPart(Vector3.one * s, colors[(i - 1) % #colors + 1], Enum.Material.Plastic,
			CFrame.new(pos + Vector3.new(0, 1, 0)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0))
		c.MaterialVariant = "Studs"
		c.Anchored = false
		local ang = rng:NextNumber(0, math.pi * 2)
		c.AssemblyLinearVelocity = Vector3.new(math.cos(ang), 0, math.sin(ang)) * rng:NextNumber(spd * 0.5, spd)
			+ Vector3.new(0, rng:NextNumber(up * 0.6, up), 0)
		c.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
		task.delay(0.7, function()
			if c.Parent then
				TweenService:Create(c, TweenInfo.new(0.35), { Size = Vector3.one * 0.05, Transparency = 1 }):Play()
			end
		end)
		Debris:AddItem(c, 1.1)
	end
end

-- Petite brique laissee derriere le noob en vol.
local function studDrop(pos: Vector3, color: Color3)
	local rng = Random.new()
	local p = fxPart(Vector3.one * rng:NextNumber(0.6, 1), color, Enum.Material.Plastic,
		CFrame.new(pos + rng:NextUnitVector() * 0.8) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0))
	p.MaterialVariant = "Studs"
	TweenService:Create(p, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.one * 0.08,
		Transparency = 1,
		CFrame = p.CFrame * CFrame.new(0, -1.5, 0),
	}):Play()
	Debris:AddItem(p, 0.6)
end

local NOOB_COLORS = { Shared.NOOB_YELLOW, Shared.NOOB_BLUE, Shared.NOOB_GREEN }

local function poofNoob(pos: Vector3)
	smokePuff(pos, WHITE, 12, 2.2)
	sparkles(pos, Shared.NOOB_YELLOW, 12, 14)
	chunks(pos - Vector3.new(0, 2, 0), NOOB_COLORS, 6, 12, 18)
end

local function landingFx(land: Vector3, color: Color3, splash: boolean)
	groundRing(land, color, 4, 34, 0.6)
	task.delay(0.07, function()
		groundRing(land, WHITE, 3, 22, 0.45)
	end)
	smokePuff(land + Vector3.new(0, 1, 0), splash and Color3.fromRGB(190, 225, 255) or color:Lerp(WHITE, 0.55), 22, 3.2)
	sparkles(land + Vector3.new(0, 2, 0), color:Lerp(WHITE, 0.3), 18, 22)
	chunks(land, { color, WHITE, shade(color, 0.7) }, 16, 30, 40)
	playSoundAt(land, "rbxasset://sounds/collide.wav", 1.2, 0.85)
	if splash then
		playSoundAt(land, "rbxasset://sounds/impact_water.mp3", 1)
	end
end

local function restoreCamera()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		Workspace.CurrentCamera.CameraSubject = humanoid
	end
end

local function cameraShake(duration: number, strength: number)
	local name = "YeetShake"
	local t0 = os.clock()
	pcall(function()
		RunService:UnbindFromRenderStep(name)
	end)
	RunService:BindToRenderStep(name, Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - t0
		if t >= duration then
			RunService:UnbindFromRenderStep(name)
			return
		end
		local k = strength * (1 - t / duration) ^ 2
		local cam = Workspace.CurrentCamera
		cam.CFrame = cam.CFrame * CFrame.new(math.random() * k - k / 2, math.random() * k - k / 2, 0)
			* CFrame.Angles(0, 0, (math.random() - 0.5) * k * 0.03)
	end)
end

local baseFov = nil
local function getBaseFov(): number
	baseFov = baseFov or Workspace.CurrentCamera.FieldOfView
	return baseFov
end
local function fovPunch(add: number, dur: number)
	local cam = Workspace.CurrentCamera
	local base = getBaseFov()
	cam.FieldOfView = base + add
	TweenService:Create(cam, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base }):Play()
end

--==================================================================
--== Noob (parties placees a la main pour pouvoir le faire gigoter) ==--
--==================================================================
local LIMBS = {
	LeftArm = { pivot = Vector3.new(-1.5, 0.9, 0), off = Vector3.new(0, 0.5, 0), phase = 0, arm = true, side = -1 },
	RightArm = { pivot = Vector3.new(1.5, 0.9, 0), off = Vector3.new(0, 0.5, 0), phase = math.pi, arm = true, side = 1 },
	LeftLeg = { pivot = Vector3.new(-0.5, -1, 0), off = Vector3.new(0, -1, 0), phase = math.pi, side = -1 },
	RightLeg = { pivot = Vector3.new(0.5, -1, 0), off = Vector3.new(0, -1, 0), phase = 0, side = 1 },
}

local function makeNoob()
	local model = Shared.BuildNoob()
	local d = { model = model, list = {}, base = {}, cframes = {}, scale = 1 }
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") then
			table.insert(d.list, part)
			d.base[part] = part.Size
		end
	end
	d.torso = model.PrimaryPart
	model.Parent = fxFolder
	return d
end

local function setNoob(d, cf: CFrame, flail: number, scale: number, t: number)
	if math.abs(d.scale - scale) > 1e-3 then
		d.scale = scale
		for part, size in pairs(d.base) do
			part.Size = size * scale
		end
	end
	local s = d.scale
	local cfs = d.cframes
	table.clear(cfs)
	for i, part in ipairs(d.list) do
		local name = part.Name
		local c = cf
		if name == "Head" then
			c = cf * CFrame.new(0, 1.65 * s, 0) * CFrame.Angles(math.sin(t * 7) * 0.12 * flail, 0, math.sin(t * 11) * 0.15 * flail)
		else
			local L = LIMBS[name]
			if L then
				local w = math.sin(t * (L.arm and 17 or 13) + L.phase) * flail
				local rot
				if L.arm then
					rot = CFrame.Angles(w * 0.55, 0, -L.side * (0.25 + math.abs(w) * 0.35))
				else
					rot = CFrame.Angles(w * 0.7, 0, -L.side * math.abs(w) * 0.15)
				end
				c = cf * CFrame.new(L.pivot * s) * rot * CFrame.new(L.off * s)
			end
		end
		cfs[i] = c
	end
	Workspace:BulkMoveTo(d.list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
end

--==================================================================
--== Poses du lanceur ==--
--==================================================================
local K = {}
K.HOLD = Shared.HOLD_OFFSET
K.HOLD_ROT = CFrame.Angles(-math.pi / 2, 0, 0) -- allonge, tete vers l'avant
K.STAND = Vector3.new(0, 0, 2.8) -- noob debout derriere le joueur
K.GRAB_POS = Vector3.new(0, 0, -2.8) -- meme point vu depuis le corps retourne
K.LIFT_CTRL = Vector3.new(0, 4, -2.2)
K.ARM_RAISED = math.pi * 1.1
K.ARM_REACH = 1.2
K.ARM_FORWARD = 0.8
K.WIND_ARM = K.ARM_RAISED + 0.55
K.WIND_LEAN = 0.55
K.WIND_OFFSET = Vector3.new(0, -0.7, 1.9)
K.SWING, K.RECOVER = 0.14, 0.45
K.FACE_BACK = CFrame.Angles(0, math.pi, 0)

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end
local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end
local function smooth(x: number): number
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end
local function easeOut(x: number): number
	x = clamp01(x)
	return 1 - (1 - x) ^ 3
end
local function easeOutBack(x: number): number
	x = clamp01(x)
	local c1 = 1.9
	return 1 + (c1 + 1) * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end
local function bezier(a: Vector3, b: Vector3, c: Vector3, t: number): Vector3
	return a:Lerp(b, t):Lerp(b:Lerp(c, t), t)
end

local function chargeValue(rec, t: number): number
	if rec.frozenV then
		return rec.frozenV
	end
	return Shared.MeterValue(math.max(0, t - rec.chargeStart))
end

-- Pose a l'instant t : bras, buste, rotation du corps, noob (repere du RootPart).
local function computePose(rec, t: number)
	local p = { arm = 0, lean = 0, yaw = 0, offset = K.HOLD, rot = K.HOLD_ROT, flail = 0.5, scale = 1 }

	-- 3. TIR
	if rec.startTime and t >= rec.windStart then
		if t < rec.startTime then
			local from = rec.from
			local e = easeOut((t - rec.windStart) / math.max(rec.startTime - rec.windStart, 0.01))
			p.arm = lerp(from.arm, K.WIND_ARM, e)
			p.lean = lerp(from.lean, K.WIND_LEAN, e)
			p.yaw = lerp(from.yaw, 0, e)
			p.offset = from.offset:Lerp(K.HOLD + K.WIND_OFFSET, e)
			p.rot = from.rot:Lerp(K.HOLD_ROT * CFrame.Angles(0.45, 0, 0), e)
			p.flail = 1.4
		else
			local s = t - rec.startTime
			if s < K.SWING then
				local e = (s / K.SWING) ^ 2
				p.arm = lerp(K.WIND_ARM, K.ARM_FORWARD, e)
				p.lean = lerp(K.WIND_LEAN, -0.5, e)
			else
				local e = smooth((s - K.SWING) / K.RECOVER)
				p.arm = K.ARM_FORWARD * (1 - e)
				p.lean = -0.5 * (1 - e)
			end
			p.offset = K.HOLD + K.WIND_OFFSET
		end
		return p
	end

	-- 1. PRISE
	local k = (t - rec.t0) / PICKUP
	if k < 1 then
		if k < 0.5 then
			-- Le noob "pop" derriere ; le joueur jette un oeil puis se retourne.
			p.scale = math.max(0.05, easeOutBack(k / 0.22))
			local hop = math.sin(clamp01(k / 0.32) * math.pi) * 1.3
			p.offset = K.STAND + Vector3.new(0, -3 + 3 * p.scale + hop, 0)
			p.rot = K.FACE_BACK
			p.flail = 0.35
			if k < 0.22 then
				p.yaw = lerp(0, 0.35, smooth(k / 0.22))
			else
				local e = smooth((k - 0.22) / 0.28)
				p.yaw = lerp(0.35, math.pi, e)
				p.arm = lerp(0, K.ARM_REACH, e)
				p.lean = lerp(0, -0.45, e)
			end
		elseif k < 0.56 then
			-- Attrape !
			p.yaw = math.pi
			p.arm = K.ARM_REACH
			p.lean = -0.45
			p.offset = K.STAND + Vector3.new(0, math.sin((k - 0.5) / 0.06 * math.pi) * 0.35, 0)
			p.rot = K.FACE_BACK
			p.flail = 1.2
		else
			-- Souleve au-dessus de la tete en se retournant vers le champ.
			local e = smooth((k - 0.56) / 0.44)
			p.yaw = math.pi * (1 - e)
			p.arm = lerp(K.ARM_REACH, K.ARM_RAISED, e)
			p.lean = lerp(-0.45, 0.15, e)
			local yawCF = CFrame.Angles(0, p.yaw, 0)
			p.offset = yawCF * bezier(K.GRAB_POS, K.LIFT_CTRL, K.HOLD, e)
			p.rot = yawCF * CFrame.new():Lerp(K.HOLD_ROT, e)
			p.flail = 1.3
		end
		return p
	end

	-- 2. CHARGE
	local v = chargeValue(rec, t)
	local shake = v * v * 0.14
	p.arm = K.ARM_RAISED + 0.35 * v + math.sin(t * 6) * 0.04
	p.lean = 0.15 + 0.35 * v
	p.offset = K.HOLD + Vector3.new(math.sin(t * 37) * shake, -0.3 * v + math.sin(t * 4) * 0.08, 1.0 * v + math.cos(t * 41) * shake)
	p.rot = K.HOLD_ROT * CFrame.Angles(0.15 * v, 0, math.sin(t * 3) * 0.08)
	p.flail = 0.8 + v
	return p
end

local function findJoints(character: Model)
	local function get(parentName: string, jointName: string)
		local holder = character:FindFirstChild(parentName)
		local j = holder and holder:FindFirstChild(jointName)
		if j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) then
			return j
		end
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local J = { r15 = humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R15 }
	if J.r15 then
		J.rs = get("RightUpperArm", "RightShoulder")
		J.ls = get("LeftUpperArm", "LeftShoulder")
		J.waist = get("UpperTorso", "Waist")
		J.root = get("LowerTorso", "Root")
	else
		J.rs = get("Torso", "Right Shoulder")
		J.ls = get("Torso", "Left Shoulder")
		J.root = get("HumanoidRootPart", "RootJoint")
	end
	return J
end

local function applyJoint(joint, cf: CFrame)
	if joint and joint.Parent then
		joint.Transform = cf * joint.Transform
	end
end

local function applyPose(J, p)
	if J.r15 then
		local arms = CFrame.Angles(p.arm, 0, 0)
		applyJoint(J.rs, arms)
		applyJoint(J.ls, arms)
		applyJoint(J.waist, CFrame.Angles(p.lean, 0, 0))
		applyJoint(J.root, CFrame.Angles(0, p.yaw, 0))
	else
		applyJoint(J.rs, CFrame.Angles(0, 0, p.arm))
		applyJoint(J.ls, CFrame.Angles(0, 0, -p.arm))
		applyJoint(J.root, CFrame.Angles(-p.lean * 0.6, 0, p.yaw))
	end
end

--==================================================================
--== Lanceurs (tous les joueurs) ==--
--==================================================================
local recs = {} -- [thrower] = prise / charge / tir en cours
local flights = {} -- [thrower] = noob en vol

local function floorBelow(root: BasePart, character: Model): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, fxFolder }
	local r = Workspace:Raycast(root.Position, Vector3.new(0, -15, 0), params)
	return r and r.Position.Y or root.Position.Y - 3
end

local function destroyRec(thrower: Player, poof: boolean?)
	local rec = recs[thrower]
	if not rec then
		return
	end
	recs[thrower] = nil
	if rec.pad then
		rec.pad:Destroy()
	end
	if rec.noob then
		if poof and rec.noob.torso.Parent then
			poofNoob(rec.noob.torso.Position)
		end
		rec.noob.model:Destroy()
	end
end

local function createRec(thrower: Player, t0: number)
	local character = thrower.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	destroyRec(thrower)
	local rec = {
		character = character,
		root = root,
		joints = findJoints(character),
		t0 = t0,
		chargeStart = t0 + PICKUP,
	}
	rec.noob = makeNoob()

	-- Aura (etincelles) accrochee au noob.
	local att = Instance.new("Attachment")
	att.Parent = rec.noob.torso
	local aura = Instance.new("ParticleEmitter")
	aura.Texture = SPARK
	aura.LightEmission = 1
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	aura.Transparency = NumberSequence.new(0.1, 1)
	aura.Lifetime = NumberRange.new(0.35, 0.7)
	aura.Speed = NumberRange.new(2, 6)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.RotSpeed = NumberRange.new(-200, 200)
	aura.Rate = 0
	aura.Parent = att
	rec.aura = aura

	-- Disque lumineux au sol (couleur de la barre).
	rec.floorY = floorBelow(root, character)
	rec.pad = fxPart(Vector3.new(0.1, 5, 5), WHITE, Enum.Material.Neon,
		CFrame.new(root.Position.X, rec.floorY + 0.08, root.Position.Z) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
	rec.pad.Transparency = 1

	local t = serverNow()
	local p = computePose(rec, t)
	setNoob(rec.noob, root.CFrame * CFrame.new(p.offset) * p.rot, 0, p.scale, t)
	if t - t0 < PICKUP * 0.3 then
		local standPos = root.CFrame:PointToWorldSpace(K.STAND)
		smokePuff(standPos, WHITE, 10, 2)
		sparkles(standPos, Shared.NOOB_YELLOW, 10, 12)
		groundRing(Vector3.new(standPos.X, rec.floorY, standPos.Z), Shared.NOOB_YELLOW, 1, 9, 0.4)
		playSoundAt(standPos, "rbxasset://sounds/electronicpingshort.wav", 0.5, 1.3)
	end
	recs[thrower] = rec
	return rec
end

local function updateChargeFx(rec, t: number)
	local root = rec.root
	if rec.startTime then
		rec.aura.Rate = 120
		rec.pad.Transparency = 0.2
		return
	end
	if t < rec.chargeStart then
		rec.aura.Rate = 0
		rec.pad.Transparency = 1
		return
	end
	local v = chargeValue(rec, t)
	local c = colorForV(v)
	rec.aura.Color = ColorSequence.new(c)
	rec.aura.Rate = 6 + 70 * v
	local pulse = 0.5 + 0.5 * math.sin(t * (6 + 12 * v))
	local d = 5 + 4 * v + pulse * 0.8
	rec.pad.Size = Vector3.new(0.1, d, d)
	rec.pad.Color = c
	rec.pad.Transparency = 0.55 + 0.25 * pulse
	rec.pad.CFrame = CFrame.new(root.Position.X, rec.floorY + 0.08, root.Position.Z) * CFrame.Angles(0, 0, math.pi / 2)
end

local function endFlight(thrower: Player)
	local fl = flights[thrower]
	if not fl then
		return
	end
	flights[thrower] = nil
	fl.noob.model:Destroy()
	if thrower == player then
		restoreCamera()
	end
end

--== Etat local ==--
local state = "idle" -- "idle" | "pickup" | "charging" | "sent" | "flying"
local actionAt = 0
local confirmed = false
local lastYeet = -math.huge
local lastMult = 1

local function resetLocal(sendCancel: boolean)
	if sendCancel and (state == "pickup" or state == "charging" or state == "sent") then
		YeetEvent:FireServer("Cancel")
	end
	local rec = recs[player]
	if rec and not rec.startTime then
		destroyRec(player, true)
	end
	state = "idle"
	setControls(true)
	hideMeter()
	setButtonMode("yeet")
	Workspace.CurrentCamera.FieldOfView = getBaseFov()
end

-- Le noob quitte les mains : debut du vol.
local function handOff(thrower: Player, rec)
	local d = rec.noob
	rec.noob = nil
	if rec.pad then
		rec.pad:Destroy()
		rec.pad = nil
	end
	local fl = rec.flight
	fl.noob = d
	fl.corr = d.torso.Position - fl.start
	flights[thrower] = fl

	rec.aura.Rate = 45
	rec.aura.Color = ColorSequence.new(fl.perfect and GOLD or WHITE)

	-- Trainee large.
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(-1.3, 0, 0)
	a0.Parent = d.torso
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(1.3, 0, 0)
	a1.Parent = d.torso
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.Color = fl.perfect and ColorSequence.new(GOLD, Color3.fromRGB(255, 120, 40)) or ColorSequence.new(WHITE, Color3.fromRGB(140, 200, 255))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
	trail.LightEmission = fl.perfect and 1 or 0.4
	trail.Parent = d.torso

	local scream = Instance.new("Sound")
	scream.SoundId = "rbxasset://sounds/uuhhh.mp3"
	scream.Volume = 0.9
	scream.RollOffMaxDistance = 250
	scream.Parent = d.torso
	scream:Play()

	-- Onde de choc du lancer.
	local pos = d.torso.Position
	local ringCF = CFrame.lookAt(pos, pos + fl.dir) * CFrame.Angles(0, math.pi / 2, 0)
	local ringColor = fl.perfect and GOLD or WHITE
	shockRing(ringCF, ringColor, 2, 16, 0.35, 0.35)
	task.delay(0.07, function()
		shockRing(ringCF * CFrame.new(-3, 0, 0), ringColor, 1.5, 11, 0.3, 0.25)
	end)
	sparkles(pos, ringColor, fl.perfect and 30 or 16, 26)
	local root = rec.root
	if root and root.Parent then
		local feet = Vector3.new(root.Position.X, rec.floorY or root.Position.Y - 3, root.Position.Z)
		smokePuff(feet + Vector3.new(0, 0.5, 0), Color3.fromRGB(225, 220, 205), 14, 2.4)
		groundRing(feet, ringColor, 3, 18, 0.45)
	end
	playSoundAt(pos, "rbxasset://sounds/swordlunge.wav", 1)
	if fl.perfect then
		playSoundAt(pos, "rbxasset://sounds/electronicpingshort.wav", 0.8, 0.8)
	end

	if thrower == player then
		-- On rend les controles pour pouvoir diriger le noob (le perso reste ancre).
		setControls(true)
		Workspace.CurrentCamera.CameraSubject = d.torso
		fovPunch(14, 0.6)
		cameraShake(0.2, 0.6)
		task.delay(0.35, hideMeter)
	end
end

local function onThrow(thrower: Player, start: Vector3, land: Vector3, duration: number, apex: number, startTime: number, mult: number)
	endFlight(thrower)
	local t = serverNow()
	local rec = recs[thrower]
	if not rec or rec.startTime then
		-- Prise ratee (arrive en cours de partie...) : on part direct de la charge.
		rec = createRec(thrower, t - PICKUP - 0.01)
		if not rec then
			return
		end
	end
	if rec.frozenV == nil then
		rec.frozenV = clamp01((mult - Shared.MIN_MULT) / (Shared.MAX_MULT - Shared.MIN_MULT))
	end
	rec.from = computePose(rec, t)
	rec.windStart = math.max(startTime - WINDUP, math.min(t, startTime - 0.06))
	rec.startTime = startTime

	local target = land + Vector3.new(0, 3, 0)
	local dir = (target - start) * Vector3.new(1, 0, 1)
	rec.flight = {
		start = start,
		offset = serverNow() - os.clock(),
		target = target,
		duration = duration,
		apex = apex,
		startTime = startTime,
		perfect = mult >= Shared.PERFECT_MULT,
		spins = 1.5 + (start - land).Magnitude / 140,
		dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, -1),
		lastDrop = 0,
		dropIndex = 0,
		steer = Vector3.zero, -- decalage controle par le lanceur
		steerVel = 0,
		steerTarget = Vector3.zero, -- (autres joueurs) dernier decalage recu
		lastSteerSend = 0,
		sentSteer = Vector3.zero,
	}
	if rec.noob then
		playSoundAt(rec.noob.torso.Position, "rbxasset://sounds/swordslash.wav", 0.6, 0.7)
	end

	if thrower == player then
		state = "flying"
		lastMult = mult
	end
end

local function onLanded(thrower: Player, land: Vector3, zoneText: string, color: Color3, dist: number)
	endFlight(thrower)
	landingFx(land, color, zoneText == "SPLASH" or zoneText == "WATER")
	if thrower == player then
		restoreCamera()
		resetLocal(false)
		showZone(zoneText, color, dist, lastMult)
		cameraShake(0.45, 1.6)
		flash(0.25, color)
	end
end

--== Poses (tous les lanceurs) apres l'Animator ==--
RunService.PreSimulation:Connect(function()
	local t = serverNow()
	for thrower, rec in pairs(recs) do
		if not rec.character.Parent or (rec.startTime and t > rec.startTime + K.SWING + K.RECOVER) then
			destroyRec(thrower, false)
		else
			applyPose(rec.joints, computePose(rec, t))
		end
	end
end)

--== Controle en vol ==--
local function flatUnit(v: Vector3): Vector3
	v = Vector3.new(v.X, 0, v.Z)
	return v.Magnitude > 1e-3 and v.Unit or Vector3.zero
end

-- -1 = gauche, 1 = droite. Clavier (QWERTY + AZERTY), fleches, manette, puis joystick mobile.
local function steerInput(): number
	local x = 0
	if UserInputService:GetFocusedTextBox() == nil then
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Q)
			or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			x -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			x += 1
		end
	end
	if x == 0 then
		for _, st in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
			if st.KeyCode == Enum.KeyCode.Thumbstick1 and math.abs(st.Position.X) > 0.2 then
				x = st.Position.X
			end
		end
	end
	if x == 0 and controls then
		local ok, mv = pcall(controls.GetMoveVector, controls)
		if ok and typeof(mv) == "Vector3" then
			x = mv.X
		end
	end
	return math.clamp(x, -1, 1)
end

local function updateSteer(thrower: Player, fl, dt: number)
	if thrower ~= player then
		fl.steer = fl.steer:Lerp(fl.steerTarget, 1 - math.exp(-6 * dt))
		return
	end
	-- Gauche / droite uniquement, par rapport a la camera, avec inertie.
	local input = steerInput()
	local right = flatUnit(Workspace.CurrentCamera.CFrame.RightVector)
	local side = (right.X >= 0) and 1 or -1
	local wanted = input * side * Shared.STEER_SPEED
	-- Acceleration douce (plus rapide pour freiner / changer de sens).
	local accel = (math.abs(wanted) > math.abs(fl.steerVel) and wanted * fl.steerVel >= 0) and 5 or 8
	fl.steerVel += (wanted - fl.steerVel) * (1 - math.exp(-accel * dt))
	local x = fl.steer.X + fl.steerVel * dt
	-- Ralentit en douceur pres des bords au lieu de taper le mur.
	local max = Shared.STEER_MAX_X
	if math.abs(x) > max * 0.8 and x * fl.steerVel > 0 then
		local k = 1 - math.clamp((math.abs(x) - max * 0.8) / (max * 0.2), 0, 1)
		fl.steerVel *= k
	end
	x = math.clamp(x, -max, max)
	fl.steer = Vector3.new(x, 0, 0)
	if os.clock() - fl.lastSteerSend >= Shared.STEER_SEND and (fl.steer - fl.sentSteer).Magnitude > 0.05 then
		fl.lastSteerSend = os.clock()
		fl.sentSteer = fl.steer
		YeetEvent:FireServer("Steer", fl.steer)
	end
end

--== Noobs tenus + noobs en vol ==--
-- BindToRenderStep juste AVANT la camera : le noob est deplace avant que la
-- camera lise sa position (sinon elle a une frame de retard = tremblement
-- a haute vitesse).
RunService:BindToRenderStep("YeetNoobUpdate", Enum.RenderPriority.Camera.Value - 1, function(dt: number)
	local t = serverNow()

	for thrower, rec in pairs(recs) do
		local d = rec.noob
		local root = rec.root
		if d and root and root.Parent then
			if rec.startTime and t >= rec.startTime then
				handOff(thrower, rec)
			else
				local p = computePose(rec, t)
				setNoob(d, root.CFrame * CFrame.new(p.offset) * p.rot, p.flail, p.scale, t)
				updateChargeFx(rec, t)
				if not rec.grabbed and (t - rec.t0) / PICKUP >= 0.5 then
					rec.grabbed = true
					sparkles(d.torso.Position, WHITE, 8, 10)
					playSoundAt(d.torso.Position, "rbxasset://sounds/button.wav", 0.7, 0.8)
				end
			end
		end
	end

	for thrower, fl in pairs(flights) do
		local d = fl.noob
		if not d.model.Parent then
			flights[thrower] = nil
			continue
		end
		-- Horloge locale (os.clock + decalage serveur pris au lancer) : le temps
		-- serveur bouge par petits a-coups, a 400 studs/s ca fait trembler le noob.
		local tf = fl.offset and (os.clock() + fl.offset) or t
		local a = clamp01((tf - fl.startTime) / fl.duration)
		local k = smooth((tf - fl.startTime) / 0.15)
		if a < 1 then
			updateSteer(thrower, fl, dt)
		end
		local pos = Shared.FlightPosition(fl.start + fl.corr * (1 - k), fl.target, fl.apex, a) + fl.steer
		-- Leger penche du noob dans le sens du deplacement.
		fl.bank = (fl.bank or 0) + ((fl.steerVel or 0) / Shared.STEER_SPEED * -0.5 - (fl.bank or 0)) * (1 - math.exp(-6 * dt))
		local rot = CFrame.lookAt(Vector3.zero, fl.dir) * CFrame.Angles(0, 0, fl.bank)
			* CFrame.Angles(-math.pi / 2 - a * fl.spins * math.pi * 2, 0, 0)
		setNoob(d, CFrame.new(pos) * rot, a < 1 and 1.5 or 0.3, 1, t)

		if a < 1 and os.clock() - fl.lastDrop > 0.045 then
			fl.lastDrop = os.clock()
			fl.dropIndex += 1
			studDrop(pos, fl.perfect and (fl.dropIndex % 2 == 0 and GOLD or YELLOW) or NOOB_COLORS[fl.dropIndex % 3 + 1])
		end
		if a >= 1 and not fl.arrived then
			fl.arrived = true
			-- Securite si "Landed" n'arrive jamais (mort, deco).
			task.delay(1.5, function()
				if flights[thrower] == fl then
					endFlight(thrower)
					if thrower == player and state == "flying" then
						resetLocal(false)
					end
				end
			end)
		end
	end
end)

--==================================================================
--== Joueur local : entrees ==--
--==================================================================
local function getRoot()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and root and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function canStand(): boolean
	local root = getRoot()
	if not root then
		return false
	end
	if player:GetAttribute("CarryingBrainrot") or player:GetAttribute("IsNoob") or player:GetAttribute("Yeeting") then
		return false
	end
	return Shared.IsOnYeetLine(Shared.GetSafeZone(), root.Position, 0)
end

local function eligible(): boolean
	return os.clock() - lastYeet >= Shared.COOLDOWN and canStand()
end

local function beginGrab()
	local root = getRoot()
	if not root then
		return
	end
	setControls(false)
	root.Parent:PivotTo(CFrame.lookAt(root.Position, root.Position + Vector3.new(0, 0, -1)))
	if not createRec(player, serverNow()) then
		setControls(true)
		return
	end
	state = "pickup"
	actionAt = os.clock()
	confirmed = false
	YeetEvent:FireServer("Charge")
	updateMeter(0)
	showMeter()
	setButtonMode("grab")
	playUI("Popup")
end

local function release()
	local rec = recs[player]
	if not rec then
		resetLocal(true)
		return
	end
	local v = chargeValue(rec, serverNow())
	rec.frozenV = v
	state = "sent"
	actionAt = os.clock()
	lastYeet = os.clock()
	updateMeter(v)
	YeetEvent:FireServer("Yeet", v)
	if Shared.MultFromPower(v) >= Shared.PERFECT_MULT then
		popPerfect()
		flash(0.45, GOLD)
		playUI("Buy")
	end
end

local function onActivate()
	if state == "idle" and eligible() then
		beginGrab()
	elseif state == "charging" then
		release()
	end
end

button.Activated:Connect(onActivate)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX then
		onActivate()
	end
end)

RunService.RenderStepped:Connect(function()
	local t = serverNow()
	if state == "pickup" or state == "charging" then
		local rec = recs[player]
		if not rec or not canStand() or (not confirmed and os.clock() - actionAt > SEND_TIMEOUT) then
			resetLocal(true)
		else
			if state == "pickup" and t >= rec.chargeStart then
				state = "charging"
				setButtonMode("throw")
				playUI("Popup")
			end
			if state == "charging" then
				local v = chargeValue(rec, t)
				updateMeter(v)
				Workspace.CurrentCamera.FieldOfView = getBaseFov() - 6 * v
			end
		end
	elseif state == "sent" then
		if os.clock() - actionAt > SEND_TIMEOUT and not player:GetAttribute("Yeeting") then
			resetLocal(true)
		end
	end

	local show = (state == "idle" and eligible()) or state == "pickup" or state == "charging"
	setButtonShown(show)
	if show then
		local speed = state == "charging" and 14 or 4
		btnPulse.Scale = 1 + math.sin(os.clock() * speed) * (state == "charging" and 0.045 or 0.025)
		btnIcon.Rotation = -8 + math.sin(os.clock() * speed * 0.8) * (state == "idle" and 6 or 12)
	end

	setBannerShown(player:GetAttribute("IsNoob") == true and not player:GetAttribute("CarryingBrainrot"))
	if bannerShown then
		bannerIcon.Rotation = math.sin(os.clock() * 3) * 8
	end
end)

--== Evenements serveur ==--
YeetEvent.OnClientEvent:Connect(function(action: string, thrower: Player, ...)
	if action == "Charge" then
		local t0 = ...
		if thrower == player then
			confirmed = true
		else
			createRec(thrower, t0)
		end
	elseif action == "Cancel" then
		if thrower ~= player then
			destroyRec(thrower, true)
		end
	elseif action == "Steer" then
		local fl = flights[thrower] or (recs[thrower] and recs[thrower].flight)
		if fl then
			fl.steerTarget = ...
		end
	elseif action == "Throw" then
		onThrow(thrower, ...)
	elseif action == "Landed" then
		onLanded(thrower, ...)
	elseif action == "Unnoob" then
		local pos = ...
		local ground = pos - Vector3.new(0, 2.5, 0)
		groundRing(ground, Shared.NOOB_YELLOW, 2, 16, 0.5)
		smokePuff(pos, WHITE, 14, 2.4)
		sparkles(pos, Shared.NOOB_YELLOW, 16, 16)
		chunks(ground, NOOB_COLORS, 8, 14, 22)
	end
end)

player.CharacterAdded:Connect(function()
	endFlight(player)
	destroyRec(player)
	resetLocal(true)
end)

Players.PlayerRemoving:Connect(function(p)
	endFlight(p)
	destroyRec(p)
end)

--== Murs invisibles entre les zones ==--
-- Crees LOCALEMENT : le client possede la physique de son perso, donc un
-- mur local le bloque lui sans gener les autres joueurs.
do
local WALL_HEIGHT = 140
local walls = {}
task.spawn(function()
	local zs
	for _ = 1, 60 do
		zs = Shared.GetWallZs()
		-- Les Z viennent de l'attribut serveur (tout de suite dispo) : on attend
		-- aussi que la SAFE ZONE soit streamee avant de poser les murs.
		if #zs >= #Shared.ZONE_MODELS and Shared.GetSafeZone() then
			break
		end
		task.wait(0.5)
	end
	local safe = Shared.GetSafeZone()
	if not safe then
		return
	end
	local wallFolder = Instance.new("Folder")
	wallFolder.Name = "YeetWallsLocal"
	wallFolder.Parent = Workspace
	local baseY = safe.Position.Y + safe.Size.Y / 2
	for i, z in ipairs(zs) do
		local w = Instance.new("Part")
		w.Name = "ZoneWall" .. i
		w.Size = Vector3.new(safe.Size.X, WALL_HEIGHT, Shared.WALL_THICKNESS)
		w.CFrame = CFrame.new(safe.Position.X, baseY - 10 + WALL_HEIGHT / 2, z)
		w.Anchored = true
		w.Transparency = 1
		w.CanCollide = true
		w.CanQuery = false
		w.CanTouch = false
		w.CastShadow = false
		w:SetAttribute("WallZ", z)
		w.Parent = wallFolder
		table.insert(walls, w)
	end
end)

local function updateWalls()
	local isNoob = player:GetAttribute("IsNoob") == true
	local limit = player:GetAttribute("YeetLimitZ")
	for _, w in ipairs(walls) do
		local open = isNoob and typeof(limit) == "number" and w:GetAttribute("WallZ") > limit
		w.CanCollide = not open
	end
end
player:GetAttributeChangedSignal("IsNoob"):Connect(updateWalls)
player:GetAttributeChangedSignal("YeetLimitZ"):Connect(updateWalls)

--== Brainrots : attrapables uniquement en noob ==--
local PROMPT_NAME = "BrainrotTakePrompt"
task.spawn(function()
	local folder = Workspace:WaitForChild("SpawnedBrainrots", 30)
	if not folder then
		return
	end
	while true do
		updateWalls()
		local isNoob = player:GetAttribute("IsNoob") == true
		local limitZ = player:GetAttribute("YeetLimitZ")
		for _, part in ipairs(folder:GetChildren()) do
			local prompt = part:FindFirstChild(PROMPT_NAME)
			if prompt and prompt:IsA("ProximityPrompt") then
				local want = isNoob and not part:GetAttribute("Despawning") and not part:GetAttribute("_taken")
					and not (typeof(limitZ) == "number" and part.Position.Z < limitZ)
				if prompt.Enabled ~= want then
					prompt.Enabled = want
				end
			end
		end
		task.wait(0.2)
	end
end)

end
