local L = require(script.Parent.PirateBuildLib)
local C = L.C
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local TAU = math.pi * 2

local P = {}

local function pick(rng, t)
	return t[rng:NextInteger(1, #t)]
end

local SHINY = { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.25 }

--== PERSONNAGES ==--

-- o = { capitaine = bool, shirt, pants, bandana, pegLeg, hook, beard, sword, pose }
function P.pirate(parent, cf, rng, o)
	o = o or {}
	local m = L.model(o.capitaine and "Capitaine" or "Pirate", parent, cf)
	local shirt = o.shirt or C.shirtW
	local pants = o.pants or C.navy
	for _, s in { -1, 1 } do
		if o.pegLeg and s == 1 then
			L.part(m, "JambeBois", V(0.5, 2.2, 0.5), cf * CF(s * 0.7, 1.1, 0), C.woodL)
			L.part(m, "Cuisse", V(1.2, 1, 1.2), cf * CF(s * 0.7, 2.5, 0), pants)
		else
			L.part(m, "Botte", V(1.3, 1.1, 1.6), cf * CF(s * 0.7, 0.55, -0.15), C.black)
			L.part(m, "Revers", V(1.4, 0.3, 1.4), cf * CF(s * 0.7, 1.2, 0), C.dark)
			L.part(m, "BotteBoucle", V(0.5, 0.3, 0.1), cf * CF(s * 0.7, 0.7, -0.96), C.gold, SHINY)
			L.part(m, "Semelle", V(1.35, 0.2, 1.65), cf * CF(s * 0.7, 0.1, -0.15), C.woodD)
			L.part(m, "Jambe", V(1.2, 1.8, 1.2), cf * CF(s * 0.7, 2.1, 0), pants)
		end
	end
	L.part(m, "Ceinture", V(3.1, 0.5, 1.9), cf * CF(0, 3.2, 0), C.dark)
	L.part(m, "Boucle", V(0.7, 0.6, 0.1), cf * CF(0, 3.2, -0.97), C.gold, SHINY)
	L.part(m, "BoucleCentre", V(0.3, 0.25, 0.12), cf * CF(0, 3.2, -0.99), C.dark)
	L.part(m, "Echarpe", V(0.6, 1.2, 0.2), cf * CF(1.1, 2.6, -0.95) * ANG(0, 0, rad(-10)), o.capitaine and C.gold or C.red)
	L.part(m, "Pistolet", V(0.35, 0.5, 1.2), cf * CF(-1.2, 3.3, -0.9) * ANG(rad(-20), 0, 0), C.woodD)
	L.part(m, "PistoletCanon", V(0.25, 0.25, 0.9), cf * CF(-1.2, 3.1, -1.5) * ANG(rad(-20), 0, 0), C.iron)
	L.part(m, "Bourse", V(0.6, 0.7, 0.5), cf * CF(1.3, 3, 0.7), C.woodL)
	local torsoCol = o.capitaine and C.coat or shirt
	L.part(m, "Torse", V(3, 2.8, 1.8), cf * CF(0, 4.8, 0), torsoCol)
	if not o.capitaine then
		for i = 0, 2 do
			L.part(m, "Rayure", V(3.05, 0.35, 1.85), cf * CF(0, 3.9 + i * 0.9, 0), C.red)
		end
	else
		L.part(m, "Chemise", V(1, 2.6, 0.1), cf * CF(0, 4.9, -0.92), C.shirtW)
		L.part(m, "Jabot", V(0.8, 0.5, 0.2), cf * CF(0, 5.9, -1), C.shirtW)
		for i = 0, 2 do
			for _, s in { -1, 1 } do
				L.part(m, "Bouton", V(0.2, 0.2, 0.08), cf * CF(s * 0.85, 4.2 + i * 0.6, -0.93), C.gold, SHINY)
			end
		end
		for _, s in { -1, 1 } do
			L.part(m, "Revers", V(0.3, 2.6, 0.12), cf * CF(s * 0.65, 4.9, -0.93), C.gold)
			L.part(m, "Epaulette", V(1.1, 0.35, 1.9), cf * CF(s * 1.3, 6.3, 0), C.gold, SHINY)
		end
		L.part(m, "Pan", V(3, 1.4, 0.3), cf * CF(0, 3, 0.85), C.coat)
	end
	for _, s in { -1, 1 } do
		local armCol = o.capitaine and C.coat or shirt
		local up = o.pose == "salut" and s == -1
		if up then
			L.part(m, "Bras", V(0.9, 2.5, 0.9), cf * CF(s * 1.95, 7, 0) * ANG(0, 0, s * rad(-20)), armCol)
			L.part(m, "Main", V(0.8, 0.8, 0.8), cf * CF(s * 2.35, 8.4, 0), C.skin)
		else
			L.part(m, "Bras", V(0.9, 2.5, 0.9), cf * CF(s * 1.95, 5, 0), armCol)
			if o.hook and s == 1 then
				L.part(m, "Manche", V(0.5, 0.5, 0.5), cf * CF(s * 1.95, 3.5, 0), C.iron)
				L.part(m, "Crochet", V(0.2, 0.9, 0.2), cf * CF(s * 1.95, 2.9, 0), C.metalL, SHINY)
				L.part(m, "Crochet", V(0.2, 0.2, 0.6), cf * CF(s * 1.95, 2.5, -0.2), C.metalL, SHINY)
			else
				L.part(m, "Main", V(0.8, 0.8, 0.8), cf * CF(s * 1.95, 3.4, 0), C.skin)
			end
		end
	end
	if o.sword then
		local h = cf * CF(-1.95, 3.4, -0.6)
		L.part(m, "Garde", V(0.9, 0.2, 0.3), h, C.gold, SHINY)
		L.part(m, "Lame", V(0.2, 0.2, 3), h * CF(0, 0, -1.6), C.metalL, SHINY)
	end
	local head = cf * CF(0, 7.7, 0)
	L.part(m, "Tete", V(2.6, 2.6, 2.4), head, C.skin)
	L.part(m, "BlancOeil", V(0.7, 0.6, 0.1), head * CF(0.6, 0.2, -1.22), C.white)
	L.part(m, "Pupille", V(0.35, 0.4, 0.1), head * CF(0.5, 0.18, -1.26), C.black)
	L.part(m, "Sourcil", V(0.8, 0.2, 0.1), head * CF(0.6, 0.65, -1.24) * ANG(0, 0, rad(-12)), C.beard)
	L.part(m, "Bandeau", V(0.8, 0.7, 0.12), head * CF(-0.6, 0.2, -1.24), C.black)
	L.part(m, "Laniere", V(0.15, 0.15, 2.5), head * CF(-0.6, 0.62, 0) * ANG(0, 0, 0), C.black)
	L.part(m, "Laniere", V(2.62, 0.15, 0.15), head * CF(0, 0.62, 1.2), C.black)
	L.part(m, "Sourcil", V(0.8, 0.2, 0.1), head * CF(-0.6, 0.65, -1.25) * ANG(0, 0, rad(12)), C.beard)
	L.part(m, "Nez", V(0.45, 0.55, 0.35), head * CF(0, -0.15, -1.33), C.skinD)
	if o.beard ~= false then
		local bc = o.beard or C.beard
		L.part(m, "Barbe", V(2.6, 1.1, 0.4), head * CF(0, -0.95, -1.1), bc)
		L.part(m, "BarbePointe", V(1.2, 0.8, 0.4), head * CF(0, -1.8, -1.1), bc)
		L.part(m, "Moustache", V(1.8, 0.3, 0.2), head * CF(0, -0.45, -1.3), bc)
	else
		L.part(m, "Bouche", V(0.9, 0.15, 0.1), head * CF(0, -0.6, -1.22), C.dark)
	end
	if o.capitaine then
		L.part(m, "Chapeau", V(3.6, 0.4, 3.2), head * CF(0, 1.45, 0), C.black)
		L.part(m, "ChapeauHaut", V(2.6, 1.3, 2.4), head * CF(0, 2.2, 0), C.black)
		for _, s in { -1, 1 } do
			L.wedge(m, "Corne", V(0.4, 1, 1.8), head * CF(s * 1.7, 1.9, 0) * ANG(0, s * rad(90), 0), C.black)
		end
		L.part(m, "Galon", V(3.7, 0.15, 3.3), head * CF(0, 1.7, 0), C.gold, SHINY)
		L.part(m, "Plume", V(0.3, 2, 0.8), head * CF(1.2, 3, 0.6) * ANG(rad(-20), 0, rad(-25)), C.red)
		L.part(m, "PlumeBout", V(0.25, 0.8, 0.6), head * CF(1.7, 3.9, 0.9) * ANG(rad(-20), 0, rad(-40)), C.white)
		L.part(m, "Crane", V(0.8, 0.8, 0.1), head * CF(0, 2.2, -1.22), C.white)
		L.part(m, "CraneOs", V(1.2, 0.2, 0.1), head * CF(0, 1.75, -1.22) * ANG(0, 0, rad(30)), C.white)
	else
		local bcol = o.bandana or C.bandana
		L.part(m, "Bandana", V(2.7, 0.9, 2.5), head * CF(0, 1, 0), bcol)
		L.part(m, "Noeud", V(0.5, 0.5, 0.8), head * CF(0, 1, 1.5), bcol)
		L.part(m, "Pois", V(0.3, 0.3, 0.05), head * CF(0.6, 1.05, -1.26), C.white)
		L.part(m, "Pois", V(0.3, 0.3, 0.05), head * CF(-0.5, 0.9, -1.26), C.white)
		L.part(m, "Boucle", V(0.3, 0.4, 0.1), head * CF(1.35, -0.3, 0), C.gold, SHINY)
		L.part(m, "Oreille", V(0.2, 0.6, 0.4), head * CF(1.32, 0, 0.1), C.skinD)
	end
	return m
end

function P.parrot(parent, cf, rng, cols)
	cols = cols or { C.parrotR, C.parrotB, C.parrotY }
	local m = L.model("Perroquet", parent, cf)
	L.part(m, "Perchoir", V(0.3, 4, 0.3), cf * CF(0, 2, 0), C.woodD)
	L.part(m, "Barre", V(2.2, 0.3, 0.3), cf * CF(0, 4, 0), C.woodL)
	L.part(m, "Socle", V(1.6, 0.3, 1.6), cf * CF(0, 0.15, 0), C.woodD)
	local b = cf * CF(0, 4.9, 0)
	L.part(m, "Corps", V(1, 1.4, 1), b, cols[1])
	L.part(m, "Ventre", V(0.8, 0.9, 0.1), b * CF(0, -0.1, -0.52), cols[3])
	L.part(m, "Tete", V(0.9, 0.9, 0.9), b * CF(0, 1, -0.1), cols[1])
	L.part(m, "Joue", V(0.92, 0.4, 0.5), b * CF(0, 0.9, -0.2), C.white)
	L.part(m, "Bec", V(0.4, 0.4, 0.5), b * CF(0, 0.85, -0.7), C.dark)
	for _, s in { -1, 1 } do
		L.part(m, "Oeil", V(0.1, 0.2, 0.2), b * CF(s * 0.46, 1.1, -0.2), C.black)
		L.part(m, "Aile", V(0.2, 1.2, 0.9), b * CF(s * 0.6, -0.1, 0.1), cols[2])
		L.part(m, "Patte", V(0.2, 0.4, 0.2), b * CF(s * 0.25, -0.85, 0), C.parrotY)
	end
	L.part(m, "Queue", V(0.6, 0.2, 1.4), b * CF(0, -0.55, 0.75) * ANG(rad(-35), 0, 0), cols[2])
	L.part(m, "QueueBout", V(0.5, 0.2, 0.9), b * CF(0, -0.95, 1.4) * ANG(rad(-35), 0, 0), cols[3])
	L.part(m, "Crete", V(0.3, 0.5, 0.6), b * CF(0, 1.6, 0), cols[3])
	return m
end

--== TRESORS ==--

function P.treasure(parent, cf, rng, s)
	s = s or 1
	local m = L.model("TasDeTresor", parent, cf)
	L.part(m, "Tas", V(5, 0.8, 4) * s, cf * CF(0, 0.4 * s, 0), C.gold, SHINY)
	L.part(m, "Tas", V(3.6, 0.8, 2.8) * s, cf * CF(0.2 * s, 1.1 * s, 0.1 * s), C.gold, SHINY)
	L.part(m, "Tas", V(2, 0.7, 1.6) * s, cf * CF(-0.1 * s, 1.8 * s, 0), C.gold, SHINY)
	for _ = 1, 14 do
		local a = rng:NextNumber(0, TAU)
		local r = rng:NextNumber(2, 3.4) * s
		L.cyl(m, "Piece", 0.15 * s, 0.7 * s, cf * CF(math.cos(a) * r, 0.1 * s, math.sin(a) * r) * ANG(0, a, rad(90)), C.gold, SHINY)
	end
	for _ = 1, 3 do
		local x, z = rng:NextNumber(-1.8, 1.8) * s, rng:NextNumber(-1.2, 1.2) * s
		for k = 0, rng:NextInteger(2, 5) do
			L.cyl(m, "Pile", 0.15 * s, 0.7 * s, cf * CF(x, (0.9 + k * 0.16) * s, z) * ANG(0, 0, rad(90)), C.gold, SHINY)
		end
	end
	for _, g in { C.ruby, C.emerald, C.sapphire, C.ruby } do
		L.part(m, "Gemme", V(0.5, 0.5, 0.5) * s, cf * CF(rng:NextNumber(-1.8, 1.8) * s, rng:NextNumber(0.9, 2.2) * s, rng:NextNumber(-1.2, 1.2) * s) * ANG(0.6, 0.7, 0), g, L.glow())
	end
	local cup = cf * CF(1.2 * s, 2.1 * s, -0.4 * s)
	L.part(m, "CoupePied", V(0.6, 0.15, 0.6) * s, cup, C.goldD, SHINY)
	L.part(m, "CoupeTige", V(0.2, 0.6, 0.2) * s, cup * CF(0, 0.35 * s, 0), C.goldD, SHINY)
	L.part(m, "Coupe", V(0.8, 0.6, 0.8) * s, cup * CF(0, 0.9 * s, 0), C.goldD, SHINY)
	local crown = cf * CF(-1 * s, 2.3 * s, 0.2 * s)
	L.part(m, "Couronne", V(1.2, 0.5, 1.2) * s, crown, C.gold, SHINY)
	for i = 0, 3 do
		local a = i * math.pi / 2
		L.part(m, "Pointe", V(0.25, 0.4, 0.25) * s, crown * CF(math.cos(a) * 0.45 * s, 0.4 * s, math.sin(a) * 0.45 * s), C.gold, SHINY)
	end
	L.part(m, "Rubis", V(0.3, 0.3, 0.1) * s, crown * CF(0, 0, -0.62 * s), C.ruby, L.glow())
	local ch = cf * CF(0, 0, 2.6 * s)
	L.part(m, "Coffre", V(3.2, 1.8, 2) * s, ch * CF(0, 0.9 * s, 0), C.wood)
	L.part(m, "CoffreBande", V(0.3, 1.9, 2.1) * s, ch * CF(-1 * s, 0.9 * s, 0), C.goldD, SHINY)
	L.part(m, "CoffreBande", V(0.3, 1.9, 2.1) * s, ch * CF(1 * s, 0.9 * s, 0), C.goldD, SHINY)
	L.part(m, "CoffreCouvercle", V(3.2, 0.8, 2) * s, ch * CF(0, 2.3 * s, 0.9 * s) * ANG(rad(70), 0, 0), C.woodL)
	L.part(m, "CoffreOr", V(2.8, 0.4, 1.6) * s, ch * CF(0, 1.85 * s, 0), C.gold, SHINY)
	for i = 0, 7 do
		local a = i / 8 * TAU
		L.part(m, "Perle", V(0.25, 0.25, 0.25) * s, cf * CF(-1.6 * s + math.cos(a) * 0.6 * s, 1.25 * s, -0.8 * s + math.sin(a) * 0.6 * s), C.white, SHINY)
	end
	L.part(m, "Epee", V(0.2, 0.2, 3.2) * s, cf * CF(1.6 * s, 1.4 * s, 0) * ANG(rad(25), rad(30), 0), C.metalL, SHINY)
	L.part(m, "EpeeGarde", V(0.9, 0.2, 0.25) * s, cf * CF(1.6 * s, 1.4 * s, 0) * ANG(rad(25), rad(30), 0) * CF(0, 0, 1.3 * s), C.gold, SHINY)
	local glowP = L.anchor(m, "Eclat", cf * CF(0, 2 * s, 0))
	L.light(glowP, C.yellow, 12 * s, 1.2)
	L.sparkles(glowP, C.yellow, 4, 0.5 * s)
	return m
end

function P.wanted(parent, cf, rng, text)
	local m = L.model("AvisDeRecherche", parent, cf)
	for _, s in { -1, 1 } do
		L.part(m, "Poteau", V(0.6, 7, 0.6), cf * CF(s * 2.2, 3.5, 0), C.woodD)
	end
	L.part(m, "Planche", V(5.4, 4.2, 0.4), cf * CF(0, 4.6, 0), C.wood)
	local paper = L.part(m, "Affiche", V(3.4, 3.6, 0.1), cf * CF(0, 4.6, -0.25) * ANG(0, 0, rad(rng:NextNumber(-4, 4))), C.paper)
	L.label(paper, Enum.NormalId.Front, text or "WANTED", C.dark, Enum.Font.Fantasy)
	local pf = paper.CFrame
	L.part(m, "Portrait", V(1.6, 1.4, 0.05), pf * CF(0, -0.2, -0.06), C.skin:Lerp(C.paper, 0.4))
	L.part(m, "PortraitChapeau", V(2, 0.5, 0.05), pf * CF(0, 0.6, -0.08), C.black)
	L.part(m, "PortraitBandeau", V(0.4, 0.35, 0.05), pf * CF(-0.35, -0.1, -0.09), C.black)
	L.part(m, "PortraitBarbe", V(1.2, 0.4, 0.05), pf * CF(0, -0.75, -0.09), C.beard)
	L.part(m, "Prix", V(2.6, 0.35, 0.05), pf * CF(0, -1.4, -0.07), C.coat)
	for _, c in { { -1.5, 1.6 }, { 1.5, 1.6 }, { -1.5, -1.6 }, { 1.5, -1.6 } } do
		L.part(m, "Punaise", V(0.2, 0.2, 0.1), pf * CF(c[1], c[2], -0.08), C.iron)
	end
	local p2 = L.part(m, "Affiche2", V(1.4, 1.8, 0.08), cf * CF(-1.8, 5.8, -0.25) * ANG(0, 0, rad(8)), C.paper:Lerp(C.woodL, 0.3))
	L.part(m, "Coin", V(0.4, 0.4, 0.06), p2.CFrame * CF(0.5, -0.7, -0.03) * ANG(0, 0, rad(45)), C.paper:Lerp(C.woodD, 0.3))
	L.part(m, "Clou", V(0.2, 0.2, 0.2), cf * CF(0, 6.3, -0.35), C.iron)
	L.part(m, "Toit", V(6, 0.4, 1.4), cf * CF(0, 7.1, -0.2), C.woodD)
	return m
end

function P.cannonballs(parent, cf, rng)
	local m = L.model("Boulets", parent, cf)
	L.part(m, "Socle", V(3.6, 0.3, 3.6), cf * CF(0, 0.15, 0), C.woodD)
	local d = 0.9
	for layer = 0, 2 do
		local n = 3 - layer
		for i = 0, n - 1 do
			for j = 0, n - 1 do
				local x = (i - (n - 1) / 2) * d
				local z = (j - (n - 1) / 2) * d
				L.ball(m, "Boulet", d, cf * CF(x, 0.3 + d / 2 + layer * d * 0.75, z), C.ironD, { Material = Enum.Material.Metal, MaterialVariant = "" })
			end
		end
	end
	return m
end

--== DECOR ==--

function P.lantern(parent, cf, rng)
	local m = L.model("Lanterne", parent, cf)
	L.part(m, "Pied", V(1.4, 0.4, 1.4), cf * CF(0, 0.2, 0), C.woodD)
	L.part(m, "Mat", V(0.5, 8, 0.5), cf * CF(0, 4.2, 0), C.wood)
	L.part(m, "Bras", V(0.35, 0.35, 2), cf * CF(0, 8, -0.9), C.wood)
	L.part(m, "Chaine", V(0.12, 0.8, 0.12), cf * CF(0, 7.5, -1.7), C.iron)
	L.part(m, "Renfort", V(0.25, 1.4, 0.25), cf * CF(0, 7.4, -0.5) * ANG(rad(45), 0, 0), C.woodD)
	for k = 0, 2 do
		L.part(m, "CordeEnroulee", V(0.62, 0.15, 0.62), cf * CF(0, 1.6 + k * 0.2, 0), C.rope)
	end
	L.part(m, "Pancarte", V(1.4, 0.8, 0.1), cf * CF(0.5, 3, -0.3) * ANG(0, 0, rad(8)), C.woodL)
	local lamp = cf * CF(0, 6.5, -1.7)
	L.part(m, "Toit", V(1.2, 0.3, 1.2), lamp * CF(0, 0.75, 0), C.ironD)
	L.part(m, "Verre", V(0.9, 1.1, 0.9), lamp, C.orange, L.glow({ Transparency = 0.2 }))
	L.part(m, "Base", V(1.1, 0.2, 1.1), lamp * CF(0, -0.6, 0), C.ironD)
	for _, x in { -0.5, 0.5 } do
		for _, z in { -0.5, 0.5 } do
			L.part(m, "Montant", V(0.12, 1.2, 0.12), lamp * CF(x, 0, z), C.ironD)
		end
	end
	L.light(L.anchor(m, "Flamme", lamp), C.orange, 16, 1.6)
	return m
end

function P.dock(parent, cf, rng, len)
	len = len or 16
	local m = L.model("Ponton", parent, cf)
	local n = math.floor(len / 1.2)
	for i = 0, n - 1 do
		L.part(m, "Planche", V(5, 0.35, 1.1), cf * CF(0, 1.3 + rng:NextNumber(-0.05, 0.05), -i * 1.2) * ANG(0, rad(rng:NextNumber(-2, 2)), 0), (i % 3 == 0) and C.woodL or C.plank)
	end
	for i = 0, math.floor(n / 4) do
		for _, s in { -1, 1 } do
			local pc = cf * CF(s * 2.6, 0, -i * 4.8)
			L.part(m, "Pilier", V(0.8, 2.8, 0.8), pc * CF(0, 1.4, 0), C.woodD)
			L.part(m, "Corde", V(0.9, 0.25, 0.9), pc * CF(0, 1.9, 0), C.rope)
		end
	end
	for _, s in { -1, 1 } do
		L.part(m, "Rambarde", V(0.2, 0.2, len), cf * CF(s * 2.6, 2.6, -len / 2 + 0.6), C.rope)
	end
	local tip = cf * CF(0, 0, -len + 1.2)
	for _, sd in { -1, 1 } do
		L.part(m, "Bitte", V(0.8, 1, 0.8), tip * CF(sd * 1.8, 2, 0), C.ironD)
		L.part(m, "BitteHaut", V(1.1, 0.3, 1.1), tip * CF(sd * 1.8, 2.6, 0), C.ironD)
		L.part(m, "Amarre", V(1.2, 0.3, 1.2), tip * CF(sd * 1.8, 1.7, 0), C.rope)
	end
	for k = 0, 3 do
		L.part(m, "Echelle", V(1.4, 0.2, 0.2), tip * CF(0, 1 - k * 0.5, -0.8), C.woodD)
	end
	L.part(m, "Caisse", V(1.4, 1.4, 1.4), cf * CF(1.5, 2.2, -1.5), C.plank)
	L.part(m, "Tonneau", V(1.2, 1.6, 1.2), cf * CF(-1.6, 2.3, -2.2), C.wood)
	L.part(m, "TonneauCercle", V(1.3, 0.2, 1.3), cf * CF(-1.6, 2.6, -2.2), C.iron)
	local rod = cf * CF(2, 1.8, -len * 0.6)
	L.part(m, "Canne", V(0.12, 0.12, 5), rod * ANG(rad(25), rad(-30), 0) * CF(0, 0, -2), C.woodL)
	L.part(m, "Seau", V(0.9, 0.9, 0.9), cf * CF(1.6, 1.95, -len * 0.6 + 0.8), C.woodD)
	L.part(m, "Poisson", V(0.9, 0.35, 0.2), cf * CF(1.3, 1.6, -len * 0.4), C.metalL)
	local post = cf * CF(-2.6, 0, -len * 0.5)
	L.part(m, "PoteauLanterne", V(0.4, 4, 0.4), post * CF(0, 3.4, 0), C.woodD)
	local lan = L.part(m, "Lanterne", V(0.7, 0.9, 0.7), post * CF(0, 5.6, 0), C.orange, L.glow())
	L.light(lan, C.orange, 14, 1.2)
	L.part(m, "Eau", V(9, 0.3, len + 3), cf * CF(0, 0.2, -len / 2 + 0.6), C.water, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.35, CanCollide = false })
	return m
end

function P.wreck(parent, cf, rng)
	local m = L.model("Epave", parent, cf)
	L.part(m, "Sable", V(18, 0.4, 14), cf * CF(0, 0.2, 0), C.sand)
	local hull = cf * CF(0, 0, 0) * ANG(0, 0, rad(18))
	L.part(m, "Fond", V(6, 1, 11), hull * CF(0, 0.6, 0), C.woodD)
	for i = 0, 3 do
		local y = 1.4 + i * 0.9
		local col = (i % 2 == 0) and C.wood or C.woodD
		L.part(m, "BordGauche", V(0.5, 0.85, 11), hull * CF(-2.8, y, 0), col)
		L.part(m, "BordDroit", V(0.5, 0.85, 7 - i * 1.2), hull * CF(2.8, y, 2 + i * 0.6), col)
	end
	for i = 0, 2 do
		L.part(m, "Proue", V(4.6 - i * 1.5, 3.6, 1.2), hull * CF(0, 2.6, -6 - i * 1.1), (i % 2 == 0) and C.wood or C.woodD)
	end
	L.part(m, "Poupe", V(6, 4.6, 1), hull * CF(0, 3, 5.5), C.woodD)
	L.part(m, "PoupeFenetre", V(3, 1.2, 0.2), hull * CF(0, 3.6, 6.05), C.dark)
	for i = -1, 1 do
		L.part(m, "Couple", V(5.6, 0.45, 0.45), hull * CF(0, 4.2, i * 3), C.woodL)
	end
	L.part(m, "MatCasse", V(0.9, 6, 0.9), hull * CF(0, 4, -1) * ANG(rad(-25), 0, rad(-30)), C.woodL)
	L.part(m, "Voile", V(0.12, 2.6, 3.4), hull * CF(1.6, 5.4, -1.4) * ANG(rad(-25), 0, rad(-30)), C.sailD)
	for _ = 1, 5 do
		L.part(m, "Debris", V(rng:NextNumber(1.5, 3), 0.3, rng:NextNumber(0.5, 1)), cf * CF(rng:NextNumber(-8, 8), 0.55, rng:NextNumber(-6, 6)) * ANG(0, rng:NextNumber(0, TAU), 0), C.woodL)
	end
	L.part(m, "Tonneau", V(1.4, 1.8, 1.4), cf * CF(5.5, 1.3, -3), C.wood)
	L.part(m, "Cercle", V(1.5, 0.25, 1.5), cf * CF(5.5, 1.8, -3), C.iron)
	return m
end

function P.mapTable(parent, cf, rng)
	local m = L.model("TableDesCartes", parent, cf)
	L.part(m, "Plateau", V(6, 0.4, 4), cf * CF(0, 3, 0), C.wood)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -1.6, 1.6 } do
			L.part(m, "Pied", V(0.5, 2.8, 0.5), cf * CF(x, 1.4, z), C.woodD)
		end
	end
	local map = L.part(m, "Carte", V(4, 0.1, 2.8), cf * CF(0, 3.25, 0) * ANG(0, rad(5), 0), C.paper)
	L.part(m, "X", V(0.8, 0.12, 0.15), map.CFrame * CF(1, 0.02, 0.4) * ANG(0, rad(45), 0), C.red)
	L.part(m, "X", V(0.8, 0.12, 0.15), map.CFrame * CF(1, 0.02, 0.4) * ANG(0, rad(-45), 0), C.red)
	for i = 0, 4 do
		L.part(m, "Chemin", V(0.35, 0.12, 0.12), map.CFrame * CF(-1.4 + i * 0.5, 0.02, -0.6 + i * 0.22), C.dark)
	end
	L.part(m, "Rouleau", V(0.3, 0.3, 2.8), map.CFrame * CF(-2.1, 0.1, 0), C.paper)
	local candle = cf * CF(-2.2, 3.2, -1.3)
	L.part(m, "Bougeoir", V(0.6, 0.2, 0.6), candle, C.gold, SHINY)
	L.part(m, "Bougie", V(0.3, 0.9, 0.3), candle * CF(0, 0.55, 0), C.white)
	local flame = L.part(m, "Flamme", V(0.2, 0.35, 0.2), candle * CF(0, 1.15, 0), C.orange, L.glow())
	L.light(flame, C.orange, 12, 1.4)
	local comp = cf * CF(2.3, 3.25, -1.3)
	L.cyl(m, "Boussole", 0.2, 0.9, comp * ANG(0, 0, rad(90)), C.gold, SHINY)
	L.part(m, "Aiguille", V(0.1, 0.1, 0.6), comp * CF(0, 0.12, 0) * ANG(0, rad(30), 0), C.red)
	L.part(m, "Dague", V(0.12, 1.4, 0.3), cf * CF(-1, 3.8, 0.6) * ANG(0, 0, rad(10)), C.metalL, SHINY)
	L.part(m, "DagueGarde", V(0.6, 0.12, 0.2), cf * CF(-0.9, 4.4, 0.6) * ANG(0, 0, rad(10)), C.gold, SHINY)
	L.part(m, "DagueManche", V(0.2, 0.6, 0.2), cf * CF(-0.85, 4.8, 0.6) * ANG(0, 0, rad(10)), C.woodD)
	L.part(m, "Bouteille", V(0.5, 1, 0.5), cf * CF(2.4, 3.7, 1.2), C.emerald, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.25 })
	L.part(m, "Goulot", V(0.25, 0.4, 0.25), cf * CF(2.4, 4.4, 1.2), C.emerald, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.25 })
	L.part(m, "Encrier", V(0.4, 0.35, 0.4), cf * CF(1.6, 3.37, -1.4), C.black)
	L.part(m, "Plume", V(0.08, 1.1, 0.3), cf * CF(1.65, 3.9, -1.4) * ANG(0, 0, rad(-20)), C.white)
	for i = 0, 3 do
		L.part(m, "Piece", V(0.4, 0.1, 0.4), cf * CF(-0.6 + i * 0.35, 3.26 + (i % 2) * 0.1, 1.5), C.gold, SHINY)
	end
	L.part(m, "Tabouret", V(1.4, 0.3, 1.4), cf * CF(0, 1.8, 3), C.woodL)
	L.part(m, "TabouretPied", V(0.4, 1.7, 0.4), cf * CF(0, 0.85, 3), C.woodD)
	return m
