-- Versions haute qualite des modeles d'origine de la Pirate Map.
-- Chaque fonction : (parent, cf au sol, rng, s = echelle) -> Model, face vers -Z.
local L = require(script.Parent.PirateBuildLib)
local C = L.C
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local TAU = math.pi * 2

local H = {}
local SHINY = { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.25 }

local function sc(s) return function(x, y, z) return V(x, y, z) * s end end

function H.Crab(parent, cf, rng, s)
	s = s or 1
	local v = sc(s)
	local red, redD, redL = C.red, C.red:Lerp(C.black, 0.3), C.red:Lerp(C.white, 0.3)
	local m = L.model("Crab", parent, cf)
	local b = cf * CF(0, 1.3 * s, 0)
	L.part(m, "Ventre", v(3, 0.6, 2.2), b * CF(0, -0.35 * s, 0), C.sand)
	L.part(m, "Carapace", v(3.4, 0.9, 2.6), b, red)
	L.part(m, "Dos", v(2.6, 0.5, 2), b * CF(0, 0.65 * s, 0.1 * s), redL)
	L.part(m, "Bosse", v(1.4, 0.3, 1), b * CF(0, 1 * s, 0.1 * s), red)
	for _, x in { -1.2, 1.2 } do
		L.part(m, "Pointe", v(0.5, 0.4, 0.5), b * CF(x * s, 0.1 * s, -1.2 * s), redD)
	end
	for _, x in { -0.6, 0.6 } do
		L.part(m, "Tige", v(0.25, 1, 0.25), b * CF(x * s, 0.9 * s, -1 * s), redD)
		L.part(m, "Oeil", v(0.55, 0.55, 0.55), b * CF(x * s, 1.55 * s, -1 * s), C.white)
		L.part(m, "Pupille", v(0.3, 0.3, 0.1), b * CF(x * s, 1.58 * s, -1.3 * s), C.black)
	end
	L.part(m, "Bouche", v(0.8, 0.12, 0.1), b * CF(0, -0.1 * s, -1.32 * s), C.dark)
	for _, side in { -1, 1 } do
		for i = -1, 1 do
			local hip = b * CF(side * 1.7 * s, -0.1 * s, i * 0.75 * s)
			local knee = b * CF(side * 2.6 * s, 0.4 * s, i * 0.95 * s)
			local foot = cf * CF(side * 3.1 * s, 0.1 * s, i * 1.1 * s)
			L.bar(m, "Patte", hip.Position, knee.Position, 0.3 * s, redD)
			L.bar(m, "Patte", knee.Position, foot.Position, 0.25 * s, red)
		end
		local sh = b * CF(side * 1.5 * s, 0, -1.1 * s)
		local el = b * CF(side * 2.3 * s, 0.6 * s, -2 * s)
		L.bar(m, "Bras", sh.Position, el.Position, 0.45 * s, redD)
		local claw = el * CF(0, 0.2 * s, -0.8 * s)
		L.part(m, "Pince", v(1.3, 1, 1.4), claw, red)
		L.part(m, "PinceHaut", v(0.5, 0.4, 1.3), claw * CF(side * -0.2 * s, 0.55 * s, -1 * s) * ANG(rad(20), 0, 0), redL)
		L.part(m, "PinceBas", v(0.5, 0.35, 1.1), claw * CF(side * -0.2 * s, -0.3 * s, -0.95 * s) * ANG(rad(-12), 0, 0), redD)
	end
	return m
end

