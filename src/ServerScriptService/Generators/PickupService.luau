--[[
	PickupService
	-------------
	Script (serveur) à placer dans ServerScriptService.

	Fonctionnement :
	  1. Toute Part ayant l'Attribute "IncomePerSecond", tant qu'elle n'est
	     PAS déjà posée dans un plot (Ranch ou Base, voir PlotShared), peut
	     être ramassée en MARCHANT dessus (Touched). GRATUIT pour l'instant.
	     Elle disparaît du sol, tu la reçois dans ton Backpack sous forme
	     d'Outil (Tool), et elle réapparaît au sol après quelques secondes.
	  2. En la portant (équipée), un aperçu (nom / rareté / revenu / total
	     $/s) s'affiche au-dessus de ta tête.
	  3. Marche vers un emplacement VIDE de TON plot : un prompt "E Placer
	     l'objet" apparaît -> ça pose le générateur là, précisément.
	  4. Marche vers un emplacement déjà OCCUPÉ : un prompt "E Prendre /
	     Échanger" apparaît sur le générateur posé.
	       - Si tu ne portes rien : il repart dans ton Backpack.
	       - Si tu portes un générateur : ÉCHANGE direct (le nouveau se
	         pose, l'ancien repart dans ton Backpack).

	Attribute attendu sur chaque Part au sol :
	  IncomePerSecond  (Number) -- revenu une fois posée
	  (ShopPrice est optionnel : si présent, débité au ramassage ; sinon gratuit)
]]

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local CollectionService = game:GetService("CollectionService")

local MoneyService = require(ServerScriptService.Money.MoneyService)
local PlotShared = require(ServerScriptService.PlotShared)
local WorkspaceIndex = require(ServerScriptService.WorkspaceIndex)
local GeneratorRarity = require(ServerScriptService.Generators.GeneratorRarity)
local MutationLabel = require(ServerScriptService.Brainrots.MutationLabel)
local RebirthService = require(ServerScriptService.Rebirth.RebirthService)
local GeneratorLevelShared = require(ServerScriptService.Generators.GeneratorLevelShared)
local InventoryShared = require(game:GetService("ReplicatedStorage").Inventory.InventoryShared)

local STATS_FONT = Enum.Font.LuckiestGuy

local STROKE_DARKEN_FACTOR = 0.42
local function darkenColor(color: Color3): Color3
	return Color3.new(color.R * STROKE_DARKEN_FACTOR, color.G * STROKE_DARKEN_FACTOR, color.B * STROKE_DARKEN_FACTOR)
end

local BOARD_WIDTH_STUDS = 4.6
local BOARD_HEIGHT_STUDS = 2.5

local function computeUniformTextSize(texts: { string }, font: Enum.Font, lineCount: number): number
	local PIXELS_PER_STUD = 60
	local widthPx = BOARD_WIDTH_STUDS * PIXELS_PER_STUD
	local heightPx = (BOARD_HEIGHT_STUDS / lineCount) * PIXELS_PER_STUD
	local REF_SIZE = 200
	local bestSize = REF_SIZE
	for _, text in ipairs(texts) do
		local bounds = TextService:GetTextSize(text, REF_SIZE, font, Vector2.new(10000, 10000))
		local scale = math.min(widthPx / bounds.X, heightPx / bounds.Y)
		bestSize = math.min(bestSize, REF_SIZE * scale)
	end
	return bestSize
end

-- Son + flash rouge quand le joueur encaisse l'argent d'une dalle de collecte
-- (demande utilisateur, id fourni).
local COLLECT_SOUND_ID = "rbxassetid://134810204798705"
local COLLECT_FLASH_COLOR = Color3.fromRGB(255, 35, 35)
local COLLECT_FLASH_DURATION = 1

-- Un seul Sound par dalle, cree a la premiere collecte puis REUTILISE.
-- L'ancienne version faisait Instance.new("Sound") + Debris a CHAQUE
-- encaissement : creation d'instance, replication vers tous les clients, puis
-- destruction, en boucle (les joueurs encaissent tres souvent). Reutiliser la
-- meme instance donne exactement le meme son sans ce va-et-vient.
local function playCollectSound(pad: BasePart)
	local sound = pad:FindFirstChild("CollectSound")
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "CollectSound"
		sound.SoundId = COLLECT_SOUND_ID
		sound.Volume = 1
		sound.Parent = pad
	end
	sound.TimePosition = 0
	sound:Play()
end

-- Couleur d'origine des dalles, gardee cote serveur dans une table a cles
-- FAIBLES. L'ancienne version la stockait dans QUATRE Attributes par dalle
-- (_originalColorR/G/B/Set) : des attributs repliques a tous les clients alors
-- qu'ils ne servent qu'au serveur, sur chaque dalle du jeu.
local padOriginalColor = setmetatable({}, { __mode = "k" })
local padFlashToken = setmetatable({}, { __mode = "k" })

-- Passe la dalle en rouge pendant 1s puis revient a sa couleur d'origine.
-- Un "jeton" (compteur) evite qu'un encaissement rapide juste apres ne se
-- fasse ecraser par le retour a la couleur normale d'un encaissement
-- precedent encore en attente (task.delay).
local function flashCollectPad(pad: BasePart)
	local original = padOriginalColor[pad]
	if not original then
		original = pad.Color
		padOriginalColor[pad] = original
	end

	local token = (padFlashToken[pad] or 0) + 1
	padFlashToken[pad] = token
	pad.Color = COLLECT_FLASH_COLOR

	task.delay(COLLECT_FLASH_DURATION, function()
		if pad.Parent and padFlashToken[pad] == token then
			pad.Color = original
		end
	end)
end

local RESPAWN_TIME = 5
local PLACE_ACTION_TEXT = "Place item"
-- Texte raccourci ("Prendre" au lieu de "Prendre / Echanger") pour que les
-- deux prompts (Prendre + Vendre) tiennent cote a cote sans se chevaucher.
-- La fonctionnalite d'echange (poser un objet different sur un slot deja
-- occupe) reste inchangee, seul le libelle affiche est raccourci.
local TAKE_ACTION_TEXT = "Take"
-- Demande utilisateur : reprendre un générateur déjà posé doit nécessiter de
-- MAINTENIR la touche (pas un simple appui) - uniquement pour cette action,
-- le prompt de pose (sur un slot vide) reste instantané.
local TAKE_HOLD_DURATION = 0.6

