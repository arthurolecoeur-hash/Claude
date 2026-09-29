--[[
	YeetShared
	----------
	ModuleScript dans ReplicatedStorage.Yeet.

	Reglages et fonctions communs au serveur (YeetService) et au client
	(YeetClient) pour la mecanique "Yeet a Noob" (facon Kick a Lucky Block) :

	  - sur la ligne jaune (SAFE ZONE), le joueur lance la barre "xX Distance" ;
	  - il la stoppe : multiplicateur entre MIN_MULT et MAX_MULT (x1.5 max) ;
	  - distance = BaseDistance(Force) * multiplicateur ;
	  - le noob vole, atterrit, et le joueur DEVIENT ce noob a l'arrivee ;
	  - revenu a la SAFE ZONE, il reprend son apparence normale.
]]

local Workspace = game:GetService("Workspace")

local YeetShared = {}

--== Barre ==--
YeetShared.MIN_MULT = 0.5
YeetShared.MAX_MULT = 1.5
-- A partir de ce multiplicateur c'est un "PERFECT".
YeetShared.PERFECT_MULT = 1.45
-- Duree d'un aller-retour complet de la barre (secondes).
YeetShared.METER_PERIOD = 1.3

--== Distance ==--
-- La Force monte de facon exponentielle (sacs x3 a chaque palier) : la
-- distance suit donc le LOG de la Force, sinon on sortirait de la map au
-- 3e sac.
--   Force 0        -> 30 studs
--   Force 1 000    -> ~195
--   Force 1 000 000 -> ~360
--   Force 1e9      -> ~525   (x1.5 -> jungle)
--
-- Au-dela de 1e9 (5 nouvelles zones), la pente augmente pour que chaque
-- nouveau palier de sac ouvre une zone. Distances depuis la ligne jaune :
-- (maps allongees : 125 / 130 / 135 / 140 / 145 studs)
--   Candy 896-1021 / Volcano 1126-1256 / Sky 1376-1511 / Cyber 1646-1786 / Cosmos 1936-2081
-- Reperes (base -> avec un PERFECT x1.5) :
--   1e10 -> 640  (x1.5 = 960  : Candy)
--   1e11 -> 790  (x1.5 = 1185 : Volcano)
--   1e12 -> 960  (x1.5 = 1440 : Sky)
--   1e13 -> 1140 (x1.5 = 1710 : Cyber)
--   1e14 -> 1340 (x1.5 = 2010 : Cosmos)
--
-- 5 zones supplementaires (Pirate / Haunted / Steampunk / Atlantis / Dragon),
-- separees par des intersections d'eau de plus en plus larges (165 / 180 /
-- 195 / 210 / 225 studs) : distances depuis la ligne jaune (Z = 780) :
--   Water10 2081-2246 | Pirate 2246-2396 | Water11 2396-2576 | Haunted 2576-2731
--   Water12 2731-2926 | Steam 2926-3086  | Water13 3086-3296 | Atlantis 3296-3461
--   Water14 3461-3686 | Dragon 3686-3856
-- Chaque zone demande x5 de Force (pas x10) : un palier de sac (x5) par zone.
-- Reperes (base -> avec un PERFECT x1.5, centre de la zone) :
--   5e14   -> 1550 (x1.5 = 2325 : Pirate)
--   2.5e15 -> 1770 (x1.5 = 2655 : Haunted)
--   1.25e16-> 2005 (x1.5 = 3007 : Steam)
--   6.3e16 -> 2250 (x1.5 = 3375 : Atlantis)
--   3.2e17 -> 2515 (x1.5 = 3772 : Dragon)
--
-- 5 zones de plus (Sakura / Toy / Enchanted / Olympus / Glitch), eau de
-- 240 / 255 / 270 / 285 / 300 studs, maps de 175 / 180 / 185 / 190 / 195 :
--   Water15 3856-4096 | Sakura 4096-4271    | Water16 4271-4526 | Toy 4526-4706
--   Water17 4706-4976 | Enchanted 4976-5161 | Water18 5161-5446 | Olympus 5446-5636
--   Water19 5636-5936 | Glitch 5936-6131 (mur du fond)
-- Toujours x5 de Force par zone (un nouveau sac par zone, voir BagTiersData) :
--   1.6e18 -> 2790 (x1.5 = 4185 : Sakura)
--   8e18   -> 3080 (x1.5 = 4620 : Toy)
--   4e19   -> 3380 (x1.5 = 5070 : Enchanted)
--   2e20   -> 3695 (x1.5 = 5542 : Olympus)
--   1e21   -> 4025 (x1.5 = 6037 : Glitch)
-- Un lancer un peu faible (~x1.2) retombe dans la zone d'avant : il faut
-- viser le PERFECT pour debloquer une zone des l'achat de son sac.
YeetShared.BASE_DISTANCE = 30
YeetShared.DISTANCE_PER_DECADE = 55
-- { log10(Force), distance de base } au-dela de 1e9, interpolation lineaire.
YeetShared.LATE_CURVE = {
	{ 9, 525 },
	{ 10, 640 },
	{ 11, 790 },
	{ 12, 960 },
	{ 13, 1140 },
	{ 14, 1340 },
	{ 14.7, 1550 },
	{ 15.4, 1770 },
	{ 16.1, 2005 },
	{ 16.8, 2250 },
	{ 17.5, 2515 },
	{ 18.2, 2790 },
	{ 18.9, 3080 },
	{ 19.6, 3380 },
	{ 20.3, 3695 },
	{ 21.0, 4025 },
}
YeetShared.LATE_PER_DECADE = 470 -- au-dela du dernier repere (le mur du fond arrete tout)

