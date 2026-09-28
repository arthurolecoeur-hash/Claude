--[[
	YeetService
	-----------
	Script (serveur) dans ServerScriptService.Yeet.

	Mecanique "Yeet a Noob" :
	  1. Sur la ligne jaune, le client envoie ("Yeet", power 0..1).
	  2. On valide (zone, cooldown, pas de brainrot porte, pas deja noob).
	  3. Distance = BaseDistance(Force) * multiplicateur (x0.5 -> x1.5).
	  4. Le vol est ANIME COTE CLIENT (fluide) : le serveur n'envoie que
	     depart / arrivee / duree / horodatage.
	  5. A l'atterrissage : le perso est teleporte sur place et transforme
	     en noob (HumanoidDescription + matiere Studs).
	  6. De retour sur la SAFE ZONE : apparence d'origine restauree.

	La mort ou un respawn remet tout a zero (le nouveau perso est normal).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local YeetFolder = ReplicatedStorage:WaitForChild("Yeet")
local Shared = require(YeetFolder:WaitForChild("YeetShared"))
local YeetEvent = YeetFolder:WaitForChild("YeetEvent") :: RemoteEvent

local ForceService = require(ServerScriptService.Training.ForceService)
local Carry = require(ServerScriptService.Brainrots.BrainrotCarryService)

local CHECK_INTERVAL = 0.2
-- Marge laterale : on n'atterrit pas dans les murs d'eau / falaises.
local SIDE_MARGIN = 32
-- Marge au bout de la derniere zone (Steampunk, mur du fond).
local END_MARGIN = 6
-- Vol : les lancers vers les zones lointaines (~2000 studs) restent lisibles.
-- (20 zones : ~6100 studs de vol max, le temps de vol reste plafonne)
local MAX_FLIGHT_TIME = 6.8
local MAX_APEX = 300

--== Map ==--
local maps = Workspace:WaitForChild("Build"):WaitForChild("Maps")

-- Zones dans l'ordre depuis la ligne jaune. `floor` = la dalle sol du modele.
local ZONES = {
	{ model = "Farm Map", label = "FARM", color = Color3.fromRGB(140, 230, 90) },
	{ model = "Desert Map", label = "DESERT", color = Color3.fromRGB(255, 205, 90) },
	{ model = "Cave Map", label = "CAVE", color = Color3.fromRGB(180, 120, 255) },
	{ model = "Tuundra Map", label = "TUNDRA", color = Color3.fromRGB(140, 225, 255) },
	{ model = "Jungle Map", label = "JUNGLE", color = Color3.fromRGB(255, 90, 90) },
	{ model = "Candy Map", label = "CANDY", color = Color3.fromRGB(255, 130, 200) },
	{ model = "Cosmos Map", label = "COSMOS", color = Color3.fromRGB(200, 110, 255) },
	{ model = "Pirate Map", label = "PIRATE", color = Color3.fromRGB(255, 150, 45) },
	{ model = "Haunted Map", label = "HAUNTED", color = Color3.fromRGB(170, 255, 60) },
	{ model = "Steampunk Map", label = "STEAMPUNK", color = Color3.fromRGB(215, 175, 100) },
}

local floors = {}
local minX, maxX = math.huge, -math.huge
local farZ = math.huge
for _, zone in ipairs(ZONES) do
	local model = maps:WaitForChild(zone.model)
	local floor = model:WaitForChild(zone.model) :: BasePart
	zone.floor = floor
	table.insert(floors, floor)
	minX = math.min(minX, floor.Position.X - floor.Size.X / 2)
	maxX = math.max(maxX, floor.Position.X + floor.Size.X / 2)
	farZ = math.min(farZ, floor.Position.Z - floor.Size.Z / 2)
end
-- L'eau entre les zones est un sol marchable : on peut y atterrir.
local waterPoints = maps:FindFirstChild("WaterPoints")
if waterPoints then
	for _, d in ipairs(waterPoints:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Water" then
			table.insert(floors, d)
		end
	end
end
minX += SIDE_MARGIN
maxX -= SIDE_MARGIN
farZ += END_MARGIN

-- Publie les murs invisibles pour les clients (StreamingEnabled : ils
-- n'ont pas forcement les sols des zones lointaines).
do
	local parts = {}
	for _, z in ipairs(Shared.GetWallZs()) do
		table.insert(parts, string.format("%.3f", z))
	end
	YeetFolder:SetAttribute("WallZs", table.concat(parts, ","))
end

local floorParams = RaycastParams.new()
floorParams.FilterType = Enum.RaycastFilterType.Include
floorParams.FilterDescendantsInstances = floors

local clearParams = OverlapParams.new()
clearParams.FilterType = Enum.RaycastFilterType.Exclude
do
	local list = table.clone(floors)
	local pads = maps:FindFirstChild("BrainrotSpawnPoint")
	if pads then
		table.insert(list, pads)
	end
	local spawned = Workspace:FindFirstChild("SpawnedBrainrots")
	if spawned then
		table.insert(list, spawned)
	end
	clearParams.FilterDescendantsInstances = list
end

local function groundAt(x: number, z: number): Vector3?
	local r = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), floorParams)
	return r and r.Position
end

-- Pas d'atterrissage dans un tronc, une grange, un cactus...
local function isClear(ground: Vector3): boolean
	local parts = Workspace:GetPartBoundsInBox(
		CFrame.new(ground + Vector3.new(0, 3.5, 0)),
		Vector3.new(4, 6, 4),
		clearParams)
	for _, p in ipairs(parts) do
		if p.CanCollide then
			local model = p:FindFirstAncestorOfClass("Model")
			if not (model and model:FindFirstChildOfClass("Humanoid")) then
				return false
			end
		end
	end
	return true
end

local OFFSETS_X = { 0, 6, -6, 12, -12, 18, -18, 26, -26, 34, -34 }
local OFFSETS_Z = { 0, 6, -6, 12, -12 }

local function findLanding(x: number, z: number, lineZ: number): Vector3
	for _, dz in ipairs(OFFSETS_Z) do
		for _, dx in ipairs(OFFSETS_X) do
			local px = math.clamp(x + dx, minX, maxX)
			local pz = math.clamp(z + dz, farZ, lineZ)
			local g = groundAt(px, pz)
			if g and isClear(g) then
				return g
			end
		end
	end
	return groundAt(x, z) or Vector3.new(x, 0, z)
end

local function zoneAt(z: number)
	for _, zone in ipairs(ZONES) do
		local f = zone.floor
		if math.abs(z - f.Position.Z) <= f.Size.Z / 2 then
			return zone.label, zone.color
		end
	end
	return "SPLASH", Color3.fromRGB(80, 170, 255)
end

--== Apparence noob ==--
local ACCESSORY_PROPS = {
	"HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory",
	"ShouldersAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory",
}
local BODY_PART_PROPS = { "Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg" }

local function buildNoobDescription(original: HumanoidDescription): HumanoidDescription
	local d = original:Clone()
	d.HeadColor = Shared.NOOB_YELLOW
	d.LeftArmColor = Shared.NOOB_YELLOW
	d.RightArmColor = Shared.NOOB_YELLOW
	d.TorsoColor = Shared.NOOB_BLUE
	d.LeftLegColor = Shared.NOOB_GREEN
	d.RightLegColor = Shared.NOOB_GREEN
	d.Shirt = 0
	d.Pants = 0
	d.GraphicTShirt = 0
	d.Face = 0
	for _, prop in ipairs(BODY_PART_PROPS) do
		d[prop] = 0
	end
	for _, prop in ipairs(ACCESSORY_PROPS) do
		d[prop] = ""
	end
	pcall(function()
		d:SetAccessories({}, true)
	end)
	d.HeightScale = 1
	d.WidthScale = 1
	d.DepthScale = 1
	d.HeadScale = 1
	d.BodyTypeScale = 0
	d.ProportionScale = 0
	return d
end

-- Parties du corps (pas le RootPart, pas le brainrot porte, pas les accessoires).
local function bodyParts(character: Model): { BasePart }
	local list = {}
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" and not child:GetAttribute("CarriedVisual") then
			table.insert(list, child)
		end
	end
	return list
end

local function applyStuds(character: Model)
	for _, p in ipairs(bodyParts(character)) do
		p.Material = Enum.Material.Plastic
		p.MaterialVariant = "Studs"
		p:SetAttribute("_noobStuds", true)
	end
end

local function snapshotMaterials(character: Model)
	local snap = {}
	for _, p in ipairs(bodyParts(character)) do
		snap[p.Name] = { material = p.Material, variant = p.MaterialVariant }
	end
	return snap
end

local function restoreMaterials(character: Model, snap)
	for _, p in ipairs(bodyParts(character)) do
		if p:GetAttribute("_noobStuds") then
			local s = snap and snap[p.Name]
			p.Material = s and s.material or Enum.Material.Plastic
			p.MaterialVariant = s and s.variant or ""
			p:SetAttribute("_noobStuds", nil)
		end
	end
end

--== Etat joueurs ==--
-- [player] = { phase = nil|"flying"|"noob"|"restoring", last, character, original, materials }
local states: { [Player]: any } = {}

local function getState(player: Player)
	local st = states[player]
	if not st then
		st = { last = 0 }
		states[player] = st
	end
	return st
end

local function resetState(player: Player)
	local st = states[player]
	if st then
		st.phase = nil
		st.character = nil
		st.original = nil
		st.materials = nil
		st.charging = false
	end
	player:SetAttribute("YeetCharging", nil)
	player:SetAttribute("Yeeting", nil)
	player:SetAttribute("IsNoob", nil)
	player:SetAttribute("YeetLimitZ", nil)
end

local function rootHeight(humanoid: Humanoid, root: BasePart): number
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return 3
end

--== Streaming : la map d'atterrissage se charge PENDANT le vol ==--
-- Avec StreamingEnabled, le serveur ne charge que autour du perso, qui reste
-- fige sur la ligne pendant le vol. On deplace donc le "focus de replication"
-- du joueur le long de la trajectoire et on demande le point d'impact des le
-- lancer : a l'atterrissage la map est deja chargee (plus de vide / chute).
local FOCUS_STEP = 0.1
local FOCUS_LEAD = 0.06 -- avance (fraction du vol) pour charger avant que la camera arrive

local function streamAlongFlight(player: Player, st, character: Model, start: Vector3, land: Vector3, apex: number, startTime: number, duration: number)
	local focus = Instance.new("Part")
	focus.Name = "YeetStreamFocus"
	focus.Anchored = true
	focus.CanCollide = false
	focus.CanQuery = false
	focus.CanTouch = false
	focus.CastShadow = false
	focus.Transparency = 1
	focus.Size = Vector3.one
	focus.Position = start
	focus.Parent = Workspace

	-- Precharge le point d'impact tout de suite (le vol dure 1 a 5 s).
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(land, 4)
		end)
	end)
	pcall(function()
		player.ReplicationFocus = focus
	end)

	local target = land + Vector3.new(0, 3, 0)
	while player.Parent and st.phase == "flying" and st.character == character do
		local a = math.clamp((Workspace:GetServerTimeNow() - startTime) / duration, 0, 1)
		local ahead = math.min(a + FOCUS_LEAD, 1)
		focus.Position = Shared.FlightPosition(start, target, apex, ahead) + (st.steer or Vector3.zero)
		task.wait(FOCUS_STEP)
	end

	pcall(function()
		if player.ReplicationFocus == focus then
			player.ReplicationFocus = nil
		end
	end)
	focus:Destroy()
