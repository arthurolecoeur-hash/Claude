--[[
	UIJuice
	-------
	LocalScript (StarterPlayerScripts) qui rend TOUTES les UIs du jeu plus
	vivantes, sans toucher aux scripts de chaque UI :

	  - reflet blanc qui balaie regulierement chaque bouton colore ;
	  - survol : le bouton grossit et penche un peu ; clic : il s'ecrase puis
	    rebondit + petite explosion de studs et onde a l'endroit du bouton ;
	  - boutons du HUD : icones qui se balancent + petit "coucou" regulier ;
	  - (cascade a l'ouverture des fenetres : desactivee, voir watchWindow) ;
	  - textes : degrade brillant (haut clair -> bas plus sombre), contours
	    arrondis, et reflet qui passe sur les titres ;
	  - Toasts : apparition avec rebond.
	  - texte centre dans les boutons et les titres (attribut KeepAlign =
	    true sur un texte pour garder son alignement).

	Pour exclure un objet (et tout ce qu'il contient) : attribut NoJuice = true.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local STUDS = "rbxassetid://10509831729"
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(14, 10, 28)

local SKIP_GUIS = {
	LuckyBlockOpenUI = true,
	JuiceFX = true,
	TouchGui = true,
	Freecam = true,
	BubbleChat = true,
	Chat = true,
}
local WINDOW_NAMES = {
	Overlay = true,
	Modal = true,
	Window = true,
	Panel = true,
	Inventory = true,
	Backpack = true,
}
local HUD_BUTTONS = {
	{ "RebirthUI", "RebirthButton" },
	{ "IndexUI", "IndexButton" },
	{ "ShopUI", "ShopButton" },
	{ "SpinWheelHud", "Holder", "Icon" },
	{ "SettingsGui", "SettingsButton" },
}

local function tween(inst, t, props, style, dir, delay)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	tw:Play()
	return tw
end

local function loop(inst, t, props, delay, reverses)
	local tw = TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, reverses == true, delay or 0), props)
	tw:Play()
	return tw
end

-- ScreenGui concerne (nil = a ignorer).
local function juiceGui(inst: Instance): ScreenGui?
	local sg = inst:FindFirstAncestorWhichIsA("LayerCollector")
	if not sg or not sg:IsA("ScreenGui") or SKIP_GUIS[sg.Name] or sg:GetAttribute("NoJuice") then
		return nil
	end
	local a = inst
	while a and a ~= sg do
		if a:GetAttribute("NoJuice") then
			return nil
		end
		a = a.Parent
	end
	return sg
end

-- UIScale a nous (jamais de 2e UIScale si le script de l'UI en a deja un).
local function ownScale(obj: GuiObject): UIScale?
	local own = obj:FindFirstChild("JuiceScale")
	if own then
		return own
	end
	if obj:FindFirstChildOfClass("UIScale") then
		return nil
	end
	local s = Instance.new("UIScale")
	s.Name = "JuiceScale"
	s.Parent = obj
	return s
end

--== Couche d'effets (explosions au clic) ==--
local fxGui = Instance.new("ScreenGui")
fxGui.Name = "JuiceFX"
fxGui.IgnoreGuiInset = true
fxGui.DisplayOrder = 250
fxGui.ResetOnSpawn = false
fxGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
fxGui.Parent = playerGui

local function burst(button: GuiObject)
	local sg = button:FindFirstAncestorWhichIsA("ScreenGui")
	if not sg then
		return
	end
	local pos = button.AbsolutePosition + button.AbsoluteSize / 2
	if not sg.IgnoreGuiInset then
		pos += GuiService:GetGuiInset()
	end
	local h, s, v = button.BackgroundColor3:ToHSV()
	local color = button.BackgroundTransparency < 0.5 and Color3.fromHSV(h, math.min(1, s + 0.1), math.min(1, v + 0.15)) or Color3.fromRGB(255, 220, 60)
	local size = math.clamp(math.max(button.AbsoluteSize.X, button.AbsoluteSize.Y), 40, 260)

	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromOffset(pos.X, pos.Y)
	ring.Size = UDim2.fromOffset(size * 0.5, size * 0.5)
	ring.BackgroundTransparency = 1
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0.5, 0)
	rc.Parent = ring
	local rs = Instance.new("UIStroke")
	rs.Thickness = 5
	rs.Color = WHITE
	rs.Parent = ring
	ring.Parent = fxGui
	tween(ring, 0.38, { Size = UDim2.fromOffset(size * 1.5, size * 1.5) }, Enum.EasingStyle.Quart)
	tween(rs, 0.38, { Transparency = 1, Thickness = 1 }, Enum.EasingStyle.Quart)
	task.delay(0.4, function()
		ring:Destroy()
	end)

	for i = 1, 9 do
		local d = math.random(10, 16)
		local p = Instance.new("ImageLabel")
		p.AnchorPoint = Vector2.new(0.5, 0.5)
		p.Position = UDim2.fromOffset(pos.X, pos.Y)
		p.Size = UDim2.fromOffset(d, d)
		p.BackgroundColor3 = (i % 3 == 0) and WHITE or color
		p.BorderSizePixel = 0
		p.Image = STUDS
		p.ScaleType = Enum.ScaleType.Tile
		p.TileSize = UDim2.fromOffset(d, d)
		p.ImageTransparency = 0.35
		p.Rotation = math.random(0, 90)
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 3)
		c.Parent = p
		local st = Instance.new("UIStroke")
		st.Thickness = 2
		st.Color = DARK
		st.Parent = p
		p.Parent = fxGui
		local angle = (i / 9) * math.pi * 2 + math.random() * 0.5
		local dist = size * 0.5 + math.random(20, 55)
		local goal = pos + Vector2.new(math.cos(angle), math.sin(angle)) * dist
		local t = math.random(35, 55) / 100
		tween(p, t, { Position = UDim2.fromOffset(goal.X, goal.Y + 12), Rotation = p.Rotation + math.random(-200, 200), Size = UDim2.fromOffset(d * 0.4, d * 0.4), BackgroundTransparency = 1, ImageTransparency = 1 }, Enum.EasingStyle.Quad)
		tween(st, t, { Transparency = 1 })
		task.delay(t + 0.05, function()
			p:Destroy()
		end)
	end
end

--== Reflet sur les boutons ==--
local SHINE_T = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.4, 1),
	NumberSequenceKeypoint.new(0.46, 0.75),
	NumberSequenceKeypoint.new(0.5, 0.55),
	NumberSequenceKeypoint.new(0.54, 0.75),
	NumberSequenceKeypoint.new(0.6, 1),
	NumberSequenceKeypoint.new(1, 1),
})

