--[[
	WeatherFX
	---------
	ModuleScript client (StarterPlayerScripts.Weather).
	Ambiance + sons de chaque meteo, 100% locale (rien ne se replique) :
	  Lava    : ciel rouge, meteorites (zone d'impact au sol, trainee de feu),
	            explosions + cratere + debris, braises, cendres
	  Galaxy  : skybox galaxie (ReplicatedStorage.WeatherAssets.GalaxySky),
	            planetes, nebuleuses, etoiles filantes, poussiere d'etoiles
	  Hacker  : BillboardGui de hacking, pluie Matrix, terminal, scans radar,
	            cubes de donnees, glitchs
	  Rainbow : arc-en-ciel geant qui scintille, bulles, ondes arc-en-ciel,
	            trainee arc-en-ciel sur le joueur, paillettes
	  Admin   : intro plein ecran (flash, titre, glitch), portail geant
	            rouge et or dans le ciel, lasers orbitaux, marteau du ban
	            qui s'ecrase, eclairs, couronnes, pluie d'etincelles dorees
	Tout est restaure a la fin. Sons : table SFX ci-dessous.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local assets = ReplicatedStorage:WaitForChild("WeatherAssets")

local FX = {}

local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_FIRE = "rbxasset://textures/particles/fire_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local SFX = {
	LavaStart = { id = "rbxassetid://9114428742", vol = 0.9 },
	LavaAmbient = { id = "rbxassetid://116275103627699", vol = 0.3, loop = true },
	MeteorWhoosh = { id = "rbxassetid://118217695193917", vol = 1 },
	MeteorImpact = { id = "rbxassetid://89620476747699", vol = 1.2 },
	GalaxyAmbient = { id = "rbxassetid://124292389178542", vol = 0.55, loop = true },
	Twinkle = { id = "rbxassetid://106443875576213", vol = 0.35 },
	HackBeep = { id = "rbxassetid://9120149295", vol = 0.18 },
	HackGlitch = { id = "rbxassetid://9120159078", vol = 0.5 },
	HackScan = { id = "rbxassetid://9120150771", vol = 0.45 },
	Chime = { id = "rbxassetid://4612374393", vol = 0.45 },
	Chime2 = { id = "rbxassetid://4612374495", vol = 0.45 },
	AdminStart = { id = "rbxassetid://9114630450", vol = 1 },
	AdminZap = { id = "rbxassetid://98753363372264", vol = 0.9 },
	AdminBoom = { id = "rbxassetid://89620476747699", vol = 0.8 },
	AdminAmbient = { id = "rbxassetid://116275103627699", vol = 0.22, loop = true },
}

local RAINBOW_COLORS = {
	Color3.fromRGB(255, 40, 40),
	Color3.fromRGB(255, 150, 0),
	Color3.fromRGB(255, 235, 0),
	Color3.fromRGB(40, 220, 70),
	Color3.fromRGB(0, 160, 255),
	Color3.fromRGB(80, 60, 255),
	Color3.fromRGB(190, 60, 255),
}
local RAINBOW_SEQ = (function()
	local kps = {}
	for i, c in ipairs(RAINBOW_COLORS) do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#RAINBOW_COLORS - 1), c))
	end
	return ColorSequence.new(kps)
end)()

local HACK_LINES = {
	"ACCESS GRANTED", "HACKING...", "SYSTEM BREACH", "FIREWALL DOWN", "> brainrot.exe",
	"sudo steal --all", "PASSWORD: ********", "ERROR 404", "INJECTING...", "[#####---] 62%",
	"0xDEADBEEF", "ROOT ACCESS", "DOWNLOADING RAM...", "> ping brainrot.gg", "DECRYPTING...",
	"TRACE: 127.0.0.1", "OVERRIDE ACCEPTED", "[########] 100%", "BYPASSING...", "> hack --mutation",
}
local TERMINAL_LINES = {
	"> connecting to brainrot mainframe...", "> bypassing firewall [OK]", "> injecting HACKER mutation",
	"> scanning bases...", "> 3 targets found", "> decrypting brainrot.db", "> uploading virus.lua",
	"> mutation chance x10 [ACTIVE]", "> erasing logs...", "> access level: ROOT", "> spoofing ip 127.0.0.1",
	"> compiling exploit.exe", "> tracing admin...", "> WARNING: intrusion detected", "> ignoring warning lol",
}

local state = nil
local shake = 0

local function kp(t, v)
	return NumberSequenceKeypoint.new(t, v)
end

local function focus(): Vector3
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		return root.Position
	end
	local cam = workspace.CurrentCamera
	return cam and cam.Focus.Position or Vector3.zero
end

local function rand(a: number, b: number): number
	return a + math.random() * (b - a)
end

local function newPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function emitter(parent, props)
	local pe = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		pe[k] = v
	end
	pe.Parent = parent
	return pe
end

local function addTrail(part: BasePart, width: number, lifetime: number, color: ColorSequence)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(width / 2, 0, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(-width / 2, 0, 0)
	a1.Parent = part
	local tr = Instance.new("Trail")
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = lifetime
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.Color = color
	tr.Transparency = NumberSequence.new(0, 1)
	tr.WidthScale = NumberSequence.new(1, 0)
	tr.Parent = part
	return tr
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(x: number, z: number, fromY: number): Vector3?
	local exclude = {}
	if state then
		table.insert(exclude, state.folder)
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
	local origin = Vector3.new(x, fromY, z)
	for _ = 1, 6 do
		local hit = workspace:Raycast(origin, Vector3.new(0, -1500, 0), rayParams)
		if not hit then
			return nil
		end
		local inst = hit.Instance
		if inst:IsA("Terrain") or (inst.CanCollide and inst.Transparency < 0.95) then
			return hit.Position
		end
		table.insert(exclude, inst)
		rayParams.FilterDescendantsInstances = exclude
	end
	return nil
end

--== Sons ==--

local function playSound(name: string, parent: Instance?, speed: number?): Sound?
	local d = SFX[name]
	if not d then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = d.id
	s.Volume = d.vol
	s.Looped = d.loop == true
	s.PlaybackSpeed = speed or 1
	if parent then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 20
		s.RollOffMaxDistance = 300
	end
	s.Parent = parent or SoundService
	s:Play()
	if not s.Looped then
		Debris:AddItem(s, 8)
	end
	return s
end

local function soundAt(name: string, pos: Vector3, speed: number?)
	local holder = newPart({ Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(pos), Parent = state.folder })
	playSound(name, holder, speed)
	Debris:AddItem(holder, 8)
end

--== Etat / restauration ==--

local function getCC()
	local cc = Lighting:FindFirstChild("WeatherFXCC")
	if not cc then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "WeatherFXCC"
		cc.Parent = Lighting
	end
	return cc
end

local function getBloom()
	local b = Lighting:FindFirstChild("WeatherFXBloom")
	if not b then
		b = Instance.new("BloomEffect")
		b.Name = "WeatherFXBloom"
		b.Intensity = 0
		b.Size = 24
		b.Threshold = 2
		b.Parent = Lighting
	end
	return b
end

local function getClouds()
	return workspace.Terrain:FindFirstChildOfClass("Clouds")
end

local function setProp(inst, goals, t)
	if not inst or not state then
		return
	end
	local saved = state.saved[inst]
	if not saved then
		saved = {}
		state.saved[inst] = saved
	end
	local tw = {}
	for prop, val in pairs(goals) do
		if saved[prop] == nil then
			saved[prop] = inst[prop]
		end
		local ty = typeof(val)
		if t and (ty == "number" or ty == "Color3") then
			tw[prop] = val
		else
			inst[prop] = val
		end
	end
	if next(tw) then
		local tween = TweenService:Create(inst, TweenInfo.new(t, Enum.EasingStyle.Sine), tw)
		table.insert(state.tweens, tween)
		tween:Play()
	end
end

local function onCleanup(fn)
	table.insert(state.cleanups, fn)
end

local function loop(interval, fn)
	local my = state
	task.spawn(function()
		while state == my do
			local ok, err = pcall(fn)
			if not ok then
				warn("WeatherFX: " .. tostring(err))
			end
			task.wait(type(interval) == "function" and interval() or interval)
		end
	end)
end

local function step(fn)
	local c = RunService.RenderStepped:Connect(fn)
	onCleanup(function()
		c:Disconnect()
	end)
end

local function ambient(name: string)
	local s = playSound(name)
	if not s then
		return
	end
	local target = s.Volume
	s.Volume = 0
	TweenService:Create(s, TweenInfo.new(2.5), { Volume = target }):Play()
	onCleanup(function()
		TweenService:Create(s, TweenInfo.new(1.8), { Volume = 0 }):Play()
		Debris:AddItem(s, 2)
	end)
end

local function followEmitter(size: Vector3, offset: Vector3, props)
	local p = newPart({ Size = size, Transparency = 1, CFrame = CFrame.new(focus() + offset), Parent = state.folder })
	props.Shape = Enum.ParticleEmitterShape.Box
	props.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	local pe = emitter(p, props)
	step(function()
		p.CFrame = CFrame.new(focus() + offset)
	end)
	return pe
end

local function swapSky(template: Sky)
	local olds = {}
	for _, s in ipairs(Lighting:GetChildren()) do
		if s:IsA("Sky") then
			table.insert(olds, s)
			s.Parent = nil
		end
	end
	local sky = template:Clone()
	sky.Parent = Lighting
	onCleanup(function()
		sky:Destroy()
		for _, s in ipairs(olds) do
			s.Parent = Lighting
		end
	end)
end

local function screenGui(name: string, order: number)
	local sg = Instance.new("ScreenGui")
	sg.Name = name
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.DisplayOrder = order
	sg.Parent = player:WaitForChild("PlayerGui")
	onCleanup(function()
		sg:Destroy()
	end)
	return sg
end

-- Onde qui s'etend au sol autour d'un point.
local function groundRing(pos: Vector3, color: Color3, maxSize: number, t: number, thickness: number?)
	local ring = newPart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(thickness or 0.4, 2, 2), Material = Enum.Material.Neon,
		Color = color, Transparency = 0.15, CFrame = CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = state.folder,
	})
	TweenService:Create(ring, TweenInfo.new(t, Enum.EasingStyle.Quart), {
		Size = Vector3.new(thickness or 0.4, maxSize, maxSize), Transparency = 1,
	}):Play()
	Debris:AddItem(ring, t + 0.1)
	return ring
end

RunService:BindToRenderStep("WeatherShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shake > 0 then
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * CFrame.Angles((math.random() - 0.5) * shake * 0.02, (math.random() - 0.5) * shake * 0.02, 0)
			* CFrame.new((math.random() - 0.5) * shake, (math.random() - 0.5) * shake, 0)
		shake = math.max(0, shake - dt * 3.5)
	end
end)

--== Lava ==--

local WIND = Vector3.new(0.55, 1, 0.35).Unit

local function debrisRock(pos: Vector3, size: number)
	local a = math.random() * math.pi * 2
	local dist = rand(size * 1.5, size * 4)
	local land = pos + Vector3.new(math.cos(a) * dist, 0, math.sin(a) * dist)
	local peak = pos:Lerp(land, 0.5) + Vector3.new(0, rand(size * 1.2, size * 2.5), 0)
	local s = rand(0.6, 1.4) * size * 0.22
	local rock = newPart({
		Size = Vector3.new(s, s, s), Material = Enum.Material.CrackedLava, Color = Color3.fromRGB(255, 90, 20),
		CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Parent = state.folder,
	})
	local up = TweenService:Create(rock, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.new(peak) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
	})
	up.Completed:Connect(function()
		local down = TweenService:Create(rock, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(land + Vector3.new(0, s / 2, 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
		})
		down.Completed:Connect(function()
			TweenService:Create(rock, TweenInfo.new(2.5), { Transparency = 1, Color = Color3.fromRGB(40, 30, 28) }):Play()
			Debris:AddItem(rock, 2.6)
		end)
		down:Play()
	end)
	up:Play()
end

local function impact(pos: Vector3, size: number)
	local folder = state.folder
	local flash = newPart({
		Shape = Enum.PartType.Ball, Size = Vector3.one * size, Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 200, 80), CFrame = CFrame.new(pos), Parent = folder,
	})
	TweenService:Create(flash, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = Vector3.one * size * 4.5, Transparency = 1, Color = Color3.fromRGB(255, 60, 0) }):Play()
	Debris:AddItem(flash, 0.6)
	groundRing(pos, Color3.fromRGB(255, 120, 20), size * 9, 0.7, 0.35)
	groundRing(pos, Color3.fromRGB(255, 220, 120), size * 5, 0.45, 0.25)

	local crater = newPart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, size * 2.6, size * 2.6), Material = Enum.Material.CrackedLava,
		Color = Color3.fromRGB(255, 80, 10), CFrame = CFrame.new(pos + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Parent = folder,
	})
	TweenService:Create(crater, TweenInfo.new(4, Enum.EasingStyle.Sine), { Color = Color3.fromRGB(35, 25, 22) }):Play()
	task.delay(4, function()
		if crater.Parent then
			TweenService:Create(crater, TweenInfo.new(1.5), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(crater, 6)

	local holder = newPart({ Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(pos), Parent = folder })
	emitter(holder, {
		Texture = TEX_FIRE, Rate = 0, Speed = NumberRange.new(25, 55), SpreadAngle = Vector2.new(75, 75),
		EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(0.5, 1.1), Acceleration = Vector3.new(0, -70, 0),
		Size = NumberSequence.new(size * 0.45, 0), LightEmission = 1, Drag = 2,
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 80), Color3.fromRGB(255, 40, 0)),
	}):Emit(40)
	emitter(holder, {
		Texture = TEX_SMOKE, Rate = 0, Speed = NumberRange.new(5, 12), SpreadAngle = Vector2.new(65, 65),
		EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(1.8, 3), Drag = 1.5,
		Size = NumberSequence.new({ kp(0, size * 0.9), kp(1, size * 3) }),
		Transparency = NumberSequence.new({ kp(0, 0.25), kp(1, 1) }),
		RotSpeed = NumberRange.new(-40, 40), Rotation = NumberRange.new(0, 360),
		Color = ColorSequence.new(Color3.fromRGB(70, 45, 40), Color3.fromRGB(30, 25, 25)),
	}):Emit(14)
	local lingering = emitter(holder, {
		Texture = TEX_FIRE, Rate = 18, Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(25, 25),
		EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(0.5, 0.9), LightEmission = 1,
		Size = NumberSequence.new({ kp(0, size * 0.5), kp(1, 0) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 180, 60), Color3.fromRGB(255, 50, 0)),
	})
	task.delay(2.5, function()
		lingering.Enabled = false
	end)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 30)
	light.Range = size * 7
	light.Brightness = 6
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(2.5), { Brightness = 0 }):Play()
	Debris:AddItem(holder, 4)

	for _ = 1, math.random(4, 7) do
		debrisRock(pos, size)
	end
	soundAt("MeteorImpact", pos, rand(0.85, 1.1))

	local cam = workspace.CurrentCamera
	local d = cam and (cam.CFrame.Position - pos).Magnitude or 999
	if d < 90 then
		shake = math.max(shake, (1 - d / 90) * 1.6)
	end
