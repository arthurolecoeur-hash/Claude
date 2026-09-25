--[[
	PirateBuildMain
	---------------
	Nouveaux modeles pirates (style blocs de la map). Depuis la Command Bar :

	Modeles exposes sur une plateforme au-dessus de la Pirate Map
	(Workspace > ModelesPirate) :

		local f = game.ServerStorage.PirateBuild_Generateurs:Clone() f.Parent = game.ServerStorage print(require(f.PirateBuildMain).kit()) f:Destroy()

	Ajout dans la Pirate Map (Pirate Map > DecoPirate, remplace a chaque
	lancement, ne touche pas PirateDecor / PirateHeroes) :

		local f = game.ServerStorage.PirateBuild_Generateurs:Clone() f.Parent = game.ServerStorage print(require(f.PirateBuildMain).run()) f:Destroy()
]]

local G = script.Parent
local L = require(G.PirateBuildLib)
local P = require(G.PirateProps)
local C = L.C
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local CX, CZ = 863, -2348
local STRIPS = { { 793, 816 }, { 910, 933 } }
local Z0, Z1 = -2182, -2514

local LOOKS = {
	{ capitaine = true, hook = true, sword = true },
	{ shirt = C.shirtW, pants = C.navy, bandana = C.bandana },
	{ shirt = C.shirtW, pants = C.woodD, bandana = C.navy, pegLeg = true, beard = C.dark },
	{ shirt = C.shirtW, pants = C.dark, bandana = C.parrotY, beard = false, pose = "salut", sword = true },
	{ shirt = C.shirtW, pants = C.navy, bandana = C.emerald, beard = C.orange, hook = true },
}

local M = {}

local function count(root)
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end

function M.kit()
	local old = workspace:FindFirstChild("ModelesPirate")
	if old then old:Destroy() end
	local root = Instance.new("Folder"); root.Name = "ModelesPirate"; root.Parent = workspace
	local rng = Random.new(7)
	local origin = CF(CX, 300, CZ)

	local items = {}
	for _, look in LOOKS do
		table.insert(items, { 6, function(cf) return P.pirate(root, cf, rng, look) end })
	end
	table.insert(items, { 4, function(cf) return P.parrot(root, cf, rng) end })
	table.insert(items, { 4, function(cf) return P.parrot(root, cf, rng, { C.emerald, C.parrotY, C.parrotR }) end })
	table.insert(items, { 9, function(cf) return P.treasure(root, cf, rng, 1) end })
	table.insert(items, { 7, function(cf) return P.wanted(root, cf, rng, "WANTED") end })
	table.insert(items, { 5, function(cf) return P.cannonballs(root, cf, rng) end })
	table.insert(items, { 5, function(cf) return P.lantern(root, cf, rng) end })
	table.insert(items, { 8, function(cf) return P.mapTable(root, cf, rng) end })
	table.insert(items, { 7, function(cf) return P.cage(root, cf, rng) end })
	table.insert(items, { 12, function(cf) return P.mast(root, cf, rng) end })
	table.insert(items, { 14, function(cf) return P.kraken(root, cf, rng, 5) end })
	table.insert(items, { 16, function(cf) return P.wreck(root, cf, rng) end })
	table.insert(items, { 11, function(cf) return P.dock(root, cf * CF(0, 0, 8), rng, 16) end })
	table.insert(items, { 15, function(cf) return P.sloop(root, cf, rng) end })
	table.insert(items, { 15, function(cf) return P.sign(root, cf, rng, "PIRATES") end })

	local total = 0
	for _, it in items do total += it[1] end
	L.part(root, "Plateforme", V(total + 20, 2, 40), origin * CF(0, -1, 0), C.sand)
	L.part(root, "PlateformeBord", V(total + 21, 0.4, 41), origin * CF(0, -0.3, 0), C.woodD)
	local x = -total / 2
	for _, it in items do
		x += it[1] / 2
		it[2](origin * CF(x, 0, 0))
		x += it[1] / 2
	end
	return ("ModelesPirate : %d pieces (au-dessus de la Pirate Map, Y=300)"):format(count(root))
end