-- Prompt "Vendre", juste a cote du prompt "Prendre / Echanger" sur un
-- generateur pose : meme UI native (ProximityPrompt) que celle qui
-- fonctionne deja de facon fiable pour Prendre/Echanger/Placer, plutot
-- qu'un menu custom (BillboardGui/SurfaceGui, abandonne : peu fiable au
-- clic et complique a bien positionner).
local SELL_ACTION_TEXT = "Sell"
-- Valeur de vente = revenu de BASE du generateur (1 pour 1 : un poulet a
-- 10/s se vend 10$ au niveau 1), avec le meme multiplicateur de niveau que
-- le revenu (GeneratorLevelShared) - un generateur monte de niveau se
-- revend donc plus cher, proportionnellement.
local function getSellValue(generator: BasePart): number
	local baseIncome = generator:GetAttribute("IncomePerSecond") or 0
	local level = generator:GetAttribute("Level") or 1
	return math.floor(baseIncome * GeneratorLevelShared.GetMultiplier(level))
end

--[[
	Orientation du generateur pose : il regarde DE FACE vers l'allee de la
	base, c'est-a-dire vers le MoneyPlace de son Generator (le pad de
	collecte est toujours devant, cote allee). Les brainrots du pack
	regardent vers -Z (LookVector), donc CFrame.lookAt suffit ; ceux de
	InventoryShared.FLIPPED sont retournes. Sans MoneyPlace (ranch), on
	garde l'orientation du slot.
]]
local function getFacing(slot: BasePart, template: BasePart): CFrame
	local generatorModel = slot:FindFirstAncestorWhichIsA("Model")
	while generatorModel and not generatorModel.Name:match("^Generator%d+$") do
		generatorModel = generatorModel:FindFirstAncestorWhichIsA("Model")
	end
	local moneyPlace = generatorModel and generatorModel:FindFirstChild("MoneyPlace")

	local dir
	if moneyPlace and moneyPlace:IsA("Model") then
		dir = moneyPlace:GetPivot().Position - slot.Position
	else
		dir = slot.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.01 then
		return CFrame.identity
	end

	local facing = CFrame.lookAt(Vector3.zero, dir.Unit)
	-- Le template est souvent le Handle d'un Tool : le vrai nom est dans
	-- DisplayName.
	if InventoryShared.FLIPPED[template:GetAttribute("DisplayName") or template.Name] then
		facing *= CFrame.Angles(0, math.pi, 0)
	end
	return facing