function H.Palm(parent, cf, rng, s)
	s = s or 1
	local m = L.model("Palm", parent, cf)
	local lean = rng:NextNumber(-12, 12)
	local p = cf * ANG(0, rng:NextNumber(0, TAU), 0)
	L.part(m, "Butte", V(3.4, 0.6, 3.4) * s, cf * CF(0, 0.3 * s, 0), C.sand:Lerp(C.woodD, 0.1))
	local segs = 9
	for i = 1, segs do
		local w = (1.5 - i * 0.05) * s
		p = p * CF(0, 1.3 * s, 0) * ANG(0, 0, rad(lean / segs))
		L.part(m, "Tronc", V(w, 1.35 * s, w), p, (i % 2 == 0) and C.wood or C.woodL)
		L.part(m, "Anneau", V(w + 0.15 * s, 0.25 * s, w + 0.15 * s), p * CF(0, -0.6 * s, 0), C.woodD)
	end
	local top = p * CF(0, 0.8 * s, 0)
	for i = 0, 2 do
		local a = i / 3 * TAU
		L.part(m, "NoixCoco", V(0.8, 0.8, 0.8) * s, top * CF(math.cos(a) * 0.6 * s, -0.4 * s, math.sin(a) * 0.6 * s), C.woodD)
	end
	local greens = { Color3.fromRGB(60, 190, 70), Color3.fromRGB(40, 150, 60), Color3.fromRGB(110, 220, 90) }
	local n = 7
	for i = 0, n - 1 do
		local a = i / n * TAU + rng:NextNumber(-0.2, 0.2)
		local f = top * ANG(0, a, 0)
		local droop = 0
		local q = f
		for k = 1, 6 do
			droop += 7 + k * 3
			q = q * ANG(rad(-(7 + k * 3)), 0, 0) * CF(0, 0, -1.1 * s)
			local w = (1.9 - k * 0.22) * s
			L.part(m, "Palme", V(w, 0.15 * s, 1.2 * s), q, greens[(i + k) % 3 + 1])
			L.part(m, "Nervure", V(0.15 * s, 0.2 * s, 1.2 * s), q * CF(0, 0.08 * s, 0), greens[2])
		end
	end
	return m
end

function H.Barrel(parent, cf, rng, s)
	s = s or 1
	local m = L.model("Barrel", parent, cf)
	local ws = { 2.5, 2.8, 3, 3.05, 3, 2.8, 2.5 }
	for i, w in ws do
		L.vcyl(m, "Douve", 0.66 * s, w * s, cf * CF(0, (0.33 + (i - 1) * 0.66) * s, 0), (i % 2 == 0) and C.wood or C.woodD)
	end
	for _, y in { 0.45, 1.5, 3.1, 4.15 } do
		local w = (y == 1.5 or y == 3.1) and 3.15 or 2.7
		L.vcyl(m, "Cercle", 0.22 * s, w * s, cf * CF(0, y * s, 0), C.iron)
	end
	L.vcyl(m, "Couvercle", 0.12 * s, 2.35 * s, cf * CF(0, 4.62 * s, 0), C.woodL)
	L.part(m, "Bonde", V(0.4, 0.15, 0.4) * s, cf * CF(0.5 * s, 4.7 * s, 0.3 * s), C.woodD)
	L.cyl(m, "Robinet", 0.6 * s, 0.35 * s, cf * CF(0, 1.1 * s, -1.6 * s) * ANG(0, rad(90), 0), C.gold, SHINY)
	L.part(m, "RobinetCle", V(0.5, 0.12, 0.12) * s, cf * CF(0, 1.3 * s, -1.85 * s), C.gold, SHINY)
	return m
end

function H.Crate(parent, cf, rng, s)
	s = s or 1
	local m = L.model("Crate", parent, cf)
	local c = cf * CF(0, 1.6 * s, 0)
	L.part(m, "Caisse", V(3.2, 3.2, 3.2) * s, c, C.plank)
	for _, face in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local fc = c * CF(face[1] * 1.62 * s, 0, face[2] * 1.62 * s) * ANG(0, face[1] ~= 0 and rad(90) or 0, 0)
		for _, x in { -1.45, 1.45 } do
			L.part(m, "Cadre", V(0.3, 3.2, 0.1) * s, fc * CF(x * s, 0, 0), C.woodD)
		end
		for _, y in { -1.45, 1.45 } do
			L.part(m, "Cadre", V(3.2, 0.3, 0.1) * s, fc * CF(0, y * s, 0), C.woodD)
		end
		L.part(m, "Diagonale", V(0.3, 3.8, 0.08) * s, fc * ANG(0, 0, rad(45)), C.woodD)
		L.part(m, "Planche", V(2.6, 0.06, 0.06) * s, fc * CF(0, 0.5 * s, 0), C.woodD)
		L.part(m, "Planche", V(2.6, 0.06, 0.06) * s, fc * CF(0, -0.5 * s, 0), C.woodD)
	end
	L.part(m, "Dessus", V(3, 0.1, 3) * s, c * CF(0, 1.62 * s, 0), C.woodL)
	return m
end