local function addShine(obj: GuiObject)
	if obj:FindFirstChild("JuiceShine") or obj:FindFirstChild("Shine") then
		return
	end
	if obj.BackgroundTransparency > 0.4 then
		return
	end
	local sz = obj.Size
	if (sz.X.Scale == 0 and sz.X.Offset < 30) or (sz.Y.Scale == 0 and sz.Y.Offset < 22) then
		return
	end
	local shine = Instance.new("Frame")
	shine.Name = "JuiceShine"
	shine.BackgroundColor3 = WHITE
	shine.BorderSizePixel = 0
	shine.Size = UDim2.fromScale(1, 1)
	shine.ZIndex = obj.ZIndex
	local corner = obj:FindFirstChildOfClass("UICorner")
	if corner then
		corner:Clone().Parent = shine
	end
	local g = Instance.new("UIGradient")
	g.Rotation = 25
	g.Transparency = SHINE_T
	g.Offset = Vector2.new(-1.2, 0)
	g.Parent = shine
	shine.Parent = obj
	loop(g, 0.85, { Offset = Vector2.new(1.2, 0) }, 1.6 + math.random() * 2.6)
end

--== Boutons ==--
local hudSet = {}
local hooked = setmetatable({}, { __mode = "k" })

local function hookButton(b: GuiButton)
	if hooked[b] then
		return
	end
	if b.BackgroundTransparency >= 0.99 and (b.Size.X.Scale >= 0.9 or b.Name:find("Blocker")) then
		return -- zones de clic plein ecran
	end
	if not juiceGui(b) then
		return
	end
	hooked[b] = true

	task.defer(addShine, b)

	local baseRot = b.Rotation
	local tiltDir = math.random() < 0.5 and -1 or 1
	local isHud = hudSet[b] == true
	-- Dans une liste qui defile, un bouton tourne sortirait du cadre.
	local noTilt = isHud or b:FindFirstAncestorWhichIsA("ScrollingFrame") ~= nil
	local hovering = false

	b.MouseEnter:Connect(function()
		hovering = true
		b:SetAttribute("JuiceHover", true)
		local s = ownScale(b)
		if s then
			tween(s, 0.2, { Scale = 1.07 }, Enum.EasingStyle.Back)
		end
		if not noTilt then
			tween(b, 0.2, { Rotation = baseRot + tiltDir * 2 }, Enum.EasingStyle.Back)
		end
	end)
	b.MouseLeave:Connect(function()
		hovering = false
		b:SetAttribute("JuiceHover", nil)
		local s = b:FindFirstChild("JuiceScale")
		if s then
			tween(s, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		if not noTilt then
			tween(b, 0.2, { Rotation = baseRot }, Enum.EasingStyle.Back)
		end
	end)
	b.MouseButton1Down:Connect(function()
		local s = b:FindFirstChild("JuiceScale")
		if s then
			tween(s, 0.07, { Scale = 0.9 })
		end
	end)
	b.MouseButton1Up:Connect(function()
		local s = b:FindFirstChild("JuiceScale")
		if s then
			tween(s, 0.3, { Scale = hovering and 1.07 or 1 }, Enum.EasingStyle.Back)
		end
	end)
	b.Activated:Connect(function()
		if b.Active then
			burst(b)
		end
	end)
end

--== Textes ==--
local GLOSS = ColorSequence.new({
	ColorSequenceKeypoint.new(0, WHITE),
	ColorSequenceKeypoint.new(0.45, WHITE),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(192, 196, 220)),
})
local SHIMMER_BASE = Color3.fromRGB(222, 222, 236)
local SHIMMER = ColorSequence.new({
	ColorSequenceKeypoint.new(0, SHIMMER_BASE),
	ColorSequenceKeypoint.new(0.4, SHIMMER_BASE),
	ColorSequenceKeypoint.new(0.5, WHITE),
	ColorSequenceKeypoint.new(0.6, SHIMMER_BASE),
	ColorSequenceKeypoint.new(1, SHIMMER_BASE),
})
local shimmerRunning = setmetatable({}, { __mode = "k" })

