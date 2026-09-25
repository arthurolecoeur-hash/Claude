local L = require(script.Parent.GalaxyBuildLib)
local C = L.C
local V = Vector3.new
local C3 = Color3.fromRGB
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local TAU = math.pi * 2

local P = {}

local function pick(rng, t)
	return t[rng:NextInteger(1, #t)]
end

--== CIEL ==--

function P.planet(parent, cf, rng, o)
	o = o or {}
	local d = o.d or 40
	local base = o.color or C.orange
	local m = L.model("Planete", parent, cf)
	local tilt = cf * ANG(rad(o.tilt or rng:NextNumber(-25, 25)), 0, rad(rng:NextNumber(-20, 20)))
	L.ball(m, "Globe", d, tilt, base, L.sky())
	local bands = o.bands or 4
	for i = 1, bands do
		local h = (i / (bands + 1) - 0.5) * d * 0.8
		local r = math.sqrt((d / 2) ^ 2 - h ^ 2)
		local col = (i % 2 == 0) and (o.color2 or base:Lerp(C.white, 0.35)) or base:Lerp(C.black, 0.25)
		L.cyl(m, "Bande", d * rng:NextNumber(0.04, 0.09), r * 2 + 0.3, tilt * CF(0, h, 0) * ANG(0, 0, rad(90)), col, L.sky())
	end
	if o.ring ~= false then
		local rc = o.ringColor or C.gold
		L.cyl(m, "Anneau", 0.3, d * 2.1, tilt * ANG(0, 0, rad(90)), rc, L.sky({ Transparency = 0.45 }))
		L.cyl(m, "AnneauExt", 0.2, d * 2.6, tilt * ANG(0, 0, rad(90)), rc:Lerp(C.white, 0.4), L.sky({ Transparency = 0.7 }))
		L.cyl(m, "AnneauLueur", 0.15, d * 1.7, tilt * ANG(0, 0, rad(90)), rc, L.glow(L.sky({ Transparency = 0.6 })))
	end
	L.ball(m, "Halo", d * 1.12, tilt, base:Lerp(C.white, 0.5), L.glow(L.sky({ Transparency = 0.88 })))
	for _ = 1, (o.moons or 0) do
		local a = rng:NextNumber(0, TAU)
		local md = d * rng:NextNumber(0.12, 0.2)
		L.ball(m, "Lune", md, cf * CF(math.cos(a) * d * 1.5, rng:NextNumber(-d * 0.3, d * 0.3), math.sin(a) * d * 1.5), C.moon, L.sky())
	end
	return m
end

function P.moon(parent, cf, rng, d)
	local m = L.model("Lune", parent, cf)
	L.ball(m, "Globe", d, cf, C.moon, L.sky())
	for _ = 1, 9 do
		local dir = V(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit
		local cd = d * rng:NextNumber(0.12, 0.28)
		L.ball(m, "Cratere", cd, cf * CF(dir * (d / 2 - cd * 0.3)), C.moonD, L.sky())
	end
	L.ball(m, "Halo", d * 1.1, cf, C.white, L.glow(L.sky({ Transparency = 0.9 })))
	return m
end

function P.blackHole(parent, cf, rng, d)
	local m = L.model("TrouNoir", parent, cf)
	local flat = cf * ANG(rad(rng:NextNumber(10, 25)), 0, rad(90))
	L.ball(m, "Horizon", d, cf, C.black, L.sky())
	L.ball(m, "Photons", d * 1.08, cf, C.orange, L.glow(L.sky({ Transparency = 0.75 })))
	L.cyl(m, "Disque", 0.4, d * 2.2, flat, C.orange, L.glow(L.sky({ Transparency = 0.2 })))
	L.cyl(m, "DisqueChaud", 0.3, d * 1.6, flat * CF(0.1, 0, 0), C.yellow, L.glow(L.sky({ Transparency = 0.1 })))
	L.cyl(m, "DisqueFroid", 0.25, d * 3.2, flat * CF(-0.1, 0, 0), C.magenta, L.glow(L.sky({ Transparency = 0.55 })))
	L.cyl(m, "Brume", 0.2, d * 4.2, flat * CF(-0.2, 0, 0), C.purple, L.glow(L.sky({ Transparency = 0.82 })))
	L.ball(m, "Centre", d * 0.98, cf, C.black, L.sky())
	for i = 1, 14 do
		local a = i / 14 * TAU
		local r = d * rng:NextNumber(1.2, 2)
		L.ball(m, "Debris", rng:NextNumber(0.8, 2), flat * CF(0, math.cos(a) * r, math.sin(a) * r), pick(rng, { C.orange, C.yellow, C.pink }), L.glow(L.sky()))
	end
	return m
end

function P.galaxy(parent, cf, rng, radius, colors)
	colors = colors or { C.cyan, C.purple, C.pink, C.white }
	local m = L.model("Galaxie", parent, cf)
	L.ball(m, "Noyau", radius * 0.22, cf, C.yellow, L.glow(L.sky()))
	L.ball(m, "NoyauHalo", radius * 0.4, cf, C.white, L.glow(L.sky({ Transparency = 0.7 })))
	L.ball(m, "Halo", radius * 0.75, cf, C.purple, L.glow(L.sky({ Transparency = 0.9 })))
	local arms = 3
	local steps = 36
	for a = 0, arms - 1 do
		local off = a / arms * TAU
		local col = colors[a % #colors + 1]
		for i = 1, steps do
			local t = i / steps
			local theta = off + t * math.pi * 2.2
			local r = radius * (0.15 + 0.85 * t)
			local j = radius * 0.06 * (1 - t * 0.5)
			local p = V(math.cos(theta) * r + rng:NextNumber(-j, j), rng:NextNumber(-j, j) * 0.4, math.sin(theta) * r + rng:NextNumber(-j, j))
			local s = (1 - t) * radius * 0.09 + rng:NextNumber(0.6, 1.4)
			L.ball(m, "Etoile", s, cf * CF(p), col:Lerp(C.white, rng:NextNumber(0, 0.4)), L.glow(L.sky({ Transparency = t * 0.45 })))
		end
	end
	return m
end

function P.nebula(parent, cf, rng, size, colors)
	colors = colors or { C.purple, C.pink, C.blue }
	local m = L.model("Nebuleuse", parent, cf)
	for _ = 1, 12 do
		local p = V(rng:NextNumber(-1, 1) * size, rng:NextNumber(-0.4, 0.4) * size, rng:NextNumber(-1, 1) * size * 0.6)
		L.ball(m, "Nuage", size * rng:NextNumber(0.5, 1.1), cf * CF(p), pick(rng, colors), L.glow(L.sky({ Transparency = rng:NextNumber(0.8, 0.9) })))
	end
	for _ = 1, 10 do
		local p = V(rng:NextNumber(-1, 1) * size, rng:NextNumber(-0.5, 0.5) * size, rng:NextNumber(-1, 1) * size * 0.6)
		L.ball(m, "Etoile", rng:NextNumber(0.8, 1.8), cf * CF(p), C.white, L.glow(L.sky()))
	end
	return m
end

function P.comet(parent, cf, rng, len)
	local m = L.model("Comete", parent, cf)
	L.ball(m, "Tete", 4, cf, C.white, L.glow(L.sky()))
	L.ball(m, "Aura", 6.5, cf, C.cyan, L.glow(L.sky({ Transparency = 0.6 })))
	local n = 14
	for i = 1, n do
		local t = i / n
		L.ball(m, "Queue", 5.5 * (1 - t * 0.8), cf * CF(0, 0, t * len), (i % 2 == 0) and C.cyan or C.blue, L.glow(L.sky({ Transparency = 0.35 + t * 0.6 })))
	end
	return m
end

function P.asteroid(parent, cf, rng, s)
	local m = L.model("Asteroide", parent, cf)
	local col = pick(rng, { C.rock, C.rockB, C.rockD })
	for i = 1, rng:NextInteger(3, 5) do
		local o = V(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.4, 0.4)) * s
		local sz = V(rng:NextNumber(0.6, 1), rng:NextNumber(0.5, 0.9), rng:NextNumber(0.6, 1)) * s
		L.part(m, "Roche", sz, cf * CF(o) * ANG(rng:NextNumber(0, TAU), rng:NextNumber(0, TAU), rng:NextNumber(0, TAU)),
			i == 1 and col or col:Lerp(C.black, rng:NextNumber(0, 0.3)), L.sky())
	end
	if rng:NextNumber() < 0.35 then
		L.part(m, "Minerai", V(0.5, 0.5, 0.5) * s * 0.35, cf * CF(0, s * 0.4, 0) * ANG(0.6, 0.7, 0), pick(rng, L.GLOWS), L.glow(L.sky()))
	end
	return m
end

function P.satellite(parent, cf, rng)
	local m = L.model("Satellite", parent, cf)
	L.part(m, "Corps", V(3, 3, 4), cf, C.gold, L.sky({ Material = Enum.Material.Foil, MaterialVariant = "" }))
	L.part(m, "Bord", V(3.2, 0.3, 4.2), cf * CF(0, 1.5, 0), C.metalD, L.sky())
	for _, s in { -1, 1 } do
		L.cyl(m, "Bras", 3, 0.3, cf * CF(s * 3, 0, 0), C.metalL, L.sky())
		local pnl = cf * CF(s * 8, 0, 0)
		L.part(m, "Panneau", V(8, 0.2, 3.6), pnl, C.panel, L.sky({ Material = Enum.Material.Glass, MaterialVariant = "", Reflectance = 0.2 }))
		for k = -1, 1 do
			L.part(m, "Grille", V(0.12, 0.25, 3.6), pnl * CF(k * 2.6, 0, 0), C.panelD, L.sky())
		end
	end
	L.cyl(m, "Parabole", 0.4, 3, cf * CF(0, 0, -2.6) * ANG(0, rad(90), 0), C.metalL, L.sky())
	L.bar(m, "Antenne", (cf * CF(0, 0, -2.8)).Position, (cf * CF(0, 0, -4.8)).Position, 0.15, C.metalD, L.sky())
	local tip = L.ball(m, "Balise", 0.5, cf * CF(0, 0, -4.9), C.red, L.glow(L.sky()))
	L.light(tip, C.red, 8, 1.5)
	return m
end

function P.wormhole(parent, cf, rng, r)
	local m = L.model("Vortex", parent, cf)
	local n = 24
	for i = 1, n do
		local a = i / n * TAU
		local p = V(math.cos(a) * r, math.sin(a) * r, 0)
		local seg = 2 * math.pi * r / n * 1.05
		L.part(m, "Anneau", V(seg, 1.2, 1.2), cf * CF(p) * ANG(0, 0, a + math.pi / 2), (i % 2 == 0) and C.purple or C.cyan, L.glow(L.sky()))
	end
	L.cyl(m, "Portail", 0.3, r * 2, cf * ANG(0, rad(90), 0), C.magenta, L.glow(L.sky({ Transparency = 0.55 })))
	L.cyl(m, "Coeur", 0.4, r * 1.1, cf * ANG(0, rad(90), 0), C.white, L.glow(L.sky({ Transparency = 0.4 })))
	L.sparkles(L.anchor(m, "Particules", cf, V(r * 1.6, r * 1.6, 1)), C.cyan, 8, 1.2)
	return m
end

function P.star(parent, cf, rng)
	local s = rng:NextNumber(0.8, 2.2)
	local p = L.ball(parent, "Etoile", s, cf, pick(rng, { C.white, C.white, C.cyan, C.yellow, C.pink }), L.glow(L.sky()))
	if rng:NextNumber() < 0.3 then
		L.ball(parent, "EtoileHalo", s * 2.2, cf, p.Color, L.glow(L.sky({ Transparency = 0.8 })))
	end
	return p
end

--== SOL ==--

-- Plantes aliens en blocs (style de la map).
-- kind : "bulbes" (tiges + bulbes lumineux), "tentacules" (tiges qui ondulent),
-- "carnivore" (machoire a dents) ; par defaut au hasard.
function P.alienPlant(parent, cf, rng, col, kind)
	col = col or pick(rng, L.GLOWS)
	kind = kind or pick(rng, { "bulbes", "tentacules", "carnivore" })
	local m = L.model("PlanteAlien", parent, cf)
	L.part(m, "Pot", V(3.6, 0.8, 3.6), cf * CF(0, 0.4, 0), C.soil)
	L.part(m, "Terre", V(3, 0.3, 3), cf * CF(0, 0.9, 0), C.soilL)
	if kind == "carnivore" then
		L.part(m, "Tige", V(0.7, 3.5, 0.7), cf * CF(0, 2.8, 0), C.teal)
		for _, s in { -1, 1 } do
			L.part(m, "Feuille", V(2, 0.25, 0.9), cf * CF(s * 1.2, 2, 0) * ANG(0, 0, s * rad(25)), C.teal:Lerp(C.black, 0.2))
		end
		local head = cf * CF(0, 5.2, 0)
		L.part(m, "Machoire", V(2.6, 0.9, 2.6), head * CF(0, -0.5, 0), col)
		L.part(m, "Machoire", V(2.6, 0.9, 2.6), head * CF(0, 0.9, 0.6) * ANG(rad(-35), 0, 0), col)
		L.part(m, "Gorge", V(2, 0.3, 2), head * CF(0, 0, 0), C.dark)
		for i = -1, 1 do
			L.wedge(m, "Dent", V(0.4, 0.5, 0.3), head * CF(i * 0.8, 0.05, -1.15), C.white)
			L.wedge(m, "Dent", V(0.4, 0.5, 0.3), head * CF(i * 0.8, 0.35, -0.75) * ANG(rad(-35), 0, rad(180)), C.white)
		end
		for _, s in { -1, 1 } do
			L.part(m, "Oeil", V(0.6, 0.6, 0.6), head * CF(s * 0.7, 1.6, 0.2), C.yellow, L.glow())
			L.part(m, "Pupille", V(0.3, 0.3, 0.1), head * CF(s * 0.7, 1.6, -0.12), C.black)
		end
		L.light(L.anchor(m, "Lueur", head), col, 10, 1.2)
		return m
	end
	for i = 1, rng:NextInteger(3, 5) do
		local a = i / 5 * TAU + rng:NextNumber(-0.4, 0.4)
		local h = rng:NextNumber(3, 6)
		local lean = rng:NextNumber(0.5, 1.3)
		local p0 = cf * CF(math.cos(a) * 0.5, 1, math.sin(a) * 0.5)
		local p1 = cf * CF(math.cos(a) * lean * 0.6, 1 + h * 0.5, math.sin(a) * lean * 0.6)
		local p2 = cf * CF(math.cos(a) * lean * 1.4, 1 + h, math.sin(a) * lean * 1.4)
		L.bar(m, "Tige", p0.Position, p1.Position, 0.45, C.stemL)
		L.bar(m, "Tige", p1.Position, p2.Position, 0.4, C.stem)
		if kind == "tentacules" then
			local p3 = p2 * CF(math.cos(a) * 0.8, 0.9, math.sin(a) * 0.8)
			L.bar(m, "Tentacule", p2.Position, p3.Position, 0.35, col)
			L.part(m, "Ventouse", V(0.5, 0.5, 0.5), p3, col:Lerp(C.white, 0.4), L.glow())
		else
			local sz = rng:NextNumber(0.9, 1.4)
			L.part(m, "Bulbe", V(sz, sz, sz), p2 * ANG(0, a, rad(45)), col, L.glow())
		end
		L.part(m, "Feuille", V(1.4, 0.15, 0.7), p1 * ANG(0, -a, rad(20)), C.teal)
	end
	local core = L.part(m, "Coeur", V(1.1, 1.1, 1.1), cf * CF(0, 1.6, 0) * ANG(0, rad(45), 0), col, L.glow())
	L.light(core, col, 10, 1.2)
	return m
end

function P.shrooms(parent, cf, rng, col)
	col = col or pick(rng, L.GLOWS)
	local m = L.model("Champignons", parent, cf)
	for i = 1, rng:NextInteger(3, 6) do
		local a = rng:NextNumber(0, TAU)
		local r = i == 1 and 0 or rng:NextNumber(0.9, 2.2)
		local h = i == 1 and rng:NextNumber(2.5, 3.5) or rng:NextNumber(0.8, 2)
		local c = cf * CF(math.cos(a) * r, 0, math.sin(a) * r) * ANG(0, rng:NextNumber(0, TAU), 0)
		L.part(m, "Pied", V(h * 0.3, h, h * 0.3), c * CF(0, h / 2, 0), C.white:Lerp(col, 0.2))
		L.part(m, "Chapeau", V(h * 0.95, h * 0.3, h * 0.95), c * CF(0, h, 0), col, L.glow())
		L.part(m, "ChapeauHaut", V(h * 0.55, h * 0.2, h * 0.55), c * CF(0, h + h * 0.22, 0), col:Lerp(C.white, 0.3), L.glow())
		L.part(m, "Point", V(h * 0.15, h * 0.05, h * 0.15), c * CF(h * 0.25, h + h * 0.17, -h * 0.2), C.white, L.glow())
	end
	return m
end

function P.crystal(parent, cf, rng, col, scale)
	col = col or pick(rng, L.GLOWS)
	scale = scale or 1
	local m = L.model("CristalGeant", parent, cf)
	L.vcyl(m, "Socle", 1, 6 * scale, cf * CF(0, 0.5, 0), C.rockD)
	local biggest
	for i = 1, rng:NextInteger(5, 7) do
		local h = (i == 1 and 9 or rng:NextNumber(3, 7)) * scale
		local w = (i == 1 and 1.8 or rng:NextNumber(0.9, 1.4)) * scale
		local a = rng:NextNumber(0, TAU)
		local r = i == 1 and 0 or rng:NextNumber(0.8, 2.2) * scale
		local tilt = i == 1 and 0 or rng:NextNumber(0.15, 0.45)
		local base = cf * CF(math.cos(a) * r, 0.8, math.sin(a) * r) * ANG(0, -a, 0) * ANG(0, 0, -tilt)
		local body = L.part(m, "Cristal", V(w, h, w), base * CF(0, h / 2, 0), col, L.glow({ Transparency = 0.15 }))
		L.wedge(m, "Pointe", V(w, w * 1.2, w / 2), base * CF(0, h + w * 0.6, -w / 4), col:Lerp(C.white, 0.3), L.glow())
		L.wedge(m, "Pointe", V(w, w * 1.2, w / 2), base * CF(0, h + w * 0.6, w / 4) * ANG(0, math.pi, 0), col:Lerp(C.white, 0.3), L.glow())
		if i == 1 then biggest = body end
	end
	L.light(biggest, col, 16 * scale, 1.6)
	L.sparkles(biggest, col, 3, 0.4)
	return m
end

function P.boulder(parent, cf, rng, s)
	local m = L.model("RocheLunaire", parent, cf)
	for i = 1, rng:NextInteger(2, 4) do
		local sz = V(rng:NextNumber(0.7, 1.2), rng:NextNumber(0.5, 0.9), rng:NextNumber(0.7, 1.2)) * s
		L.part(m, "Roche", sz, cf * CF(rng:NextNumber(-0.4, 0.4) * s, sz.Y * 0.4, rng:NextNumber(-0.4, 0.4) * s) * ANG(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, TAU), rng:NextNumber(-0.3, 0.3)),
			i == 1 and C.rock or C.rockL)
	end
	if rng:NextNumber() < 0.5 then
		L.part(m, "Veine", V(0.2, s * 0.5, s * 0.8), cf * CF(0, s * 0.45, 0) * ANG(0, rng:NextNumber(0, TAU), 0.3), pick(rng, L.GLOWS), L.glow())
	end
	return m
end

function P.lamp(parent, cf, rng, col)
	col = col or C.cyan
	local m = L.model("Lampadaire", parent, cf)
	L.vcyl(m, "Base", 0.6, 2.4, cf * CF(0, 0.3, 0), C.metalD)
	L.vcyl(m, "Mat", 9, 0.5, cf * CF(0, 5, 0), C.metal)
	L.vcyl(m, "Anneau", 0.3, 0.9, cf * CF(0, 3, 0), col, L.glow())
	L.vcyl(m, "Anneau", 0.3, 0.9, cf * CF(0, 7, 0), col, L.glow())
	L.part(m, "Bras", V(0.4, 0.4, 3), cf * CF(0, 9.3, -1.2), C.metal)
	L.vcyl(m, "Abat", 0.5, 1.8, cf * CF(0, 9.3, -2.6), C.metalD)
	local orb = L.ball(m, "Globe", 1.3, cf * CF(0, 8.6, -2.6), col, L.glow())
	L.light(orb, col, 18, 1.4)
	L.ball(m, "Pointe", 0.6, cf * CF(0, 9.8, 0), col, L.glow())
	return m
end

function P.portal(parent, cf, rng, width, height, text)
	local m = L.model("PortailCosmos", parent, cf)
	for _, s in { -1, 1 } do
		local pc = cf * CF(s * width / 2, 0, 0)
		L.part(m, "Pied", V(6, 2, 6), pc * CF(0, 1, 0), C.metalD)
		L.part(m, "Pilier", V(4, height, 4), pc * CF(0, height / 2 + 2, 0), C.dark)
		for k = 1, 4 do
			L.part(m, "Neon", V(4.2, 0.5, 4.2), pc * CF(0, 2 + k * height / 5, 0), (k % 2 == 0) and C.purple or C.cyan, L.glow())
		end
		L.part(m, "BandeAvant", V(0.4, height - 2, 0.3), pc * CF(0, height / 2 + 2, -2.05), C.cyan, L.glow())
		L.part(m, "BandeArriere", V(0.4, height - 2, 0.3), pc * CF(0, height / 2 + 2, 2.05), C.cyan, L.glow())
		local top = L.ball(m, "Orbe", 4, pc * CF(0, height + 4.5, 0), C.magenta, L.glow())
		L.light(top, C.magenta, 24, 2)
		L.sparkles(top, C.pink, 5, 0.8)
	end
	local beamY = height + 2
	local beam = L.part(m, "Poutre", V(width, 5, 3), cf * CF(0, beamY, 0), C.dark)
	L.part(m, "PoutreNeon", V(width, 0.5, 3.2), cf * CF(0, beamY - 2.6, 0), C.cyan, L.glow())
	L.part(m, "PoutreNeon", V(width, 0.5, 3.2), cf * CF(0, beamY + 2.6, 0), C.purple, L.glow())
	local sign = L.part(m, "Enseigne", V(math.min(width * 0.5, 50), 9, 1), cf * CF(0, beamY + 7, 0), C.dark)
	L.part(m, "Cadre", sign.Size + V(1, 1, -0.2), sign.CFrame, C.purple, L.glow())
	L.label(sign, Enum.NormalId.Front, text or "COSMOS", C.cyan)
	L.label(sign, Enum.NormalId.Back, text or "COSMOS", C.cyan)
	local rr = 7
	for i = 1, 16 do
		local a = i / 16 * TAU
		L.part(m, "Halo", V(2.9, 0.7, 0.7), cf * CF(math.cos(a) * rr, beamY + 7 + math.sin(a) * rr, 1.2) * ANG(0, 0, a + math.pi / 2), (i % 2 == 0) and C.cyan or C.pink, L.glow({ CanCollide = false }))
	end
	return m, beam
end

-- Petit rover-araignee en blocs : cabine cube, 6 pattes, gros oeil laser,
-- ailes solaires et un mini-drone au-dessus.
function P.rover(parent, cf, rng, col)
	col = col or C.cyan
	local m = L.model("RoverAraignee", parent, cf)
	local body = cf * CF(0, 3, 0)
	L.part(m, "Coque", V(3.4, 1.8, 3.8), body, C.white)
	L.part(m, "Ceinture", V(3.6, 0.35, 4), body * CF(0, -0.5, 0), col, L.glow())
	L.part(m, "Dessous", V(2.6, 0.6, 3), body * CF(0, -1.2, 0), C.metalD)
	L.part(m, "Cabine", V(2.4, 1.4, 2.2), body * CF(0, 1.6, 0.3), col, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.45 })
	L.part(m, "Pilote", V(1, 1, 1), body * CF(0, 1.4, 0.4), C3(190, 255, 160))
	L.part(m, "PiloteOeil", V(0.6, 0.3, 0.05), body * CF(0, 1.5, -0.12), C.black)
	local eye = body * CF(0, 0.1, -1.95)
	L.part(m, "OeilCadre", V(1.8, 1.2, 0.3), eye, C.dark)
	L.part(m, "Oeil", V(1.2, 0.7, 0.12), eye * CF(0, 0, -0.18), C.red, L.glow())
	L.light(L.anchor(m, "Laser", eye * CF(0, 0, -0.5)), C.red, 12, 1.5)
	for _, s in { -1, 1 } do
		L.part(m, "Phare", V(0.4, 0.4, 0.1), body * CF(s * 1.3, -0.1, -1.95), C.yellow, L.glow())
	end
	for i = 0, 5 do
		local side = i < 3 and -1 or 1
		local z = ((i % 3) - 1) * 1.4
		local hip = body * CF(side * 1.8, -0.4, z)
		local knee = body * CF(side * 3, 0.9, z * 1.25)
		local foot = cf * CF(side * 3.9, 0.35, z * 1.5)
		L.part(m, "Hanche", V(0.7, 0.7, 0.7), hip, C.metalD)
		L.bar(m, "Cuisse", hip.Position, knee.Position, 0.45, C.metal)
		L.part(m, "Genou", V(0.6, 0.6, 0.6), knee, col, L.glow())
		L.bar(m, "Patte", knee.Position, foot.Position, 0.38, C.metalD)
		L.part(m, "Pied", V(0.8, 0.4, 0.8), foot * CF(0, -0.15, 0), C.dark)
	end
	for _, s in { -1, 1 } do
		local w = body * CF(s * 2.4, 1, 1.4) * ANG(0, 0, s * rad(20))
		L.part(m, "AileSolaire", V(2.6, 0.15, 1.6), w, C.panel, { Material = Enum.Material.Glass, MaterialVariant = "", Reflectance = 0.25 })
		L.part(m, "AileBord", V(2.7, 0.2, 0.15), w * CF(0, 0, -0.8), col, L.glow())
	end
	L.bar(m, "Antenne", (body * CF(1.1, 0.9, 1.5)).Position, (body * CF(1.3, 3.2, 1.7)).Position, 0.15, C.metalD)
	L.part(m, "Balise", V(0.45, 0.45, 0.45), body * CF(1.3, 3.3, 1.7), C.yellow, L.glow())
	local drone = body * CF(-0.9, 4, -0.8)
	L.part(m, "Drone", V(1, 0.6, 1), drone, C.white)
	L.part(m, "DroneOeil", V(0.4, 0.25, 0.05), drone * CF(0, 0, -0.52), col, L.glow())
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local r = drone * CF(math.cos(a) * 1, 0.1, math.sin(a) * 1)
		L.bar(m, "DroneBras", drone.Position, r.Position, 0.12, C.metalD, { CanCollide = false })
		L.part(m, "Helice", V(0.9, 0.05, 0.2), r * CF(0, 0.12, 0) * ANG(0, a, 0), col, L.glow({ Transparency = 0.3 }))
	end
	return m
end

function P.flag(parent, cf, rng, col)
	col = col or C.purple
	local m = L.model("Drapeau", parent, cf)
	L.vcyl(m, "Socle", 0.5, 2, cf * CF(0, 0.25, 0), C.metalD)
	L.vcyl(m, "Mat", 8, 0.25, cf * CF(0, 4.3, 0), C.metalL)
	L.part(m, "Barre", V(3.6, 0.2, 0.2), cf * CF(1.8, 8.1, 0), C.metalL)
	L.part(m, "Tissu", V(3.6, 2.4, 0.1), cf * CF(1.8, 6.8, 0), col)
	L.ball(m, "Etoile", 0.9, cf * CF(1.8, 6.8, 0), C.yellow, L.glow())
	return m
end

function P.observatory(parent, cf, rng)
	local m = L.model("Observatoire", parent, cf)
	L.vcyl(m, "Base", 7, 14, cf * CF(0, 3.5, 0), C.metalL)
	L.vcyl(m, "Liseré", 0.6, 14.3, cf * CF(0, 6.8, 0), C.cyan, L.glow())
	L.vcyl(m, "Liseré", 0.6, 14.3, cf * CF(0, 1, 0), C.purple, L.glow())
	L.ball(m, "Dome", 13, cf * CF(0, 7, 0), C.metal)
	L.part(m, "Fente", V(2.4, 6, 12.6), cf * CF(0, 10, 0) * ANG(rad(-20), 0, 0), C.dark)
	local tube = cf * CF(0, 12.5, -5) * ANG(rad(35), 0, 0)
	L.cyl(m, "Telescope", 9, 2, tube * ANG(0, rad(90), 0), C.white)
	L.cyl(m, "Lentille", 0.3, 1.8, tube * CF(0, 0, -4.6) * ANG(0, rad(90), 0), C.cyan, L.glow())
	L.part(m, "Porte", V(3, 5, 0.4), cf * CF(0, 2.5, -7), C.dark)
	L.part(m, "PorteNeon", V(3.4, 0.3, 0.5), cf * CF(0, 5.1, -7), C.cyan, L.glow())
	for i = 1, 3 do
		L.part(m, "Marche", V(4, 0.35, 1), cf * CF(0, 0.35 * i - 0.17, -7.5 - (3 - i)), C.metalD)
	end
	local b = L.ball(m, "Balise", 0.8, cf * CF(0, 13.7, 0), C.red, L.glow())
	L.light(b, C.cyan, 20, 1.5)
	return m
end

function P.nest(parent, cf, rng, col)
	col = col or C.green
	local m = L.model("NidAlien", parent, cf)
	for i = 1, 10 do
		local a = i / 10 * TAU
		L.part(m, "Bord", V(1.6, 1, 1.2), cf * CF(math.cos(a) * 2.6, 0.5, math.sin(a) * 2.6) * ANG(0, -a, rng:NextNumber(-0.3, 0.3)), C.soilL)
	end
	L.vcyl(m, "Fond", 0.3, 5, cf * CF(0, 0.15, 0), C.soil)
	for i = 1, 3 do
		local a = i / 3 * TAU
		local e = cf * CF(math.cos(a) * 1.1, 1.2, math.sin(a) * 1.1)
		L.ball(m, "Oeuf", 1.8, e, col, L.glow({ Transparency = 0.1 }))
		L.ball(m, "OeufHaut", 1.3, e * CF(0, 0.7, 0), col:Lerp(C.white, 0.3), L.glow())
	end
	L.light(L.anchor(m, "Lueur", cf * CF(0, 1.5, 0)), col, 12, 1.2)
	return m
end

function P.holoSign(parent, cf, rng, text, col)
	col = col or C.cyan
	local m = L.model("PanneauHolo", parent, cf)
	L.vcyl(m, "Pied", 0.4, 2, cf * CF(0, 0.2, 0), C.metalD)
	L.vcyl(m, "Mat", 4, 0.3, cf * CF(0, 2.4, 0), C.metal)
	local panel = L.part(m, "Ecran", V(7, 3, 0.2), cf * CF(0, 5.5, 0), col, L.glow({ Transparency = 0.7 }))
	L.part(m, "Cadre", V(7.4, 0.25, 0.3), cf * CF(0, 7.1, 0), col, L.glow())
	L.part(m, "Cadre", V(7.4, 0.25, 0.3), cf * CF(0, 3.9, 0), col, L.glow())
	L.label(panel, Enum.NormalId.Front, text, C.white)
	L.label(panel, Enum.NormalId.Back, text, C.white)
	return m
end

function P.floorCrack(parent, cf, rng, col)
	local n = rng:NextInteger(3, 5)
	local p = cf
	for _ = 1, n do
		local len = rng:NextNumber(1.5, 3.5)
		p = p * ANG(0, rng:NextNumber(-0.7, 0.7), 0)
		L.part(parent, "Fissure", V(0.25, 0.12, len), p * CF(0, 0.06, -len / 2), col, L.glow())
		p = p * CF(0, 0, -len)
	end
end

function P.dust(parent, cf, rng)
	L.part(parent, "Poussiere", V(rng:NextNumber(4, 8), 0.15, rng:NextNumber(3, 6)), cf * CF(0, 0.08, 0) * ANG(0, rng:NextNumber(0, TAU), 0),
		pick(rng, { C.soil, C.soilL, C.rockD }))
end

--== PERSONNAGES & VEHICULES ==--

-- Style de la map : tout en blocs a picots (MaterialVariant "Studs").
-- o = { skin, suit, eyes (1-3), gear = "casque" | "pistolet" | "cape" | nil, pose = "salut" | nil }
function P.alien(parent, cf, rng, o)
	o = o or {}
	local skin = o.skin or C3(190, 255, 160)
	local suit = o.suit or C3(110, 90, 230)
	local trim = o.trim or C.cyan
	local m = L.model("Alien", parent, cf)
	for _, s in { -1, 1 } do
		L.part(m, "Chaussure", V(1.3, 0.8, 1.6), cf * CF(s * 0.75, 0.4, -0.15), C.white)
		L.part(m, "Jambe", V(1.2, 2.2, 1.2), cf * CF(s * 0.75, 1.9, 0), suit)
	end
	L.part(m, "Ceinture", V(3.2, 0.5, 1.9), cf * CF(0, 3.2, 0), trim)
	L.part(m, "Corps", V(3, 2.8, 1.8), cf * CF(0, 4.8, 0), suit)
	L.part(m, "Insigne", V(0.8, 0.8, 0.2), cf * CF(0, 5, -0.95) * ANG(0, 0, rad(45)), C.yellow, L.glow())
	L.part(m, "Col", V(2, 0.4, 1.4), cf * CF(0, 6.4, 0), trim)
	for _, s in { -1, 1 } do
		local up = o.pose == "salut" and s == 1
		if up then
			L.part(m, "Bras", V(0.9, 2.4, 0.9), cf * CF(s * 1.95, 7, 0) * ANG(0, 0, s * rad(-20)), skin)
			L.part(m, "Manchette", V(1, 0.4, 1), cf * CF(s * 2.35, 8.1, 0) * ANG(0, 0, s * rad(-20)), trim)
		else
			L.part(m, "Bras", V(0.9, 2.6, 0.9), cf * CF(s * 1.95, 4.9, 0), skin)
			L.part(m, "Manchette", V(1, 0.4, 1), cf * CF(s * 1.95, 3.8, 0), trim)
		end
	end
	if o.gear == "pistolet" then
		local g = cf * CF(-1.95, 3.4, -0.9)
		L.part(m, "Pistolet", V(0.5, 0.7, 1.6), g, C.metalD)
		L.part(m, "Canon", V(0.3, 0.3, 0.8), g * CF(0, 0.15, -1.1), C.pink, L.glow())
	end
	if o.gear == "cape" then
		L.part(m, "Cape", V(3.1, 4.2, 0.2), cf * CF(0, 4.4, 1.05) * ANG(rad(-6), 0, 0), C.red)
	end
	local head = cf * CF(0, 8.3, 0)
	L.part(m, "Tete", V(3.4, 3.2, 3), head, skin)
	local eyes = o.eyes or 2
	local xs = eyes == 1 and { 0 } or (eyes == 2 and { -0.8, 0.8 } or { -1.05, 0, 1.05 })
	local w = eyes == 1 and 1.4 or (eyes == 2 and 1.1 or 0.75)
	for _, x in xs do
		local tilt = x == 0 and 0 or (x < 0 and rad(-12) or rad(12))
		local e = head * CF(x, 0.1, -1.52) * ANG(0, 0, tilt)
		L.part(m, "Oeil", V(w, w * 0.75, 0.1), e, C.black)
		L.part(m, "Reflet", V(w * 0.25, w * 0.25, 0.12), e * CF(w * 0.15, w * 0.12, -0.02), C.white, L.glow())
	end
	L.part(m, "Bouche", V(0.8, 0.15, 0.1), head * CF(0, -0.9, -1.52), C.dark)
	for _, s in { -1, 1 } do
		local a0 = head * CF(s * 0.9, 1.6, 0)
		local a1 = head * CF(s * 1.5, 3.4, 0)
		L.bar(m, "Antenne", a0.Position, a1.Position, 0.25, skin:Lerp(C.black, 0.2))
		local tip = L.part(m, "AntenneBout", V(0.8, 0.8, 0.8), a1, o.tip or C.pink, L.glow())
		if s == 1 then L.light(tip, o.tip or C.pink, 8, 1) end
	end
	if o.gear == "casque" then
		L.part(m, "Casque", V(3.9, 3.7, 3.5), head * CF(0, 0.1, 0), C.cyan, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.6, CanCollide = false })
		L.part(m, "CasqueBord", V(4, 0.4, 3.6), head * CF(0, -1.7, 0), C.metalL)
	end
	return m
