--[[
	UIKit
	-----
	ModuleScript partage (ReplicatedStorage) : briques d'UI + animations +
	support telephone / console, utilisees par la Trait Machine, le panneau
	admin et les podiums.

	- Helpers de construction : corner, stroke, gradient, text, padding...
	- Animations : tween, pressable (survol / clic / selection manette),
	  shine (reflet qui balaie), pop, shake, countUp, burst (confettis UI).
	- Plateforme : IsGamepad / IsTouch, fitScale (adapte la fenetre a
	  l'ecran, telephone compris).
	- Fenetres : PushModal / PopModal. Sur manette, la fenetre du dessus se
	  ferme avec B et le premier bouton est selectionne automatiquement.
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local UIKit = {}

UIKit.FONT_TITLE = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
UIKit.FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
UIKit.ROBUX = utf8.char(0xE002)
-- Meme texture studs que les autres UIs du jeu (shop, rebirth, spin...).
UIKit.STUDS = "rbxassetid://10509831729"

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

UIKit.C = {
	white = WHITE,
	black = BLACK,
	ink = Color3.fromRGB(14, 10, 22),
	panel = Color3.fromRGB(24, 20, 34),
	panel2 = Color3.fromRGB(36, 30, 50),
	gold = Color3.fromRGB(255, 205, 40),
	goldD = Color3.fromRGB(230, 140, 0),
	green = Color3.fromRGB(70, 230, 70),
	greenD = Color3.fromRGB(25, 160, 45),
	red = Color3.fromRGB(240, 60, 70),
	redD = Color3.fromRGB(170, 20, 35),
	purple = Color3.fromRGB(180, 80, 255),
	purpleD = Color3.fromRGB(110, 30, 200),
	blue = Color3.fromRGB(60, 170, 255),
	blueD = Color3.fromRGB(20, 90, 210),
	grey = Color3.fromRGB(190, 190, 200),
}

UIKit.RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 30)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(70, 240, 90)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(40, 180, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(190, 70, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 60, 60)),
})

--== Construction ==--

function UIKit.new(className: string, props: { [string]: any }?, parent: Instance?)
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			inst[k] = v
		end
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UIKit.corner(p: Instance, r: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 10)
	c.Parent = p
	return c
end

function UIKit.round(p: Instance)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = p
	return c
end

function UIKit.stroke(p: Instance, t: number?, color: Color3?, contextual: boolean?)
	local s = Instance.new("UIStroke")
	s.Thickness = t or 3
	s.Color = color or BLACK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = contextual and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

function UIKit.gradient(p: Instance, a: any, b: Color3?, rot: number?)
	local g = Instance.new("UIGradient")
	if typeof(a) == "ColorSequence" then
		g.Color = a
	else
		g.Color = ColorSequence.new(a :: Color3, b or a :: Color3)
	end
	g.Rotation = rot or 90
	g.Parent = p
	return g
end

function UIKit.padding(p: Instance, all: number)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, all)
	pad.PaddingRight = UDim.new(0, all)
	pad.PaddingTop = UDim.new(0, all)
	pad.PaddingBottom = UDim.new(0, all)
	pad.Parent = p
	return pad
end

function UIKit.list(p: Instance, dir: Enum.FillDirection?, pad: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?)
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, pad or 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Left
	l.VerticalAlignment = vAlign or Enum.VerticalAlignment.Top
	l.Parent = p
	return l
end

-- Texture a picots (Lego), meme rendu que les autres UIs : image blanche
-- en mosaique + leger degrade. `color` garde pour compatibilite (ignore).
function UIKit.studs(p: GuiObject, tile: number?, transp: number?, radius: number?, _color: Color3?)
	local img = Instance.new("ImageLabel")
	img.Name = "StudsTexture"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = UIKit.STUDS
	img.ScaleType = Enum.ScaleType.Tile
	img.TileSize = UDim2.fromOffset(tile or 36, tile or 36)
	img.ImageColor3 = WHITE
	img.ImageTransparency = transp and math.min(transp, 0.65) or 0.55
	img.ZIndex = p.ZIndex
	img.Parent = p
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(WHITE, Color3.fromRGB(200, 200, 200))
	g.Parent = img
	if radius then
		UIKit.corner(img, radius)
	end
	return img
end

-- Texte avec contour noir arrondi. size = taille max (TextScaled + contrainte).
function UIKit.text(parent: Instance, str: string, size: number, color: Color3?, font: Font?, strokeT: number?)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font or UIKit.FONT
	l.Text = str
	l.TextScaled = true
	l.TextColor3 = color or WHITE
	l.RichText = true
	l.ZIndex = (parent:IsA("GuiObject") and parent.ZIndex or 1) + 1
	l.Size = UDim2.new(1, 0, 0, size)
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = size
	c.MinTextSize = math.min(8, size)
	c.Parent = l
	UIKit.stroke(l, strokeT or math.max(1.5, size / 12), BLACK, true)
	return l
end

--== Animations ==--

function UIKit.tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?, delay: number?)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	tw:Play()
	return tw
end