function H.Chest(parent, cf, rng, s)
	s = s or 1
	local m = L.model("Chest", parent, cf)
	local b = cf * CF(0, 1.2 * s, 0)
	L.part(m, "Coffre", V(5, 2.4, 3.2) * s, b, C.wood)
	for _, x in { -1.9, 0, 1.9 } do
		L.part(m, "Bande", V(0.35, 2.5, 3.3) * s, b * CF(x * s, 0, 0), C.gold, SHINY)
	end
	L.part(m, "Fond", V(5.1, 0.3, 3.3) * s, b * CF(0, -1.1 * s, 0), C.woodD)
	local hinge = b * CF(0, 1.2 * s, 1.6 * s) * ANG(rad(55), 0, 0)
	L.part(m, "Couvercle", V(5, 1.1, 3.2) * s, hinge * CF(0, 0.55 * s, -1.6 * s), C.woodL)
	for _, x in { -1.9, 0, 1.9 } do
		L.part(m, "BandeCouvercle", V(0.35, 1.2, 3.3) * s, hinge * CF(x * s, 0.55 * s, -1.6 * s), C.gold, SHINY)
	end
	L.part(m, "Or", V(4.6, 0.6, 2.8) * s, b * CF(0, 1.1 * s, 0), C.gold, SHINY)
	L.part(m, "Or", V(3, 0.6, 2) * s, b * CF(0.3 * s, 1.6 * s, 0), C.gold, SHINY)
	for _, g in { { -1.3, C.ruby }, { 0.8, C.emerald }, { 1.6, C.sapphire } } do
		L.part(m, "Gemme", V(0.5, 0.5, 0.5) * s, b * CF(g[1] * s, 1.8 * s, rng:NextNumber(-0.6, 0.6) * s) * ANG(0.6, 0.7, 0), g[2], L.glow())
	end
	L.part(m, "Serrure", V(0.7, 0.8, 0.2) * s, b * CF(0, 0.5 * s, -1.7 * s), C.gold, SHINY)
	L.part(m, "Trou", V(0.15, 0.3, 0.05) * s, b * CF(0, 0.45 * s, -1.81 * s), C.black)
	for _ = 1, 6 do
		local a = rng:NextNumber(0, TAU)
		L.part(m, "Piece", V(0.5, 0.12, 0.5) * s, cf * CF(math.cos(a) * 3 * s, 0.06 * s, math.sin(a) * 2.4 * s) * ANG(0, a, 0), C.gold, SHINY)
	end
	L.sparkles(L.anchor(m, "Eclat", b * CF(0, 1.8 * s, 0)), C.yellow, 4, 0.5 * s)
	return m
end

function H.Skeleton(parent, cf, rng, s)
	s = s or 1
	local bone = Color3.fromRGB(236, 232, 214)
	local m = L.model("Skeleton", parent, cf)
	for _, x in { -0.6, 0.6 } do
		L.part(m, "Pied", V(0.6, 0.3, 1) * s, cf * CF(x * s, 0.15 * s, -0.2 * s), bone)
		L.part(m, "Tibia", V(0.3, 2, 0.3) * s, cf * CF(x * s, 1.3 * s, 0), bone)
		L.part(m, "Genou", V(0.5, 0.4, 0.5) * s, cf * CF(x * s, 2.4 * s, 0), bone)
		L.part(m, "Femur", V(0.35, 1.8, 0.35) * s, cf * CF(x * s, 3.4 * s, 0), bone)
	end
	L.part(m, "Bassin", V(1.8, 0.7, 0.9) * s, cf * CF(0, 4.5 * s, 0), bone)
	L.part(m, "Colonne", V(0.35, 2.6, 0.35) * s, cf * CF(0, 5.9 * s, 0.25 * s), bone)
	for i = 0, 3 do
		local w = (2 - math.abs(i - 1.2) * 0.3) * s
		L.part(m, "Cote", V(w, 0.22 * s, 1.3 * s), cf * CF(0, (5.4 + i * 0.45) * s, 0), bone)
	end
	L.part(m, "Sternum", V(0.3, 1.6, 0.1) * s, cf * CF(0, 6.1 * s, -0.66 * s), bone)
	L.part(m, "Epaules", V(2.6, 0.35, 0.5) * s, cf * CF(0, 7.3 * s, 0), bone)
	for _, x in { -1, 1 } do
		local sh = cf * CF(x * 1.35 * s, 7.2 * s, 0)
		local el = cf * CF(x * 1.6 * s, 5.8 * s, -0.3 * s)
		local wr = cf * CF(x * 1.5 * s, 4.6 * s, -0.8 * s)
		L.bar(m, "Humerus", sh.Position, el.Position, 0.28 * s, bone)
		L.bar(m, "AvantBras", el.Position, wr.Position, 0.24 * s, bone)
		L.part(m, "Main", V(0.4, 0.5, 0.4) * s, wr, bone)
	end
	local sw = cf * CF(1.5 * s, 4.6 * s, -0.8 * s)
	L.part(m, "Garde", V(0.8, 0.2, 0.2) * s, sw, C.gold, SHINY)
	L.part(m, "Lame", V(0.2, 0.15, 2.6) * s, sw * CF(0, 0, -1.4 * s), C.metalL, SHINY)
	local head = cf * CF(0, 8.4 * s, 0)
	L.part(m, "Crane", V(1.8, 1.6, 1.7) * s, head, bone)
	L.part(m, "Machoire", V(1.3, 0.5, 1.2) * s, head * CF(0, -1 * s, -0.15 * s), bone)
	for _, x in { -0.4, 0.4 } do
		L.part(m, "Orbite", V(0.5, 0.5, 0.1) * s, head * CF(x * s, 0.1 * s, -0.86 * s), C.black)
	end
	L.part(m, "Nez", V(0.2, 0.3, 0.1) * s, head * CF(0, -0.35 * s, -0.86 * s), C.black)
	for i = -2, 2 do
		L.part(m, "Dent", V(0.15, 0.2, 0.05) * s, head * CF(i * 0.2 * s, -0.8 * s, -0.78 * s), C.dark)
	end
	L.part(m, "Bandana", V(1.9, 0.6, 1.8) * s, head * CF(0, 0.7 * s, 0), C.bandana)
	L.part(m, "Noeud", V(0.4, 0.4, 0.7) * s, head * CF(0, 0.6 * s, 1 * s), C.bandana)
	return m