end

local function computeGeneratorCFrame(slot: BasePart, template: BasePart): CFrame
	local slotTopY = slot.Position.Y + slot.Size.Y / 2
	local halfHeight = template.Size.Y / 2
	return CFrame.new(slot.Position.X, slotTopY + halfHeight, slot.Position.Z) * getFacing(slot, template)
end

local function isAlreadyPlaced(part: BasePart): boolean
	return PlotShared.IsAlreadyPlaced(part)
end

local function findGeneratorInSlot(slot: Instance): BasePart?
	for _, child in ipairs(slot:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("IncomePerSecond") and not child:GetAttribute("_retrieving") then
			return child
		end
	end
	return nil
end

-- Un prompt Prendre/Vendre n'est valide que sur un generateur vraiment
-- pose dans un slot, et pas deja en cours de reprise.
local function getPlacedGenerator(prompt: ProximityPrompt): (BasePart?, BasePart?)
	local generator = prompt.Parent
	if not (generator and generator:IsA("BasePart")) or generator:GetAttribute("_retrieving") then
		return nil, nil
	end
	local slot = generator.Parent
	if not (slot and slot:IsA("BasePart")) or not isAlreadyPlaced(generator) then
		return nil, nil
	end
	return generator, slot
end

local function setSlotPlacePromptEnabled(slot: Instance, enabled: boolean)
	local prompt = slot:FindFirstChild("PlacePrompt")
	if prompt then
		prompt.Enabled = enabled
	end
end

local createGeneratorTool
local doPlace
local doRetrieve
local placeCarriedToolInSlot

local function buildStatsBillboard(parent: Instance, name: string, sourcePart: BasePart, player: Player?, studsOffsetY: number): BillboardGui
	local income = sourcePart:GetAttribute("IncomePerSecond") or 0
	local rarityTier = GeneratorRarity.GetTier(sourcePart)
	local mutationKey, displayName = MutationLabel.Get(sourcePart)
	local level = sourcePart:GetAttribute("Level") or 1
	local levelText = "Level " .. level

	local incomeText = PlotShared.FormatPrice(income) .. "/s"
	if player then
		local multiplier = require(ServerScriptService.Generators.IncomeShared).GetCashMultiplier(player)
		incomeText = incomeText .. (" (x%.2f)"):format(multiplier)
	end

	local lineCount = mutationKey and 5 or 4
	local uniformTextSize = computeUniformTextSize({ levelText, displayName, rarityTier.DisplayName, incomeText }, STATS_FONT, lineCount)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = name
	billboard.Size = UDim2.new(BOARD_WIDTH_STUDS, 0, BOARD_HEIGHT_STUDS * lineCount / 4, 0)
	billboard.StudsOffset = Vector3.new(0, studsOffsetY, 0)
	-- Ligne en plus : le panneau grandit vers le haut, le bas ne bouge pas.
	billboard.SizeOffset = Vector2.new(0, (lineCount - 4) / (2 * lineCount))
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 45
	billboard.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = billboard

	local function addLabel(labelName: string, order: number, text: string, color: Color3, weight: number)
		local label = Instance.new("TextLabel")
		label.Name = labelName
		label.LayoutOrder = order
		label.Size = UDim2.new(1, 0, weight / lineCount, 0)
		label.BackgroundTransparency = 1
		label.Font = STATS_FONT
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = true
		label.Parent = billboard

		local stroke = Instance.new("UIStroke")
		stroke.Color = darkenColor(color)
		stroke.Thickness = 3
		stroke.Parent = label

		return label
	end

	if mutationKey then
		local mutationLabel = addLabel("MutationLabel", 0, mutationKey, Color3.new(1, 1, 1), 1)
		MutationLabel.Style(mutationLabel, mutationKey)
	end

	local levelLabel = addLabel("LevelLabel", 1, levelText, Color3.fromRGB(255, 225, 120), 1)
	local levelGradient = Instance.new("UIGradient")
	levelGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 250, 190)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 205, 40)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(225, 145, 5)),
	})
	levelGradient.Rotation = 90
	levelGradient.Parent = levelLabel

	addLabel("NameLabel", 2, displayName, Color3.new(1, 1, 1), 1)
	addLabel("RarityLabel", 3, rarityTier.DisplayName, rarityTier.Color, 1)
	addLabel("IncomeLabel", 4, incomeText, Color3.fromRGB(70, 220, 90), 1)

	return billboard
