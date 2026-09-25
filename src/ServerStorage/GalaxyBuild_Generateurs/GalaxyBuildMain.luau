--[[
	GalaxyBuildMain
	---------------
	Decor "galaxie" de la Cosmos Map. A lancer une fois depuis la Command Bar
	de Studio (en mode edition) :

		local f = game.ServerStorage.GalaxyBuild_Generateurs:Clone() f.Parent = game.ServerStorage print(require(f.GalaxyBuildMain).run()) f:Destroy()

	Modeles seuls, exposes sur une plateforme (Workspace > ModelesGalaxie) :

		local f = game.ServerStorage.GalaxyBuild_Generateurs:Clone() f.Parent = game.ServerStorage print(require(f.GalaxyBuildMain).kit()) f:Destroy()

	Tout est range dans Cosmos Map > DecoGalaxy (remplace a chaque lancement).
	Le decor existant (CosmosDecor, CosmosHeroes) n'est pas modifie : les
	objets au sol qui le chevaucheraient sont deplaces ou abandonnes.
]]

local G = script.Parent
local L = require(G.GalaxyBuildLib)
local P = require(G.GalaxyProps)
local C = L.C
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local STRIPS = { { 793, 816 }, { 910, 933 } }
local Z0, Z1 = -1600, -1906
local CX = 863

local M = {}