end

function H.Cannon(parent, cf, rng, s)
	s = s or 1
	local m = L.model("Cannon", parent, cf)
	L.part(m, "Affut", V(2.6, 1, 4.6) * s, cf * CF(0, 1.1 * s, 0.3 * s), C.wood)
	for _, x in { -1.2, 1.2 } do
		L.part(m, "Flasque", V(0.4, 1.6, 4) * s, cf * CF(x * s, 1.8 * s, 0.4 * s), C.woodD)
	end
	for _, x in { -1.5, 1.5 } do
		for _, z in { -1.4, 2 } do
			L.cyl(m, "Roue", 0.4 * s, 1.4 * s, cf * CF(x * s, 0.7 * s, z * s), C.woodD)
			L.cyl(m, "Moyeu", 0.5 * s, 0.4 * s, cf * CF(x * s, 0.7 * s, z * s), C.iron)
		end
	end
	local barrel = cf * CF(0, 2.4 * s, -0.4 * s) * ANG(rad(8), rad(90), 0)
	L.cyl(m, "Fut", 5 * s, 1.4 * s, barrel, C.ironD, SHINY)
	L.cyl(m, "Culasse", 0.8 * s, 1.7 * s, barrel * CF(-2.2 * s, 0, 0), C.iron, SHINY)
	L.cyl(m, "Bouche", 0.6 * s, 1.7 * s, barrel * CF(2.3 * s, 0, 0), C.iron, SHINY)
	L.cyl(m, "Ame", 0.1 * s, 0.9 * s, barrel * CF(2.62 * s, 0, 0), C.black)
	L.cyl(m, "Bouton", 0.5 * s, 0.6 * s, barrel * CF(-2.8 * s, 0, 0), C.iron)
	L.part(m, "Meche", V(0.12, 0.6, 0.12) * s, cf * CF(0, 3.3 * s, 1.4 * s), C.rope)
	local spark = L.part(m, "Etincelle", V(0.25, 0.25, 0.25) * s, cf * CF(0, 3.65 * s, 1.4 * s), C.orange, L.glow())
	L.sparkles(spark, C.orange, 6, 0.3 * s)
	for i = 0, 2 do
		L.ball(m, "Boulet", 0.8 * s, cf * CF((2.4 + (i % 2) * 0.8) * s, (0.4 + (i == 2 and 0.65 or 0)) * s, (1.6 + (i == 2 and 0.4 or i * 0.8)) * s), C.ironD, SHINY)
	end
	return m
end