end

local function addIncomeLabel(generator: BasePart, player: Player?)
	if not generator:GetAttribute("IncomePerSecond") then
		return
	end
	buildStatsBillboard(generator, "InfoDisplay", generator, player, generator.Size.Y / 2 + 2.6)
end

local function addCarryLabel(handle: BasePart)
	buildStatsBillboard(handle, "CarryDisplay", handle, nil, handle.Size.Y / 2 + 1.2)
end

createGeneratorTool = function(templatePart: BasePart, level: number?): Tool
	local tool = Instance.new("Tool")
	tool.Name = templatePart.Name
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	local handle = templatePart:Clone()
	handle.Name = "Handle"
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanTouch = false
	handle.CanQuery = false
	handle.Massless = true
	handle.Transparency = 0
	-- BUG TP CORRIGE : une fois l'outil equipe, le Handle entre dans le
	-- workspace avec "IncomePerSecond" -> setupPickup le prenait pour un
	-- brainrot au sol et l'ANCRAIT a sa position d'origine (celle du
	-- template, dans BrainrotPack) : le personnage, soude a lui, etait
	-- teleporte la-bas. Ce marqueur (+ le filtre Tool dans setupPickup)
	-- l'en empeche.
	handle:SetAttribute("_pickupReady", true)
	handle:SetAttribute("_collected", nil)

	-- BUG DUPLICATION CORRIGE : l'ancienne version ne retirait qu'UN seul
	-- ProximityPrompt (FindFirstChildOfClass). Un generateur pose en a deux
	-- (TakePrompt + SellPrompt) : le second restait dans le Handle, se
	-- retrouvait sur le generateur a la pose suivante, et s'accumulait a
	-- chaque reprise. Avec deux "Prendre" sur la meme part, un appui sur E
	-- declenchait DEUX reprises -> brainrot duplique. Et le prompt reste
	-- dans l'objet tenu en main, toujours le plus proche du joueur,
	-- masquait le prompt "Placer" du slot (un seul prompt par touche
	-- affiche) -> impossible de poser.
	-- On retire donc TOUT ce qui appartient au generateur pose.
	for _, d in ipairs(handle:GetDescendants()) do
		if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
			d:Destroy()
		end
	end
	handle:SetAttribute("_retrieving", nil)

	if level then
		handle:SetAttribute("Level", level)
	end

	handle.Parent = tool
	addCarryLabel(handle)

	return tool
end

