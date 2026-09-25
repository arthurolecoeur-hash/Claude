local L = require(script.Parent.SteamBuildLib)
local C = L.C
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local TAU = math.pi * 2
local SH = L.SHINY

local P = {}

local function ring(parent, cf, d, h, col)
	return L.vcyl(parent, "Cercle", h, d, cf, col)
end

--== AUTOMATE A VAPEUR ==--
function P.automaton(parent, cf, rng, o)
	o = o or {}
	local body = o.body or C.copper
	local trim = o.trim or C.brass
	local eye = o.eye or C.glowO
	local m = L.model("Automate", parent, cf)
	for _, s in { -1, 1 } do
		local leg = cf * CF(s * 0.9, 0, 0)
		L.part(m, "Pied", V(1.5, 0.6, 2.2), leg * CF(0, 0.3, -0.3), C.ironD)
		L.part(m, "PiedOrteil", V(1.5, 0.35, 0.5), leg * CF(0, 0.2, -1.55), trim)
		L.vcyl(m, "Cheville", 0.5, 0.9, leg * CF(0, 0.8, 0), C.steel)
		L.part(m, "Tibia", V(1.1, 1.8, 1.1), leg * CF(0, 1.9, 0), body)
		L.cyl(m, "Genou", 1.4, 0.9, leg * CF(0, 2.9, 0), trim)
		L.part(m, "Piston", V(0.3, 1.6, 0.3), leg * CF(0, 2, -0.7), C.steelL, SH)
		L.part(m, "Cuisse", V(1.2, 1.4, 1.2), leg * CF(0, 3.8, 0), C.iron)
	end
	L.part(m, "Bassin", V(3.2, 0.9, 1.9), cf * CF(0, 4.6, 0), C.ironD)
	local torso = cf * CF(0, 6.4, 0)
	L.part(m, "Torse", V(3.6, 2.8, 2.4), torso, body)
	L.part(m, "TorseHaut", V(3.9, 0.5, 2.6), torso * CF(0, 1.5, 0), trim)
	L.part(m, "TorseBas", V(3.7, 0.4, 2.5), torso * CF(0, -1.3, 0), trim)
	L.rivets(m, (torso * CF(-1.6, 1.1, -1.23)).Position, (torso * CF(1.6, 1.1, -1.23)).Position, 7, 0.16)
	L.rivets(m, (torso * CF(-1.6, -1.0, -1.23)).Position, (torso * CF(1.6, -1.0, -1.23)).Position, 7, 0.16)
	L.gauge(m, torso * CF(-0.7, 0.1, -1.25), 1.2, 60)
	L.part(m, "Fenetre", V(1, 1.1, 0.1), torso * CF(0.8, 0.1, -1.22), C.glowO, L.glow())
	for k = -1, 1 do
		L.part(m, "Grille", V(0.08, 1.1, 0.12), torso * CF(0.8 + k * 0.3, 0.1, -1.26), C.ironD)
	end
	L.light(L.anchor(m, "Foyer", torso * CF(0.8, 0.1, -1.5)), C.glowO, 8, 1)
	-- chaudiere dorsale
	local back = torso * CF(0, 0.3, 1.8)
	L.vcyl(m, "Chaudiere", 3, 1.8, back, C.copperD)
	for _, y in { -1, 0, 1 } do ring(m, back * CF(0, y, 0), 1.95, 0.2, trim) end
	L.vcyl(m, "Cheminee", 1.6, 0.6, back * CF(0.5, 2.2, 0.2), C.ironD)
	L.vcyl(m, "ChemineeBord", 0.25, 0.85, back * CF(0.5, 3, 0.2), trim)
	L.steam(m, back * CF(0.5, 3.3, 0.2), 1, 4)
	L.pipe(m, (back * CF(-0.9, 1, 0)).Position, (torso * CF(-1.5, 1.4, 0.3)).Position, 0.3)
	-- bras
	for _, s in { -1, 1 } do
		local sh = torso * CF(s * 2.3, 0.9, 0)
		L.gear(m, sh * CF(s * 0.1, 0, 0) * ANG(0, rad(90), 0), 1.6, 0.4, trim, 10)
		L.part(m, "Epaule", V(1.2, 1.2, 1.4), sh, C.iron)
		local elbow = sh * CF(s * 0.2, -1.7, -0.3)
		L.bar(m, "Bras", sh.Position, elbow.Position, 0.8, body)
		L.ball(m, "Coude", 0.9, elbow, trim, SH)
		local hand = elbow * CF(0, -1.2, -0.8)
		L.bar(m, "AvantBras", elbow.Position, hand.Position, 0.7, C.iron)
		L.part(m, "PistonBras", V(0.2, 0.2, 1.6), elbow * CF(s * 0.45, -0.6, -0.4) * ANG(rad(-35), 0, 0), C.steelL, SH)
		if s == 1 and o.tool == "cle" then
			L.part(m, "Cle", V(0.3, 2.6, 0.3), hand * CF(0, -0.8, -0.4) * ANG(rad(30), 0, 0), C.steel, SH)
			L.part(m, "CleTete", V(0.9, 0.4, 0.3), hand * CF(0, -2, -1.1) * ANG(rad(30), 0, 0), C.steel, SH)
		end
		L.part(m, "Paume", V(0.8, 0.6, 0.8), hand, C.ironD)
		for f = -1, 1 do
			L.part(m, "Doigt", V(0.18, 0.55, 0.18), hand * CF(f * 0.25, -0.5, -0.2) * ANG(rad(-15), 0, 0), trim)
		end
	end
	-- tete
	L.vcyl(m, "Cou", 0.6, 1, torso * CF(0, 1.9, 0), C.steel)
	local head = torso * CF(0, 3.2, 0)
	L.part(m, "Tete", V(2.4, 2, 2.2), head, body)
	L.part(m, "TeteDessus", V(2.6, 0.3, 2.4), head * CF(0, 1.1, 0), trim)
	L.part(m, "Machoire", V(2, 0.5, 0.2), head * CF(0, -0.6, -1.12), C.ironD)
	for k = -3, 3 do
		L.part(m, "Dent", V(0.1, 0.35, 0.1), head * CF(k * 0.25, -0.6, -1.24), C.steelL)
	end
	for _, s in { -1, 1 } do
		local e = head * CF(s * 0.55, 0.2, -1.12)
		L.cyl(m, "Lunette", 0.3, 0.85, e * ANG(0, rad(90), 0), trim, SH)
		L.cyl(m, "Oeil", 0.35, 0.6, e * CF(0, 0, -0.02) * ANG(0, rad(90), 0), eye, L.glow())
		L.part(m, "Oreille", V(0.3, 0.9, 0.9), head * CF(s * 1.3, 0.1, 0), trim)
		L.part(m, "Boulon", V(0.25, 0.25, 0.25), head * CF(s * 1.48, 0.1, 0), C.brassL)
	end
	L.light(L.anchor(m, "Regard", head * CF(0, 0.2, -1.6)), eye, 8, 1)
	if o.hat then
		L.vcyl(m, "ChapeauBord", 0.2, 3.2, head * CF(0, 1.35, 0), C.black)
		L.vcyl(m, "Chapeau", 1.8, 2, head * CF(0, 2.3, 0), C.black)
		ring(m, head * CF(0, 1.7, 0), 2.05, 0.35, C.red)
		L.gear(m, head * CF(0.7, 1.9, -1.02), 0.8, 0.15, trim, 8)
	else
		L.part(m, "Antenne", V(0.15, 1.2, 0.15), head * CF(0.6, 1.8, 0), C.steel)
		L.ball(m, "AntenneBoule", 0.4, head * CF(0.6, 2.5, 0), C.glowR, L.glow())
	end
	return m