end

function P.kraken(parent, cf, rng, n)
	n = n or 4
	local m = L.model("Kraken", parent, cf)
	L.part(m, "Flaque", V(14, 0.3, 14), cf * CF(0, 0.15, 0), C.water, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.3 })
	L.part(m, "Tete", V(4, 2.2, 4), cf * CF(0, 0.9, 0), C.kraken)
	for _, s in { -1, 1 } do
		L.part(m, "Oeil", V(1.1, 1.1, 0.2), cf * CF(s * 1, 1.3, -2.02), C.yellow, L.glow())
		L.part(m, "Pupille", V(0.25, 0.9, 0.22), cf * CF(s * 1, 1.3, -2.08), C.black)
	end
	for i = 1, n do
		local a = i / n * TAU + rng:NextNumber(-0.25, 0.25)
		local base = cf * CF(math.cos(a) * 4.2, 0, math.sin(a) * 4.2) * ANG(0, -a, 0)
		local segs = rng:NextInteger(7, 9)
		local p = base
		for k = 1, segs do
			local t = k / segs
			local w = 1.6 * (1 - t * 0.75)
			local bend = t < 0.5 and -4 or (t - 0.5) * 70
			p = p * CF(0, 1.35, 0) * ANG(0, 0, rad(bend))
			L.part(m, "Tentacule", V(w, 1.5, w), p, C.kraken)
			if k % 2 == 1 then
				L.part(m, "Ventouse", V(0.1, w * 0.55, w * 0.55), p * CF(w / 2 + 0.02, 0, 0), C.pink)
			end
		end
	end
	for _ = 1, 6 do
		L.part(m, "Eclaboussure", V(0.5, 0.5, 0.5), cf * CF(rng:NextNumber(-6, 6), rng:NextNumber(0.5, 2), rng:NextNumber(-6, 6)), C.white, { Transparency = 0.3, CanCollide = false })
	end
	return m
