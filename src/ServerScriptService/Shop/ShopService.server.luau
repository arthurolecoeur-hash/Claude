--[[
	ShopService
	-----------
	Script serveur dans ServerScriptService.Shop.

	- Game Passes : voir ShopPerks (VIP, x2 Cash, x2 Strength).
	- Strawberry Lucky Block : achete par 1 / 3 / 8 (Developer Products). Les
	  blocs vont dans l'INVENTAIRE (un seul Tool empile, attribut Count) ; le
	  joueur les ouvre en cliquant dessus (sac ou en main).
	- Achat direct 1x1x1x1 : donne le brainrot tout de suite.

	Revenu du brainrot obtenu = % du MEILLEUR brainrot du joueur (voir
	ShopConfig). Il est porte par l'attribut IncomePerSecond + le marqueur
	CustomIncome, et sauvegarde par GeneratorSaveService.

	Sauvegarde des Lucky Blocks non ouverts : champ de profil "luckyBlocks"
	({ [cle] = nombre }). Le Tool est recree au respawn (Roblox vide le sac
	a la mort).

	Remote ReplicatedStorage.Shop.ShopEvent :
	  client -> serveur : "OpenLucky", tool, nombre (1 / 3 / 8) | "StudioBuy", kind, arg
	  serveur -> client : "LuckyOpened", data | "LuckyGranted", data |
	                      "DirectGranted", data
	  serveur -> TOUS   : "LuckyWorld", { kind, owner, left, items = {
	                      { cf, reward, percent, income }, ... } }
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local ShopConfig = require(ReplicatedStorage.Shop.ShopConfig)
local ShopPerks = require(ServerScriptService.Shop.ShopPerks)
local PurchaseRouter = require(ServerScriptService.Purchases.PurchaseRouter)
local PlayerProfileService = require(ServerScriptService.PlayerProfileService)
local PickupService = require(ServerScriptService.Generators.PickupService)
local GeneratorLevelShared = require(ServerScriptService.Generators.GeneratorLevelShared)
local PlotShared = require(ServerScriptService.PlotShared)
local BrainrotFactory = require(ServerScriptService.Brainrots.BrainrotGeneratorFactory)
local InventoryShared = require(ReplicatedStorage.Inventory.InventoryShared)
local NumberFormat = require(ReplicatedStorage.NumberFormat)
local TraitShared = require(ReplicatedStorage.Traits.TraitShared)
local StockService = require(ServerScriptService.Shop.StockService)
local AdminGrants = require(ServerScriptService:WaitForChild("Admin"):WaitForChild("AdminGrants"))
local MarketplaceService = game:GetService("MarketplaceService")

local shopEvent = ReplicatedStorage.Shop.ShopEvent
local toolTemplates = ServerStorage:WaitForChild("Shop")

local LUCKY = ShopConfig.LUCKY_BLOCK
-- Une ouverture (x1 / x3 / x8) a la fois : la roulette dure quelques
-- secondes, le client bloque aussi pendant toute la scene.
local OPEN_COOLDOWN = 3
-- Positions des blocs devant le joueur : { lateral, devant } en studs.
local OPEN_LAYOUTS = {
	[1] = { { 0, 10 } },
	[3] = { { -7, 10 }, { 0, 11 }, { 7, 10 } },
	[8] = {
		{ -10.5, 10 }, { -3.5, 10 }, { 3.5, 10 }, { 10.5, 10 },
		{ -10.5, 18 }, { -3.5, 18 }, { 3.5, 18 }, { 10.5, 18 },
	},
}

local rng = Random.new()

-- Cles faibles partout (voir PlayerProfileService).
local counts = setmetatable({}, { __mode = "k" }) -- Player -> { [key] = n }
local loaded = setmetatable({}, { __mode = "k" }) -- Player -> true
local lastSlot = setmetatable({}, { __mode = "k" }) -- Player -> { [key] = HotbarSlot }
local lastOpen = setmetatable({}, { __mode = "k" }) -- Player -> os.clock()

--== Utilitaires ==--

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and character.Parent ~= nil
end

-- Attend que le joueur soit vivant avec un sac pret (un objet donne pendant
-- qu'il est mort serait efface au respawn). false si il quitte / timeout.
local function waitAlive(player: Player, timeout: number): boolean
	local t0 = os.clock()
	while player.Parent and os.clock() - t0 < timeout do
		if isAlive(player) and player:FindFirstChildOfClass("Backpack") then
			return true
		end
		task.wait(0.25)
	end
	return false
end

local function waitLoaded(player: Player): boolean
	local t0 = os.clock()
	while player.Parent and not loaded[player] and os.clock() - t0 < 30 do
		task.wait(0.1)
	end
	return loaded[player] == true
end

local function getCounts(player: Player)
	local c = counts[player]
	if not c then
		c = {}
		counts[player] = c
	end
	return c
end

--== Tool Lucky Block (un seul, empile) ==--

local function findLuckyTools(player: Player, key: string): { Tool }
	local list = {}
	for _, tool in ipairs(InventoryShared.GetItems(player)) do
		if tool:GetAttribute("ItemType") == InventoryShared.TYPE_LUCKY and tool:GetAttribute("LuckyKey") == key then
			table.insert(list, tool)
		end
	end
	return list
end

local function unequipIfHeld(player: Player, tool: Tool)
	local character = player.Character
	if character and tool.Parent == character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid:UnequipTools()
		end
	end
end

-- Met le sac en accord avec le compteur : cree / met a jour / retire le Tool.
local function syncTool(player: Player, key: string)
	if not isAlive(player) then
		return -- refait au respawn
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end

	local n = getCounts(player)[key] or 0
	local tools = findLuckyTools(player, key)

	-- Doublons eventuels : on n'en garde qu'un.
	for i = #tools, 2, -1 do
		unequipIfHeld(player, tools[i])
		tools[i]:Destroy()
		tools[i] = nil
	end
	local tool = tools[1]

	if n <= 0 then
		if tool then
			unequipIfHeld(player, tool)
			tool:Destroy()
		end
		return
	end

	if not tool then
		local template = toolTemplates:FindFirstChild(key .. "LuckyBlock")
		if not template then
			warn("ShopService: template de Lucky Block introuvable : " .. key)
			return
		end
		tool = template:Clone()
		tool:SetAttribute("Count", n)
		-- Case de hotbar retenue avant la mort, sinon dans le SAC (demande :
		-- les Lucky Blocks apparaissent d'abord dans l'inventaire).
		local remembered = lastSlot[player] and lastSlot[player][key]
		tool:SetAttribute("HotbarSlot", remembered or 0)
		tool:GetAttributeChangedSignal("HotbarSlot"):Connect(function()
			lastSlot[player] = lastSlot[player] or {}
			lastSlot[player][key] = tool:GetAttribute("HotbarSlot")
		end)
		tool.Parent = backpack
	else
		tool:SetAttribute("Count", n)
	end
end

local function addLucky(player: Player, key: string, amount: number)
	local c = getCounts(player)
	c[key] = (c[key] or 0) + amount
	syncTool(player, key)
end

--== Revenu ==--

local function effectiveIncome(part: Instance): number
	local base = part:GetAttribute("IncomePerSecond") or 0
	local level = part:GetAttribute("Level") or 1
	return base * GeneratorLevelShared.GetMultiplier(level) * TraitShared.GetMultiplier(part)
end

local function countsForBest(part: Instance): boolean
	return ShopConfig.COUNT_SHOP_BRAINROTS_IN_BEST or not part:GetAttribute("CustomIncome")
end

-- Revenu/s du meilleur brainrot POSE du joueur (niveau compris). Sans aucun
-- brainrot normal pose : 0 -> les brainrots "%" ne rapportent rien.
local function getBestIncome(player: Player): number
	local best = 0

	local plot = PlotShared.GetPlayerPlot(player)
	if plot then
		for _, slot in ipairs(PlotShared.GetSlots(plot)) do
			for _, child in ipairs(slot:GetChildren()) do
				if child:IsA("BasePart") and child:GetAttribute("IncomePerSecond") and countsForBest(child) and not child:GetAttribute("_retrieving") then
					best = math.max(best, effectiveIncome(child))
				end
			end
		end
	end

	return best
end

local function percentIncome(best: number, percent: number): number
	if best <= 0 then
		return 0
	end
	return math.max(1, math.floor(best * percent / 100 + 0.5))
end

local function createBrainrotTool(name: string, income: number, percent: number?): Tool?
	local template = BrainrotFactory.GetTemplate(name)
	if not template then
		BrainrotFactory.EnsureTemplates()
		template = BrainrotFactory.GetTemplate(name)
	end
	if not template then
		warn("ShopService: template introuvable pour " .. name)
		return nil
	end
	local copy = template:Clone()
	copy:SetAttribute("IncomePerSecond", income)
	copy:SetAttribute("CustomIncome", true)
	copy:SetAttribute("Percent", percent)
	local tool = PickupService.CreateGeneratorTool(copy, 1)
	copy:Destroy()
	return tool
end

-- Donne un brainrot de la boutique (revenu = percent% du meilleur).
local function giveShopBrainrot(player: Player, name: string, percent: number)
	local best = getBestIncome(player)
	local income = percentIncome(best, percent)
	local tool = createBrainrotTool(name, income, percent)
	if not tool then
		return nil
	end
	tool.Parent = player:FindFirstChildOfClass("Backpack")
	return { reward = name, percent = percent, income = income, best = best }
end

--[[
	Brainrots "% du meilleur" : leur revenu suit EN CONTINU le meilleur
	brainrot du joueur (niveau compris). Monter un autre brainrot de niveau
	fait donc monter ceux-la. Eux-memes ne s'upgradent pas (niveau 1 force,
	voir GeneratorUpgradeHandler).
]]
local function percentOf(part: Instance): number?
	local p = part:GetAttribute("Percent")
	if type(p) == "number" then
		return p
	end
	local drop = ShopConfig.GetDrop(part:GetAttribute("BaseName") or part:GetAttribute("DisplayName") or part.Name)
	return drop and drop.percent or nil
end

local function syncShopIncomes(player: Player)
	local parts = {}
	local plot = PlotShared.GetPlayerPlot(player)
	if plot then
		for _, slot in ipairs(PlotShared.GetSlots(plot)) do
			for _, child in ipairs(slot:GetChildren()) do
				if child:IsA("BasePart") and child:GetAttribute("CustomIncome") then
					table.insert(parts, child)
				end
			end
		end
	end
	for _, tool in ipairs(InventoryShared.GetItems(player)) do
		local handle = tool:FindFirstChild("Handle")
		if handle and handle:GetAttribute("CustomIncome") then
			table.insert(parts, handle)
		end
	end
	if #parts == 0 then
		return
	end

	local best = getBestIncome(player)
	for _, part in ipairs(parts) do
		local pct = percentOf(part)
		if pct then
			if part:GetAttribute("Percent") ~= pct then
				part:SetAttribute("Percent", pct)
			end
			local income = percentIncome(best, pct)
			if part:GetAttribute("IncomePerSecond") ~= income then
				part:SetAttribute("IncomePerSecond", income)
			end
			if (part:GetAttribute("Level") or 1) ~= 1 then
				part:SetAttribute("Level", 1)
				GeneratorLevelShared.ApplyScale(part :: BasePart, 1)
			end
			for _, bbName in ipairs({ "InfoDisplay", "CarryDisplay" }) do
				local bb = part:FindFirstChild(bbName)
				if bb then
					local lvl = bb:FindFirstChild("LevelLabel")
					if lvl then
						lvl.Text = ("%d%% of best"):format(pct)
					end
					if bbName == "CarryDisplay" then
						local inc = bb:FindFirstChild("IncomeLabel")
						if inc then
							inc.Text = NumberFormat.FormatPrice(income) .. "/s"
						end
					end
				end
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			if loaded[player] then
				pcall(function()
					player:SetAttribute("BestIncome", getBestIncome(player))
				end)
				local ok, err = pcall(syncShopIncomes, player)
				if not ok then
					warn("ShopService: sync % du meilleur - " .. tostring(err))
				end
			end
		end
	end
end)

--== Position au sol devant le joueur ==--

local function getGroundCFrame(player: Player, side: number, forward: number): CFrame?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return nil
	end

	local exclude = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude

	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.05 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	local right = look:Cross(Vector3.yAxis)

	-- Pas a travers un mur : on raccourcit si besoin.
	local wanted = look * forward + right * side
	local dist = wanted.Magnitude
	local wallHit = workspace:Raycast(root.Position, wanted, params)
	if wallHit and wallHit.Instance.CanCollide and wallHit.Instance.Transparency < 0.95 then
		dist = math.max(3, (wallHit.Position - root.Position).Magnitude - 3.5)
	end
	local flat = root.Position + wanted.Unit * dist

	-- Sol : on ignore les parts invisibles / traversables.
	local origin = flat + Vector3.new(0, 8, 0)
	local ground: Vector3? = nil
	for _ = 1, 6 do
		local hit = workspace:Raycast(origin, Vector3.new(0, -60, 0), params)
		if not hit then
			break
		end
		local part = hit.Instance
		if part.CanCollide and part.Transparency < 0.95 then
			ground = hit.Position
			break
		end
		table.insert(exclude, part)
		params.FilterDescendantsInstances = exclude
	end
	if not ground then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local hip = humanoid and humanoid.HipHeight or 2
		ground = Vector3.new(flat.X, root.Position.Y - root.Size.Y / 2 - hip, flat.Z)
	end

	-- Le bloc fait face au joueur.
	return CFrame.lookAt(ground, ground - look)
end

--== Tirage ==--

local function rollDrop()
	local total = 0
	for _, d in ipairs(LUCKY.drops) do
		total += math.max(0, d.chance)
	end
	local roll = rng:NextNumber(0, total)
	local acc = 0
	for _, d in ipairs(LUCKY.drops) do
		acc += math.max(0, d.chance)
		if roll <= acc then
			return d
		end
	end
	return LUCKY.drops[1]
end

-- Ouvre `amount` Lucky Blocks d'un coup (1, 3 ou 8 : choix dans l'UI qui
-- s'ouvre quand on clique en tenant le bloc). Chaque bloc est pose au sol
-- devant le joueur ; la roulette et l'ouverture sont animees cote clients.
local function openLucky(player: Player, tool: any, amount: any)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return
	end
	if tool:GetAttribute("ItemType") ~= InventoryShared.TYPE_LUCKY then
		return
	end
	local parent = tool.Parent
	if not parent or (parent ~= player:FindFirstChildOfClass("Backpack") and parent ~= player.Character) then
		return
	end
	if not isAlive(player) or not loaded[player] then
		return
	end
	amount = tonumber(amount) or 1
	local layout = OPEN_LAYOUTS[amount]
	if not layout then
		return
	end

	local now = os.clock()
	if lastOpen[player] and now - lastOpen[player] < OPEN_COOLDOWN then
		return
	end

	local key = tool:GetAttribute("LuckyKey") or LUCKY.key
	local c = getCounts(player)
	if (c[key] or 0) < amount then
		syncTool(player, key)
		return
	end
	lastOpen[player] = now

	local items = {}
	for i = 1, amount do
		local drop = rollDrop()
		local result = giveShopBrainrot(player, drop.name, drop.percent)
		if not result then
			break -- rien de consomme pour les suivants
		end
		c[key] -= 1
		local pos = layout[i]
		result.cf = getGroundCFrame(player, pos[1], pos[2])
		table.insert(items, result)
	end
	if #items == 0 then
		return
	end
	syncTool(player, key)

	shopEvent:FireClient(player, "LuckyOpened", { key = key, left = c[key], count = #items })
	shopEvent:FireAllClients("LuckyWorld", {
		kind = "lucky",
		owner = player,
		items = items,
		left = c[key],
	})
end

--== Joueurs ==--

local function onCharacterAdded(player: Player, character: Model)
	-- Roblox repeuple le sac juste apres l'apparition : on attend.
	if not character.Parent then
		character.AncestryChanged:Wait()
	end
	task.wait(0.2)
	if player.Character ~= character or not loaded[player] then
		return
	end
	for key in pairs(getCounts(player)) do
		syncTool(player, key)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)

	local profile = PlayerProfileService.WaitForProfile(player)
	local saved = profile.luckyBlocks
	local c = getCounts(player)
	if type(saved) == "table" then
		for key, n in pairs(saved) do
			if type(key) == "string" and type(n) == "number" and n > 0 then
				c[key] = (c[key] or 0) + math.floor(n)
			end
		end
	end
	loaded[player] = true

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

PlayerProfileService.RegisterField("luckyBlocks", function(player: Player)
	local c = counts[player]
	if not c then
		return nil
	end
	local data = {}
	for key, n in pairs(c) do
		if n > 0 then
			data[key] = n
		end
	end
	return data
end)

--== Achats Robux ==--

local function grantLuckyPack(player: Player, amount: number): boolean
	if not waitLoaded(player) then
		return false
	end
	addLucky(player, LUCKY.key, amount)
	shopEvent:FireClient(player, "LuckyGranted", { key = LUCKY.key, amount = amount, total = getCounts(player)[LUCKY.key] })
	task.spawn(PlayerProfileService.Save, player)
	return true
end

local function grantDirect(player: Player, direct, free: boolean?): boolean
	if not waitLoaded(player) or not waitAlive(player, 30) then
		return false
	end
	local result = giveShopBrainrot(player, direct.name, direct.percent)
	if not result then
		return false
	end
	if not free then
		StockService.Consume(direct.key)
	end
	shopEvent:FireClient(player, "DirectGranted", result)
	result.cf = getGroundCFrame(player, 0, 9)
	if result.cf then
		shopEvent:FireAllClients("LuckyWorld", {
			kind = "direct",
			owner = player,
			items = { result },
		})
	end
	task.spawn(PlayerProfileService.Save, player)
	return true
end

-- Dons du panneau admin (ne touchent pas au stock global).
AdminGrants.Register("Lucky", function(player: Player, amount: any)
	local n = math.clamp(math.floor(tonumber(amount) or 0), 1, 100)
	return grantLuckyPack(player, n)
end)
AdminGrants.Register("Direct", function(player: Player, key: any)
	local direct = ShopConfig.GetDirect(tostring(key))
	return direct ~= nil and grantDirect(player, direct, true)
end)

for _, pack in ipairs(LUCKY.packs) do
	PurchaseRouter.Register(pack.id, function(player)
		return grantLuckyPack(player, pack.amount)
	end)
end
for _, direct in ipairs(ShopConfig.DIRECT_BUYS) do
	if direct.id ~= 0 then
		PurchaseRouter.Register(direct.id, function(player)
			return grantDirect(player, direct)
		end)
	end
end

--== Remote ==--

local lastStudioBuy = setmetatable({}, { __mode = "k" })
local lastBuyPrompt = setmetatable({}, { __mode = "k" })

local function requestDirect(player: Player, direct)
	local now = os.clock()
	if lastBuyPrompt[player] and now - lastBuyPrompt[player] < 1 then
		return
	end
	lastBuyPrompt[player] = now
	if not StockService.HasStock(direct.key) then
		shopEvent:FireClient(player, "SoldOut", direct.key)
		return
	end
	if direct.id ~= 0 then
		MarketplaceService:PromptProductPurchase(player, direct.id)
	elseif RunService:IsStudio() then
		task.spawn(grantDirect, player, direct)
	end
end

game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, player)
	if prompt.Name ~= "PodiumBuyPrompt" then
		return
	end
	local podium = prompt:FindFirstAncestorWhichIsA("Model")
	local direct = podium and ShopConfig.GetDirect(tostring(podium:GetAttribute("DirectKey")))
	if direct then
		requestDirect(player, direct)
	end
end)