--== Divers ==--
YeetShared.COOLDOWN = 2
-- Temps de prise d'elan (noob souleve au-dessus de la tete) avant le vol.
YeetShared.WINDUP = 0.35
-- Apparition du noob derriere le joueur + prise, avant que la barre demarre.
YeetShared.PICKUP = 0.9
-- Controle en vol : le lanceur peut un peu diriger le noob (studs/s, decalage max).
YeetShared.STEER_SPEED = 28
YeetShared.STEER_MAX_X = 40 -- gauche / droite
YeetShared.STEER_MAX_Z = 0 -- pas de controle avant / arriere
YeetShared.STEER_SEND = 0.1 -- frequence d'envoi au serveur
-- Position du noob tenu, relative au RootPart du lanceur (au-dessus / derriere la tete).
YeetShared.HOLD_OFFSET = Vector3.new(0, 4.7, 0.6)
-- Marge autour de la ligne jaune pour pouvoir lancer.
YeetShared.LINE_TOLERANCE = 4
-- Hauteur au-dessus de la SAFE ZONE encore consideree "dedans".
YeetShared.ZONE_HEIGHT = 25

--== Couleurs du noob classique ==--
YeetShared.NOOB_YELLOW = Color3.fromRGB(245, 205, 48)
YeetShared.NOOB_BLUE = Color3.fromRGB(13, 105, 172)
YeetShared.NOOB_GREEN = Color3.fromRGB(164, 189, 71)

function YeetShared.MultFromPower(power: number): number
	power = math.clamp(power, 0, 1)
	return YeetShared.MIN_MULT + (YeetShared.MAX_MULT - YeetShared.MIN_MULT) * power
end

--[[
	Murs invisibles (crees COTE CLIENT, voir YeetClient) :
	  mur 1 = bord avant de la SAFE ZONE, puis un mur au milieu de chaque
	  bande d'eau entre deux zones.
	Tout est ferme tant qu'on n'est pas noob. Apres un yeet, le serveur pose
	"YeetLimitZ" = Z du premier mur AU-DELA du point d'impact : les murs
	entre l'impact et la safe zone s'ouvrent, ceux plus loin restent fermes.
]]
YeetShared.NO_LIMIT = -1e9
YeetShared.WALL_THICKNESS = 1
YeetShared.ZONE_MODELS = {
	"Farm Map", "Desert Map", "Cave Map", "Tuundra Map", "Jungle Map",
	"Candy Map", "Cosmos Map", "Pirate Map", "Haunted Map", "Steampunk Map",
}