doPlace = function(handle: BasePart, slot: BasePart, plot: Model, generatorName: string, player: Player?, level: number?): BasePart
	local generator = handle:Clone()
	generator.Name = generatorName
	level = GeneratorLevelShared.Sanitize(level or 1)
	generator:SetAttribute("Level", level)
	-- Taille selon le niveau, AVANT le calcul de position (hors workspace :
	-- pas encore de recalage sur le slot ici).
	GeneratorLevelShared.ApplyScale(generator, level)
	generator:SetAttribute("_retrieving", nil)

	-- Par securite (outils sauvegardes avant le correctif, avec des
	-- prompts restes dedans) : aucun prompt ni panneau herite, ceux du
	-- generateur sont recrees juste en dessous.
	for _, d in ipairs(generator:GetDescendants()) do
		if d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") then
			d:Destroy()
		end
	end
	local finalCFrame = computeGeneratorCFrame(slot, generator)
	generator.CFrame = finalCFrame * CFrame.new(0, 1.4, 0)
	generator.Anchored = true
	generator.CanCollide = false
	generator.CanTouch = true
	generator.Transparency = 1
	-- Jamais ramassable au contact une fois pose (seulement via Prendre).
	generator:SetAttribute("_pickupReady", true)
	generator.CanQuery = true
	generator.Massless = false
	generator.Parent = slot

	TweenService:Create(generator, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = finalCFrame,
		Transparency = 0,
	}):Play()

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TakePrompt"
	prompt.ActionText = TAKE_ACTION_TEXT
	prompt.ObjectText = generator:GetAttribute("DisplayName") or generator.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = TAKE_HOLD_DURATION
	prompt.MaxActivationDistance = 10
	-- Retour a l'UI native (Style Custom essaye puis abandonne : l'affichage
	-- ne se declenchait pas de facon fiable). Decalage large pour eviter le
	-- chevauchement avec le prompt "Vendre" juste a cote.
	prompt.UIOffset = Vector2.new(-75, 0)
	prompt.Parent = generator
	-- Le déclenchement est géré par le listener global ProximityPromptService.PromptTriggered
	-- (voir handleTakePrompt plus bas) : une connexion individuelle faite ici, pendant la
	-- partie, ne se déclenchait pas de façon fiable en conditions réelles (bug reproduit et
	-- confirmé : le joueur ne pouvait pas échanger/reprendre son générateur).

	local sellPrompt = Instance.new("ProximityPrompt")
	sellPrompt.Name = "SellPrompt"
	sellPrompt.ActionText = SELL_ACTION_TEXT
	sellPrompt.ObjectText = PlotShared.FormatPrice(getSellValue(generator))
	sellPrompt.KeyboardKeyCode = Enum.KeyCode.G
	sellPrompt.HoldDuration = TAKE_HOLD_DURATION
	sellPrompt.MaxActivationDistance = 10
	sellPrompt.UIOffset = Vector2.new(75, 0)
	sellPrompt.Parent = generator

	-- Le prix affiche doit suivre les upgrades de niveau faits pendant que
	-- le generateur est pose (demande utilisateur : "$600" doit se mettre a
	-- jour) : on reecrit l'ObjectText a chaque changement de l'attribute
	-- "Level". La connexion est nettoyee automatiquement a la destruction
	-- du generateur (repris/vendu).
	generator:GetAttributeChangedSignal("Level"):Connect(function()
		sellPrompt.ObjectText = PlotShared.FormatPrice(getSellValue(generator))
	end)

	addIncomeLabel(generator, player)

	slot:SetAttribute("Occupied", true)
	setSlotPlacePromptEnabled(slot, false)

	return generator
end

doRetrieve = function(generator: BasePart, slot: BasePart): Tool
	-- Verrou pose AVANT tout : la disparition dure 0.18s, et une seconde
	-- demande pendant ce temps (double appui, Vendre + Prendre, BEST)
	-- aurait recree un second outil.
	generator:SetAttribute("_retrieving", true)
	local tool = createGeneratorTool(generator, GeneratorLevelShared.GetLevel(generator))

	slot:SetAttribute("Occupied", false)
	setSlotPlacePromptEnabled(slot, true)

	for _, d in ipairs(generator:GetChildren()) do
		if d:IsA("ProximityPrompt") then
			d.Enabled = false
		end
	end
	generator.CanTouch = false
	local removeTween = TweenService:Create(generator, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = generator.CFrame * CFrame.new(0, 1.2, 0),
		Transparency = 1,
	})
	removeTween.Completed:Connect(function()
		generator:Destroy()
	end)
	removeTween:Play()

	return tool
end

placeCarriedToolInSlot = function(player: Player, slot: BasePart): boolean
	local character = player.Character
	local carriedTool = character and character:FindFirstChildOfClass("Tool")
	if not carriedTool then
		return false
	end

	local handle = carriedTool:FindFirstChild("Handle")
	if not handle or not handle:GetAttribute("IncomePerSecond") then
		return false
	end

	local plot = PlotShared.GetPlayerPlot(player)
	if not plot then
		return false
	end

	if slot:GetAttribute("Locked") then
		return false
	end

	if slot:GetAttribute("Occupied") then
		local oldGenerator = findGeneratorInSlot(slot)
		if oldGenerator then
			local oldTool = doRetrieve(oldGenerator, slot)
			oldTool.Parent = player:WaitForChild("Backpack")
		end
	end

	-- Garde le niveau porte par l'outil (sinon retour au niveau 1).
	doPlace(handle, slot, plot, carriedTool.Name, player, handle:GetAttribute("Level"))
	carriedTool:Destroy()

	return true