--== Podiums (brainrot expose) ==--
task.spawn(function()
	local folder = workspace:WaitForChild("ShopPodiums", 30)
	if not folder then
		return
	end
	local AnimRegistry = require(ServerScriptService.BrainrotAnimRegistry)
	for _, podium in ipairs(folder:GetChildren()) do
		local direct = ShopConfig.GetDirect(tostring(podium:GetAttribute("DirectKey")))
		local anchor = podium:FindFirstChild("DisplayAnchor")
		if direct and anchor then
			local prompt = podium:FindFirstChild("PodiumBuyPrompt", true)
			if prompt then
				prompt.ObjectText = direct.name
			end
			task.spawn(function()
				local template = BrainrotFactory.GetTemplate(direct.name)
				local t0 = os.clock()
				while not template and os.clock() - t0 < 30 do
					task.wait(1)
					template = BrainrotFactory.GetTemplate(direct.name)
				end
				if not template then
					BrainrotFactory.EnsureTemplates()
					template = BrainrotFactory.GetTemplate(direct.name)
				end
				if not template then
					warn("ShopService: pas de modele pour le podium " .. direct.name)
					return
				end
				local display = template:Clone()
				for _, attr in ipairs({ "IncomePerSecond", "IsBrainrot", "CustomIncome", "Percent", "_pickupReady" }) do
					display:SetAttribute(attr, nil)
				end
				for _, d in ipairs(display:GetDescendants()) do
					if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then
						d:Destroy()
					end
				end
				display.Name = "Display"
				display.Anchored = true
				display.CanCollide = false
				display.CanTouch = false
				display.CFrame = anchor.CFrame * CFrame.new(0, display.Size.Y / 2 - 0.1, 0)
				display.Parent = podium
				podium:SetAttribute("DisplayHeight", display.Size.Y)
				local baseName = display:GetAttribute("BaseName") or direct.name
				local waited = 0
				while AnimRegistry.Get(baseName) == nil and waited < 20 do
					task.wait(0.5)
					waited += 0.5
				end
				pcall(BrainrotFactory.PlayIdle, display)
			end)
		end
	end
end)

