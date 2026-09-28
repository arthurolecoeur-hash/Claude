--[[
	IndexUIClient
	-------------
	Branche la logique sur l'UI statique StarterGui > IndexUI (style studs).

	- Onglets a gauche = mutations du jeu (Normal + BrainrotCatalog.MUTATIONS)
	- Une carte par brainrot : apercu 3D, revenu/s, mutation, rarete
	- Brainrot jamais obtenu : silhouette noire + cadenas + "???"
	- % complete et compteur global dans la barre de titre
	- Badge "!" sur le bouton quand un nouveau brainrot est debloque

	Le serveur (IndexService) est la seule source de verite.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("Shop"):WaitForChild("ShopConfig"))
local ShopViewports = require(ReplicatedStorage.Shop:WaitForChild("ShopViewports"))

-- Brainrots LIMITED (boutique : Lucky Block + achat direct) : ils ont leur
-- propre colonne a droite et ne sont pas dans les onglets Normal/mutations.
local LIMITED = {}
local limitedSet = {}
for _, d in ipairs(ShopConfig.LUCKY_BLOCK.drops) do
	table.insert(LIMITED, d)
	limitedSet[d.name] = true
end
table.insert(LIMITED, ShopConfig.DIRECT_BUY)
limitedSet[ShopConfig.DIRECT_BUY.name] = true

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("IndexRemotes")
local getIndexData = remotes:WaitForChild("GetIndexData") :: RemoteFunction
local indexUpdated = remotes:WaitForChild("IndexUpdated") :: RemoteEvent

local MODAL_WIDTH = 1130
local MODAL_HEIGHT = 560

-- Couleur de chaque onglet / libelle de mutation.
local MUTATION_COLORS = {
	Normal  = Color3.fromRGB(215, 215, 225),
	Gold    = Color3.fromRGB(255, 196, 0),
	Diamond = Color3.fromRGB(0, 190, 255),
	Ruby    = Color3.fromRGB(255, 20, 75),
	Lava    = Color3.fromRGB(255, 85, 0),
	Galaxy  = Color3.fromRGB(140, 70, 255),
	Hacker  = Color3.fromRGB(0, 235, 80),
	Rainbow = Color3.fromRGB(255, 255, 255),
	Admin   = Color3.fromRGB(35, 35, 40),
}

-- Couleurs vives des cartes de l'onglet Normal (par rarete).
local RARITY_COLORS = {
	Commun     = Color3.fromRGB(130, 145, 185),
	PeuCommun  = Color3.fromRGB(30, 225, 95),
	Rare       = Color3.fromRGB(20, 140, 255),
	Epique     = Color3.fromRGB(170, 40, 255),
	Legendaire = Color3.fromRGB(255, 175, 0),
	Mythique   = Color3.fromRGB(255, 30, 90),
	Divin      = Color3.fromRGB(255, 225, 110),
	Celeste    = Color3.fromRGB(90, 215, 255),
	Secret     = Color3.fromRGB(0, 240, 160),
	Cosmique   = Color3.fromRGB(255, 60, 230),
	Ancestral  = Color3.fromRGB(255, 140, 30),
	Maudit     = Color3.fromRGB(160, 245, 40),
	Mecanique  = Color3.fromRGB(215, 170, 90),
	Abyssal    = Color3.fromRGB(60, 95, 255),
	Draconique = Color3.fromRGB(255, 40, 40),
	Sacre       = Color3.fromRGB(255, 150, 200),
	Ludique = Color3.fromRGB(255, 120, 90),
	Enchante    = Color3.fromRGB(120, 255, 190),
	Olympien    = Color3.fromRGB(255, 240, 170),
	Glitch      = Color3.fromRGB(255, 40, 220),
}

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 30, 30)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 0)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(30, 235, 60)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 160, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(160, 40, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 30, 30)),
})
-- Degrade leger (haut clair -> bas un peu plus sombre) sans ternir la couleur.
local SHADE = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190))
local LOCKED_BG = Color3.fromRGB(25, 27, 38)