end

-- Listener global unique pour tous les ProximityPrompt de pose/reprise, au lieu d'une
-- connexion par prompt. Les connexions individuelles créées au démarrage du serveur
-- (BaseSetup) ou pendant la partie (doPlace, ci-dessus pour TakePrompt) se sont avérées
-- ne pas se déclencher de façon fiable pour un vrai joueur (bug confirmé par test réel :
-- touche E pressée en jeu, le serveur reçoit bien le Triggered, mais l'ancienne connexion
-- individuelle ne produisait aucun effet). Ce listener central, lui, fonctionne de façon fiable.
local function handlePlacePrompt(prompt: ProximityPrompt, triggeringPlayer: Player)
	local slot = prompt.Parent
	if slot and slot:IsA("BasePart") then
		placeCarriedToolInSlot(triggeringPlayer, slot)
	end
end

-- Vend directement le generateur pose (pas besoin de le reprendre dans
-- l'inventaire d'abord) : detruit le generateur, credite l'argent, libere
-- le slot.
local function handleSellPrompt(prompt: ProximityPrompt, triggeringPlayer: Player)
	local generator, slot = getPlacedGenerator(prompt)
	if not (generator and slot) then
		return
	end
	-- Seul le proprietaire du plot vend ses generateurs.
	local ownPlot = PlotShared.GetPlayerPlot(triggeringPlayer)
	if not (ownPlot and generator:IsDescendantOf(ownPlot)) then
		return
	end

	local value = getSellValue(generator)
	doRetrieve(generator, slot) -- libere le slot, cree un Tool (jete juste apres) et anime la disparition
	if value > 0 then
		MoneyService.AddMoney(triggeringPlayer, value)
	end
end

local function handleTakePrompt(prompt: ProximityPrompt, triggeringPlayer: Player)
	local generator, slot = getPlacedGenerator(prompt)
	if not (generator and slot) then
		return
	end
	local plot = PlotShared.GetPlayerPlot(triggeringPlayer)
	if not (plot and generator:IsDescendantOf(plot)) then
		return
	end

	local tCharacter = triggeringPlayer.Character
	local carriedTool = tCharacter and tCharacter:FindFirstChildOfClass("Tool")
	local carriedHandle = carriedTool and carriedTool:FindFirstChild("Handle")

	if carriedHandle and carriedHandle:GetAttribute("IncomePerSecond") then
		local oldTool = doRetrieve(generator, slot)
		doPlace(carriedHandle, slot, plot, carriedTool.Name, triggeringPlayer, carriedHandle:GetAttribute("Level"))
		carriedTool:Destroy()
		oldTool.Parent = triggeringPlayer:WaitForChild("Backpack")
	else
		local newTool = doRetrieve(generator, slot)
		newTool.Parent = triggeringPlayer:WaitForChild("Backpack")
	end
end

game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if prompt.Name == "PlacePrompt" then
		handlePlacePrompt(prompt, triggeringPlayer)
	elseif prompt.Name == "TakePrompt" then
		handleTakePrompt(prompt, triggeringPlayer)
	elseif prompt.Name == "SellPrompt" then
		handleSellPrompt(prompt, triggeringPlayer)
	end
end)

local function setupPickup(part: BasePart)
	if part:GetAttribute("_pickupReady") or isAlreadyPlaced(part) then
		return
	end
	-- Un Handle d'outil (en main) ou un objet porte n'est jamais un
	-- generateur au sol.
	if part:FindFirstAncestorOfClass("Tool") or part:FindFirstAncestorOfClass("Model") and part:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid") then
		return
	end
	part:SetAttribute("_pickupReady", true)

	part.Anchored = true

	part.Touched:Connect(function(hit)
		if part:GetAttribute("_collected") then
			return
		end

		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local price = part:GetAttribute("ShopPrice")
		if price and not MoneyService.RemoveMoney(player, price) then
			return
		end

		part:SetAttribute("_collected", true)
		part.Transparency = 1
		part.CanCollide = false
		part.CanTouch = false

		local tool = createGeneratorTool(part)
		tool.Parent = player:WaitForChild("Backpack")

		task.delay(RESPAWN_TIME, function()
			if part and part.Parent then
				part:SetAttribute("_collected", false)
				part.Transparency = 0
				part.CanCollide = true
				part.CanTouch = true
			end
		end)
	end)