local function isTitle(l: GuiObject): boolean
	local n = l.Name
	if n:find("Title") or n:find("Header") then
		return true
	end
	return tostring(l.FontFace.Family):find("LuckiestGuy") ~= nil and l.Size.Y.Scale == 0 and l.Size.Y.Offset >= 30
end

local function startShimmer(g: UIGradient)
	if shimmerRunning[g] then
		return
	end
	shimmerRunning[g] = true
	g.Offset = Vector2.new(-1, 0)
	loop(g, 1.1, { Offset = Vector2.new(1, 0) }, 2 + math.random() * 2)
end

-- Texte bien centre : boutons, textes dans un bouton et titres. Les
-- listes / paragraphes (texte a la ligne) gardent leur alignement.
local function centerText(l: any)
	if not (l:IsA("TextLabel") or l:IsA("TextButton")) or l:GetAttribute("KeepAlign") then
		return
	end
	local inButton = l:IsA("TextButton") or (l.Parent ~= nil and l.Parent:IsA("GuiButton"))
	if inButton or isTitle(l) then
		l.TextXAlignment = Enum.TextXAlignment.Center
	end
	if not l.TextWrapped or inButton then
		l.TextYAlignment = Enum.TextYAlignment.Center
	end
end

local styled = setmetatable({}, { __mode = "k" })
local function styleText(l: TextLabel)
	if styled[l] then
		return
	end
	styled[l] = true
	if not l.Parent or not juiceGui(l) then
		return
	end
	centerText(l)
	local stroke = l:FindFirstChildOfClass("UIStroke")
	if stroke and stroke.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
		stroke.LineJoinMode = Enum.LineJoinMode.Round
	end
	local existing = l:FindFirstChildOfClass("UIGradient")
	if existing then
		-- Clone d'un modele deja style : on relance juste le reflet.
		if existing.Name == "JuiceGloss" and existing:GetAttribute("Shimmer") then
			startShimmer(existing)
		end
		return
	end
	if l.BackgroundTransparency < 0.95 then
		return -- le degrade teinterait aussi le fond
	end
	local g = Instance.new("UIGradient")
	g.Name = "JuiceGloss"
	if isTitle(l) then
		g.Rotation = 15
		g.Color = SHIMMER
		g:SetAttribute("Shimmer", true)
	else
		g.Rotation = 90
		g.Color = GLOSS
	end
	g.Parent = l
	if g:GetAttribute("Shimmer") then
		startShimmer(g)
	end
	-- Si le script de l'UI pose son propre degrade ensuite, il gagne.
	local conn
	conn = l.ChildAdded:Connect(function(c)
		if c:IsA("UIGradient") and c ~= g then
			g:Destroy()
			conn:Disconnect()
		end
	end)