end

function P.mast(parent, cf, rng)
	local m = L.model("MatVoile", parent, cf)
	L.part(m, "Socle", V(3, 0.6, 3), cf * CF(0, 0.3, 0), C.woodD)
	L.part(m, "Mat", V(1, 20, 1), cf * CF(0, 10.5, 0), C.woodL)
	L.part(m, "Vergue", V(10, 0.6, 0.6), cf * CF(0, 16, 0), C.wood)
	L.part(m, "Vergue", V(8, 0.5, 0.5), cf * CF(0, 8, 0), C.wood)
	local sail = L.part(m, "Voile", V(9.4, 7.6, 0.25), cf * CF(0, 12, -0.5), C.sail)
	L.part(m, "Crane", V(2.4, 2.2, 0.1), sail.CFrame * CF(0, 0.6, -0.15), C.black)
	L.part(m, "Os", V(4, 0.5, 0.1), sail.CFrame * CF(0, -1, -0.15) * ANG(0, 0, rad(30)), C.black)
	L.part(m, "Os", V(4, 0.5, 0.1), sail.CFrame * CF(0, -1, -0.15) * ANG(0, 0, rad(-30)), C.black)
	for _, x in { -0.45, 0.45 } do
		L.part(m, "Orbite", V(0.5, 0.5, 0.1), sail.CFrame * CF(x, 0.8, -0.2), C.sail)
	end
	L.part(m, "Nid", V(3, 1.2, 3), cf * CF(0, 18.5, 0), C.wood)
	for h = 0, 7 do
		L.part(m, "Echelon", V(1.2, 0.2, 0.2), cf * CF(0, 1.5 + h * 2, 0.65), C.woodL)
	end
	L.part(m, "RouleauCorde", V(2, 0.5, 2), cf * CF(1.8, 0.85, 1.8), C.rope)
	L.part(m, "RouleauCordeHaut", V(1.3, 0.4, 1.3), cf * CF(1.8, 1.3, 1.8), C.rope:Lerp(C.woodD, 0.2))
	L.part(m, "Fanion", V(0.1, 0.6, 1.8), cf * CF(0, 22.6, 0.9), C.red)
	L.part(m, "LongueVue", V(0.3, 0.3, 1.4), cf * CF(1.1, 19.4, -1.3), C.gold, SHINY)
	L.part(m, "NidBord", V(3.2, 0.3, 3.2), cf * CF(0, 19.2, 0), C.woodD)
	L.part(m, "Drapeau", V(2.4, 1.6, 0.1), cf * CF(1.2, 21.5, 0), C.black)
	L.part(m, "DrapeauCrane", V(0.6, 0.6, 0.12), cf * CF(1.2, 21.6, 0), C.white)
	for _, s in { -1, 1 } do
		L.bar(m, "Hauban", (cf * CF(s * 5, 16, 0)).Position, (cf * CF(s * 4, 0.6, 2)).Position, 0.15, C.rope)
		L.bar(m, "Hauban", (cf * CF(s * 0.5, 18, 0)).Position, (cf * CF(s * 4, 0.6, -2)).Position, 0.15, C.rope)
		L.part(m, "Taquet", V(0.8, 0.8, 0.8), cf * CF(s * 4, 0.4, 2), C.iron)
		L.part(m, "Taquet", V(0.8, 0.8, 0.8), cf * CF(s * 4, 0.4, -2), C.iron)
	end
	return m
end