end

local function meteor()
	local f = focus()
	local a = math.random() * math.pi * 2
	local r = rand(15, 180)
	local x, z = f.X + math.cos(a) * r, f.Z + math.sin(a) * r
	local hit = groundAt(x, z, f.Y + 400) or Vector3.new(x, f.Y - 3, z)
	local size = rand(3, 9)
	local startPos = hit + WIND * rand(260, 340)
	local rot = CFrame.lookAt(startPos, hit).Rotation
	local dur = rand(1.4, 2.2)

	local marker = newPart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 0.5, 0.5), Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 40, 20), Transparency = 0.7,
		CFrame = CFrame.new(hit + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), Parent = state.folder,
	})
	TweenService:Create(marker, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = Vector3.new(0.2, size * 3, size * 3), Transparency = 0.35,
	}):Play()

	local ball = newPart({
		Shape = Enum.PartType.Ball, Size = Vector3.one * size, Material = Enum.Material.CrackedLava,
		Color = Color3.fromRGB(255, 100, 20), CFrame = CFrame.new(startPos) * rot, Parent = state.folder,
	})
	local glow = newPart({
		Shape = Enum.PartType.Ball, Size = Vector3.one * size * 1.35, Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 140, 30), Transparency = 0.55, CFrame = ball.CFrame, Parent = state.folder,
	})
	emitter(ball, {
		Texture = TEX_FIRE, Rate = 80, Speed = NumberRange.new(0, 2), Lifetime = NumberRange.new(0.35, 0.7),
		Size = NumberSequence.new({ kp(0, size * 1.1), kp(1, 0) }), LightEmission = 1, LockedToPart = false,
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 120), Color3.fromRGB(255, 50, 0)),
		RotSpeed = NumberRange.new(-120, 120), Rotation = NumberRange.new(0, 360),
	})
	emitter(ball, {
		Texture = TEX_SMOKE, Rate = 25, Speed = NumberRange.new(0, 1), Lifetime = NumberRange.new(1, 1.8),
		Size = NumberSequence.new({ kp(0, size * 0.8), kp(1, size * 2) }),
		Transparency = NumberSequence.new({ kp(0, 0.4), kp(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(60, 40, 35)),
	})
	addTrail(ball, size * 0.9, 0.6, ColorSequence.new(Color3.fromRGB(255, 230, 130), Color3.fromRGB(255, 40, 0)))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 30)
	light.Range = size * 6
	light.Brightness = 4
	light.Parent = ball
	if math.random() < 0.6 then
		playSound("MeteorWhoosh", ball, rand(0.8, 1.15))
	end

	local my = state
	local goal = CFrame.new(hit) * rot
	local info = TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(glow, info, { CFrame = goal }):Play()
	local tw = TweenService:Create(ball, info, { CFrame = goal })
	tw.Completed:Connect(function()
		ball:Destroy()
		glow:Destroy()
		marker:Destroy()
		if state == my then
			impact(hit, size)
		end
	end)
	tw:Play()
end

--== Galaxy ==--

local function shootingStar()
	local f = focus()
	local a = math.random() * math.pi * 2
	local start = f + Vector3.new(math.cos(a) * 250, rand(150, 270), math.sin(a) * 250)
	local dir = Vector3.new(-math.cos(a) + (math.random() - 0.5), -0.35, -math.sin(a) + (math.random() - 0.5)).Unit
	local finish = start + dir * rand(250, 400)
	local rot = CFrame.lookAt(start, finish).Rotation
	local colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 110, 255), Color3.fromRGB(110, 200, 255), Color3.fromRGB(255, 140, 230) }
	local col = colors[math.random(#colors)]
	local star = newPart({
		Shape = Enum.PartType.Ball, Size = Vector3.one * rand(1.2, 2.2), Material = Enum.Material.Neon,
		Color = Color3.new(1, 1, 1), CFrame = CFrame.new(start) * rot, Parent = state.folder,
	})
	addTrail(star, 1.6, 0.8, ColorSequence.new(Color3.new(1, 1, 1), col))
	emitter(star, {
		Texture = TEX_SPARK, Rate = 40, Speed = NumberRange.new(0, 2), Lifetime = NumberRange.new(0.5, 1),
		Size = NumberSequence.new({ kp(0, 1.2), kp(1, 0) }), LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(col),
	})
	if math.random() < 0.5 then
		playSound("Twinkle", nil, rand(0.9, 1.3))
	end
	local tw = TweenService:Create(star, TweenInfo.new(rand(0.9, 1.4), Enum.EasingStyle.Linear), { CFrame = CFrame.new(finish) * rot })
	tw.Completed:Connect(function()
		star.Transparency = 1
		local pe = star:FindFirstChildOfClass("ParticleEmitter")
		if pe then
			pe.Enabled = false
		end
		Debris:AddItem(star, 1.2)
	end)
	tw:Play()
end

local function planets()
	local f = focus()
	local defs = {
		{ dir = Vector3.new(1, 0.55, 0.3), dist = 700, size = 120, color = Color3.fromRGB(170, 90, 255), ring = Color3.fromRGB(255, 180, 255) },
		{ dir = Vector3.new(-0.8, 0.8, 0.6), dist = 800, size = 70, color = Color3.fromRGB(70, 170, 255), ring = nil },
		{ dir = Vector3.new(-0.2, 0.45, -1), dist = 750, size = 95, color = Color3.fromRGB(255, 110, 190), ring = Color3.fromRGB(150, 220, 255) },
	}
	local list = {}
	for i, d in ipairs(defs) do
		local pos = f + d.dir.Unit * d.dist
		local planet = newPart({
			Shape = Enum.PartType.Ball, Size = Vector3.one * d.size, Material = Enum.Material.Neon,
			Color = d.color, Transparency = 1, CFrame = CFrame.new(pos), Parent = state.folder,
		})
		TweenService:Create(planet, TweenInfo.new(4), { Transparency = 0.15 }):Play()
		local atmo = newPart({
			Shape = Enum.PartType.Ball, Size = Vector3.one * d.size * 1.18, Material = Enum.Material.Neon,
			Color = d.color:Lerp(Color3.new(1, 1, 1), 0.4), Transparency = 1, CFrame = CFrame.new(pos), Parent = state.folder,
		})
		TweenService:Create(atmo, TweenInfo.new(4), { Transparency = 0.8 }):Play()
		local ring
		if d.ring then
			ring = newPart({
				Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, d.size * 2.1, d.size * 2.1), Material = Enum.Material.Neon,
				Color = d.ring, Transparency = 1, CFrame = CFrame.new(pos) * CFrame.Angles(math.rad(70), 0, math.rad(20)),
				Parent = state.folder,
			})
			TweenService:Create(ring, TweenInfo.new(4), { Transparency = 0.55 }):Play()
		end
		table.insert(list, { planet = planet, atmo = atmo, ring = ring, base = pos, phase = i * 2 })
	end
	local t0 = os.clock()
	step(function()
		local t = os.clock() - t0
		for _, p in ipairs(list) do
			local off = Vector3.new(0, math.sin(t * 0.3 + p.phase) * 8, 0)
			p.planet.CFrame = CFrame.new(p.base + off) * CFrame.Angles(0, t * 0.1, 0)
			p.atmo.CFrame = CFrame.new(p.base + off)
			if p.ring then
				p.ring.CFrame = CFrame.new(p.base + off) * CFrame.Angles(0, t * 0.05, 0) * CFrame.Angles(math.rad(70), 0, math.rad(20))
			end
		end
	end)
end

--== Hacker ==--

local function randomBinary(n: number): string
	local t = {}
	for i = 1, n do
		t[i] = math.random() < 0.5 and "0" or "1"
		if i % 8 == 0 and i < n then
			t[i] ..= " "
		end
	end
	return table.concat(t)
end

local function hackBillboard()
	if state.billboards >= 45 then
		return
	end
	local f = focus()
	local a = math.random() * math.pi * 2
	local r = rand(12, 80)
	local pos = f + Vector3.new(math.cos(a) * r, rand(2, 28), math.sin(a) * r)
	local line = math.random() < 0.25 and randomBinary(16) or HACK_LINES[math.random(#HACK_LINES)]
	local danger = line:find("ERROR") or line:find("BREACH") or line:find("DOWN")
	local col = danger and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(0, 255, 90)

	local anchor = newPart({ Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(pos), Parent = state.folder })
	local bb = Instance.new("BillboardGui")
	local w = math.clamp(#line * 0.85, 6, 18)
	bb.Size = UDim2.new(w, 0, 2.8, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 260
	bb.Adornee = anchor
	bb.Parent = anchor
	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = bb
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = holder
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0.15, 0)
	local st = Instance.new("UIStroke")
	st.Color = col
	st.Thickness = 2
	st.Parent = frame
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0.18, 0)
	header.BackgroundColor3 = col
	header.BorderSizePixel = 0
	header.Parent = frame
	Instance.new("UICorner", header).CornerRadius = UDim.new(0.5, 0)
	local label = Instance.new("TextLabel")
	label.Position = UDim2.new(0.05, 0, 0.26, 0)
	label.Size = UDim2.new(0.9, 0, 0.64, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextScaled = true
	label.TextColor3 = col
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = ""
	label.Parent = frame

	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	state.billboards += 1
	if math.random() < 0.35 then
		soundAt("HackBeep", pos, rand(0.8, 1.6))
	end

	local my = state
	task.spawn(function()
		for i = 1, #line do
			if not anchor.Parent then
				break
			end
			label.Text = line:sub(1, i) .. "_"
			if math.random() < 0.08 then
				bb.StudsOffset = Vector3.new(rand(-0.4, 0.4), rand(-0.2, 0.2), 0)
			end
			task.wait(0.03)
		end
		bb.StudsOffset = Vector3.zero
		label.Text = line
		local t0 = os.clock()
		local life = rand(1.4, 2.8)
		while anchor.Parent and os.clock() - t0 < life do
			label.Text = (math.floor((os.clock() - t0) * 3) % 2 == 0) and line or (line .. "_")
			if math.random() < 0.05 then
				label.TextColor3 = Color3.new(1, 1, 1)
				bb.StudsOffset = Vector3.new(rand(-0.5, 0.5), 0, 0)
				task.wait(0.05)
				label.TextColor3 = col
				bb.StudsOffset = Vector3.zero
			end
			task.wait(0.1)
		end
		for _ = 1, 4 do
			frame.Visible = not frame.Visible
			task.wait(0.05)
		end
		TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 0 }):Play()
		task.wait(0.16)
		anchor:Destroy()
		if state == my then
			my.billboards -= 1
		end
	end)
end

local function dataCube()
	local f = focus()
	local a = math.random() * math.pi * 2
	local r = rand(6, 45)
	local pos = f + Vector3.new(math.cos(a) * r, rand(-3, 0), math.sin(a) * r)
	local s = rand(0.5, 1.4)
	local cube = newPart({
		Size = Vector3.one * s, Material = Enum.Material.Neon, Color = Color3.fromRGB(0, 255, 110),
		Transparency = 0.2, CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 6, math.random() * 6, 0), Parent = state.folder,
	})
	local box = Instance.new("SelectionBox")
	box.Adornee = cube
	box.Color3 = Color3.fromRGB(180, 255, 200)
	box.LineThickness = 0.04
	box.SurfaceTransparency = 1
	box.Parent = cube
	local t = rand(2, 3.5)
	TweenService:Create(cube, TweenInfo.new(t, Enum.EasingStyle.Sine), {
		CFrame = CFrame.new(pos + Vector3.new(0, rand(12, 22), 0)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
		Transparency = 1,
	}):Play()
	TweenService:Create(box, TweenInfo.new(t), { Transparency = 1 }):Play()
	Debris:AddItem(cube, t + 0.1)
end

local function scanPulse()
	local f = focus()
	local ground = groundAt(f.X, f.Z, f.Y + 5) or (f - Vector3.new(0, 3, 0))
	groundRing(ground, Color3.fromRGB(0, 255, 110), 240, 2.2, 0.5)
	groundRing(ground, Color3.fromRGB(180, 255, 200), 160, 1.6, 0.3)
	playSound("HackScan", nil, rand(0.9, 1.1))
end

local function randomColumn(): string
	local chars = "01ABCDEF#$%&?"
	local t = {}
	for i = 1, math.random(12, 26) do
		local k = math.random(#chars)
		t[i] = chars:sub(k, k)
	end
	return table.concat(t, "\n")
end

local function matrixRain(sg)
	local cols = {}
	local N = 30
	for i = 1, N do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Code
		l.TextSize = 18
		l.TextColor3 = Color3.fromRGB(0, 255, 90)
		l.TextTransparency = 0.7
		l.TextYAlignment = Enum.TextYAlignment.Bottom
		l.AnchorPoint = Vector2.new(0.5, 1)
		l.Size = UDim2.new(0, 20, 0.7, 0)
		l.Text = randomColumn()
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new(1, 0)
		g.Parent = l
		l.Parent = sg
		cols[i] = { label = l, x = (i - 0.5) / N, y = math.random() * 1.7, speed = rand(0.15, 0.45) }
	end
	local acc = 0
	step(function(dt)
		acc += dt
		local swap = acc > 0.12
		if swap then
			acc = 0
		end
		for _, c in ipairs(cols) do
			c.y += c.speed * dt
			if c.y > 1.7 then
				c.y = 0
				c.label.Text = randomColumn()
			elseif swap and math.random() < 0.2 then
				c.label.Text = randomColumn()
			end
			c.label.Position = UDim2.new(c.x, 0, c.y, 0)
		end
	end)
end

local function terminal(sg)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 16, 1, -120)
	panel.Size = UDim2.fromOffset(330, 150)
	panel.BackgroundColor3 = Color3.new(0, 0, 0)
	panel.BackgroundTransparency = 0.25
	panel.BorderSizePixel = 0
	panel.Parent = sg
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromRGB(0, 255, 90)
	st.Thickness = 2
	st.Parent = panel
	local head = Instance.new("TextLabel")
	head.Size = UDim2.new(1, 0, 0, 22)
	head.BackgroundColor3 = Color3.fromRGB(0, 255, 90)
	head.BorderSizePixel = 0
	head.Font = Enum.Font.Code
	head.TextSize = 14
	head.TextColor3 = Color3.new(0, 0, 0)
	head.Text = " root@brainrot:~# HACKER WEATHER"
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.Parent = panel
	Instance.new("UICorner", head).CornerRadius = UDim.new(0, 10)
	local body = Instance.new("TextLabel")
	body.Position = UDim2.fromOffset(10, 28)
	body.Size = UDim2.new(1, -20, 1, -34)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Code
	body.TextSize = 13
	body.TextColor3 = Color3.fromRGB(0, 255, 90)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Bottom
	body.TextWrapped = true
	body.Text = ""
	body.Parent = panel
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = panel
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	local lines = {}
	local my = state
	task.spawn(function()
		while state == my do
			local line = TERMINAL_LINES[math.random(#TERMINAL_LINES)]
			table.insert(lines, "")
			if #lines > 8 then
				table.remove(lines, 1)
			end
			for i = 1, #line do
				if state ~= my then
					return
				end
				lines[#lines] = line:sub(1, i)
				body.Text = table.concat(lines, "\n") .. "_"
				task.wait(0.018)
			end
			task.wait(rand(0.3, 0.9))
		end
	end)
end

local function glitch(sg)
	local bars = {}
	for _ = 1, math.random(4, 8) do
		local b = Instance.new("Frame")
		b.BorderSizePixel = 0
		local roll = math.random()
		b.BackgroundColor3 = roll < 0.6 and Color3.fromRGB(0, 255, 90) or (roll < 0.8 and Color3.fromRGB(255, 0, 90) or Color3.new(1, 1, 1))
		b.BackgroundTransparency = rand(0.4, 0.7)
		b.Position = UDim2.new(rand(-0.2, 0.1), 0, math.random(), 0)
		b.Size = UDim2.new(rand(0.6, 1.3), 0, 0, math.random(3, 30))
		b.Parent = sg
		table.insert(bars, b)
	end
	local cc = getCC()
	local old = cc.Contrast
	cc.Contrast = old + 0.5
	shake = math.max(shake, 0.5)
	playSound("HackGlitch", nil, rand(0.8, 1.3))
	for _ = 1, 3 do
		task.wait(0.04)
		for _, b in ipairs(bars) do
			b.Position = UDim2.new(rand(-0.2, 0.1), 0, b.Position.Y.Scale + rand(-0.02, 0.02), 0)
		end
	end
	cc.Contrast = old
	for _, b in ipairs(bars) do
		b:Destroy()
	end
end

--== Rainbow ==--

local function rainbowArc()
	local cam = workspace.CurrentCamera
	local f = focus()
	local look = cam and cam.CFrame.LookVector * Vector3.new(1, 0, 1) or Vector3.new(0, 0, -1)
	if look.Magnitude < 0.1 then
		look = Vector3.new(0, 0, -1)
	end
	look = look.Unit
	local right = look:Cross(Vector3.yAxis).Unit
	local center = f + look * 450 + Vector3.new(0, -30, 0)
	local SEG = 40
	local bands = {}
	for b, col in ipairs(RAINBOW_COLORS) do
		local r = 320 - (b - 1) * 14
		local segLen = math.pi * r / SEG * 1.08
		local parts = {}
		for i = 0, SEG - 1 do
			local th = (i + 0.5) / SEG * math.pi
			local radial = right * math.cos(th) + Vector3.yAxis * math.sin(th)
			local tangent = -right * math.sin(th) + Vector3.yAxis * math.cos(th)
			local pos = center + radial * r
			local p = newPart({
				Size = Vector3.new(3, 14, segLen), Material = Enum.Material.Neon, Color = col, Transparency = 1,
				CFrame = CFrame.lookAt(pos, pos + tangent, radial), Parent = state.folder,
			})
			task.delay(i * 0.04, function()
				if p.Parent then
					TweenService:Create(p, TweenInfo.new(0.8), { Transparency = 0.3 }):Play()
				end
			end)
			parts[i + 1] = p
		end
		bands[b] = parts
	end
	local t0 = os.clock()
	local acc = 0
	step(function(dt)
		acc += dt
		if acc < 0.08 then
			return
		end
		acc = 0
		local t = os.clock() - t0
		if t < 2.5 then
			return
		end
		for _, parts in ipairs(bands) do
			for i, p in ipairs(parts) do
				p.Transparency = 0.3 + math.max(0, math.sin(i * 0.35 - t * 4)) * 0.35
			end
		end
	end)
end

local function bubble()
	local f = focus()
	local a = math.random() * math.pi * 2
	local r = rand(6, 50)
	local pos = f + Vector3.new(math.cos(a) * r, rand(-3, 2), math.sin(a) * r)
	local s = rand(1.2, 3.5)
	local b = newPart({
		Shape = Enum.PartType.Ball, Size = Vector3.one * s, Material = Enum.Material.Glass,
		Color = Color3.fromHSV(math.random(), 0.6, 1), Transparency = 0.45, Reflectance = 0.3,
		CFrame = CFrame.new(pos), Parent = state.folder,
	})
	local t = rand(3, 5)
	local drift = Vector3.new(rand(-6, 6), rand(18, 32), rand(-6, 6))
	local tw = TweenService:Create(b, TweenInfo.new(t, Enum.EasingStyle.Sine), { CFrame = CFrame.new(pos + drift) })
	tw.Completed:Connect(function()
		local pop = newPart({
			Shape = Enum.PartType.Ball, Size = Vector3.one * s, Material = Enum.Material.Neon,
			Color = b.Color, Transparency = 0.3, CFrame = b.CFrame, Parent = b.Parent,
		})
		b:Destroy()
		if pop.Parent then
			TweenService:Create(pop, TweenInfo.new(0.25), { Size = Vector3.one * s * 2, Transparency = 1 }):Play()
			Debris:AddItem(pop, 0.3)
		else
			pop:Destroy()
		end
	end)
	tw:Play()
end

local function rainbowWave()
	local f = focus()
	local ground = groundAt(f.X, f.Z, f.Y + 5) or (f - Vector3.new(0, 3, 0))
	for i, col in ipairs(RAINBOW_COLORS) do
		task.delay(i * 0.06, function()
			if state then
				groundRing(ground, col, 70 + i * 8, 1.4, 0.3)
			end
		end)
	end
	playSound(math.random() < 0.5 and "Chime" or "Chime2", nil, rand(0.9, 1.3))
end

local function playerTrail()
	local function attach(char)
		local root = char and char:WaitForChild("HumanoidRootPart", 5)
		if not root or not state then
			return
		end
		local a0 = Instance.new("Attachment")
		a0.Name = "WeatherTrail0"
		a0.Position = Vector3.new(0, 1.2, 0)
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Name = "WeatherTrail1"
		a1.Position = Vector3.new(0, -1.8, 0)
		a1.Parent = root
		local tr = Instance.new("Trail")
		tr.Name = "WeatherTrail"
		tr.Attachment0 = a0
		tr.Attachment1 = a1
		tr.Lifetime = 0.6
		tr.LightEmission = 0.8
		tr.Color = RAINBOW_SEQ
		tr.Transparency = NumberSequence.new(0.2, 1)
		tr.MinLength = 0.05
		tr.Parent = root
		onCleanup(function()
			a0:Destroy()
			a1:Destroy()
			tr:Destroy()
		end)
	end
	task.spawn(attach, player.Character)
	local c = player.CharacterAdded:Connect(attach)
	onCleanup(function()
		c:Disconnect()
	end)
end

--== Meteos ==--

local builders = {}

builders.Lava = function()
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local lavaSky = assets:FindFirstChild("LavaSky")
	if lavaSky then
		swapSky(lavaSky)
	end
	setProp(Lighting, { ClockTime = 17.6 }, 3)
	setProp(atm, { Color = Color3.fromRGB(255, 120, 60), Decay = Color3.fromRGB(120, 30, 10), Density = 0.3, Haze = 1.2, Glare = 0.5 }, 3)
	setProp(getCC(), { TintColor = Color3.fromRGB(255, 205, 175), Contrast = 0.14, Saturation = 0.2 }, 3)
	setProp(getBloom(), { Intensity = 0.6, Threshold = 0.9 }, 3)
	setProp(getClouds(), { Color = Color3.fromRGB(90, 40, 30), Cover = 0.75 }, 3)
	playSound("LavaStart")
	ambient("LavaAmbient")
	shake = 1.2
	followEmitter(Vector3.new(170, 1, 170), Vector3.new(0, -3, 0), {
		Texture = TEX_SPARK, Rate = 45, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(2, 6),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25),
		Size = NumberSequence.new({ kp(0, 0.4), kp(1, 0) }), LightEmission = 1, Acceleration = Vector3.new(1, 2, 0.5),
		Color = ColorSequence.new(Color3.fromRGB(255, 210, 70), Color3.fromRGB(255, 60, 0)),
	})
	followEmitter(Vector3.new(200, 1, 200), Vector3.new(0, 60, 0), {
		Texture = TEX_SMOKE, Rate = 25, Lifetime = NumberRange.new(6, 9), Speed = NumberRange.new(3, 6),
		EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(20, 20),
		Size = NumberSequence.new(0.35), Transparency = NumberSequence.new({ kp(0, 0.2), kp(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(70, 60, 58)), RotSpeed = NumberRange.new(-60, 60),
	})
	loop(function()
		return rand(0.2, 0.5)
	end, meteor)
end

builders.Galaxy = function()
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local sky = assets:FindFirstChild("GalaxySky")
	if sky then
		swapSky(sky)
	end
	setProp(Lighting, { ClockTime = 0, OutdoorAmbient = Color3.fromRGB(150, 120, 230), Ambient = Color3.fromRGB(120, 100, 190) }, 3)
	setProp(atm, { Density = 0.15, Haze = 0, Glare = 0, Color = Color3.fromRGB(150, 100, 255), Decay = Color3.fromRGB(60, 30, 120) }, 3)
	setProp(getCC(), { TintColor = Color3.fromRGB(225, 210, 255), Contrast = 0.12, Saturation = 0.2 }, 3)
	setProp(getBloom(), { Intensity = 0.8, Threshold = 0.85 }, 3)
	setProp(getClouds(), { Enabled = false })
	ambient("GalaxyAmbient")
	playSound("Twinkle", nil, 0.8)
	planets()
	followEmitter(Vector3.new(230, 90, 230), Vector3.new(0, 50, 0), {
		Texture = TEX_SPARK, Rate = 55, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(0, 0),
		Size = NumberSequence.new({ kp(0, 0), kp(0.5, 1), kp(1, 0) }), LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 140, 255)),
	})
	followEmitter(Vector3.new(120, 1, 120), Vector3.new(0, -2, 0), {
		Texture = TEX_SPARK, Rate = 25, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(1, 3),
		EmissionDirection = Enum.NormalId.Top, Size = NumberSequence.new({ kp(0, 0.3), kp(1, 0) }),
		LightEmission = 1, LightInfluence = 0, Color = ColorSequence.new(Color3.fromRGB(150, 220, 255), Color3.fromRGB(230, 120, 255)),
	})
	followEmitter(Vector3.new(700, 40, 700), Vector3.new(0, 220, 0), {
		Texture = TEX_SMOKE, Rate = 4, Lifetime = NumberRange.new(15, 22), Speed = NumberRange.new(0, 1),
		Size = NumberSequence.new({ kp(0, 60), kp(1, 120) }), LightEmission = 1, LightInfluence = 0,
		Transparency = NumberSequence.new({ kp(0, 1), kp(0.3, 0.75), kp(0.7, 0.75), kp(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(150, 70, 255), Color3.fromRGB(60, 150, 255)),
		RotSpeed = NumberRange.new(-5, 5), Rotation = NumberRange.new(0, 360),
	})
	loop(function()
		return rand(0.4, 1.1)
	end, shootingStar)
end

builders.Hacker = function()
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	setProp(Lighting, { ClockTime = 20.5, OutdoorAmbient = Color3.fromRGB(70, 160, 90) }, 3)
	setProp(atm, { Color = Color3.fromRGB(40, 255, 120), Decay = Color3.fromRGB(0, 70, 25), Density = 0.36, Haze = 1.6, Glare = 0 }, 3)
	setProp(getCC(), { TintColor = Color3.fromRGB(175, 255, 190), Contrast = 0.25, Saturation = -0.35 }, 3)
	setProp(getBloom(), { Intensity = 0.7, Threshold = 0.85 }, 3)
	setProp(getClouds(), { Color = Color3.fromRGB(20, 80, 40) }, 3)
	state.billboards = 0
	local sg = screenGui("WeatherHacker", 0)
	matrixRain(sg)
	terminal(sg)
	local sg2 = screenGui("WeatherGlitch", 6)
	loop(function()
		return rand(0.12, 0.3)
	end, hackBillboard)
	loop(function()
		return rand(0.08, 0.18)
	end, dataCube)
	loop(function()
		return rand(4, 7)
	end, scanPulse)
	loop(function()
		return rand(3, 6)
	end, function()
		glitch(sg2)
	end)
end

builders.Rainbow = function()
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local cc = getCC()
	setProp(Lighting, { ClockTime = 13 }, 3)
	setProp(atm, { Density = 0.3, Haze = 1, Glare = 0.3 }, 3)
	if atm then
		setProp(atm, { Color = atm.Color })
	end
	setProp(cc, { Saturation = 0.4, Contrast = 0.08, TintColor = cc.TintColor })
	setProp(getBloom(), { Intensity = 0.7, Threshold = 0.9 }, 3)
	playSound("Chime", nil, 0.8)
	rainbowArc()
	playerTrail()
	followEmitter(Vector3.new(170, 1, 170), Vector3.new(0, 45, 0), {
		Texture = TEX_SPARK, Rate = 70, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(3, 6),
		EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(25, 25),
		Size = NumberSequence.new({ kp(0, 0.6), kp(1, 0.3) }), LightEmission = 1, Color = RAINBOW_SEQ,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-180, 180),
	})
	loop(function()
		return rand(0.15, 0.35)
	end, bubble)
	loop(function()
		return rand(3.5, 6)
	end, rainbowWave)
	local t0 = os.clock()
	step(function()
		local h = ((os.clock() - t0) * 0.08) % 1
		cc.TintColor = Color3.fromHSV(h, 0.14, 1)
		if atm then
			atm.Color = Color3.fromHSV((h + 0.5) % 1, 0.45, 1)
		end
	end)
end

--== Admin ==--

local ADMIN_RED = Color3.fromRGB(255, 30, 45)
local ADMIN_GOLD = Color3.fromRGB(255, 210, 70)

local function adminBolt()
	local f = focus()
	local a = math.random() * math.pi * 2
	local r = rand(12, 140)
	local x, z = f.X + math.cos(a) * r, f.Z + math.sin(a) * r
	local ground = groundAt(x, z, f.Y + 300) or Vector3.new(x, f.Y - 3, z)
	local top = ground + Vector3.new(rand(-20, 20), 220, rand(-20, 20))
	local segments = 9
	local prev = top
	local parts = {}
	for i = 1, segments do
		local t = i / segments
		local target = top:Lerp(ground, t)
		if i < segments then
			target += Vector3.new(rand(-7, 7), 0, rand(-7, 7))
		end
		local len = (target - prev).Magnitude
		local seg = newPart({
			Size = Vector3.new(0.9, 0.9, len), Material = Enum.Material.Neon,
			Color = i % 2 == 0 and ADMIN_RED or Color3.fromRGB(255, 230, 230),
			CFrame = CFrame.lookAt(prev:Lerp(target, 0.5), target), Parent = state.folder,
		})
		table.insert(parts, seg)
		prev = target
	end
	for _, seg in ipairs(parts) do
		TweenService:Create(seg, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Transparency = 1, Size = Vector3.new(0.1, 0.1, seg.Size.Z) }):Play()
		Debris:AddItem(seg, 0.4)
	end
	groundRing(ground, ADMIN_RED, 38, 0.7, 0.4)
	groundRing(ground, ADMIN_GOLD, 20, 0.45, 0.3)
	local holder = newPart({ Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(ground), Parent = state.folder })
	emitter(holder, {
		Texture = TEX_SPARK, Rate = 0, Speed = NumberRange.new(20, 45), SpreadAngle = Vector2.new(80, 80),
		EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(0.4, 0.9), Acceleration = Vector3.new(0, -60, 0),
		Size = NumberSequence.new(1.2, 0), LightEmission = 1, Drag = 2,
		Color = ColorSequence.new(ADMIN_GOLD, ADMIN_RED),
	}):Emit(35)
	local light = Instance.new("PointLight")
	light.Color = ADMIN_RED
	light.Range = 45
	light.Brightness = 8
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	Debris:AddItem(holder, 1.5)
	soundAt("AdminZap", ground, rand(0.85, 1.15))
	local cam = workspace.CurrentCamera
	local d = cam and (cam.CFrame.Position - ground).Magnitude or 999
	if d < 70 then
		shake = math.max(shake, (1 - d / 70) * 1.2)
	end
	local cc = getCC()
	local b = cc.Brightness
	cc.Brightness = b + 0.12
	TweenService:Create(cc, TweenInfo.new(0.25), { Brightness = b }):Play()
end

local function adminCrown()
	local f = focus()
	local a = math.random() * math.pi * 2
	local r = rand(6, 40)
	local pos = f + Vector3.new(math.cos(a) * r, rand(-2, 3), math.sin(a) * r)
	local holder = newPart({ Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(pos), Parent = state.folder })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(4, 4)
	bb.LightInfluence = 0
	bb.Parent = holder
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.TextScaled = true
	t.Text = math.random() < 0.7 and "👑" or "⚠️"
	t.Parent = bb
	local dur = rand(2.5, 4)
	TweenService:Create(holder, TweenInfo.new(dur, Enum.EasingStyle.Sine), { CFrame = CFrame.new(pos + Vector3.new(0, rand(12, 22), 0)) }):Play()
	TweenService:Create(t, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1 }):Play()
	Debris:AddItem(holder, dur + 0.1)
end

local function adminBanner(sg)
	local vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = ADMIN_RED
	vignette.BackgroundTransparency = 0
	vignette.BorderSizePixel = 0
	vignette.Parent = sg
	local vg = Instance.new("UIGradient")
	vg.Transparency = NumberSequence.new({ kp(0, 0.55), kp(0.15, 1), kp(0.85, 1), kp(1, 0.55) })
	vg.Parent = vignette
	local vignette2 = vignette:Clone()
	vignette2.UIGradient.Rotation = 90
	vignette2.Parent = sg

	local banner = Instance.new("TextLabel")
	banner.Name = "AdminBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 150)
	banner.Size = UDim2.fromOffset(460, 46)
	banner.BackgroundTransparency = 1
	banner.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
	banner.Text = "⚠ ADMIN ABUSE ⚠"
	banner.TextScaled = true
	banner.TextColor3 = Color3.new(1, 1, 1)
	banner.Parent = sg
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, ADMIN_GOLD),
		ColorSequenceKeypoint.new(0.5, ADMIN_RED),
		ColorSequenceKeypoint.new(1, ADMIN_GOLD),
	})
	g.Parent = banner
	local st = Instance.new("UIStroke")
	st.Thickness = 3.5
	st.Color = Color3.fromRGB(40, 0, 5)
	st.Parent = banner
	local sub = Instance.new("TextLabel")
	sub.AnchorPoint = Vector2.new(0.5, 0)
	sub.Position = UDim2.new(0.5, 0, 1, 2)
	sub.Size = UDim2.fromOffset(520, 24)
	sub.BackgroundTransparency = 1
	sub.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
	sub.Text = "👑 4% ADMIN MUTATION CHANCE 👑"
	sub.TextScaled = true
	sub.TextColor3 = ADMIN_GOLD
	sub.Parent = banner
	local st2 = st:Clone()
	st2.Thickness = 2.5
	st2.Parent = sub
	local scale = Instance.new("UIScale")
	scale.Parent = banner
	local t0 = os.clock()
	step(function()
		local t = os.clock() - t0
		scale.Scale = 1 + math.abs(math.sin(t * 3)) * 0.06
		g.Offset = Vector2.new(math.sin(t * 1.8) * 0.5, 0)
		local pulse = 0.55 + (math.sin(t * 4) + 1) * 0.12
		vg.Transparency = NumberSequence.new({ kp(0, pulse), kp(0.15, 1), kp(0.85, 1), kp(1, pulse) })
		vignette2.UIGradient.Transparency = vg.Transparency
	end)
