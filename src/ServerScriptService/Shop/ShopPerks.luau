--[[
	ShopPerks
	---------
	ModuleScript dans ServerScriptService.Shop.

	Possession des Game Passes (VIP, x2 Cash, x2 Strength) et bonus associes :

		ShopPerks.GetCashMultiplier(player)     -- lu par IncomeShared
		ShopPerks.GetStrengthMultiplier(player) -- lu par PunchingBagToolService / TrainingHandler
		ShopPerks.Owns(player, "VIP")
		ShopPerks.Grant(player, "VIP")         -- achat confirme (ou test Studio)
		ShopPerks.Gift(player, "VIP")          -- don admin (sauvegarde, champ "giftedPasses")

	Attributs repliques sur le Player (lus par l'UI) : Pass_VIP, Pass_Cash2x,
	Pass_Strength2x (boolean).

	Le titre VIP est un BillboardGui "VIPTitle" au-dessus de la tete.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ShopConfig = require(ReplicatedStorage:WaitForChild("Shop"):WaitForChild("ShopConfig"))
local PlayerProfileService = require(game:GetService("ServerScriptService"):WaitForChild("PlayerProfileService"))

local ShopPerks = {}

-- Cles faibles (voir PlayerProfileService).
local owned = setmetatable({}, { __mode = "k" }) -- Player -> { [key] = true }
local gifted = setmetatable({}, { __mode = "k" }) -- Player -> { [key] = true } donnes par un admin

local VIP_GOLD = Color3.fromRGB(255, 200, 40)

local function getOwned(player: Player)
	local t = owned[player]
	if not t then
		t = {}
		owned[player] = t
	end
	return t
end

--== Titre VIP ==--
-- Juste la couronne + "VIP", sans fond. Place SOUS l'affichage d'argent
-- (TotalIncomeDisplay, StudsOffset Y 2.6) pour ne pas le cacher.
local VIP_CROWN = ShopConfig.GetPass("VIP").icon

local function buildTitle(head: BasePart)
	local old = head:FindFirstChild("VIPTitle")
	if old then
		old:Destroy()
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "VIPTitle"
	bb.Size = UDim2.new(3, 0, 0.85, 0)
	bb.StudsOffset = Vector3.new(0, 1.75, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 60
	bb.LightInfluence = 0

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = bb
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0.02, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = row

	local crown = Instance.new("ImageLabel")
	crown.BackgroundTransparency = 1
	crown.Image = VIP_CROWN
	crown.ScaleType = Enum.ScaleType.Fit
	crown.Size = UDim2.fromScale(0.3, 1)
	crown.LayoutOrder = 1
	crown.Parent = row

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(0.45, 1)
	label.LayoutOrder = 2
	label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	label.Text = ShopConfig.VIP_TITLE_TEXT
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = row
	local lg = Instance.new("UIGradient")
	lg.Rotation = 90
	lg.Color = ColorSequence.new(Color3.fromRGB(255, 245, 150), VIP_GOLD)
	lg.Parent = label
	local ls = Instance.new("UIStroke")
	ls.Thickness = 2.5
	ls.Color = Color3.fromRGB(90, 50, 0)
	ls.Parent = label

	bb.Parent = head
end

local function refreshTitle(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	if ShopPerks.Owns(player, "VIP") then
		buildTitle(head)
	else
		local old = head:FindFirstChild("VIPTitle")
		if old then
			old:Destroy()
		end
	end
end

local function pushAttributes(player: Player)
	for _, pass in ipairs(ShopConfig.PASSES) do
		player:SetAttribute("Pass_" .. pass.key, ShopPerks.Owns(player, pass.key))
	end
end

--== API ==--

function ShopPerks.Owns(player: Player, key: string): boolean
	local t = owned[player]
	return t ~= nil and t[key] == true
end

function ShopPerks.Grant(player: Player, key: string)
	if not ShopConfig.GetPass(key) then
		return
	end
	getOwned(player)[key] = true
	pushAttributes(player)
	if key == "VIP" then
		refreshTitle(player)
	end
end

function ShopPerks.Gift(player: Player, key: string): boolean
	if not ShopConfig.GetPass(key) then
		return false
	end
	local g = gifted[player] or {}
	gifted[player] = g
	g[key] = true
	ShopPerks.Grant(player, key)
	return true
end

function ShopPerks.GetCashMultiplier(player: Player): number
	local m = 1
	if ShopPerks.Owns(player, "VIP") then
		m *= ShopConfig.VIP_CASH_MULT
	end
	if ShopPerks.Owns(player, "Cash2x") then
		m *= ShopConfig.CASH2X_MULT
	end
	return m
end

function ShopPerks.GetStrengthMultiplier(player: Player): number
	local m = 1
	if ShopPerks.Owns(player, "VIP") then
		m *= ShopConfig.VIP_POWER_MULT
	end
	if ShopPerks.Owns(player, "Strength2x") then
		m *= ShopConfig.STRENGTH2X_MULT
	end
	return m
end

--== Chargement ==--

local function onPlayerAdded(player: Player)
	local t = getOwned(player)
	for _, pass in ipairs(ShopConfig.PASSES) do
		if pass.id and pass.id ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok and has then
				t[pass.key] = true
			end
		 end
	end
	local profile = PlayerProfileService.WaitForProfile(player)
	if type(profile.giftedPasses) == "table" then
		local g = gifted[player] or {}
		gifted[player] = g
		for _, k in ipairs(profile.giftedPasses) do
			if type(k) == "string" and ShopConfig.GetPass(k) then
				g[k] = true
				t[k] = true
			end
		end
	end
	pushAttributes(player)

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		refreshTitle(player)
	end)
	if player.Character then
		task.spawn(refreshTitle, player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Achat d'un pass pendant la session : effet immediat, sans rejoin.
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, purchased: boolean)
	if not purchased then
		return
	end
	for _, pass in ipairs(ShopConfig.PASSES) do
		if pass.id == passId and pass.id ~= 0 then
			ShopPerks.Grant(player, pass.key)
		end
	end
end)

PlayerProfileService.RegisterField("giftedPasses", function(player: Player)
	local g = gifted[player]
	if g == nil and PlayerProfileService.IsLoaded(player) then
		return PlayerProfileService.WaitForProfile(player).giftedPasses
	end
	local list = {}
	for k in pairs(g or {}) do
		table.insert(list, k)
	end
	return list
end)

return ShopPerks