end

--== DIRIGEABLE / MONTGOLFIERE ==--
function P.balloon(parent, cf, rng)
	local m = L.model("Montgolfiere", parent, cf)
	L.part(m, "Socle", V(6, 0.6, 6), cf * CF(0, 0.3, 0), C.iron)
	for _, x in { -2.4, 2.4 } do
		for _, z in { -2.4, 2.4 } do
			L.part(m, "Pieu", V(0.4, 1.2, 0.4), cf * CF(x, 1, z), C.brassD)
		end
	end
	local g = cf * CF(0, 4, 0)
	L.part(m, "Nacelle", V(4.4, 2.4, 4.4), g, C.leather)
	for k = 0, 4 do
		L.part(m, "Osier", V(4.45, 0.12, 4.45), g * CF(0, -1 + k * 0.5, 0), C.leatherD)
	end
	L.part(m, "NacelleBord", V(4.8, 0.4, 4.8), g * CF(0, 1.3, 0), C.brass)
	for _, s in { -1, 1 } do
		L.part(m, "SacLest", V(0.8, 1, 0.8), g * CF(s * 2.6, 0, -1), C.cream)
		L.part(m, "SacLestLien", V(0.85, 0.15, 0.85), g * CF(s * 2.6, 0.4, -1), C.leatherD)
	end
	L.gauge(m, g * CF(-1, 0.3, -2.25), 0.9, -20)
	L.vcyl(m, "Bruleur", 1, 1.2, g * CF(0, 2.6, 0), C.ironD)
	local fl = L.part(m, "Flamme", V(0.7, 1.2, 0.7), g * CF(0, 3.6, 0), C.glowO, L.glow({ CanCollide = false }))
	L.light(fl, C.glowO, 16, 1.6)
	for _, x in { -1.9, 1.9 } do
		for _, z in { -1.9, 1.9 } do
			L.bar(m, "Corde", (g * CF(x, 1.4, z)).Position, (g * CF(x * 0.55, 6.9, z * 0.55)).Position, 0.12, C.leatherD)
		end
	end
	local b = g * CF(0, 12, 0)
	local cols = { C.red, C.cream }
	local R, top, bot = 4.8, 6.2, -5
	local i = 0
	for y = bot, top, 0.7 do
		i += 1
		local t = (y - bot) / (top - bot)
		local r
		if t < 0.45 then
			r = 1.2 + (R - 1.2) * math.sin(t / 0.45 * math.pi / 2) ^ 0.8
		else
			r = R * math.sqrt(math.max(0, 1 - ((t - 0.45) / 0.55) ^ 2)) + 0.4
		end
		L.vcyl(m, "Ballon", 0.75, r * 2, b * CF(0, y, 0), (math.floor(i / 2) % 2 == 0) and C.red or C.cream)
	end
	for k = 0, 7 do
		local a = k / 8 * TAU
		for y = bot + 1, top - 1.5, 1.4 do
			local t = (y - bot) / (top - bot)
			local r = t < 0.45 and (1.2 + (R - 1.2) * math.sin(t / 0.45 * math.pi / 2) ^ 0.8) or (R * math.sqrt(math.max(0, 1 - ((t - 0.45) / 0.55) ^ 2)) + 0.4)
			L.part(m, "Couture", V(0.12, 1.3, 0.12), b * CF(math.cos(a) * r, y + 0.35, math.sin(a) * r), C.brass)
		end
	end
	ring(m, b * CF(0, 0.2, 0), 10.3, 0.4, C.brass)
	ring(m, b * CF(0, -5.2, 0), 2.6, 0.4, C.brass)
	L.vcyl(m, "Sommet", 0.4, 1.8, b * CF(0, 6.8, 0), C.brass)
	L.gear(m, b * CF(0, 1, -5.1), 2.4, 0.3, C.brass, 12)
	for _, s in { -1, 1 } do
		local h = g * CF(s * 3.2, 0.5, 1.5)
		L.part(m, "HeliceSupport", V(1.4, 0.3, 0.3), h * CF(-s * 0.6, 0, 0), C.iron)
		L.cyl(m, "HeliceMoteur", 0.9, 0.7, h * ANG(0, rad(90), 0), C.copper)
		for k = 0, 2 do
			L.part(m, "Pale", V(0.2, 1.6, 0.1), h * CF(0, 0, 0.5) * ANG(0, 0, k / 3 * TAU) * CF(0, 0.7, 0), C.woodL)
		end
	end
	return m
end