local function seq(a, b, c)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, a),
		ColorSequenceKeypoint.new(0.5, b),
		ColorSequenceKeypoint.new(1, c),
	})
end

-- Rendu "matiere" de chaque mutation (fond blanc + degrade).
local MUTATION_STYLES = {
	Normal  = { color = seq(Color3.fromRGB(215, 220, 240), Color3.fromRGB(150, 158, 190), Color3.fromRGB(95, 100, 130)), rotation = 90 },
	Gold    = { color = seq(Color3.fromRGB(255, 215, 40), Color3.fromRGB(255, 180, 0), Color3.fromRGB(170, 95, 0)), rotation = 60, shine = true },
	Diamond = { color = seq(Color3.fromRGB(90, 225, 255), Color3.fromRGB(0, 180, 255), Color3.fromRGB(0, 85, 215)), rotation = 60, shine = true },
	Ruby    = { color = seq(Color3.fromRGB(255, 70, 110), Color3.fromRGB(240, 10, 65), Color3.fromRGB(140, 0, 35)), rotation = 60, shine = true },
	Lava    = { color = seq(Color3.fromRGB(255, 190, 0), Color3.fromRGB(255, 70, 0), Color3.fromRGB(130, 10, 0)), rotation = 90, shine = true },
	Galaxy  = { color = seq(Color3.fromRGB(200, 140, 255), Color3.fromRGB(120, 50, 240), Color3.fromRGB(25, 10, 90)), rotation = 60, shine = true },
	Hacker  = { color = seq(Color3.fromRGB(70, 255, 120), Color3.fromRGB(0, 200, 60), Color3.fromRGB(0, 60, 25)), rotation = 90, shine = true },
	Rainbow = { color = RAINBOW, rotation = 45, shine = true, animated = true },
	Admin   = { color = seq(Color3.fromRGB(95, 95, 105), Color3.fromRGB(35, 35, 40), Color3.fromRGB(5, 5, 6)), rotation = 90, shine = true },
}

local function raritySeq(c: Color3)
	return seq(c:Lerp(Color3.new(1, 1, 1), 0.08), c, c:Lerp(Color3.new(0, 0, 0), 0.45))
end

-- Reflet qui balaie la carte / l'onglet (meme principe que le bouton Rebirth).
local shineGradients = {} -- UIGradient -> true
local animatedGradients = {} -- UIGradient -> true (Rainbow qui defile)

local function ensureShine(frame: GuiObject, radius: UDim, z: number)
	local shine = frame:FindFirstChild("Shine")
	if shine then
		return shine
	end
	shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.new(1, 1, 1)
	shine.BorderSizePixel = 0
	shine.Size = UDim2.fromScale(1, 1)
	shine.ZIndex = z
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = shine
	local g = Instance.new("UIGradient")
	g.Rotation = 20
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Offset = Vector2.new(-1, 0)
	g.Parent = shine
	shineGradients[g] = true
	shine.Parent = frame
	return shine
end

local function applyStyle(frame: GuiObject, style, radius: UDim, shineZ: number, active: boolean)
	local grad = frame:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = style.color
		grad.Rotation = style.rotation
		animatedGradients[grad] = (style.animated and active) or nil
		if not style.animated then
			grad.Offset = Vector2.zero
		end
	end
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local shine = ensureShine(frame, radius, shineZ)
	shine.Visible = style.shine == true and active
end

local LOCKED_TEXT = Color3.fromRGB(150, 150, 160)
local GREEN = Color3.fromRGB(60, 255, 100)
local WHITE = Color3.new(1, 1, 1)
local DARK_STROKE = Color3.fromRGB(14, 10, 28)

-- Bordure des cartes debloquees : degrade de la couleur qui tourne.
local borderGradients = {} -- UIGradient -> phase
local hoveredCard: Frame? = nil
local newlySeen = {} -- [card] = true (sticker NEW! a retirer a la fermeture)