end

function P.cybernaut(parent, cf, rng, accent, pose)
	accent = accent or C.cyan
	local m = L.model("Cybernaute", parent, cf)
	for _, s in { -1, 1 } do
		L.part(m, "Botte", V(1.3, 1, 1.9), cf * CF(s * 0.75, 0.5, -0.2), C.metalD)
		L.part(m, "Jambe", V(1.1, 2.6, 1.2), cf * CF(s * 0.75, 2.3, 0), C.white)
		L.part(m, "Genou", V(1.2, 0.5, 1.3), cf * CF(s * 0.75, 2.2, -0.05), accent, L.glow())
	end
	L.part(m, "Ceinture", V(2.8, 0.5, 1.6), cf * CF(0, 3.8, 0), C.metalD)
	L.part(m, "Torse", V(3, 3, 1.8), cf * CF(0, 5.5, 0), C.white)
	L.part(m, "Plastron", V(1.8, 1.4, 0.2), cf * CF(0, 5.8, -0.95), C.dark)
	for i = 0, 2 do
		L.part(m, "Voyant", V(0.3, 0.3, 0.1), cf * CF(-0.5 + i * 0.5, 6, -1.08), ({ C.red, C.yellow, C.green })[i + 1], L.glow())
	end
	L.part(m, "Jauge", V(1.2, 0.2, 0.1), cf * CF(0, 5.4, -1.08), accent, L.glow())
	L.part(m, "SacDos", V(2.6, 3, 1.2), cf * CF(0, 5.6, 1.4), C.metalL)
	for _, s in { -1, 1 } do
		L.vcyl(m, "Reservoir", 2.6, 0.8, cf * CF(s * 0.7, 5.6, 2.1), C.metal)
		L.part(m, "Tube", V(0.2, 2.4, 0.2), cf * CF(s * 0.7, 5.6, 2.55), accent, L.glow())
	end
	for _, s in { -1, 1 } do
		local cyber = s == 1
		local sh = cf * CF(s * 1.9, 6.5, 0)
		local up = pose == "salut" and s == 1
		local elbow = up and (cf * CF(s * 2.6, 7.6, 0)) or (sh * CF(0, -1.6, 0))
		local hand = up and (cf * CF(s * 2.4, 9.2, -0.2)) or (sh * CF(0, -3, -0.3))
		L.ball(m, "Epaule", 1.3, sh, cyber and C.metalD or C.white)
		L.bar(m, "BrasHaut", sh.Position, elbow.Position, 0.9, cyber and C.metalD or C.white)
		L.bar(m, "AvantBras", elbow.Position, hand.Position, 0.8, cyber and C.dark or C.white)
		if cyber then
			L.ball(m, "Articulation", 0.8, elbow, accent, L.glow())
		end
		L.ball(m, "Gant", 1, hand, cyber and accent or C.metalD, cyber and L.glow() or nil)
	end
	local head = cf * CF(0, 8.3, 0)
	L.vcyl(m, "Col", 0.5, 1.8, cf * CF(0, 7.1, 0), C.metalD)
	L.ball(m, "Casque", 3.2, head, C.white)
	L.ball(m, "Visiere", 2.5, head * CF(0, 0, -0.5), C.dark, { Material = Enum.Material.Glass, MaterialVariant = "", Reflectance = 0.4 })
	L.part(m, "VisiereLueur", V(2.2, 0.15, 0.1), head * CF(0, 0.1, -1.73), accent, L.glow())
	L.part(m, "OeilCyber", V(0.5, 0.3, 0.1), head * CF(0.55, 0.35, -1.72), C.red, L.glow())
	L.bar(m, "Antenne", (head * CF(1.2, 1, 0)).Position, (head * CF(1.4, 2.8, 0.2)).Position, 0.15, C.metalD)
	local b = L.ball(m, "Balise", 0.45, head * CF(1.4, 2.9, 0.2), accent, L.glow())
	L.light(b, accent, 8, 1)
	return m