--== ORGUE A TUYAUX ==--
function P.pipeOrgan(parent, cf, rng)
	local m = L.model("OrgueAVapeur", parent, cf)
	L.part(m, "Socle", V(9, 1.2, 4), cf * CF(0, 0.6, 0), C.woodD)
	L.part(m, "SocleBord", V(9.3, 0.3, 4.3), cf * CF(0, 1.3, 0), C.brass)
	L.part(m, "Console", V(5, 2.6, 2), cf * CF(0, 2.6, -1.4), C.wood)
	L.part(m, "ConsoleDessus", V(5.3, 0.3, 2.3), cf * CF(0, 4, -1.4), C.brassD)
	for k = 0, 13 do
		local x = -2.2 + k * 0.34
		L.part(m, "Touche", V(0.3, 0.15, 0.8), cf * CF(x, 3.2, -2.4), (k % 3 == 1) and C.black or C.cream)
	end
	for i = -1, 1 do
		L.gauge(m, cf * CF(i * 1.4, 4.9, -1.9), 0.8, i * 40)
	end
	local heights = { 5, 7, 9, 11, 13, 11, 9, 7, 5 }
	for i, h in heights do
		local x = (i - 5) * 0.95
		local col = (i % 2 == 0) and C.brass or C.copper
		L.vcyl(m, "Tuyau", h, 0.8, cf * CF(x, 1.4 + h / 2, 0.6), col, SH)
		L.vcyl(m, "Bec", 0.3, 0.95, cf * CF(x, 3, 0.6), C.brassD)
		L.part(m, "Bouche", V(0.4, 0.5, 0.1), cf * CF(x, 3.6, 0.19), C.dark)
		L.vcyl(m, "Bout", 0.3, 0.95, cf * CF(x, 1.4 + h, 0.6), C.brassL)
		if i == 5 or i == 2 or i == 8 then
			L.steam(m, cf * CF(x, 1.8 + h, 0.6), 0.6, 3)
		end
	end
	L.gear(m, cf * CF(-4.3, 6, 0.6) * ANG(0, rad(90), 0), 3, 0.4, C.brass, 14)
	L.gear(m, cf * CF(4.3, 5, 0.6) * ANG(0, rad(90), 0), 2.2, 0.4, C.copper, 11)
	L.pipe(m, (cf * CF(-4.2, 1.4, 1.8)).Position, (cf * CF(-4.2, 4, 1.8)).Position, 0.4)
	L.valve(m, cf * CF(-4.2, 3, 1.3) * ANG(0, 0, 0), 1.1)
	L.part(m, "Banc", V(3, 0.4, 1), cf * CF(0, 1.6, -3.2), C.leather)
	L.part(m, "BancPied", V(2.6, 1.2, 0.6), cf * CF(0, 0.7, -3.2), C.woodD)
	return m
end

--== TOUR A ENGRENAGES ==--
function P.gearTower(parent, cf, rng)
	local m = L.model("TourEngrenages", parent, cf)
	L.part(m, "Socle", V(6, 1, 6), cf * CF(0, 0.5, 0), C.ironD)
	L.part(m, "Pilier", V(2.2, 16, 2.2), cf * CF(0, 9, 0), C.iron)
	for y = 2, 16, 3.5 do
		L.part(m, "Collier", V(2.6, 0.4, 2.6), cf * CF(0, y, 0), C.brass)
		L.rivets(m, (cf * CF(-1.1, y + 0.4, -1.12)).Position, (cf * CF(1.1, y + 0.4, -1.12)).Position, 4, 0.18)
	end
	local sizes = { { 5, 4, C.brass }, { 3.4, 7.5, C.copper }, { 4.2, 10.5, C.brass }, { 2.6, 13.4, C.copperL }, { 3.6, 15.8, C.brassD } }
	for i, g in sizes do
		local side = (i % 2 == 0) and -1 or 1
		L.gear(m, cf * CF(0, g[2], side * 1.4) * ANG(0, 0, rad(i * 13)), g[1], 0.5, g[3])
	end
	L.gear(m, cf * CF(1.4, 6, 0) * ANG(0, rad(90), 0), 3.2, 0.5, C.copperD)
	L.gear(m, cf * CF(-1.4, 12, 0) * ANG(0, rad(90), 0), 3.8, 0.5, C.brass)
	local top = cf * CF(0, 17.6, 0)
	L.part(m, "Chapiteau", V(3.2, 1, 3.2), top, C.brass)
	L.vcyl(m, "Dome", 1.2, 2.4, top * CF(0, 1, 0), C.copper)
	local bulb = L.ball(m, "Ampoule", 1.4, top * CF(0, 2.2, 0), C.glowY, L.glow({ Transparency = 0.1 }))
	L.light(bulb, C.glowY, 22, 1.5)
	for i = 0, 3 do
		local a = i / 4 * TAU
		L.part(m, "Griffe", V(0.2, 1.4, 0.2), top * CF(math.cos(a) * 0.8, 2.2, math.sin(a) * 0.8) * ANG(math.sin(a) * 0.3, 0, -math.cos(a) * 0.3), C.brass)
	end
	return m
end

--== TELESCOPE EN LAITON ==--
function P.telescope(parent, cf, rng)
	local m = L.model("Telescope", parent, cf)
	for i = 0, 2 do
		local a = i / 3 * TAU
		L.bar(m, "Trepied", (cf * CF(0, 4, 0)).Position, (cf * CF(math.cos(a) * 2.2, 0.1, math.sin(a) * 2.2)).Position, 0.3, C.woodD)
		L.part(m, "Sabot", V(0.5, 0.25, 0.5), cf * CF(math.cos(a) * 2.2, 0.12, math.sin(a) * 2.2), C.brass)
	end
	L.vcyl(m, "Rotule", 0.6, 0.9, cf * CF(0, 4.2, 0), C.brassD, SH)
	local t = cf * CF(0, 4.9, 0) * ANG(rad(25), 0, 0)
	L.cyl(m, "Tube", 5, 0.9, t * ANG(0, rad(90), 0), C.brass, SH)
	L.cyl(m, "Tube2", 1.8, 0.7, t * CF(0, 0, 3.2) * ANG(0, rad(90), 0), C.brassL, SH)
	L.cyl(m, "Oculaire", 0.8, 0.45, t * CF(0, 0, 4.4) * ANG(0, rad(90), 0), C.ironD)
	L.cyl(m, "Pare", 1, 1.3, t * CF(0, 0, -2.8) * ANG(0, rad(90), 0), C.copper, SH)
	L.cyl(m, "Lentille", 0.1, 1.1, t * CF(0, 0, -3.3) * ANG(0, rad(90), 0), C.glowC, L.glow({ Transparency = 0.3 }))
	for _, z in { -1.5, 0, 1.5 } do
		L.cyl(m, "Bague", 0.25, 1.05, t * CF(0, 0, z) * ANG(0, rad(90), 0), C.copperD)
	end
	L.cyl(m, "Chercheur", 1.6, 0.3, t * CF(0.6, 0.4, 0.5) * ANG(0, rad(90), 0), C.brassD)
	L.gear(m, cf * CF(0.6, 4.4, 0) * ANG(0, rad(90), 0), 1, 0.2, C.copper, 9)
	return m
