--[[
	PurchaseRouter
	--------------
	ModuleScript a placer dans ServerScriptService.Purchases.

	POURQUOI CE MODULE :
	Roblox n'accepte QU'UN SEUL MarketplaceService.ProcessReceipt pour tout le
	jeu - le dernier script qui l'affecte ecrase tous les autres. Avant ce
	routeur, c'etait SpeedRobuxHandler qui le posait, et lui seul connaissait
	les produits Speed. Tout autre produit tombait donc dans son `warn` et
	repartait en NotProcessedYet.

	Ici, un seul ProcessReceipt vit dans ce module, et chaque systeme enregistre
	ses produits :

		PurchaseRouter.Register(productId, function(player, receiptInfo)
			-- accorde l'achat ; renvoie true si c'est fait
			return true
		end)

	La deduplication (DataStore "PurchaseHistory") est faite ICI, une fois pour
	tous les systemes : un recu re-livre par Roblox apres un crash serveur n'est
	jamais accorde deux fois.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerProfileService = require(ServerScriptService.PlayerProfileService)

local PurchaseRouter = {}

local purchaseHistoryStore = DataStoreService:GetDataStore("RobuxPurchaseHistory_v1")

-- [productId] = function(player, receiptInfo) -> boolean
local handlers = {}

--[[
	Enregistre le traitement d'un produit. `grant` doit accorder l'achat et
	renvoyer true ; renvoyer false fait repartir le recu en NotProcessedYet
	(Roblox reessaiera), ce qui est le bon comportement si une dependance n'est
	pas prete.
]]
function PurchaseRouter.Register(productId: number, grant: (Player, any) -> boolean)
	if not productId or productId == 0 then
		return -- ID pas encore configure, on ignore silencieusement
	end
	if handlers[productId] then
		warn(("PurchaseRouter: le produit %d est deja enregistre, il sera ecrase"):format(productId))
	end
	handlers[productId] = grant
end

local function processReceipt(receiptInfo)
	local grant = handlers[receiptInfo.ProductId]
	if not grant then
		-- Produit inconnu : on ne peut rien accorder, mais surtout on ne marque
		-- pas le recu comme traite, sinon le joueur aurait paye pour rien.
		warn("PurchaseRouter: ProductId inconnu " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Deconnecte avant traitement : Roblox reessaiera a sa prochaine session.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Profil pas encore charge (achat pendant le join) ou en echec : ce qui
	-- serait accorde ne pourrait pas etre sauvegarde. Roblox reessaiera.
	if not PlayerProfileService.IsLoaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local historyKey = tostring(receiptInfo.PurchaseId)
	local alreadyGranted = false
	local readOk = pcall(function()
		alreadyGranted = purchaseHistoryStore:GetAsync(historyKey) ~= nil
	end)
	if not readOk then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- DataStore muet, on reessaiera
	end

	if not alreadyGranted then
		local ok, granted = pcall(grant, player, receiptInfo)
		if not ok then
			warn("PurchaseRouter: erreur du handler pour " .. tostring(receiptInfo.ProductId) .. " - " .. tostring(granted))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		if granted == false then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Sauvegarde AVANT de confirmer a Roblox : un crash serveur juste
		-- apres ne fait plus perdre l'achat.
		PlayerProfileService.Save(player)

		local saveOk = pcall(function()
			purchaseHistoryStore:SetAsync(historyKey, os.time())
		end)
		if not saveOk then
			-- Accorde mais pas marque : si Roblox redonne ce recu, on accordera
			-- une seconde fois. Rare, et prefere a un joueur qui paie sans rien
			-- recevoir.
			warn("PurchaseRouter: echec sauvegarde historique pour " .. historyKey)
		end
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

MarketplaceService.ProcessReceipt = processReceipt

return PurchaseRouter