end

-- Intro plein ecran : flash rouge, titre qui s'ecrase, bandes de glitch.
local function adminIntro(sg)
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = ADMIN_RED
	flash.BorderSizePixel = 0
	flash.ZIndex = 50
	flash.Parent = sg
	TweenService:Create(flash, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(flash, 1)

	for i = 1, 14 do
		local bar = Instance.new("Frame")
		bar.BorderSizePixel = 0
		bar.BackgroundColor3 = i % 3 == 0 and ADMIN_GOLD or (i % 2 == 0 and Color3.new(1, 1, 1) or ADMIN_RED)
		bar.BackgroundTransparency = 0.2
		bar.Position = UDim2.new(math.random() * 0.6 - 0.2, 0, math.random(), 0)
		bar.Size = UDim2.new(rand(0.3, 1), 0, 0, math.random(4, 22))
		bar.ZIndex = 51
		bar.Parent = sg
		task.delay(rand(0.05, 0.9), function()
			bar:Destroy()
		end)
	end

	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.4)
	title.Size = UDim2.fromScale(0.8, 0.2)
	title.BackgroundTransparency = 1
	title.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
	title.Text = "⚠ ADMIN ABUSE ⚠"
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.ZIndex = 60
	title.Parent = sg
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(ADMIN_GOLD, ADMIN_RED)
	g.Parent = title
	local st = Instance.new("UIStroke")
	st.Thickness = 6
	st.Color = Color3.fromRGB(40, 0, 5)
	st.Parent = title
	local sc = Instance.new("UIScale")
	sc.Scale = 4
	sc.Parent = title
	title.Rotation = -12
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(title, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()
	task.delay(0.33, function()
		shake = math.max(shake, 2.2)
		playSound("AdminBoom", nil, 0.8)
	end)
	task.delay(2.2, function()
		TweenService:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.3 }):Play()
		TweenService:Create(title, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		TweenService:Create(st, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		Debris:AddItem(title, 0.4)
	end)

	local cam = workspace.CurrentCamera
	if cam then
		local fov = cam.FieldOfView
		cam.FieldOfView = fov + 18
		TweenService:Create(cam, TweenInfo.new(0.8, Enum.EasingStyle.Back), { FieldOfView = fov }):Play()
	end
end

-- Portail geant (anneau rouge et or) qui tourne dans le ciel au-dessus du joueur.
local PORTAL_Y = 120
local function adminPortal()
	local ring = Instance.new("Model")
	ring.Name = "AdminPortal"
	local segs = 36
	local radius = 70
	local parts = {}
	for i = 1, segs do
		local a = i / segs * math.pi * 2
		local seg = newPart({
			Size = Vector3.new(3, 3, radius * 2 * math.pi / segs + 0.6), Material = Enum.Material.Neon,
			Color = i % 2 == 0 and ADMIN_RED or ADMIN_GOLD, Parent = ring,
		})
		parts[i] = { part = seg, a = a }
	end
	local core = newPart({ Size = Vector3.new(1, 1, 1), Transparency = 1, Parent = ring })
	emitter(core, {
		Texture = "rbxasset://textures/particles/forcefield_vortex_main.dds", Rate = 3, Lifetime = NumberRange.new(3, 3),
		Speed = NumberRange.new(0, 0), Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Bottom, LockedToPart = true, LightEmission = 1,
		Size = NumberSequence.new({ kp(0, 40), kp(1, 130) }), Transparency = NumberSequence.new({ kp(0, 0.4), kp(1, 1) }),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-40, 40),
		Color = ColorSequence.new(ADMIN_RED, Color3.fromRGB(120, 0, 15)),
	})
	emitter(core, {
		Texture = TEX_SPARK, Rate = 40, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(20, 40),
		EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(40, 40), LightEmission = 1,
		Size = NumberSequence.new({ kp(0, 2), kp(1, 0) }), Color = ColorSequence.new(ADMIN_GOLD, ADMIN_RED),
	})
	local light = Instance.new("PointLight")
	light.Color = ADMIN_RED
	light.Range = 60
	light.Brightness = 4
	light.Parent = core
	ring.Parent = state.folder
	local t0 = os.clock()
	step(function()
		local f = focus()
		local t = os.clock() - t0
		local center = Vector3.new(f.X, f.Y + PORTAL_Y, f.Z)
		local tilt = CFrame.new(center) * CFrame.Angles(0, t * 0.25, 0)
		core.CFrame = CFrame.new(center)
		local pulse = 1 + math.sin(t * 2) * 0.04
		for _, p in ipairs(parts) do
			local a = p.a
			local pos = tilt * Vector3.new(math.cos(a) * radius * pulse, math.sin(t * 1.5 + a * 3) * 2, math.sin(a) * radius * pulse)
			local tangent = tilt:VectorToWorldSpace(Vector3.new(-math.sin(a), 0, math.cos(a)))
			p.part.CFrame = CFrame.lookAt(pos, pos + tangent)
		end
	end)
