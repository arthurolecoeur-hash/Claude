--[[
	PodiumBuild
	-----------
	Refait le decor des podiums du spawn (Workspace.ShopPodiums) :

	  - Podium_Strawberry : socle rond orange a double anneau blanc/rouge,
	    disque lumineux rose, faisceau de lumiere venu du ciel, etincelles
	    (style image 1). Les effets animes (orbite, bob) sont dans
	    ShopPodiumsClient.
	  - Podium_WOrL / Podium_1x1x1x1 : dalle sombre basse a liseré blanc,
	    halo de la couleur du brainrot sous le modele (style image 4).

	Ne touche pas : DisplayAnchor (prompts, attachments, lumiere),
	LuckyBlockDisplay, attributs du Model (DirectKey / ShopSection).
	Relancable : le decor precedent (dossier "Decor") est remplace.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local G = script.Parent
local L = require(G.ShopBuildLib)
local C = L.C
local V = Vector3.new
local CF = CFrame.new

local M = {}

local OLD_PARTS = { "Base", "RingOuter", "RingRed", "Edge1", "Edge2", "Edge3", "Edge4", "Top" }

local function reset(podium: Model): (Folder, CFrame)
	local anchor = podium:FindFirstChild("DisplayAnchor") :: BasePart
	local center = podium:GetAttribute("BuildCenter")
	if typeof(center) ~= "CFrame" then
		local base = podium:FindFirstChild("Base")
		local p = anchor and anchor.Position or podium:GetPivot().Position
		if base and base:IsA("BasePart") then
			p = V(base.Position.X, base.Position.Y - (base.Shape == Enum.PartType.Cylinder and base.Size.X or base.Size.Y) / 2, base.Position.Z)
		end
		center = CF(p)
		podium:SetAttribute("BuildCenter", center)
	end
	for _, n in ipairs(OLD_PARTS) do
		local p = podium:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			p:Destroy()
		end
	end
	local old = podium:FindFirstChild("Decor")
	if old then
		old:Destroy()
	end
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = podium
	return decor, center
end

local function beam(decor: Instance, bottom: CFrame, height: number, color: Color3, w0: number, w1: number)
	local holder = L.part(decor, "BeamHolder", V(1, 1, 1), bottom, C.white, { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
	local a0 = Instance.new("Attachment")
	a0.Name = "BeamBottom"
	a0.Parent = holder
	local a1 = Instance.new("Attachment")
	a1.Name = "BeamTop"
	a1.Position = V(0, height, 0)
	a1.Parent = holder
	local b = Instance.new("Beam")
	b.Name = "LightBeam"
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Width0 = w0
	b.Width1 = w1
	b.FaceCamera = true
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Segments = 1
	b.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color)
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35),
		NumberSequenceKeypoint.new(0.6, 0.75),
		NumberSequenceKeypoint.new(1, 1),
	})
	b.Parent = holder
	return holder
end

function M.strawberry(podium: Model)
	local decor, O = reset(podium)
	local function at(x, y, z)
		return O * CF(x, y, z)
	end
	L.cyl(decor, "RingRed", 0.7, 14, at(0, 0.35, 0), C.red, L.smooth())
	L.cyl(decor, "RingWhite", 0.8, 13, at(0, 0.4, 0), C.white, L.smooth())
	local base = L.cyl(decor, "Base", 0.9, 12, at(0, 0.45, 0), C.orange, L.smooth())
	base.CanCollide = true
	L.cyl(decor, "Inner", 0.92, 9.4, at(0, 0.46, 0), Color3.fromRGB(255, 70, 50), L.smooth())
	local disk = L.cyl(decor, "GlowDisk", 0.94, 7, at(0, 0.47, 0), C.pink, L.glow({ Transparency = 0.25 }))
	L.cyl(decor, "GlowCore", 0.96, 4, at(0, 0.48, 0), C.pinkL, L.glow({ Transparency = 0.1 }))
	L.sparkles(disk, C.pinkL, 10, {
		Shape = Enum.ParticleEmitterShape.Cylinder, EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(2, 5), Lifetime = NumberRange.new(1.2, 2.2), SpreadAngle = Vector2.new(8, 8),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) }),
	})
	-- Pastilles "lumieres de scene" sur l'anneau blanc.
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		L.ball(decor, "RimLight", 0.45, at(math.cos(a) * 6.5, 0.85, math.sin(a) * 6.5), i % 2 == 0 and C.pinkL or C.yellow, L.glow())
	end
	beam(decor, at(0, 0.9, 0), 38, C.pink, 7, 2.5)
	local light = Instance.new("SpotLight")
	light.Face = Enum.NormalId.Top
	light.Angle = 70
	light.Range = 14
	light.Brightness = 2
	light.Color = C.pinkL
	light.Parent = base
	podium:SetAttribute("PodiumStyle", "Strawberry")
end

function M.direct(podium: Model, color: Color3)
	local decor, O = reset(podium)
	local function at(x, y, z)
		return O * CF(x, y, z)
	end
	local slab = L.part(decor, "Base", V(12, 0.8, 12), at(0, 0.4, 0), Color3.fromRGB(58, 50, 66))
	slab.CanCollide = true
	L.part(decor, "TopPlate", V(11.2, 0.1, 11.2), at(0, 0.85, 0), Color3.fromRGB(44, 38, 52), L.smooth())
	local EDGE = Color3.fromRGB(250, 250, 255)
	L.part(decor, "Edge", V(12.3, 0.22, 0.35), at(0, 0.91, 5.98), EDGE, L.smooth())
	L.part(decor, "Edge", V(12.3, 0.22, 0.35), at(0, 0.91, -5.98), EDGE, L.smooth())
	L.part(decor, "Edge", V(0.35, 0.22, 12.3), at(5.98, 0.91, 0), EDGE, L.smooth())
	L.part(decor, "Edge", V(0.35, 0.22, 12.3), at(-5.98, 0.91, 0), EDGE, L.smooth())
	local halo = L.cyl(decor, "Halo", 0.06, 7.5, at(0, 0.93, 0), color, L.glow({ Transparency = 0.55 }))
	L.cyl(decor, "HaloCore", 0.07, 4.5, at(0, 0.94, 0), color:Lerp(Color3.new(1, 1, 1), 0.4), L.glow({ Transparency = 0.4 }))
	L.sparkles(halo, color, 6, {
		Shape = Enum.ParticleEmitterShape.Cylinder, EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(1.5, 3), Lifetime = NumberRange.new(1.5, 2.5), SpreadAngle = Vector2.new(5, 5),
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 1.5
	light.Parent = halo
	podium:SetAttribute("PodiumStyle", "Direct")
end

function M.run(): string
	local folder = workspace:FindFirstChild("ShopPodiums")
	if not folder then
		return "Workspace.ShopPodiums introuvable"
	end
	local ShopConfig = require(ReplicatedStorage.Shop.ShopConfig)
	local done = {}
	for _, podium in ipairs(folder:GetChildren()) do
		if podium:IsA("Model") then
			local key = podium:GetAttribute("DirectKey")
			local direct = key and ShopConfig.GetDirect(key)
			if direct then
				M.direct(podium, direct.color)
				table.insert(done, podium.Name)
			elseif podium:GetAttribute("ShopSection") or podium.Name == "Podium_Strawberry" then
				M.strawberry(podium)
				table.insert(done, podium.Name)
			end
		end
	end
	return "Podiums refaits : " .. table.concat(done, ", ")
end

return M