local function borderSeq(c: Color3)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, c:Lerp(WHITE, 0.75)),
		ColorSequenceKeypoint.new(0.25, c),
		ColorSequenceKeypoint.new(0.5, c:Lerp(Color3.new(0, 0, 0), 0.35)),
		ColorSequenceKeypoint.new(0.75, c),
		ColorSequenceKeypoint.new(1, c:Lerp(WHITE, 0.75)),
	})
end

local function tween(inst, t, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function addHoverScale(button: GuiButton, hoverScale: number)
	local uiScale = Instance.new("UIScale")
	uiScale.Name = "HoverScale"
	uiScale.Parent = button
	button.MouseEnter:Connect(function() tween(uiScale, 0.12, { Scale = hoverScale }) end)
	button.MouseLeave:Connect(function() tween(uiScale, 0.12, { Scale = 1 }) end)
	button.MouseButton1Down:Connect(function() tween(uiScale, 0.08, { Scale = hoverScale * 0.94 }) end)
	button.MouseButton1Up:Connect(function() tween(uiScale, 0.08, { Scale = hoverScale }) end)
end

--== References ==--
local screenGui = player:WaitForChild("PlayerGui"):WaitForChild("IndexUI")
local openButton = screenGui:WaitForChild("IndexButton") :: TextButton
local newBadge = openButton:WaitForChild("NewBadge") :: Frame
local badgePulse = newBadge:WaitForChild("Pulse") :: UIScale

local overlay = screenGui:WaitForChild("Overlay") :: Frame
local modal = overlay:WaitForChild("Holder"):WaitForChild("IndexModal") :: Frame
local openScale = modal:WaitForChild("OpenScale") :: UIScale
local tabsFrame = modal:WaitForChild("Tabs") :: ScrollingFrame
local tabTemplate = tabsFrame:WaitForChild("TabTemplate") :: TextButton
local main = modal:WaitForChild("Main") :: Frame
local titleBar = main:WaitForChild("TitleBar")
local completedLabel = titleBar:WaitForChild("Completed") :: TextLabel
local collectedLabel = titleBar:WaitForChild("Collected") :: TextLabel
local closeButton = titleBar:WaitForChild("CloseButton") :: TextButton
local grid = main:WaitForChild("Grid") :: ScrollingFrame
local cardTemplate = main:WaitForChild("CardTemplate") :: Frame

addHoverScale(openButton, 1.06)
addHoverScale(closeButton, 1.1)

--== Donnees ==--
local data = nil
local discovered = {} -- [nomComplet] = true
local tabs = {} -- { key, prefix, button }
local cardsByTab = {} -- key -> { [nomComplet] = card }
local currentTab = "Normal"
local isModalOpen = false

local function fullName(tabKey: string, baseName: string): string
	for _, t in ipairs(tabs) do
		if t.key == tabKey then
			return t.prefix == "" and baseName or (t.prefix .. " " .. baseName)
		end
	end
	return baseName
end

local function multOf(tabKey: string): number
	for _, t in ipairs(tabs) do
		if t.key == tabKey then
			return t.mult
		end
	end
	return 1
end

--== Apercu 3D ==--
local YAW = math.rad(28)
local FOV = 30
local modelsFolder: Folder? = nil
task.spawn(function()
	modelsFolder = ReplicatedStorage:WaitForChild("IndexModels")
end)

local function buildViewport(name: string, parent: Instance, locked: boolean)
	local folder = modelsFolder or ReplicatedStorage:WaitForChild("IndexModels", 20)
	local src = folder and folder:WaitForChild(name, 10)
	if not (src and src:IsA("BasePart")) or not parent.Parent then
		return
	end
	local model = src:Clone()
	model.CFrame = CFrame.Angles(0, YAW, 0)

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.ZIndex = parent.ZIndex
	viewport.Ambient = Color3.fromRGB(165, 165, 165)
	viewport.LightColor = Color3.new(1, 1, 1)
	viewport.LightDirection = Vector3.new(0.4, -1, 0.8)
	if locked then
		viewport.ImageColor3 = Color3.new(0, 0, 0)
		viewport.ImageTransparency = 0.15
	end

	local size = model.Size
	local c, s = math.abs(math.cos(YAW)), math.abs(math.sin(YAW))
	local width = size.X * c + size.Z * s
	local depth = size.X * s + size.Z * c
	local half = math.max(width * 0.62, size.Y) / 2
	local dist = half / math.tan(math.rad(FOV / 2)) + depth / 2

	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.12, -dist), Vector3.new(0, -size.Y * 0.02, 0))
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	model.Parent = viewport
	viewport.Parent = parent