function H.Bonfire(parent, cf, rng, s)
	s = s or 1
	local m = L.model("Bonfire", parent, cf)
	for i = 0, 9 do
		local a = i / 10 * TAU
		L.part(m, "Pierre", V(1.1, 0.8, 1) * s, cf * CF(math.cos(a) * 2 * s, 0.4 * s, math.sin(a) * 2 * s) * ANG(0, -a, rng:NextNumber(-0.2, 0.2)), (i % 2 == 0) and C.stone or C.stone:Lerp(C.black, 0.2))
	end
	L.part(m, "Cendres", V(3, 0.2, 3) * s, cf * CF(0, 0.1 * s, 0), C.dark)
	for i = 0, 3 do
		local a = i / 4 * TAU + 0.4
		local base = cf * CF(math.cos(a) * 1.2 * s, 0.4 * s, math.sin(a) * 1.2 * s)
		L.bar(m, "Buche", base.Position, (cf * CF(0, 2 * s, 0)).Position, 0.5 * s, (i % 2 == 0) and C.woodD or C.wood)
	end
	L.part(m, "Braise", V(1.6, 0.4, 1.6) * s, cf * CF(0, 0.4 * s, 0), C.orange, L.glow())
	L.part(m, "Flamme", V(1.6, 1.4, 1.6) * s, cf * CF(0, 1.2 * s, 0) * ANG(0, rad(20), 0), C.orange, L.glow({ Transparency = 0.15, CanCollide = false }))
	L.part(m, "Flamme", V(1.1, 1.3, 1.1) * s, cf * CF(0.1 * s, 2.3 * s, 0) * ANG(0, rad(50), 0), C.yellow, L.glow({ Transparency = 0.15, CanCollide = false }))
	L.part(m, "Flamme", V(0.6, 0.9, 0.6) * s, cf * CF(-0.1 * s, 3.2 * s, 0.1 * s) * ANG(0, rad(10), 0), C.white:Lerp(C.yellow, 0.5), L.glow({ Transparency = 0.2, CanCollide = false }))
	local fx = L.anchor(m, "Feu", cf * CF(0, 1.5 * s, 0), V(1.5, 1, 1.5) * s)
	L.emitter(fx, {
		Name = "Feu", Texture = "rbxasset://textures/particles/fire_main.dds", LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(C.yellow, C.orange), Size = L.seq({ 0, 1.4 * s, 1, 0.2 }), Transparency = L.seq({ 0, 0.3, 1, 1 }),
		Lifetime = NumberRange.new(0.6, 1), Rate = 25, Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(10, 10),
	})
	L.sparkles(fx, C.orange, 6, 0.3 * s)
	L.light(fx, C.orange, 22 * s, 2)
	for _, a in { rad(30), rad(200) } do
		local log = cf * CF(math.cos(a) * 4.5 * s, 0.5 * s, math.sin(a) * 4.5 * s) * ANG(0, -a + math.pi / 2, 0)
		L.part(m, "Banc", V(3.4, 1, 1) * s, log, C.wood)
		L.part(m, "BancBout", V(0.1, 0.9, 0.9) * s, log * CF(1.72 * s, 0, 0), C.woodL)
		L.part(m, "BancBout", V(0.1, 0.9, 0.9) * s, log * CF(-1.72 * s, 0, 0), C.woodL)
	end
	return m
end

