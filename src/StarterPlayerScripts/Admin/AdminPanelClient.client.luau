--[[
	AdminPanelClient
	----------------
	- Annonces globales (tout le monde) : bandeau en haut de l'ecran.
	- Panneau admin (admins seulement) : bouton ADMIN en haut a droite ou
	  /admin dans le chat.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local AdminFolder = ReplicatedStorage:WaitForChild("Admin")
local remote = AdminFolder:WaitForChild("AdminRemote") :: RemoteFunction
local event = AdminFolder:WaitForChild("AdminEvent") :: RemoteEvent
local AdminConfig = require(AdminFolder:WaitForChild("AdminConfig"))
local WeatherShared = require(ReplicatedStorage:WaitForChild("WeatherShared"))
local ShopConfig = require(ReplicatedStorage:WaitForChild("Shop"):WaitForChild("ShopConfig"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))

local FONT_TITLE = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local RED = Color3.fromRGB(255, 35, 50)
local DARK = Color3.fromRGB(28, 10, 14)

local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end
local function stroke(p, t, color, mode)
	local s = Instance.new("UIStroke")
	s.Thickness = t
	s.Color = color or BLACK
	s.ApplyStrokeMode = mode or Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end
local function tween(i, t, props, style)
	local tw = TweenService:Create(i, TweenInfo.new(t, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function label(parent, text, size, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = font or FONT
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color or WHITE
	l.Parent = parent
	stroke(l, 2, BLACK, Enum.ApplyStrokeMode.Contextual)
	return l
end
local function button(parent, text, color, size)
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.BackgroundColor3 = color
	b.FontFace = FONT
	b.Text = text
	b.TextSize = size or 18
	b.TextColor3 = WHITE
	b.Parent = parent
	corner(b, 8)
	stroke(b, 2.5)
	stroke(b, 2, BLACK, Enum.ApplyStrokeMode.Contextual)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(WHITE, Color3.fromRGB(170, 170, 170))
	g.Rotation = 90
	g.Parent = b
	local sc = Instance.new("UIScale")
	sc.Parent = b
	b.MouseEnter:Connect(function() tween(sc, 0.1, { Scale = 1.05 }) end)
	b.MouseLeave:Connect(function() tween(sc, 0.1, { Scale = 1 }) end)
	b.MouseButton1Down:Connect(function() tween(sc, 0.06, { Scale = 0.95 }) end)
	b.MouseButton1Up:Connect(function() tween(sc, 0.1, { Scale = 1.05 }) end)
	return b
end

local gui = Instance.new("ScreenGui")
gui.Name = "AdminGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

--== Annonces ==--
local announceHolder = Instance.new("Frame")
announceHolder.Name = "Announcements"
announceHolder.AnchorPoint = Vector2.new(0.5, 0)
announceHolder.Position = UDim2.new(0.5, 0, 0, 230)
announceHolder.Size = UDim2.fromOffset(640, 300)
announceHolder.BackgroundTransparency = 1
announceHolder.Parent = gui
local annLayout = Instance.new("UIListLayout")
annLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
annLayout.Padding = UDim.new(0, 8)
annLayout.SortOrder = Enum.SortOrder.LayoutOrder
annLayout.Parent = announceHolder

local annOrder = 0
local function showAnnouncement(data)
	annOrder += 1
	local color = typeof(data.color) == "Color3" and data.color or RED
	local card = Instance.new("CanvasGroup")
	card.LayoutOrder = annOrder
	card.Size = UDim2.fromOffset(600, 74)
	card.BackgroundColor3 = DARK
	card.BackgroundTransparency = 0.12
	card.GroupTransparency = 1
	card.Parent = announceHolder
	corner(card, 12)
	stroke(card, 3, color)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 8, 1, 0)
	bar.BackgroundColor3 = color
	bar.BorderSizePixel = 0
	bar.Parent = card
	local tag = label(card, "📢 ANNOUNCEMENT • " .. string.upper(tostring(data.from or "ADMIN")), 15, color)
	tag.Position = UDim2.fromOffset(20, 6)
	tag.Size = UDim2.new(1, -30, 0, 20)
	tag.TextXAlignment = Enum.TextXAlignment.Left
	local msg = label(card, tostring(data.text or ""), 24, WHITE)
	msg.Position = UDim2.fromOffset(20, 26)
	msg.Size = UDim2.new(1, -30, 0, 42)
	msg.TextXAlignment = Enum.TextXAlignment.Left
	msg.TextWrapped = true
	msg.TextScaled = true
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 26
	cap.Parent = msg
	local sc = Instance.new("UIScale")
	sc.Scale = 0.8
	sc.Parent = card
	UISounds.Play("Indicator")
	tween(card, 0.25, { GroupTransparency = 0 })
	tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(6, function()
		tween(card, 0.4, { GroupTransparency = 1 }).Completed:Wait()
		card:Destroy()
	end)
end

event.OnClientEvent:Connect(function(kind, data)
	if kind == "Announce" and type(data) == "table" then
		showAnnouncement(data)
	end
end)

--== Panneau admin ==--
local built = false
local panel, openButton
local isOpen = false
local selectedDuration = AdminConfig.DURATIONS[2] or 300
local durationButtons = {}
local stockLabels = {}

local function formatDuration(s: number): string
	if s >= 60 then
		local m = s / 60
		return (m % 1 == 0 and ("%dm"):format(m) or ("%.1fm"):format(m))
	end
	return s .. "s"
end

local function feedback(ok)
	UISounds.Play(ok and "Success" or "BuyFail")
end

local fitScale = 1
local lastToggle = 0

local function setOpen(open: boolean)
	if not panel then
		return
	end
	if os.clock() - lastToggle < 0.25 then
		return
	end
	lastToggle = os.clock()
	isOpen = open
	local sc = panel:FindFirstChild("OpenScale")
	if open then
		panel.Visible = true
		sc.Scale = fitScale * 0.85
		tween(sc, 0.25, { Scale = fitScale }, Enum.EasingStyle.Back)
		UISounds.Play("Open")
	else
		UISounds.Play("Swoosh")
		tween(sc, 0.12, { Scale = fitScale * 0.85 }).Completed:Connect(function()
			if not isOpen then
				panel.Visible = false
			end
		end)
	end
end

local function buildPanel()
	if built then
		return
	end
	built = true

	openButton = button(gui, "🛡 ADMIN", RED, 18)
	openButton.AnchorPoint = Vector2.new(1, 0)
	openButton.Position = UDim2.new(1, -86, 0, 18)
	openButton.Size = UDim2.fromOffset(112, 42)
	openButton.MouseButton1Click:Connect(function()
		setOpen(not isOpen)
	end)

	panel = Instance.new("Frame")
	panel.Name = "AdminPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(560, 470)
	panel.BackgroundColor3 = DARK
	panel.BackgroundTransparency = 0.05
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 14)
	stroke(panel, 4, RED)
	local pg = Instance.new("UIGradient")
	pg.Color = ColorSequence.new(Color3.fromRGB(70, 18, 26), Color3.fromRGB(20, 6, 9))
	pg.Rotation = 90
	pg.Parent = panel
	local sc = Instance.new("UIScale")
	sc.Name = "OpenScale"
	sc.Parent = panel

	local title = label(panel, "🛡 ADMIN PANEL", 32, WHITE, FONT_TITLE)
	title.Position = UDim2.fromOffset(18, 8)
	title.Size = UDim2.new(1, -80, 0, 44)
	title.TextXAlignment = Enum.TextXAlignment.Left
	local tg = Instance.new("UIGradient")
	tg.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), RED)
	tg.Rotation = 90
	tg.Parent = title

	local close = button(panel, "X", Color3.fromRGB(220, 50, 55), 20)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 12)
	close.Size = UDim2.fromOffset(38, 38)
	close.MouseButton1Click:Connect(function()
		setOpen(false)
	end)

	local y = 60
	local function section(text)
		local l = label(panel, text, 17, Color3.fromRGB(255, 190, 190))
		l.Position = UDim2.fromOffset(18, y)
		l.Size = UDim2.new(1, -36, 0, 20)
		l.TextXAlignment = Enum.TextXAlignment.Left
		y += 24
	end

	section("⛈ SUMMON WEATHER")
	local wGrid = Instance.new("Frame")
	wGrid.BackgroundTransparency = 1
	wGrid.Position = UDim2.fromOffset(18, y)
	wGrid.Size = UDim2.new(1, -36, 0, 92)
	wGrid.Parent = panel
	local gl = Instance.new("UIGridLayout")
	gl.CellSize = UDim2.new(1 / 3, -6, 0, 42)
	gl.CellPadding = UDim2.fromOffset(8, 8)
	gl.SortOrder = Enum.SortOrder.LayoutOrder
	gl.Parent = wGrid
	for i, w in ipairs(WeatherShared.LIST) do
		local c = w.color
		if w.rainbow then
			c = Color3.fromRGB(170, 60, 255)
		end
		local b = button(wGrid, (w.adminOnly and "👑 " or "") .. w.name:gsub(" Weather", ""), c, 17)
		b.LayoutOrder = w.adminOnly and 0 or i
		b.MouseButton1Click:Connect(function()
			feedback(remote:InvokeServer("Weather", w.key, selectedDuration))
		end)
	end
	y += 100

	section("⏱ DURATION")
	local dRow = Instance.new("Frame")
	dRow.BackgroundTransparency = 1
	dRow.Position = UDim2.fromOffset(18, y)
	dRow.Size = UDim2.new(1, -36, 0, 38)
	dRow.Parent = panel
	local dl = Instance.new("UIListLayout")
	dl.FillDirection = Enum.FillDirection.Horizontal
	dl.Padding = UDim.new(0, 8)
	dl.Parent = dRow
	local function refreshDur()
		for d, b in pairs(durationButtons) do
			b.BackgroundColor3 = d == selectedDuration and Color3.fromRGB(255, 190, 40) or Color3.fromRGB(70, 60, 70)
		end
	end
	for _, d in ipairs(AdminConfig.DURATIONS) do
		local b = button(dRow, formatDuration(d), Color3.fromRGB(70, 60, 70), 17)
		b.Size = UDim2.fromOffset(80, 36)
		durationButtons[d] = b
		b.MouseButton1Click:Connect(function()
			selectedDuration = d
			UISounds.Play("Tab")
			refreshDur()
		end)
	end
	local stop = button(dRow, "⏹ STOP", Color3.fromRGB(90, 90, 100), 17)
	stop.Size = UDim2.fromOffset(150, 36)
	stop.MouseButton1Click:Connect(function()
		feedback(remote:InvokeServer("StopWeather"))
	end)
	refreshDur()
	y += 48

	section("📢 ANNOUNCE (everyone)")
	local box = Instance.new("TextBox")
	box.Position = UDim2.fromOffset(18, y)
	box.Size = UDim2.new(1, -150, 0, 40)
	box.BackgroundColor3 = Color3.fromRGB(15, 5, 8)
	box.FontFace = FONT
	box.TextSize = 18
	box.TextColor3 = WHITE
	box.PlaceholderText = "Message..."
	box.PlaceholderColor3 = Color3.fromRGB(150, 120, 125)
	box.Text = ""
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.Parent = panel
	corner(box, 8)
	stroke(box, 2.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.Parent = box
	local send = button(panel, "SEND", Color3.fromRGB(40, 200, 80), 18)
	send.AnchorPoint = Vector2.new(1, 0)
	send.Position = UDim2.new(1, -18, 0, y)
	send.Size = UDim2.fromOffset(118, 40)
	local function doSend()
		if box.Text:match("^%s*$") then
			return
		end
		local ok = remote:InvokeServer("Announce", box.Text)
		feedback(ok)
		if ok then
			box.Text = ""
		end
	end
	send.MouseButton1Click:Connect(doSend)
	box.FocusLost:Connect(function(enter)
		if enter then
			doSend()
		end
	end)
	y += 52

	section("📦 SHOP STOCK")
	for _, d in ipairs(ShopConfig.DIRECT_BUYS) do
		local row = Instance.new("Frame")
		row.BackgroundColor3 = Color3.fromRGB(15, 5, 8)
		row.BackgroundTransparency = 0.3
		row.Position = UDim2.fromOffset(18, y)
		row.Size = UDim2.new(1, -36, 0, 40)
		row.Parent = panel
		corner(row, 8)
		local name = label(row, d.name, 19, WHITE)
		name.Position = UDim2.fromOffset(12, 0)
		name.Size = UDim2.new(0.4, 0, 1, 0)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local left = label(row, "", 18, Color3.fromRGB(255, 215, 90))
		left.Position = UDim2.new(0.4, 0, 0, 0)
		left.Size = UDim2.new(0.3, 0, 1, 0)
		stockLabels[d.key] = left
		local function refresh()
			local v = ShopConfig.GetStockLeft(d.key)
			left.Text = v and (("%d / %d LEFT"):format(v, d.stock)) or "..."
		end
		ReplicatedStorage.Shop:GetAttributeChangedSignal("StockLeft_" .. d.key):Connect(refresh)
		refresh()
		local rs = button(row, "RESTOCK", Color3.fromRGB(255, 160, 30), 16)
		rs.AnchorPoint = Vector2.new(1, 0.5)
		rs.Position = UDim2.new(1, -6, 0.5, 0)
		rs.Size = UDim2.fromOffset(120, 32)
		rs.MouseButton1Click:Connect(function()
			feedback(remote:InvokeServer("Restock", d.key))
		end)
		y += 46
	end

	local hint = label(panel, "Chat: /admin  /abuse [sec]  /stopweather  /announce msg  /restock name", 13, Color3.fromRGB(200, 160, 165))
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -8)
	hint.Size = UDim2.new(1, -20, 0, 16)

	panel.Size = UDim2.fromOffset(560, y + 34)
	local function fit()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
		fitScale = math.clamp(math.min((vp.X - 20) / 560, (vp.Y - 60) / (y + 34)), 0.4, 1)
		if isOpen then
			sc.Scale = fitScale
		end
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
end

local function checkAdmin()
	if player:GetAttribute("IsAdmin") == true then
		buildPanel()
	end
end
player:GetAttributeChangedSignal("IsAdmin"):Connect(checkAdmin)
checkAdmin()

player.Chatted:Connect(function(msg)
	if msg:lower():match("^/admin$") and player:GetAttribute("IsAdmin") then
		buildPanel()
		setOpen(not isOpen)
	end
end)

local TextChatService = game:GetService("TextChatService")
pcall(function()
	TextChatService.SendingMessage:Connect(function(msg)
		if msg.Text:lower():match("^/admin$") and player:GetAttribute("IsAdmin") then
			buildPanel()
			setOpen(not isOpen)
		end
	end)
end)
