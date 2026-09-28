--[[
	AdminService
	------------
	Panneau admin (bouton ADMIN, ou /admin dans le chat) :
	  - lancer n'importe quelle meteo (dont ADMIN ABUSE) pour une duree
	  - arreter la meteo
	  - annonce globale (filtree) sur l'ecran de tout le serveur
	  - restock des achats directs (stock global)
	  - GIVE : donner a un joueur (ou a tout le serveur) une base, un game
	    pass, des lucky blocks, un brainrot du shop, des lucky rolls ou du cash
	    (voir AdminGrants : chaque service enregistre ce qu'il sait donner)

	Qui est admin : ReplicatedStorage.Admin.AdminConfig.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TextService = game:GetService("TextService")

local AdminConfig = require(ReplicatedStorage.Admin.AdminConfig)
local WeatherShared = require(ReplicatedStorage.WeatherShared)
local ShopConfig = require(ReplicatedStorage.Shop.ShopConfig)
local StockService = require(ServerScriptService.Shop.StockService)
local ShopPerks = require(ServerScriptService.Shop.ShopPerks)
local MoneyService = require(ServerScriptService.Money.MoneyService)
local AdminGrants = require(ServerScriptService.Admin.AdminGrants)
local BaseSkinShared = require(ReplicatedStorage.BaseSkinShared)
local TraitShared = require(ReplicatedStorage.Traits.TraitShared)
local NumberFormat = require(ReplicatedStorage.NumberFormat)

local remote = ReplicatedStorage.Admin.AdminRemote
local event = ReplicatedStorage.Admin.AdminEvent
local weatherControl = ServerScriptService:WaitForChild("Weather"):WaitForChild("WeatherService"):WaitForChild("WeatherControl", 30)

local lastAction = setmetatable({}, { __mode = "k" })

local function filter(text: string, player: Player): string?
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	return ok and result or nil
end

local function announce(player: Player, text: string, color: Color3?)
	event:FireAllClients("Announce", { text = text, from = player.DisplayName, color = color })
end

local actions = {}

actions.Weather = function(player: Player, key: any, duration: any)
	local w = WeatherShared.Get(tostring(key))
	if not w or not weatherControl then
		return false
	end
	local d = math.clamp(tonumber(duration) or WeatherShared.DURATION, 10, 3600)
	weatherControl:Invoke("start", w.key, d)
	announce(player, ("%s started %s!"):format(player.DisplayName, w.name), w.color)
	return true
end

actions.StopWeather = function(player: Player)
	if weatherControl then
		weatherControl:Invoke("stop")
	end
	return true
end

actions.Announce = function(player: Player, text: any)
	if type(text) ~= "string" then
		return false
	end
	text = text:sub(1, 140)
	if text:match("^%s*$") then
		return false
	end
	local filtered = filter(text, player)
	if not filtered then
		return false
	end
	announce(player, filtered)
	return true
end

actions.Restock = function(player: Player, key: any)
	local d = ShopConfig.GetDirect(tostring(key))
	if not d then
		return false
	end
	StockService.Restock(d.key)
	announce(player, ("%s is back in stock! (%d LEFT)"):format(d.name, d.stock), Color3.fromRGB(255, 215, 60))
	return true
end

AdminGrants.Register("Pass", function(target: Player, key: any)
	return ShopPerks.Gift(target, tostring(key))
end)
AdminGrants.Register("Money", function(target: Player, amount: any)
	local n = math.floor(tonumber(amount) or 0)
	return n > 0 and MoneyService.AddMoney(target, n)
end)

local GIVE_LIMITS = { Lucky = 100, TraitLuck = 1000, Money = 1e30 }

-- Texte lisible du don (annonce au joueur qui le recoit).
local function describeGift(kind: string, arg: any): string?
	if kind == "BaseSkin" then
		local s = BaseSkinShared.Get(tostring(arg))
		return s and s.name
	elseif kind == "Pass" then
		local p = ShopConfig.GetPass(tostring(arg))
		return p and (p.title .. " Game Pass")
	elseif kind == "Lucky" then
		local n = tonumber(arg)
		return n and ("%d %s"):format(n, ShopConfig.LUCKY_BLOCK.name .. (n > 1 and "s" or ""))
	elseif kind == "Direct" then
		local d = ShopConfig.GetDirect(tostring(arg))
		return d and d.name
	elseif kind == "TraitLuck" then
		local n = tonumber(arg)
		return n and ("%d %dx Lucky Roll%s"):format(n, TraitShared.LUCK_MULT, n > 1 and "s" or "")
	elseif kind == "Money" then
		local n = tonumber(arg)
		return n and ("$" .. NumberFormat.Format(n))
	end
	return nil
end

local function resolveTargets(who: any): { Player }
	if who == "ALL" then
		return Players:GetPlayers()
	end
	local n = type(who) == "string" and tonumber(who:match("^RANDOM:(%d+)$"))
	if n then
		local pool = Players:GetPlayers()
		for i = #pool, 2, -1 do
			local j = math.random(1, i)
			pool[i], pool[j] = pool[j], pool[i]
		end
		local out = {}
		for i = 1, math.min(math.clamp(n, 1, 50), #pool) do
			out[i] = pool[i]
		end
		return out
	end
	local target = Players:GetPlayerByUserId(tonumber(who) or 0)
	return target and { target } or {}
end

actions.Give = function(player: Player, who: any, data: any)
	if type(data) ~= "table" or type(data.kind) ~= "string" then
		return false
	end
	local kind, arg = data.kind, data.arg
	local limit = GIVE_LIMITS[kind]
	if limit then
		arg = tonumber(arg)
		if not arg or arg < 1 or arg > limit then
			return false
		end
		arg = math.floor(arg)
	end
	local label = describeGift(kind, arg)
	if not label or not AdminGrants.Has(kind) then
		return false
	end
	local targets = resolveTargets(who)
	if #targets == 0 then
		return false
	end
	for _, target in ipairs(targets) do
		task.spawn(function()
			if AdminGrants.Grant(kind, target, arg) then
				event:FireClient(target, "Gift", { text = label, from = player.DisplayName, kind = kind })
			end
		end)
	end
	if who == "ALL" then
		announce(player, ("%s gave everyone %s!"):format(player.DisplayName, label), Color3.fromRGB(255, 215, 60))
	elseif type(who) == "string" and who:match("^RANDOM:") then
		local names = {}
		for _, t in ipairs(targets) do
			table.insert(names, t.DisplayName)
		end
		announce(player, ("🎲 %s won %s!"):format(table.concat(names, ", "), label), Color3.fromRGB(255, 215, 60))
	end
	return true
end

remote.OnServerInvoke = function(player: Player, action: any, a: any, b: any)
	if not AdminConfig.IsAdmin(player) then
		return false
	end
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 0.4 then
		return false
	end
	lastAction[player] = now
	local fn = actions[action]
	if not fn then
		return false
	end
	local ok, result = pcall(fn, player, a, b)
	return ok and result or false
end

local function onChatted(player: Player, msg: string)
	if not AdminConfig.IsAdmin(player) then
		return
	end
	local lower = msg:lower()
	if lower:match("^/stopweather") then
		actions.StopWeather(player)
	elseif lower:match("^/restock%s+") then
		local key = msg:match("^/%a+%s+(.+)$")
		for _, d in ipairs(ShopConfig.DIRECT_BUYS) do
			if key and (d.key:lower() == key:lower() or d.name:lower() == key:lower()) then
				actions.Restock(player, d.key)
			end
		end
	elseif lower:match("^/announce%s+") then
		actions.Announce(player, msg:match("^/%a+%s+(.+)$"))
	elseif lower:match("^/abuse") then
		actions.Weather(player, "Admin", tonumber(lower:match("^/abuse%s+(%d+)")) or 300)
	end
end

local function onPlayerAdded(player: Player)
	task.spawn(function()
		player:SetAttribute("IsAdmin", AdminConfig.IsAdmin(player))
	end)
	player.Chatted:Connect(function(msg)
		onChatted(player, msg)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end
