--[[
	TraitFxClient
	-------------
	Effets visuels (locaux) sur chaque brainrot qui a un TRAIT (attribut
	"Trait" de sa part : pose sur une base, porte en main, au sol...).
	Chaque trait a son style, de plus en plus fou avec la rarete :
	  1 : icones du trait qui montent doucement
	  2 : + etincelles
	  3 : + flammes / braises
	  4 : + halo lumineux + lumiere
	  5 : + tourbillon d'energie
	  6 : + onde qui pulse
	  7 : + faisceau vers le ciel + tout en plus fort
	Couleur + icone : ReplicatedStorage.Traits.TraitShared.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local TraitShared = require(ReplicatedStorage:WaitForChild("Traits"):WaitForChild("TraitShared"))

local player = Players.LocalPlayer
local FX_NAME = "TraitFX"
local MAX_DISTANCE = 140

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local EMBER = "rbxasset://textures/particles/fire_sparks_main.dds"
local VORTEX = "rbxasset://textures/particles/forcefield_vortex_main.dds"
local WAVE = "rbxasset://textures/particles/explosion01_shockwave_main.dds"
local GLOW = "rbxasset://textures/particles/forcefield_glow_main.dds"

local function kp(t, v)
	return NumberSequenceKeypoint.new(t, v)
end

local function emitter(parent: Instance, name: string, props)
	local pe = Instance.new("ParticleEmitter")
	pe.Name = name
	pe.LightInfluence = 0
	for k, v in pairs(props) do
		pe[k] = v
	end
	pe.Parent = parent
	return pe
end

local function build(part: BasePart, trait)
	local old = part:FindFirstChild(FX_NAME)
	if old then
		old:Destroy()
	end
	local att = Instance.new("Attachment")
	att.Name = FX_NAME
	att.Parent = part
	local s = math.clamp(math.max(part.Size.X, part.Size.Y, part.Size.Z) / 5, 0.5, 2.5)
	local rank = trait.rank or 1
	local color = trait.color
	local light = color:Lerp(Color3.new(1, 1, 1), 0.5)
	local icon = TraitShared.Image(trait)

	-- 1 : icones du trait qui montent.
	if icon ~= "" then
		emitter(att, "TraitIcons", {
			Texture = icon, Rate = 0.8 + rank * 0.35, Lifetime = NumberRange.new(1.6, 2.4),
			Speed = NumberRange.new(1.2 * s, 2.2 * s), SpreadAngle = Vector2.new(35, 35), EmissionDirection = Enum.NormalId.Top,
			Size = NumberSequence.new({ kp(0, 0), kp(0.15, (0.7 + rank * 0.08) * s), kp(0.8, (0.7 + rank * 0.08) * s), kp(1, 0) }),
			Transparency = NumberSequence.new({ kp(0, 0.1), kp(0.8, 0.2), kp(1, 1) }),
			Rotation = NumberRange.new(-20, 20), RotSpeed = NumberRange.new(-30, 30),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Acceleration = Vector3.new(0, 0.5, 0), ZOffset = 1,
		})
	end
	-- 2 : etincelles.
	if rank >= 2 then
		emitter(att, "TraitSparkles", {
			Texture = SPARK, Color = ColorSequence.new(light, color), LightEmission = 1,
			Rate = 4 + rank * 2, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(180, 180), Shape = Enum.ParticleEmitterShape.Sphere,
			Size = NumberSequence.new({ kp(0, 0), kp(0.3, 0.45 * s), kp(1, 0) }),
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-180, 180),
		})
	end
	-- 3 : flammes + braises.
	if rank >= 3 then
		emitter(att, "TraitFlames", {
			Texture = FIRE, Color = ColorSequence.new(light, color), LightEmission = 0.9,
			Rate = 8 + rank * 2, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(1 * s, 2.5 * s),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			Size = NumberSequence.new({ kp(0, 1 * s), kp(1, 0.1 * s) }),
			Transparency = NumberSequence.new({ kp(0, 0.6), kp(0.4, 0.45), kp(1, 1) }), ZOffset = -1,
		})
		emitter(att, "TraitEmbers", {
			Texture = EMBER, Color = ColorSequence.new(light), LightEmission = 1,
			Rate = 5 + rank, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(2 * s, 4 * s),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Drag = 1,
			Size = NumberSequence.new({ kp(0, 0.35 * s), kp(1, 0) }),
		})
	end
	-- 4 : halo + lumiere.
	if rank >= 4 then
		emitter(att, "TraitHalo", {
			Texture = GLOW, Color = ColorSequence.new(color), LightEmission = 1,
			Rate = 2, Lifetime = NumberRange.new(1.2, 1.2), Speed = NumberRange.new(0, 0), LockedToPart = true,
			Size = NumberSequence.new({ kp(0, 3 * s), kp(0.5, 3.6 * s), kp(1, 3 * s) }),
			Transparency = NumberSequence.new({ kp(0, 1), kp(0.5, 0.75), kp(1, 1) }),
		})
		local pl = Instance.new("PointLight")
		pl.Name = "TraitLight"
		pl.Color = color
		pl.Range = 6 + rank * 1.5
		pl.Brightness = 0.6 + rank * 0.15
		pl.Parent = att
	end
	-- 5 : tourbillon.
	if rank >= 5 then
		emitter(att, "TraitVortex", {
			Texture = VORTEX, Color = ColorSequence.new(light, color), LightEmission = 1,
			Rate = 2, Lifetime = NumberRange.new(0.8, 0.8), Speed = NumberRange.new(0, 0), LockedToPart = true,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top,
			Size = NumberSequence.new({ kp(0, 2 * s), kp(1, 4 * s) }),
			Transparency = NumberSequence.new({ kp(0, 0.5), kp(1, 1) }),
			Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-300, 300),
		})
	end
	-- 6 : onde qui pulse au sol.
	if rank >= 6 then
		emitter(att, "TraitPulse", {
			Texture = WAVE, Color = ColorSequence.new(light, color), LightEmission = 1,
			Rate = 0.7, Lifetime = NumberRange.new(1.3, 1.3), Speed = NumberRange.new(0, 0), LockedToPart = true,
			Orientation = Enum.ParticleOrientation.VelocityPerpendicular, EmissionDirection = Enum.NormalId.Top,
			Size = NumberSequence.new({ kp(0, 0.5 * s), kp(1, 7 * s) }),
			Transparency = NumberSequence.new({ kp(0, 0.2), kp(1, 1) }),
		})
	end
	-- 7 : faisceau vers le ciel.
	if rank >= 7 then
		local top = Instance.new("Attachment")
		top.Name = FX_NAME .. "Top"
		top.Position = Vector3.new(0, 30, 0)
		top.Parent = att
		local beam = Instance.new("Beam")
		beam.Attachment0 = att
		beam.Attachment1 = top
		beam.Width0 = 2.5 * s
		beam.Width1 = 0.5 * s
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(light, color)
		beam.Transparency = NumberSequence.new({ kp(0, 0.35), kp(1, 1) })
		beam.Parent = att
	end
	att:SetAttribute("TraitKey", trait.key)