end

local function landPlayer(player: Player, character: Model, land: Vector3, label: string, color: Color3, distance: number)
	local st = states[player]
	if not (st and st.phase == "flying" and st.character == character) then
		return
	end

	-- Controle en vol : on decale le point d'impact selon la direction du joueur.
	local steer = st.steer
	if steer and steer.Magnitude > 0.5 then
		local x = math.clamp(land.X + steer.X, minX, maxX)
		local z = math.clamp(land.Z + steer.Z, farZ, st.lineZ)
		land = findLanding(x, z, st.lineZ)
		label, color = zoneAt(land.Z)
		distance = (Vector3.new(land.X, 0, land.Z) - Vector3.new(st.origin.X, 0, st.origin.Z)).Magnitude
	end
	st.steer = nil
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character.Parent and humanoid and root and humanoid.Health > 0) then
		resetState(player)
		return
	end

	-- Teleport sur le point d'impact, face a la SAFE ZONE (+Z).
	local pos = land + Vector3.new(0, rootHeight(humanoid, root) + 1, 0)
	character:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, 1)))
	root.AssemblyLinearVelocity = Vector3.zero
	-- On garde le perso ancre tant que le sol n'est pas charge (max 1.5 s),
	-- sinon il tombe dans le vide avant que la map arrive.
	root.Anchored = true
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(pos, 1.5)
		end)
		if root.Parent then
			root.Anchored = false
		end
	end)

	st.phase = "noob"
	player:SetAttribute("Yeeting", nil)
	-- Ouvre les murs jusqu'a la zone d'impact (pas plus loin).
	player:SetAttribute("YeetLimitZ", Shared.LimitForLanding(land.Z))
	player:SetAttribute("IsNoob", true)
	YeetEvent:FireAllClients("Landed", player, land, label, color, math.floor(distance + 0.5))

	-- Transformation en noob.
	local ok, err = pcall(function()
		st.original = humanoid:GetAppliedDescription()
		st.materials = snapshotMaterials(character)
		humanoid:ApplyDescription(buildNoobDescription(st.original))
	end)
	if not ok then
		warn("YeetService: morph noob rate -", err)
	end
	if character.Parent and st.character == character then
		applyStuds(character)
	end
