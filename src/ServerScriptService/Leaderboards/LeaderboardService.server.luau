--[[
	LeaderboardService
	------------------
	6 classements globaux (OrderedDataStore) affiches sur les panneaux
	Workspace.Leaderboards (LB_<Stat>) autour du spawn :
	  Money, Rebirths, Strength, Speed, Playtime, RobuxSpent.

	Les grosses valeurs (cash / force / vitesse, jusqu'a sx et plus) sont
	stockees en log10 (un OrderedDataStore n'accepte que des entiers < 2^63).
	Les joueurs du serveur sont fusionnes en direct avec le top global.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NumberFormat = require(ReplicatedStorage.NumberFormat)
local ShopConfig = require(ReplicatedStorage.Shop.ShopConfig)
local StatTracker = require(script.Parent.StatTracker)
local MoneyService = require(ServerScriptService.Money.MoneyService)
local SpeedService = require(ServerScriptService.Training.SpeedService)
local ForceService = require(ServerScriptService.Training.ForceService)
local RebirthService = require(ServerScriptService.Rebirth.RebirthService)

local VERSION = "v1"
local TOP = 10
local WRITE_EVERY = 120
local REFRESH_EVERY = 75
local LOG_SCALE = 1e12
local ROBUX = utf8.char(0xE002)

local function formatTime(s: number): string
	s = math.floor(s)
	local d = math.floor(s / 86400)
	local h = math.floor(s % 86400 / 3600)
	local m = math.floor(s % 3600 / 60)
	if d > 0 then
		return ("%dd %dh"):format(d, h)
	elseif h > 0 then
		return ("%dh %dm"):format(h, m)
	end
	return ("%dm"):format(m)
end

local STATS = {
	Money = { title = "TOP MONEY", icon = "💵", log = true, color = Color3.fromRGB(70, 220, 90),
		get = function(p) return MoneyService.GetMoney(p) end, fmt = function(v) return "$" .. NumberFormat.Format(v) end },
	Rebirths = { title = "TOP REBIRTHS", icon = "🔁", color = Color3.fromRGB(185, 90, 255),
		get = function(p) return RebirthService.GetRebirths(p) end, fmt = function(v) return NumberFormat.Format(v) end },
	Strength = { title = "TOP STRENGTH", icon = "💪", log = true, color = Color3.fromRGB(255, 70, 70),
		get = function(p) return ForceService.GetForce(p) end, fmt = function(v) return NumberFormat.Format(v) end },
	Speed = { title = "TOP SPEED", icon = "⚡", log = true, color = Color3.fromRGB(50, 190, 255),
		get = function(p) return SpeedService.GetSpeed(p) end, fmt = function(v) return NumberFormat.Format(v) end },
	Playtime = { title = "TOP PLAYTIME", icon = "⏱", color = Color3.fromRGB(255, 160, 40),
		get = function(p) return StatTracker.GetPlaytime(p) end, fmt = formatTime },
	RobuxSpent = { title = "TOP ROBUX SPENT", icon = ROBUX, color = Color3.fromRGB(255, 210, 50),
		get = function(p) return StatTracker.GetRobux(p) end, fmt = function(v) return ROBUX .. " " .. NumberFormat.Format(v) end },
}

local stores = {}
for key in pairs(STATS) do
	pcall(function()
		stores[key] = DataStoreService:GetOrderedDataStore("LB_" .. key .. "_" .. VERSION)
	end)
end

local function encode(stat, v: number): number
	v = math.max(0, tonumber(v) or 0)
	if stat.log then
		return math.floor(math.log10(v + 1) * LOG_SCALE)
	end
	return math.floor(v)
end

local function decode(stat, n: number): number
	if stat.log then
		return math.max(0, 10 ^ (n / LOG_SCALE) - 1)
	end
	return n
end

local nameCache = {}
local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local p = Players:GetPlayerByUserId(userId)
	if p then
		nameCache[userId] = p.DisplayName
		return p.DisplayName
	end
	if userId <= 0 then
		return "Player" .. math.abs(userId)
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or ("#" .. userId)
	return nameCache[userId]
end

local function safeGet(stat, p: Player): number
	local ok, v = pcall(stat.get, p)
	return ok and tonumber(v) or 0
end

--== Ecriture ==--
local function writePlayer(p: Player)
	if p.UserId <= 0 then
		return
	end
	for key, stat in pairs(STATS) do
		local store = stores[key]
		if store then
			local value = encode(stat, safeGet(stat, p))
			if value > 0 then
				pcall(function()
					store:SetAsync(tostring(p.UserId), value)
				end)
			end
		end
	end
end

Players.PlayerRemoving:Connect(function(p)
	writePlayer(p)
end)

task.spawn(function()
	while true do
		for _, p in ipairs(Players:GetPlayers()) do
			if StatTracker.IsLoaded(p) then
				task.spawn(writePlayer, p)
				task.wait(1)
			end
		end
		task.wait(WRITE_EVERY)
	end
end)

--== Game passes : Robux depenses ==--
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	local price
	for _, pass in ipairs(ShopConfig.PASSES) do
		if pass.id == passId then
			price = pass.price
		end
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfo(passId, Enum.InfoType.GamePass)
	end)
	if ok and info and info.PriceInRobux then
		price = info.PriceInRobux
	end
	if price then
		StatTracker.AddRobux(player, price)
	end
end)

--== Affichage ==--
local FONT_TITLE = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local RANK_COLORS = { Color3.fromRGB(255, 205, 40), Color3.fromRGB(205, 215, 230), Color3.fromRGB(215, 130, 60) }

local function stroke(p, t, c)
	local s = Instance.new("UIStroke")
	s.Thickness = t
	s.Color = c or Color3.new(0, 0, 0)
	s.Parent = p
	return s
end
local function corner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local boards = {}

--[[
	Icone d'un classement : attribut "Icon" du modele LB_<Stat> (ex:
	rbxassetid://123456 d'un de tes decals) sinon icone dessinee ici :
	pastille de la couleur du classement + emoji (logo Robux pour RobuxSpent).
]]
local ROBUX_IMAGE = "rbxasset://textures/ui/common/robux.png"
local function iconBadge(parent: Instance, model: Model, stat, pos: UDim2, size: UDim2?)
	local badge = Instance.new("Frame")
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = pos
	badge.Size = size or UDim2.fromOffset(92, 92)
	badge.BackgroundColor3 = Color3.new(1, 1, 1)
	badge.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = badge
	stroke(badge, 5)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(stat.color:Lerp(Color3.new(1, 1, 1), 0.45), stat.color:Lerp(Color3.new(0, 0, 0), 0.25))
	g.Parent = badge
	local custom = model:GetAttribute("Icon")
	if type(custom) == "string" and custom ~= "" then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(0.78, 0.78)
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = custom:match("^%d+$") and ("rbxassetid://" .. custom) or custom
		img.Parent = badge
	elseif stat.icon == ROBUX then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromScale(0.64, 0.64)
		img.ScaleType = Enum.ScaleType.Fit
		img.Image = ROBUX_IMAGE
		img.Parent = badge
	else
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, 0.52)
		t.Size = UDim2.fromScale(0.72, 0.72)
		t.TextScaled = true
		t.Text = stat.icon
		t.Parent = badge
	end
	return badge
end

local function buildBoard(model: Model, stat)
	local board = model:FindFirstChild("Board")
	if not board then
		return
	end
	local old = board:FindFirstChild("LeaderboardGui")
	if old then
		old:Destroy()
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "LeaderboardGui"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(560, 760)
	sg.LightInfluence = 0
	sg.Brightness = 1.2
	sg.MaxDistance = 260
	sg.Parent = board

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 110)
	header.BackgroundColor3 = stat.color
	header.BorderSizePixel = 0
	header.Parent = sg
	local hg = Instance.new("UIGradient")
	hg.Color = ColorSequence.new(stat.color:Lerp(Color3.new(1, 1, 1), 0.25), stat.color:Lerp(Color3.new(0, 0, 0), 0.35))
	hg.Rotation = 90
	hg.Parent = header
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.5)
	title.Size = UDim2.new(1, -240, 1, -24)
	title.FontFace = FONT_TITLE
	title.TextScaled = true
	title.Text = stat.title
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Parent = header
	stroke(title, 4)
	iconBadge(header, model, stat, UDim2.new(0, 60, 0.5, 0))
	iconBadge(header, model, stat, UDim2.new(1, -60, 0.5, 0))

	-- Grosse icone flottante au-dessus du panneau.
	local top = model:FindFirstChild("Cap") or board
	local old2 = top:FindFirstChild("LeaderboardIcon")
	if old2 then
		old2:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "LeaderboardIcon"
	bb.Size = UDim2.fromScale(6, 6)
	bb.StudsOffset = Vector3.new(0, 4.5, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 200
	bb.Parent = top
	iconBadge(bb, model, stat, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1))

	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(12, 122)
	list.Size = UDim2.new(1, -24, 1, -170)
	list.Parent = sg
	local ll = Instance.new("UIListLayout")
	ll.Padding = UDim.new(0, 5)
	ll.SortOrder = Enum.SortOrder.LayoutOrder
	ll.Parent = list

	local rows = {}
	for i = 1, TOP do
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 56)
		row.BackgroundColor3 = i <= 3 and RANK_COLORS[i]:Lerp(Color3.fromRGB(22, 22, 28), 0.72) or Color3.fromRGB(38, 38, 46)
		row.Parent = list
		corner(row, 10)
		local rank = Instance.new("TextLabel")
		rank.BackgroundTransparency = 1
		rank.Size = UDim2.fromOffset(60, 56)
		rank.FontFace = FONT_TITLE
		rank.TextSize = i <= 3 and 40 or 32
		rank.Text = "#" .. i
		rank.TextColor3 = RANK_COLORS[i] or Color3.fromRGB(200, 200, 210)
		rank.Parent = row
		stroke(rank, 2.5)
		local avatar = Instance.new("ImageLabel")
		avatar.Position = UDim2.fromOffset(62, 4)
		avatar.Size = UDim2.fromOffset(48, 48)
		avatar.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		avatar.Image = ""
		avatar.Parent = row
		corner(avatar, 24)
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(118, 0)
		name.Size = UDim2.new(0.58, -118, 1, 0)
		name.FontFace = FONT
		name.TextSize = 30
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.TextColor3 = Color3.new(1, 1, 1)
		name.Text = "..."
		name.Parent = row
		stroke(name, 2)
		local value = Instance.new("TextLabel")
		value.BackgroundTransparency = 1
		value.AnchorPoint = Vector2.new(1, 0)
		value.Position = UDim2.new(1, -12, 0, 0)
		value.Size = UDim2.new(0.42, -12, 1, 0)
		value.FontFace = FONT_TITLE
		value.TextSize = 32
		value.TextXAlignment = Enum.TextXAlignment.Right
		value.TextColor3 = stat.color:Lerp(Color3.new(1, 1, 1), 0.2)
		value.Text = ""
		value.Parent = row
		stroke(value, 2.5)
		row.Visible = false
		rows[i] = { row = row, avatar = avatar, name = name, value = value }
	end

	local footer = Instance.new("TextLabel")
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0.5, 1)
	footer.Position = UDim2.new(0.5, 0, 1, -8)
	footer.Size = UDim2.new(1, -20, 0, 30)
	footer.FontFace = FONT
	footer.TextSize = 24
	footer.TextColor3 = Color3.fromRGB(170, 170, 185)
	footer.Text = "Global • updates every minute"
	footer.Parent = sg

	local empty = Instance.new("TextLabel")
	empty.BackgroundTransparency = 1
	empty.Position = UDim2.fromOffset(0, 300)
	empty.Size = UDim2.new(1, 0, 0, 60)
	empty.FontFace = FONT_TITLE
	empty.TextSize = 40
	empty.TextColor3 = Color3.fromRGB(150, 150, 165)
	empty.Text = "LOADING..."
	empty.Parent = sg

	return { rows = rows, empty = empty }
