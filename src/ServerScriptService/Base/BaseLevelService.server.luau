--[[
	BaseLevelService
	-----------------
	Script (serveur) à placer dans ServerScriptService.Base.
	Équivalent de RanchLevelService : sauvegarde/charge le niveau de Base
	de chaque joueur (DataStore séparé de celui du Ranch), et réapplique le
	déblocage des générateurs correspondant à sa connexion.

	IMPORTANT : doit se lancer APRÈS AssignationBaseScript. Attend/réessaie
	automatiquement si la Base n'est pas encore assignée.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local BaseShared = require(ServerScriptService.Base.BaseShared)
local BaseSlots = require(ServerScriptService.Base.BaseSlots)
local PlayerProfileService = require(ServerScriptService.PlayerProfileService)

local WAIT_FOR_BASE_TIMEOUT = 10

-- Table a cles FAIBLES (voir PlayerProfileService) : jamais nettoyee a la
-- main a la deconnexion, pour que le getter enregistre plus bas reste
-- valide jusqu'a la toute derniere sauvegarde.
local playerBases = setmetatable({}, { __mode = "k" })

local function waitForBase(player: Player): Model?
	local elapsed = 0
	local base = BaseShared.GetBaseForPlayer(player)

	while not base and elapsed < WAIT_FOR_BASE_TIMEOUT do
		task.wait(0.5)
		elapsed += 0.5
		base = BaseShared.GetBaseForPlayer(player)
	end

	return base
end

local function onPlayerAdded(player: Player)
	local base = waitForBase(player)
	if not base then
		warn("BaseLevelService: aucune base assignée pour " .. player.Name .. " (timeout)")
		return
	end

	playerBases[player] = base

	local profile = PlayerProfileService.WaitForProfile(player)
	if not player.Parent then
		return -- parti pendant le chargement : base deja liberee
	end
	local savedLevel = profile.baseLevel or 1

	local levelValue = base:FindFirstChild("Level")
	if not levelValue then
		levelValue = Instance.new("IntValue")
		levelValue.Name = "Level"
		levelValue.Parent = base
	end
	levelValue.Value = savedLevel

	BaseShared.UpdateSignUI(base, savedLevel)
	BaseSlots.ApplyUnlockState(base, savedLevel, false)

	base:SetAttribute("LevelRestored", true)
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- Rattrape les joueurs deja connectes au demarrage de ce script (PlayerAdded
-- ne se rejoue pas pour eux).
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

PlayerProfileService.RegisterField("baseLevel", function(player: Player): number
	local base = playerBases[player]
	local levelValue = base and base:FindFirstChild("Level")
	return levelValue and levelValue.Value or 1
end)