function P.cage(parent, cf, rng)
	local m = L.model("Cage", parent, cf)
	L.part(m, "Sol", V(5, 0.5, 5), cf * CF(0, 0.25, 0), C.woodD)
	L.part(m, "Toit", V(5.4, 0.5, 5.4), cf * CF(0, 6.25, 0), C.ironD)
	for i = 0, 5 do
		local t = -2.2 + i * 0.88
		for _, s in { -1, 1 } do
			L.part(m, "Barreau", V(0.25, 5.8, 0.25), cf * CF(t, 3.25, s * 2.3), C.iron)
			L.part(m, "Barreau", V(0.25, 5.8, 0.25), cf * CF(s * 2.3, 3.25, t), C.iron)
		end
	end
	L.part(m, "Anneau", V(0.3, 1.2, 1.2), cf * CF(0, 7.1, 0), C.iron)
	L.part(m, "Chaine", V(0.2, 2, 0.2), cf * CF(0, 8.6, 0), C.iron)
	L.part(m, "Potence", V(0.9, 11, 0.9), cf * CF(4, 5.5, 0), C.woodD)
	L.part(m, "PotenceBras", V(5, 0.8, 0.8), cf * CF(1.9, 10, 0), C.woodD)
	L.part(m, "PotenceRenfort", V(0.5, 3, 0.5), cf * CF(3.1, 8.6, 0) * ANG(0, 0, rad(45)), C.wood)
	L.part(m, "PotencePied", V(3, 0.5, 3), cf * CF(4, 0.25, 0), C.woodD)
	L.part(m, "Panneau", V(2, 1, 0.15), cf * CF(4, 4, -0.55), C.paper)
	L.part(m, "Bol", V(0.8, 0.3, 0.8), cf * CF(-1.5, 0.65, -1.2), C.woodL)
	L.part(m, "Cadenas", V(0.7, 0.8, 0.3), cf * CF(0.8, 3, -2.5), C.gold, SHINY)
	local sk = cf * CF(0, 0.5, 0.6)
	L.part(m, "Crane", V(1.1, 1, 1), sk * CF(0, 0.5, 0), C.white)
	for _, x in { -0.25, 0.25 } do
		L.part(m, "Orbite", V(0.3, 0.3, 0.05), sk * CF(x, 0.6, -0.5), C.black)
	end
	L.part(m, "Os", V(1.8, 0.25, 0.25), sk * CF(0, 0.15, -0.6) * ANG(0, rad(30), 0), C.white)
	L.part(m, "Os", V(1.8, 0.25, 0.25), sk * CF(0, 0.15, -0.6) * ANG(0, rad(-30), 0), C.white)
	return m
end

-- Navire pirate : coque galbee construite par tranches (plus large au
-- milieu, effilee a la proue, plus etroite vers la quille), 2 mats a voiles
-- gonflees, chateau arriere, beaupre et focs.
function P.sloop(parent, cf, rng, hullCol)
	hullCol = hullCol or C.wood
	local m = L.model("NavirePirate", parent, cf)
	local LEN, BEAM, H = 26, 7.2, 4.6
	local SL = 1.3
	local n = math.floor(LEN / SL)
	local function halfW(t)
		if t < 0.55 then
			return BEAM / 2 * math.sin(math.min(1, t / 0.55) * math.pi / 2) ^ 0.75
		end
		return BEAM / 2 * (1 - (t - 0.55) / 0.45 * 0.18)
	end
	local function sheer(t)
		return H + 1.3 * (1 - t) ^ 3 + 0.4 * t ^ 4
	end
	local function zOf(t) return -LEN / 2 + t * LEN end
	local waterDark = C.coat:Lerp(C.black, 0.5)
	-- eau + ecume
	L.part(m, "Eau", V(LEN + 12, 0.3, BEAM + 12), cf * CF(0, 0.15, 0), C.water, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.3, CanCollide = false })
	for i = 0, n - 1 do
		local t = (i + 0.5) / n
		local w = halfW(t)
		if w > 0.3 then
			local z = zOf(t)
			local top = sheer(t)
			local layers = math.ceil(top / 0.6)
			for k = 0, layers - 1 do
				local y0 = k * 0.6
				local f = 0.5 + 0.5 * math.min(1, (y0 / H)) ^ 0.45
				local width = math.max(0.4, 2 * w * f)
				local col
				if y0 < 1.2 then col = waterDark
				elseif y0 >= 2.9 and y0 < 3.4 then col = C.gold
				elseif y0 >= top - 0.6 then col = C.woodD
				else col = (k % 2 == 0) and hullCol or hullCol:Lerp(C.black, 0.15) end
				L.part(m, "Coque", V(width, 0.6, SL + 0.05), cf * CF(0, y0 + 0.3, z), col)
			end
			-- pont
			if t > 0.08 then
				L.part(m, "Pont", V(2 * w * 0.92, 0.2, SL), cf * CF(0, top + 0.1, z), C.plank)
				-- bastingage
				for _, sd in { -1, 1 } do
					L.part(m, "Bastingage", V(0.3, 0.3, SL + 0.05), cf * CF(sd * (w - 0.15), top + 1.15, z), C.woodD)
					if i % 2 == 0 then
						L.part(m, "Balustre", V(0.18, 0.8, 0.18), cf * CF(sd * (w - 0.15), top + 0.6, z), C.woodL)
					end
				end
			end
			-- sabords et canons
			if t > 0.25 and t < 0.75 and i % 3 == 0 then
				for _, sd in { -1, 1 } do
					local wx = 2 * w * (0.5 + 0.5 * math.min(1, 2.6 / H) ^ 0.45) / 2
					local port = cf * CF(sd * (wx + 0.05), 2.6, z)
					L.part(m, "Sabord", V(0.12, 0.9, 1), port, C.black)
					L.part(m, "SabordCadre", V(0.14, 1.1, 1.2), port * CF(sd * -0.02, 0, 0), C.gold)
					L.cyl(m, "Canon", 1.2, 0.5, port * CF(sd * 0.5, 0, 0), C.ironD)
				end
			end
		end
	end
	local sternZ, bowZ = zOf(1), zOf(0)
	local deckBack = sheer(0.95)
	-- chateau arriere
	local castle = cf * CF(0, deckBack + 1.4, sternZ - 3)
	L.part(m, "Chateau", V(BEAM * 0.8, 2.6, 5.4), castle, hullCol)
	L.part(m, "ChateauBande", V(BEAM * 0.82, 0.35, 5.5), castle * CF(0, 0.6, 0), C.gold)
	L.part(m, "ChateauToit", V(BEAM * 0.86, 0.3, 5.8), castle * CF(0, 1.45, 0), C.plank)
	for _, sd in { -1, 1 } do
		L.part(m, "ChateauRambarde", V(0.3, 0.3, 5.8), castle * CF(sd * BEAM * 0.42, 2.4, 0), C.woodD)
		for k = -2, 2 do
			L.part(m, "ChateauBalustre", V(0.18, 0.8, 0.18), castle * CF(sd * BEAM * 0.42, 1.95, k * 1.2), C.woodL)
		end
		local lan = L.part(m, "Lanterne", V(0.7, 1, 0.7), castle * CF(sd * BEAM * 0.4, 3.3, 2.6), C.orange, L.glow())
		L.part(m, "LanterneToit", V(0.9, 0.25, 0.9), castle * CF(sd * BEAM * 0.4, 3.9, 2.6), C.gold)
		L.light(lan, C.orange, 14, 1.2)
	end
	L.part(m, "ChateauRambarde", V(BEAM * 0.86, 0.3, 0.3), castle * CF(0, 2.4, 2.8), C.woodD)
	for i = -1, 1 do
		local w = castle * CF(i * 1.5, 0.1, 2.72)
		L.part(m, "Fenetre", V(1, 1.1, 0.1), w, C.orange, L.glow())
		L.part(m, "FenetreCadre", V(1.25, 1.35, 0.08), w * CF(0, 0, -0.03), C.gold)
		L.part(m, "FenetreCroix", V(0.08, 1.1, 0.12), w, C.woodD)
	end
	L.part(m, "Balcon", V(BEAM * 0.8, 0.25, 1.1), castle * CF(0, -1.2, 3.2), C.woodD)
	for k = -3, 3 do
		L.part(m, "BalconBalustre", V(0.15, 0.7, 0.15), castle * CF(k * 0.9, -0.8, 3.7), C.gold)
	end
	L.part(m, "BalconRambarde", V(BEAM * 0.8, 0.2, 0.2), castle * CF(0, -0.4, 3.7), C.gold)
	L.part(m, "Gouvernail", V(0.4, 4.4, 1.4), cf * CF(0, 2.2, sternZ + 0.6), C.woodD)
	-- barre (roue)
	local wheel = castle * CF(0, 2.6, -1.8)
	L.part(m, "RouePied", V(0.6, 1.4, 0.6), wheel * CF(0, -0.5, 0.3), C.woodD)
	for k = 0, 7 do
		local ang = k / 8 * TAU
		L.part(m, "Roue", V(0.15, 0.15, 1.6), wheel * CF(0, 0.6, 0) * ANG(0, 0, 0) * CFrame.fromAxisAngle(V(1, 0, 0), 0) * ANG(ang, 0, 0), C.woodL)
	end
	-- gaillard d'avant
	local fc = cf * CF(0, sheer(0.12) + 0.5, bowZ + 4.5)
	L.part(m, "Gaillard", V(BEAM * 0.55, 1, 3.2), fc, hullCol)
	L.part(m, "GaillardPont", V(BEAM * 0.58, 0.2, 3.3), fc * CF(0, 0.6, 0), C.plank)
	-- figure de proue
	local fh = cf * CF(0, sheer(0) - 0.4, bowZ - 0.8) * ANG(rad(-30), 0, 0)
	L.part(m, "Proue", V(0.8, 1.6, 0.9), fh, C.gold)
	L.part(m, "ProueTete", V(0.9, 0.9, 0.9), fh * CF(0, 1.1, -0.2), C.gold)
	L.part(m, "ProueCrin", V(1, 0.8, 0.5), fh * CF(0, 1.1, 0.35), C.goldD)
	-- beaupre + focs
	local bs0 = cf * CF(0, sheer(0) + 0.4, bowZ + 1)
	local bs1 = cf * CF(0, sheer(0) + 2.6, bowZ - 6)
	L.bar(m, "Beaupre", bs0.Position, bs1.Position, 0.4, C.woodL)
	-- mats
	local function mast(t, h, sails)
		local z = zOf(t)
		local base = sheer(t)
		local top = base + h
		L.part(m, "Mat", V(0.7, h, 0.7), cf * CF(0, base + h / 2, z), C.woodL)
		for k = 1, math.floor(h / 3) do
			L.part(m, "MatCercle", V(0.8, 0.15, 0.8), cf * CF(0, base + k * 3, z), C.iron)
		end
		for si, sl in sails do
			local y0, y1, wid = base + sl[1], base + sl[2], sl[3]
			L.part(m, "Vergue", V(wid + 1.2, 0.35, 0.35), cf * CF(0, y1 + 0.2, z), C.woodD)
			local strips = 5
			for k = 0, strips - 1 do
				local u = (k + 0.5) / strips
				local belly = math.sin(u * math.pi) * 1.1
				local hh = (y1 - y0) / strips
				local col = (si == 1 and k == 2) and C.red or C.sail
				local sail = L.part(m, "Voile", V(wid * (1 - 0.06 * (1 - u)), hh + 0.35, 0.4), cf * CF(0, y1 - hh * (k + 0.5), z - belly), col)
				sail:SetAttribute("D", true)
			end
			if si == 1 then
				local sk = cf * CF(0, (y0 + y1) / 2 + 0.3, z - 1.2)
				L.part(m, "VoileCrane", V(1.6, 1.4, 0.1), sk, C.black)
				L.part(m, "VoileOs", V(3, 0.3, 0.1), sk * CF(0, -1, 0) * ANG(0, 0, rad(30)), C.black)
				L.part(m, "VoileOs", V(3, 0.3, 0.1), sk * CF(0, -1, 0) * ANG(0, 0, rad(-30)), C.black)
			end
		end
		L.part(m, "Nid", V(2.2, 0.9, 2.2), cf * CF(0, top - 1.8, z), C.wood)
		L.part(m, "NidBord", V(2.4, 0.25, 2.4), cf * CF(0, top - 1.3, z), C.woodD)
		for k = 0, 3 do
			local wv = math.sin(k * 1.2) * 0.2
			L.part(m, "Drapeau", V(0.1, 1.4, 0.75), cf * CF(wv, top + 0.4, z + 0.45 + k * 0.72), C.black)
		end
		L.part(m, "DrapeauCrane", V(0.14, 0.55, 0.55), cf * CF(0, top + 0.45, z + 1.5), C.white)
		for _, sd in { -1, 1 } do
			local w = halfW(t)
			for k = -1, 1 do
				L.bar(m, "Hauban", (cf * CF(sd * (w - 0.15), base + 1.2, z + k * 0.9)).Position, (cf * CF(sd * 0.3, top - 2, z)).Position, 0.08, C.rope)
			end
			for hh = 1, 5 do
				local fy = base + 1.2 + hh * (h - 3.2) / 6
				local tt = (fy - base - 1.2) / (top - 2 - base - 1.2)
				local xw = (w - 0.15) * (1 - tt) + 0.3 * tt
				L.part(m, "Enflechure", V(0.06, 0.06, 1.9 * (1 - tt) + 0.1), cf * CF(sd * xw, fy, z), C.rope)
			end
		end
		return top
	end
	local mainTop = mast(0.52, 16, { { 3.2, 8.6, BEAM * 1.25 }, { 9.4, 13.2, BEAM * 0.9 } })
	local foreTop = mast(0.24, 13, { { 3, 7.6, BEAM * 1.05 }, { 8.2, 11, BEAM * 0.75 } })
	-- focs (triangles)
	local fz = zOf(0.24)
	for k = 0, 3 do
		local tt = k / 4
		local a = bs1.Position:Lerp((cf * CF(0, sheer(0.24) + 11, fz)).Position, tt)
		local b = bs0.Position:Lerp((cf * CF(0, sheer(0.24) + 3, fz)).Position, tt)
		L.bar(m, "Foc", a, b, 0.15, C.sail, nil, 0.9 - tt * 0.6)
	end
	L.bar(m, "Etai", (cf * CF(0, foreTop - 1, fz)).Position, bs1.Position, 0.1, C.rope)
	L.bar(m, "Etai", (cf * CF(0, mainTop - 1, zOf(0.52))).Position, (cf * CF(0, foreTop - 2, fz)).Position, 0.1, C.rope)
	-- pont : ecoutille, tonneaux, cordes, cloche
	local mid = cf * CF(0, sheer(0.4) + 0.3, zOf(0.4))
	L.part(m, "Ecoutille", V(2.4, 0.3, 2), mid * CF(0, 0, 1.6), C.woodD)
	for k = -1, 1 do
		L.part(m, "Grille", V(2.4, 0.32, 0.12), mid * CF(0, 0, 1.6 + k * 0.6), C.wood)
	end
	for k = 0, 2 do
		L.part(m, "Tonneau", V(0.9, 1.2, 0.9), mid * CF(-1.8 + k * 0.1, 0.6, -1.6 + k * 1), C.wood)
		L.part(m, "TonneauCercle", V(1, 0.15, 1), mid * CF(-1.8 + k * 0.1, 0.9, -1.6 + k * 1), C.iron)
	end
	L.part(m, "RouleauCorde", V(1.2, 0.4, 1.2), mid * CF(1.8, 0.2, -1), C.rope)
	local anc = cf * CF(-halfW(0.12) - 0.2, 2.6, zOf(0.12))
	L.part(m, "Ancre", V(0.25, 2.2, 0.35), anc, C.ironD)
	L.part(m, "AncreBras", V(0.25, 0.35, 1.8), anc * CF(0, -1, 0), C.ironD)
	L.part(m, "AncreJas", V(0.25, 0.3, 1.3), anc * CF(0, 0.95, 0), C.woodD)
	-- ecume autour de la coque
	for k = 0, 9 do
		local tt = k / 9
		for _, sd in { -1, 1 } do
			L.part(m, "Ecume", V(0.8, 0.12, 1.4), cf * CF(sd * (halfW(tt) + 0.5), 0.33, zOf(tt)), C.white, { Transparency = 0.25, CanCollide = false })
		end
	end
	return m