function UIKit.scaleOf(inst: Instance): UIScale
	local s = inst:FindFirstChild("KitScale")
	if not s then
		s = Instance.new("UIScale")
		s.Name = "KitScale"
		s.Parent = inst
	end
	return s :: UIScale
end

-- Pop d'apparition (0 -> 1 avec rebond).
function UIKit.pop(inst: GuiObject, delay: number?, from: number?)
	local s = UIKit.scaleOf(inst)
	s.Scale = from or 0.4
	return UIKit.tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, delay)
end

function UIKit.shake(inst: GuiObject, power: number?)
	local p = power or 8
	local base = inst.Rotation
	task.spawn(function()
		for i = 1, 6 do
			inst.Rotation = base + (i % 2 == 0 and -1 or 1) * p * (1 - i / 7)
			task.wait(0.035)
		end
		inst.Rotation = base
	end)
end

-- Bouton vivant : survol, clic, selection manette. hover = echelle au survol.
function UIKit.pressable(b: GuiButton, hover: number?)
	local s = UIKit.scaleOf(b)
	local h = hover or 1.06
	local over = false
	local function set(v, t)
		UIKit.tween(s, t or 0.12, { Scale = v }, Enum.EasingStyle.Back)
	end
	b.MouseEnter:Connect(function()
		over = true
		set(h)
	end)
	b.MouseLeave:Connect(function()
		over = false
		set(1)
	end)
	b.SelectionGained:Connect(function()
		over = true
		set(h)
	end)
	b.SelectionLost:Connect(function()
		over = false
		set(1)
	end)
	b.MouseButton1Down:Connect(function()
		UIKit.tween(s, 0.06, { Scale = h * 0.9 })
	end)
	b.MouseButton1Up:Connect(function()
		set(over and h or 1, 0.2)
	end)
	b.Activated:Connect(function()
		if UIKit.IsGamepad() then
			s.Scale = h * 0.9
			set(h, 0.2)
		end
	end)
	b.SelectionImageObject = UIKit.SelectionFrame()
	return s
end

