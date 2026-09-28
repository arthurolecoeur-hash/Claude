--[[
	BrainrotSpawnFxClient
	---------------------
	LocalScript dans StarterPlayerScripts.Brainrots.

	VFX des brainrots au sol (Workspace.SpawnedBrainrots), en local :

	  - APPARITION : cercle qui se charge au sol, rayon qui tombe du ciel,
	    flash de lumiere, le brainrot jaillit en tournant puis retombe avec
	    un rebond. Intensite selon la rarete ; etoiles colorees en plus pour
	    une mutation (Gold, Diamond, Ruby, Lava, Hacker, Rainbow).
	  - DISPARITION (fin du decompte) : s'eleve en tournant et s'efface.
	  - RETRAIT (pris) : bouffee + etincelles.
	  - DECOMPTE : le texte "45s" est mis a jour ICI a partir de l'attribut
	    ExpiresAt (plus aucune replication reseau pour le timer).

	Perf : aucun effet joue au-dela de FX_MAX_DIST de la camera, et le
	decompte n'est rafraichi que pour les brainrots proches.

	Pas de mise a l'echelle : sur une MeshPart skinnee, changer Size
	deforme le maillage. On joue sur la position et
	LocalTransparencyModifier, qui ne touchent pas au serveur.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local InventoryShared = require(ReplicatedStorage:WaitForChild("Inventory"):WaitForChild("InventoryShared"))

local spawnFolder = Workspace:WaitForChild("SpawnedBrainrots")

local SPARKLE_TEX = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local WHITE = Color3.new(1, 1, 1)

local FX_MAX_DIST = 220
local TIMER_MAX_DIST = 90
local TIMER_TICK = 0.25
-- ExpiresAt restant au-dessus de ca = brainrot tout juste apparu.
local FRESH_THRESHOLD = 42

local MUTATION_COLORS = {
	Gold = ColorSequence.new(Color3.fromRGB(255, 215, 60), Color3.fromRGB(255, 170, 0)),
	Diamond = ColorSequence.new(Color3.fromRGB(180, 245, 255), Color3.fromRGB(80, 200, 255)),
	Ruby = ColorSequence.new(Color3.fromRGB(255, 90, 110), Color3.fromRGB(200, 0, 40)),
	Lava = ColorSequence.new(Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 60, 0)),
	Galaxy = ColorSequence.new(Color3.fromRGB(230, 180, 255), Color3.fromRGB(110, 40, 255)),
	Hacker = ColorSequence.new(Color3.fromRGB(120, 255, 120), Color3.fromRGB(0, 180, 40)),
	Admin = ColorSequence.new(Color3.fromRGB(255, 215, 90), Color3.fromRGB(255, 30, 45)),
	Rainbow = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 180, 40)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 60)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 255, 100)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(60, 150, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 80, 255)),
	}),
}

local fxFolder = Instance.new("Folder")
fxFolder.Name = "BrainrotFxLocal"
fxFolder.Parent = Workspace

local function rarityInfo(part: BasePart)
	local key = part:GetAttribute("Rarity") or "Commun"
	local info = InventoryShared.RARITY[key]
	local c = info and info.color or WHITE
	-- Le gris du Commun est terne en Neon : on le remplace par un cyan vif.
	if key == "Commun" then
		c = Color3.fromRGB(120, 230, 255)
	end
	return c, (info and info.order) or 1
end

local function isNear(pos: Vector3, maxDist: number): boolean
	local cam = Workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - pos).Magnitude <= maxDist
end