end

function P.sign(parent, cf, rng, text)
	local m = L.model("EnseignePirate", parent, cf)
	for _, s in { -1, 1 } do
		L.part(m, "Poteau", V(1, 12, 1), cf * CF(s * 6, 6, 0), C.woodD)
		L.part(m, "Crane", V(1.4, 1.3, 1.3), cf * CF(s * 6, 12.7, 0), C.white)
		L.part(m, "Orbite", V(0.35, 0.35, 0.05), cf * CF(s * 6 - 0.3, 12.8, -0.66), C.black)
		L.part(m, "Orbite", V(0.35, 0.35, 0.05), cf * CF(s * 6 + 0.3, 12.8, -0.66), C.black)
	end
	local board = L.part(m, "Planche", V(11, 3.4, 0.5), cf * CF(0, 9, 0) * ANG(0, 0, rad(-3)), C.wood)
	L.part(m, "Bord", V(11.4, 0.4, 0.6), board.CFrame * CF(0, 1.7, 0), C.woodD)
	L.part(m, "Bord", V(11.4, 0.4, 0.6), board.CFrame * CF(0, -1.7, 0), C.woodD)
	L.label(board, Enum.NormalId.Front, text or "PIRATES", C.gold, Enum.Font.Fantasy)
	L.label(board, Enum.NormalId.Back, text or "PIRATES", C.gold, Enum.Font.Fantasy)
	for _, s in { -1, 1 } do
		local sw = cf * CF(0, 5.6, -0.5) * ANG(0, 0, s * rad(40))
		L.part(m, "Lame", V(5, 0.35, 0.15), sw, C.metalL, SHINY)
		L.part(m, "Garde", V(0.3, 1, 0.3), sw * CF(s * -2.4, 0, 0), C.gold, SHINY)
		L.part(m, "Poignee", V(0.9, 0.3, 0.3), sw * CF(s * -3, 0, 0), C.woodD)
	end
	return m
end

--== LOT 2 ==--

function P.ghost(parent, cf, rng)
	local m = P.pirate(parent, cf * CF(0, 1.2, 0), rng, { capitaine = rng:NextNumber() < 0.5, sword = true, beard = C.ghost })
	m.Name = "PiratFantome"
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Color = C.ghost:Lerp(d.Color, 0.25)
			d.Material = Enum.Material.Neon
			d.MaterialVariant = ""
			d.Transparency = 0.45
			d.CanCollide = false
			d.CastShadow = false
		end
	end
	for _, d in m:GetChildren() do
		if d.Name == "Botte" or d.Name == "JambeBois" or d.Name == "Revers" then d:Destroy() end
	end
	L.part(m, "Trainee", V(2.4, 1.4, 1.6), cf * CF(0, 1.9, 0.1), C.ghost, L.glow({ Transparency = 0.7, CanCollide = false }))
	L.part(m, "Trainee", V(1.4, 1, 1), cf * CF(0.2, 0.9, 0.4), C.ghost, L.glow({ Transparency = 0.8, CanCollide = false }))
	local a = L.anchor(m, "Aura", cf * CF(0, 5, 0), V(3, 6, 2))
	L.light(a, C.ghost, 14, 1.5)
	L.sparkles(a, C.ghost, 5, 0.6)
	return m
end

function P.sharks(parent, cf, rng, n)
	n = n or 3
	local m = L.model("Requins", parent, cf)
	L.part(m, "Bord", V(17, 0.5, 17), cf * CF(0, 0.25, 0), C.sand)
	for i = 0, 11 do
		local a = i / 12 * TAU
		L.part(m, "Pierre", V(2.2, 0.8, 1.2), cf * CF(math.cos(a) * 8, 0.6, math.sin(a) * 8) * ANG(0, -a + math.pi / 2, 0), (i % 2 == 0) and C.stone or C.stone:Lerp(C.black, 0.2))
	end
	L.part(m, "Fond", V(15, 0.3, 15), cf * CF(0, 0.35, 0), C.water:Lerp(C.black, 0.4))
	L.part(m, "Eau", V(15, 0.4, 15), cf * CF(0, 0.7, 0), C.water, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.25 })
	local grey, belly = C.iron:Lerp(C.navy, 0.3), C.white
	for i = 1, n do
		local a = i / n * TAU + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(3, 5.5)
		local f = cf * CF(math.cos(a) * r, 0.9, math.sin(a) * r) * ANG(0, -a, 0)
		L.wedge(m, "Aileron", V(0.35, 2.2, 1.8), f * CF(0, 1.1, 0), grey)
		L.part(m, "Dos", V(1.4, 0.4, 3.4), f * CF(0, 0.05, 0.4), grey)
		L.wedge(m, "Queue", V(0.3, 1.2, 1), f * CF(0, 0.6, 2.5), grey)
		for k = 0, 3 do
			L.part(m, "Sillage", V(1.4 - k * 0.25, 0.08, 0.6), f * CF(0, 0.02, 2.6 + k * 0.8), C.white, { Transparency = 0.2 + k * 0.15, CanCollide = false })
		end
	end
	local j = cf * CF(0, 3.2, 0) * ANG(rad(-35), rad(rng:NextNumber(0, 360)), 0)
	L.part(m, "SautCorps", V(1.8, 1.6, 4.6), j, grey)
	L.part(m, "SautVentre", V(1.5, 0.3, 3.8), j * CF(0, -0.8, -0.2), belly)
	L.part(m, "SautMuseau", V(1.4, 1.2, 1.2), j * CF(0, 0.1, -2.8), grey)
	L.part(m, "SautGueule", V(1.2, 0.5, 1), j * CF(0, -0.45, -2.7), C.coat)
	for x = -1, 1 do
		L.wedge(m, "Dent", V(0.25, 0.3, 0.15), j * CF(x * 0.35, -0.25, -3.25), C.white)
	end
	for _, x in { -0.72, 0.72 } do
		L.part(m, "SautOeil", V(0.05, 0.3, 0.3), j * CF(x, 0.35, -2.7), C.black)
	end
	L.wedge(m, "SautAileron", V(0.3, 1.6, 1.4), j * CF(0, 1.5, 0.2), grey)
	L.part(m, "SautQueue", V(0.3, 2, 0.8), j * CF(0, 0.3, 2.8) * ANG(rad(20), 0, 0), grey)
	for _, x in { -1, 1 } do
		L.part(m, "SautNageoire", V(1.4, 0.2, 0.9), j * CF(x * 1.3, -0.5, -0.6) * ANG(0, 0, x * rad(-25)), grey)
	end
	for _ = 1, 6 do
		L.part(m, "Goutte", V(0.35, 0.35, 0.35), j * CF(rng:NextNumber(-2, 2), rng:NextNumber(-2.5, -1), rng:NextNumber(-1, 3)), C.white, { Transparency = 0.25, CanCollide = false })
	end
	return m
end

function P.plank(parent, cf, rng)
	local m = L.model("PlancheDuSupplice", parent, cf)
	L.part(m, "Pont", V(6, 3, 5), cf * CF(0, 1.5, 4), C.woodD)
	L.part(m, "PontDessus", V(6.2, 0.3, 5.2), cf * CF(0, 3.1, 4), C.plank)
	for i = -2, 2 do
		L.part(m, "Latte", V(0.08, 0.32, 5.2), cf * CF(i * 1.2, 3.11, 4), C.woodD)
	end
	L.part(m, "Coque", V(6.3, 0.4, 5.3), cf * CF(0, 1, 4), C.gold)
	L.part(m, "Tonneau", V(1.3, 1.7, 1.3), cf * CF(2, 4.1, 5.5), C.wood)
	L.part(m, "TonneauCercle", V(1.4, 0.2, 1.4), cf * CF(2, 4.3, 5.5), C.iron)
	L.part(m, "Corde", V(1.6, 0.5, 1.6), cf * CF(-1.8, 3.5, 5.3), C.rope)
	L.part(m, "CordeHaut", V(1, 0.4, 1), cf * CF(-1.8, 3.9, 5.3), C.rope:Lerp(C.woodD, 0.2))
	L.part(m, "Planche", V(1.8, 0.45, 9), cf * CF(0, 3.25, -3), C.woodL)
	for _, s in { -1, 1 } do
		L.part(m, "Rambarde", V(0.3, 1.6, 5), cf * CF(s * 2.9, 4, 4), C.woodD)
	end
	L.part(m, "Clou", V(0.3, 0.3, 0.3), cf * CF(0, 3.4, 1.2), C.iron)
	local sh = P.sharks(m, cf * CF(0, 0, -5), rng, 3)
	sh.Parent = m
	return m
end