function H.TikiHut(parent, cf, rng, s)
	s = s or 1
	local m = L.model("TikiHut", parent, cf)
	L.part(m, "Plancher", V(10, 0.6, 9) * s, cf * CF(0, 0.3 * s, 0), C.woodL)
	for i = -4, 4 do
		L.part(m, "Latte", V(0.08, 0.62, 9) * s, cf * CF(i * 1.1 * s, 0.31 * s, 0), C.woodD)
	end
	for _, x in { -4.4, 4.4 } do
		for _, z in { -3.9, 3.9 } do
			for k = 0, 3 do
				L.part(m, "Bambou", V(0.7, 1.7, 0.7) * s, cf * CF(x * s, (1.4 + k * 1.75) * s, z * s), (k % 2 == 0) and C.woodL or C.sand:Lerp(C.woodL, 0.4))
				L.part(m, "Noeud", V(0.8, 0.2, 0.8) * s, cf * CF(x * s, (2.3 + k * 1.75) * s, z * s), C.woodD)
			end
		end
	end
	local straw, strawD = Color3.fromRGB(226, 190, 110), Color3.fromRGB(190, 150, 80)
	for i = 0, 5 do
		local w = (12 - i * 1.9) * s
		local d = (11 - i * 1.7) * s
		L.part(m, "Toit", V(w, 0.8 * s, d), cf * CF(0, (8 + i * 0.75) * s, 0), (i % 2 == 0) and straw or strawD)
	end
	for i = -5, 5 do
		L.part(m, "Frange", V(0.9, 0.9, 0.15) * s, cf * CF(i * 1.05 * s, 7.3 * s, -5.45 * s) * ANG(0, 0, rng:NextNumber(-0.15, 0.15)), strawD)
	end
	L.part(m, "Comptoir", V(8, 2.6, 1.4) * s, cf * CF(0, 1.9 * s, -3 * s), C.wood)
	L.part(m, "ComptoirDessus", V(8.6, 0.3, 1.8) * s, cf * CF(0, 3.3 * s, -3 * s), C.woodD)
	for i = -3, 3 do
		L.part(m, "Bambou", V(0.6, 2.6, 0.2) * s, cf * CF(i * 1.1 * s, 1.9 * s, -3.75 * s), (i % 2 == 0) and C.woodL or C.sand:Lerp(C.woodL, 0.4))
	end
	for i, col in { C.emerald, C.orange, C.kraken } do
		L.part(m, "Verre", V(0.5, 0.8, 0.5) * s, cf * CF((-2.5 + i * 1.3) * s, 3.85 * s, -3 * s), col, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.3 })
		L.part(m, "Paille", V(0.1, 0.8, 0.1) * s, cf * CF((-2.4 + i * 1.3) * s, 4.4 * s, -3 * s) * ANG(0, 0, 0.3), C.pink)
	end
	local mask = cf * CF(0, 6.4 * s, -4.1 * s)
	L.part(m, "Masque", V(2, 2.6, 0.4) * s, mask, C.woodD)
	for _, x in { -0.45, 0.45 } do
		L.part(m, "Oeil", V(0.5, 0.4, 0.1) * s, mask * CF(x * s, 0.5 * s, -0.22 * s), C.yellow, L.glow())
	end
	L.part(m, "Bouche", V(1.2, 0.5, 0.1) * s, mask * CF(0, -0.6 * s, -0.22 * s), C.white)
	L.part(m, "Sourcil", V(1.8, 0.3, 0.15) * s, mask * CF(0, 1 * s, -0.22 * s), C.red)
	for _, x in { -5.6, 5.6 } do
		local t = cf * CF(x * s, 0, -5 * s)
		L.part(m, "Torche", V(0.4, 4.5, 0.4) * s, t * CF(0, 2.25 * s, 0), C.woodL)
		L.part(m, "Coupe", V(0.8, 0.5, 0.8) * s, t * CF(0, 4.6 * s, 0), C.woodD)
		local fl = L.part(m, "Flamme", V(0.5, 0.8, 0.5) * s, t * CF(0, 5.2 * s, 0), C.orange, L.glow({ CanCollide = false }))
		L.light(fl, C.orange, 14 * s, 1.4)
	end
	return m
end

function H.FlagPole(parent, cf, rng, s)
	s = s or 1
	local m = L.model("FlagPole", parent, cf)
	L.part(m, "Socle", V(2.4, 0.6, 2.4) * s, cf * CF(0, 0.3 * s, 0), C.stone)
	L.part(m, "Mat", V(0.5, 16, 0.5) * s, cf * CF(0, 8.4 * s, 0), C.woodD)
	L.part(m, "Boule", V(0.8, 0.8, 0.8) * s, cf * CF(0, 16.8 * s, 0), C.gold, SHINY)
	local segs = 6
	for i = 0, segs - 1 do
		local x = (0.6 + i * 0.9) * s
		local wave = math.sin(i * 1.1) * 0.35 * s
		L.part(m, "Drapeau", V(0.92, 3.4, 0.1) * s, cf * CF(x, 14.3 * s, wave), C.black)
	end
	local fc = cf * CF(2.9 * s, 14.4 * s, -0.1 * s)
	L.part(m, "Crane", V(1.3, 1.1, 0.12) * s, fc, C.white)
	for _, x in { -0.3, 0.3 } do
		L.part(m, "Orbite", V(0.3, 0.3, 0.14) * s, fc * CF(x * s, 0.1 * s, 0), C.black)
	end
	L.part(m, "Os", V(2.6, 0.3, 0.12) * s, fc * CF(0, -1 * s, 0) * ANG(0, 0, rad(25)), C.white)
	L.part(m, "Os", V(2.6, 0.3, 0.12) * s, fc * CF(0, -1 * s, 0) * ANG(0, 0, rad(-25)), C.white)
	L.bar(m, "Corde", (cf * CF(0.35 * s, 16 * s, 0)).Position, (cf * CF(0.35 * s, 1.5 * s, 0)).Position, 0.1 * s, C.rope)
	L.part(m, "Taquet", V(0.3, 0.6, 0.3) * s, cf * CF(0.45 * s, 1.5 * s, 0), C.iron)
	return m