end

--== Toasts ==--
local function hookToast(l: GuiObject)
	l:GetPropertyChangedSignal("Visible"):Connect(function()
		if not l.Visible then
			return
		end
		local s = ownScale(l)
		if s then
			s.Scale = 0.5
			tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		l.Rotation = math.random(-5, 5)
		tween(l, 0.4, { Rotation = 0 }, Enum.EasingStyle.Back)
	end)
end

--== Fenetres : contenu en cascade ==--
local function cascade(window: GuiObject)
	local items = {}
	for _, layout in ipairs(window:GetDescendants()) do
		if layout:IsA("UIGridStyleLayout") and layout.Parent then
			local n = 0
			for _, item in ipairs(layout.Parent:GetChildren()) do
				if item:IsA("GuiObject") and item.Visible and n < 40 then
					n += 1
					table.insert(items, item)
				end
			end
		end
	end
	table.sort(items, function(a, b)
		local pa, pb = a.AbsolutePosition, b.AbsolutePosition
		if math.abs(pa.Y - pb.Y) > 4 then
			return pa.Y < pb.Y
		end
		return pa.X < pb.X
	end)
	for i, item in ipairs(items) do
		local s = item:FindFirstChild("Pop")
		if not (s and s:IsA("UIScale")) then
			s = ownScale(item)
		end
		if s then
			s.Scale = 0.35
			tween(s, 0.42, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, math.min(0.7, 0.06 + (i - 1) * 0.035))
		end
	end
end

local watchedWindows = setmetatable({}, { __mode = "k" })
local function watchWindow(w: GuiObject)
	-- Cascade pop a l'ouverture desactivee (effet dezoom/rezoom juge genant).
	do
		return
	end
	if watchedWindows[w] or not juiceGui(w) then
		return
	end
	watchedWindows[w] = true
	w:GetPropertyChangedSignal("Visible"):Connect(function()
		if w.Visible then
			task.defer(cascade, w)
		end
	end)
end

--== Branchement ==--
local function strokeSeq(c: Color3)
	local _, _, v = c:ToHSV()
	return ColorSequence.new(c:Lerp(WHITE, v < 0.3 and 0.25 or 0.4), c:Lerp(Color3.new(0, 0, 0), v < 0.3 and 0.2 or 0.5))
end

local function colorStroke(s: UIStroke)
	local p = s.Parent
	if not (p and p:IsA("GuiObject")) or s.ApplyStrokeMode ~= Enum.ApplyStrokeMode.Border then
		return
	end
	s.BorderStrokePosition = Enum.BorderStrokePosition.Inner
	if s:FindFirstChildOfClass("UIGradient") or p.BackgroundTransparency >= 0.6 or not juiceGui(s) then
		return
	end
	local g = Instance.new("UIGradient")
	g.Name = "StrokeGrad"
	g.Rotation = 90
	g.Color = strokeSeq(p.BackgroundColor3)
	g.Parent = s
	s.Color = WHITE
end

local FREDOKA = "rbxasset://fonts/families/FredokaOne.json"
local FONT_SKIP = { TouchGui = true, Freecam = true, BubbleChat = true, Chat = true, JuiceFX = true }