end

function P.rocket(parent, cf, rng, col, h)
	col = col or C.red
	h = h or 30
	local d = h * 0.2
	local m = L.model("Fusee", parent, cf)
	L.vcyl(m, "Pas", 1, d * 2.6, cf * CF(0, 0.5, 0), C.metalD)
	L.vcyl(m, "PasNeon", 0.3, d * 2.7, cf * CF(0, 1, 0), C.cyan, L.glow())
	local base = h * 0.18
	local lift = h * 0.15
	L.vcyl(m, "Tuyere", base * 0.5, d * 0.7, cf * CF(0, 1 + lift + base * 0.25, 0), C.metalD)
	L.vcyl(m, "TuyereBas", base * 0.3, d * 0.9, cf * CF(0, 1 + lift + base * 0.15, 0), C.dark)
	local body0 = 1 + lift + base * 0.5
	for i = 0, 3 do
		local a = i * math.pi / 2
		local top = (cf * ANG(0, a, 0) * CF(0, body0 + 1, -d / 2)).Position
		local foot = (cf * ANG(0, a, 0) * CF(0, 1, -(d / 2 + lift * 0.7))).Position
		L.bar(m, "Bequille", top, foot, 0.5, C.metalD)
		L.vcyl(m, "Patin", 0.3, 1.4, CF(foot) * CF(0, 0.15, 0), C.dark)
	end
	local bodyH = h * 0.55
	L.vcyl(m, "Corps", bodyH, d, cf * CF(0, body0 + bodyH / 2, 0), C.white)
	for i, t in { 0.12, 0.55 } do
		L.vcyl(m, "Bande", bodyH * 0.07, d + 0.2, cf * CF(0, body0 + bodyH * t, 0), i == 1 and col or C.dark)
	end
	for i = 0, 1 do
		local y = body0 + bodyH * (0.7 + i * 0.16)
		local win = cf * CF(0, y, -d / 2)
		L.cyl(m, "Hublot", 0.3, d * 0.34, win * ANG(0, rad(90), 0), C.metalD)
		L.cyl(m, "Vitre", 0.35, d * 0.24, win * ANG(0, rad(90), 0), C.cyan, L.glow({ Transparency = 0.2 }))
	end
	local y = body0 + bodyH
	local coneSteps = 6
	for i = 1, coneSteps do
		local t = (i - 0.5) / coneSteps
		local step = h * 0.28 / coneSteps
		L.vcyl(m, "Nez", step + 0.05, d * (1 - t * 0.85), cf * CF(0, y + step / 2, 0), i <= 2 and C.white or col)
		y += step
	end
	L.ball(m, "Pointe", d * 0.18, cf * CF(0, y, 0), col)
	local tip = L.ball(m, "Feu", 0.6, cf * CF(0, y + d * 0.1, 0), C.red, L.glow())
	L.light(tip, C.red, 10, 1)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		local fc = cf * ANG(0, a, 0) * CF(0, body0 + h * 0.08, -(d / 2 + h * 0.06))
		L.wedge(m, "Aileron", V(0.5, h * 0.18, h * 0.12), fc, col)
		L.part(m, "AileronPied", V(0.6, h * 0.02, h * 0.12), fc * CF(0, -h * 0.09, 0), C.dark)
	end
	local flame = L.anchor(m, "Flamme", cf * CF(0, 1 + lift, 0), V(d * 0.6, 0.4, d * 0.6))
	L.vcyl(m, "FlammeNeon", lift * 0.8, d * 0.55, cf * CF(0, 1 + lift * 0.6, 0), C.orange, L.glow({ Transparency = 0.25, CanCollide = false }))
	L.emitter(flame, {
		Name = "Feu", Texture = "rbxasset://textures/particles/fire_main.dds", LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(C.yellow, C.orange), Size = L.seq({ 0, d * 0.4, 1, d * 0.1 }), Transparency = L.seq({ 0, 0.2, 1, 1 }),
		Lifetime = NumberRange.new(0.4, 0.7), Rate = 40, Speed = NumberRange.new(4, 7), EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(15, 15),
	})
	L.light(flame, C.orange, 16, 2)
	return m