function M.run()
	local map = workspace.Build.Maps["Cosmos Map"]
	local old = map:FindFirstChild("DecoGalaxy")
	if old then old:Destroy() end
	local root = Instance.new("Folder"); root.Name = "DecoGalaxy"; root.Parent = map
	local sky = Instance.new("Folder"); sky.Name = "Ciel"; sky.Parent = root
	local ground = Instance.new("Folder"); ground.Name = "Sol"; ground.Parent = root
	local floating = Instance.new("Folder"); floating.Name = "Flottant"; floating.Parent = root
	local details = Instance.new("Folder"); details.Name = "Details"; details.Parent = root
	local rng = Random.new(20260925)

	local blockers = { root }
	for _, name in { "CosmosDecor", "CosmosHeroes" } do
		local f = map:FindFirstChild(name)
		if f then table.insert(blockers, f) end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = blockers

	local function overlaps(model)
		local ok, hits = pcall(function()
			local cf, size = model:GetBoundingBox()
			return workspace:GetPartBoundsInBox(cf, size + V(1, 0, 1), params)
		end)
		if not ok then return false end
		for _, h in hits do
			if not h:IsDescendantOf(model) then return true end
		end
		return false
	end

	-- Construit, et reessaie ailleurs si ca chevauche le decor existant.
	local function place(build, positions)
		for _, cf in positions do
			local m = build(cf)
			if not overlaps(m) then return m end
			m:Destroy()
		end
		return nil
	end

	local function stripPos(side, z)
		local s = STRIPS[side]
		local list = {}
		for _ = 1, 5 do
			local x = rng:NextNumber(s[1] + 3, s[2] - 3)
			table.insert(list, CF(x, 0, z + rng:NextNumber(-3, 3)) * ANG(0, rng:NextNumber(0, math.pi * 2), 0))
		end
		return list
	end

	local function face(side) return side == 1 and rad(-90) or rad(90) end

	--== Portails aux deux entrees ==--
	P.portal(root, CF(CX, 0, Z0 + 2), rng, 126, 34, "COSMOS")
	P.portal(root, CF(CX, 0, Z1 - 2) * ANG(0, math.pi, 0), rng, 126, 34, "COSMOS")

	--== Grands elements au sol ==--
	place(function(cf) return P.observatory(ground, cf, rng) end, {
		CF(804, 0, -1872) * ANG(0, face(1), 0), CF(804, 0, -1850) * ANG(0, face(1), 0), CF(804, 0, -1640) * ANG(0, face(1), 0),
	})
	place(function(cf) return P.observatory(ground, cf, rng) end, {
		CF(922, 0, -1634) * ANG(0, face(2), 0), CF(922, 0, -1660) * ANG(0, face(2), 0), CF(922, 0, -1880) * ANG(0, face(2), 0),
	})
	place(function(cf) return P.rover(ground, cf, rng) end, {
		CF(806, 0, -1655) * ANG(0, rad(20), 0), CF(806, 0, -1830) * ANG(0, rad(160), 0), CF(806, 0, -1675),
	})
	place(function(cf) return P.rover(ground, cf, rng) end, {
		CF(920, 0, -1845) * ANG(0, rad(-30), 0), CF(920, 0, -1665) * ANG(0, rad(200), 0), CF(920, 0, -1830),
	})
	for _, z in { -1620, -1890 } do
		for side = 1, 2 do
			place(function(cf) return P.crystal(ground, cf, rng, nil, 1.6) end, stripPos(side, z))
		end
	end
	place(function(cf) return P.holoSign(ground, cf, rng, "ZONE GALAXIE", C.cyan) end, {
		CF(814, 0, -1612) * ANG(0, face(1), 0), CF(814, 0, -1625) * ANG(0, face(1), 0),
	})
	place(function(cf) return P.holoSign(ground, cf, rng, "ATTENTION ALIENS", C.pink) end, {
		CF(912, 0, -1895) * ANG(0, face(2), 0), CF(912, 0, -1880) * ANG(0, face(2), 0),
	})
	for side = 1, 2 do
		place(function(cf) return P.flag(ground, cf, rng, side == 1 and C.purple or C.cyan) end, stripPos(side, side == 1 and -1690 or -1815))
		place(function(cf) return P.nest(ground, cf, rng, side == 1 and C.green or C.pink) end, stripPos(side, side == 1 and -1830 or -1685))
	end

	--== Personnages et engins ==--
	local alienLooks = {
		{ eyes = 2 },
		{ skin = Color3.fromRGB(160, 220, 255), suit = C.pink, eyes = 3, gear = "pistolet", tip = C.yellow },
		{ skin = Color3.fromRGB(255, 190, 240), suit = C.teal, eyes = 1, gear = "casque", trim = C.yellow },
		{ skin = Color3.fromRGB(200, 170, 255), suit = C.red, eyes = 2, gear = "cape", pose = "salut", tip = C.cyan },
	}
	for i, z in { -1612, -1700, -1790, -1880 } do
		local side = i % 2 + 1
		place(function(cf) return P.alien(ground, cf, rng, alienLooks[i]) end, stripPos(side, z))
	end
	for i, z in { -1650, -1760, -1860 } do
		local side = (i + 1) % 2 + 1
		place(function(cf) return P.cybernaut(ground, cf, rng, i == 2 and C.pink or C.cyan, i == 2 and "salut" or nil) end, stripPos(side, z))
	end
	place(function(cf) return P.rocket(ground, cf, rng, C.purple, 26) end, { CF(805, 0, -1895), CF(805, 0, -1885), CF(805, 0, -1615) })
	place(function(cf) return P.rocket(ground, cf, rng, C.red, 22) end, { CF(921, 0, -1612), CF(921, 0, -1622), CF(921, 0, -1895) })
	place(function(cf) return P.dish(ground, cf, rng, 0.8) end, { CF(806, 0, -1665) * ANG(0, rad(40), 0), CF(806, 0, -1845) * ANG(0, rad(140), 0) })
	place(function(cf) return P.dish(ground, cf, rng, 0.8) end, { CF(920, 0, -1850) * ANG(0, rad(-40), 0), CF(920, 0, -1672) * ANG(0, rad(-140), 0) })

	--== Remplissage des bandes laterales ==--
	local fillers = {
		{ 3, function(cf) return P.alienPlant(ground, cf, rng) end },
		{ 3, function(cf) return P.shrooms(ground, cf, rng) end },
		{ 3, function(cf) return P.boulder(ground, cf, rng, rng:NextNumber(2, 4)) end },
		{ 2, function(cf) return P.crystal(ground, cf, rng, nil, rng:NextNumber(0.7, 1.1)) end },
	}
	local totalW = 0
	for _, f in fillers do totalW += f[1] end
	local function randomFiller()
		local r = rng:NextNumber(0, totalW)
		for _, f in fillers do
			r -= f[1]
			if r <= 0 then return f[2] end
		end
		return fillers[1][2]
	end
	for z = Z0 - 8, Z1 + 8, -8 do
		for side = 1, 2 do
			if rng:NextNumber() < 0.8 then
				place(randomFiller(), stripPos(side, z))
			end
		end
	end

	--== Lampadaires le long de l'allee ==--
	for z = Z0 - 14, Z1 + 14, -28 do
		place(function(cf) return P.lamp(ground, cf, rng, C.cyan) end, { CF(819, 0, z) * ANG(0, face(1), 0), CF(819, 0, z - 4) * ANG(0, face(1), 0) })
		place(function(cf) return P.lamp(ground, cf, rng, C.purple) end, { CF(907, 0, z) * ANG(0, face(2), 0), CF(907, 0, z - 4) * ANG(0, face(2), 0) })
	end

	--== Details au sol ==--
	for z = Z0 - 4, Z1 + 4, -6 do
		for side = 1, 2 do
			local s = STRIPS[side]
			if rng:NextNumber() < 0.5 then
				P.dust(details, CF(rng:NextNumber(s[1] + 2, s[2] - 2), 0, z), rng)
			end
			if rng:NextNumber() < 0.35 then
				P.floorCrack(details, CF(rng:NextNumber(s[1] + 2, s[2] - 2), 0, z) * ANG(0, rng:NextNumber(0, 6.28), 0), rng, L.GLOWS[rng:NextInteger(1, #L.GLOWS)])
			end
		end
		if rng:NextNumber() < 0.25 then
			P.floorCrack(details, CF(rng:NextNumber(822, 904), 0, z) * ANG(0, rng:NextNumber(0, 6.28), 0), rng, C.purple)
		end
	end

	--== Objets flottants ==--
	for _, cf in {
		CF(805, 40, -1640) * ANG(0.3, 0.8, 0.2), CF(921, 44, -1862) * ANG(-0.2, 2.4, 0.3), CF(812, 46, -1885) * ANG(0.1, -1.2, -0.3), CF(916, 38, -1625) * ANG(0, 0.4, 0.4),
	} do
		place(function(c) return P.satellite(floating, c, rng) end, { cf, cf * CF(0, 6, 0), cf * CF(0, -6, 0) })
	end
	place(function(cf) return P.wormhole(floating, cf, rng, 12) end, { CF(CX, 78, -1625), CF(CX, 90, -1625) })

	for _ = 1, 60 do
		local side = rng:NextNumber() < 0.5 and { 770, 792 } or { 934, 956 }
		local high = rng:NextNumber() < 0.3
		local x = high and rng:NextNumber(800, 926) or rng:NextNumber(side[1], side[2])
		local y = high and rng:NextNumber(95, 130) or rng:NextNumber(60, 82)
		local z = rng:NextNumber(Z1 + 5, Z0 - 5)
		place(function(cf) return P.asteroid(floating, cf, rng, rng:NextNumber(2, high and 7 or 5)) end, { CF(x, y, z), CF(x, y + 8, z) })
	end

	--== Ciel ==--
	P.planet(sky, CF(700, 110, -1660), rng, { d = 50, color = C.orange, ringColor = C.gold, bands = 5 })
	P.planet(sky, CF(688, 150, -1855), rng, { d = 34, color = C.teal, ring = false, bands = 3, moons = 2 })
	P.planet(sky, CF(1030, 120, -1800), rng, { d = 60, color = C.purple, color2 = C.pink, ringColor = C.cyan, bands = 6 })
	P.planet(sky, CF(1022, 96, -1638), rng, { d = 28, color = C.red, ring = false, bands = 4, moons = 1 })
	P.planet(sky, CF(860, 230, -1880), rng, { d = 40, color = C.blue, ringColor = C.white, bands = 4 })
	P.moon(sky, CF(758, 175, -1760), rng, 22)
	P.blackHole(sky, CF(CX, 190, -1745), rng, 26)
	P.galaxy(sky, CF(1085, 150, -1740) * ANG(0, 0, rad(90)) * ANG(0, 0.5, 0), rng, 80)
	P.galaxy(sky, CF(645, 170, -1720) * ANG(0, 0, rad(-90)) * ANG(0, -0.8, 0), rng, 50, { C.pink, C.yellow, C.white })
	P.nebula(sky, CF(CX, 140, -1640), rng, 30, { C.purple, C.pink, C.magenta })
	P.nebula(sky, CF(CX, 150, -1870), rng, 28, { C.blue, C.cyan, C.teal })
	P.nebula(sky, CF(1000, 210, -1700), rng, 42, { C.purple, C.blue, C.pink })
	for _, c in {
		{ V(720, 200, -1620), V(1, -0.3, -0.6) },
		{ V(1000, 170, -1900), V(-1, -0.25, 0.4) },
		{ V(900, 240, -1700), V(-0.6, -0.4, -1) },
	} do
		P.comet(sky, CFrame.lookAt(c[1], c[1] + c[2]), rng, 50)
	end
	for _ = 1, 90 do
		local x = rng:NextNumber(650, 1080)
		local y = rng:NextNumber(70, 240)
		if not (x > 780 and x < 946 and y < 100) then
			P.star(sky, CF(x, y, rng:NextNumber(Z1, Z0)), rng)
		end
	end

	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then n += 1 end
	end
	return ("DecoGalaxy : %d pieces"):format(n)
end

-- Expose chaque modele sur une plateforme au-dessus de la Cosmos Map, pour
-- les copier/deplacer a la main. Tout est dans Workspace > ModelesGalaxie.
function M.kit()
	local old = workspace:FindFirstChild("ModelesGalaxie")
	if old then old:Destroy() end
	local root = Instance.new("Folder"); root.Name = "ModelesGalaxie"; root.Parent = workspace
	local rng = Random.new(42)
	local origin = CF(CX, 300, -1753)
	L.part(root, "Plateforme", V(170, 2, 70), origin * CF(0, -1, 0), C.dark)
	L.part(root, "PlateformeNeon", V(171, 0.4, 71), origin * CF(0, -0.3, 0), C.purple, L.glow())

	local items = {
		{ 6, function(cf) return P.alien(root, cf, rng, { eyes = 2 }) end },
		{ 6, function(cf) return P.alien(root, cf, rng, { skin = Color3.fromRGB(160, 220, 255), suit = C.pink, eyes = 3, gear = "pistolet", tip = C.yellow }) end },
		{ 6, function(cf) return P.alien(root, cf, rng, { skin = Color3.fromRGB(255, 190, 240), suit = C.teal, eyes = 1, gear = "casque", trim = C.yellow }) end },
		{ 6, function(cf) return P.alien(root, cf, rng, { skin = Color3.fromRGB(200, 170, 255), suit = C.red, eyes = 2, gear = "cape", pose = "salut", tip = C.cyan }) end },
		{ 6, function(cf) return P.alien(root, cf, rng, { skin = Color3.fromRGB(255, 230, 120), suit = C.blue, eyes = 3, trim = C.pink }) end },
		{ 7, function(cf) return P.cybernaut(root, cf, rng, C.cyan) end },
		{ 7, function(cf) return P.cybernaut(root, cf, rng, C.pink, "salut") end },
		{ 7, function(cf) return P.cybernaut(root, cf, rng, C.green) end },
		{ 16, function(cf) return P.rocket(root, cf, rng, C.red, 30) end },
		{ 12, function(cf) return P.rocket(root, cf, rng, C.purple, 20) end },
		{ 14, function(cf) return P.dish(root, cf, rng, 1) end },
		{ 10, function(cf) return P.dish(root, cf, rng, 0.6) end },
		{ 9, function(cf) return P.rover(root, cf, rng) end },
	}
	local total = 0
	for _, it in items do total += it[1] end
	local x = -total / 2
	for _, it in items do
		x += it[1] / 2
		it[2](origin * CF(x, 0, 0))
		x += it[1] / 2
	end

	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then n += 1 end
	end
	return ("ModelesGalaxie : %d pieces (au-dessus de la Cosmos Map, Y=300)"):format(n)
end

return M