end

--== VOITURE A VAPEUR ==--
function P.steamCar(parent, cf, rng, col)
	col = col or C.red
	local m = L.model("VoitureAVapeur", parent, cf)
	for _, x in { -1.9, 1.9 } do
		for _, z in { -2.4, 2.6 } do
			local w = cf * CF(x, 1.3, z)
			L.cyl(m, "Pneu", 0.5, 2.6, w, C.black)
			L.cyl(m, "Jante", 0.55, 1.8, w, C.brass, SH)
			for k = 0, 5 do
				L.part(m, "Rayon", V(0.56, 1.6, 0.1), w * ANG(k / 6 * math.pi, 0, 0), C.brassD)
			end
			L.cyl(m, "Moyeu", 0.7, 0.5, w, C.brassL)
			L.part(m, "GardeBoue", V(0.9, 0.2, 2.9), w * CF(0, 1.5, 0), col)
		end
	end
	L.part(m, "Chassis", V(3.4, 0.5, 7), cf * CF(0, 1.5, 0.1), C.ironD)
	L.part(m, "Caisse", V(3.2, 1.4, 3.2), cf * CF(0, 2.4, 1.5), col)
	L.part(m, "CaisseBord", V(3.4, 0.25, 3.4), cf * CF(0, 3.2, 1.5), C.brass)
	L.part(m, "Siege", V(2.8, 0.6, 1.2), cf * CF(0, 3.3, 2.4), C.leather)
	L.part(m, "Dossier", V(2.8, 1.4, 0.4), cf * CF(0, 3.9, 3), C.leather)
	for k = -1, 1 do
		L.part(m, "Capiton", V(0.2, 0.2, 0.05), cf * CF(k * 0.8, 4, 2.78), C.brassL)
	end
	local boiler = cf * CF(0, 3, -1.5) * ANG(rad(90), 0, 0)
	L.vcyl(m, "Chaudiere", 3.4, 2.4, boiler, C.copper, SH)
	for _, y in { -1.2, 0, 1.2 } do ring(m, boiler * CF(0, y, 0), 2.55, 0.2, C.brass) end
	L.cyl(m, "Calandre", 0.3, 2.3, cf * CF(0, 3, -3.3) * ANG(0, rad(90), 0), C.brassD)
	for k = -2, 2 do
		L.part(m, "Grille", V(0.1, 1.8, 0.1), cf * CF(k * 0.35, 3, -3.47), C.ironD)
	end
	for _, s in { -1, 1 } do
		local lamp = cf * CF(s * 1.4, 3.7, -3.2)
		L.cyl(m, "Phare", 0.5, 0.8, lamp * ANG(0, rad(90), 0), C.brass, SH)
		L.cyl(m, "PhareVerre", 0.1, 0.6, lamp * CF(0, 0, -0.28) * ANG(0, rad(90), 0), C.glowY, L.glow())
		L.light(L.anchor(m, "Faisceau", lamp * CF(0, 0, -0.6)), C.glowY, 14, 1.2)
	end
	L.vcyl(m, "Cheminee", 2.6, 0.6, cf * CF(0, 5.2, -1.2), C.ironD)
	L.vcyl(m, "ChemineeHaut", 0.4, 1, cf * CF(0, 6.6, -1.2), C.brass)
	L.steam(m, cf * CF(0, 7, -1.2), 1.1, 5)
	L.gauge(m, cf * CF(0.8, 3.9, 0.08) * ANG(0, math.pi, 0), 0.7, 20)
	L.part(m, "Colonne", V(0.2, 1.4, 0.2), cf * CF(-0.6, 3.6, 0.6) * ANG(rad(-25), 0, 0), C.steel)
	L.valve(m, cf * CF(-0.6, 4.3, 0.3) * ANG(rad(-65), 0, 0), 1)
	L.part(m, "Klaxon", V(0.3, 0.3, 1), cf * CF(1.5, 3.9, 0.3), C.brass, SH)
	L.part(m, "KlaxonPavillon", V(0.6, 0.6, 0.3), cf * CF(1.5, 3.9, -0.3), C.brassL, SH)
	L.part(m, "Malle", V(2.6, 1.2, 1.2), cf * CF(0, 2.5, 3.9), C.leatherD)
	L.part(m, "MalleSangle", V(2.65, 1.25, 0.2), cf * CF(0, 2.5, 3.9), C.brassD)
	return m
end