end

function P.dish(parent, cf, rng, s)
	s = s or 1
	local m = L.model("Parabole", parent, cf)
	L.part(m, "Socle", V(5, 1, 5) * s, cf * CF(0, 0.5 * s, 0), C.metalD)
	L.part(m, "SocleNeon", V(5.2, 0.25, 5.2) * s, cf * CF(0, 1 * s, 0), C.cyan, L.glow())
	L.vcyl(m, "Pilier", 5 * s, 1.2 * s, cf * CF(0, 3.5 * s, 0), C.metal)
	L.part(m, "Fourche", V(3.6, 0.6, 0.8) * s, cf * CF(0, 6.2 * s, 0), C.metalD)
	for _, x in { -1.6, 1.6 } do
		L.part(m, "FourcheBras", V(0.4, 2, 0.8) * s, cf * CF(x * s, 7.2 * s, 0), C.metalD)
	end
	local aim = cf * CF(0, 8 * s, 0) * ANG(rad(40), 0, 0)
	local layers = 6
	for i = 0, layers - 1 do
		local t = i / (layers - 1)
		local dd = (2 + t * 8) * s
		L.cyl(m, "Coupe", 0.35 * s, dd, aim * CF(0, 0, -(t * t) * 2.2 * s) * ANG(0, rad(90), 0), i == layers - 1 and C.metalL or C.white)
	end
	L.cyl(m, "Liseré", 0.2 * s, 10.3 * s, aim * CF(0, 0, -2.3 * s) * ANG(0, rad(90), 0), C.cyan, L.glow({ Transparency = 0.3 }))
	local rx = (aim * CF(0, 0, -6.5 * s)).Position
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		L.bar(m, "Support", (aim * CF(math.cos(a) * 4.5 * s, math.sin(a) * 4.5 * s, -2.2 * s)).Position, rx, 0.18 * s, C.metalD)
	end
	local rcv = L.ball(m, "Recepteur", 0.9 * s, CF(rx), C.magenta, L.glow())
	L.light(rcv, C.magenta, 10 * s, 1.2)
	L.sparkles(rcv, C.pink, 3, 0.4 * s)
	L.part(m, "Boitier", V(1.6, 1.4, 1) * s, cf * CF(0, 2.2 * s, -0.9 * s), C.metalL)
	L.part(m, "Ecran", V(1.2, 0.8, 0.1) * s, cf * CF(0, 2.3 * s, -1.42 * s), C.green, L.glow())
	return m
end

return P
