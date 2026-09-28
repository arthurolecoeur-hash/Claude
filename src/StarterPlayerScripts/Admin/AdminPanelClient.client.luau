--[[
	AdminPanelClient
	----------------
	- Annonces globales (tout le monde) : bandeau en haut de l'ecran.
	- Cadeaux admin : popup "GIFT" chez le joueur qui recoit.
	- Panneau admin (admins seulement) : bouton ADMIN en haut a droite ou
	  /admin dans le chat. 3 onglets :
	    WEATHER : lancer / arreter une meteo (dont ADMIN ABUSE) + duree
	    GIVE    : donner a un joueur (ou a tout le serveur) une base, un
	              game pass, des lucky blocks, un brainrot du shop, des
	              lucky rolls ou du cash
	    SERVER  : annonce globale + stock du shop
	Telephone : la fenetre s'adapte a l'ecran. Manette : navigation au
	D-pad, B pour fermer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local AdminFolder = ReplicatedStorage:WaitForChild("Admin")
local remote = AdminFolder:WaitForChild("AdminRemote") :: RemoteFunction
local event = AdminFolder:WaitForChild("AdminEvent") :: RemoteEvent
local AdminConfig = require(AdminFolder:WaitForChild("AdminConfig"))
local WeatherShared = require(ReplicatedStorage:WaitForChild("WeatherShared"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("Shop"):WaitForChild("ShopConfig"))
local BaseSkinShared = require(ReplicatedStorage:WaitForChild("BaseSkinShared"))
local TraitShared = require(ReplicatedStorage:WaitForChild("Traits"):WaitForChild("TraitShared"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local UI = require(ReplicatedStorage:WaitForChild("UIKit"))

local C = UI.C
local WHITE, BLACK = C.white, C.black
local RED = Color3.fromRGB(255, 35, 50)
local DARK = Color3.fromRGB(26, 9, 14)
local GOLD = Color3.fromRGB(255, 205, 60)

local W, H = 720, 640

local gui = Instance.new("ScreenGui")
gui.Name = "AdminGui"
-- Animations deja gerees ici (UIKit) : UIJuice ne doit pas ajouter les siennes.
gui:SetAttribute("NoJuice", true)
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local function button(parent: Instance, label: string, color: Color3, textSize: number?)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = WHITE
	b.Text = ""
	b.ZIndex = (parent:IsA("GuiObject") and parent.ZIndex or 1) + 1
	b.Parent = parent
	UI.corner(b, 10)
	UI.stroke(b, 3, BLACK)
	local g = UI.gradient(b, color:Lerp(WHITE, 0.18), color:Lerp(BLACK, 0.32))
	g.Name = "Fill"
	local l = UI.text(b, label, textSize or 20, WHITE, UI.FONT_TITLE)
	l.Name = "Label"
	l.Size = UDim2.new(1, -10, 1, -6)
	l.Position = UDim2.fromOffset(5, 3)
	l.ZIndex = b.ZIndex + 2
	UI.pressable(b)
	return b
end

local function setButtonColor(b: GuiButton, color: Color3)
	local g = b:FindFirstChild("Fill")
	if g then
		g.Color = ColorSequence.new(color:Lerp(WHITE, 0.18), color:Lerp(BLACK, 0.32))
	end
end

--== Annonces ==--
local announceHolder = Instance.new("Frame")
announceHolder.Name = "Announcements"
announceHolder.AnchorPoint = Vector2.new(0.5, 0)
announceHolder.Position = UDim2.new(0.5, 0, 0, 200)
announceHolder.Size = UDim2.fromOffset(640, 320)
announceHolder.BackgroundTransparency = 1
announceHolder.Parent = gui
UI.list(announceHolder, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center)
local annScale = Instance.new("UIScale")
annScale.Parent = announceHolder
UI.bindFit(680, 520, function(s)
	annScale.Scale = math.min(1, s)
end)

local annOrder = 0
local function showAnnouncement(data)
	annOrder += 1
	local color = typeof(data.color) == "Color3" and data.color or RED
	local card = Instance.new("CanvasGroup")
	card.LayoutOrder = annOrder
	card.Size = UDim2.fromOffset(620, 78)
	card.BackgroundColor3 = DARK
	card.BackgroundTransparency = 0.08
	card.GroupTransparency = 1
	card.Parent = announceHolder
	UI.corner(card, 14)
	UI.stroke(card, 3, color)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 10, 1, 0)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.Parent = card
	local tag = UI.text(card, "📢 " .. string.upper(tostring(data.from or "ADMIN")), 16, color, UI.FONT_TITLE)
	tag.Position = UDim2.fromOffset(24, 6)
	tag.Size = UDim2.new(1, -34, 0, 20)
	local msg = UI.text(card, tostring(data.text or ""), 26, WHITE)
	msg.Position = UDim2.fromOffset(24, 28)
	msg.Size = UDim2.new(1, -34, 0, 42)
	msg.TextWrapped = true
	UI.shine(card, 1.5, 0.12)
	local sc = UI.scaleOf(card)
	sc.Scale = 0.7
	UISounds.Play("Indicator")
	UI.tween(card, 0.25, { GroupTransparency = 0 })
	UI.tween(sc, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(6, function()
		UI.tween(sc, 0.35, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		UI.tween(card, 0.35, { GroupTransparency = 1 }).Completed:Wait()
		card:Destroy()
	end)
end

--== Popup cadeau (joueur qui recoit) ==--
local GIFT_ICONS = { BaseSkin = "🏠", Pass = "🎫", Lucky = "🍓", Direct = "🧠", TraitLuck = "🍀", Money = "💵" }

local function showGift(data)
	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.42)
	root.Size = UDim2.fromOffset(460, 230)
	root.BackgroundTransparency = 1
	root.ZIndex = 300
	root.Parent = gui
	local fit = Instance.new("UIScale")
	fit.Scale = math.min(1, UI.fitScale(480, 260))
	fit.Parent = root

	local rays = Instance.new("ImageLabel")
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.45)
	rays.Size = UDim2.fromOffset(520, 520)
	rays.BackgroundTransparency = 1
	rays.Image = "rbxassetid://6120458939"
	rays.ImageColor3 = GOLD
	rays.ImageTransparency = 0.35
	rays.ZIndex = 300
	rays.Parent = root

	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = WHITE
	card.ZIndex = 301
	card.Parent = root
	UI.corner(card, 18)
	UI.stroke(card, 5, BLACK)
	UI.gradient(card, Color3.fromRGB(255, 225, 90), Color3.fromRGB(255, 140, 20))
	UI.studs(card, 34, 0.84, 18)
	local head = UI.text(card, "🎁 ADMIN GIFT!", 44, WHITE, UI.FONT_TITLE, 4)
	head.Position = UDim2.fromOffset(0, 14)
	head.Size = UDim2.new(1, 0, 0, 50)
	head.ZIndex = 303
	local icon = UI.text(card, GIFT_ICONS[data.kind] or "🎁", 70, WHITE)
	icon.Position = UDim2.fromOffset(0, 64)
	icon.Size = UDim2.new(1, 0, 0, 76)
	icon.ZIndex = 303
	local what = UI.text(card, tostring(data.text or ""), 34, WHITE, UI.FONT_TITLE, 3)
	what.Position = UDim2.fromOffset(12, 140)
	what.Size = UDim2.new(1, -24, 0, 40)
	what.ZIndex = 303
	local from = UI.text(card, "from " .. tostring(data.from or "an admin"), 22, Color3.fromRGB(90, 40, 0), UI.FONT)
	from.Position = UDim2.fromOffset(12, 184)
	from.Size = UDim2.new(1, -24, 0, 26)
	from.ZIndex = 303
	from:FindFirstChildOfClass("UIStroke").Color = Color3.fromRGB(255, 240, 200)

	UISounds.Play("Success")
	UI.pop(card, 0, 0.2)
	UI.burst(root, UDim2.fromScale(0.5, 0.5), { GOLD, RED, C.green, C.blue, WHITE }, 34, 260, 310)
	local t0 = os.clock()
	local conn = RunService.RenderStepped:Connect(function()
		rays.Rotation = (os.clock() - t0) * 40
	end)
	task.delay(3.4, function()
		UI.tween(UI.scaleOf(card), 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		UI.tween(rays, 0.3, { ImageTransparency = 1 }).Completed:Wait()
		conn:Disconnect()
		root:Destroy()
	end)
end

event.OnClientEvent:Connect(function(kind, data)
	if type(data) ~= "table" then
		return
	end
	if kind == "Announce" then
		showAnnouncement(data)
	elseif kind == "Gift" then
		showGift(data)
	end
end)

--== Panneau admin ==--
local built = false
local panel, openButton, panelScale
local isOpen = false
local fitScale = 1
local lastToggle = 0
local firstTab

local toastLabel
local toastToken = 0
local function toast(msg: string, color: Color3?)
	if not toastLabel then
		return
	end
	toastToken += 1
	local my = toastToken
	toastLabel.Text = msg
	toastLabel.TextColor3 = color or WHITE
	toastLabel.Visible = true
	UI.pop(toastLabel, 0, 0.6)
	task.delay(2.2, function()
		if my == toastToken then
			toastLabel.Visible = false
		end
	end)
end

-- Historique local des actions reussies (onglet SERVER).
local history: { { text: string, at: number } } = {}
local historyChanged: (() -> ())? = nil

local function feedback(ok: boolean, okMsg: string?, from: GuiObject?)
	UISounds.Play(ok and "Success" or "BuyFail")
	if ok then
		if okMsg then
			toast(okMsg, C.green)
			table.insert(history, 1, { text = okMsg, at = os.time() })
			if #history > 8 then
				table.remove(history)
			end
			if historyChanged then
				historyChanged()
			end
		end
		if from and panel then
			local p = from.AbsolutePosition + from.AbsoluteSize / 2 - panel.AbsolutePosition
			local s = panelScale.Scale
			UI.burst(panel, UDim2.fromOffset(p.X / s, p.Y / s), { GOLD, RED, WHITE }, 14, 90, 80)
		end
	else
		toast("FAILED", C.red)
		if from then
			UI.shake(from)
		end
	end
end

local function setOpen(open: boolean)
	if not panel or open == isOpen then
		return
	end
	if os.clock() - lastToggle < 0.2 then
		return
	end
	lastToggle = os.clock()
	isOpen = open
	if open then
		panel.Visible = true
		panelScale.Scale = fitScale * 0.8
		UI.tween(panelScale, 0.35, { Scale = fitScale }, Enum.EasingStyle.Back)
		UISounds.Play("Open")
		UI.PushModal("AdminPanel", function()
			setOpen(false)
		end, firstTab)
	else
		UISounds.Play("Swoosh")
		UI.PopModal("AdminPanel")
		UI.tween(panelScale, 0.15, { Scale = fitScale * 0.85 }).Completed:Connect(function()
			if not isOpen then
				panel.Visible = false
			end
		end)
	end
end

local function formatDuration(s: number): string
	if s >= 60 then
		local m = s / 60
		return m % 1 == 0 and ("%dm"):format(m) or ("%.1fm"):format(m)
	end
	return s .. "s"
end

local function scrolling(parent: Instance, pos: UDim2, size: UDim2)
	local sf = Instance.new("ScrollingFrame")
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.Position = pos
	sf.Size = size
	sf.ScrollBarThickness = 6
	sf.ScrollBarImageColor3 = GOLD
	sf.CanvasSize = UDim2.new()
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.ScrollingDirection = Enum.ScrollingDirection.Y
	sf.ZIndex = 5
	sf.Parent = parent
	return sf
end

local function sectionTitle(parent: Instance, str: string, y: number)
	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, y)
	pill.Size = UDim2.fromOffset(280, 24)
	pill.BackgroundColor3 = WHITE
	pill.ZIndex = 5
	pill.Parent = parent
	UI.round(pill)
	UI.stroke(pill, 2, BLACK)
	UI.gradient(pill, Color3.fromRGB(255, 225, 110), Color3.fromRGB(230, 150, 20))
	local l = UI.text(pill, str, 16, WHITE, UI.FONT_TITLE, 2)
	l.Size = UDim2.new(1, -12, 1, -2)
	l.Position = UDim2.fromOffset(6, 1)
	l.ZIndex = 6
	return pill
end

--== Onglet WEATHER ==--
local function buildWeatherPage(page: Frame)
	local selectedDuration = AdminConfig.DURATIONS[2] or 300
	local durButtons = {}

	local status = UI.text(page, "", 20, WHITE, UI.FONT_TITLE)
	status.Size = UDim2.new(1, 0, 0, 22)
	local barBg = Instance.new("Frame")
	barBg.AnchorPoint = Vector2.new(0.5, 0)
	barBg.Position = UDim2.new(0.5, 0, 0, 24)
	barBg.Size = UDim2.new(0.7, 0, 0, 8)
	barBg.BackgroundColor3 = Color3.fromRGB(30, 10, 14)
	barBg.ZIndex = 5
	barBg.Parent = page
	UI.round(barBg)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = WHITE
	bar.ZIndex = 6
	bar.Parent = barBg
	UI.round(bar)
	local lastTotal = 1
	local function refreshStatus()
		local w, left = WeatherShared.GetCurrent()
		if w then
			local l = math.floor(left)
			lastTotal = math.max(lastTotal, l)
			status.Text = ("NOW: <font color=\"#%s\">%s</font>  •  %d:%02d"):format(w.color:ToHex(), string.upper(w.name), l // 60, l % 60)
			bar.BackgroundColor3 = w.rainbow and Color3.fromRGB(190, 70, 255) or w.color
			bar.Size = UDim2.fromScale(math.clamp(l / lastTotal, 0, 1), 1)
		else
			lastTotal = 1
			status.Text = "NOW: <font color=\"#aaaaaa\">NO WEATHER</font>"
			bar.Size = UDim2.fromScale(0, 1)
		end
	end
	task.spawn(function()
		while page.Parent do
			refreshStatus()
			task.wait(0.5)
		end
	end)

	sectionTitle(page, "⛈ SUMMON WEATHER", 34)
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 60)
	grid.Size = UDim2.new(1, 0, 0, 200)
	grid.ZIndex = 5
	grid.Parent = page
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.new(1 / 3, -8, 0, 92)
	gl.CellPadding = UDim2.fromOffset(12, 12)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = grid
	local ICONS = { Lava = "🌋", Galaxy = "🌌", Hacker = "💻", Rainbow = "🌈", Admin = "👑" }
	for i, w in ipairs(WeatherShared.LIST) do
		local color = w.rainbow and Color3.fromRGB(190, 70, 255) or w.color
		local b = button(grid, "", color)
		b.LayoutOrder = w.adminOnly and 0 or i
		b.Label.Text = ("%s\n%s"):format(ICONS[w.key] or "☁", string.upper((w.name:gsub(" Weather", ""))))
		b.Label.Size = UDim2.new(1, -10, 1, -10)
		b.Label.Position = UDim2.fromOffset(5, 5)
		b.Label.UITextSizeConstraint.MaxTextSize = 26
		if w.rainbow then
			b.Fill.Color = UI.RAINBOW
			b.Fill.Rotation = 0
		end
		if w.adminOnly then
			UI.shine(b, 1.2)
			local boost = UI.text(b, ("x%d"):format(w.boost or WeatherShared.BOOST), 18, GOLD, UI.FONT_TITLE)
			boost.AnchorPoint = Vector2.new(1, 0)
			boost.Position = UDim2.new(1, -6, 0, 4)
			boost.Size = UDim2.fromOffset(60, 20)
			boost.TextXAlignment = Enum.TextXAlignment.Right
			boost.ZIndex = b.ZIndex + 4
		end
		b.Activated:Connect(function()
			local ok = remote:InvokeServer("Weather", w.key, selectedDuration)
			lastTotal = selectedDuration
			feedback(ok, ok and (w.name:upper() .. " STARTED!") or nil, b)
			refreshStatus()
		end)
	end

	sectionTitle(page, "⏱ DURATION", 272)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(0, 298)
	row.Size = UDim2.new(1, 0, 0, 52)
	row.ZIndex = 5
	row.Parent = page
	UI.list(row, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	local function refreshDur()
		for d, b in pairs(durButtons) do
			setButtonColor(b, d == selectedDuration and Color3.fromRGB(255, 185, 40) or Color3.fromRGB(80, 66, 84))
		end
	end
	for _, d in ipairs(AdminConfig.DURATIONS) do
		local b = button(row, formatDuration(d), Color3.fromRGB(80, 66, 84), 22)
		b.Size = UDim2.fromOffset(96, 50)
		durButtons[d] = b
		b.Activated:Connect(function()
			selectedDuration = d
			UISounds.Play("Tab")
			refreshDur()
		end)
	end
	refreshDur()

	local extend = button(page, "⏩ +1 MIN", Color3.fromRGB(40, 170, 90), 24)
	extend.Position = UDim2.fromOffset(0, 372)
	extend.Size = UDim2.new(0.5, -6, 0, 58)
	extend.Activated:Connect(function()
		local w, left = WeatherShared.GetCurrent()
		if not w then
			feedback(false, nil, extend)
			return
		end
		local ok = remote:InvokeServer("Weather", w.key, math.floor(left) + 60)
		lastTotal = math.floor(left) + 60
		feedback(ok, ok and (w.name:upper() .. " +1 MIN") or nil, extend)
		refreshStatus()
	end)
	local stop = button(page, "⏹ STOP", Color3.fromRGB(95, 95, 110), 24)
	stop.AnchorPoint = Vector2.new(1, 0)
	stop.Position = UDim2.new(1, 0, 0, 372)
	stop.Size = UDim2.new(0.5, -6, 0, 58)
	stop.Activated:Connect(function()
		local ok = remote:InvokeServer("StopWeather")
		feedback(ok, ok and "WEATHER STOPPED" or nil, stop)
		refreshStatus()
	end)
end

--== Onglet GIVE ==--
local function buildGivePage(page: Frame)
	local target: any = player.UserId
	local category = "BaseSkin"
	local targetButtons: { [any]: any } = {}

	sectionTitle(page, "🎯 TARGET", 0)
	local search = Instance.new("TextBox")
	search.Position = UDim2.fromOffset(0, 32)
	search.Size = UDim2.fromOffset(150, 48)
	search.BackgroundColor3 = Color3.fromRGB(15, 5, 8)
	search.FontFace = UI.FONT
	search.TextSize = 18
	search.TextColor3 = WHITE
	search.PlaceholderText = "🔍 Search..."
	search.PlaceholderColor3 = Color3.fromRGB(150, 120, 125)
	search.Text = ""
	search.ClearTextOnFocus = false
	search.ZIndex = 6
	search.Parent = page
	UI.corner(search, 10)
	UI.stroke(search, 3, BLACK)
	local targets = Instance.new("ScrollingFrame")
	targets.BackgroundTransparency = 1
	targets.BorderSizePixel = 0
	targets.Position = UDim2.fromOffset(160, 28)
	targets.Size = UDim2.new(1, -160, 0, 58)
	targets.ScrollBarThickness = 4
	targets.ScrollingDirection = Enum.ScrollingDirection.X
	targets.AutomaticCanvasSize = Enum.AutomaticSize.X
	targets.CanvasSize = UDim2.new()
	targets.ZIndex = 5
	targets.Parent = page
	UI.list(targets, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	-- RANDOM : donne a N joueurs tires au hasard (re-cliquer change N).
	local RANDOM_COUNTS = { 1, 2, 3, 5, 10 }
	local randomIndex = 1
	local function refreshRandomLabel()
		local b = targetButtons["RANDOM"]
		if b then
			b.Label.Text = ("🎲 RANDOM x%d"):format(RANDOM_COUNTS[randomIndex])
		end
	end

	local info = UI.text(page, "", 18, WHITE, UI.FONT_TITLE, 2)
	info.Position = UDim2.fromOffset(0, 88)
	info.Size = UDim2.new(1, 0, 0, 22)

	local function cashOf(p: Player): string
		local ls = p:FindFirstChild("leaderstats")
		local v = ls and ls:FindFirstChild("Cash")
		if v and v:IsA("ValueBase") then
			return "$" .. NumberFormat.Format(tonumber((v :: any).Value) or 0)
		end
		return "?"
	end

	local function refreshInfo()
		if target == "ALL" then
			info.Text = ("GIVING TO: <font color=\"#FFD23C\">EVERYONE (%d)</font>"):format(#Players:GetPlayers())
		elseif target == "RANDOM" then
			info.Text = ("GIVING TO: <font color=\"#FFD23C\">%d RANDOM PLAYER(S)</font>"):format(RANDOM_COUNTS[randomIndex])
		else
			local p = Players:GetPlayerByUserId(target)
			info.Text = p and ("GIVING TO: <font color=\"#FFD23C\">%s</font>  •  %s"):format(p.DisplayName:upper(), cashOf(p)) or ""
		end
	end
	task.spawn(function()
		while page.Parent do
			if isOpen then
				refreshInfo()
			end
			task.wait(1)
		end
	end)

	local function refreshTargets()
		for who, b in pairs(targetButtons) do
			setButtonColor(b, who == target and Color3.fromRGB(255, 185, 40) or Color3.fromRGB(70, 58, 78))
		end
		refreshInfo()
	end

	local function applySearch()
		local q = search.Text:lower()
		for _, b in pairs(targetButtons) do
			local name = b:GetAttribute("SearchName")
			b.Visible = q == "" or name == nil or string.find(name, q, 1, true) ~= nil
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(applySearch)

	local function addTarget(who: any, label: string, order: number, userId: number?)
		local b = button(targets, label, Color3.fromRGB(70, 58, 78), 17)
		b.LayoutOrder = order
		b.Size = UDim2.fromOffset(150, 52)
		if userId then
			local img = Instance.new("ImageLabel")
			img.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
			img.Position = UDim2.fromOffset(6, 6)
			img.Size = UDim2.fromOffset(40, 40)
			img.ZIndex = b.ZIndex + 3
			img.Parent = b
			UI.round(img)
			task.spawn(function()
				local ok, content = pcall(function()
					return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				end)
				if ok then
					img.Image = content
				end
			end)
			b.Label.Position = UDim2.fromOffset(50, 3)
			b.Label.Size = UDim2.new(1, -56, 1, -6)
			b:SetAttribute("SearchName", label:lower())
		end
		targetButtons[who] = b
		b.Activated:Connect(function()
			if who == "RANDOM" and target == "RANDOM" then
				randomIndex = randomIndex % #RANDOM_COUNTS + 1
				refreshRandomLabel()
				UI.pop(b.Label, 0, 0.6)
			end
			target = who
			UISounds.Play("Tab")
			refreshTargets()
		end)
	end

	local function rebuildTargets()
		for _, b in pairs(targetButtons) do
			b:Destroy()
		end
		table.clear(targetButtons)
		addTarget("ALL", "🌍 EVERYONE", 0)
		addTarget("RANDOM", "", -1)
		refreshRandomLabel()
		for i, p in ipairs(Players:GetPlayers()) do
			addTarget(p.UserId, p == player and "ME" or p.DisplayName, p == player and 1 or i + 1, p.UserId)
		end
		if type(target) == "number" and not Players:GetPlayerByUserId(target) then
			target = player.UserId
		end
		refreshTargets()
		applySearch()
	end
	Players.PlayerAdded:Connect(rebuildTargets)
	Players.PlayerRemoving:Connect(function()
		task.defer(rebuildTargets)
	end)
	rebuildTargets()

	sectionTitle(page, "📦 WHAT", 114)
	local cats = Instance.new("Frame")
	cats.BackgroundTransparency = 1
	cats.Position = UDim2.fromOffset(0, 142)
	cats.Size = UDim2.new(1, 0, 0, 44)
	cats.ZIndex = 5
	cats.Parent = page
	local cl = Instance.new("UIGridLayout")
	cl.CellSize = UDim2.new(1 / 6, -7, 1, 0)
	cl.CellPadding = UDim2.fromOffset(8, 0)
	cl.SortOrder = Enum.SortOrder.LayoutOrder
	cl.Parent = cats

	local items = scrolling(page, UDim2.fromOffset(0, 194), UDim2.new(1, 0, 1, -194))
	local il = Instance.new("UIGridLayout")
	il.CellSize = UDim2.new(1 / 3, -8, 0, 86)
	il.CellPadding = UDim2.fromOffset(12, 12)
	il.SortOrder = Enum.SortOrder.LayoutOrder
	il.Parent = items
	UI.padding(items, 4)

	local CATEGORIES = {
		{ key = "BaseSkin", label = "🏠 BASES", color = Color3.fromRGB(255, 70, 80) },
		{ key = "Pass", label = "🎫 PASSES", color = Color3.fromRGB(255, 180, 0) },
		{ key = "Lucky", label = "🍓 LUCKY", color = Color3.fromRGB(255, 70, 150) },
		{ key = "Direct", label = "🧠 SHOP", color = Color3.fromRGB(40, 220, 110) },
		{ key = "TraitLuck", label = "🍀 ROLLS", color = Color3.fromRGB(90, 230, 70) },
		{ key = "Money", label = "💵 CASH", color = Color3.fromRGB(70, 170, 255) },
	}
	local catButtons = {}

	local function entries(key: string)
		local out = {}
		if key == "BaseSkin" then
			for _, s in ipairs(BaseSkinShared.SKINS) do
				if s.key ~= "Normal" then
					table.insert(out, { arg = s.key, label = s.name:upper(), sub = ("x%s CASH"):format(tostring(s.mult)), color = s.rainbow and Color3.fromRGB(190, 70, 255) or s.color })
				end
			end
		elseif key == "Pass" then
			for _, p in ipairs(ShopConfig.PASSES) do
				table.insert(out, { arg = p.key, label = p.title, sub = "GAME PASS", color = p.color })
			end
		elseif key == "Lucky" then
			for _, n in ipairs({ 1, 3, 8, 25, 50, 100 }) do
				table.insert(out, { arg = n, label = ("x%d"):format(n), sub = "LUCKY BLOCK" .. (n > 1 and "S" or ""), color = Color3.fromRGB(255, 70, 120) })
			end
		elseif key == "Direct" then
			for _, d in ipairs(ShopConfig.DIRECT_BUYS) do
				table.insert(out, { arg = d.key, label = d.name:upper(), sub = ("%d%% OF BEST"):format(d.percent), color = d.color })
			end
		elseif key == "TraitLuck" then
			for _, n in ipairs({ 1, 5, 10, 25, 100, 500 }) do
				table.insert(out, { arg = n, label = ("x%d"):format(n), sub = ("%dx LUCK ROLL%s"):format(TraitShared.LUCK_MULT, n > 1 and "S" or ""), color = Color3.fromRGB(70, 200, 70) })
			end
		elseif key == "Money" then
			for _, n in ipairs({ 1e3, 1e6, 1e9, 1e12, 1e15, 1e18 }) do
				table.insert(out, { arg = n, label = "$" .. NumberFormat.Format(n), sub = "CASH", color = Color3.fromRGB(60, 200, 90) })
			end
		end
		return out
	end

	local customBox, customRow
	-- EVERYONE / RANDOM : deuxieme clic pour confirmer (evite les dons par erreur).
	local pendingFrom: GuiObject? = nil
	local pendingAt = 0
	local function give(arg: any, from: GuiObject?)
		if (target == "ALL" or target == "RANDOM") and not (pendingFrom == from and os.clock() - pendingAt < 2.5) then
			pendingFrom = from
			pendingAt = os.clock()
			UISounds.Play("Tab")
			toast("CLICK AGAIN TO CONFIRM", GOLD)
			if from then
				UI.shake(from, 4)
			end
			return
		end
		pendingFrom = nil
		local sendTo = target == "RANDOM" and ("RANDOM:" .. RANDOM_COUNTS[randomIndex]) or target
		local ok = remote:InvokeServer("Give", sendTo, { kind = category, arg = arg })
		local who
		if target == "ALL" then
			who = "EVERYONE"
		elseif target == "RANDOM" then
			who = ("%d RANDOM PLAYER%s"):format(RANDOM_COUNTS[randomIndex], RANDOM_COUNTS[randomIndex] > 1 and "S" or "")
		elseif target == player.UserId then
			who = "YOU"
		else
			local p = Players:GetPlayerByUserId(target)
			who = p and p.DisplayName:upper() or "?"
		end
		feedback(ok, ok and ("GIVEN TO " .. who .. "!") or nil, from)
	end

	local function fillItems()
		for _, c in ipairs(items:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for order, e in ipairs(entries(category)) do
			local b = button(items, e.label, e.color, 22)
			b.LayoutOrder = order
			b.Label.Size = UDim2.new(1, -10, 0, 34)
			b.Label.Position = UDim2.fromOffset(5, 12)
			local sub = UI.text(b, e.sub, 15, Color3.fromRGB(255, 255, 255), UI.FONT)
			sub.Position = UDim2.fromOffset(5, 48)
			sub.Size = UDim2.new(1, -10, 0, 20)
			sub.ZIndex = b.ZIndex + 3
			sub.TextTransparency = 0.1
			b.Activated:Connect(function()
				give(e.arg, b)
			end)
			UI.pop(b, (order - 1) * 0.03, 0.6)
		end
		customRow.Visible = category == "Lucky" or category == "TraitLuck" or category == "Money"
		items.Size = customRow.Visible and UDim2.new(1, 0, 1, -252) or UDim2.new(1, 0, 1, -194)
	end

	customRow = Instance.new("Frame")
	customRow.BackgroundTransparency = 1
	customRow.AnchorPoint = Vector2.new(0, 1)
	customRow.Position = UDim2.new(0, 0, 1, 0)
	customRow.Size = UDim2.new(1, 0, 0, 50)
	customRow.ZIndex = 5
	customRow.Parent = page
	customBox = Instance.new("TextBox")
	customBox.Size = UDim2.new(1, -170, 1, 0)
	customBox.BackgroundColor3 = Color3.fromRGB(15, 5, 8)
	customBox.FontFace = UI.FONT
	customBox.TextSize = 22
	customBox.TextColor3 = WHITE
	customBox.PlaceholderText = "Custom amount (ex: 250, 5e12)..."
	customBox.PlaceholderColor3 = Color3.fromRGB(150, 120, 125)
	customBox.Text = ""
	customBox.ClearTextOnFocus = false
	customBox.ZIndex = 6
	customBox.Parent = customRow
	UI.corner(customBox, 10)
	UI.stroke(customBox, 3, BLACK)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.Parent = customBox
	local customGive = button(customRow, "🎁 GIVE", C.green, 24)
	customGive.AnchorPoint = Vector2.new(1, 0)
	customGive.Position = UDim2.new(1, 0, 0, 0)
	customGive.Size = UDim2.new(0, 158, 1, 0)
	customGive.Activated:Connect(function()
		local n = tonumber(customBox.Text)
		if not n or n < 1 then
			UISounds.Play("BuyFail")
			UI.shake(customBox)
			return
		end
		give(math.floor(n), customGive)
	end)

	local function refreshCats()
		for key, b in pairs(catButtons) do
			local cat
			for _, c in ipairs(CATEGORIES) do
				if c.key == key then
					cat = c
				end
			end
			setButtonColor(b, key == category and cat.color or Color3.fromRGB(70, 58, 78))
		end
	end
	for i, cat in ipairs(CATEGORIES) do
		local b = button(cats, cat.label, Color3.fromRGB(70, 58, 78), 16)
		b.LayoutOrder = i
		catButtons[cat.key] = b
		b.Activated:Connect(function()
			if category == cat.key then
				return
			end
			category = cat.key
			UISounds.Play("Tab")
			refreshCats()
			fillItems()
		end)
	end
	refreshCats()
	fillItems()
end

--== Onglet SERVER ==--
local function buildServerPage(page: Frame)
	sectionTitle(page, "📢 ANNOUNCE (everyone)", 0)
	local box = Instance.new("TextBox")
	box.Position = UDim2.fromOffset(0, 26)
	box.Size = UDim2.new(1, -150, 0, 52)
	box.BackgroundColor3 = Color3.fromRGB(15, 5, 8)
	box.FontFace = UI.FONT
	box.TextSize = 22
	box.TextColor3 = WHITE
	box.PlaceholderText = "Message..."
	box.PlaceholderColor3 = Color3.fromRGB(150, 120, 125)
	box.Text = ""
	box.ClearTextOnFocus = false
	box.ZIndex = 6
	box.Parent = page
	UI.corner(box, 10)
	UI.stroke(box, 3, BLACK)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.Parent = box
	local send = button(page, "SEND", Color3.fromRGB(40, 200, 80), 24)
	send.AnchorPoint = Vector2.new(1, 0)
	send.Position = UDim2.new(1, 0, 0, 26)
	send.Size = UDim2.fromOffset(138, 52)
	local function doSend()
		if box.Text:match("^%s*$") then
			return
		end
		local ok = remote:InvokeServer("Announce", box.Text)
		feedback(ok, ok and "SENT!" or nil, send)
		if ok then
			box.Text = ""
		end
	end
	send.Activated:Connect(doSend)
	box.FocusLost:Connect(function(enter)
		if enter then
			doSend()
		end
	end)

	sectionTitle(page, "📦 SHOP STOCK", 92)
	local y = 122
	for _, d in ipairs(ShopConfig.DIRECT_BUYS) do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Color3.fromRGB(15, 5, 8)
		row.BackgroundTransparency = 0.25
		row.Position = UDim2.fromOffset(0, y)
		row.Size = UDim2.new(1, 0, 0, 62)
		row.ZIndex = 5
		row.Parent = page
		UI.corner(row, 12)
		UI.stroke(row, 2, d.color)
		local name = UI.text(row, d.name:upper(), 24, d.color, UI.FONT_TITLE)
		name.Position = UDim2.fromOffset(8, 0)
		name.Size = UDim2.new(0.36, -8, 1, 0)
		local left = UI.text(row, "", 22, GOLD, UI.FONT_TITLE)
		left.Position = UDim2.new(0.36, 0, 0, 0)
		left.Size = UDim2.new(0.64, -170, 1, 0)
		local function refresh()
			local v = ShopConfig.GetStockLeft(d.key)
			left.Text = v and ("%d / %d LEFT"):format(v, d.stock) or "..."
		end
		ReplicatedStorage.Shop:GetAttributeChangedSignal("StockLeft_" .. d.key):Connect(refresh)
		refresh()
		local rs = button(row, "RESTOCK", Color3.fromRGB(255, 160, 30), 20)
		rs.AnchorPoint = Vector2.new(1, 0.5)
		rs.Position = UDim2.new(1, -8, 0.5, 0)
		rs.Size = UDim2.fromOffset(150, 46)
		rs.Activated:Connect(function()
			local ok = remote:InvokeServer("Restock", d.key)
			feedback(ok, ok and "RESTOCKED!" or nil, rs)
		end)
		y += 72
	end

	sectionTitle(page, "🕘 RECENT ACTIONS", y + 4)
	local log = Instance.new("Frame")
	log.BackgroundColor3 = Color3.fromRGB(15, 5, 8)
	log.BackgroundTransparency = 0.3
	log.Position = UDim2.fromOffset(0, y + 34)
	log.Size = UDim2.new(1, 0, 1, -(y + 58))
	log.ZIndex = 5
	log.Parent = page
	UI.corner(log, 12)
	UI.padding(log, 8)
	UI.list(log, Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Center)
	local function renderHistory()
		for _, c in ipairs(log:GetChildren()) do
			if c:IsA("TextLabel") then
				c:Destroy()
			end
		end
		if #history == 0 then
			local l = UI.text(log, "Nothing yet", 16, Color3.fromRGB(170, 140, 145))
			l.Size = UDim2.new(1, 0, 0, 20)
		end
		for i, h in ipairs(history) do
			local l = UI.text(log, ("%s  <font color=\"#aa8c91\">%s</font>"):format(h.text, os.date("%H:%M", h.at)), 16, i == 1 and WHITE or Color3.fromRGB(215, 200, 205))
			l.LayoutOrder = i
			l.Size = UDim2.new(1, 0, 0, 20)
			l.ZIndex = 6
		end
	end
	historyChanged = renderHistory
	renderHistory()

	local hint = UI.text(page, "F2 = open/close  •  Chat: /admin  /abuse [sec]  /stopweather  /announce msg  /restock name", 15, Color3.fromRGB(200, 160, 165))
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, 0, 1, 0)
	hint.Size = UDim2.new(1, 0, 0, 18)
end

local function buildPanel()
	if built then
		return
	end
	built = true

	openButton = button(gui, "🛡 ADMIN", RED, 20)
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(1, -86, 0, 14)
	openButton.Size = UDim2.fromOffset(124, 46)
	UI.shine(openButton, 4)
	openButton.Activated:Connect(function()
		setOpen(not isOpen)
	end)

	panel = Instance.new("Frame")
	panel.Name = "AdminPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(W, H)
	panel.BackgroundColor3 = WHITE
	panel.Visible = false
	panel.Parent = gui
	UI.corner(panel, 18)
	UI.stroke(panel, 5, BLACK)
	panel.Active = true
	UI.gradient(panel, Color3.fromRGB(110, 28, 40), Color3.fromRGB(45, 10, 18))
	UI.studs(panel, 40, 0.9, 18, WHITE)
	panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	-- On peut deplacer le panneau en le tirant (souris / doigt).
	local drag = Instance.new("UIDragDetector")
	drag.Parent = panel

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 70)
	header.BackgroundColor3 = WHITE
	header.ZIndex = 3
	header.Parent = panel
	UI.corner(header, 18)
	UI.gradient(header, Color3.fromRGB(255, 70, 80), Color3.fromRGB(160, 10, 25))
	UI.studs(header, 30, 0.72, 18)
	local hb = Instance.new("Frame")
	hb.AnchorPoint = Vector2.new(0, 1)
	hb.Position = UDim2.fromScale(0, 1)
	hb.Size = UDim2.new(1, 0, 0, 4)
	hb.BackgroundColor3 = BLACK
	hb.BorderSizePixel = 0
	hb.ZIndex = 4
	hb.Parent = header

	local title = UI.text(header, "🛡 ADMIN PANEL 🛡", 42, WHITE, UI.FONT_TITLE, 4)
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.5)
	title.Size = UDim2.new(1, -150, 0, 52)
	title.ZIndex = 6
	UI.gradient(title, Color3.fromRGB(255, 240, 150), GOLD)
	UI.shine(header, 3)

	local close = button(header, "X", Color3.fromRGB(230, 50, 55), 32)
	close.AnchorPoint = Vector2.new(1, 0.5)
	close.Position = UDim2.new(1, -12, 0.5, -2)
	close.Size = UDim2.fromOffset(56, 50)
	close.ZIndex = 7
	close.Activated:Connect(function()
		setOpen(false)
	end)

	-- Onglets
	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(20, 84)
	tabBar.Size = UDim2.new(1, -40, 0, 50)
	tabBar.ZIndex = 4
	tabBar.Parent = panel
	local tl = Instance.new("UIGridLayout")
	tl.CellSize = UDim2.new(1 / 3, -8, 1, 0)
	tl.CellPadding = UDim2.fromOffset(12, 0)
	tl.SortOrder = Enum.SortOrder.LayoutOrder
	tl.Parent = tabBar

	local pagesHolder = Instance.new("Frame")
	pagesHolder.BackgroundTransparency = 1
	pagesHolder.ClipsDescendants = true
	pagesHolder.Position = UDim2.fromOffset(20, 146)
	pagesHolder.Size = UDim2.new(1, -40, 1, -166)
	pagesHolder.ZIndex = 4
	pagesHolder.Parent = panel

	toastLabel = UI.text(panel, "", 26, WHITE, UI.FONT_TITLE, 3)
	toastLabel.AnchorPoint = Vector2.new(0.5, 1)
	toastLabel.Position = UDim2.new(0.5, 0, 1, -12)
	toastLabel.Size = UDim2.fromOffset(420, 42)
	toastLabel.BackgroundColor3 = BLACK
	toastLabel.BackgroundTransparency = 0.25
	toastLabel.ZIndex = 90
	toastLabel.Visible = false
	UI.corner(toastLabel, 12)

	local TABS = {
		{ key = "WEATHER", label = "⛈ WEATHER", color = Color3.fromRGB(140, 70, 255), build = buildWeatherPage },
		{ key = "GIVE", label = "🎁 GIVE", color = Color3.fromRGB(40, 200, 90), build = buildGivePage },
		{ key = "SERVER", label = "📢 SERVER", color = Color3.fromRGB(255, 150, 20), build = buildServerPage },
	}
	local pages, tabButtons = {}, {}
	local current = nil
	local function showTab(key: string)
		if current == key then
			return
		end
		local prevIndex, nextIndex = 0, 0
		for i, t in ipairs(TABS) do
			if t.key == current then
				prevIndex = i
			end
			if t.key == key then
				nextIndex = i
			end
		end
		local dir = nextIndex > prevIndex and 1 or -1
		for k, pg in pairs(pages) do
			if k == key then
				pg.Visible = true
				pg.Position = UDim2.fromScale(0.25 * dir, 0)
				UI.tween(pg, 0.28, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back)
			elseif k == current then
				local old = pg
				UI.tween(old, 0.18, { Position = UDim2.fromScale(-1 * dir, 0) }).Completed:Connect(function()
					if current ~= k then
						old.Visible = false
					end
				end)
			else
				pg.Visible = false
			end
		end
		for _, t in ipairs(TABS) do
			setButtonColor(tabButtons[t.key], t.key == key and t.color or Color3.fromRGB(70, 58, 78))
		end
		current = key
	end
	for i, t in ipairs(TABS) do
		local b = button(tabBar, t.label, Color3.fromRGB(70, 58, 78), 22)
		b.LayoutOrder = i
		tabButtons[t.key] = b
		b.Activated:Connect(function()
			UISounds.Play("Tab")
			showTab(t.key)
		end)
		local page = Instance.new("Frame")
		page.Name = t.key
		page.BackgroundTransparency = 1
		page.Size = UDim2.fromScale(1, 1)
		page.Visible = false
		page.ZIndex = 4
		page.Parent = pagesHolder
		pages[t.key] = page
		t.build(page)
	end
	firstTab = tabButtons.WEATHER
	showTab("WEATHER")

	UI.bindFit(W, H, function(s)
		fitScale = s
		if isOpen then
			panelScale.Scale = s
		end
	end)
end

-- F2 : ouvrir / fermer le panneau.
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= Enum.KeyCode.F2 or player:GetAttribute("IsAdmin") ~= true then
		return
	end
	buildPanel()
	setOpen(not isOpen)
end)

local function checkAdmin()
	if player:GetAttribute("IsAdmin") == true then
		buildPanel()
	end
end
player:GetAttributeChangedSignal("IsAdmin"):Connect(checkAdmin)
checkAdmin()

local function onChat(text: string)
	if text:lower():match("^/admin$") and player:GetAttribute("IsAdmin") then
		buildPanel()
		setOpen(not isOpen)
	end
end
player.Chatted:Connect(onChat)
pcall(function()
	game:GetService("TextChatService").SendingMessage:Connect(function(msg)
		onChat(msg.Text)
	end)
end)
