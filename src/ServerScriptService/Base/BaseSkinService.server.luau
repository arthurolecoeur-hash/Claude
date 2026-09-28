--[[
	BaseSkinService
	---------------
	Script serveur (ServerScriptService.Base).

	Skins de base debloques par l'Index (voir ReplicatedStorage.BaseSkinShared) :
	avoir 50% des brainrots d'une mutation debloque la base de cette mutation.
	Le joueur l'equipe au stand "Bases" (Workspace.BaseStand).

	- Le skin equipe est sauvegarde dans le profil (champ "baseSkin").
	- Applique sur les Parts de structure de la base (sol, piliers, echelles,
	  emplacements) : couleur + matiere. Les brainrots poses, les plaques
	  neon d'argent et les panneaux ne sont pas touches.
	- Couleur/matiere d'origine gardees en attribut : Normal les restaure,
	  et la base est remise a zero quand le joueur part (elle est reattribuee).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local BaseShared = require(ServerScriptService.Base.BaseShared)
local PlayerProfileService = require(ServerScriptService.PlayerProfileService)
local PurchaseRouter = require(ServerScriptService.Purchases.PurchaseRouter)
local IndexState = require(ServerScriptService.Index.IndexState)
local BaseSkinShared = require(ReplicatedStorage:WaitForChild("BaseSkinShared"))

local WAIT_TIMEOUT = 20

-- Rendu des skins : BaseSkinShared.STYLES / BaseSkinShared.Paint.
local EXCLUDED_MODELS = { NameSign = true, UpgradeSign = true }

-- Parts de structure de la base (a recolorer).
local function isStructural(part: BasePart, base: Model): boolean
	if part:IsA("SpawnLocation") or part.Name == "MoneyIncomePlace" or part.Name == "FixedGenerator" then
		return false
	end
	local origMat = part:GetAttribute("SkinOrigMaterial")
	if (origMat or part.Material.Name) == "Neon" then
		return false
	end
	-- Brainrot pose (clone avec IncomePerSecond) ou tout ce qui est dedans.
	local node: Instance? = part
	while node and node ~= base do
		if node:GetAttribute("IncomePerSecond") ~= nil or EXCLUDED_MODELS[node.Name] or node:IsA("Tool") then
			return false
		end
		node = node.Parent
	end
	return node == base
end

local function applySkin(base: Model, key: string)
	if base:GetAttribute("BaseSkin") == key then
		return
	end
	for _, part in ipairs(base:GetDescendants()) do
		if part:IsA("BasePart") and isStructural(part, base) then
			-- Memorise l'origine la premiere fois.
			if part:GetAttribute("SkinOrigColor") == nil then
				part:SetAttribute("SkinOrigColor", part.Color)
				part:SetAttribute("SkinOrigMaterial", part.Material.Name)
			end
			local origColor: Color3 = part:GetAttribute("SkinOrigColor")
			local origMat = Enum.Material[part:GetAttribute("SkinOrigMaterial")] or Enum.Material.Plastic

			BaseSkinShared.Paint(part, key, origColor, origMat)
		end
	end
	base:SetAttribute("BaseSkin", key)
end

--== Etat joueur ==--
-- Cles faibles : voir PlayerProfileService.
local equipped = setmetatable({}, { __mode = "k" }) -- Player -> cle de skin
local playerBases = setmetatable({}, { __mode = "k" }) -- Player -> Model
local lastEquip = setmetatable({}, { __mode = "k" })
local savedSkin = setmetatable({}, { __mode = "k" }) -- Player -> skin lu dans le profil (repli pour la sauvegarde)
local bought = setmetatable({}, { __mode = "k" }) -- Player -> { [cle] = true } achetes en Robux

local function getBought(player: Player)
	if not bought[player] then
		local set = {}
		if PlayerProfileService.IsLoaded(player) then
			local profile = PlayerProfileService.WaitForProfile(player)
			if type(profile.baseSkinsBought) == "table" then
				for _, k in ipairs(profile.baseSkinsBought) do
					if type(k) == "string" then
						set[k] = true
					end
				end
			end
		end
		bought[player] = set
	end
	return bought[player]
end

local function isUnlocked(player: Player, key: string): boolean
	if key == "Normal" or getBought(player)[key] then
		return true
	end
	if not BaseSkinShared.Get(key) then
		return false
	end
	local n, total = IndexState.CountForMutation(player, key)
	return n >= BaseSkinShared.GetRequired(total)
end

local function buildState(player: Player)
	local skins = {}
	for _, s in ipairs(BaseSkinShared.SKINS) do
		local n, total = IndexState.CountForMutation(player, s.key)
		skins[s.key] = {
			count = n,
			total = total,
			required = BaseSkinShared.GetRequired(total),
			unlocked = isUnlocked(player, s.key),
			bought = getBought(player)[s.key] == true,
		}
	end
	return { equipped = equipped[player] or "Normal", skins = skins }
end

--== Remotes ==--
local remotes = Instance.new("Folder")
remotes.Name = "BaseSkinRemotes"
local getState = Instance.new("RemoteFunction")
getState.Name = "GetBaseSkins"
getState.Parent = remotes
local equipEvent = Instance.new("RemoteEvent")
equipEvent.Name = "EquipBaseSkin"
equipEvent.Parent = remotes
local changedEvent = Instance.new("RemoteEvent")
changedEvent.Name = "BaseSkinsChanged"
changedEvent.Parent = remotes
local studioBuyEvent = Instance.new("RemoteEvent")
studioBuyEvent.Name = "StudioBuyBaseSkin"
studioBuyEvent.Parent = remotes

local function push(player: Player)
	if player.Parent then
		changedEvent:FireClient(player, buildState(player))
	end
end

local function applyForPlayer(player: Player)
	-- Lu par IncomeShared (multiplicateur de cash) et l'UI client.
	player:SetAttribute("BaseSkin", equipped[player] or "Normal")
	local base = playerBases[player]
	if base and base.Parent then
		applySkin(base, equipped[player] or "Normal")
	end
end

getState.OnServerInvoke = function(player: Player)
	return buildState(player)
end

equipEvent.OnServerEvent:Connect(function(player: Player, key)
	if type(key) ~= "string" then
		return
	end
	local now = os.clock()
	if lastEquip[player] and now - lastEquip[player] < 0.4 then
		return
	end
	lastEquip[player] = now
	if not isUnlocked(player, key) then
		push(player)
		return
	end
	equipped[player] = key
	applyForPlayer(player)
	push(player)
end)

--== Achat Robux ==--
local function grantSkin(player: Player, key: string): boolean
	if not BaseSkinShared.Get(key) or key == "Normal" then
		return false
	end
	getBought(player)[key] = true
	equipped[player] = key
	applyForPlayer(player)
	push(player)
	return true
end

for _, s in ipairs(BaseSkinShared.SKINS) do
	if s.productId and s.productId ~= 0 then
		PurchaseRouter.Register(s.productId, function(player)
			return grantSkin(player, s.key)
		end)
	end
end

-- Studio uniquement : produit pas encore cree -> accorde gratuitement pour tester.
studioBuyEvent.OnServerEvent:Connect(function(player: Player, key)
	if not RunService:IsStudio() or type(key) ~= "string" then
		return
	end
	local s = BaseSkinShared.Get(key)
	if s and (s.productId or 0) == 0 then
		grantSkin(player, key)
	end
end)

-- Un brainrot de plus dans l'Index peut debloquer un skin.
IndexState.Changed:Connect(function(player: Player)
	push(player)
end)

--== Connexion / deconnexion ==--
local function onPlayerAdded(player: Player)
	local profile = PlayerProfileService.WaitForProfile(player)
	local saved = type(profile.baseSkin) == "string" and profile.baseSkin or "Normal"
	savedSkin[player] = saved
	local set = bought[player] or {}
	if type(profile.baseSkinsBought) == "table" then
		for _, k in ipairs(profile.baseSkinsBought) do
			if type(k) == "string" then
				set[k] = true
			end
		end
	end
	bought[player] = set

	-- La base et l'Index doivent etre prets avant de valider le skin.
	local elapsed = 0
	local base = BaseShared.GetBaseForPlayer(player)
	while (not base or not IndexState.IsReady(player)) and elapsed < WAIT_TIMEOUT and player.Parent do
		task.wait(0.5)
		elapsed += 0.5
		base = base or BaseShared.GetBaseForPlayer(player)
	end
	if not player.Parent then
		return
	end

	if equipped[player] == nil then
		equipped[player] = isUnlocked(player, saved) and saved or "Normal"
	end
	if base then
		playerBases[player] = base
		applyForPlayer(player)
	else
		warn("BaseSkinService: aucune base assignee pour " .. player.Name .. " (timeout)")
	end
	push(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- La base est reattribuee au prochain joueur : on la remet d'origine.
Players.PlayerRemoving:Connect(function(player: Player)
	local base = playerBases[player]
	if base and base.Parent then
		applySkin(base, "Normal")
	end
end)

PlayerProfileService.RegisterField("baseSkin", function(player: Player)
	return equipped[player] or savedSkin[player] or "Normal"
end)

PlayerProfileService.RegisterField("baseSkinsBought", function(player: Player)
	local list = {}
	for k in pairs(getBought(player)) do
		table.insert(list, k)
	end
	return list
end)

remotes.Parent = ReplicatedStorage
