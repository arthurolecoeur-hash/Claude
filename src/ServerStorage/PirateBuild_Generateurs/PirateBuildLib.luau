local L = {}
L.MV = "Studs"
local C = Color3.fromRGB
L.C = {
	rock = C(92, 88, 110), rockD = C(62, 58, 78), rockL = C(132, 128, 150), rockB = C(110, 86, 70), rockBD = C(76, 58, 48),
	moon = C(196, 196, 206), moonD = C(150, 150, 164),
	metal = C(190, 196, 210), metalD = C(110, 116, 132), metalL = C(228, 232, 240), dark = C(28, 26, 40), black = C(8, 6, 14),
	gold = C(255, 196, 60), goldD = C(206, 142, 30), white = C(248, 248, 255), red = C(236, 60, 76), orange = C(255, 140, 40),
	panel = C(40, 80, 190), panelD = C(24, 44, 120),
	cyan = C(70, 236, 255), blue = C(70, 120, 255), purple = C(170, 90, 255), pink = C(255, 90, 210), magenta = C(230, 60, 255),
	green = C(110, 255, 150), alienGrey = C(170, 190, 180), lime = C(190, 255, 80), yellow = C(255, 230, 90), teal = C(40, 200, 190),
	wood = C(146, 96, 54), woodD = C(100, 64, 34), woodL = C(190, 136, 80), plank = C(170, 116, 66),
	sail = C(240, 230, 204), sailD = C(206, 192, 160), rope = C(206, 176, 120), iron = C(70, 70, 78), ironD = C(40, 40, 46),
	skin = C(246, 200, 156), skinD = C(210, 160, 120), beard = C(80, 50, 30), navy = C(40, 56, 110), coat = C(150, 30, 40),
	shirtW = C(240, 240, 236), bandana = C(210, 40, 50), sand = C(236, 210, 150), water = C(40, 150, 210), kraken = C(140, 60, 170),
	parrotR = C(230, 40, 50), parrotB = C(40, 110, 230), parrotY = C(255, 210, 40), paper = C(236, 220, 176),
	emerald = C(40, 220, 120), ruby = C(230, 30, 70), sapphire = C(50, 110, 255),
	stem = C(70, 50, 110), stemL = C(110, 80, 160), soil = C(54, 44, 74), soilL = C(78, 64, 104),
}
L.GLOWS = { L.C.gold, L.C.orange, L.C.yellow }

local function finish(p, parent, props)
	p.Anchored = true
	p.Material = Enum.Material.Plastic
	p.MaterialVariant = L.MV
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
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

return L