function YeetShared.GetWallZs(): { number }
	local zs = {}
	-- StreamingEnabled : les maps lointaines (Cyber, Cosmos...) ne sont pas
	-- chargees chez le client au spawn. Le serveur publie donc les Z des murs
	-- en attribut (voir YeetService) : le client n'a plus besoin des sols.
	local published = script.Parent and script.Parent:GetAttribute("WallZs")
	if typeof(published) == "string" and published ~= "" then
		for s in string.gmatch(published, "[^,]+") do
			table.insert(zs, tonumber(s))
		end
		return zs
	end
	local safe = YeetShared.GetSafeZone()
	local build = Workspace:FindFirstChild("Build")
	local maps = build and build:FindFirstChild("Maps")
	if not (safe and maps) then
		return zs
	end
	table.insert(zs, safe.Position.Z - safe.Size.Z / 2 - 2)
	local floors = {}
	for _, name in ipairs(YeetShared.ZONE_MODELS) do
		local model = maps:FindFirstChild(name)
		local floor = model and model:FindFirstChild(name)
		if floor and floor:IsA("BasePart") then
			table.insert(floors, floor)
		end
	end
	for i = 1, #floors - 1 do
		local a, b = floors[i], floors[i + 1]
		table.insert(zs, ((a.Position.Z - a.Size.Z / 2) + (b.Position.Z + b.Size.Z / 2)) / 2)
	end
	return zs
end

-- Premier mur au-dela (plus loin de la safe zone) du point z.
function YeetShared.LimitForLanding(z: number): number
	local best = YeetShared.NO_LIMIT
	for _, wz in ipairs(YeetShared.GetWallZs()) do
		if wz < z and wz > best then
			best = wz
		end
	end
	return best
end


