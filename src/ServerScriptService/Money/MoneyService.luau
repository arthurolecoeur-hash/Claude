--[[
	MoneyService
	------------
	ModuleScript à placer dans ServerScriptService.

	Gère l'argent des joueurs :
	  - Crée un leaderstats "Cash" visible pour chaque joueur
	  - Sauvegarde/charge automatiquement avec un DataStore
	  - Fournit une API simple pour ajouter/retirer/lire l'argent

	Utilisation depuis un autre script :

		local MoneyService = require(game.ServerScriptService.Money.MoneyService)

		MoneyService.GetMoney(player)              -> nombre
		MoneyService.AddMoney(player, 500)          -> ajoute 500
		MoneyService.RemoveMoney(player, 200)       -> retire 200 (false si pas assez)
		MoneyService.SetMoney(player, 1000)         -> fixe la valeur
		MoneyService.MoneyChanged:Connect(function(player, nouveau, ancien) end)

	IMPORTANT : Active "Enable Studio Access to API Services" dans
	Game Settings > Security pour tester le DataStore en Studio.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local PlayerProfileService = require(ServerScriptService.PlayerProfileService)

local MoneyService = {}

local STARTING_MONEY = 0

-- Cache local : Player -> NumberValue (référence vers leaderstats.Cash)
-- NumberValue (double) plutôt qu'IntValue : IntValue est un entier 32 bits
-- qui déborde/plante autour de ~2.1 milliards, largement en dessous de ce
-- que le HUD peut afficher (K/M/B/T/Qa/Qn/Sx/Sp/Oc/No/De/...).
-- Table a cles FAIBLES (voir PlayerProfileService) : ne JAMAIS faire
-- cashValues[player] = nil a la deconnexion, le getter enregistre plus bas
-- doit pouvoir relire la valeur jusqu'a la toute derniere sauvegarde.
local cashValues = setmetatable({}, { __mode = "k" })
-- Joueurs deja en cours d'init (evite un double leaderstats : l'ancien
-- code avait DEUX boucles de rattrapage qui lancaient onPlayerAdded deux
-- fois, car cashValues n'est rempli qu'apres WaitForProfile).
local initializing = setmetatable({}, { __mode = "k" })
-- Argent tel que charge : renvoye a la sauvegarde tant que Cash n'existe
-- pas encore, au lieu de STARTING_MONEY (qui effacerait l'argent).
local loadedMoney = setmetatable({}, { __mode = "k" })

local moneyChangedEvent = Instance.new("BindableEvent")
MoneyService.MoneyChanged = moneyChangedEvent.Event

local LOAD_TIMEOUT = 15

-- Montant valide : nombre fini (pas NaN / inf).
local function isValidAmount(amount: any): boolean
	return type(amount) == "number" and amount == amount and amount ~= math.huge and amount ~= -math.huge
end

local function onPlayerAdded(player: Player)
	if initializing[player] or cashValues[player] then
		return
	end
	initializing[player] = true

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	local profile = PlayerProfileService.WaitForProfile(player)
	if not player.Parent then
		return
	end

	local saved = profile and profile.money
	loadedMoney[player] = saved
	local cash = Instance.new("NumberValue")
	cash.Name = "Cash"
	cash.Value = (isValidAmount(saved) and saved >= 0) and saved or STARTING_MONEY
	cash.Parent = leaderstats

	cashValues[player] = cash
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- Rattrape les joueurs deja connectes (require en lazy, voir BaseSetup).
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Attend que l'argent soit charge (au lieu d'echouer en silence si un
-- achat/gain arrive pendant le chargement du profil).
local function getCash(player: Player): NumberValue?
	local cash = cashValues[player]
	if cash then
		return cash
	end
	local deadline = os.clock() + LOAD_TIMEOUT
	while not cashValues[player] and player.Parent and os.clock() < deadline do
		task.wait()
	end
	cash = cashValues[player]
	if not cash then
		warn("MoneyService: pas de valeur Cash pour " .. player.Name)
	end
	return cash
end

-- Indique a PlayerProfileService comment relire l'argent ACTUEL de ce
-- joueur au moment de sauvegarder (PlayerProfileService se charge seul de
-- QUAND sauvegarder : deconnexion + BindToClose, en un seul SetAsync
-- partage avec tous les autres champs du profil).
PlayerProfileService.RegisterField("money", function(player: Player): number
	local cash = cashValues[player]
	if cash then
		return cash.Value
	end
	local saved = loadedMoney[player]
	return if isValidAmount(saved) then saved else STARTING_MONEY
end)

local function setCash(player: Player, cash: NumberValue, value: number)
	local old = cash.Value
	cash.Value = value
	if value ~= old then
		moneyChangedEvent:Fire(player, value, old)
	end
end

--== API publique ==--

-- Retourne l'argent actuel du joueur (0 si pas encore chargé)
function MoneyService.GetMoney(player: Player): number
	local cash = cashValues[player]
	return cash and cash.Value or 0
end

function MoneyService.IsLoaded(player: Player): boolean
	return cashValues[player] ~= nil
end

function MoneyService.CanAfford(player: Player, amount: number): boolean
	return isValidAmount(amount) and MoneyService.GetMoney(player) >= amount
end

-- Ajoute un montant. Négatif = retrait, refusé (false) si pas assez d'argent.
function MoneyService.AddMoney(player: Player, amount: number): boolean
	if not isValidAmount(amount) then
		warn("MoneyService.AddMoney: montant invalide", amount)
		return false
	end
	if amount < 0 then
		return MoneyService.RemoveMoney(player, -amount)
	end
	local cash = getCash(player)
	if not cash then
		return false
	end
	setCash(player, cash, cash.Value + amount)
	return true
end

-- Retire un montant. Retourne false si pas assez d'argent (rien n'est retiré)
function MoneyService.RemoveMoney(player: Player, amount: number): boolean
	if not isValidAmount(amount) or amount < 0 then
		warn("MoneyService.RemoveMoney: montant invalide", amount)
		return false
	end
	local cash = getCash(player)
	if not cash or cash.Value < amount then
		return false
	end
	setCash(player, cash, cash.Value - amount)
	return true
end

-- Fixe directement la valeur (>= 0)
function MoneyService.SetMoney(player: Player, amount: number): boolean
	if not isValidAmount(amount) then
		warn("MoneyService.SetMoney: montant invalide", amount)
		return false
	end
	local cash = getCash(player)
	if not cash then
		return false
	end
	setCash(player, cash, math.max(0, amount))
	return true
end

-- Force une sauvegarde immédiate (utile après un gros achat par exemple).
-- Sauvegarde maintenant le PROFIL COMPLET (tous les champs, un seul
-- SetAsync) plutôt que juste l'argent - comportement équivalent pour
-- l'appelant, en mieux (jamais désynchronisé du reste du profil).
function MoneyService.Save(player: Player)
	PlayerProfileService.Save(player)
end

return MoneyService