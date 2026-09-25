--[[
	PlayerProfileService
	---------------------
	ModuleScript a placer directement dans ServerScriptService.

	AVANT ce module, chaque connexion de joueur declenchait 8 GetAsync
	separes (un par systeme : Money, Generators, Inventory, Rebirths,
	Force, Speed, BagTier, BaseLevel), et chaque deconnexion 8 SetAsync -
	sans compter les 3 tentatives de retry de chacun en cas d'echec
	reseau. Ce module fusionne tout ca en UN SEUL profil par joueur : 1
	GetAsync au join, 1 SetAsync a la deconnexion (+ BindToClose).

	MIGRATION : la premiere fois qu'un joueur qui a deja des sauvegardes
	(sous l'ancien systeme) se connecte apres ce changement, aucun profil
	fusionne n'existe encore pour lui - ce module lit alors, EN PARALLELE,
	les 8 anciens DataStores separes (jamais plus ecrits ensuite) pour
	reconstruire son profil, qui est desormais sauvegarde sous le nouveau
	format. Aucune progression n'est perdue.

	Utilisation depuis un service qui possede un champ du profil (ex:
	MoneyService pour "money") :

		local PlayerProfileService = require(ServerScriptService.PlayerProfileService)

		-- Au join : recupere la valeur sauvegardee (nil si jamais sauvegardee)
		local profile = PlayerProfileService.WaitForProfile(player)
		cash.Value = profile.money or STARTING_MONEY

		-- Une fois : indique COMMENT relire la valeur ACTUELLE de ce champ
		-- au moment de sauvegarder (pas de require croise avec les autres
		-- services - chacun s'enregistre lui-meme, PlayerProfileService ne
		-- connait le sens d'aucun champ).
		PlayerProfileService.RegisterField("money", function(player)
			return cashValues[player] and cashValues[player].Value or STARTING_MONEY
		end)

	IMPORTANT (ordre de sauvegarde a la deconnexion) : PlayerProfileService
	est LE SEUL a sauvegarder (Players.PlayerRemoving + BindToClose) - les
	services ne doivent plus faire leur propre SetAsync. Comme l'ordre entre
	plusieurs connexions PlayerRemoving de scripts differents n'est pas
	garanti, chaque service DOIT garder ses caches (cashValues, etc.) dans
	une table a cles FAIBLES (setmetatable({}, { __mode = "k" })) et ne
	JAMAIS faire cache[player] = nil dans son propre PlayerRemoving : sinon,
	si ce nettoyage s'execute AVANT le Save() de PlayerProfileService, le
	getter enregistre renverrait la valeur par defaut au lieu de la vraie
	valeur, et la derniere session du joueur serait perdue. Les tables a
	cles faibles se nettoient toutes seules (a la destruction du Player)
	sans risque d'ordre.
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local PlayerProfileService = {}

local profileStore = DataStoreService:GetDataStore("PlayerProfile_v1")

-- Anciens DataStores (lecture SEULE, pour la migration au premier join
-- suivant ce changement - plus jamais ecrits ensuite).
local legacyStores = {
	money = DataStoreService:GetDataStore("PlayerMoney_v1"),
	generators = DataStoreService:GetDataStore("RanchGenerators_v1"),
	inventory = DataStoreService:GetDataStore("RanchInventory_v1"),
	rebirths = DataStoreService:GetDataStore("PlayerRebirths_v1"),
	force = DataStoreService:GetDataStore("PlayerForce_v1"),
	speed = DataStoreService:GetDataStore("PlayerSpeed_v1"),
	bagTier = DataStoreService:GetDataStore("PlayerBagTier_v1"),
	baseLevel = DataStoreService:GetDataStore("BaseLevel_v1"),
}

local SAVE_RETRY_ATTEMPTS = 3

-- Tables a cles FAIBLES : sans ca, chaque Player ayant rejoint le serveur
-- restait reference ici pour toute la duree de vie du serveur (fuite
-- memoire qui grossit a chaque connexion). Avec __mode = "k", l'entree
-- disparait d'elle-meme une fois le Player detruit, sans qu'on ait a la
-- nettoyer a la main dans PlayerRemoving (ce qui casserait la sauvegarde,
-- cf. commentaire d'en-tete sur l'ordre des connexions).
local profiles = setmetatable({}, { __mode = "k" }) -- Player -> profil charge (table de champs bruts)
local pendingLoads = setmetatable({}, { __mode = "k" }) -- Player -> BindableEvent (chargement deja en cours, evite un double GetAsync)
-- Joueurs dont le chargement a ECHOUE (panne DataStore) : leur profil est
-- vide, donc le sauvegarder ecraserait leur vraie progression par des
-- valeurs par defaut. Aucune sauvegarde pour eux, et ils sont kick.
local loadFailed = setmetatable({}, { __mode = "k" })
local fieldGetters = {} -- nom de champ -> function(player): any (rempli par RegisterField)
-- Appeles a la deconnexion, APRES la photo du profil : un service peut alors
-- remettre a zero ce qui appartenait au joueur (sa base) sans risquer de
-- vider les donnees avant qu'elles soient lues pour la sauvegarde.
local releaseCallbacks: { (Player) -> () } = {}

-- Sauvegarde periodique : sans ca, un crash/arret brutal du serveur faisait
-- perdre TOUTE la session du joueur (rien n'etait ecrit entre le join et la
-- deconnexion). Etale par joueur pour ne pas envoyer toutes les requetes au
-- meme tick.
local AUTOSAVE_INTERVAL = 120
local lastSaveAt = setmetatable({}, { __mode = "k" }) -- Player -> os.clock() de la derniere sauvegarde

local function tryDataStoreCall(fn, description: string): (boolean, any)
	for attempt = 1, SAVE_RETRY_ATTEMPTS do
		local success, result = pcall(fn)
		if success then
			return true, result
		end
		warn(("PlayerProfileService: %s (essai %d/%d) - %s"):format(
			description, attempt, SAVE_RETRY_ATTEMPTS, tostring(result)
			))
		task.wait(1)
	end
	return false, nil
end

local function loadLegacyValue(key: string, player: Player): (boolean, any)
	local store = legacyStores[key]
	if not store then
		return true, nil
	end
	local dsKey = "Player_" .. player.UserId
	local success, result = pcall(function()
		return store:GetAsync(dsKey)
	end)
	if success then
		return true, result
	end
	warn(("PlayerProfileService: echec migration legacy '%s' pour %s - %s"):format(key, player.Name, tostring(result)))
	return false, nil
end

-- Charge (ou migre) le profil d'un joueur. Jamais appele directement de
-- l'exterieur : passe toujours par WaitForProfile.
local function loadProfile(player: Player): ({ [string]: any }, boolean)
	local dsKey = "Player_" .. player.UserId

	local ok, result = tryDataStoreCall(function()
		return profileStore:GetAsync(dsKey)
	end, "echec chargement profil pour " .. player.Name)

	if not ok then
		-- GetAsync a echoue : on ne sait PAS si le joueur a une sauvegarde.
		-- Surtout ne pas enchainer sur la migration (qui renverrait un
		-- profil vide, sauvegarde ensuite par-dessus la vraie progression).
		return {}, false
	end
	if result ~= nil then
		return result, true
	end

	-- Pas encore de profil fusionne pour ce joueur : migration depuis les
	-- 8 anciens DataStores separes, EN PARALLELE (ce sont des DataStores
	-- differents, donc des lectures independantes) plutot que les unes
	-- apres les autres, pour ne pas cumuler leurs latences sur ce join -
	-- seule la connexion suivant le deploiement de ce systeme paie ce
	-- cout, une fois par joueur.
	local migrated = {}
	local allOk = true
	local remaining = 0
	for _ in pairs(legacyStores) do
		remaining += 1
	end

	for key in pairs(legacyStores) do
		task.spawn(function()
			local legacyOk, value = loadLegacyValue(key, player)
			if legacyOk then
				migrated[key] = value
			else
				allOk = false
			end
			remaining -= 1
		end)
	end

	while remaining > 0 do
		task.wait(0.05)
	end

	return migrated, allOk
end

-- A appeler par tout service ayant besoin du profil charge d'un joueur -
-- garantit un SEUL GetAsync (+ migration eventuelle) par joueur, meme si
-- plusieurs services l'appellent en parallele au join (PlayerAdded de
-- scripts differents s'executent chacun dans leur propre thread).
function PlayerProfileService.WaitForProfile(player: Player): { [string]: any }
	local existing = profiles[player]
	if existing then
		return existing
	end

	local pending = pendingLoads[player]
	if pending then
		pending.Event:Wait() -- BindableEvent.Event est le VRAI signal attendable (pas le BindableEvent lui-meme)
		return profiles[player]
	end

	local event = Instance.new("BindableEvent")
	pendingLoads[player] = event
	local profile, ok = loadProfile(player)
	if not ok then
		loadFailed[player] = true
		task.defer(function()
			if player.Parent then
				player:Kick("Impossible de charger ta sauvegarde (serveurs Roblox). Reconnecte-toi, ta progression est intacte.")
			end
		end)
	end
	profiles[player] = profile
	pendingLoads[player] = nil
	event:Fire()
	event:Destroy()

	return profile
end

-- Enregistre comment relire la valeur ACTUELLE d'un champ du profil au
-- moment de sauvegarder. Aucun require croise necessaire : chaque service
-- proprietaire d'un champ (money, generators, inventory, rebirths, force,
-- speed, bagTier, baseLevel) s'enregistre lui-meme au demarrage.
-- true si le profil est charge ET sauvegardable (pas en echec de chargement).
function PlayerProfileService.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil and not loadFailed[player]
end

-- `callback(player)` est appele a la deconnexion, une fois les donnees du
-- joueur lues pour la sauvegarde finale (ou tout de suite s'il n'y a rien
-- a sauvegarder). C'est ici, et non dans un PlayerRemoving, qu'on libere
-- et nettoie ce que le joueur possedait.
function PlayerProfileService.OnPlayerReleased(callback: (Player) -> ())
	table.insert(releaseCallbacks, callback)
end

function PlayerProfileService.RegisterField(fieldName: string, getter: (Player) -> any)
	fieldGetters[fieldName] = getter
end

-- Part du profil charge : un champ dont le service n'est pas (encore)
-- enregistre n'est plus efface a la sauvegarde.
local function collectProfile(player: Player): { [string]: any }
	local data = table.clone(profiles[player])
	for fieldName, getter in pairs(fieldGetters) do
		local ok, value = pcall(getter, player)
		if ok then
			data[fieldName] = value
		else
			warn(("PlayerProfileService: echec lecture du champ '%s' pour %s - %s"):format(fieldName, player.Name, tostring(value)))
		end
	end
	return data
end

local writeProfile: (Player, { [string]: any }) -> ()

-- Sauvegarde immediate du profil COMPLET (tous les champs enregistres),
-- en UN SEUL SetAsync. A utiliser pour un "force une sauvegarde tout de
-- suite" ponctuel (ex: apres un gros achat) - la sauvegarde normale a la
-- deconnexion/BindToClose est deja geree automatiquement ci-dessous.
function PlayerProfileService.Save(player: Player)
	if not profiles[player] then
		return -- profil jamais charge (le joueur n'est pas reste assez longtemps) - rien a sauvegarder
	end
	if loadFailed[player] then
		return -- chargement echoue : sauvegarder ecraserait la vraie progression
	end
	writeProfile(player, collectProfile(player))
end

writeProfile = function(player: Player, data: { [string]: any })
	local dsKey = "Player_" .. player.UserId
	lastSaveAt[player] = os.clock()
	-- UpdateAsync plutot que SetAsync : si deux serveurs ecrivent la meme cle
	-- (ex: le joueur rejoint un autre serveur pendant que celui-ci sauvegarde),
	-- SetAsync ecrase aveuglement la valeur la plus recente. UpdateAsync passe
	-- par le systeme de versions du DataStore et serialise les ecritures.
	tryDataStoreCall(function()
		profileStore:UpdateAsync(dsKey, function()
			return data
		end)
	end, "echec sauvegarde profil pour " .. player.Name)
end

Players.PlayerRemoving:Connect(function(player: Player)
	-- Photo prise tout de suite (sans yield), AVANT de liberer la base.
	local data = if PlayerProfileService.IsLoaded(player) then collectProfile(player) else nil
	for _, callback in ipairs(releaseCallbacks) do
		task.spawn(callback, player)
	end
	if data then
		writeProfile(player, data)
	end
end)

-- Boucle d'autosave (voir AUTOSAVE_INTERVAL). Chaque joueur est sauvegarde
-- dans son propre thread pour qu'un GetAsync lent ne bloque pas les autres.
task.spawn(function()
	while true do
		task.wait(10)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local last = lastSaveAt[player]
			if profiles[player] and not loadFailed[player] and (not last or now - last >= AUTOSAVE_INTERVAL) then
				lastSaveAt[player] = now -- pose tout de suite pour ne pas relancer la meme sauvegarde au tick suivant
				task.spawn(PlayerProfileService.Save, player)
			end
		end
	end
end)

-- Roblox n'accorde qu'environ 30 secondes a BindToClose. La version
-- precedente sauvegardait les joueurs LES UNS APRES LES AUTRES, et chaque
-- echec reseau coute jusqu'a 3 essais x 1s d'attente : avec plusieurs
-- joueurs, le budget explosait et les derniers n'etaient jamais ecrits.
-- On lance tout en parallele et on attend que l'ensemble soit fini.
game:BindToClose(function()
	local players = Players:GetPlayers()
	local remaining = #players
	if remaining == 0 then
		return
	end

	for _, player in ipairs(players) do
		task.spawn(function()
			PlayerProfileService.Save(player)
			remaining -= 1
		end)
	end

	local deadline = os.clock() + 25
	while remaining > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end)

return PlayerProfileService