local NUM_SUFFIX = {}
do
	for _, s in ipairs({ "K", "M", "B", "T", "Qa", "Qn", "Sx", "Sp", "Oc", "No", "De", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nd", "Ce" }) do
		NUM_SUFFIX[s:lower()] = true
	end
	local ones = { "", "Un", "Do", "Tr", "Qa", "Qi", "Sx", "Sp", "Oc", "No" }
	for _, t in ipairs({ "Dc", "Vg", "Tg", "Qg", "Qq", "Sg", "Sn", "Og", "Ng" }) do
		for _, o in ipairs(ones) do
			NUM_SUFFIX[(o .. t):lower()] = true
		end
	end
end

local function upperSuffixes(s: string): string
	return (s:gsub("(%d)(%a+)", function(d, letters)
		if NUM_SUFFIX[letters:lower()] then
			return d .. letters:upper()
		end
		return nil
	end))
end

local function sentenceCase(s: string): string
	local out = {}
	local inTag, capNext, afterDigit = false, true, false
	for _, cp in utf8.codes(s) do
		local ch = utf8.char(cp)
		if ch == "<" then
			inTag = true
		elseif ch == ">" and inTag then
			inTag = false
		elseif not inTag then
			if ch:match("%a") then
				if not afterDigit then
					ch = capNext and ch:upper() or ch:lower()
				end
				capNext = false
			elseif ch:match("%d") then
				capNext = false
				afterDigit = true
			else
				afterDigit = false
				if ch == "." or ch == "!" or ch == "?" then
					capNext = true
				end
			end
		end
		table.insert(out, ch)
	end
	return upperSuffixes(table.concat(out))
end

local typed = setmetatable({}, { __mode = "k" })
local function typeText(l: GuiObject)
	if typed[l] then
		return
	end
	local sg = l:FindFirstAncestorWhichIsA("LayerCollector")
	if not sg or FONT_SKIP[sg.Name] or l:GetAttribute("KeepText") then
		return
	end
	typed[l] = true
	local lbl = l :: TextLabel
	lbl.FontFace = Font.new(FREDOKA, lbl.FontFace.Weight, lbl.FontFace.Style)
	lbl:GetPropertyChangedSignal("FontFace"):Connect(function()
		if lbl.FontFace.Family ~= FREDOKA then
			lbl.FontFace = Font.new(FREDOKA, lbl.FontFace.Weight, lbl.FontFace.Style)
		end
	end)
	if l:IsA("TextBox") then
		return
	end
	local function fix()
		local t = sentenceCase(lbl.Text)
		if t ~= lbl.Text then
			lbl.Text = t
		end
	end
	fix()
	lbl:GetPropertyChangedSignal("Text"):Connect(fix)
end

local function onDescendant(d: Instance)
	if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
		typeText(d)
	end
	if d:IsA("UIStroke") then
		task.defer(colorStroke, d)
		return
	end
	if d:IsA("GuiButton") then
		hookButton(d)
	end
	if d:IsA("TextLabel") or d:IsA("TextButton") then
		task.delay(0.15, styleText, d)
		if d.Name == "Toast" then
			hookToast(d)
		end
	end
	if d:IsA("GuiObject") and d.Parent and (d.Parent:IsA("ScreenGui") or WINDOW_NAMES[d.Name]) then
		watchWindow(d)
	end
end

--== HUD : icones qui se balancent + petit coucou ==--
local hudButtons = {}
local function setupHud()
	for i, path in ipairs(HUD_BUTTONS) do
		local obj: Instance? = playerGui:WaitForChild(path[1], 20)
		for j = 2, #path do
			obj = obj and obj:WaitForChild(path[j], 10)
		end
		if obj and obj:IsA("GuiButton") then
			hudSet[obj] = true
			table.insert(hudButtons, obj)
			local icon = obj:FindFirstChild("Icon")
			if icon and icon:IsA("GuiObject") then
				icon.Rotation = -7
				loop(icon, 1.2 + i * 0.13, { Rotation = 7 }, 0, true)
				local p = icon.Position
				loop(icon, 0.9 + i * 0.11, { Position = p + UDim2.fromOffset(0, -4) }, 0, true)
			end
		end
	end
end

setupHud()
for _, d in ipairs(playerGui:GetDescendants()) do
	onDescendant(d)
end
playerGui.DescendantAdded:Connect(onDescendant)

-- Un bouton du HUD "fait coucou" de temps en temps.
task.spawn(function()
	while true do
		task.wait(4 + math.random() * 3)
		local b = hudButtons[math.random(1, math.max(1, #hudButtons))]
		if b and b.Parent and b.Visible and not b:GetAttribute("JuiceHover") then
			local base = 0
			for _, r in ipairs({ -9, 8, -6, 4, -2, 0 }) do
				tween(b, 0.07, { Rotation = base + r }, Enum.EasingStyle.Sine)
				task.wait(0.07)
			end
			b.Rotation = base
		end
	end
end)
