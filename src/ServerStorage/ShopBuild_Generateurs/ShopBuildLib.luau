local L = {}

L.MV = "Studs"
local C3 = Color3.fromRGB
L.C = {
	gold = C3(255, 200, 40), goldL = C3(255, 228, 110), goldD = C3(214, 144, 16), goldDD = C3(160, 98, 8),
	black = C3(22, 20, 26), dark = C3(40, 36, 46), white = C3(248, 246, 240), cream = C3(255, 248, 225),
	red = C3(235, 40, 50), redD = C3(150, 20, 30), blue = C3(40, 140, 255), blueD = C3(20, 80, 200),
	green = C3(70, 220, 70), pink = C3(255, 90, 160), pinkL = C3(255, 170, 205), pinkD = C3(200, 30, 100),
	straw = C3(235, 30, 60), leaf = C3(70, 200, 60), wood = C3(150, 96, 50), woodD = C3(105, 64, 32),
	orange = C3(255, 120, 40), yellow = C3(255, 240, 60), grass = C3(60, 150, 50),
}

local function finish(p: BasePart, parent: Instance, props)
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	p.Material = Enum.Material.Plastic
	p.MaterialVariant = L.MV
	local s = p.Size
	if math.min(s.X, s.Y, s.Z) < 0.6 then
		p.CanCollide = false
		p.CanQuery = false
	end
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

-- Neon sans picots, sans ombre.
function L.glow(extra)
	local t = { Material = Enum.Material.Neon, MaterialVariant = "", CastShadow = false, CanCollide = false, CanQuery = false }
	if extra then
		for k, v in pairs(extra) do
			t[k] = v
		end
	end
	return t
end

function L.smooth(extra)
	local t = { Material = Enum.Material.SmoothPlastic, MaterialVariant = "" }
	if extra then
		for k, v in pairs(extra) do
			t[k] = v
		end
	end
	return t
end

function L.part(parent, name, size, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	return finish(p, parent, props)
end

function L.wedge(parent, name, size, cf, color, props)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	return finish(p, parent, props)
end

-- Cylindre dont l'axe est Y (hauteur h, diametre d).
function L.cyl(parent, name, h, d, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(h, d, d)
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	p.Color = color
	return finish(p, parent, props)
end

function L.ball(parent, name, d, cf, color, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(d, d, d)
	p.CFrame = cf
	p.Color = color
	return finish(p, parent, props)
end

function L.model(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- SurfaceGui sur une face ; pixels par stud eleves pour un texte net.
function L.surface(part: BasePart, face: Enum.NormalId, name: string?, ppu: number?)
	local sg = Instance.new("SurfaceGui")
	sg.Name = name or "SurfaceGui"
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = ppu or 60
	sg.LightInfluence = 0
	sg.Brightness = 1.4
	sg.MaxDistance = 250
	sg.Parent = part
	return sg
end

L.FONT_TITLE = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
L.FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)

function L.label(parent: Instance, text: string, color: Color3, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.FontFace = L.FONT_TITLE
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color
	l.RichText = true
	if props then
		for k, v in pairs(props) do
			l[k] = v
		end
	end
	l.Parent = parent
	local s = Instance.new("UIStroke")
	s.Thickness = 4
	s.Color = Color3.new(0, 0, 0)
	s.Parent = l
	return l
end

function L.sparkles(parent: Instance, color: Color3, rate: number, props)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Sparkles"
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(1, 2)
	pe.Speed = NumberRange.new(1, 3)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-90, 90)
	if props then
		for k, v in pairs(props) do
			pe[k] = v
		end
	end
	pe.Parent = parent
	return pe
end

function L.count(root: Instance): number
	local n = 0
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

return L