end

local tracked = setmetatable({}, { __mode = "k" }) -- BasePart -> true

local function refresh(part: BasePart)
	local trait = TraitShared.Get(part:GetAttribute("Trait"))
	local att = part:FindFirstChild(FX_NAME)
	if not trait then
		if att then
			att:Destroy()
		end
		return
	end
	if att and att:GetAttribute("TraitKey") == trait.key then
		return
	end
	build(part, trait)
end

local function watch(inst: Instance)
	if not inst:IsA("BasePart") or tracked[inst] then
		return
	end
	if inst:GetAttribute("Trait") == nil and inst:GetAttribute("IncomePerSecond") == nil then
		return
	end
	tracked[inst] = true
	refresh(inst)
	inst:GetAttributeChangedSignal("Trait"):Connect(function()
		refresh(inst)
	end)
end

for _, d in ipairs(workspace:GetDescendants()) do
	watch(d)
end
workspace.DescendantAdded:Connect(watch)

-- Economie : on coupe les effets des brainrots loin du joueur.
task.spawn(function()
	while true do
		task.wait(1)
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			for part in pairs(tracked) do
				local att = part.Parent and part:FindFirstChild(FX_NAME)
				if att then
					local on = (part.Position - root.Position).Magnitude < MAX_DISTANCE
					for _, c in ipairs(att:GetChildren()) do
						if c:IsA("ParticleEmitter") or c:IsA("Beam") or c:IsA("PointLight") then
							c.Enabled = on
						end
					end
				end
			end
		end
	end
end)