end

-- Laser orbital : colonne rouge qui tombe du portail et frappe le sol.
local function adminLaser()
	local f = focus()
	local a = math.random() * math.pi * 2
	local r = rand(15, 90)
	local x, z = f.X + math.cos(a) * r, f.Z + math.sin(a) * r
	local ground = groundAt(x, z, f.Y + 300) or Vector3.new(x, f.Y - 3, z)
	local top = Vector3.new(x, f.Y + PORTAL_Y, z)
	local h = top.Y - ground.Y
	local mid = (top + ground) / 2

	local warn = groundRing(ground, ADMIN_RED, 14, 0.9, 0.2)
	warn.Transparency = 0.4
	task.wait(0.55)
	if not state then
		return
	end
	local core = newPart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1, 1), Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 235, 235), CFrame = CFrame.new(mid) * CFrame.Angles(0, 0, math.rad(90)), Parent = state.folder,
	})
	local outer = newPart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1, 1), Material = Enum.Material.Neon,
		Color = ADMIN_RED, Transparency = 0.35, CFrame = core.CFrame, Parent = state.folder,
	})
	TweenService:Create(core, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Size = Vector3.new(h, 3.5, 3.5) }):Play()
	TweenService:Create(outer, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Size = Vector3.new(h, 8, 8) }):Play()
	task.delay(0.45, function()
		TweenService:Create(core, TweenInfo.new(0.35), { Size = Vector3.new(h, 0.1, 0.1), Transparency = 1 }):Play()
		TweenService:Create(outer, TweenInfo.new(0.35), { Size = Vector3.new(h, 0.1, 0.1), Transparency = 1 }):Play()
	end)
	Debris:AddItem(core, 0.9)
	Debris:AddItem(outer, 0.9)

	groundRing(ground, ADMIN_RED, 46, 0.8, 0.5)
	groundRing(ground, ADMIN_GOLD, 26, 0.55, 0.35)
	groundRing(ground, Color3.new(1, 1, 1), 12, 0.35, 0.3)
	local scorch = newPart({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 10, 10), Material = Enum.Material.Neon,
		Color = ADMIN_RED, CFrame = CFrame.new(ground + Vector3.new(0, 0.07, 0)) * CFrame.Angles(0, 0, math.rad(90)), Parent = state.folder,
	})
	TweenService:Create(scorch, TweenInfo.new(3, Enum.EasingStyle.Sine), { Color = Color3.fromRGB(40, 10, 12), Transparency = 1 }):Play()
	Debris:AddItem(scorch, 3.2)
	local holder = newPart({ Size = Vector3.one, Transparency = 1, CFrame = CFrame.new(ground), Parent = state.folder })
	emitter(holder, {
		Texture = TEX_SPARK, Rate = 0, Speed = NumberRange.new(30, 60), SpreadAngle = Vector2.new(85, 85),
		EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(0.5, 1), Acceleration = Vector3.new(0, -80, 0),
		Size = NumberSequence.new(1.4, 0), LightEmission = 1, Drag = 2, Color = ColorSequence.new(ADMIN_GOLD, ADMIN_RED),
	}):Emit(50)
	emitter(holder, {
		Texture = TEX_SMOKE, Rate = 0, Speed = NumberRange.new(6, 14), SpreadAngle = Vector2.new(70, 70),
		EmissionDirection = Enum.NormalId.Top, Lifetime = NumberRange.new(1.5, 2.5), Drag = 1.5,
		Size = NumberSequence.new({ kp(0, 4), kp(1, 12) }), Transparency = NumberSequence.new({ kp(0, 0.3), kp(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(120, 20, 30), Color3.fromRGB(30, 10, 12)),
	}):Emit(12)
	local light = Instance.new("PointLight")
	light.Color = ADMIN_RED
	light.Range = 60
	light.Brightness = 10
	light.Parent = holder
	TweenService:Create(light, TweenInfo.new(0.8), { Brightness = 0 }):Play()
	Debris:AddItem(holder, 3)
	soundAt("AdminBoom", ground, rand(0.9, 1.15))
	soundAt("AdminZap", ground, rand(0.7, 0.9))
	local cam = workspace.CurrentCamera
	local d = cam and (cam.CFrame.Position - ground).Magnitude or 999
	if d < 110 then
		shake = math.max(shake, (1 - d / 110) * 2)
	end
end

-- Marteau du ban geant qui tombe du ciel.
local function banHammer()
	local f = focus()
	local a = math.random() * math.pi * 2
	local r = rand(25, 70)
	local x, z = f.X + math.cos(a) * r, f.Z + math.sin(a) * r
	local ground = groundAt(x, z, f.Y + 300) or Vector3.new(x, f.Y - 3, z)
	local model = Instance.new("Model")
	model.Name = "BanHammer"
	local yaw = CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local base = CFrame.new(ground) * yaw
	newPart({ Size = Vector3.new(2.2, 26, 2.2), Material = Enum.Material.Wood, Color = Color3.fromRGB(110, 60, 30), CFrame = base * CFrame.new(0, 13 + 7, 0), Parent = model })
	newPart({ Size = Vector3.new(2.8, 2, 2.8), Material = Enum.Material.Neon, Color = ADMIN_GOLD, CFrame = base * CFrame.new(0, 30, 0), Parent = model })
	newPart({ Size = Vector3.new(2.8, 1.2, 2.8), Material = Enum.Material.Neon, Color = ADMIN_GOLD, CFrame = base * CFrame.new(0, 8, 0), Parent = model })
	local head = newPart({ Size = Vector3.new(18, 9, 9), Material = Enum.Material.Metal, Color = Color3.fromRGB(200, 25, 40), CFrame = base * CFrame.new(0, 3.5 + 32, 0), Parent = model })
	newPart({ Size = Vector3.new(19, 1.4, 9.6), Material = Enum.Material.Neon, Color = ADMIN_GOLD, CFrame = base * CFrame.new(0, 35.5 + 3.2, 0), Parent = model })
	newPart({ Size = Vector3.new(19, 1.4, 9.6), Material = Enum.Material.Neon, Color = ADMIN_GOLD, CFrame = base * CFrame.new(0, 35.5 - 3.2, 0), Parent = model })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(14, 4)
	bb.StudsOffset = Vector3.new(0, 7, 0)
	bb.LightInfluence = 0
	bb.AlwaysOnTop = true
	bb.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
	label.Text = "BAN HAMMER"
	label.TextScaled = true
	label.TextColor3 = ADMIN_GOLD
	label.Parent = bb
	local ls = Instance.new("UIStroke")
	ls.Thickness = 4
	ls.Parent = label
	addTrail(head, 9, 0.35, ColorSequence.new(ADMIN_GOLD, ADMIN_RED))
	model.Parent = state.folder

	-- Le marteau tombe en tournant vers le sol (pivot au bout du manche).
	local fall = 160
	local start = base * CFrame.new(0, fall, 0) * CFrame.Angles(math.rad(-80), 0, 0)
	local offsets = {}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			offsets[p] = base:ToObjectSpace(p.CFrame)
			p.CFrame = start * offsets[p]
		end
	end
	soundAt("MeteorWhoosh", ground + Vector3.new(0, 60, 0), 0.7)
	local value = Instance.new("NumberValue")
	value.Changed:Connect(function(v)
		local cf = base * CFrame.new(0, fall * (1 - v), 0) * CFrame.Angles(math.rad(-80 * (1 - v) + 90 * v), 0, 0)
		for p, off in pairs(offsets) do
			p.CFrame = cf * off
		end
	end)
	local tw = TweenService:Create(value, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = 1 })
	tw:Play()
	tw.Completed:Wait()
	value:Destroy()
	if not state then
		return
	end
	local hit = head.Position - Vector3.new(0, head.Size.Z / 2, 0)
	local impactPos = Vector3.new(hit.X, ground.Y, hit.Z)
	groundRing(impactPos, ADMIN_RED, 70, 0.9, 0.6)
	groundRing(impactPos, ADMIN_GOLD, 40, 0.6, 0.4)
	for _ = 1, 8 do
		debrisRock(impactPos, 4)
	end
	soundAt("AdminBoom", impactPos, 0.7)
	soundAt("MeteorImpact", impactPos, 0.8)
	label.Text = "BANNED!"
	label.TextColor3 = ADMIN_RED
	local cam = workspace.CurrentCamera
	local d = cam and (cam.CFrame.Position - impactPos).Magnitude or 999
	if d < 140 then
		shake = math.max(shake, (1 - d / 140) * 3)
	end
	task.delay(1.4, function()
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				TweenService:Create(p, TweenInfo.new(0.8), { Transparency = 1 }):Play()
			elseif p:IsA("Trail") then
				p.Enabled = false
			end
		end
		bb.Enabled = false
		Debris:AddItem(model, 1)
	end)
end

builders.Admin = function()
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	setProp(Lighting, { ClockTime = 18.3, OutdoorAmbient = Color3.fromRGB(160, 100, 105), Ambient = Color3.fromRGB(125, 85, 90) }, 3)
	setProp(atm, { Color = Color3.fromRGB(255, 110, 115), Decay = Color3.fromRGB(120, 15, 30), Density = 0.28, Haze = 1.2, Glare = 0.4 }, 3)
	setProp(getCC(), { TintColor = Color3.fromRGB(255, 226, 226), Contrast = 0.16, Saturation = 0.18, Brightness = 0 }, 3)
	setProp(getBloom(), { Intensity = 1, Threshold = 0.8, Size = 30 }, 3)
	setProp(getClouds(), { Color = Color3.fromRGB(90, 8, 20), Cover = 0.85, Density = 0.6 }, 3)
	playSound("AdminStart")
	ambient("AdminAmbient")
	shake = 1.5
	local sg = screenGui("WeatherAdmin", 5)
	adminIntro(sg)
	task.delay(1.2, function()
		if state and state.key == "Admin" then
			adminBanner(sg)
		end
	end)
	adminPortal()
	followEmitter(Vector3.new(200, 1, 200), Vector3.new(0, 55, 0), {
		Texture = TEX_SPARK, Rate = 90, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(6, 12),
		EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(15, 15),
		Size = NumberSequence.new({ kp(0, 0.8), kp(1, 0.2) }), LightEmission = 1,
		Color = ColorSequence.new(ADMIN_GOLD, ADMIN_RED), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-120, 120),
	})
	followEmitter(Vector3.new(160, 1, 160), Vector3.new(0, -3, 0), {
		Texture = TEX_FIRE, Rate = 35, Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(2, 5),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), LightEmission = 1,
		Size = NumberSequence.new({ kp(0, 0.6), kp(1, 0) }), Acceleration = Vector3.new(0, 3, 0),
		Color = ColorSequence.new(Color3.fromRGB(255, 80, 80), Color3.fromRGB(150, 0, 15)),
	})
	followEmitter(Vector3.new(120, 1, 120), Vector3.new(0, 40, 0), {
		Texture = "rbxasset://textures/particles/fire_sparks_main.dds", Rate = 25, Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(10, 18), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(10, 10),
		Size = NumberSequence.new({ kp(0, 1.2), kp(1, 0.4) }), LightEmission = 1,
		Color = ColorSequence.new(ADMIN_GOLD), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-200, 200),
	})
	loop(function()
		return rand(0.6, 1.4)
	end, adminBolt)
	loop(function()
		return rand(0.2, 0.45)
	end, adminCrown)
	task.delay(2.5, function()
		if not state or state.key ~= "Admin" then
			return
		end
		loop(function()
			return rand(2.5, 5)
		end, adminLaser)
		loop(function()
			return rand(9, 15)
		end, banHammer)
	end)