end

local function refreshBoard(key: string)
	local stat = STATS[key]
	local ui = boards[key]
	if not stat or not ui then
		return
	end
	local entries: { [number]: number } = {}
	local store = stores[key]
	if store then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, TOP)
		end)
		if ok and pages then
			for _, item in ipairs(pages:GetCurrentPage()) do
				local uid = tonumber(item.key)
				if uid then
					entries[uid] = decode(stat, item.value)
				end
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if StatTracker.IsLoaded(p) then
			local v = safeGet(stat, p)
			if v > 0 then
				entries[p.UserId] = math.max(entries[p.UserId] or 0, v)
			end
		end
	end
	local list = {}
	for uid, v in pairs(entries) do
		table.insert(list, { uid = uid, v = v })
	end
	table.sort(list, function(a, b)
		return a.v > b.v
	end)
	for i = 1, TOP do
		local r = ui.rows[i]
		local e = list[i]
		if e then
			r.row.Visible = true
			r.name.Text = nameOf(e.uid)
			r.value.Text = stat.fmt(e.v)
			r.avatar.Image = e.uid > 0 and ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(e.uid) or ""
		else
			r.row.Visible = false
		end
	end
	ui.empty.Visible = #list == 0
	ui.empty.Text = "NO DATA YET"
end

local folder = workspace:WaitForChild("Leaderboards", 30)
if folder then
	for _, model in ipairs(folder:GetChildren()) do
		local key = model:GetAttribute("Stat")
		local stat = key and STATS[key]
		if stat then
			boards[key] = buildBoard(model, stat)
		end
	end
	task.spawn(function()
		task.wait(8)
		while true do
			for key in pairs(boards) do
				pcall(refreshBoard, key)
				task.wait(1)
			end
			task.wait(REFRESH_EVERY)
		end
	end)
end
