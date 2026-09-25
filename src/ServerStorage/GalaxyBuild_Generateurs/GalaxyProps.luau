local L = require(script.Parent.GalaxyBuildLib)
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

function P.alienPlant(parent, cf, rng, col)
	col = col or pick(rng, L.GLOWS)
	local m = L.model("PlanteAlien", parent, cf)
	L.vcyl(m, "Butte", 0.8, 4, cf * CF(0, 0.4, 0), C.soil)
	L.vcyl(m, "ButteHaut", 0.6, 2.8, cf * CF(0, 0.9, 0), C.soilL)
	for i = 1, rng:NextInteger(3, 5) do
		local a = i / 5 * TAU + rng:NextNumber(-0.4, 0.4)
		local h = rng:NextNumber(3, 6)
		local lean = rng:NextNumber(0.6, 1.6)
		local p0 = (cf * CF(math.cos(a) * 0.5, 1, math.sin(a) * 0.5)).Position
		local p1 = (cf * CF(math.cos(a) * lean * 0.5, 1 + h * 0.5, math.sin(a) * lean * 0.5)).Position
		local p2 = (cf * CF(math.cos(a) * lean * 1.3, 1 + h, math.sin(a) * lean * 1.3)).Position
		L.bar(m, "Tige", p0, p1, 0.35, C.stemL)
		L.bar(m, "Tige", p1, p2, 0.3, C.stem)
		L.ball(m, "Bulbe", rng:NextNumber(0.9, 1.4), CF(p2), col, L.glow())
		L.wedge(m, "Feuille", V(0.15, 0.8, 1.6), CF(p1) * ANG(0, a, rad(30)), C.teal)
	end
	local core = L.ball(m, "Coeur", 1.2, cf * CF(0, 1.4, 0), col, L.glow())
	L.light(core, col, 10, 1.2)
	return m
end

function P.shrooms(parent, cf, rng, col)
	col = col or pick(rng, L.GLOWS)
	local m = L.model("Champignons", parent, cf)
	for i = 1, rng:NextInteger(3, 6) do
		local a = rng:NextNumber(0, TAU)
		local r = i == 1 and 0 or rng:NextNumber(0.8, 2.2)
		local h = i == 1 and rng:NextNumber(2.5, 3.5) or rng:NextNumber(0.8, 2)
		local c = cf * CF(math.cos(a) * r, 0, math.sin(a) * r)
		L.vcyl(m, "Pied", h, h * 0.25, c * CF(0, h / 2, 0), C.white:Lerp(col, 0.2))
		L.vcyl(m, "Chapeau", h * 0.25, h * 0.9, c * CF(0, h, 0), col, L.glow())
		L.ball(m, "Dome", h * 0.6, c * CF(0, h + 0.05, 0), col:Lerp(C.white, 0.3), L.glow({ Transparency = 0.3 }))
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

function P.rover(parent, cf, rng)
	local m = L.model("Rover", parent, cf)
	L.part(m, "Chassis", V(5, 1, 8), cf * CF(0, 2.2, 0), C.metalL)
	L.part(m, "Caisse", V(4, 1.6, 5), cf * CF(0, 3.5, 0.5), C.white)
	L.part(m, "Or", V(4.1, 0.4, 5.1), cf * CF(0, 2.9, 0.5), C.gold, { Material = Enum.Material.Foil, MaterialVariant = "" })
	for _, z in { -3, 0, 3 } do
		for _, s in { -1, 1 } do
			L.cyl(m, "Roue", 1, 2.4, cf * CF(s * 3, 1.2, z), C.dark)
			L.cyl(m, "Jante", 1.1, 1.1, cf * CF(s * 3, 1.2, z), C.metal)
			L.bar(m, "Suspension", (cf * CF(s * 2.5, 2.2, z)).Position, (cf * CF(s * 3, 1.2, z)).Position, 0.3, C.metalD)
		end
	end
	L.part(m, "Panneau", V(5.5, 0.2, 4), cf * CF(0, 4.5, 1), C.panel, { Material = Enum.Material.Glass, MaterialVariant = "", Reflectance = 0.2 })
	L.vcyl(m, "Mat", 3, 0.35, cf * CF(0, 5, -2.5), C.metal)
	L.part(m, "Tete", V(1.6, 1, 1), cf * CF(0, 6.8, -2.5), C.white)
	local eye = L.part(m, "Camera", V(0.6, 0.6, 0.2), cf * CF(0, 6.8, -3.05), C.cyan, L.glow())
	L.light(eye, C.cyan, 10, 1)
	L.bar(m, "Antenne", (cf * CF(1.5, 3.8, 2.5)).Position, (cf * CF(1.8, 7, 3)).Position, 0.15, C.metalD)
	L.ball(m, "Balise", 0.5, cf * CF(1.8, 7.1, 3), C.red, L.glow())
	for _, s in { -1, 1 } do
		L.part(m, "Phare", V(0.8, 0.4, 0.2), cf * CF(s * 1.6, 2.4, -4.05), C.yellow, L.glow())
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

return P
