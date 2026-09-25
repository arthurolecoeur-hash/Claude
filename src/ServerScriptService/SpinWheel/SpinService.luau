--[[
	SpinService
	-----------
	ModuleScript a placer dans ServerScriptService.SpinWheel.

	Donne UN spin gratuit toutes les 25 minutes. Seule l'ACCUMULATION DE SPINS
	GRATUITS est plafonnee (MAX_FREE_STORED) : le total de spins d'un joueur,
	lui, n'a aucune limite, les achats et les dons s'empilent librement.
	La progression passe par PlayerProfileService, comme tous les autres
	systemes du jeu : un seul GetAsync au join et un seul SetAsync a la
	deconnexion, pas de DataStore dedie.

	COMMUNICATION AVEC LE CLIENT :
	Aucun RemoteEvent. Deux Attributes sur le Player, que Roblox replique tout
	seul au client concerne :
	  WheelSpins       (number) -- spins disponibles
	  WheelNextSpinAt  (number) -- date d'arrivee du prochain spin

	WheelNextSpinAt est exprime dans l'horloge de workspace:GetServerTimeNow(),
	qui est SYNCHRONISEE entre serveur et client - contrairement a os.time(),
	dont le client peut etre decale de plusieurs secondes. Le client peut donc
	faire son decompte tout seul, sans que le serveur ait a lui pousser le
	temps restant chaque seconde.

	API :
		SpinService.GetSpins(player)          -> number
		SpinService.TryConsumeSpin(player)    -> boolean (false si aucun spin)
		SpinService.GrantSpins(player, n)
		SpinService.GetSecondsLeft(player)    -> number
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerProfileService = require(ServerScriptService.PlayerProfileService)

local SpinService = {}

local SPIN_INTERVAL = 25 * 60 -- 25 minutes
local MAX_FREE_STORED = 5     -- plafond des spins GRATUITS non depenses
local STARTING_SPINS = 1      -- un spin offert a la toute premiere connexion

--[[
	IL N'Y A AUCUN PLAFOND SUR LE TOTAL DE SPINS.

	Le plafond ne porte que sur les spins GRATUITS accumules : passe 5 en
	stock, le timer se met en pause et ne redistribue qu'une fois le joueur
	redescendu. Les spins achetes, offerts ou donnes par commande s'ajoutent
	par-dessus sans limite, et n'empechent jamais le timer de tourner.

	C'est pour ca que l'etat suit DEUX compteurs : `spins` est le total
	utilisable, `free` la part de ce total qui vient du timer. Consommer un
	spin retire d'abord de `free`, donc un joueur qui achete un pack continue
	d'accumuler ses gratuits normalement.
]]

-- Table a cles FAIBLES, comme le reste du jeu (voir PlayerProfileService) :
-- jamais nettoyee a la main a la deconnexion, pour que le getter enregistre
-- plus bas reste valide jusqu'a la derniere sauvegarde.
-- [player] = { spins = number, free = number, nextAtUnix = number }
local states = setmetatable({}, { __mode = "k" })

local function pushAttributes(player: Player)
	local state = states[player]
	if not state then
		return
	end
	player:SetAttribute("WheelSpins", state.spins)
	-- le client en a besoin pour afficher "MAX FREE SPINS" sans croire que le
	-- total est plafonne
	player:SetAttribute("WheelFreeSpins", state.free)
	-- Conversion os.time() -> horloge serveur synchronisee (cf. en-tete)
	local secondsLeft = math.max(0, state.nextAtUnix - os.time())
	player:SetAttribute("WheelNextSpinAt", workspace:GetServerTimeNow() + secondsLeft)
end

-- Rattrape tous les spins gratuits dus depuis `nextAtUnix`, y compris ceux
-- gagnes pendant que le joueur etait deconnecte.
local function accrue(state)
	local now = os.time()

	-- Garde-fou : une echeance sauvegardee ne doit jamais depasser un
	-- intervalle complet. Sans ca, un joueur reste bloque a attendre une date
	-- devenue absurde - par exemple si SPIN_INTERVAL est raccourci apres coup,
	-- ou si une valeur erronee se retrouve dans le profil.
	if state.nextAtUnix > now + SPIN_INTERVAL then
		state.nextAtUnix = now + SPIN_INTERVAL
	end

	if state.free >= MAX_FREE_STORED then
		-- Stock de GRATUITS plein : le timer ne tourne pas, il repart quand le
		-- joueur en depensera un. Le total, lui, peut etre bien plus haut.
		state.nextAtUnix = now + SPIN_INTERVAL
		return false
	end

	if now < state.nextAtUnix then
		return false
	end

	local due = 1 + math.floor((now - state.nextAtUnix) / SPIN_INTERVAL)
	local gained = math.min(due, MAX_FREE_STORED - state.free)
	state.free += gained
	state.spins += gained
	state.nextAtUnix = state.nextAtUnix + due * SPIN_INTERVAL

	-- Si le plafond a tronque le gain, on recale le timer sur maintenant
	-- plutot que de laisser une date deja passee.
	if state.nextAtUnix <= now then
		state.nextAtUnix = now + SPIN_INTERVAL
	end

	return gained > 0
end

local function onPlayerAdded(player: Player)
	local profile = PlayerProfileService.WaitForProfile(player)
	local saved = profile.spinWheel

	local state
	if type(saved) == "table" then
		local spins = math.max(0, tonumber(saved.spins) or 0)
		state = {
			-- aucun clamp : le total n'a pas de plafond
			spins = spins,
			-- profils d'avant la separation : on suppose que tout etait gratuit,
			-- borne au plafond
			free = math.clamp(tonumber(saved.free) or spins, 0, MAX_FREE_STORED),
			nextAtUnix = tonumber(saved.nextAtUnix) or (os.time() + SPIN_INTERVAL),
		}
	else
		state = { spins = STARTING_SPINS, free = STARTING_SPINS, nextAtUnix = os.time() + SPIN_INTERVAL }
	end

	states[player] = state
	accrue(state)
	pushAttributes(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- Rattrape les joueurs deja connectes quand ce module est require.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

PlayerProfileService.RegisterField("spinWheel", function(player: Player)
	local state = states[player]
	if not state then
		return nil
	end
	return { spins = state.spins, free = state.free, nextAtUnix = state.nextAtUnix }
end)

-- Boucle d'attribution. 5 s de granularite suffisent : le client fait son
-- propre decompte a la seconde a partir de WheelNextSpinAt, donc le serveur
-- n'a qu'a creer le spin quand l'echeance est passee.
task.spawn(function()
	while true do
		task.wait(5)
		for _, player in ipairs(Players:GetPlayers()) do
			local state = states[player]
			if state then
				if accrue(state) then
					pushAttributes(player)
				elseif state.free >= MAX_FREE_STORED then
					-- stock de gratuits plein : on garde l'affichage du timer coherent
					pushAttributes(player)
				end
			end
		end
	end
end)

--== API publique ==--

function SpinService.GetSpins(player: Player): number
	local state = states[player]
	return state and state.spins or 0
end

function SpinService.GetSecondsLeft(player: Player): number
	local state = states[player]
	if not state then
		return SPIN_INTERVAL
	end
	return math.max(0, state.nextAtUnix - os.time())
end

--[[
	Ajoute des spins au total. Ils ne comptent PAS comme des gratuits : le
	timer continue donc de tourner normalement par-dessus, et ces spins ne
	sont jamais rabotes par le plafond.

	`bypassCap` n'existe plus que pour compatibilite : le total n'ayant plus
	de plafond, l'argument est ignore.
]]
function SpinService.GrantSpins(player: Player, amount: number, _bypassCap: boolean?): boolean
	local state = states[player]
	if not state then
		return false
	end
	state.spins = math.max(0, state.spins + amount)
	state.free = math.min(state.free, state.spins)
	pushAttributes(player)
	return true
end

-- Retire un spin. Renvoie false si le joueur n'en a pas : c'est CE retour que
-- le futur handler de la roue doit tester avant de lancer quoi que ce soit,
-- le client ne devant jamais decider s'il a le droit de tourner.
function SpinService.TryConsumeSpin(player: Player): boolean
	local state = states[player]
	if not state or state.spins <= 0 then
		return false
	end

	local wasFull = state.free >= MAX_FREE_STORED
	state.spins -= 1
	-- on retire d'abord des gratuits : sinon un joueur qui a achete un pack
	-- garderait son stock de gratuits plein et son timer en pause a vie
	if state.free > 0 then
		state.free -= 1
	end

	-- Le timer etait en pause parce que le stock de GRATUITS etait plein : il
	-- repart maintenant que de la place s'est liberee.
	if wasFull then
		state.nextAtUnix = os.time() + SPIN_INTERVAL
	end

	pushAttributes(player)
	return true
end

SpinService.SPIN_INTERVAL = SPIN_INTERVAL
SpinService.MAX_FREE_STORED = MAX_FREE_STORED
SpinService.MAX_STORED = MAX_FREE_STORED   -- ancien nom, conserve pour compat

function SpinService.GetFreeSpins(player: Player): number
	local state = states[player]
	return state and state.free or 0
end

return SpinService