end

function H.ShipWheel(parent, cf, rng, s)
	s = s or 1
	local m = L.model("ShipWheel", parent, cf)
	L.part(m, "Socle", V(3, 0.5, 2.4) * s, cf * CF(0, 0.25 * s, 0), C.woodD)
	L.part(m, "Pied", V(1.2, 4.2, 1.2) * s, cf * CF(0, 2.6 * s, 0.4 * s), C.wood)
	L.part(m, "Tete", V(1.6, 1, 1.6) * s, cf * CF(0, 4.8 * s, 0.4 * s), C.woodD)
	local hub = cf * CF(0, 5.4 * s, -0.4 * s)
	L.cyl(m, "Axe", 0.8 * s, 0.6 * s, hub * CF(0, 0, 0.4 * s) * ANG(0, rad(90), 0), C.iron)
	L.cyl(m, "Moyeu", 0.6 * s, 1.2 * s, hub * ANG(0, rad(90), 0), C.gold, SHINY)
	local R = 2.2 * s
	local n = 16
	for i = 0, n - 1 do
		local a = i / n * TAU
		L.part(m, "Jante", V(0.9 * s, 0.35 * s, 0.35 * s), hub * CF(math.cos(a) * R, math.sin(a) * R, 0) * ANG(0, 0, a + math.pi / 2), C.wood)
	end
	for i = 0, 7 do
		local a = i / 8 * TAU
		L.part(m, "Rayon", V(R * 2 / 2, 0.25 * s, 0.25 * s), hub * CF(math.cos(a) * R / 2, math.sin(a) * R / 2, 0) * ANG(0, 0, a), C.woodL)
		L.part(m, "Poignee", V(1.2 * s, 0.35 * s, 0.35 * s), hub * CF(math.cos(a) * (R + 0.7 * s), math.sin(a) * (R + 0.7 * s), 0) * ANG(0, 0, a), C.woodD)
		L.part(m, "PoigneeBout", V(0.45, 0.45, 0.45) * s, hub * CF(math.cos(a) * (R + 1.3 * s), math.sin(a) * (R + 1.3 * s), 0), C.gold, SHINY)
	end
	return m
end

function H.Anchor(parent, cf, rng, s)
	s = s or 1
	local m = L.model("Anchor", parent, cf)
	local iron = C.ironD
	local base = cf * CF(0, 0, 0) * ANG(rad(-12), 0, 0)
	L.part(m, "Tige", V(0.7, 7, 0.7) * s, base * CF(0, 4.2 * s, 0), iron, SHINY)
	L.part(m, "Jas", V(4, 0.5, 0.5) * s, base * CF(0, 6.8 * s, 0), C.woodD)
	for i = 0, 7 do
		local a = i / 8 * TAU
		L.part(m, "Anneau", V(0.5, 0.3, 0.3) * s, base * CF(math.cos(a) * 0.65 * s, (8.2 + math.sin(a) * 0.65) * s, 0) * ANG(0, 0, a + math.pi / 2), iron, SHINY)
	end
	local steps = 6
	for side = -1, 1, 2 do
		for i = 0, steps do
			local a = rad(180 - i * 12)
			local p = base * CF(side * math.cos(a) * -2.2 * s, (1.6 + math.sin(a - math.pi) * -1 + 0) * s, 0)
			L.part(m, "Bras", V(0.7, 0.7, 0.7) * s, base * CF(side * (i / steps) * 2.4 * s, (0.8 + (i / steps) ^ 2 * 2) * s, 0), iron, SHINY)
		end
		L.wedge(m, "Patte", V(0.4, 1.4, 1.2) * s, base * CF(side * 2.5 * s, 3.3 * s, 0) * ANG(0, rad(90) * side, 0), iron, SHINY)
	end
	L.part(m, "Couronne", V(1.2, 0.9, 0.9) * s, base * CF(0, 0.7 * s, 0), iron, SHINY)
	for i = 0, 5 do
		L.part(m, "Maillon", V(0.35, 0.8, 0.5) * s, cf * CF((0.6 + i * 0.6) * s, 0.25 * s, (1.2 + i * 0.35) * s) * ANG(0, 0, rad(90 * (i % 2))), C.iron, SHINY)
	end
	return m
end