--== RESERVOIR SOUS PRESSION ==--
function P.pressureTank(parent, cf, rng)
	local m = L.model("ReservoirPression", parent, cf)
	L.part(m, "Socle", V(5, 0.5, 5), cf * CF(0, 0.25, 0), C.ironD)
	for _, x in { -1.6, 1.6 } do
		for _, z in { -1.6, 1.6 } do
			L.part(m, "Pied", V(0.5, 1.6, 0.5), cf * CF(x, 1.2, z), C.iron)
		end
	end
	local t = cf * CF(0, 5, 0)
	L.vcyl(m, "Cuve", 6, 3.8, t, C.copper, SH)
	L.ball(m, "Dome", 3.8, t * CF(0, 3, 0), C.copper, SH)
	L.ball(m, "DomeBas", 3.8, t * CF(0, -3, 0), C.copperD)
	for _, y in { -2.4, -0.8, 0.8, 2.4 } do
		ring(m, t * CF(0, y, 0), 3.95, 0.25, C.brass)
		for k = 0, 11 do
			local a = k / 12 * TAU
			L.part(m, "Rivet", V(0.15, 0.15, 0.15), t * CF(math.cos(a) * 1.98, y + 0.25, math.sin(a) * 1.98), C.brassL)
		end
	end
	L.gauge(m, t * CF(0, 1.4, -2), 1.2, 110)
	L.gauge(m, t * CF(-1.3, -0.8, -1.55) * ANG(0, rad(40), 0), 0.8, -40)
	L.part(m, "Hublot", V(1, 1.4, 0.2), t * CF(1, -0.5, -1.85) * ANG(0, rad(-30), 0), C.brass)
	L.part(m, "HubloVerre", V(0.7, 1.1, 0.1), t * CF(1, -0.5, -1.97) * ANG(0, rad(-30), 0), C.glowG, L.glow({ Transparency = 0.3 }))
	L.pipe(m, (t * CF(0, 4.2, 0)).Position, (t * CF(0, 5.4, 0)).Position, 0.5)
	L.part(m, "Soupape", V(0.9, 0.5, 0.9), t * CF(0, 5.6, 0), C.brass)
	L.steam(m, t * CF(0, 6, 0), 0.8, 5)
	L.pipe(m, (t * CF(1.9, 1.5, 0)).Position, (t * CF(3.2, 1.5, 0)).Position, 0.5)
	L.pipe(m, (t * CF(3.2, 1.5, 0)).Position, (cf * CF(3.2, 0.5, 0)).Position, 0.5)
	L.valve(m, t * CF(2.7, 1.5, -0.5), 1.1)
	L.part(m, "Plaque", V(1.6, 0.6, 0.1), t * CF(0, -2, -1.95), C.brass)
	return m
end

--== GRUE A VAPEUR ==--
function P.crane(parent, cf, rng)
	local m = L.model("GrueAVapeur", parent, cf)
	L.part(m, "Socle", V(5, 1, 5), cf * CF(0, 0.5, 0), C.ironD)
	L.vcyl(m, "Pivot", 0.8, 4, cf * CF(0, 1.4, 0), C.brass)
	local cab = cf * CF(0, 3.4, 0.6)
	L.part(m, "Cabine", V(3.4, 3.2, 3.6), cab, C.copper)
	L.part(m, "CabineToit", V(3.8, 0.4, 4), cab * CF(0, 1.8, 0), C.ironD)
	L.part(m, "Fenetre", V(2.4, 1.2, 0.1), cab * CF(0, 0.5, -1.82), C.glass, { Material = Enum.Material.Glass, MaterialVariant = "", Transparency = 0.3 })
	L.rivets(m, (cab * CF(-1.6, -1.4, -1.82)).Position, (cab * CF(1.6, -1.4, -1.82)).Position, 6, 0.16)
	L.vcyl(m, "Cheminee", 2, 0.6, cab * CF(1, 2.8, 1.2), C.ironD)
	L.steam(m, cab * CF(1, 3.9, 1.2), 0.9, 4)
	L.cyl(m, "Treuil", 2.6, 1.2, cab * CF(0, -0.4, 2.1), C.brassD)
	-- fleche en treillis
	local base = cab * CF(0, 1.2, -1.2)
	local tip = cab * CF(0, 9, -9)
	for _, s in { -0.6, 0.6 } do
		L.bar(m, "Fleche", (base * CF(s, 0, 0)).Position, (tip * CF(s * 0.4, 0, 0)).Position, 0.3, C.brass)
		L.bar(m, "Fleche", (base * CF(s, 1, 0)).Position, (tip * CF(s * 0.4, 0.4, 0)).Position, 0.25, C.brass)
	end
	for k = 1, 7 do
		local t = k / 8
		local a = base.Position:Lerp(tip.Position, t)
		L.part(m, "Traverse", V(1.2 * (1 - t * 0.6), 0.15, 0.15), CF(a) * cab.Rotation, C.brassD)
		L.bar(m, "Diagonale", a, base.Position:Lerp(tip.Position, t + 0.12) + V(0, 0.7, 0), 0.12, C.brassD)
	end
	L.part(m, "Poulie", V(0.5, 0.9, 0.9), tip, C.iron)
	L.part(m, "Cable", V(0.08, 5, 0.08), tip * CF(0, -2.8, 0), C.ironD)
	L.part(m, "Crochet", V(0.3, 0.8, 0.3), tip * CF(0, -5.6, 0), C.steel, SH)
	L.part(m, "CrochetBas", V(0.3, 0.3, 0.7), tip * CF(0, -6, -0.2), C.steel, SH)
	local crate = tip * CF(0, -7.6, 0)
	L.part(m, "Caisse", V(2.2, 2.2, 2.2), crate, C.wood)
	L.part(m, "CaisseCadre", V(2.3, 0.25, 2.3), crate * CF(0, 1, 0), C.woodD)
	L.part(m, "CaisseCadre", V(2.3, 0.25, 2.3), crate * CF(0, -1, 0), C.woodD)
	for _, s in { -1, 1 } do
		L.bar(m, "Elingue", (tip * CF(0, -6, 0)).Position, (crate * CF(s * 1, 1.1, 0)).Position, 0.08, C.ironD)
	end
	L.part(m, "Contrepoids", V(3, 2, 1.4), cab * CF(0, -0.2, 2.9), C.ironD)
	L.gear(m, cab * CF(1.75, 0, 0) * ANG(0, rad(90), 0), 2, 0.3, C.brass, 10)
	return m
end

