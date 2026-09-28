--[[
	MasteryService
	--------------
	- Chaque YEET donne des points de Mastery (plus loin = plus), a
	  l'atterrissage (attribut "IsNoob" pose par YeetService).
	- Les points achetent des skins old Roblox (MasteryShared.SKINS).
	- Bonus de force = meilleur skin possede -> attribut "SkinPower", lu par
	  ShopPerks.GetStrengthMultiplier.
	- Le skin "porte" (attribut SkinEquipped) est l'apparence du noob qu'on
	  LANCE : YeetShared.BuildNoob (modele en vol) + YeetService (perso a
	  l'atterrissage). Le perso normal garde son avatar.

	Sauvegarde : champ de profil "mastery" = { points, total, owned = {cles}, equipped }.

	Remote ReplicatedStorage.Mastery.MasteryRemote (RemoteFunction) :
	  "GetState"        -> { points, total, owned = { [cle] = true }, equipped }
	  "Buy", cle        -> { ok, err? }
	  "Equip", cle|nil  -> { ok }   (nil = noob classique)
	Event ReplicatedStorage.Mastery.MasteryEvent : "Gained", { amount, total } | "State", state
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MasteryShared = require(ReplicatedStorage.Mastery.MasteryShared)
local PlayerProfileService = require(ServerScriptService.PlayerProfileService)
local AdminGrants = require(ServerScriptService.Admin.AdminGrants)
local YeetShared = require(ReplicatedStorage:WaitForChild("Yeet"):WaitForChild("YeetShared"))

local folder = ReplicatedStorage.Mastery
local remote = Instance.new("RemoteFunction")
remote.Name = "MasteryRemote"
remote.Parent = folder
local event = Instance.new("RemoteEvent")
event.Name = "MasteryEvent"
event.Parent = folder

-- Cles faibles (voir PlayerProfileService).
local data = setmetatable({}, { __mode = "k" }) -- Player -> { points, total, owned, equipped }
local lastAction = setmetatable({}, { __mode = "k" })

local function stateOf(player: Player)
	local d = data[player]
	if not d then
		return nil
	end
	return { points = d.points, total = d.total, owned = d.owned, equipped = d.equipped }
end

local function push(player: Player)
	local d = data[player]
	if not d then
		return
	end
	player:SetAttribute("Mastery", d.points)
	player:SetAttribute("SkinPower", MasteryShared.BestMult(d.owned))
	player:SetAttribute("SkinEquipped", d.equipped or "")
	event:FireClient(player, "State", stateOf(player))
end

--== Gains ==--
local function addPoints(player: Player, amount: number)
	local d = data[player]
	if not d or amount <= 0 then
		return
	end
	d.points += amount
	d.total += amount
	push(player)
	event:FireClient(player, "Gained", { amount = amount, total = d.points })
end

local function onLanded(player: Player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local zone = YeetShared.GetSafeZone()
	if not root or not zone then
		addPoints(player, 1)
		return
	end
	local distance = math.abs((zone :: BasePart).Position.Z - root.Position.Z)
	addPoints(player, MasteryShared.PointsForDistance(distance))
end

--== Remote ==--
remote.OnServerInvoke = function(player: Player, action: any, arg: any)
	local d = data[player]
	if action == "GetState" then
		return stateOf(player)
	end
	if not d then
		return { ok = false, err = "Loading..." }
	end
	local now = os.clock()
	if lastAction[player] and now - lastAction[player] < 0.3 then
		return { ok = false, err = "Too fast!" }
	end
	lastAction[player] = now
	if action == "Buy" then
		local skin = MasteryShared.Get(arg)
		if not skin then
			return { ok = false, err = "Unknown skin" }
		end
		if d.owned[skin.key] then
			return { ok = false, err = "Already owned" }
		end
		if d.points < skin.cost then
			return { ok = false, err = "Not enough Mastery!" }
		end
		d.points -= skin.cost
		d.owned[skin.key] = true
		d.equipped = skin.key
		push(player)
		task.spawn(PlayerProfileService.Save, player)
		return { ok = true }
	elseif action == "Equip" then
		if arg ~= nil and not (MasteryShared.Get(arg) and d.owned[arg]) then
			return { ok = false, err = "Not owned" }
		end
		d.equipped = arg
		push(player)
		return { ok = true }
	end
	return { ok = false }
end

AdminGrants.Register("Mastery", function(player: Player, amount: any)
	local n = math.floor(tonumber(amount) or 0)
	if n <= 0 or not data[player] then
		return false
	end
	addPoints(player, n)
	return true
end)

--== Joueurs ==--
local function onPlayerAdded(player: Player)
	local profile = PlayerProfileService.WaitForProfile(player)
	local saved = type(profile.mastery) == "table" and profile.mastery or {}
	local owned = {}
	if type(saved.owned) == "table" then
		for _, k in ipairs(saved.owned) do
			if MasteryShared.Get(k) then
				owned[k] = true
			end
		end
	end
	data[player] = {
		points = math.max(0, math.floor(tonumber(saved.points) or 0)),
		total = math.max(0, math.floor(tonumber(saved.total) or 0)),
		owned = owned,
		equipped = (MasteryShared.Get(saved.equipped) and owned[saved.equipped]) and saved.equipped or nil,
	}
	push(player)

	player:GetAttributeChangedSignal("IsNoob"):Connect(function()
		if player:GetAttribute("IsNoob") == true then
			onLanded(player)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

PlayerProfileService.RegisterField("mastery", function(player: Player)
	local d = data[player]
	if not d then
		if PlayerProfileService.IsLoaded(player) then
			return PlayerProfileService.WaitForProfile(player).mastery
		end
		return nil
	end
	local owned = {}
	for k in pairs(d.owned) do
		table.insert(owned, k)
	end
	return { points = d.points, total = d.total, owned = owned, equipped = d.equipped }
end)