end

local function restorePlayer(player: Player, st)
	local character = st.character
	st.phase = "restoring"
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		YeetEvent:FireAllClients("Unnoob", player, root.Position)
	end
	if humanoid and st.original then
		local ok, err = pcall(function()
			humanoid:ApplyDescription(st.original)
		end)
		if not ok then
			warn("YeetService: restauration apparence ratee -", err)
		end
	end
	if character and character.Parent then
		restoreMaterials(character, st.materials)
	end
	-- Un respawn pendant l'ApplyDescription a deja tout remis a zero.
	if st.phase == "restoring" then
		resetState(player)
	end
end

--== Lancer ==--
--[[
	Phase "Charge" : le noob apparait derriere le joueur, il l'attrape et
	le tient au-dessus de sa tete pendant la barre. Le serveur fige le
	joueur face au champ et previent tout le monde (anim cote clients).
]]
local CHARGE_SPAM = 0.35

local function stopCharge(player: Player, st)
	if not st.charging then
		return
	end
	st.charging = false
	player:SetAttribute("YeetCharging", nil)
	if not st.phase then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			root.Anchored = false
		end
	end
end

local function onCharge(player: Player, st)
	local now = os.clock()
	if st.phase or st.charging or now - st.last < Shared.COOLDOWN or now - (st.lastCharge or 0) < CHARGE_SPAM then
		return
	end
	if Carry.IsCarrying(player) then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and root:IsA("BasePart") and humanoid.Health > 0) then
		return
	end
	if not Shared.IsOnYeetLine(Shared.GetSafeZone(), root.Position, Shared.LINE_TOLERANCE) then
		return
	end
	st.charging = true
	st.lastCharge = now
	humanoid:UnequipTools()
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	character:PivotTo(CFrame.lookAt(root.Position, root.Position + Vector3.new(0, 0, -1)))
	player:SetAttribute("YeetCharging", true)
	YeetEvent:FireAllClients("Charge", player, Workspace:GetServerTimeNow())
