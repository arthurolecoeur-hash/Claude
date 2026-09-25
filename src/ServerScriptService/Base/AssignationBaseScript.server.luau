-- Script (Server) in ServerScriptService.Base
-- Équivalent de AssignationRanchScript, pour les Bases.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerProfileService = require(ServerScriptService.PlayerProfileService)
local PickupService = require(ServerScriptService.Generators.PickupService)
local PlotShared = require(ServerScriptService.PlotShared)
local BaseShared = require(ServerScriptService.Base.BaseShared)
local BaseSlots = require(ServerScriptService.Base.BaseSlots)

local build = workspace:WaitForChild("Build")
local basesFolder = build:WaitForChild("Bases")

local function findOwnerValue(baseFolderInst)
	local nameSign = baseFolderInst:FindFirstChild("NameSign", true)
	return nameSign and nameSign:FindFirstChild("Owner", true)
end

local function findOwnerIdValue(baseFolderInst)
	local nameSign = baseFolderInst:FindFirstChild("NameSign", true)
	return nameSign and nameSign:FindFirstChild("OwnerId", true)
end

local function assignBase(player)
	local freeBases = {}

	for _, baseFolderInst in ipairs(basesFolder:GetChildren()) do
		local owner = findOwnerValue(baseFolderInst)
		if owner and (owner.Value == "" or owner.Value == "None") then
			table.insert(freeBases, baseFolderInst)
		end
	end

	if #freeBases == 0 then
		warn("No free base available for " .. player.Name)
		return
	end

	local chosenBaseFolder = freeBases[math.random(1, #freeBases)]
	local owner = findOwnerValue(chosenBaseFolder)
	owner.Value = player.Name

	local ownerId = findOwnerIdValue(chosenBaseFolder)
	if ownerId then
		ownerId.Value = player.UserId
	end

	local spawnPart = chosenBaseFolder:FindFirstChild("Spawn", true)
	if spawnPart then
		player.RespawnLocation = spawnPart
	end

	print(player.Name .. " received " .. chosenBaseFolder.Name)
end

-- Remet la Base a neuf AVANT de la liberer : sans ca, le joueur suivant
-- heritait des generateurs, de l'argent non collecte et du niveau de
-- l'ancien proprietaire (et les sauvegardait chez lui = duplication).
local function resetBase(baseFolderInst)
	local base = baseFolderInst:FindFirstChild("Base")
	if not base then
		return
	end
	for _, slot in ipairs(PlotShared.GetSlots(base)) do
		PickupService.ClearSlot(slot)
	end
	base:SetAttribute("LevelRestored", nil)
	local levelValue = base:FindFirstChild("Level")
	if levelValue then
		levelValue.Value = 1
	end
	BaseShared.UpdateSignUI(base, 1)
	BaseSlots.ApplyUnlockState(base, 1, false)
end

-- Libère la Base d'un joueur quand il quitte, pour qu'elle redevienne
-- disponible pour un futur joueur. Appele par PlayerProfileService une fois
-- la base lue pour la sauvegarde finale (jamais avant).
local function freeBase(player)
	for _, baseFolderInst in ipairs(basesFolder:GetChildren()) do
		local owner = findOwnerValue(baseFolderInst)
		if owner and owner.Value == player.Name then
			local ok, err = pcall(resetBase, baseFolderInst)
			if not ok then
				warn("AssignationBaseScript: echec remise a zero de " .. baseFolderInst.Name .. " - " .. tostring(err))
			end
			owner.Value = ""
			local ownerId = findOwnerIdValue(baseFolderInst)
			if ownerId then
				ownerId.Value = 0
			end
			break
		end
	end
end

Players.PlayerAdded:Connect(assignBase)
-- Rattrape les joueurs deja connectes au demarrage de ce script (PlayerAdded
-- ne se rejoue pas pour eux) : sans ca, un joueur entre avant le chargement
-- du script n'aurait jamais de base assignee.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(assignBase, player)
end
PlayerProfileService.OnPlayerReleased(freeBase)
