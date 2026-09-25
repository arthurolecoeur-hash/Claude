--[[
	SpeedRobuxHandler
	------------------
	Script (serveur) a placer dans ServerScriptService.Training.

	Achats Robux de Speed (Developer Products, voir SpeedRobuxProducts pour les
	ID a configurer).

	Ce script ne pose PLUS lui-meme MarketplaceService.ProcessReceipt : Roblox
	n'en accepte qu'un seul pour tout le jeu, et le poser ici empechait tout
	autre systeme d'encaisser (c'etait deja le cas des achats de sacs, qui
	tombaient dans le "ProductId inconnu"). Il enregistre ses produits aupres
	de PurchaseRouter, qui centralise le recu et la deduplication.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SpeedRobuxProducts = require(ReplicatedStorage.Training:WaitForChild("SpeedRobuxProducts"))
local SpeedService = require(ServerScriptService.Training.SpeedService)
local PurchaseRouter = require(ServerScriptService.Purchases.PurchaseRouter)

for productId, amount in pairs(SpeedRobuxProducts.AMOUNT_BY_PRODUCT_ID) do
	PurchaseRouter.Register(productId, function(player)
		return SpeedService.AddSpeed(player, amount)
	end)
end