--== HIBOU MECANIQUE ==--
function P.owl(parent, cf, rng)
	local m = L.model("HibouMecanique", parent, cf)
	L.part(m, "Perchoir", V(0.4, 5, 0.4), cf * CF(0, 2.5, 0), C.iron)
	L.part(m, "PerchoirPied", V(2, 0.4, 2), cf * CF(0, 0.2, 0), C.ironD)
	L.part(m, "Barre", V(2.4, 0.3, 0.3), cf * CF(0, 5, 0), C.brass)
	local b = cf * CF(0, 6.3, 0)
	L.part(m, "Corps", V(1.8, 2.2, 1.6), b, C.brass)
	L.part(m, "Ventre", V(1.3, 1.6, 0.1), b * CF(0, -0.1, -0.82), C.copperL)
	for r = 0, 2 do
		for c = -1, 1 do
			L.part(m, "Plume", V(0.35, 0.3, 0.06), b * CF(c * 0.38, 0.4 - r * 0.45, -0.88) * ANG(0, 0, rad(45)), C.copperD)
		end
	end
	for _, s in { -1, 1 } do
		L.part(m, "Aile", V(0.25, 1.8, 1.4), b * CF(s * 1, -0.1, 0.1), C.copper)
		for k = 0, 3 do
			L.part(m, "AilePlume", V(0.3, 0.2, 1.3), b * CF(s * 1.02, 0.6 - k * 0.45, 0.1), C.brassD)
		end
		L.part(m, "Serre", V(0.35, 0.4, 0.6), b * CF(s * 0.4, -1.25, -0.1), C.steel)
	end
	local h = b * CF(0, 1.7, 0)
	L.part(m, "Tete", V(1.9, 1.3, 1.6), h, C.brass)
	for _, s in { -1, 1 } do
		L.wedge(m, "Aigrette", V(0.3, 0.8, 0.6), h * CF(s * 0.7, 0.9, 0), C.copperD)
		local e = h * CF(s * 0.45, 0.05, -0.8)
		L.cyl(m, "Monocle", 0.2, 0.8, e * ANG(0, rad(90), 0), C.copperD, SH)
		L.cyl(m, "Oeil", 0.25, 0.55, e * CF(0, 0, -0.02) * ANG(0, rad(90), 0), C.glowY, L.glow())
		L.cyl(m, "Pupille", 0.28, 0.2, e * CF(0, 0, -0.05) * ANG(0, rad(90), 0), C.black)
	end
	L.wedge(m, "Bec", V(0.35, 0.5, 0.4), h * CF(0, -0.35, -0.9) * ANG(math.pi, 0, 0), C.steelL)
	L.gear(m, b * CF(0, -0.2, 0.82), 1, 0.12, C.brassL, 8)
	L.part(m, "Cle", V(0.15, 0.15, 0.9), b * CF(0, 0.3, 1.2), C.steel)
	L.part(m, "CleTete", V(0.8, 0.5, 0.12), b * CF(0, 0.3, 1.7), C.brass)
	return m
end

--== CHATEAU D'EAU ==--
function P.waterTower(parent, cf, rng)
	local m = L.model("ChateauDEau", parent, cf)
	for _, x in { -2.6, 2.6 } do
		for _, z in { -2.6, 2.6 } do
			L.part(m, "Pilier", V(0.7, 12, 0.7), cf * CF(x, 6, z), C.iron)
			L.part(m, "PilierPied", V(1.4, 0.6, 1.4), cf * CF(x, 0.3, z), C.ironD)
		end
	end
	for _, y in { 4, 8 } do
		for _, s in { -1, 1 } do
			L.part(m, "Traverse", V(5.6, 0.3, 0.3), cf * CF(0, y, s * 2.6), C.brassD)
			L.part(m, "Traverse", V(0.3, 0.3, 5.6), cf * CF(s * 2.6, y, 0), C.brassD)
			L.bar(m, "Croix", (cf * CF(-2.6, y - 3.8, s * 2.6)).Position, (cf * CF(2.6, y, s * 2.6)).Position, 0.15, C.ironD)
		end
	end
	local t = cf * CF(0, 15.5, 0)
	L.vcyl(m, "Cuve", 6, 7.4, t, C.copper)
	for y = -2.5, 2.5, 1 do ring(m, t * CF(0, y, 0), 7.55, 0.2, C.brassD) end
	for i = 0, 5 do
		L.vcyl(m, "Toit", 0.5, 7.8 - i * 1.3, t * CF(0, 3.25 + i * 0.5, 0), (i % 2 == 0) and C.ironD or C.iron)
	end
	L.part(m, "Girouette", V(0.2, 2, 0.2), t * CF(0, 7, 0), C.brass)
	L.part(m, "GirouetteFleche", V(0.15, 0.3, 2), t * CF(0, 7.6, 0), C.brass)
	L.gauge(m, t * CF(0, 0, -3.72), 2.2, 80)
	L.part(m, "Passerelle", V(9, 0.3, 9), cf * CF(0, 12.3, 0), C.ironD)
	for i = 0, 15 do
		local a = i / 16 * TAU
		L.part(m, "Garde", V(0.15, 1.2, 0.15), cf * CF(math.cos(a) * 4.4, 13, math.sin(a) * 4.4), C.brass)
	end
	for k = 0, 11 do
		L.part(m, "Echelon", V(1.2, 0.15, 0.15), cf * CF(0, 0.6 + k * 1, -2.95), C.steel)
	end
	L.pipe(m, (t * CF(2.5, -3, 0)).Position, (cf * CF(2.5, 0.5, 0)).Position, 0.7)
	L.valve(m, cf * CF(2.5, 2, -0.6), 1.2)
	return m
end

--== LAMPADAIRE DOUBLE A ENGRENAGE ==--
function P.fancyLamp(parent, cf, rng)
	local m = L.model("LampadaireVapeur", parent, cf)
	L.part(m, "Socle", V(2.2, 0.6, 2.2), cf * CF(0, 0.3, 0), C.ironD)
	L.part(m, "SocleHaut", V(1.6, 0.8, 1.6), cf * CF(0, 1, 0), C.iron)
	L.vcyl(m, "Mat", 9, 0.5, cf * CF(0, 5.9, 0), C.ironD)
	for _, y in { 2, 5, 8 } do ring(m, cf * CF(0, y, 0), 0.8, 0.3, C.brass) end
	L.gear(m, cf * CF(0, 7, -0.35), 1.6, 0.2, C.brass, 10)
	L.part(m, "Crosse", V(4.6, 0.3, 0.3), cf * CF(0, 10.2, 0), C.ironD)
	for _, s in { -1, 1 } do
		L.part(m, "Volute", V(0.3, 1, 0.3), cf * CF(s * 2.2, 9.8, 0), C.ironD)
		local lamp = cf * CF(s * 2.2, 8.7, 0)
		L.part(m, "LanterneToit", V(1.3, 0.4, 1.3), lamp * CF(0, 0.9, 0), C.copper)
		L.part(m, "LanternePointe", V(0.4, 0.4, 0.4), lamp * CF(0, 1.3, 0), C.brass)
		local g = L.part(m, "Verre", V(0.9, 1.2, 0.9), lamp, C.glowO, L.glow({ Transparency = 0.15 }))
		for _, x in { -0.45, 0.45 } do
			for _, z in { -0.45, 0.45 } do
				L.part(m, "Montant", V(0.1, 1.3, 0.1), lamp * CF(x, 0, z), C.brassD)
			end
		end
		L.part(m, "LanterneBas", V(1, 0.3, 1), lamp * CF(0, -0.75, 0), C.copper)
		L.light(g, C.glowO, 16, 1.4)
	end
	L.part(m, "Panneau", V(2.2, 0.8, 0.12), cf * CF(0.9, 4, -0.3), C.brass)
	return m