function H.Rowboat(parent, cf, rng, s)
	s = s or 1
	local m = L.model("Rowboat", parent, cf)
	L.part(m, "Fond", V(3, 0.5, 8) * s, cf * CF(0, 0.3 * s, 0), C.woodD)
	for _, x in { -1.7, 1.7 } do
		L.part(m, "Bord", V(0.4, 1.4, 8) * s, cf * CF(x * s, 1.1 * s, 0), C.wood)
		L.part(m, "Liseré", V(0.5, 0.2, 8.1) * s, cf * CF(x * s, 1.85 * s, 0), C.woodL)
	end
	L.part(m, "Poupe", V(3.8, 1.4, 0.4) * s, cf * CF(0, 1.1 * s, 4 * s), C.wood)
	for i = 0, 2 do
		L.part(m, "Proue", V((3 - i * 1) * s, 1.4 * s, 0.8 * s), cf * CF(0, 1.1 * s, (-4.4 - i * 0.7) * s), (i % 2 == 0) and C.wood or C.woodD)
	end
	for _, z in { -1.5, 1.5 } do
		L.part(m, "Banc", V(3.2, 0.3, 0.9) * s, cf * CF(0, 1.3 * s, z * s), C.woodL)
	end
	for _, side in { -1, 1 } do
		local o = cf * CF(side * 1.9 * s, 1.95 * s, 0) * ANG(0, side * rad(-20), side * rad(-18))
		L.part(m, "Tolet", V(0.3, 0.5, 0.3) * s, cf * CF(side * 1.9 * s, 2.1 * s, 0), C.iron)
		L.part(m, "Rame", V(6, 0.25, 0.25) * s, o * CF(side * 1.8 * s, 0, 0), C.woodL)
		L.part(m, "Pale", V(1.4, 0.12, 0.8) * s, o * CF(side * 5.2 * s, 0, 0), C.woodL)
	end
	L.part(m, "Lanterne", V(0.6, 0.8, 0.6) * s, cf * CF(0, 2.3 * s, 3.4 * s), C.orange, L.glow())
	return m
end

function H.Seagull(parent, cf, rng, s)
	s = s or 1
	local m = L.model("Seagull", parent, cf)
	local b = cf * CF(0, 0.5 * s, 0)
	L.part(m, "Corps", V(1, 0.9, 2.2) * s, b, C.white)
	L.part(m, "Tete", V(0.8, 0.8, 0.8) * s, b * CF(0, 0.4 * s, -1.2 * s), C.white)
	L.part(m, "Bec", V(0.3, 0.25, 0.7) * s, b * CF(0, 0.3 * s, -1.9 * s), C.orange)
	for _, x in { -0.41, 0.41 } do
		L.part(m, "Oeil", V(0.05, 0.2, 0.2) * s, b * CF(x * s, 0.55 * s, -1.4 * s), C.black)
	end
	for _, side in { -1, 1 } do
		local w = b * CF(side * 0.5 * s, 0.2 * s, 0) * ANG(0, 0, side * rad(12))
		L.part(m, "Aile", V(2.2, 0.15, 1.2) * s, w * CF(side * 1.1 * s, 0, 0), C.metalL)
		L.part(m, "AileBout", V(1.4, 0.15, 0.9) * s, w * CF(side * 2.8 * s, 0.25 * s, 0.1 * s) * ANG(0, 0, side * rad(15)), C.dark)
	end
	L.part(m, "Queue", V(0.8, 0.15, 0.7) * s, b * CF(0, 0.1 * s, 1.4 * s), C.metalL)
	return m
end

function H.Rock(parent, cf, rng, s)
	s = s or 1
	local m = L.model("Rock", parent, cf)
	for i = 1, rng:NextInteger(3, 5) do
		local sz = V(rng:NextNumber(1.6, 3), rng:NextNumber(1, 2.4), rng:NextNumber(1.6, 3)) * s
		L.part(m, "Roche", sz, cf * CF(rng:NextNumber(-1, 1) * s, sz.Y * 0.45, rng:NextNumber(-1, 1) * s) * ANG(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, TAU), rng:NextNumber(-0.2, 0.2)),
			(i == 1) and C.stone or C.stone:Lerp(i % 2 == 0 and C.black or C.white, 0.18))
	end
	if rng:NextNumber() < 0.6 then
		L.part(m, "Mousse", V(1.4, 0.2, 1.2) * s, cf * CF(0, 1.9 * s, 0), Color3.fromRGB(90, 160, 70))
	end
	return m
end

return H