end

--== API ==--

function FX.Stop(instant: boolean?)
	local s = state
	if not s then
		return
	end
	state = nil
	for _, fn in ipairs(s.cleanups) do
		pcall(fn)
	end
	for _, tw in ipairs(s.tweens) do
		tw:Cancel()
	end
	for inst, props in pairs(s.saved) do
		local tw = {}
		for prop, val in pairs(props) do
			local ty = typeof(val)
			if not instant and (ty == "number" or ty == "Color3") then
				tw[prop] = val
			else
				inst[prop] = val
			end
		end
		if next(tw) then
			TweenService:Create(inst, TweenInfo.new(2, Enum.EasingStyle.Sine), tw):Play()
		end
	end
	if instant then
		s.folder:Destroy()
	else
		for _, p in ipairs(s.folder:GetDescendants()) do
			if p:IsA("BasePart") and p.Transparency < 1 then
				TweenService:Create(p, TweenInfo.new(1.2), { Transparency = 1 }):Play()
			elseif p:IsA("ParticleEmitter") or p:IsA("Trail") then
				p.Enabled = false
			elseif p:IsA("BillboardGui") then
				p.Enabled = false
			end
		end
		Debris:AddItem(s.folder, 2)
	end
	shake = 0
end

function FX.Start(key: string)
	FX.Stop(true)
	local builder = builders[key]
	if not builder then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "WeatherFX_" .. key
	folder.Parent = workspace
	state = { key = key, folder = folder, saved = {}, tweens = {}, cleanups = {} }
	local ok, err = pcall(builder)
	if not ok then
		warn("WeatherFX: " .. tostring(err))
	end
end

function FX.Current(): string?
	return state and state.key
end

return FX