shopEvent.OnServerEvent:Connect(function(player: Player, action: any, arg1: any, arg2: any)
	if action == "OpenLucky" then
		openLucky(player, arg1, arg2)

	elseif action == "BuyDirect" then
		local direct = ShopConfig.GetDirect(tostring(arg1))
		if direct then
			requestDirect(player, direct)
		end

	elseif action == "StudioBuy" then
		-- MODE TEST : uniquement dans Studio ET pour un objet dont l'ID n'est
		-- pas encore configure. Impossible a declencher en jeu publie.
		if not RunService:IsStudio() then
			return
		end
		local now = os.clock()
		if lastStudioBuy[player] and now - lastStudioBuy[player] < 0.5 then
			return
		end
		lastStudioBuy[player] = now

		if arg1 == "pass" then
			local pass = ShopConfig.GetPass(tostring(arg2))
			if pass and pass.id == 0 then
				ShopPerks.Grant(player, pass.key)
			end
		elseif arg1 == "lucky" then
			for _, pack in ipairs(LUCKY.packs) do
				if pack.amount == arg2 and pack.id == 0 then
					task.spawn(grantLuckyPack, player, pack.amount)
				end
			end
		elseif arg1 == "direct" then
			local direct = ShopConfig.GetDirect(tostring(arg2))
			if direct and direct.id == 0 then
				task.spawn(grantDirect, player, direct)
			end
		end
	end
end)