end

-- Scan du workspace mutualise (voir WorkspaceIndex) : couvre les parts deja
-- au sol ET celles ajoutees ensuite, sans parcours dedie ni connexion
-- DescendantAdded propre a ce script.
WorkspaceIndex.ObserveParts(function(part)
	return part:GetAttribute("IncomePerSecond") ~= nil and not isAlreadyPlaced(part)
end, setupPickup)

local PickupService = {}

-- Encaissement de l'argent accumulé sur les dalles de collecte (tag "MoneyCollectPad",
-- posé par BaseSetup). Comme pour les prompts plus haut, c'est câblé ici de façon
-- centralisée plutôt qu'avec une connexion Touched individuelle par dalle créée au
-- démarrage du serveur : la version précédente (Touched câblé dans BaseSetup) souffrait
-- du même bug que les prompts et ne se déclenchait pas de façon fiable (argent bloqué,
-- impossible à encaisser en marchant sur la plaque).
local function wireCollectPad(pad: Instance)
	if not pad:IsA("BasePart") then
		return
	end
	if pad:GetAttribute("_collectWired") then
		return
	end
	pad:SetAttribute("_collectWired", true)

	pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local padPlot = pad:FindFirstAncestor("Base") or pad:FindFirstAncestor("Ranch")
		if PlotShared.GetPlayerPlot(player) ~= padPlot then
			return
		end

		local pending = pad:GetAttribute("Pending") or 0
		local amount = math.floor(pending)
		if amount <= 0 then
			return
		end

		-- On garde la fraction restante au lieu de la perdre.
		pad:SetAttribute("Pending", pending - amount)
		MoneyService.AddMoney(player, amount)
		playCollectSound(pad)
		flashCollectPad(pad)

		local display = pad:FindFirstChild("CollectDisplay")
		local amountLabel = display and display:FindFirstChild("AmountLabel")
		if amountLabel then
			amountLabel.Text = PlotShared.FormatPrice(0)
		end
	end)
end

for _, pad in ipairs(CollectionService:GetTagged("MoneyCollectPad")) do
	wireCollectPad(pad)
end
CollectionService:GetInstanceAddedSignal("MoneyCollectPad"):Connect(wireCollectPad)

PickupService.CreateGeneratorTool = createGeneratorTool

-- Vide un slot (generateur + argent non collecte) quand sa base change de
-- proprietaire : rien ne doit passer au joueur suivant.
PickupService.ClearSlot = function(slot: BasePart)
	for _, child in ipairs(slot:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("IncomePerSecond") then
			child:Destroy()
		end
	end
	slot:SetAttribute("Occupied", false)
	setSlotPlacePromptEnabled(slot, true)

	local pad = PlotShared.GetCollectPad(slot)
	if pad then
		pad:SetAttribute("Pending", 0)
		local display = pad:FindFirstChild("CollectDisplay")
		local amountLabel = display and display:FindFirstChild("AmountLabel")
		if amountLabel then
			amountLabel.Text = PlotShared.FormatPrice(0)
		end
	end
end
PickupService.PlaceCarriedToolInSlot = placeCarriedToolInSlot
PickupService.GetSellValue = getSellValue
PickupService.FindGeneratorInSlot = findGeneratorInSlot
-- Reprend un generateur pose : libere le slot et renvoie son Tool (non
-- parente). Utilise par le bouton BEST (InventoryService).
PickupService.RetrieveFromSlot = function(generator: BasePart, slot: BasePart): Tool
	return doRetrieve(generator, slot)
end
PickupService.PlaceGeneratorInSlot = function(templatePart: BasePart, slot: BasePart, generatorName: string, player: Player?, level: number?): BasePart
	local plot = PlotShared.GetPlayerPlot(player)
	return doPlace(templatePart, slot, plot, generatorName, player, level)
end

return PickupService