function P.hammock(parent, cf, rng)
	local m = L.model("Hamac", parent, cf)
	L.part(m, "Sable", V(13, 0.3, 6), cf * CF(0, 0.15, 0), C.sand)
	for _, s in { -1, 1 } do
		for k = 0, 3 do
			L.part(m, "Poteau", V(0.9 - k * 0.05, 1.6, 0.9 - k * 0.05), cf * CF(s * 5, 0.9 + k * 1.6, 0), (k % 2 == 0) and C.woodD or C.wood)
		end
		L.part(m, "PoteauHaut", V(1.1, 0.4, 1.1), cf * CF(s * 5, 6.9, 0), C.woodL)
		L.part(m, "Anneau", V(0.3, 0.6, 0.6), cf * CF(s * 4.5, 5, 0), C.iron)
		for _, z in { -0.8, 0, 0.8 } do
			L.bar(m, "Corde", (cf * CF(s * 4.5, 5, 0)).Position, (cf * CF(s * 3.3, 3.3, z)).Position, 0.1, C.rope)
		end
		L.part(m, "Barre", V(0.25, 0.25, 2.4), cf * CF(s * 3.3, 3.3, 0), C.woodL)
	end
	for i = -4, 4 do
		local t = i / 4
		local y = 3.3 - (1 - t * t) * 1.1
		local tilt = t * 0.35
		L.part(m, "Toile", V(0.8, 0.2, 2.4), cf * CF(i * 0.73, y, 0) * ANG(0, 0, tilt), (i % 2 == 0) and C.red or C.sail)
		for _, z in { -1.3, 1.3 } do
			L.part(m, "Frange", V(0.6, 0.4, 0.08), cf * CF(i * 0.73, y - 0.25, z), C.gold)
		end
	end
	L.part(m, "Coussin", V(1.4, 0.45, 1.8), cf * CF(-2.2, 2.9, 0) * ANG(0, 0, 0.3), C.parrotY)
	L.part(m, "Livre", V(0.8, 0.2, 1), cf * CF(0.6, 2.35, 0.3) * ANG(0, 0.4, 0), C.coat)
	L.part(m, "Bouteille", V(0.4, 1, 0.4), cf * CF(3.8, 0.8, 1.6), C.emerald, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.25 })
	L.part(m, "Chapeau", V(1.6, 0.35, 1.4), cf * CF(-4, 0.5, 1.5) * ANG(0, 0.5, 0), C.black)
	return m
end

function P.stall(parent, cf, rng)
	local m = L.model("EtalMarche", parent, cf)
	L.part(m, "Comptoir", V(7, 3, 2.4), cf * CF(0, 1.5, 0), C.wood)
	L.part(m, "Dessus", V(7.4, 0.3, 2.8), cf * CF(0, 3.15, 0), C.woodL)
	for _, x in { -3.4, 3.4 } do
		L.part(m, "Montant", V(0.5, 7, 0.5), cf * CF(x, 3.5, 1), C.woodD)
		L.part(m, "MontantAvant", V(0.5, 6, 0.5), cf * CF(x, 3, -1.2), C.woodD)
	end
	for i = 0, 6 do
		L.part(m, "Auvent", V(1.05, 0.25, 4), cf * CF(-3.15 + i * 1.05, 6.6, -0.1) * ANG(rad(-15), 0, 0), (i % 2 == 0) and C.red or C.white)
	end
	for i = 0, 4 do
		local col = ({ C.emerald, C.parrotB, C.orange, C.kraken, C.emerald })[i + 1]
		local b = cf * CF(-2.6 + i * 1.3, 3.3, -0.3)
		L.part(m, "Bouteille", V(0.5, 1.1, 0.5), b * CF(0, 0.55, 0), col, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.25 })
		L.part(m, "Goulot", V(0.25, 0.4, 0.25), b * CF(0, 1.3, 0), col, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.25 })
		L.part(m, "Bouchon", V(0.28, 0.2, 0.28), b * CF(0, 1.55, 0), C.woodL)
	end
	for i = 0, 5 do
		L.part(m, "Fruit", V(0.6, 0.6, 0.6), cf * CF(-2.5 + i * 0.5, 3.6, 0.8), (i % 2 == 0) and C.orange or C.parrotY)
	end
	for _, x in { -2.8, 2.8 } do
		L.part(m, "Crochet", V(0.1, 0.6, 0.1), cf * CF(x, 6, -1.2), C.iron)
		local lp = L.part(m, "Lampion", V(0.6, 0.8, 0.6), cf * CF(x, 5.4, -1.2), C.orange, L.glow())
		L.light(lp, C.orange, 10, 1)
	end
	for i = 0, 2 do
		L.part(m, "PoissonPendu", V(0.25, 1, 0.5), cf * CF(-1 + i * 0.9, 5.2, -1.3), (i % 2 == 0) and C.metalL or C.parrotB)
	end
	L.part(m, "Balance", V(0.15, 1.2, 0.15), cf * CF(2.4, 3.9, 0.4), C.gold, SHINY)
	L.part(m, "BalanceFleau", V(1.4, 0.1, 0.1), cf * CF(2.4, 4.5, 0.4), C.gold, SHINY)
	for _, x in { -0.6, 0.6 } do
		L.part(m, "Plateau", V(0.5, 0.08, 0.5), cf * CF(2.4 + x, 4.1, 0.4), C.gold, SHINY)
	end
	L.part(m, "Bocal", V(0.7, 0.9, 0.7), cf * CF(-3, 3.75, 0.5), C.white, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.4 })
	L.part(m, "BocalOr", V(0.55, 0.5, 0.55), cf * CF(-3, 3.55, 0.5), C.gold, SHINY)
	for i = 0, 1 do
		local cr = cf * CF(-2 + i * 4, 0.6, -2)
		L.part(m, "Cagette", V(1.6, 1.2, 1.2), cr, C.plank)
		for k = 0, 3 do
			L.part(m, "Fruit", V(0.5, 0.5, 0.5), cr * CF(-0.5 + (k % 2) * 1, 0.8, -0.25 + math.floor(k / 2) * 0.5), (i == 0) and C.orange or C.red)
		end
	end
	local sign = L.part(m, "Panneau", V(4, 1.2, 0.2), cf * CF(0, 5.4, 1.1), C.paper)
	L.label(sign, Enum.NormalId.Front, "RHUM", C.coat, Enum.Font.Fantasy)
	return m
end

function P.digSpot(parent, cf, rng)
	local m = L.model("TrouAuTresor", parent, cf)
	L.part(m, "Sable", V(8, 0.3, 8), cf * CF(0, 0.15, 0), C.sand)
	L.part(m, "Trou", V(3, 0.1, 3), cf * CF(0, 0.32, 0), C.dark)
	L.part(m, "Tas", V(2.6, 1, 2.2), cf * CF(3, 0.6, 1.5), C.sand:Lerp(C.woodD, 0.15))
	L.part(m, "Tas", V(1.6, 0.8, 1.4), cf * CF(3.1, 1.3, 1.5), C.sand:Lerp(C.woodD, 0.15))
	L.part(m, "CoffreCouvercle", V(2.4, 0.5, 1.6), cf * CF(0, 0.5, 0) * ANG(rad(25), 0, 0), C.wood)
	L.part(m, "Or", V(2, 0.3, 1.2), cf * CF(0, 0.45, 0.2), C.gold, { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.25 })
	local sh = cf * CF(-2.4, 0, 1.2) * ANG(0, rad(30), rad(-20))
	L.part(m, "Manche", V(0.3, 4, 0.3), sh * CF(0, 2.2, 0), C.woodL)
	L.part(m, "Poignee", V(0.9, 0.25, 0.3), sh * CF(0, 4.2, 0), C.woodD)
	L.part(m, "Pelle", V(1, 1.2, 0.15), sh * CF(0, 0.4, 0), C.metalL, { Material = Enum.Material.Metal, MaterialVariant = "" })
	for _, a in { rad(45), rad(-45) } do
		L.part(m, "X", V(3.6, 0.12, 0.4), cf * CF(0, 0.32, 0) * ANG(0, a, 0), C.red)
	end
	L.light(L.anchor(m, "Eclat", cf * CF(0, 1, 0)), C.yellow, 8, 1)
	return m
end

function P.watchtower(parent, cf, rng)
	local m = L.model("TourDeGuet", parent, cf)
	local h = 14
	for _, x in { -2.5, 2.5 } do
		for _, z in { -2.5, 2.5 } do
			L.part(m, "Pilotis", V(0.9, h, 0.9), cf * CF(x, h / 2, z), C.woodD)
		end
	end
	for _, y in { 4, 9 } do
		for _, s in { -1, 1 } do
			L.part(m, "Traverse", V(6, 0.4, 0.4), cf * CF(0, y, s * 2.5), C.wood)
			L.part(m, "Traverse", V(0.4, 0.4, 6), cf * CF(s * 2.5, y, 0), C.wood)
		end
	end
	L.part(m, "Plancher", V(7.4, 0.5, 7.4), cf * CF(0, h, 0), C.plank)
	for _, s in { -1, 1 } do
		L.part(m, "Garde", V(7.4, 1.4, 0.3), cf * CF(0, h + 0.9, s * 3.6), C.wood)
		L.part(m, "Garde", V(0.3, 1.4, 7.4), cf * CF(s * 3.6, h + 0.9, 0), C.wood)
		L.part(m, "Poteau", V(0.5, 4, 0.5), cf * CF(s * 3.4, h + 2.2, 3.4), C.woodD)
		L.part(m, "Poteau", V(0.5, 4, 0.5), cf * CF(s * 3.4, h + 2.2, -3.4), C.woodD)
	end
	for i = 0, 5 do
		L.part(m, "Toit", V(8.6 - i * 1.4, 0.5, 8.6 - i * 1.4), cf * CF(0, h + 4.4 + i * 0.5, 0), (i % 2 == 0) and C.sand or C.woodL)
	end
	for i = 0, 12 do
		L.part(m, "Echelon", V(1.8, 0.25, 0.25), cf * CF(0, 0.8 + i * 1.05, -3.3), C.woodL)
	end
	for _, s in { -1, 1 } do
		L.part(m, "Echelle", V(0.3, h, 0.3), cf * CF(s * 0.9, h / 2, -3.3), C.woodD)
	end
	L.part(m, "LongueVue", V(0.4, 0.4, 2), cf * CF(1.8, h + 2, -3.2) * ANG(rad(10), 0, 0), C.gold, { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.25 })
	L.part(m, "Mat", V(0.3, 5, 0.3), cf * CF(0, h + 9.5, 0), C.woodD)
	L.part(m, "Drapeau", V(2.2, 1.4, 0.1), cf * CF(1.2, h + 11.2, 0), C.black)
	L.part(m, "DrapeauCrane", V(0.5, 0.5, 0.12), cf * CF(1.2, h + 11.3, 0), C.white)
	L.part(m, "Poulie", V(0.5, 0.5, 0.5), cf * CF(3.4, h + 4.2, -3.4), C.iron)
	L.part(m, "CordeSeau", V(0.08, h, 0.08), cf * CF(3.9, h / 2 + 3.5, -3.9), C.rope)
	L.part(m, "Seau", V(0.9, 0.9, 0.9), cf * CF(3.9, 3, -3.9), C.woodD)
	for i = 0, 2 do
		L.part(m, "Caisse", V(1.6, 1.6, 1.6), cf * CF(-1.8 + (i % 2) * 1.8, 0.8 + math.floor(i / 2) * 1.6, 1.8), C.plank)
	end
	L.part(m, "Tonneau", V(1.3, 1.7, 1.3), cf * CF(1.6, 0.85, 1.8), C.wood)
	L.part(m, "Cloche", V(0.8, 0.8, 0.8), cf * CF(-3.4, h + 3.4, 3.4), C.gold, SHINY)
	local lamp = L.part(m, "Lanterne", V(0.8, 1, 0.8), cf * CF(-3, h + 3, -3), C.orange, L.glow())
	L.light(lamp, C.orange, 18, 1.5)
	return m
end

