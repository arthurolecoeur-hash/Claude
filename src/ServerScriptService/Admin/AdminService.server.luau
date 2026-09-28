--[[
	AdminService
	------------
	Panneau admin (bouton ADMIN, ou /admin dans le chat) :
	  - lancer n'importe quelle meteo (dont ADMIN ABUSE) pour une duree
	  - arreter la meteo
	  - annonce globale (filtree) sur l'ecran de tout le serveur
	  - restock des achats directs (stock global)

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
