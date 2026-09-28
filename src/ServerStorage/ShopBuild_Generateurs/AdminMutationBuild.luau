--[[
	AdminMutationBuild
	------------------
	Nouveau look de la mutation ADMIN (BrainrotPack.Admin) : avant, la
	texture etait teintee en gris quasi noir (SurfaceAppearance.Color
	45,45,50) -> brainrots tout noirs.

	Maintenant :
	  - texture d'origine teintee rouge rubis (on garde tous les details) ;
	  - aura de flammes rouges, braises dorees, etincelles, onde d'energie
	    qui pulse, eclairs dores, lumiere rouge (effets dans l'attachment
	    AdminFX, a la taille de chaque brainrot).

	Traite Workspace.BrainrotPack.Admin et ServerStorage.BrainrotPack.Admin
	(les deux si presents). Relancable.
]]

local ServerStorage = game:GetService("ServerStorage")

local M = {}

M.TINT = Color3.fromRGB(255, 92, 100)
local RED = Color3.fromRGB(255, 40, 55)
local GOLD = Color3.fromRGB(255, 205, 70)
local DEEP = Color3.fromRGB(150, 0, 20)

local function kp(t, v)
	return NumberSequenceKeypoint.new(t, v)
end

local function emitter(parent: Instance, name: string, props)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = name
	for k, v in pairs(props) do
		pe[k] = v
	end
	pe.Parent = parent
	return pe
end

local function style(mesh: MeshPart)
	local sa = mesh:FindFirstChildOfClass("SurfaceAppearance")
	if sa then
		sa.Color = M.TINT
	else
		mesh.Color = M.TINT
	end

	local fx = mesh:FindFirstChild("AdminFX")
	if fx then
		fx:ClearAllChildren()
	else
		fx = Instance.new("Attachment")
		fx.Name = "AdminFX"
		fx.Parent = mesh
	end
	local s = math.max(mesh.Size.X, mesh.Size.Y, mesh.Size.Z) / 5
	fx.Position = Vector3.new(0, -mesh.Size.Y * 0.1, 0)

	emitter(fx, "AdminAura", {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 90)), ColorSequenceKeypoint.new(0.5, RED), ColorSequenceKeypoint.new(1, DEEP) }),
		LightEmission = 0.9, LightInfluence = 0, Rate = 22,
		Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(1.5 * s, 3 * s),
		SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		Size = NumberSequence.new({ kp(0, 1.4 * s), kp(1, 0.2 * s) }),
		Transparency = NumberSequence.new({ kp(0, 0.55), kp(0.4, 0.4), kp(1, 1) }),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-60, 60),
		ZOffset = -1,
	})
	emitter(fx, "AdminEmbers", {
		Texture = "rbxasset://textures/particles/fire_sparks_main.dds",
		Color = ColorSequence.new(GOLD, Color3.fromRGB(255, 90, 40)),
		LightEmission = 1, LightInfluence = 0, Rate = 14,
		Lifetime = NumberRange.new(1, 1.8), Speed = NumberRange.new(2 * s, 4.5 * s),
		SpreadAngle = Vector2.new(40, 40), EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(0, 2 * s, 0), Drag = 1,
		Size = NumberSequence.new({ kp(0, 0.5 * s), kp(1, 0) }),
	})
	emitter(fx, "AdminSparkles", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 180), GOLD),
		LightEmission = 1, LightInfluence = 0, Rate = 9,
		Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Shape = Enum.ParticleEmitterShape.Sphere,
		Size = NumberSequence.new({ kp(0, 0), kp(0.3, 0.55 * s), kp(1, 0) }),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-180, 180),
	})
	emitter(fx, "AdminPulse", {
		Texture = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
		Color = ColorSequence.new(RED, GOLD),
		LightEmission = 1, LightInfluence = 0, Rate = 0.8,
		Lifetime = NumberRange.new(1.2, 1.2), Speed = NumberRange.new(0, 0),
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new({ kp(0, 0.5 * s), kp(1, 6 * s) }),
		Transparency = NumberSequence.new({ kp(0, 0.2), kp(1, 1) }),
		LockedToPart = true,
	})
	emitter(fx, "AdminBolts", {
		Texture = "rbxasset://textures/particles/forcefield_vortex_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 150), RED),
		LightEmission = 1, LightInfluence = 0, Rate = 3,
		Lifetime = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(0, 0),
		Size = NumberSequence.new({ kp(0, 3 * s), kp(1, 4.5 * s) }),
		Transparency = NumberSequence.new({ kp(0, 0.3), kp(1, 1) }),
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-400, 400),
		LockedToPart = true,
	})

	local light = mesh:FindFirstChild("AdminLight")
	if not light then
		light = Instance.new("PointLight")
		light.Name = "AdminLight"
		light.Parent = mesh
	end
	light.Color = RED
	light.Range = 8 * s + 4
	light.Brightness = 1.6
end

local function process(folder: Instance?): number
	if not folder then
		return 0
	end
	local n = 0
	for _, model in ipairs(folder:GetChildren()) do
		local mesh = model:FindFirstChild("Mesh")
		if mesh and mesh:IsA("MeshPart") then
			style(mesh)
			n += 1
		end
	end
	return n
end

function M.run(): string
	local a = workspace:FindFirstChild("BrainrotPack")
	local b = ServerStorage:FindFirstChild("BrainrotPack")
	local n = process(a and a:FindFirstChild("Admin")) + process(b and b:FindFirstChild("Admin"))
	return ("Mutation Admin : %d brainrots restyles"):format(n)
end

return M