function YeetShared.BaseDistance(force: number): number
	local lg = math.log10(1 + math.max(force, 0))
	local curve = YeetShared.LATE_CURVE
	if lg <= curve[1][1] then
		return YeetShared.BASE_DISTANCE + YeetShared.DISTANCE_PER_DECADE * lg
	end
	for i = 1, #curve - 1 do
		local a, b = curve[i], curve[i + 1]
		if lg <= b[1] then
			return a[2] + (b[2] - a[2]) * (lg - a[1]) / (b[1] - a[1])
		end
	end
	local last = curve[#curve]
	return last[2] + YeetShared.LATE_PER_DECADE * (lg - last[1])
end

-- Onde triangle 0 -> 1 -> 0 : vitesse constante, plus juste qu'un sinus
-- (qui ralentit pile en haut et rend le PERFECT trop facile).
function YeetShared.MeterValue(t: number): number
	local x = (t / YeetShared.METER_PERIOD) % 1
	return 1 - math.abs(x * 2 - 1)
end

function YeetShared.FlightPosition(start: Vector3, land: Vector3, apex: number, a: number): Vector3
	return start:Lerp(land, a) + Vector3.new(0, apex * 4 * a * (1 - a), 0)
end

function YeetShared.GetSafeZone(): BasePart?
	local terrain = Workspace:FindFirstChild("Terrain")
	local zone = terrain and terrain:FindFirstChild("SAFE ZONE")
	if zone and zone:IsA("BasePart") then
		return zone
	end
	return nil
end

-- Sur la ligne jaune elle-meme (la ou on lance).
function YeetShared.IsOnYeetLine(zone: BasePart?, position: Vector3, tolerance: number?): boolean
	if not zone then
		return false
	end
	local tol = tolerance or 0
	local p = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(p.X) <= half.X
		and math.abs(p.Z) <= half.Z + tol
		and p.Y >= -half.Y
		and p.Y <= half.Y + YeetShared.ZONE_HEIGHT
end

-- Sur la ligne OU derriere (cote bases) : retour en securite du noob.
-- Le +Z local de la SAFE ZONE pointe vers les bases.
function YeetShared.IsBackInSafeZone(zone: BasePart?, position: Vector3): boolean
	if not zone then
		return false
	end
	local p = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return math.abs(p.X) <= half.X
		and p.Z >= -half.Z
		and p.Y >= -half.Y
		and p.Y <= half.Y + YeetShared.ZONE_HEIGHT
end

--[[
	Noob en blocs, style studs, bras en l'air (il hurle en volant).
	Face avant = -Z du modele. PrimaryPart = Torso.
	skinKey : skin de Mastery (couleurs + chapeau), nil = noob classique.
	Les parts du chapeau portent l'attribut HeadOffset (suivent la tete).
]]
local function skinOf(skinKey: any)
	local ok, MasteryShared = pcall(function()
		return require(game:GetService("ReplicatedStorage"):WaitForChild("Mastery"):WaitForChild("MasteryShared", 5))
	end)
	return ok and MasteryShared and MasteryShared.Get(skinKey) or nil
end

function YeetShared.SkinColors(skinKey: any)
	local skin = skinOf(skinKey)
	if skin and skin.colors then
		return skin.colors, skin
	end
	return { head = YeetShared.NOOB_YELLOW, torso = YeetShared.NOOB_BLUE, arms = YeetShared.NOOB_YELLOW, legs = YeetShared.NOOB_GREEN }, nil
end

function YeetShared.BuildNoob(skinKey: any?): Model
	local model = Instance.new("Model")
	model.Name = "YeetNoob"
	local colors, skin = YeetShared.SkinColors(skinKey)

	local function part(name: string, size: Vector3, offset: Vector3, color: Color3, parent: Instance?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = CFrame.new(offset)
		p.Color = color
		p.Material = Enum.Material.Plastic
		p.MaterialVariant = "Studs"
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = true
		p.Parent = parent or model
		return p
	end

	local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.zero, colors.torso)
	local head = part("Head", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 1.65, 0), colors.head)
	part("LeftArm", Vector3.new(1, 2, 1), Vector3.new(-1.5, 1.4, 0), colors.arms)
	part("RightArm", Vector3.new(1, 2, 1), Vector3.new(1.5, 1.4, 0), colors.arms)
	part("LeftLeg", Vector3.new(1, 2, 1), Vector3.new(-0.5, -2, 0), colors.legs)
	part("RightLeg", Vector3.new(1, 2, 1), Vector3.new(0.5, -2, 0), colors.legs)

	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	-- Chapeau / cheveux du skin, soudes a la tete.
	local hat = skin and skin.hat
	if hat then
		local pieces = {}
		if hat.kind == "hardhat" then
			table.insert(pieces, { Vector3.new(1.5, 0.55, 1.5), Vector3.new(0, 2.5, 0) })
			table.insert(pieces, { Vector3.new(1.9, 0.15, 1.9), Vector3.new(0, 2.28, 0) })
			table.insert(pieces, { Vector3.new(0.3, 0.2, 1.52), Vector3.new(0, 2.82, 0) })
		elseif hat.kind == "cap" then
			table.insert(pieces, { Vector3.new(1.4, 0.4, 1.4), Vector3.new(0, 2.45, 0) })
			table.insert(pieces, { Vector3.new(1.1, 0.12, 0.7), Vector3.new(0, 2.3, -0.95) })
		elseif hat.kind == "hair" then
			table.insert(pieces, { Vector3.new(1.42, 0.45, 1.42), Vector3.new(0, 2.42, 0.02) })
			table.insert(pieces, { Vector3.new(1.42, 1.1, 0.35), Vector3.new(0, 1.85, 0.62) })
		end
		for i, pc in ipairs(pieces) do
			local p = part("Hat" .. i, pc[1], pc[2], hat.color)
			-- Position relative a la tete (lue par YeetClient pour suivre l'animation).
			p:SetAttribute("HeadOffset", pc[2] - Vector3.new(0, 1.65, 0))
		end
	end

	model:SetAttribute("Skin", skin and skin.key or "")
	model.PrimaryPart = torso
	return model
end

return YeetShared
