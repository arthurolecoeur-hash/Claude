--[[
	TraitService
	------------
	Trait Machine : le joueur choisit jusqu'a 4 brainrots de son
	inventaire, paie en cash (COST_SECONDS secondes de leur revenu) et
	chacun tire un trait. Le trait n'est remplace que si le nouveau est
	MEILLEUR (garde le meilleur).

	10x LUCK (Robux) : credits de rolls "chanceux" (x10 chance), sauvegardes
	dans le profil ("traitLuck"). Un credit consomme par ROLL (pas par
	brainrot). IDs : ReplicatedStorage.Traits.TraitShared.LUCK_PRODUCTS.

	Remote ReplicatedStorage.Traits.TraitRemote (RemoteFunction) :
	  "GetState"                  -> { luck }
	  "GetCost", { Tool }         -> cost
	  "Roll", { Tool }, useLuck   -> { ok, err?, results = { {tool, rolled, trait, improved} }, luck }
	  "BuyLuck", rolls            -> invite d'achat (ou gratuit dans Studio si id 0)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

local TraitShared = require(ReplicatedStorage.Traits.TraitShared)
local InventoryShared = require(ReplicatedStorage.Inventory.InventoryShared)
local MoneyService = require(ServerScriptService.Money.MoneyService)
local IncomeShared = require(ServerScriptService.Generators.IncomeShared)
local GeneratorLevelShared = require(ServerScriptService.Generators.GeneratorLevelShared)
local PickupService = require(ServerScriptService.Generators.PickupService)
local PlayerProfileService = require(ServerScriptService.PlayerProfileService)
local PurchaseRouter = require(ServerScriptService.Purchases.PurchaseRouter)
local AdminGrants = require(ServerScriptService:WaitForChild("Admin"):WaitForChild("AdminGrants"))

local remote = ReplicatedStorage.Traits.TraitRemote
local event = ReplicatedStorage.Traits.TraitEvent

local ROLL_COOLDOWN = 0.9

local rng = Random.new()
local luck = setmetatable({}, { __mode = "k" })
local loaded = setmetatable({}, { __mode = "k" })
local lastRoll = setmetatable({}, { __mode = "k" })

local function setLuck(player: Player, n: number)
	luck[player] = math.max(0, math.floor(n))
	player:SetAttribute("TraitLuck", luck[player])
end

local function ownsTool(player: Player, tool: any): boolean
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return false
	end
	if InventoryShared.GetItemType(tool) ~= InventoryShared.TYPE_BRAINROT then
		return false
	end
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:GetAttribute("IncomePerSecond") then
		return false
	end
	local parent = tool.Parent
	return parent ~= nil and (parent == player:FindFirstChildOfClass("Backpack") or parent == player.Character)
end

local function sanitize(player: Player, list: any): { Tool }?
	if type(list) ~= "table" then
		return nil
	end
	local out, seen = {}, {}
	for _, tool in ipairs(list) do
		if #out >= TraitShared.MAX_SELECTED then
			break
		end
		if ownsTool(player, tool) and not seen[tool] then
			seen[tool] = true
			table.insert(out, tool)
		end
	end
	return #out > 0 and out or nil
end

local function computeCost(player: Player, tools: { Tool }): number
	local mult = IncomeShared.GetCashMultiplier(player)
	local total = 0
	for _, tool in ipairs(tools) do
		local handle = tool:FindFirstChild("Handle")
		local base = handle:GetAttribute("IncomePerSecond") or 0
		local level = handle:GetAttribute("Level") or 1
		total += base * GeneratorLevelShared.GetMultiplier(level) * mult * TraitShared.COST_SECONDS
	end
	return math.max(TraitShared.MIN_COST, math.floor(total))
end

local function applyTrait(tool: Tool, trait)
	local handle = tool:FindFirstChild("Handle")
	handle:SetAttribute("Trait", trait.key)
	local base = handle:GetAttribute("IncomePerSecond") or 0
	local level = handle:GetAttribute("Level") or 1
	tool:SetAttribute("Income", math.floor(base * GeneratorLevelShared.GetMultiplier(level) * trait.mult))
	pcall(PickupService.RefreshCarryLabel, handle)
end

local function roll(player: Player, list: any, useLuck: any)
	if not loaded[player] then
		return { ok = false, err = "Loading..." }
	end
	local now = os.clock()
	if lastRoll[player] and now - lastRoll[player] < ROLL_COOLDOWN then
		return { ok = false, err = "Too fast!", silent = true }
	end
	local tools = sanitize(player, list)
	if not tools then
		return { ok = false, err = "Select a brainrot first!" }
	end
	local cost = computeCost(player, tools)
	if not MoneyService.RemoveMoney(player, cost) then
		return { ok = false, err = "Not enough money!", cost = cost }
	end
	lastRoll[player] = now

	local luckMult = 1
	if useLuck == true and (luck[player] or 0) > 0 then
		setLuck(player, luck[player] - 1)
		luckMult = TraitShared.LUCK_MULT
	end

	local results = {}
	for _, tool in ipairs(tools) do
		local rolled = TraitShared.Roll(rng, luckMult)
		local current = TraitShared.GetTrait(tool)
		local improved = not current or rolled.rank > current.rank
		if improved then
			applyTrait(tool, rolled)
		end
		local final = TraitShared.GetTrait(tool)
		table.insert(results, { tool = tool, rolled = rolled.key, trait = final and final.key, improved = improved })
	end
	return { ok = true, results = results, cost = cost, luck = luck[player] or 0, lucky = luckMult > 1 }
end

local function grantLuck(player: Player, rolls: number): boolean
	if not loaded[player] then
		return false
	end
	setLuck(player, (luck[player] or 0) + rolls)
	event:FireClient(player, "LuckGranted", { rolls = rolls, total = luck[player] })
	return true
end

AdminGrants.Register("TraitLuck", function(player: Player, rolls: any)
	local t0 = os.clock()
	while not loaded[player] and player.Parent and os.clock() - t0 < 30 do
		task.wait(0.2)
	end
	return grantLuck(player, math.clamp(math.floor(tonumber(rolls) or 0), 1, 1000))
end)

for _, p in ipairs(TraitShared.LUCK_PRODUCTS) do
	PurchaseRouter.Register(p.id, function(player)
		return grantLuck(player, p.rolls)
	end)
end

remote.OnServerInvoke = function(player: Player, action: any, a: any, b: any)
	if action == "GetState" then
		return { luck = luck[player] or 0 }
	elseif action == "GetCost" then
		local tools = sanitize(player, a)
		return tools and computeCost(player, tools) or 0
	elseif action == "Roll" then
		local ok, result = pcall(roll, player, a, b)
		if not ok then
			warn("TraitService: " .. tostring(result))
			return { ok = false, err = "Error, try again" }
		end
		return result
	elseif action == "BuyLuck" then
		local p = TraitShared.GetProduct(tonumber(a) or 0)
		if not p then
			return false
		end
		if p.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, p.id)
			return true
		elseif RunService:IsStudio() then
			return grantLuck(player, p.rolls)
		end
		return false
	end
	return nil
end

local function onPlayerAdded(player: Player)
	local profile = PlayerProfileService.WaitForProfile(player)
	setLuck(player, tonumber(profile.traitLuck) or 0)
	loaded[player] = true
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

PlayerProfileService.RegisterField("traitLuck", function(player: Player)
	if luck[player] == nil and PlayerProfileService.IsLoaded(player) then
		return PlayerProfileService.WaitForProfile(player).traitLuck
	end
	return luck[player]
end)