function P.throne(parent, cf, rng)
	local m = L.model("TroneDuCapitaine", parent, cf)
	L.part(m, "Estrade", V(7, 0.6, 6), cf * CF(0, 0.3, 0), C.woodD)
	L.part(m, "Tapis", V(3, 0.1, 4), cf * CF(0, 0.65, -1.5), C.coat)
	L.part(m, "Assise", V(4, 1, 3.4), cf * CF(0, 2.2, 0.6), C.coat)
	L.part(m, "Base", V(4.2, 1.6, 3.6), cf * CF(0, 1.2, 0.6), C.gold, { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.2 })
	L.part(m, "Dossier", V(4.2, 6, 0.8), cf * CF(0, 5, 2.1), C.gold, { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.2 })
	L.part(m, "DossierVelours", V(3.2, 4.6, 0.2), cf * CF(0, 4.8, 1.65), C.coat)
	for _, s in { -1, 1 } do
		L.part(m, "Accoudoir", V(0.7, 1, 3.4), cf * CF(s * 2.1, 3.2, 0.6), C.gold, { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.2 })
		L.part(m, "Pommeau", V(0.9, 0.9, 0.9), cf * CF(s * 2.1, 3.9, -1), C.ruby, L.glow())
	end
	for i = 0, 2 do
		L.part(m, "Gemme", V(0.5, 0.5, 0.2), cf * CF(-1.2 + i * 1.2, 7.3, 1.62) * ANG(0, 0, rad(45)), ({ C.ruby, C.emerald, C.sapphire })[i + 1], L.glow())
	end
	for _, x in { -3, 3 } do
		L.part(m, "Chandelier", V(0.8, 0.3, 0.8), cf * CF(x, 0.75, -1.5), C.gold, SHINY)
		L.part(m, "ChandelierPied", V(0.25, 3, 0.25), cf * CF(x, 2.2, -1.5), C.gold, SHINY)
		L.part(m, "Bougie", V(0.35, 0.8, 0.35), cf * CF(x, 4.1, -1.5), C.white)
		local fl = L.part(m, "Flamme", V(0.2, 0.35, 0.2), cf * CF(x, 4.7, -1.5), C.orange, L.glow())
		L.light(fl, C.orange, 10, 1.2)
	end
	for i = -3, 3 do
		L.part(m, "Frange", V(0.3, 0.12, 0.3), cf * CF(i * 0.42, 0.66, -3.55), C.gold)
	end
	L.part(m, "Coussin", V(3.2, 0.4, 2.6), cf * CF(0, 2.9, 0.4), C.navy)
	local sk = cf * CF(0, 8.6, 2.1)
	L.part(m, "Crane", V(1.8, 1.6, 1.4), sk, C.white)
	L.part(m, "Machoire", V(1.2, 0.5, 1.2), sk * CF(0, -1, -0.1), C.white)
	for _, x in { -0.4, 0.4 } do
		L.part(m, "Orbite", V(0.5, 0.5, 0.1), sk * CF(x, 0.15, -0.72), C.black)
	end
	for _, a in { rad(35), rad(-35) } do
		L.part(m, "Os", V(4.5, 0.4, 0.4), cf * CF(0, 7.4, 2.4) * ANG(0, 0, a), C.white)
	end
	return m
end

function P.bell(parent, cf, rng)
	local m = L.model("Cloche", parent, cf)
	for _, s in { -1, 1 } do
		L.part(m, "Montant", V(0.7, 7, 0.7), cf * CF(s * 2, 3.5, 0), C.woodD)
	end
	L.part(m, "Traverse", V(5, 0.7, 0.9), cf * CF(0, 7, 0), C.wood)
	L.part(m, "Toit", V(5.6, 0.4, 2), cf * CF(0, 7.6, 0), C.woodD)
	local b = cf * CF(0, 5.4, 0)
	local mat = { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.3 }
	L.part(m, "Anse", V(0.5, 0.6, 0.5), b * CF(0, 1.2, 0), C.goldD, mat)
	L.part(m, "Cloche", V(1.4, 0.8, 1.4), b * CF(0, 0.6, 0), C.gold, mat)
	L.part(m, "Cloche", V(1.9, 0.8, 1.9), b * CF(0, -0.1, 0), C.gold, mat)
	L.part(m, "Levre", V(2.3, 0.4, 2.3), b * CF(0, -0.7, 0), C.goldD, mat)
	L.part(m, "Battant", V(0.4, 0.4, 0.4), b * CF(0, -1.1, 0), C.iron)
	L.bar(m, "Corde", (b * CF(0, -1.1, 0)).Position, (cf * CF(0.6, 1.5, -0.4)).Position, 0.15, C.rope)
	L.part(m, "Pied", V(5, 0.4, 1.6), cf * CF(0, 0.2, 0), C.woodD)
	return m
end

function P.bottles(parent, cf, rng, n)
	n = n or 4
	local m = L.model("BouteillesALaMer", parent, cf)
	L.part(m, "Sable", V(7, 0.3, 7), cf * CF(0, 0.15, 0), C.sand)
	L.part(m, "Coquillage", V(0.6, 0.3, 0.5), cf * CF(2.5, 0.4, -2), C.pink)
	L.part(m, "Etoile", V(0.8, 0.2, 0.8), cf * CF(-2.4, 0.35, 2) * ANG(0, 0.5, 0), C.orange)
	for _ = 1, n do
		local a = rng:NextNumber(0, TAU)
		local r = rng:NextNumber(0.5, 3)
		local b = cf * CF(math.cos(a) * r, 0.65, math.sin(a) * r) * ANG(0, rng:NextNumber(0, TAU), rng:NextNumber(-0.15, 0.15))
		local glass = { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.3 }
		L.part(m, "Bouteille", V(1.2, 0.6, 0.6), b, C.emerald, glass)
		L.part(m, "Goulot", V(0.5, 0.3, 0.3), b * CF(0.85, 0, 0), C.emerald, glass)
		L.part(m, "Bouchon", V(0.2, 0.32, 0.32), b * CF(1.15, 0, 0), C.woodL)
		L.part(m, "Message", V(0.8, 0.35, 0.35), b, C.paper)
	end
	return m
end

function P.goldSacks(parent, cf, rng)
	local m = L.model("SacsDOr", parent, cf)
	for i = 1, rng:NextInteger(3, 4) do
		local a = i / 4 * TAU
		local sc = cf * CF(math.cos(a) * 1.4, 0, math.sin(a) * 1.4) * ANG(0, rng:NextNumber(0, TAU), 0)
		local s = rng:NextNumber(0.8, 1.2)
		L.part(m, "SacBas", V(1.8, 0.7, 1.8) * s, sc * CF(0, 0.35 * s, 0), C.sailD)
		L.part(m, "Sac", V(1.6, 0.8, 1.6) * s, sc * CF(0, 1.05 * s, 0), C.sailD:Lerp(C.white, 0.1))
		L.part(m, "SacHaut", V(1.2, 0.4, 1.2) * s, sc * CF(0, 1.6 * s, 0), C.sailD)
		L.part(m, "Col", V(0.7, 0.4, 0.7) * s, sc * CF(0, 1.95 * s, 0), C.sailD)
		L.part(m, "Lien", V(0.85, 0.2, 0.85) * s, sc * CF(0, 1.85 * s, 0), C.rope)
		L.part(m, "LienBout", V(0.15, 0.6, 0.15) * s, sc * CF(0.4 * s, 1.55 * s, -0.4 * s) * ANG(0, 0, 0.4), C.rope)
		L.part(m, "Pieces", V(0.8, 0.2, 0.8) * s, sc * CF(0, 2.25 * s, 0), C.gold, { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.25 })
		local fc = sc * CF(0, 1, -0.82 * s)
		L.part(m, "Signe", V(0.2, 0.8, 0.05) * s, fc, C.goldD)
		L.part(m, "Signe", V(0.6, 0.15, 0.05) * s, fc * CF(0, 0.25 * s, 0), C.goldD)
		L.part(m, "Signe", V(0.6, 0.15, 0.05) * s, fc * CF(0, -0.25 * s, 0), C.goldD)
		L.part(m, "Rustine", V(0.5, 0.5, 0.05) * s, sc * CF(0.5 * s, 0.5 * s, 0.92 * s), C.woodL)
	end
	for _ = 1, 8 do
		local a = rng:NextNumber(0, TAU)
		local r = rng:NextNumber(2.4, 3.4)
		L.part(m, "Piece", V(0.45, 0.1, 0.45), cf * CF(math.cos(a) * r, 0.05, math.sin(a) * r) * ANG(0, a, 0), C.gold, { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.25 })
	end
	return m
end

function P.fishNet(parent, cf, rng)
	local m = L.model("FiletDePeche", parent, cf)
	for _, s in { -1, 1 } do
		L.part(m, "Poteau", V(0.6, 6, 0.6), cf * CF(s * 3, 3, 0), C.woodD)
	end
	L.part(m, "Barre", V(6.6, 0.4, 0.4), cf * CF(0, 5.8, 0), C.wood)
	for i = 0, 5 do
		L.part(m, "Maille", V(0.1, 4.6, 0.1), cf * CF(-2.5 + i, 3.5, 0), C.rope)
	end
	for j = 0, 4 do
		L.part(m, "Maille", V(5.4, 0.1, 0.1), cf * CF(0, 1.4 + j * 1, 0), C.rope)
	end
	for i = 1, 3 do
		local f = cf * CF(-2 + i * 1.2, 2.5 + (i % 2) * 1.2, -0.2)
		local col = ({ C.parrotB, C.orange, C.metalL })[i]
		L.part(m, "Poisson", V(1.3, 0.6, 0.2), f, col)
		L.wedge(m, "Queue", V(0.2, 0.7, 0.5), f * CF(0.85, 0, 0) * ANG(0, rad(90), 0), col)
		L.part(m, "Oeil", V(0.15, 0.15, 0.05), f * CF(-0.4, 0.1, -0.11), C.black)
	end
	L.part(m, "Rouleau", V(1.8, 0.8, 1.8), cf * CF(4.4, 0.4, 0), C.rope)
	L.part(m, "RouleauHaut", V(1.2, 0.5, 1.2), cf * CF(4.4, 1, 0), C.rope:Lerp(C.woodD, 0.2))
	return m
end

function P.skullTotem(parent, cf, rng)
	local m = L.model("TotemCranes", parent, cf)
	L.part(m, "Socle", V(3, 1, 3), cf * CF(0, 0.5, 0), C.stone or C.rock)
	L.part(m, "Poteau", V(1, 10, 1), cf * CF(0, 6, 0), C.woodD)
	for i = 0, 2 do
		local sk = cf * CF(0, 3.2 + i * 2.6, 0) * ANG(0, rad(i * 25 - 25), 0)
		L.part(m, "Crane", V(1.8, 1.6, 1.6), sk, C.white)
		L.part(m, "Machoire", V(1.2, 0.5, 1.4), sk * CF(0, -1, -0.1), C.white)
		for _, x in { -0.4, 0.4 } do
			L.part(m, "Orbite", V(0.5, 0.5, 0.1), sk * CF(x, 0.15, -0.82), C.black)
		end
		L.part(m, "OrbiteFeu", V(0.25, 0.25, 0.12), sk * CF(0.4, 0.15, -0.84), C.orange, L.glow())
	end
	L.part(m, "Plume", V(0.3, 2, 0.8), cf * CF(0.4, 11.8, 0) * ANG(0, 0, rad(-15)), C.red)
	L.part(m, "Plume", V(0.3, 2, 0.8), cf * CF(-0.4, 11.8, 0) * ANG(0, 0, rad(15)), C.parrotB)
	local t = L.part(m, "Torche", V(0.5, 0.8, 0.5), cf * CF(0, 11.3, -0.7), C.orange, L.glow())
	L.light(t, C.orange, 14, 1.3)
	return m
end

