--[[
	SpeedService
	------------
	ModuleScript a placer dans ServerScriptService.Training.

	Gere la Speed des joueurs (stat achetee au Speed Stand) :
	  - Cree un leaderstat "Speed" visible pour chaque joueur (defaut :
	    SpeedLevelShared.STARTING_SPEED)
	  - Sauvegarde/charge automatiquement avec un DataStore
	  - Synchronise en continu Humanoid.WalkSpeed sur la stat Speed (voir
	    SpeedLevelShared.GetWalkSpeed) a chaque spawn ET a chaque achat
	  - Fournit une API simple pour ajouter/fixer/lire la Speed

	Utilisation depuis un autre script :

		local SpeedService = require(game.ServerScriptService.Training.SpeedService)

		SpeedService.GetSpeed(player)          -> nombre
		SpeedService.AddSpeed(player, 5)       -> ajoute 5
		SpeedService.SetSpeed(player, 400)     -> fixe la valeur
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SpeedLevelShared = require(ReplicatedStorage.Training:WaitForChild("SpeedLevelShared"))
local PlayerProfileService = require(ServerScriptService.PlayerProfileService)

local SpeedService = {}

local STARTING_SPEED = SpeedLevelShared.STARTING_SPEED

-- Cache local : Player -> NumberValue (reference vers leaderstats.Speed).
-- Table a cles FAIBLES (voir PlayerProfileService) : jamais nettoyee a la
-- main a la deconnexion, pour que le getter enregistre plus bas reste
-- valide jusqu'a la toute derniere sauvegarde.
local speedValues = setmetatable({}, { __mode = "k" })

-- Applique la Speed actuelle du joueur au WalkSpeed de son personnage
-- actuel (si vivant). Appele au spawn ET a chaque changement de Speed.
local function applyWalkSpeed(player: Player, speedStatValue: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = SpeedLevelShared.GetWalkSpeed(speedStatValue)
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then
		return
	end
	local speed = speedValues[player]
	humanoid.WalkSpeed = SpeedLevelShared.GetWalkSpeed(speed and speed.Value or STARTING_SPEED)
end

local function onPlayerAdded(player: Player)
	local leaderstats = player:WaitForChild("leaderstats")

	local profile = PlayerProfileService.WaitForProfile(player)

	local speed = Instance.new("NumberValue")
	speed.Name = "Speed"
	speed.Value = profile.speed or STARTING_SPEED
	speed.Parent = leaderstats

	speedValues[player] = speed

	speed.Changed:Connect(function(newValue)
		applyWalkSpeed(player, newValue)
	end)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- Rattrape les joueurs deja connectes quand ce module est require (PlayerAdded
-- ne se rejoue pas pour eux).
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Rattrape les joueurs deja connectes si ce module est require en lazy.
for _, player in ipairs(Players:GetPlayers()) do
	if not speedValues[player] then
		task.spawn(onPlayerAdded, player)
	end
end

PlayerProfileService.RegisterField("speed", function(player: Player): number
	local speed = speedValues[player]
	return speed and speed.Value or STARTING_SPEED
end)

--== API publique ==--

function SpeedService.GetSpeed(player: Player): number
	local speed = speedValues[player]
	return speed and speed.Value or STARTING_SPEED
end

function SpeedService.AddSpeed(player: Player, amount: number): boolean
	local speed = speedValues[player]
	if not speed then
		warn("SpeedService: pas de valeur Speed pour " .. player.Name)
		return false
	end
	speed.Value += amount
	return true
end

function SpeedService.SetSpeed(player: Player, amount: number)
	local speed = speedValues[player]
	if not speed then
		warn("SpeedService: pas de valeur Speed pour " .. player.Name)
		return
	end
	speed.Value = amount
end

function SpeedService.Save(player: Player)
	PlayerProfileService.Save(player)
end

return SpeedService