function M.run()
	local map = workspace.Build.Maps["Pirate Map"]
	local old = map:FindFirstChild("DecoPirate")
	if old then old:Destroy() end
	local root = Instance.new("Folder"); root.Name = "DecoPirate"; root.Parent = map
	local rng = Random.new(20260925)

	local blockers = { root }
	for _, name in { "PirateDecor", "PirateHeroes" } do
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

	local function place(build, positions)
		for _, cf in positions do
			local m = build(cf)
			if not overlaps(m) then return m end
			m:Destroy()
		end
		return nil
	end

	local function face(side) return side == 1 and rad(-90) or rad(90) end

	local function stripPos(side, z, margin)
		local s = STRIPS[side]
		margin = margin or 3
		local list = {}
		for k = 0, 5 do
			local x = rng:NextNumber(s[1] + margin, s[2] - margin)
			table.insert(list, CF(x, 0, z - k * 4 * (z > CZ and -1 or 1)) * ANG(0, face(side) + rng:NextNumber(-0.4, 0.4), 0))
		end
		return list
	end

	-- Entrees : enseignes, lanternes
	place(function(cf) return P.sign(root, cf, rng, "PIRATES") end, { CF(806, 0, Z0 - 6) * ANG(0, rad(-30), 0), CF(806, 0, Z0 - 14) * ANG(0, rad(-30), 0) })
	place(function(cf) return P.sign(root, cf, rng, "PIRATES") end, { CF(920, 0, Z1 + 6) * ANG(0, rad(150), 0), CF(920, 0, Z1 + 14) * ANG(0, rad(150), 0) })

	-- Zones libres des deux bouts de la map
	place(function(cf) return P.sloop(root, cf, rng) end, { CF(805, 0, -2480), CF(805, 0, -2460), CF(805, 0, -2250) })
	place(function(cf) return P.wreck(root, cf, rng) end, { CF(921, 0, -2250) * ANG(0, rad(30), 0), CF(921, 0, -2470) * ANG(0, rad(30), 0) })
	place(function(cf) return P.kraken(root, cf, rng, 5) end, { CF(921, 0, -2480), CF(921, 0, -2455), CF(805, 0, -2215) })
	place(function(cf) return P.mast(root, cf, rng) end, { CF(804, 0, -2225) * ANG(0, face(1), 0), CF(804, 0, -2440) * ANG(0, face(1), 0) })
	place(function(cf) return P.mast(root, cf, rng) end, { CF(922, 0, -2445) * ANG(0, face(2), 0), CF(922, 0, -2215) * ANG(0, face(2), 0) })
	place(function(cf) return P.dock(root, cf, rng, 14) end, { CF(805, 0, -2262) * ANG(0, rad(90), 0), CF(805, 0, -2505) * ANG(0, rad(90), 0) })
	place(function(cf) return P.mapTable(root, cf, rng) end, stripPos(2, -2272))
	place(function(cf) return P.cage(root, cf, rng) end, stripPos(1, -2500))
	place(function(cf) return P.treasure(root, cf, rng, 1) end, stripPos(2, -2500))
	place(function(cf) return P.treasure(root, cf, rng, 0.8) end, stripPos(1, -2200))
	place(function(cf) return P.wanted(root, cf, rng, "WANTED") end, stripPos(2, -2195, 4))
	place(function(cf) return P.wanted(root, cf, rng, "WANTED") end, stripPos(1, -2440, 4))

	-- Equipage et perroquets repartis sur toute la longueur
	for i, z in { -2230, -2290, -2360, -2420, -2490 } do
		local side = i % 2 + 1
		place(function(cf) return P.pirate(root, cf, rng, LOOKS[i]) end, stripPos(side, z))
	end
	for i, z in { -2205, -2330, -2465 } do
		place(function(cf) return P.parrot(root, cf, rng) end, stripPos((i % 2) + 1, z))
	end
	for _, z in { -2240, -2400, -2505 } do
		place(function(cf) return P.cannonballs(root, cf, rng) end, stripPos(z == -2400 and 1 or 2, z))
	end

	-- Lanternes le long de l'allee
	for z = Z0 - 12, Z1 + 12, -26 do
		place(function(cf) return P.lantern(root, cf, rng) end, { CF(819, 0, z) * ANG(0, face(1), 0), CF(819, 0, z - 5) * ANG(0, face(1), 0) })
		place(function(cf) return P.lantern(root, cf, rng) end, { CF(907, 0, z) * ANG(0, face(2), 0), CF(907, 0, z - 5) * ANG(0, face(2), 0) })
	end

	return ("DecoPirate : %d pieces"):format(count(root))
end

return M