function P.mermaid(parent, cf, rng)
	local m = L.model("StatueSirene", parent, cf)
	local stone = C.stone
	L.part(m, "Bassin", V(8, 0.6, 7), cf * CF(0, 0.3, 0), stone:Lerp(C.black, 0.2))
	L.part(m, "Eau", V(7, 0.3, 6), cf * CF(0, 0.65, 0), C.water, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.25 })
	L.part(m, "Rocher", V(4.6, 2, 4), cf * CF(0, 1.4, 0.3), stone:Lerp(C.black, 0.1))
	L.part(m, "Rocher", V(3.2, 1.2, 2.8), cf * CF(0.4, 2.9, 0.5) * ANG(0, 0.3, 0), stone)
	for i = 0, 2 do
		L.part(m, "Coquillage", V(0.6, 0.35, 0.5), cf * CF(-1.8 + i * 0.4, 2.5, -1.7 + i * 0.3), (i % 2 == 0) and C.pink or C.white)
	end
	local tail = cf * CF(0.6, 4, -0.2) * ANG(0, rad(-35), 0)
	local p = tail
	local teal = C.emerald
	for k = 0, 4 do
		local w = 1.6 - k * 0.22
		p = p * CF(0.6, -0.05, 0) * ANG(0, 0, rad(-12))
		L.part(m, "Queue", V(1, w * 0.9, w), p, (k % 2 == 0) and teal or teal:Lerp(C.water, 0.3))
		L.part(m, "Ecaille", V(0.4, 0.3, 0.05), p * CF(0, 0.1, -w / 2 - 0.02), teal:Lerp(C.white, 0.4))
	end
	L.wedge(m, "Nageoire", V(0.3, 1.2, 1.4), p * CF(0.6, 0.3, 0.5) * ANG(0, rad(90), rad(40)), teal:Lerp(C.white, 0.2))
	L.wedge(m, "Nageoire", V(0.3, 1.2, 1.4), p * CF(0.6, -0.3, 0.5) * ANG(0, rad(90), rad(140)), teal:Lerp(C.white, 0.2))
	L.part(m, "Hanche", V(1.8, 1, 1.4), cf * CF(0, 4.1, 0.2), teal)
	L.part(m, "Torse", V(1.7, 2, 1.1), cf * CF(0, 5.5, 0.2), C.skin)
	for _, x in { -0.45, 0.45 } do
		L.part(m, "Coquille", V(0.7, 0.6, 0.2), cf * CF(x, 5.9, -0.4), C.kraken)
	end
	L.part(m, "Collier", V(1.2, 0.15, 0.1), cf * CF(0, 6.3, -0.37), C.white, { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.25 })
	L.part(m, "BrasG", V(0.5, 1.9, 0.5), cf * CF(-1.1, 5.3, 0) * ANG(rad(-15), 0, rad(15)), C.skin)
	L.part(m, "BrasD", V(0.5, 2, 0.5), cf * CF(1.35, 6.4, 0.1) * ANG(0, 0, rad(-35)), C.skin)
	L.part(m, "Trident", V(0.2, 6, 0.2), cf * CF(2.1, 6.5, -0.1), C.gold, { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.25 })
	L.part(m, "TridentTete", V(1.4, 0.2, 0.2), cf * CF(2.1, 9.3, -0.1), C.gold, { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.25 })
	for _, x in { -0.6, 0, 0.6 } do
		L.part(m, "TridentDent", V(0.18, 0.9, 0.18), cf * CF(2.1 + x, 9.8, -0.1), C.gold, { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.25 })
	end
	local head = cf * CF(0, 7.3, 0.2)
	L.part(m, "Tete", V(1.7, 1.7, 1.5), head, C.skin)
	for _, x in { -0.4, 0.4 } do
		L.part(m, "Oeil", V(0.35, 0.35, 0.05), head * CF(x, 0.1, -0.77), C.navy)
		L.part(m, "Cils", V(0.4, 0.1, 0.05), head * CF(x, 0.35, -0.78), C.black)
	end
	L.part(m, "Bouche", V(0.4, 0.12, 0.05), head * CF(0, -0.45, -0.77), C.red)
	L.part(m, "Cheveux", V(1.9, 0.7, 1.7), head * CF(0, 0.8, 0.05), C.coat)
	L.part(m, "Meche", V(0.5, 1.2, 0.4), head * CF(-0.75, 0.2, -0.6), C.coat)
	for k = 0, 3 do
		L.part(m, "Cheveux", V(1.8 - k * 0.1, 0.8, 0.5), head * CF(0, -0.2 - k * 0.7, 0.8 + k * 0.1), C.coat:Lerp(C.orange, k * 0.1))
	end
	L.part(m, "Couronne", V(1.3, 0.35, 1.1), head * CF(0, 1.3, 0), C.gold, { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.25 })
	for x = -1, 1 do
		L.part(m, "CouronnePointe", V(0.2, 0.35, 0.2), head * CF(x * 0.45, 1.6, -0.45), C.gold, { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.25 })
	end
	L.part(m, "Perle", V(0.35, 0.35, 0.35), head * CF(0, 1.55, -0.56), C.white, L.glow())
	return m
end


--== PASSE DE DETAILS AUTOMATIQUE ==--
-- Ajoute sur chaque bloc : veines + clous (bois), rivets (metal),
-- fissures (pierre), coutures + rustines (tissus). Les pieces ajoutees sont
-- marquees "D" pour ne jamais etre re-detaillees.

local WOODS = { C.wood, C.woodD, C.woodL, C.plank }
local METALS = { C.iron, C.ironD }
local STONES = { C.stone }
local CLOTHS = { C.sail, C.sailD, C.paper }

local function near(col, list)
	for _, c in list do
		if math.abs(col.R - c.R) + math.abs(col.G - c.G) + math.abs(col.B - c.B) < 0.12 then
			return true
		end
	end
	return false
end

local function mark(p)
	p:SetAttribute("D", true)
	return p
end

-- faces : { normale locale, axe U, axe V } pour +Y, -Z, +Z, -X, +X
local FACES = {
	{ V(0, 1, 0), "X", "Z" },
	{ V(0, 0, -1), "X", "Y" },
	{ V(0, 0, 1), "X", "Y" },
	{ V(-1, 0, 0), "Z", "Y" },
	{ V(1, 0, 0), "Z", "Y" },
}

local function axisVec(a) return a == "X" and V(1, 0, 0) or (a == "Y" and V(0, 1, 0) or V(0, 0, 1)) end

local function faceFrame(part, normal)
	local s = part.Size
	local off = V(normal.X * s.X / 2, normal.Y * s.Y / 2, normal.Z * s.Z / 2)
	return part.CFrame * CF(off + normal * 0.02)
end

local function stripe(parent, part, normal, uAxis, vAxis, u, v, len, along, col, thick)
	-- trait fin sur une face, oriente selon `along` ("U" ou "V")
	local sz = V(0, 0, 0)
	local w = thick or 0.07
	local function set(axis, val)
		if axis == "X" then sz = V(val, sz.Y, sz.Z) elseif axis == "Y" then sz = V(sz.X, val, sz.Z) else sz = V(sz.X, sz.Y, val) end
	end
	set(uAxis, along == "U" and len or w)
	set(vAxis, along == "V" and len or w)
	local nAxis = normal.X ~= 0 and "X" or (normal.Y ~= 0 and "Y" or "Z")
	set(nAxis, 0.04)
	local cf = faceFrame(part, normal) * CF(axisVec(uAxis) * u + axisVec(vAxis) * v)
	return mark(L.part(parent, "Detail", sz, cf, col, { CanCollide = false, CanQuery = false, CastShadow = false }))
end

local function stud(parent, part, normal, uAxis, vAxis, u, v, d, col, props)
	local cf = faceFrame(part, normal) * CF(axisVec(uAxis) * u + axisVec(vAxis) * v)
	local p = { CanCollide = false, CanQuery = false, CastShadow = false }
	if props then for k, val in pairs(props) do p[k] = val end end
	return mark(L.part(parent, "Detail", V(d, d, d), cf, col, p))
end

local function dim(part, a) return a == "X" and part.Size.X or (a == "Y" and part.Size.Y or part.Size.Z) end

function P.detail(model, rng)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.ClassName == "Part" and d.Shape == Enum.PartType.Block
			and not d:GetAttribute("D") and d.Transparency < 0.2 then
			table.insert(parts, d)
		end
	end
	for _, part in parts do
		part:SetAttribute("D", true)
		local col = part.Color
		local mn = math.min(part.Size.X, part.Size.Y, part.Size.Z)
		if mn >= 0.3 then
			local parent = part.Parent
			local kind = near(col, WOODS) and "bois" or near(col, METALS) and "metal" or near(col, STONES) and "pierre" or near(col, CLOTHS) and "tissu" or nil
			if kind then
				for fi, f in FACES do
					if L.REALISTE and fi > 2 then break end
					local n, ua, va = f[1], f[2], f[3]
					local U, Vd = dim(part, ua), dim(part, va)
					if U * Vd >= 1.5 then
						if kind == "bois" and L.REALISTE then
							if U * Vd >= 5 then
								for _, cu in { -1, 1 } do
									for _, cv in { -1, 1 } do
										stud(parent, part, n, ua, va, cu * (U / 2 - 0.25), cv * (Vd / 2 - 0.25), 0.14, C.ironD)
									end
								end
							end
						elseif kind == "bois" then
							local along = U >= Vd and "U" or "V"
							local long, short = math.max(U, Vd), math.min(U, Vd)
							local lines = math.clamp(math.floor(short / 0.7), 1, 4)
							local dark = col:Lerp(C.black, 0.28)
							for i = 1, lines do
								local o = (i / (lines + 1) - 0.5) * short
								local len = long * rng:NextNumber(0.55, 0.92)
								local shift = rng:NextNumber(-0.2, 0.2) * (long - len)
								if along == "U" then
									stripe(parent, part, n, ua, va, shift, o, len, "U", dark)
								else
									stripe(parent, part, n, ua, va, o, shift, len, "V", dark)
								end
							end
							if U * Vd >= 3 then
								for _, cu in { -1, 1 } do
									for _, cv in { -1, 1 } do
										stud(parent, part, n, ua, va, cu * (U / 2 - 0.25), cv * (Vd / 2 - 0.25), 0.16, C.ironD)
									end
								end
							end
							if rng:NextNumber() < 0.25 then
								stud(parent, part, n, ua, va, rng:NextNumber(-0.3, 0.3) * U, rng:NextNumber(-0.3, 0.3) * Vd, 0.3, col:Lerp(C.black, 0.4))
							end
						elseif kind == "metal" then
							local step = L.REALISTE and 1.6 or 0.9
							local nu = math.max(1, math.floor(U / step))
							for i = 0, nu do
								local u = -U / 2 + 0.2 + (U - 0.4) * i / math.max(nu, 1)
								stud(parent, part, n, ua, va, u, Vd / 2 - 0.2, 0.18, col:Lerp(C.white, 0.35), SHINY)
								stud(parent, part, n, ua, va, u, -Vd / 2 + 0.2, 0.18, col:Lerp(C.white, 0.35), SHINY)
							end
						elseif kind == "pierre" and not L.REALISTE then
							local c = faceFrame(part, n)
							local dark = col:Lerp(C.black, 0.35)
							for _ = 1, 2 do
								local len = math.min(U, Vd) * rng:NextNumber(0.4, 0.8)
								local line = stripe(parent, part, n, ua, va, rng:NextNumber(-0.25, 0.25) * U, rng:NextNumber(-0.25, 0.25) * Vd, len, "U", dark, 0.08)
								line.CFrame = line.CFrame * CFrame.fromAxisAngle(n, rng:NextNumber(-0.8, 0.8))
							end
							if n.Y > 0 and rng:NextNumber() < 0.5 then
								stud(parent, part, n, ua, va, rng:NextNumber(-0.3, 0.3) * U, rng:NextNumber(-0.3, 0.3) * Vd, 0.4, Color3.fromRGB(90, 160, 70))
							end
						elseif kind == "tissu" then
							local dark = col:Lerp(C.woodD, 0.35)
							stripe(parent, part, n, ua, va, 0, Vd / 2 - 0.15, U * 0.95, "U", dark, 0.06)
							stripe(parent, part, n, ua, va, 0, -Vd / 2 + 0.15, U * 0.95, "U", dark, 0.06)
							if U * Vd >= 4 and rng:NextNumber() < 0.6 then
								local pu, pv = rng:NextNumber(-0.25, 0.25) * U, rng:NextNumber(-0.25, 0.25) * Vd
								local ps = math.min(U, Vd) * 0.25
								local patch = stud(parent, part, n, ua, va, pu, pv, ps, col:Lerp(C.woodL, 0.3))
								local nAxis = n.X ~= 0 and "X" or (n.Y ~= 0 and "Y" or "Z")
								patch.Size = V(nAxis == "X" and 0.04 or ps, nAxis == "Y" and 0.04 or ps, nAxis == "Z" and 0.04 or ps)
							end
						end
					end
				end
			end
		end
	end
	return model
end

-- Chaque modele passe par la passe de details.
for name, fn in pairs(P) do
	if name ~= "detail" then
		P[name] = function(parent, cf, rng, ...)
			local m = fn(parent, cf, rng, ...)
			if typeof(m) == "Instance" then
				P.detail(m, rng)
			end
			return m
		end
	end
end

return P