end

--== BANC EN FONTE ==--
function P.bench(parent, cf, rng)
	local m = L.model("BancFonte", parent, cf)
	for _, x in { -2.3, 2.3 } do
		L.part(m, "Pied", V(0.3, 1.8, 1.8), cf * CF(x, 0.9, 0), C.ironD)
		L.part(m, "Accoudoir", V(0.35, 0.3, 1.8), cf * CF(x, 2.2, -0.1), C.ironD)
		L.gear(m, cf * CF(x, 1.1, 0) * ANG(0, rad(90), 0), 1.2, 0.35, C.brass, 8)
	end
	for k = 0, 3 do
		L.part(m, "Latte", V(4.6, 0.2, 0.4), cf * CF(0, 1.6, -0.6 + k * 0.45), C.woodL)
	end
	for k = 0, 2 do
		L.part(m, "Dossier", V(4.6, 0.4, 0.2), cf * CF(0, 2.2 + k * 0.5, 0.9) * ANG(rad(-10), 0, 0), C.woodL)
	end
	L.part(m, "Chapeau", V(1, 0.15, 1), cf * CF(1, 1.8, -0.2), C.black)
	L.vcyl(m, "ChapeauHaut", 0.7, 0.7, cf * CF(1, 2.2, -0.2), C.black)
	L.part(m, "Journal", V(1, 0.08, 0.7), cf * CF(-1.2, 1.75, -0.2) * ANG(0, 0.3, 0), C.paper)
	return m
end

--== POTEAU INDICATEUR ==--
function P.signpost(parent, cf, rng)
	local m = L.model("PoteauIndicateur", parent, cf)
	L.part(m, "Socle", V(1.8, 0.5, 1.8), cf * CF(0, 0.25, 0), C.ironD)
	L.vcyl(m, "Mat", 8, 0.5, cf * CF(0, 4.4, 0), C.ironD)
	L.ball(m, "Pommeau", 0.8, cf * CF(0, 8.6, 0), C.brass, SH)
	local names = { { "USINE", 20 }, { "HORLOGE", -35 }, { "GARE", 150 } }
	for i, n in names do
		local a = cf * CF(0, 7.2 - i * 1.2, 0) * ANG(0, rad(n[2]), 0)
		local plate = L.part(m, "Fleche", V(3.4, 0.8, 0.15), a * CF(1.6, 0, 0), C.brass)
		L.wedge(m, "FlechePointe", V(0.15, 0.8, 0.6), a * CF(3.6, 0, 0) * ANG(0, rad(-90), 0), C.brass)
		L.label(plate, Enum.NormalId.Front, n[1], C.dark, Enum.Font.Fantasy)
		L.label(plate, Enum.NormalId.Back, n[1], C.dark, Enum.Font.Fantasy)
	end
	L.gear(m, cf * CF(0, 2.5, -0.3), 1.4, 0.2, C.copper, 9)
	return m
end

