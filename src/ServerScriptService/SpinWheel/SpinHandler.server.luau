--[[
	SpinHandler
	-----------
	Script (serveur) a placer dans ServerScriptService.SpinWheel.

	Demarre SpinService (un ModuleScript ne se lance pas tout seul) et traite
	les demandes de spin venant du bouton du HUD.

	TOUT est valide ici : le client ne fait que demander. C'est le serveur qui
	verifie que le joueur a bien un spin (SpinService.TryConsumeSpin), tire le
	lot et cree l'argent. Un client modifie ne peut donc pas s'offrir de spins.

	La liste des lots vit dans ReplicatedStorage.SpinWheelShared, pour que le
	client dessine exactement les memes secteurs et fasse tomber l'aiguille au
	bon endroit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SpinService = require(ServerScriptService.SpinWheel.SpinService)
local BoostService = require(ServerScriptService.SpinWheel.BoostService)
local MoneyService = require(ServerScriptService.Money.MoneyService)
local PurchaseRouter = require(ServerScriptService.Purchases.PurchaseRouter)
local PickupService = require(ServerScriptService.Generators.PickupService)
local BrainrotFactory = require(ServerScriptService.Brainrots.BrainrotGeneratorFactory)

-- Donne le brainrot gagne dans le sac du joueur (meme chemin que la
-- livraison d'un brainrot ramasse : BrainrotCarryService.deliver).
local function grantBrainrot(player: Player, name: string): boolean
	local template = BrainrotFactory.GetTemplate(name)
	if not template then
		warn(("SpinHandler: template '%s' introuvable dans ServerStorage.BrainrotGenerators"):format(name))
		return false
	end
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return false
	end
	local tool = PickupService.CreateGeneratorTool(template)
	tool.Parent = backpack
	return true
end
local SpinRobuxProducts = require(ReplicatedStorage:WaitForChild("SpinRobuxProducts"))

--== Achats Robux de spins ==--
-- Les spins achetes s'ajoutent au total sans aucun plafond, et sans compter
-- comme des gratuits : le timer des gratuits continue donc de tourner
-- normalement par-dessus.
for productId, amount in pairs(SpinRobuxProducts.AMOUNT_BY_PRODUCT_ID) do
	PurchaseRouter.Register(productId, function(player)
		return SpinService.GrantSpins(player, amount)
	end)
end
local Shared = require(ReplicatedStorage:WaitForChild("SpinWheelShared"))

-- Cree le RemoteEvent s'il n'existe pas encore, plutot qu'un WaitForChild seul
-- qui bloquerait tout le script si l'instance venait a manquer (meme pattern
-- defensif que GeneratorUpgradeHandler / RebirthHandler).
local spinEvent = ReplicatedStorage:FindFirstChild("SpinWheelEvent")
if not spinEvent then
	spinEvent = Instance.new("RemoteEvent")
	spinEvent.Name = "SpinWheelEvent"
	spinEvent.Parent = ReplicatedStorage
end

-- Generateur dedie : math.random global est partage par tous les scripts du
-- serveur, un Random propre rend les tirages independants du reste.
local rng = Random.new()

-- Renvoie l'INDEX du lot, pas le lot : le client a besoin de l'index pour
-- savoir sur quel secteur arreter la roue.
local function rollPrizeIndex(): number
	local roll = rng:NextNumber() * Shared.TotalWeight
	local acc = 0
	for index, prize in ipairs(Shared.Prizes) do
		acc += prize.weight
		if roll <= acc then
			return index
		end
	end
	return 1 -- filet de securite (erreurs d'arrondi flottant)
end

-- Anti-spam : un joueur ne peut pas enchainer deux demandes coup sur coup,
-- meme s'il a plusieurs spins en stock. La duree couvre l'animation de la
-- roue cote client.
local lastRequest = setmetatable({}, { __mode = "k" })
local REQUEST_COOLDOWN = 4

spinEvent.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	local last = lastRequest[player]
	if last and now - last < REQUEST_COOLDOWN then
		-- IMPORTANT : on repond quand meme. Un simple `return` laissait le
		-- client bloque sur "SPINNING..." pour toujours, puisqu'il attend une
		-- reponse pour reactiver le bouton.
		spinEvent:FireClient(player, {
			ok = false,
			reason = "cooldown",
			retryIn = REQUEST_COOLDOWN - (now - last),
		})
		return
	end
	lastRequest[player] = now

	if not SpinService.TryConsumeSpin(player) then
		spinEvent:FireClient(player, { ok = false, reason = "no_spin" })
		return
	end

	local index = rollPrizeIndex()
	local prize = Shared.Prizes[index]

	if prize.boost then
		-- Boost de revenu : rien n'est credite maintenant, c'est
		-- MoneyGeneratorService qui multipliera le revenu pendant la duree.
		BoostService.GrantBoost(player, prize.boost.multiplier, prize.boost.duration)
		spinEvent:FireClient(player, {
			ok = true,
			index = index,
			label = prize.label,
			boostSeconds = prize.boost.duration,
		})
		return
	end

	if prize.brainrot then
		if not grantBrainrot(player, prize.brainrot) then
			-- echec improbable (template manquant) : on rend le spin
			SpinService.GrantSpins(player, 1)
			spinEvent:FireClient(player, { ok = false, reason = "error" })
			return
		end
		spinEvent:FireClient(player, {
			ok = true,
			index = index,
			label = prize.label,
			brainrot = prize.brainrot,
		})
		return
	end

	local amount = prize.cash or 0
	if amount > 0 then
		MoneyService.AddMoney(player, amount)
	end

	spinEvent:FireClient(player, {
		ok = true,
		index = index,
		label = prize.label,
		amount = amount,
	})
end)