local function tween(inst: Instance, t: number, props, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function fxPart(): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Parent = fxFolder
	return p
end

-- Onde plate qui s'etale au sol.
local function ring(groundPos: Vector3, color: Color3, from: number, to: number, t: number, transp: number?)
	local p = fxPart()
	p.Shape = Enum.PartType.Cylinder
	p.Color = color
	p.Transparency = transp or 0.15
	p.Size = Vector3.new(0.15, from, from)
	p.CFrame = CFrame.new(groundPos + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	tween(p, t, { Size = Vector3.new(0.15, to, to), Transparency = 1 })
	Debris:AddItem(p, t + 0.1)
end

-- Disque qui se "charge" au sol avant l'apparition.
local function chargeDisc(groundPos: Vector3, color: Color3, size: number, t: number)
	local p = fxPart()
	p.Shape = Enum.PartType.Cylinder
	p.Color = color
	p.Transparency = 0.6
	p.Size = Vector3.new(0.1, 0.5, 0.5)
	p.CFrame = CFrame.new(groundPos + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90))
	tween(p, t, { Size = Vector3.new(0.1, size, size), Transparency = 0.2 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(t, function()
		tween(p, 0.4, { Transparency = 1 })
	end)
	Debris:AddItem(p, t + 0.5)
end

-- Rayon qui tombe du ciel et s'ecrase au sol.
local function skyBeam(groundPos: Vector3, color: Color3, width: number, t: number)
	local height = 60
	local p = fxPart()
	p.Shape = Enum.PartType.Cylinder
	p.Color = color
	p.Transparency = 0.25
	p.Size = Vector3.new(height, width, width)
	p.CFrame = CFrame.new(groundPos + Vector3.new(0, height * 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	tween(p, t, { CFrame = CFrame.new(groundPos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(t, function()
		tween(p, 0.45, { Size = Vector3.new(height, 0.05, 0.05), Transparency = 1 })
	end)
	Debris:AddItem(p, t + 0.6)
end

-- Flash de lumiere ponctuel.
local function flash(pos: Vector3, color: Color3, brightness: number, range: number, t: number)
	local holder = fxPart()
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.CFrame = CFrame.new(pos)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = holder
	tween(light, t, { Brightness = 0 })
	Debris:AddItem(holder, t + 0.1)
end

-- Emetteur de particules ponctuel (Emit une fois puis nettoye).
local function burst(pos: Vector3, props, count: number)
	local holder = fxPart()
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.CFrame = CFrame.new(pos)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.LightEmission = props.LightEmission or 1
	emitter.Texture = props.Texture
	emitter.Color = props.Color
	emitter.Size = props.Size
	emitter.Transparency = props.Transparency or NumberSequence.new(0, 1)
	emitter.Lifetime = props.Lifetime
	emitter.Speed = props.Speed
	emitter.SpreadAngle = props.Spread or Vector2.new(180, 180)
	emitter.Drag = props.Drag or 3
	emitter.Acceleration = props.Acceleration or Vector3.zero
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-120, 120)
	emitter.Parent = holder
	emitter:Emit(count)
	Debris:AddItem(holder, props.Lifetime.Max + 0.2)
end

local function sparkles(pos: Vector3, color: Color3, count: number)
	burst(pos, {
		Texture = SPARKLE_TEX,
		Color = ColorSequence.new(WHITE, color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(10, 20),
		Drag = 4,
		Acceleration = Vector3.new(0, 4, 0),
	}, count)
end

local function stars(pos: Vector3, colors: ColorSequence, count: number)
	burst(pos, {
		Texture = SPARKLE_TEX,
		Color = colors,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.7, 0.7), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.8, 1.3),
		Speed = NumberRange.new(12, 22),
		Drag = 3,
		Acceleration = Vector3.new(0, -6, 0),
		Spread = Vector2.new(60, 60),
	}, count)
end

local function smoke(pos: Vector3, color: Color3, count: number)
	burst(pos, {
		Texture = SMOKE_TEX,
		LightEmission = 0.2,
		Color = ColorSequence.new(WHITE, color),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(4, 8),
		Drag = 5,
		Acceleration = Vector3.new(0, 3, 0),
	}, count)
end

local function setBillboardEnabled(part: BasePart, enabled: boolean)
	local gui = part:FindFirstChild("InfoDisplay")
	if gui and gui:IsA("BillboardGui") then
		gui.Enabled = enabled
	end
end

-- Petit "pop" du panneau quand il apparait.
local function popBillboard(part: BasePart)
	local gui = part:FindFirstChild("InfoDisplay")
	if not (gui and gui:IsA("BillboardGui")) then
		return
	end
	local finalSize = gui.Size
	gui.Size = UDim2.new(finalSize.X.Scale * 0.2, 0, finalSize.Y.Scale * 0.2, 0)
	gui.Enabled = true
	tween(gui, 0.3, { Size = finalSize }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

--== Etat par brainrot ==--
local lastCFrame = setmetatable({}, { __mode = "k" })
local despawned = setmetatable({}, { __mode = "k" })
local tracked = {} -- [part] = true, pour le decompte

local function playDespawn(part: BasePart)
	if despawned[part] then
		return
	end
	despawned[part] = true
	local cf = lastCFrame[part] or part.CFrame
	setBillboardEnabled(part, false)
	if not isNear(cf.Position, FX_MAX_DIST) then
		part.LocalTransparencyModifier = 1
		return
	end

	local color = rarityInfo(part)
	local groundPos = cf.Position - Vector3.new(0, part.Size.Y / 2, 0)
	ring(groundPos, color, 2, 10, 0.5)
	smoke(groundPos + Vector3.new(0, 0.5, 0), color, 10)

	tween(part, 0.5, {
		CFrame = cf * CFrame.new(0, part.Size.Y * 0.6, 0) * CFrame.Angles(0, math.rad(160), 0),
		LocalTransparencyModifier = 1,
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

local function playRemoved(part: BasePart)
	local cf = lastCFrame[part] or part.CFrame
	local center = cf.Position
	if not isNear(center, FX_MAX_DIST) then
		return
	end
	local color = rarityInfo(part)
	if despawned[part] then
		sparkles(center + Vector3.new(0, part.Size.Y * 0.6, 0), color, 18)
	else
		local groundPos = center - Vector3.new(0, part.Size.Y / 2, 0)
		smoke(center, color, 12)
		sparkles(center, color, 25)
		ring(groundPos, color, 2, 9, 0.4)
		flash(center, color, 4, 14, 0.3)
	end
end

local CHARGE = 0.35

local function playSpawn(part: BasePart)
	local finalCF = part.CFrame
	lastCFrame[part] = finalCF
	if not isNear(finalCF.Position, FX_MAX_DIST) then
		return
	end

	local color, tier = rarityInfo(part)
	local mutation = part:GetAttribute("Mutation")
	local groundPos = finalCF.Position - Vector3.new(0, part.Size.Y / 2, 0)
	local footprint = math.max(part.Size.X, part.Size.Z)

	-- Cache pendant la charge.
	setBillboardEnabled(part, false)
	part.LocalTransparencyModifier = 1
	part.CFrame = finalCF * CFrame.new(0, -part.Size.Y * 0.9, 0)

	-- 1) Charge au sol + rayon du ciel.
	chargeDisc(groundPos, color, footprint * 1.6, CHARGE)
	skyBeam(groundPos, color, footprint * 0.7, CHARGE)

	task.delay(CHARGE, function()
		if not part.Parent or despawned[part] then
			return
		end

		-- 2) Impact : flash, ondes, etincelles (plus fort selon la rarete).
		flash(groundPos + Vector3.new(0, 2, 0), color, 3 + tier * 1.5, 12 + tier * 4, 0.6)
		ring(groundPos, color, 1, 12 + tier * 2, 0.55)
		if tier >= 3 then
			task.delay(0.12, function()
				ring(groundPos, WHITE, 1, 8 + tier * 2, 0.5, 0.4)
			end)
		end
		sparkles(groundPos + Vector3.new(0, 1, 0), color, 20 + tier * 8)
		smoke(groundPos + Vector3.new(0, 0.5, 0), color, 4 + tier)
		if mutation and MUTATION_COLORS[mutation] then
			stars(groundPos + Vector3.new(0, 1.5, 0), MUTATION_COLORS[mutation], 25)
		end

		-- 3) Le brainrot jaillit en tournant, depasse sa hauteur puis
		-- retombe avec un rebond.
		local peak = finalCF * CFrame.new(0, math.max(2, part.Size.Y * 0.35), 0)
		part.CFrame = finalCF * CFrame.new(0, -part.Size.Y * 0.9, 0) * CFrame.Angles(0, math.rad(-270), 0)
		tween(part, 0.18, { LocalTransparencyModifier = 0 })
		local up = tween(part, 0.32, { CFrame = peak }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		up.Completed:Once(function()
			if not part.Parent or despawned[part] then
				return
			end
			local down = tween(part, 0.45, { CFrame = finalCF }, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out)
			task.delay(0.16, function()
				-- Atterrissage : petite onde de poussiere.
				if part.Parent then
					ring(groundPos, color, footprint * 0.6, footprint * 1.8, 0.35, 0.35)
				end
			end)
			down.Completed:Once(function()
				if part.Parent and not despawned[part] then
					popBillboard(part)
				end
			end)
		end)
	end)
end

local function watch(part: Instance, animate: boolean)
	if not part:IsA("BasePart") then
		return
	end
	lastCFrame[part] = part.CFrame
	tracked[part] = true
	if animate then
		playSpawn(part)
	end
	if part:GetAttribute("Despawning") then
		playDespawn(part)
	end
	part:GetAttributeChangedSignal("Despawning"):Connect(function()
		if part:GetAttribute("Despawning") then
			playDespawn(part)
		end
	end)
end

-- Les brainrots deja presents a l'arrivee du joueur ne rejouent pas
-- l'apparition.
for _, child in ipairs(spawnFolder:GetChildren()) do
	watch(child, false)
end
spawnFolder.ChildAdded:Connect(function(child)
	-- Avec le StreamingEnabled, un brainrot deja pose "arrive" aussi quand
	-- on s'approche : on n'anime que ceux qui viennent vraiment d'apparaitre.
	local expires = child:GetAttribute("ExpiresAt")
	local fresh = expires == nil or (expires - Workspace:GetServerTimeNow()) > FRESH_THRESHOLD
	watch(child, fresh)
end)
spawnFolder.ChildRemoved:Connect(function(child)
	tracked[child] = nil
	if child:IsA("BasePart") then
		playRemoved(child)
	end
end)

--== Decompte local ==--
task.spawn(function()
	while true do
		task.wait(TIMER_TICK)
		local cam = Workspace.CurrentCamera
		local camPos = cam and cam.CFrame.Position
		local now = Workspace:GetServerTimeNow()
		for part in pairs(tracked) do
			local expires = part:GetAttribute("ExpiresAt")
			if expires and camPos and (part.Position - camPos).Magnitude <= TIMER_MAX_DIST then
				local gui = part:FindFirstChild("InfoDisplay")
				local label = gui and gui:FindFirstChild("TimerLabel")
				if label then
					local remaining = math.max(0, math.ceil(expires - now))
					local text = remaining .. "s"
					if label.Text ~= text then
						label.Text = text
					end
				end
			end
		end
	end
end)
