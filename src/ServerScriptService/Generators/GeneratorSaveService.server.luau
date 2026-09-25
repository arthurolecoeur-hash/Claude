--[[
	GeneratorSaveService
	---------------------
	Script (serveur) à placer dans ServerScriptService.

	Sauvegarde quels générateurs sont posés dans quels emplacements du
	plot d'un joueur (Ranch ou Base, voir PlotShared), et les recrée
	automatiquement à la connexion.
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PickupService = require(ServerScriptService.Generators.PickupService)
local PlotShared = require(ServerScriptService.PlotShared)
local PlayerProfileService = require(ServerScriptService.PlayerProfileService)
local WorkspaceIndex = require(ServerScriptService.WorkspaceIndex)

local WAIT_FOR_RANCH_TIMEOUT = 15

local function collectGeneratorTools(player: Player): { Tool }
	local tools = {}

	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				table.insert(tools, tool)
			end
		end
	end

	local character = player.Character
	local equipped = character and character:FindFirstChildOfClass("Tool")
	if equipped then
		table.insert(tools, equipped)
	end

	return tools
end

-- Index des modeles de generateurs (nom -> Part au sol servant de modele a
-- cloner), maintenu EN CONTINU via WorkspaceIndex au lieu d'etre reconstruit
-- a chaque connexion.
--
-- AVANT : chaque join declenchait un workspace:GetDescendants() complet
-- (45 000+ instances : BrainrotPack, Lucky Blocks, les bases...) rien que pour
-- retrouver les modeles a cloner. Avec plusieurs joueurs qui se connectent
-- coup sur coup, le serveur parcourait des centaines de milliers d'instances
-- en quelques secondes, avec des a-coups visibles en jeu.
--
-- MAINTENANT : l'index est rempli par le scan mutualise du boot puis mis a
-- jour au fil de l'eau, et un join ne coute plus qu'une lecture de table.
-- Le comportement est identique : c'est le CLONE du modele qui est reellement
-- pose (voir PickupService.doPlace), donc reutiliser la meme Part-modele pour
-- plusieurs restaurations est strictement equivalent a l'ancien code.
local templateIndex: { [string]: BasePart } = {}

WorkspaceIndex.ObserveParts(function(part)
	-- "not IsAlreadyPlaced" est essentiel : sans ce filtre, un generateur POSE
	-- dans un slot (clone porte lui aussi IncomePerSecond) viendrait s'indexer
	-- comme modele.
	return part:GetAttribute("IncomePerSecond") ~= nil and not PlotShared.IsAlreadyPlaced(part)
		-- Un Handle d'outil n'est pas un modele : il porte ses panneaux et
		-- peut etre detruit a tout moment.
		and not part:FindFirstAncestorOfClass("Tool")
end, function(part)
	if not templateIndex[part.Name] then
		templateIndex[part.Name] = part
	end
end)

--[[
	Un modele detruit ne doit plus etre clone : on rend la main a la
	prochaine Part du meme nom que WorkspaceIndex signalera.

	REPLI SUR SERVERSTORAGE (brainrots).

	Les 6 generateurs d'origine (Poulet, Loup...) sont des parts FIXES,
	toujours presentes au sol : les retrouver via l'index suffit.

	Un brainrot, lui, est un exemplaire ephemere pose par BrainrotSpawner
	et detruit des qu'un joueur le ramasse. Au moment ou un joueur se
	reconnecte, il peut tres bien n'y en avoir aucun au sol - l'index serait
	alors vide et le brainrot pose dans son plot (ou range dans son sac)
	serait perdu.

	D'ou le repli sur les templates permanents de ServerStorage, construits
	au demarrage par BrainrotGeneratorFactory.
]]
local BrainrotFactory = require(ServerScriptService.Brainrots.BrainrotGeneratorFactory)

local function getTemplate(name: string): BasePart?
	local template = templateIndex[name]
	if template and not template.Parent then
		templateIndex[name] = nil
		template = nil
	end
	return template or BrainrotFactory.GetTemplate(name)
end

--[[
	REVENU PERSONNALISE (brainrots de la boutique : Lucky Block, 1x1x1x1).

	Leur revenu depend du joueur (% de son meilleur brainrot), il ne vient
	donc pas du template. Il est marque par l'attribut "CustomIncome" et
	sauvegarde dans l'entree (`income`). A la restauration, on part d'une
	copie du template portant ce revenu : c'est elle qui est clonee pour le
	Tool ou le generateur pose, panneaux d'info compris.

	Renvoie (template, temporaire?) : la copie temporaire est a detruire
	apres usage.
]]
local function getTemplateFor(entry): (BasePart?, boolean)
	local template = getTemplate(entry.name)
	if template and type(entry.income) == "number" then
		local copy = template:Clone()
		copy:SetAttribute("IncomePerSecond", entry.income)
		copy:SetAttribute("CustomIncome", true)
		return copy, true
	end
	return template, false
end

local function customIncomeOf(part: Instance): number?
	if part:GetAttribute("CustomIncome") then
		return part:GetAttribute("IncomePerSecond")
	end
	return nil
end

--[[
	INVENTAIRE CONSERVE A LA MORT.

	Roblox vide le Backpack a chaque respawn (et l'outil tenu disparait
	avec le personnage) : les brainrots du sac etaient perdus a la mort.

	A la mort, on photographie le contenu (nom + niveau) ; au respawn, on
	le recree dans le nouveau Backpack. Entre les deux, c'est cette photo
	qui fait foi pour la sauvegarde - un joueur qui quitte pendant qu'il
	est mort ne perd donc rien non plus.

	Le meme mecanisme sert a la restauration au join : l'inventaire
	sauvegarde est mis "en attente" et donne des que le personnage est la.
]]
local pendingInventory = setmetatable({}, { __mode = "k" }) -- Player -> { {name, level} }

local function snapshotInventory(player: Player): { any }
	local data = {}
	for _, tool in ipairs(collectGeneratorTools(player)) do
		local handle = tool:FindFirstChild("Handle")
		if handle and handle:GetAttribute("IncomePerSecond") then
			table.insert(data, {
				name = tool.Name,
				level = handle:GetAttribute("Level") or 1,
				-- Case de hotbar et favori (InventoryService) : conserves a
				-- la mort et a la reconnexion.
				slot = tool:GetAttribute("HotbarSlot"),
				fav = tool:GetAttribute("Favorite") == true or nil,
				income = customIncomeOf(handle),
			})
		end
	end
	return data
end

local function isAlive(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and character.Parent ~= nil
end

-- Donne l'inventaire en attente si le personnage est vivant ; sinon on le
-- garde pour le prochain CharacterAdded.
local function flushPendingInventory(player: Player)
	local list = pendingInventory[player]
	if not list or not isAlive(player) then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	pendingInventory[player] = nil

	for _, entry in ipairs(list) do
		local template, temporary = getTemplateFor(entry)
		if template then
			local tool = PickupService.CreateGeneratorTool(template, entry.level)
			if temporary then
				template:Destroy()
			end
			-- Avant le parentage : InventoryService lit HotbarSlot a l'arrivee.
			if type(entry.slot) == "number" then
				tool:SetAttribute("HotbarSlot", entry.slot)
			end
			if entry.fav then
				tool:SetAttribute("Favorite", true)
			end
			tool.Parent = backpack
		else
			warn(("GeneratorSaveService: impossible de restaurer %s dans l'inventaire de %s"):format(
				tostring(entry.name), player.Name
				))
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	humanoid.Died:Connect(function()
		-- On fusionne avec ce qui serait deja en attente (mort avant la
		-- restauration du join) pour ne rien perdre.
		local list = pendingInventory[player] or {}
		for _, entry in ipairs(snapshotInventory(player)) do
			table.insert(list, entry)
		end
		pendingInventory[player] = list
	end)

	-- Le Backpack est repeuple par Roblox juste apres l'apparition : on
	-- attend que ce soit fait pour ne pas se faire vider.
	if not character.Parent then
		character.AncestryChanged:Wait()
	end
	task.wait(0.1)
	if player.Character == character then
		flushPendingInventory(player)
	end
end

local function watchCharacters(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function waitForPlot(player: Player): Model?
	local elapsed = 0
	local plot = PlotShared.GetPlayerPlot(player)
	while not plot and elapsed < WAIT_FOR_RANCH_TIMEOUT do
		task.wait(0.5)
		elapsed += 0.5
		plot = PlotShared.GetPlayerPlot(player)
	end
	return plot
end

local function onPlayerAdded(player: Player)
	watchCharacters(player)

	local plot = waitForPlot(player)
	if not plot then
		warn("GeneratorSaveService: aucun plot assigné pour " .. player.Name .. " (timeout)")
		return
	end

	local waitedForLevel = 0
	while not plot:GetAttribute("LevelRestored") and waitedForLevel < WAIT_FOR_RANCH_TIMEOUT do
		task.wait(0.1)
		waitedForLevel += 0.1
	end

	local profile = PlayerProfileService.WaitForProfile(player)
	-- Parti pendant le chargement : sa base est deja liberee (et peut-etre
	-- reattribuee), il ne faut rien y poser.
	if not player.Parent or PlotShared.GetPlayerPlot(player) ~= plot then
		return
	end
	local savedData = profile.generators or {}

	-- L'index des modeles est alimente par le scan initial de WorkspaceIndex :
	-- on s'assure qu'il est bien termine avant de lire dedans (cas d'un joueur
	-- connecte des les toutes premieres frames du serveur).
	WorkspaceIndex.WaitForInitialScan()

	for _, entry in ipairs(savedData) do
		local slot = PlotShared.GetSlotById(plot, entry.slot)
		local template, temporary = getTemplateFor(entry)

		if slot and template then
			PickupService.PlaceGeneratorInSlot(template, slot, entry.name, player, entry.level)
			if temporary then
				template:Destroy()
			end
		else
			warn(("GeneratorSaveService: impossible de restaurer %s dans %s pour %s"):format(
				tostring(entry.name), tostring(entry.slot), player.Name
				))
		end
	end

	-- Restauration du sac : en attente jusqu'a ce que le personnage soit
	-- vivant (donne tout de suite s'il l'est deja). On ajoute a ce qui
	-- serait deja en attente plutot que de l'ecraser.
	local savedInventory = profile.inventory or {}
	if #savedInventory > 0 then
		local list = pendingInventory[player] or {}
		for _, entry in ipairs(savedInventory) do
			table.insert(list, entry)
		end
		pendingInventory[player] = list
		flushPendingInventory(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
-- Rattrape les joueurs deja connectes au demarrage de ce script (PlayerAdded
-- ne se rejoue pas pour eux).
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

PlayerProfileService.RegisterField("generators", function(player: Player): { any }?
	local plot = PlotShared.GetPlayerPlot(player)
	if not plot then
		return nil
	end

	local data = {}
	for _, slot in ipairs(PlotShared.GetSlots(plot)) do
		if slot:GetAttribute("Occupied") then
			for _, child in ipairs(slot:GetChildren()) do
				if child:IsA("BasePart") and child:GetAttribute("IncomePerSecond") then
					table.insert(data, {
						slot = PlotShared.GetSlotId(slot),
						name = child.Name,
						level = child:GetAttribute("Level") or 1,
						income = customIncomeOf(child),
					})
					break
				end
			end
		end
	end
	return data
end)

PlayerProfileService.RegisterField("inventory", function(player: Player): { any }
	-- Inventaire en attente (joueur mort, ou pas encore restaure au join) :
	-- c'est lui la verite, le sac actuel est vide ou perime.
	local data = snapshotInventory(player)
	local pending = pendingInventory[player]
	if pending then
		if isAlive(player) then
			-- Join pas encore restaure : sac + attente.
			for _, entry in ipairs(pending) do
				table.insert(data, entry)
			end
		else
			return pending
		end
	end
	return data
end)
