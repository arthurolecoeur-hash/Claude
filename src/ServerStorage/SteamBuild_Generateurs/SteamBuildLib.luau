local L = {}
L.MV = "Studs"
local C = Color3.fromRGB
L.C = {
	copper = C(184, 104, 56), copperD = C(132, 70, 38), copperL = C(222, 150, 96),
	brass = C(206, 166, 72), brassD = C(154, 116, 44), brassL = C(240, 206, 120),
	iron = C(58, 58, 66), ironD = C(32, 32, 38), steel = C(146, 150, 160), steelL = C(196, 200, 208),
	leather = C(112, 66, 38), leatherD = C(78, 44, 24), wood = C(126, 82, 46), woodD = C(88, 56, 30), woodL = C(170, 120, 72),
	red = C(164, 36, 36), redD = C(110, 22, 22), green = C(60, 140, 90), teal = C(46, 150, 150),
	cream = C(236, 226, 196), paper = C(232, 214, 170), black = C(12, 12, 14), dark = C(24, 22, 26), white = C(245, 245, 240),
	glowO = C(255, 170, 60), glowY = C(255, 220, 110), glowC = C(90, 220, 255), glowG = C(120, 255, 140), glowR = C(255, 70, 50),
	glass = C(170, 220, 230), smoke = C(210, 210, 210), coal = C(40, 36, 34),
	yellow = C(255, 220, 90), orange = C(255, 140, 40), gold = C(255, 196, 60), goldD = C(206, 142, 30), metalL = C(228, 232, 240), metalD = C(110, 116, 132), pink = C(255, 90, 210), cyan = C(70, 236, 255), purple = C(170, 90, 255), blue = C(70, 120, 255), panel = C(40, 80, 190), panelD = C(24, 44, 120),
}
L.GLOWS = { L.C.glowO, L.C.glowY, L.C.glowC }

-- Style realiste : chaque piece prend un vrai materiau selon sa couleur
-- (bois, pierre, metal, tissu, sable...). Mettre a false pour revenir aux
-- blocs a picots de la map.
L.REALISTE = false

local FAMILIES
local function familyOf(col)
	local best, bestD = nil, 0.16
	for _, f in FAMILIES do
		for _, c in f.cols do
			local d = math.abs(col.R - c.R) + math.abs(col.G - c.G) + math.abs(col.B - c.B)
			if d < bestD then best, bestD = f, d end
		end
	end
	return best
end

local function finish(p, parent, props)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if L.REALISTE then
		local f = familyOf(p.Color)
		p.Material = f and f.mat or Enum.Material.SmoothPlastic
		p.MaterialVariant = ""
		if f and f.refl then p.Reflectance = f.refl end
	else
		p.Material = Enum.Material.Plastic
		p.MaterialVariant = L.MV
	end
	local s = p.Size
	if math.min(s.X, s.Y, s.Z) < 0.8 or s.Magnitude < 3 then p.CanCollide = false; p.CanQuery = false end
	if props then for k, v in pairs(props) do p[k] = v end end
	p.Parent = parent
	return p
end

function L.glow(extra)
	local t = { Material = Enum.Material.Neon, MaterialVariant = "", CastShadow = false }
	if extra then for k, v in pairs(extra) do t[k] = v end end
	return t
end

L.SKY = { CanCollide = false, CanQuery = false, CastShadow = false }

function L.sky(extra)
	local t = table.clone(L.SKY)
	if extra then for k, v in pairs(extra) do t[k] = v end end
	return t
end