-- Reflet blanc qui balaie l'objet en boucle.
function UIKit.shine(inst: GuiObject, period: number?, width: number?)
	local holder = Instance.new("Frame")
	holder.Name = "Shine"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ClipsDescendants = true
	holder.ZIndex = inst.ZIndex + 1
	holder.Parent = inst
	local corner = inst:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = holder
	end
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = WHITE
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0.5, 0.5)
	bar.Size = UDim2.new(width or 0.18, 0, 2.5, 0)
	bar.Position = UDim2.fromScale(-0.3, 0.5)
	bar.Rotation = 20
	bar.ZIndex = holder.ZIndex
	bar.Parent = holder
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = bar
	task.spawn(function()
		local p = period or 3
		while holder.Parent do
			bar.Position = UDim2.fromScale(-0.3, 0.5)
			local tw = UIKit.tween(bar, 0.7, { Position = UDim2.fromScale(1.3, 0.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			tw.Completed:Wait()
			task.wait(p + math.random() * 0.8)
		end
	end)
	return holder
end

-- Compte de `from` a `to` en `t` secondes dans un TextLabel.
function UIKit.countUp(label: TextLabel, from: number, to: number, fmt: (number) -> string, t: number?)
	local token = (tonumber(label:GetAttribute("CountToken")) or 0) + 1
	label:SetAttribute("CountToken", token)
	local dur = t or 0.4
	local t0 = os.clock()
	task.spawn(function()
		while label.Parent and label:GetAttribute("CountToken") == token do
			local a = math.clamp((os.clock() - t0) / dur, 0, 1)
			local e = 1 - (1 - a) ^ 3
			label.Text = fmt(from + (to - from) * e)
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

-- Explosion de confettis (carres / etoiles) depuis un point du parent.
function UIKit.burst(parent: GuiObject, center: UDim2, colors: { Color3 }, count: number?, power: number?, z: number?)
	local n = count or 18
	local pw = power or 160
	for i = 1, n do
		local f = Instance.new("Frame")
		local sz = math.random(8, 16)
		f.Size = UDim2.fromOffset(sz, sz * (math.random() < 0.5 and 1 or 0.5))
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = center
		f.BackgroundColor3 = colors[(i % #colors) + 1]
		f.BorderSizePixel = 0
		f.Rotation = math.random(0, 360)
		f.ZIndex = z or 200
		f.Parent = parent
		UIKit.stroke(f, 1.5, BLACK)
		local a = math.random() * math.pi * 2
		local d = pw * (0.5 + math.random())
		local dx, dy = math.cos(a) * d, math.sin(a) * d - pw * 0.4
		local t = 0.55 + math.random() * 0.4
		UIKit.tween(f, t, {
			Position = center + UDim2.fromOffset(dx, dy),
			Rotation = f.Rotation + math.random(-360, 360),
		}, Enum.EasingStyle.Quart)
		UIKit.tween(f, t * 0.5, { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In, t * 0.6)
		task.delay(t + 0.1, function()
			f:Destroy()
		end)
	end
end

-- Onde circulaire (feedback de clic / reussite).
function UIKit.ripple(parent: GuiObject, center: UDim2, color: Color3?, size: number?, z: number?)
	local r = Instance.new("Frame")
	r.AnchorPoint = Vector2.new(0.5, 0.5)
	r.Position = center
	r.Size = UDim2.fromOffset(10, 10)
	r.BackgroundTransparency = 1
	r.ZIndex = z or 150
	r.Parent = parent
	UIKit.round(r)
	local s = UIKit.stroke(r, 4, color or WHITE)
	local target = size or 180
	UIKit.tween(r, 0.45, { Size = UDim2.fromOffset(target, target) }, Enum.EasingStyle.Quart)
	UIKit.tween(s, 0.45, { Transparency = 1, Thickness = 1 }, Enum.EasingStyle.Quad)
	task.delay(0.5, function()
		r:Destroy()
	end)
end

--== Plateforme ==--

local GAMEPAD_TYPES = {
	[Enum.UserInputType.Gamepad1] = true, [Enum.UserInputType.Gamepad2] = true,
	[Enum.UserInputType.Gamepad3] = true, [Enum.UserInputType.Gamepad4] = true,
}

function UIKit.IsGamepad(): boolean
	return GAMEPAD_TYPES[UserInputService:GetLastInputType()] == true
		or (UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled)
end

function UIKit.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and not UIKit.IsGamepad()
end

function UIKit.IsSmallScreen(): boolean
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	return vp.Y < 560 or vp.X < 900
end

-- Echelle pour qu'une fenetre de w x h (pixels de design) tienne a l'ecran.
function UIKit.fitScale(w: number, h: number, marginX: number?, marginY: number?): number
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local inset = GuiService:GetGuiInset()
	local mx = marginX or 24
	local my = (marginY or 40) + inset.Y
	return math.clamp(math.min((vp.X - mx) / w, (vp.Y - my) / h), 0.25, 1.15)
end

-- Garde `scale` ajuste a l'ecran (appelle onFit(scale) si fourni).
function UIKit.bindFit(w: number, h: number, onFit: (number) -> (), marginX: number?, marginY: number?)
	local function update()
		onFit(UIKit.fitScale(w, h, marginX, marginY))
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		local c = workspace.CurrentCamera
		if c then
			c:GetPropertyChangedSignal("ViewportSize"):Connect(update)
			update()
		end
	end)
	update()
	return update
end

local selectionFrame
function UIKit.SelectionFrame(): Frame
	if selectionFrame then
		return selectionFrame
	end
	local f = Instance.new("Frame")
	f.Name = "KitSelection"
	f.BackgroundTransparency = 1
	f.Size = UDim2.new(1, 12, 1, 12)
	f.Position = UDim2.fromOffset(-6, -6)
	UIKit.corner(f, 14)
	local s = UIKit.stroke(f, 4, WHITE)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 160, 0))
	g.Parent = s
	selectionFrame = f
	task.spawn(function()
		local t = 0
		while true do
			t += RunService.RenderStepped:Wait()
			g.Rotation = (t * 180) % 360
			s.Thickness = 3.5 + math.sin(t * 6) * 1
		end
	end)
	return f
end

--== Fenetres (B pour fermer, selection auto sur manette) ==--

local modals = {} -- { { name, close, select } }

local function topModal()
	return modals[#modals]
end

local function onBack(_, state)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local m = topModal()
	if not m then
		return Enum.ContextActionResult.Pass
	end
	task.spawn(m.close)
	return Enum.ContextActionResult.Sink
end

local function refreshBinding()
	if #modals > 0 then
		ContextActionService:BindActionAtPriority("UIKitBack", onBack, false, Enum.ContextActionPriority.High.Value + 50, Enum.KeyCode.ButtonB)
	else
		ContextActionService:UnbindAction("UIKitBack")
	end
end

function UIKit.SelectFirst(target: GuiObject?)
	if target and UIKit.IsGamepad() then
		task.defer(function()
			if target.Parent and target.Visible then
				GuiService.SelectedObject = target
			end
		end)
	end
end

-- Enregistre une fenetre ouverte. close() doit la fermer (et appeler PopModal).
function UIKit.PushModal(name: string, close: () -> (), select: GuiObject?)
	UIKit.PopModal(name)
	table.insert(modals, { name = name, close = close, select = select })
	refreshBinding()
	UIKit.SelectFirst(select)
end

function UIKit.PopModal(name: string)
	for i = #modals, 1, -1 do
		if modals[i].name == name then
			table.remove(modals, i)
		end
	end
	refreshBinding()
	local m = topModal()
	if m and m.select then
		UIKit.SelectFirst(m.select)
	elseif #modals == 0 then
		GuiService.SelectedObject = nil
	end
end

function UIKit.IsModalOpen(name: string?): boolean
	if not name then
		return #modals > 0
	end
	for _, m in ipairs(modals) do
		if m.name == name then
			return true
		end
	end
	return false
end

-- Glyphe de la touche manette / clavier pour un raccourci affiche.
function UIKit.KeyHint(gamepad: string, keyboard: string?): string
	if UIKit.IsGamepad() then
		return gamepad
	end
	if UIKit.IsTouch() then
		return ""
	end
	return keyboard or ""
end

return UIKit