end

YeetEvent.OnServerEvent:Connect(function(player: Player, action: any, power: any)
	local st = getState(player)
	if action == "Steer" then
		-- power = decalage (Vector3) voulu par le client pendant le vol.
		if st.phase ~= "flying" or not st.flightStart or typeof(power) ~= "Vector3" then
			return
		end
		if power.X ~= power.X or power.Z ~= power.Z then
			return
		end
		local reach = Shared.STEER_SPEED * math.max(0, Workspace:GetServerTimeNow() - st.flightStart) + 2
		local mx = math.min(Shared.STEER_MAX_X, reach)
		local mz = math.min(Shared.STEER_MAX_Z, reach)
		st.steer = Vector3.new(math.clamp(power.X, -mx, mx), 0, math.clamp(power.Z, -mz, mz))
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player then
				YeetEvent:FireClient(other, "Steer", player, st.steer)
			end
		end
		return
	elseif action == "Charge" then
		onCharge(player, st)
		return
	elseif action == "Cancel" then
		if st.charging and not st.phase then
			stopCharge(player, st)
			YeetEvent:FireAllClients("Cancel", player)
		end
		return
	elseif action ~= "Yeet" then
		return
	end
	if typeof(power) ~= "number" or power ~= power then
		return
	end

	local now = os.clock()
	if st.phase or now - st.last < Shared.COOLDOWN then
		return
	end
	if Carry.IsCarrying(player) then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (humanoid and root and humanoid.Health > 0) then
		return
	end

	local zone = Shared.GetSafeZone()
	if not Shared.IsOnYeetLine(zone, root.Position, Shared.LINE_TOLERANCE) then
		return
	end

	st.last = now
	st.phase = "flying"
	st.character = character
	st.charging = false
	player:SetAttribute("YeetCharging", nil)

	local mult = Shared.MultFromPower(power)
	local distance = Shared.BaseDistance(ForceService.GetForce(player)) * mult

	-- Bord avant de la ligne jaune : on atterrit toujours dans le champ.
	local lineZ = (zone :: BasePart).Position.Z - (zone :: BasePart).Size.Z / 2 - 4
	local x = math.clamp(root.Position.X, minX, maxX)
	local targetZ = math.clamp(root.Position.Z - distance, farZ, lineZ)
	local land = findLanding(x, targetZ, lineZ)
	local label, color = zoneAt(land.Z)

	local travelled = (Vector3.new(land.X, 0, land.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
	local duration = math.clamp(1.1 + travelled / 320, 1.2, MAX_FLIGHT_TIME)
	local apex = math.min(16 + travelled * 0.16, MAX_APEX)

	-- Le lanceur reste fige sur la ligne, tourne vers le champ, pendant le vol.
	humanoid:UnequipTools()
	root.Anchored = true
	character:PivotTo(CFrame.lookAt(root.Position, root.Position + Vector3.new(0, 0, -1)))
	player:SetAttribute("Yeeting", true)

	-- Le noob part d'au-dessus de la tete, apres la prise d'elan (WINDUP).
	local start = root.Position + Shared.HOLD_OFFSET
	local startTime = Workspace:GetServerTimeNow() + Shared.WINDUP
	st.flightStart = startTime
	st.steer = Vector3.zero
	st.origin = root.Position
	st.lineZ = lineZ
	YeetEvent:FireAllClients("Throw", player, start, land, duration, apex, startTime, mult)
	task.spawn(streamAlongFlight, player, st, character, start, land, apex, startTime, duration)

	task.delay(Shared.WINDUP + duration, landPlayer, player, character, land, label, color, travelled)
end)

--== Retour force (ex : attrape par le Tung Tung Tung Sahur puis TP base) ==--
local forceRestore = script.Parent:FindFirstChild("ForceRestore")
if not forceRestore then
	forceRestore = Instance.new("BindableEvent")
	forceRestore.Name = "ForceRestore"
	forceRestore.Parent = script.Parent
end
(forceRestore :: BindableEvent).Event:Connect(function(player: Player)
	local st = states[player]
	if st and st.phase == "noob" and player.Character == st.character then
		task.spawn(restorePlayer, player, st)
	end
end)

--== Retour a la SAFE ZONE ==--
task.spawn(function()
	while true do
		task.wait(CHECK_INTERVAL)
		local zone = Shared.GetSafeZone()
		for player, st in pairs(states) do
			if st.phase == "noob" then
				local character = player.Character
				if character ~= st.character then
					resetState(player)
				else
					local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if root and Shared.IsBackInSafeZone(zone, root.Position) then
						task.spawn(restorePlayer, player, st)
					end
				end
			end
		end
	end
end)

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		resetState(player)
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end

Players.PlayerRemoving:Connect(function(player)
	states[player] = nil
end)