function L.part(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
	return finish(p, parent, props)
end

function L.wedge(parent, name, size, cf, color, props)
	local p = Instance.new("WedgePart")
	p.Name = name; p.Size = size; p.CFrame = cf; p.Color = color
	return finish(p, parent, props)
end

function L.cyl(parent, name, len, d, cf, color, props)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Name = name; p.Size = Vector3.new(len, d, d); p.CFrame = cf; p.Color = color
	return finish(p, parent, props)
end

function L.vcyl(parent, name, h, d, cf, color, props)
	return L.cyl(parent, name, h, d, cf * CFrame.Angles(0, 0, math.rad(90)), color, props)
end

function L.ball(parent, name, d, cf, color, props)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Name = name; p.Size = Vector3.new(d, d, d); p.CFrame = cf; p.Color = color
	return finish(p, parent, props)
end

function L.bar(parent, name, a, b, w, color, props, h)
	local len = (b - a).Magnitude
	return L.part(parent, name, Vector3.new(w, h or w, len), CFrame.lookAt((a + b) / 2, b), color, props)
end

function L.model(name, parent, pivot)
	local m = Instance.new("Model")
	m.Name = name
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	if pivot then m.WorldPivot = pivot end
	return m
end

function L.anchor(parent, name, cf, size)
	local p = Instance.new("Part")
	p.Name = name; p.Size = size or Vector3.new(0.4, 0.4, 0.4); p.CFrame = cf
	p.Transparency = 1
	p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Anchored = true
	p.Parent = parent
	return p
end

function L.light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color; l.Range = range; l.Brightness = brightness; l.Shadows = false
	l.Parent = parent
	return l
end

function L.seq(t)
	local k = {}
	for i = 1, #t, 2 do table.insert(k, NumberSequenceKeypoint.new(t[i], t[i + 1])) end
	return NumberSequence.new(k)
end

function L.emitter(parent, props)
	local pe = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do pe[k] = v end
	pe.Parent = parent
	return pe
end

L.TEX = {
	spark = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}

function L.sparkles(parent, color, rate, size)
	return L.emitter(parent, {
		Name = "Etincelles", Texture = L.TEX.spark, LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(color),
		Size = L.seq({ 0, 0, 0.2, size or 0.5, 1, 0 }), Transparency = L.seq({ 0, 0.1, 1, 1 }),
		Lifetime = NumberRange.new(1.5, 3), Rate = rate or 4, Speed = NumberRange.new(0.2, 0.8),
		SpreadAngle = Vector2.new(180, 180), RotSpeed = NumberRange.new(-60, 60),
	})
end

function L.label(part, face, text, color, font)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0
	g.Brightness = 2
	g.Parent = part
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextScaled = true
	t.Font = font or Enum.Font.LuckiestGuy
	t.TextColor3 = color
	t.Parent = g
	local s = Instance.new("UIStroke")
	s.Thickness = 4
	s.Color = L.C.dark
	s.Parent = t
	return g
end

--== Helpers steampunk ==--
local V, CF, ANG, rad, TAU = Vector3.new, CFrame.new, CFrame.Angles, math.rad, math.pi * 2
local SH = { Material = Enum.Material.Metal, MaterialVariant = "", Reflectance = 0.15 }
L.SHINY = SH

-- Engrenage dans le plan XY local de cf (axe = Z local).
function L.gear(parent, cf, d, thick, col, teeth)
	teeth = teeth or math.max(8, math.floor(d * 3))
	col = col or L.C.brass
	local m = L.model("Engrenage", parent, cf)
	L.cyl(m, "Roue", thick, d * 0.82, cf * ANG(0, rad(90), 0), col)
	L.cyl(m, "Jante", thick + 0.05, d * 0.62, cf * ANG(0, rad(90), 0), col:Lerp(L.C.black, 0.25))
	L.cyl(m, "Moyeu", thick + 0.2, d * 0.28, cf * ANG(0, rad(90), 0), col:Lerp(L.C.white, 0.2))
	L.cyl(m, "Axe", thick + 0.4, d * 0.1, cf * ANG(0, rad(90), 0), L.C.ironD)
	for i = 0, teeth - 1 do
		local a = i / teeth * TAU
		L.part(m, "Dent", V(d * 0.13, d * 0.12, thick), cf * CF(math.cos(a) * d * 0.44, math.sin(a) * d * 0.44, 0) * ANG(0, 0, a), col)
	end
	for i = 0, 3 do
		local a = i / 4 * TAU + 0.4
		L.part(m, "Trou", V(d * 0.12, d * 0.12, thick + 0.08), cf * CF(math.cos(a) * d * 0.2, math.sin(a) * d * 0.2, 0), L.C.dark)
	end
	return m
end

-- Manometre : face vers -Z local.
function L.gauge(parent, cf, d, needleAngle)
	L.cyl(parent, "ManoBoitier", 0.35, d, cf * ANG(0, rad(90), 0), L.C.brass, SH)
	L.cyl(parent, "ManoCadran", 0.4, d * 0.8, cf * CF(0, 0, -0.02) * ANG(0, rad(90), 0), L.C.cream)
	for i = 0, 6 do
		local a = rad(-135 + i * 45)
		L.part(parent, "ManoGrad", V(0.05, d * 0.1, 0.05), cf * CF(math.sin(a) * d * 0.32, math.cos(a) * d * 0.32, -0.22) * ANG(0, 0, -a), L.C.dark)
	end
	L.part(parent, "ManoZone", V(d * 0.14, d * 0.07, 0.05), cf * CF(d * 0.23, d * 0.2, -0.22) * ANG(0, 0, rad(-45)), L.C.red)
	local na = rad(needleAngle or 30)
	L.part(parent, "ManoAiguille", V(0.06, d * 0.36, 0.05), cf * CF(math.sin(na) * d * 0.14, math.cos(na) * d * 0.14, -0.25) * ANG(0, 0, -na), L.C.red)
	L.part(parent, "ManoCentre", V(0.12, 0.12, 0.06), cf * CF(0, 0, -0.26), L.C.brassD)
end

-- Tuyau a brides entre a et b.
function L.pipe(parent, a, b, d, col)
	col = col or L.C.copper
	local p = L.bar(parent, "Tuyau", a, b, d, col)
	local dir = (b - a).Unit
	for _, pt in { a + dir * 0.15, b - dir * 0.15 } do
		L.part(parent, "Bride", V(d * 1.5, d * 1.5, 0.2), CFrame.lookAt(pt, pt + dir), L.C.brassD)
	end
	return p
end

-- Vanne a volant : volant dans le plan XY local, face vers -Z.
function L.valve(parent, cf, d, col)
	col = col or L.C.red
	L.part(parent, "VanneTige", V(0.2, 0.2, 0.6), cf * CF(0, 0, 0.3), L.C.steel)
	local n = 10
	for i = 0, n - 1 do
		local a = i / n * TAU
		L.part(parent, "VanneJante", V(d * 0.33, 0.16, 0.16), cf * CF(math.cos(a) * d / 2, math.sin(a) * d / 2, 0) * ANG(0, 0, a + math.pi / 2), col)
	end
	for i = 0, 2 do
		local a = i / 3 * TAU
		L.part(parent, "VanneRayon", V(d / 2, 0.12, 0.12), cf * CF(math.cos(a) * d / 4, math.sin(a) * d / 4, 0) * ANG(0, 0, a), col)
	end
	L.part(parent, "VanneMoyeu", V(0.3, 0.3, 0.25), cf, L.C.brass)
end

-- Rangee de rivets sur une ligne.
function L.rivets(parent, a, b, n, d, col)
	for i = 0, n - 1 do
		local p = a:Lerp(b, n == 1 and 0.5 or i / (n - 1))
		L.part(parent, "Rivet", V(d, d, d), CF(p), col or L.C.brassL, { CanCollide = false, CanQuery = false, CastShadow = false })
	end
end

-- Vapeur (particules).
function L.steam(parent, cf, size, rate)
	local a = L.anchor(parent, "Vapeur", cf)
	L.emitter(a, {
		Name = "Vapeur", Texture = L.TEX.smoke, LightInfluence = 0.6,
		Color = ColorSequence.new(L.C.white), Size = L.seq({ 0, size * 0.4, 1, size * 1.6 }), Transparency = L.seq({ 0, 0.4, 1, 1 }),
		Lifetime = NumberRange.new(1.5, 2.5), Rate = rate or 6, Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(12, 12),
		Acceleration = V(0, 1.5, 0), RotSpeed = NumberRange.new(-30, 30),
	})
	return a
end

return L