end

--== Cartes ==--
local function styleCard(card: Frame, tabKey: string, entry, name: string)
	local unlocked = discovered[name] == true
	local rarity = data.rarities[entry.rarity] or { name = entry.rarity, color = Color3.fromRGB(165, 165, 170) }
	local rarityColor = RARITY_COLORS[entry.rarity] or rarity.color

	-- Normal : couleur de la rarete ; mutation : matiere de la mutation.
	local style = tabKey == "Normal" and { color = raritySeq(rarityColor), rotation = 90 } or MUTATION_STYLES[tabKey]
		or { color = raritySeq(MUTATION_COLORS[tabKey] or rarityColor), rotation = 90 }
	if unlocked then
		applyStyle(card, style, UDim.new(0, 12), 6, true)
	else
		local grad = card:FindFirstChildOfClass("UIGradient")
		if grad then
			grad.Color = SHADE
			grad.Rotation = 90
			grad.Offset = Vector2.zero
			animatedGradients[grad] = nil
		end
		local base = tabKey == "Normal" and rarityColor or (MUTATION_COLORS[tabKey] or rarityColor)
		card.BackgroundColor3 = base:Lerp(LOCKED_BG, 0.7)
		ensureShine(card, UDim.new(0, 12), 6).Visible = false
	end
	card.Dim.Visible = not unlocked
	card.Lock.Visible = not unlocked

	-- Couleur "theme" de la carte (rarete en Normal, mutation sinon).
	local theme = tabKey == "Normal" and rarityColor or (MUTATION_COLORS[tabKey] or rarityColor)

	card.NameLabel.Text = unlocked and name or "???"
	card.Income.Text = NumberFormat.FormatPrice(math.floor(entry.income * multOf(tabKey) + 0.5)) .. "/s"
	card.Income.TextColor3 = unlocked and GREEN or LOCKED_TEXT
	card.Mutation.Text = tabKey == "Normal" and "NORMAL" or ("\u{2728} " .. tabKey:upper())
	card.Mutation.TextColor3 = unlocked and (tabKey == "Normal" and WHITE or theme:Lerp(WHITE, 0.35)) or LOCKED_TEXT

	-- Pastille de rarete
	local pill = card:FindFirstChild("RarityPill")
	local rarityLabel = pill and pill:FindFirstChild("Rarity") or card:FindFirstChild("Rarity")
	if rarityLabel then
		rarityLabel.Text = string.upper(rarity.name)
		rarityLabel.TextColor3 = unlocked and WHITE or LOCKED_TEXT
	end
	if pill then
		pill.BackgroundColor3 = unlocked and rarityColor or rarityColor:Lerp(LOCKED_BG, 0.75)
	end

	-- Halo derriere l'apercu
	local glow = card:FindFirstChild("Glow")
	if glow then
		glow.BackgroundColor3 = unlocked and theme:Lerp(WHITE, 0.55) or Color3.fromRGB(60, 60, 80)
		glow.BackgroundTransparency = unlocked and 0.62 or 0.85
		local inner = glow:FindFirstChild("Inner")
		if inner then
			inner.BackgroundColor3 = unlocked and WHITE or Color3.fromRGB(70, 70, 90)
			inner.BackgroundTransparency = unlocked and 0.5 or 0.85
		end
	end

	-- Bordure : degrade anime si debloque, sombre sinon
	local stroke = card:FindFirstChildOfClass("UIStroke")
	local border = stroke and stroke:FindFirstChild("BorderGrad")
	if stroke and border then
		if unlocked then
			stroke.Color = WHITE
			stroke.Thickness = 4
			border.Color = tabKey == "Rainbow" and RAINBOW or borderSeq(theme)
			borderGradients[border] = borderGradients[border] or math.random() * 360
		else
			stroke.Color = DARK_STROKE
			stroke.Thickness = 3.5
			border.Color = ColorSequence.new(WHITE)
			borderGradients[border] = nil
		end
	end

	local vp = card.Preview:FindFirstChild("Viewport")
	if vp then
		vp.ImageColor3 = unlocked and Color3.new(1, 1, 1) or Color3.new(0, 0, 0)
		vp.ImageTransparency = unlocked and 0 or 0.15
	end
