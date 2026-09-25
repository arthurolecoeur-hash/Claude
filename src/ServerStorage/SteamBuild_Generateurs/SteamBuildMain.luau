--[[
	SteamBuildMain
	--------------
	Nouveaux modeles steampunk. Depuis la Command Bar :

	Plateforme d'exposition (Workspace > ModelesSteampunk) :
		local f = game.ServerStorage.SteamBuild_Generateurs:Clone() f.Parent = game.ServerStorage print(require(f.SteamBuildMain).kit()) f:Destroy()

	Ajout dans la Steampunk Map (Steampunk Map > DecoSteampunk, remplace a
	chaque lancement, ne touche pas SteamDecor / SteamHeroes) :
		local f = game.ServerStorage.SteamBuild_Generateurs:Clone() f.Parent = game.ServerStorage print(require(f.SteamBuildMain).run()) f:Destroy()
]]

local G = script.Parent
local L = require(G.SteamBuildLib)
local P = require(G.SteamProps)
local C = L.C
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local CX, CZ = 863, -3722
local STRIPS = { { 793, 816 }, { 910, 933 } }

local M = {}

local function count(root)
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end

local function items(root, rng)
	return {
		{ 7, function(cf) return P.automaton(root, cf, rng, {}) end },
		{ 7, function(cf) return P.automaton(root, cf, rng, { body = C.brass, trim = C.copper, eye = C.glowC, hat = true }) end },
		{ 7, function(cf) return P.automaton(root, cf, rng, { body = C.iron, trim = C.brass, eye = C.glowR, tool = "cle" }) end },
		{ 12, function(cf) return P.balloon(root, cf, rng) end },
		{ 11, function(cf) return P.pipeOrgan(root, cf, rng) end },
		{ 8, function(cf) return P.gearTower(root, cf, rng) end },
		{ 6, function(cf) return P.telescope(root, cf, rng) end },
		{ 9, function(cf) return P.steamCar(root, cf, rng) end },
		{ 9, function(cf) return P.pressureTank(root, cf, rng) end },
		{ 10, function(cf) return P.crane(root, cf, rng) end },
		{ 4, function(cf) return P.owl(root, cf, rng) end },
		{ 11, function(cf) return P.waterTower(root, cf, rng) end },
		{ 6, function(cf) return P.fancyLamp(root, cf, rng) end },
		{ 6, function(cf) return P.bench(root, cf, rng) end },
		{ 5, function(cf) return P.signpost(root, cf, rng) end },
		{ 9, function(cf) return P.inventorDesk(root, cf, rng) end },
		{ 13, function(cf) return P.mechSpider(root, cf, rng) end },
	}
end

function M.kit()
	local old = workspace:FindFirstChild("ModelesSteampunk")
	if old then old:Destroy() end
	local root = Instance.new("Folder"); root.Name = "ModelesSteampunk"; root.Parent = workspace
	local rng = Random.new(3)
	local origin = CF(CX, 300, CZ)
	local list = items(root, rng)
	local total = 0
	for _, it in list do total += it[1] end
	L.part(root, "Plateforme", V(total + 20, 2, 40), origin * CF(0, -1, 0), C.ironD)
	L.part(root, "PlateformeBord", V(total + 21, 0.4, 41), origin * CF(0, -0.3, 0), C.brass)
	local x = -total / 2
	for _, it in list do
		x += it[1] / 2
		it[2](origin * CF(x, 0, 0))
		x += it[1] / 2
	end
	return ("ModelesSteampunk : %d pieces (au-dessus de la Steampunk Map, Y=300)"):format(count(root))
end

function M.run()
	local map = workspace.Build.Maps["Steampunk Map"]
	local old = map:FindFirstChild("DecoSteampunk")
	if old then old:Destroy() end
	local root = Instance.new("Folder"); root.Name = "DecoSteampunk"; root.Parent = map
	local rng = Random.new(20260925)

	local blockers = { root }
	for _, name in { "SteamDecor", "SteamHeroes" } do
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
	local function stripPos(side, z)
		local s = STRIPS[side]
		local list = {}
		for k = 0, 7 do
			local x = rng:NextNumber(s[1] + 4, s[2] - 4)
			table.insert(list, CF(x, 0, z + (k % 2 == 0 and 1 or -1) * k * 4) * ANG(0, face(side) + rng:NextNumber(-0.3, 0.3), 0))
		end
		return list
	end

	local list = items(root, rng)
	local zs = { -3560, -3600, -3640, -3690, -3740, -3790, -3830, -3870, -3905 }
	local i = 0
	for _, it in list do
		i += 1
		local side = i % 2 + 1
		local z = zs[(i - 1) % #zs + 1] + (i > #zs and 15 or 0)
		place(it[2], stripPos(side, z))
	end
	for z = -3550, -3910, -30 do
		place(function(cf) return P.fancyLamp(root, cf, rng) end, { CF(819, 0, z) * ANG(0, face(1), 0), CF(819, 0, z - 6) * ANG(0, face(1), 0) })
		place(function(cf) return P.fancyLamp(root, cf, rng) end, { CF(907, 0, z - 15) * ANG(0, face(2), 0), CF(907, 0, z - 21) * ANG(0, face(2), 0) })
	end
	return ("DecoSteampunk : %d pieces"):format(count(root))
end

return M