--== LABORATOIRE D'INVENTEUR ==--
function P.inventorDesk(parent, cf, rng)
	local m = L.model("BureauInventeur", parent, cf)
	L.part(m, "Plateau", V(7, 0.4, 3.4), cf * CF(0, 3, 0), C.wood)
	L.part(m, "PlateauBord", V(7.2, 0.2, 3.6), cf * CF(0, 2.75, 0), C.brassD)
	for _, x in { -3.2, 3.2 } do
		L.part(m, "Caisson", V(1.2, 2.7, 3), cf * CF(x, 1.35, 0), C.woodD)
		for k = 0, 2 do
			L.part(m, "Tiroir", V(0.1, 0.7, 2.4), cf * CF(x, 0.6 + k * 0.85, -1.52) * ANG(0, rad(90), 0), C.wood)
			L.part(m, "Poignee", V(0.4, 0.12, 0.12), cf * CF(x, 0.6 + k * 0.85, -1.6), C.brass)
		end
	end
	local plan = L.part(m, "Plan", V(3, 0.06, 2), cf * CF(0.2, 3.23, 0) * ANG(0, rad(8), 0), C.blue:Lerp(C.panel, 0.5))
	for k = 0, 3 do
		L.part(m, "PlanTrait", V(2.4, 0.07, 0.05), plan.CFrame * CF(0, 0.01, -0.6 + k * 0.4), C.white)
	end
	L.gear(m, plan.CFrame * CF(0.6, 0.02, 0) * ANG(rad(90), 0, 0), 1, 0.02, C.white, 8)
	-- lampe articulee
	local lb = cf * CF(-2.4, 3.2, 1)
	L.vcyl(m, "LampeSocle", 0.2, 1, lb, C.brass)
	L.bar(m, "LampeBras", lb.Position, (lb * CF(0.4, 2.2, -0.4)).Position, 0.15, C.brassD)
	L.bar(m, "LampeBras", (lb * CF(0.4, 2.2, -0.4)).Position, (lb * CF(1.4, 1.8, -1.2)).Position, 0.15, C.brassD)
	local lh = L.part(m, "LampeTete", V(0.7, 0.5, 0.7), lb * CF(1.4, 1.6, -1.2), C.copper)
	L.part(m, "Ampoule", V(0.4, 0.3, 0.4), lb * CF(1.4, 1.3, -1.2), C.glowY, L.glow())
	L.light(lh, C.glowY, 12, 1.2)
	-- fioles
	for i, col in { C.glowG, C.pink, C.cyan, C.glowO } do
		local f = cf * CF(1.6 + (i - 1) * 0.55, 3.2, 1.1)
		L.part(m, "Fiole", V(0.4, 0.8, 0.4), f * CF(0, 0.4, 0), col, L.glow({ Transparency = 0.3 }))
		L.part(m, "Bouchon", V(0.25, 0.2, 0.25), f * CF(0, 0.9, 0), C.woodL)
	end
	L.part(m, "Portoir", V(2.4, 0.2, 0.6), cf * CF(2.4, 3.3, 1.1), C.woodD)
	-- globe
	L.vcyl(m, "GlobePied", 0.4, 0.6, cf * CF(-0.9, 3.4, 1.1), C.brass)
	L.ball(m, "Globe", 1.1, cf * CF(-0.9, 4.2, 1.1), C.teal)
	L.cyl(m, "GlobeArc", 0.1, 1.4, cf * CF(-0.9, 4.2, 1.1) * ANG(0, 0, rad(70)), C.brass)
	-- outils et engrenages
	L.part(m, "Cle", V(1.6, 0.12, 0.25), cf * CF(-1.6, 3.26, -1) * ANG(0, 0.5, 0), C.steel, SH)
	L.part(m, "Tournevis", V(1.2, 0.12, 0.12), cf * CF(-0.6, 3.26, -1.2) * ANG(0, -0.3, 0), C.red)
	L.gear(m, cf * CF(1.2, 3.25, -1) * ANG(rad(90), 0, 0), 0.8, 0.1, C.brass, 8)
	L.gear(m, cf * CF(1.9, 3.25, -0.7) * ANG(rad(90), 0, 0), 0.6, 0.1, C.copper, 7)
	-- tableau noir
	L.part(m, "Tableau", V(5, 3, 0.2), cf * CF(0, 6.6, 1.8), C.dark)
	L.part(m, "TableauCadre", V(5.3, 3.3, 0.15), cf * CF(0, 6.6, 1.9), C.woodD)
	for k = 0, 3 do
		L.part(m, "Craie", V(rng:NextNumber(1.5, 3.5), 0.08, 0.05), cf * CF(rng:NextNumber(-1, 1), 5.6 + k * 0.6, 1.68), C.white)
	end
	L.gear(m, cf * CF(1.5, 7, 1.68), 1.2, 0.02, C.white, 9)
	for _, x in { -2.4, 2.4 } do
		L.part(m, "Support", V(0.3, 3.4, 0.3), cf * CF(x, 4.8, 1.8), C.woodD)
	end
	-- tabouret
	L.vcyl(m, "Tabouret", 0.3, 1.4, cf * CF(0, 2, -2.4), C.leather)
	L.vcyl(m, "TabouretPied", 1.8, 0.3, cf * CF(0, 1, -2.4), C.brassD)
	return m
end

--== ARAIGNEE MECANIQUE GEANTE ==--
function P.mechSpider(parent, cf, rng)
	local m = L.model("AraigneeMecanique", parent, cf)
	local body = cf * CF(0, 4, 0)
	L.ball(m, "Abdomen", 4, body * CF(0, 0.3, 1.8), C.copper, SH)
	for _, y in { -0.6, 0.3, 1.2 } do
		L.cyl(m, "Bande", 0.3, 4.1 - math.abs(y) * 0.6, body * CF(0, y, 1.8) * ANG(0, 0, rad(90)), C.brass)
	end
	L.part(m, "Thorax", V(3, 1.8, 2.6), body * CF(0, 0, -0.6), C.iron)
	L.part(m, "ThoraxHaut", V(2.6, 0.4, 2.2), body * CF(0, 1, -0.6), C.brass)
	local head = body * CF(0, 0.2, -2.3)
	L.part(m, "Tete", V(2, 1.4, 1.2), head, C.copperD)
	for _, x in { -0.5, 0.5 } do
		L.cyl(m, "Oeil", 0.2, 0.55, head * CF(x, 0.2, -0.62) * ANG(0, rad(90), 0), C.glowR, L.glow())
	end
	for _, x in { -0.8, 0.8 } do
		L.cyl(m, "OeilPetit", 0.2, 0.3, head * CF(x, -0.3, -0.62) * ANG(0, rad(90), 0), C.glowR, L.glow())
	end
	L.light(L.anchor(m, "Regard", head * CF(0, 0, -1)), C.glowR, 12, 1.4)
	for _, s in { -1, 1 } do
		L.part(m, "Mandibule", V(0.3, 0.3, 1), head * CF(s * 0.5, -0.7, -0.8) * ANG(0, s * rad(15), 0), C.steelL, SH)
	end
	for _, s in { -1, 1 } do
		for i = 0, 3 do
			local z = -1.4 + i * 0.8
			local hip = body * CF(s * 1.5, 0, z)
			local knee = body * CF(s * 3.8, 1.8, z * 1.5)
			local foot = cf * CF(s * 5.6, 0.2, z * 2)
			L.ball(m, "Hanche", 0.8, hip, C.brass, SH)
			L.bar(m, "Cuisse", hip.Position, knee.Position, 0.45, C.iron)
			L.part(m, "Piston", V(0.15, 0.15, (knee.Position - hip.Position).Magnitude * 0.7), CFrame.lookAt((hip.Position + knee.Position) / 2 + V(0, 0.35, 0), knee.Position + V(0, 0.35, 0)), C.steelL, SH)
			L.ball(m, "Genou", 0.7, knee, C.copper, SH)
			L.bar(m, "Patte", knee.Position, foot.Position, 0.35, C.ironD)
			L.part(m, "Griffe", V(0.3, 0.5, 0.3), foot, C.brass)
		end
	end
	L.gear(m, body * CF(0, 1.5, -0.6) * ANG(rad(90), 0, 0), 1.6, 0.3, C.brass, 10)
	L.vcyl(m, "Cheminee", 1.4, 0.5, body * CF(0, 2.6, 1.8), C.ironD)
	L.steam(m, body * CF(0, 3.4, 1.8), 0.8, 4)
	return m
end

return P