end

-- Survol : la carte grossit, penche, et le brainrot tourne sur lui-meme.
local function hookCardHover(card: Frame)
	local pop = card:FindFirstChild("Pop") :: UIScale
	local dir = math.random() < 0.5 and -1 or 1
	card.MouseEnter:Connect(function()
		hoveredCard = card
		if pop then
			tween(pop, 0.18, { Scale = 1.06 }, Enum.EasingStyle.Back)
		end
	end)
	card.MouseLeave:Connect(function()
		if hoveredCard == card then
			hoveredCard = nil
		end
		if pop then
			tween(pop, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
		end
		local vp = card.Preview:FindFirstChild("Viewport")
		local m = vp and vp:FindFirstChildWhichIsA("BasePart")
		if m then
			m.CFrame = CFrame.Angles(0, YAW, 0)
		end
	end)
end

-- Les cartes visibles apparaissent en vague.
local function waveCards(tabKey: string)
	local list = {}
	for _, card in ipairs(grid:GetChildren()) do
		if card:IsA("Frame") and card:GetAttribute("Tab") == tabKey then
			table.insert(list, card)
		end
	end
	table.sort(list, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i, card in ipairs(list) do
		local pop = card:FindFirstChild("Pop")
		if pop and i <= 30 then
			pop.Scale = 0.3
			TweenService:Create(pop, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, false, 0.04 + (i - 1) * 0.03), { Scale = 1 }):Play()
		end
	end
end

local function buildTab(tabKey: string)
	if cardsByTab[tabKey] then
		return
	end
	local cards = {}
	cardsByTab[tabKey] = cards

	-- Tri : rarete puis revenu.
	local list = table.clone(data.brainrots)
	table.sort(list, function(a, b)
		local ra = data.rarities[a.rarity] and data.rarities[a.rarity].order or 0
		local rb = data.rarities[b.rarity] and data.rarities[b.rarity].order or 0
		if ra ~= rb then
			return ra < rb
		end
		return a.income < b.income
	end)

	for i, entry in ipairs(list) do
		local name = fullName(tabKey, entry.name)
		local card = cardTemplate:Clone()
		card.Name = name
		card.LayoutOrder = i
		card.Visible = currentTab == tabKey
		card:SetAttribute("Tab", tabKey)
		card.Parent = grid
		cards[name] = { card = card, entry = entry }
		hookCardHover(card)
		styleCard(card, tabKey, entry, name)
		task.spawn(function()
			buildViewport(name, card.Preview, not discovered[name])
			styleCard(card, tabKey, entry, name)
		end)
	end
end

local function refreshCounts()
	local total = #data.brainrots * #tabs
	local got = 0
	for _, t in ipairs(tabs) do
		local n = 0
		for _, entry in ipairs(data.brainrots) do
			if discovered[fullName(t.key, entry.name)] then
				n += 1
			end
		end
		got += n
		t.button.Count.Text = ("%d/%d"):format(n, #data.brainrots)
	end
	local pct = total > 0 and math.floor(got / total * 100) or 0
	completedLabel.Text = ("%d%% COMPLETE"):format(pct)
	collectedLabel.Text = ("%d/%d COLLECTED"):format(got, total)
end

local function selectTab(tabKey: string)
	currentTab = tabKey
	buildTab(tabKey)
	for _, card in ipairs(grid:GetChildren()) do
		if card:IsA("Frame") then
			card.Visible = card:GetAttribute("Tab") == tabKey
		end
	end
	for _, t in ipairs(tabs) do
		local selected = t.key == tabKey
		tween(t.button.SelectScale, 0.12, { Scale = selected and 1.05 or 0.95 })
		t.button.UIStroke.Color = selected and Color3.new(1, 1, 1) or Color3.fromRGB(10, 10, 20)
		t.button.UIStroke.Thickness = selected and 4 or 3
	end
	grid.CanvasPosition = Vector2.zero
end

local function buildTabs()
	local list = { { key = "Normal", prefix = "", mult = 1 } }
	for _, m in ipairs(data.mutations) do
		table.insert(list, { key = m.key, prefix = m.prefix, mult = m.mult })
	end
	for i, t in ipairs(list) do
		local button = tabTemplate:Clone()
		button.Name = t.key
		button.LayoutOrder = i
		button.Visible = true
		button.Label.Text = t.key
		applyStyle(button, MUTATION_STYLES[t.key] or { color = raritySeq(MUTATION_COLORS[t.key] or Color3.fromRGB(200, 195, 190)), rotation = 90 }, UDim.new(0, 12), 4, true)
		button.Parent = tabsFrame
		t.button = button
		addHoverScale(button, 1.04)
		button.MouseButton1Click:Connect(function()
			if currentTab ~= t.key then
				UISounds.Play("Popup")
				selectTab(t.key)
			end
		end)
		table.insert(tabs, t)
	end
end

--== Colonne LIMITED ==--
local limitedPanel = modal:WaitForChild("LimitedPanel")
local limitedList = limitedPanel:WaitForChild("List")
local limitedTemplate = limitedPanel:WaitForChild("LimitedCardTemplate")
local limitedCount = limitedPanel:WaitForChild("TitleBar"):WaitForChild("Count")
local limitedCards = {} -- nom -> { card, drop, vp, setYaw }
local hoveredLimited = nil

local function styleLimited(entry)
	local card, drop = entry.card, entry.drop
	local unlocked = discovered[drop.name] == true
	local color = drop.color or Color3.fromRGB(255, 60, 150)
	card.BackgroundColor3 = unlocked and color or color:Lerp(LOCKED_BG, 0.75)
	card.NameLabel.Text = unlocked and drop.name or "???"
	card.NameLabel.TextColor3 = unlocked and WHITE or LOCKED_TEXT
	card.Percent.Text = ("%d%% OF BEST"):format(drop.percent or 0)
	card.Percent.TextColor3 = unlocked and GREEN or LOCKED_TEXT
	local pillText = "LIMITED \u{2022} SHOP"
	if drop.chance then
		local c = ShopConfig.GetChancePercent(drop.name)
		pillText = ("LIMITED \u{2022} %s%%"):format(c >= 1 and tostring(math.floor(c + 0.5)) or ("%.1f"):format(c))
	end
	card.Pill.Text.Text = pillText
	card.Pill.BackgroundColor3 = unlocked and color:Lerp(Color3.new(0, 0, 0), 0.55) or Color3.fromRGB(30, 30, 42)
	card.Lock.Visible = not unlocked
	card.Glow.BackgroundColor3 = unlocked and color:Lerp(WHITE, 0.55) or Color3.fromRGB(60, 60, 80)
	card.Glow.BackgroundTransparency = unlocked and 0.55 or 0.85
	if entry.vp then
		entry.vp.ImageColor3 = unlocked and WHITE or Color3.new(0, 0, 0)
		entry.vp.ImageTransparency = unlocked and 0 or 0.2
	end
	local stroke = card:FindFirstChildOfClass("UIStroke")
	local border = stroke and stroke:FindFirstChild("BorderGrad")
	if stroke and border then
		if unlocked then
			stroke.Color = WHITE
			stroke.Thickness = 4
			border.Color = (drop.percent or 0) >= 200 and RAINBOW or borderSeq(color)
			borderGradients[border] = borderGradients[border] or math.random() * 360
		else
			stroke.Color = DARK_STROKE
			stroke.Thickness = 3.5
			border.Color = ColorSequence.new(WHITE)
			borderGradients[border] = nil
		end
	end
end

local function refreshLimitedCount()
	local n = 0
	for _, e in pairs(limitedCards) do
		if discovered[e.drop.name] then
			n += 1
		end
	end
	limitedCount.Text = ("%d/%d COLLECTED"):format(n, #LIMITED)
end

local function buildLimited()
	for i, drop in ipairs(LIMITED) do
		local card = limitedTemplate:Clone()
		card.Name = drop.name
		card.LayoutOrder = i
		card.Visible = true
		card.Parent = limitedList
		local entry = { card = card, drop = drop }
		limitedCards[drop.name] = entry
		local vp, setYaw = ShopViewports.Build(drop.name, card.Preview, { yaw = 25, zoom = 0.95 })
		entry.vp, entry.setYaw = vp, setYaw
		styleLimited(entry)
		local pop = card:FindFirstChild("Pop")
		card.MouseEnter:Connect(function()
			hoveredLimited = entry
			if pop then
				tween(pop, 0.18, { Scale = 1.04 }, Enum.EasingStyle.Back)
			end
		end)
		card.MouseLeave:Connect(function()
			if hoveredLimited == entry then
				hoveredLimited = nil
			end
			if pop then
				tween(pop, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
			end
			entry.setYaw(25)
		end)
	end
	refreshLimitedCount()
end

local loading = false
local function loadData(): boolean
	if data then
		return true
	end
	if loading then
		while loading do
			task.wait()
		end
		return data ~= nil
	end
	loading = true
	local ok, result = pcall(function()
		return getIndexData:InvokeServer()
	end)
	loading = false
	if not ok or not result or data then
		return data ~= nil
	end
	data = result
	for _, name in ipairs(result.discovered) do
		discovered[name] = true
	end
	local normal = {}
	for _, e in ipairs(result.brainrots) do
		if not limitedSet[e.name] then
			table.insert(normal, e)
		end
	end
	data.brainrots = normal
	buildTabs()
	buildLimited()
	refreshCounts()
	selectTab("Normal")
	return true
end

--== Mise a l'echelle ecran ==--
local function getFitScale(): number
	local camera = workspace.CurrentCamera
	local vp = camera and camera.ViewportSize or Vector2.new(1280, 720)
	return math.clamp(math.min(vp.Y * 0.88 / MODAL_HEIGHT, vp.X * 0.94 / MODAL_WIDTH, 1), 0.3, 1)
end

local function bindViewport()
	local camera = workspace.CurrentCamera
	if not camera then return end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if isModalOpen then
			openScale.Scale = getFitScale()
		end
	end)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindViewport)
bindViewport()

--== Animations continues ==--
local clock = 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	if newBadge.Visible then
		badgePulse.Scale = 1 + math.abs(math.sin(clock * 4)) * 0.18
	end
	if isModalOpen then
		-- Bordures qui tournent (cartes de l'onglet courant seulement)
		for g, phase in pairs(borderGradients) do
			if g.Parent then
				local card = g.Parent.Parent
				if card and card.Visible then
					g.Rotation = (phase + clock * 110) % 360
				end
			else
				borderGradients[g] = nil
			end
		end
		-- Brainrot survole qui tourne
		if hoveredLimited and hoveredLimited.setYaw then
			hoveredLimited.setYaw(25 + clock * 140)
		end
		if hoveredCard and hoveredCard.Parent then
			local vp = hoveredCard.Preview:FindFirstChild("Viewport")
			local m = vp and vp:FindFirstChildWhichIsA("BasePart")
			if m then
				m.CFrame = CFrame.Angles(0, YAW + clock * 2.4, 0)
			end
		end
		-- Stickers NEW!
		for card in pairs(newlySeen) do
			local tag = card:FindFirstChild("NewTag")
			local pulse = tag and tag:FindFirstChild("Pulse")
			if pulse then
				pulse.Scale = 1 + math.abs(math.sin(clock * 5)) * 0.15
			end
		end
		for g in pairs(animatedGradients) do
			if g.Parent then
				g.Offset = Vector2.new(math.sin(clock * 1.5) * 0.5, 0)
			else
				animatedGradients[g] = nil
			end
		end
		-- reflet toutes les 2.5s
		local shineOffset = Vector2.new(math.min((clock % 2.5) / 1.2, 1) * 2 - 1, 0)
		for g in pairs(shineGradients) do
			if g.Parent then
				g.Offset = shineOffset
			else
				shineGradients[g] = nil
			end
		end
	end
end)

--== Ouverture / fermeture ==--
local function openModal()
	if isModalOpen then return end
	if not data and not loadData() then
		return
	end
	isModalOpen = true
	newBadge.Visible = false
	UISounds.Play("Popup")
	overlay.Visible = true
	overlay.BackgroundTransparency = 1
	openScale.Scale = 0
	tween(overlay, 0.18, { BackgroundTransparency = 0.45 })
	tween(openScale, 0.32, { Scale = getFitScale() }, Enum.EasingStyle.Back)
end

local function closeModal()
	if not isModalOpen then return end
	isModalOpen = false
	-- Les stickers NEW! vus disparaissent a la fermeture.
	for card in pairs(newlySeen) do
		local tag = card:FindFirstChild("NewTag")
		if tag then
			tag.Visible = false
		end
	end
	table.clear(newlySeen)
	UISounds.Play("Close")
	tween(openScale, 0.15, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tween(overlay, 0.15, { BackgroundTransparency = 1 }).Completed:Connect(function()
		if not isModalOpen then
			overlay.Visible = false
		end
	end)
end

openButton.MouseButton1Click:Connect(function()
	if isModalOpen then closeModal() else openModal() end
end)
closeButton.MouseButton1Click:Connect(closeModal)

--== Nouveau brainrot debloque ==--
indexUpdated.OnClientEvent:Connect(function(name: string)
	if discovered[name] then return end
	discovered[name] = true
	if not data then
		newBadge.Visible = true
		return
	end
	local le = limitedCards[name]
	if le then
		styleLimited(le)
		refreshLimitedCount()
		le.card.NewTag.Visible = true
		newlySeen[le.card] = true
		if isModalOpen then
			le.card.Pop.Scale = 1.15
			tween(le.card.Pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
		else
			newBadge.Visible = true
		end
		return
	end
	for tabKey, cards in pairs(cardsByTab) do
		local c = cards[name]
		if c then
			styleCard(c.card, tabKey, c.entry, name)
			local tag = c.card:FindFirstChild("NewTag")
			if tag then
				tag.Visible = true
				newlySeen[c.card] = true
			end
			if isModalOpen and c.card.Visible then
				c.card.Pop.Scale = 1.2
				tween(c.card.Pop, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end
	end
	refreshCounts()
	if not isModalOpen then
		newBadge.Visible = true
	end
end)

-- Prechargement en arriere-plan pour une ouverture instantanee.
task.spawn(function()
	if not data then
		loadData()
	end
end)
