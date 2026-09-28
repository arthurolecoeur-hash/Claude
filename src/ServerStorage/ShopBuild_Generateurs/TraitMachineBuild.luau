--[[
	TraitMachineBuild
	-----------------
	Reconstruit Workspace.TraitMachine facon "slot machine" doree (image de
	reference) : socle lumineux jaune, pied noir, caisse doree a picots,
	ecran a 4 rouleaux, tableau de boutons, levier rouge sur le cote,
	marquee lumineuse "TRAITS", tableau ODDS et panneau INFO.

	Garde la position de l'ancienne machine et son ProximityPrompt.
	Noms lus par TraitMachineClient : OddsBoard.Odds, Screen.Reels.ReelN,
	Lever (attribut PivotCF), LeverBall, Bulb, InfoSign (TraitInfoPrompt).
]]

local G = script.Parent
local L = require(G.ShopBuildLib)
local C = L.C
local V = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad

local M = {}

local function findOrigin(old: Model?): CFrame
	if old then
		local saved = old:GetAttribute("BuildOrigin")
		if typeof(saved) == "CFrame" then
			return saved
		end
		local ped = old:FindFirstChild("Pedestal")
		if ped and ped:IsA("BasePart") then
			return CF(ped.Position - V(0, ped.Size.Y / 2 + 0.25, 0)) * ped.CFrame.Rotation
		end
		return CF(old:GetPivot().Position)
	end
	return CF(734, 0.5, 811.5)
end

function M.build(): Model
	local old = workspace:FindFirstChild("TraitMachine")
	local O = findOrigin(old :: Model?)
	-- "Devant" de la machine = +Z local.
	local function at(x, y, z)
		return O * CF(x, y, z)
	end

	local prompt = old and old:FindFirstChild("TraitMachinePrompt", true)
	if prompt then
		prompt.Parent = nil
	end

	local m = Instance.new("Model")
	m.Name = "TraitMachine"
	m:SetAttribute("BuildOrigin", O)

	--== Socle lumineux ==--
	L.part(m, "PadFrame", V(18, 0.4, 18), at(0, 0.2, 0), C.goldD)
	local glow = L.part(m, "PadGlow", V(16, 0.44, 16), at(0, 0.22, 0), C.yellow, L.glow({ Transparency = 0.3 }))
	local padLight = Instance.new("PointLight")
	padLight.Color = C.yellow
	padLight.Range = 16
	padLight.Brightness = 1.2
	padLight.Parent = glow
	L.sparkles(glow, C.yellow, 5, {
		Shape = Enum.ParticleEmitterShape.Box, EmissionDirection = Enum.NormalId.Top,
		Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(10, 10), Lifetime = NumberRange.new(1.5, 2.5),
	})
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		L.part(m, "PadCorner", V(1.4, 0.9, 1.4), at(s[1] * 8.3, 0.45, s[2] * 8.3), C.gold)
	end

	--== Pied ==--
	L.part(m, "Pedestal", V(11, 1.6, 7.6), at(0, 1.2, 0), C.black)
	L.part(m, "PedestalTrim", V(11.3, 0.3, 7.9), at(0, 2.05, 0), C.goldD)

	--== Caisse ==--
	local body = L.part(m, "Body", V(8.4, 7.2, 5.2), at(0, 5.8, 0), C.gold)
	for _, x in ipairs({ -4.3, 4.3 }) do
		L.part(m, "SidePanel", V(0.4, 7.4, 5.4), at(x, 5.8, 0), C.goldD)
	end
	L.part(m, "BackPanel", V(8.2, 7, 0.3), at(0, 5.8, -2.7), C.goldD)
	L.part(m, "CapTrim", V(9.2, 0.4, 6), at(0, 9.5, 0), C.goldL)
	L.part(m, "Cap", V(9, 1.4, 5.8), at(0, 10.4, 0), C.goldD)
	L.part(m, "CapTop", V(8.6, 0.3, 5.4), at(0, 11.2, 0), C.gold)

	-- Marquee "TRAITS" avec ampoules.
	local sign = L.part(m, "TopSign", V(7.6, 1.1, 0.3), at(0, 10.4, 3.05), C.black, L.smooth())
	local ssg = L.surface(sign, Enum.NormalId.Front, "SurfaceGui", 50)
	local sl = L.label(ssg, "⭐ TRAITS ⭐", C.goldL)
	local sg = Instance.new("UIGradient")
	sg.Color = ColorSequence.new(C.goldL, C.gold)
	sg.Rotation = 90
	sg.Parent = sl
	for i = 0, 11 do
		local x = -3.6 + i * (7.2 / 11)
		L.ball(m, "Bulb", 0.36, at(x, 11.05, 3.1), i % 2 == 0 and C.yellow or C.red, L.glow())
		L.ball(m, "Bulb", 0.36, at(x, 9.75, 3.1), i % 2 == 0 and C.red or C.yellow, L.glow())
	end

	--== Ecran a rouleaux ==--
	L.part(m, "ScreenFrame", V(7.6, 4, 0.4), at(0, 7.2, 2.75), C.black, L.smooth())
	L.part(m, "ScreenBezel", V(7.9, 0.3, 0.5), at(0, 9.25, 2.75), C.goldL)
	L.part(m, "ScreenBezel", V(7.9, 0.3, 0.5), at(0, 5.15, 2.75), C.goldL)
	local screen = L.part(m, "Screen", V(7, 3.4, 0.2), at(0, 7.2, 3.0), C.cream, L.smooth())
	local rsg = L.surface(screen, Enum.NormalId.Front, "Reels", 60)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 10)
	pad.Parent = rsg
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 10)
	layout.Parent = rsg
	for i = 1, 4 do
		local r = Instance.new("Frame")
		r.Name = "Reel" .. i
		r.LayoutOrder = i
		r.Size = UDim2.new(0.25, -10, 1, 0)
		r.BackgroundColor3 = Color3.new(1, 1, 1)
		r.ClipsDescendants = true
		r.Parent = rsg
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 14)
		c.Parent = r
		local st = Instance.new("UIStroke")
		st.Thickness = 5
		st.Color = Color3.new(0, 0, 0)
		st.Parent = r
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(190, 185, 175)),
			ColorSequenceKeypoint.new(0.3, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.7, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 185, 175)),
		})
		g.Parent = r
		local sym = Instance.new("TextLabel")
		sym.Name = "Symbol"
		sym.BackgroundTransparency = 1
		sym.Size = UDim2.fromScale(1, 1)
		sym.TextScaled = true
		sym.Text = ({ "🍃", "⚡", "🔥", "⭐" })[i]
		sym.Parent = r
	end
	L.part(m, "Glass", V(7, 3.4, 0.05), at(0, 7.2, 3.13), C.white, L.smooth({ Transparency = 0.85, Reflectance = 0.3, CastShadow = false, CanCollide = false }))

	--== Tableau de boutons ==--
	local panelCF = at(0, 4.55, 3.2) * ANG(rad(-28), 0, 0)
	L.part(m, "ControlPanel", V(7.6, 1.2, 2), panelCF, C.goldD)
	for i, x in ipairs({ -2.7, -1.3, 0.1 }) do
		L.part(m, "Button" .. i, V(1.1, 0.3, 0.9), panelCF * CF(x, 0.7, 0), C.goldDD)
	end
	L.cyl(m, "BigButton", 0.35, 1.1, panelCF * CF(1.65, 0.72, 0), C.goldDD)
	L.ball(m, "RedLight", 0.55, panelCF * CF(3, 0.85, -0.2), C.red, L.glow())
	L.part(m, "Knob", V(0.3, 0.8, 0.3), panelCF * CF(3, 0.5, -0.2), C.redD)

	-- Fente a pieces + bac.
	L.part(m, "Slot", V(2.6, 0.5, 0.2), at(0, 3.3, 2.65), C.black, L.smooth())
	L.part(m, "Tray", V(3.6, 0.3, 1.2), at(0, 2.45, 3.1), C.goldDD)
	L.part(m, "TrayLip", V(3.6, 0.6, 0.25), at(0, 2.7, 3.6), C.goldD)

	--== Levier ==--
	L.part(m, "LeverBase", V(1, 1.8, 1.8), at(4.8, 6.2, 0), C.goldD)
	L.cyl(m, "LeverHub", 1.2, 1.1, at(5.3, 6.2, 0) * ANG(0, 0, rad(90)), C.gold)
	local lever = L.cyl(m, "Lever", 3.6, 0.36, at(5.55, 8, 0), C.white, { Material = Enum.Material.Metal, MaterialVariant = "", Color = Color3.fromRGB(200, 200, 210) })
	lever:SetAttribute("PivotCF", at(5.55, 6.2, 0))
	L.ball(m, "LeverBall", 1.25, at(5.55, 10.2, 0), C.red, L.smooth({ Reflectance = 0.1 }))

	--== Tableau ODDS ==--
	local oddsCF = at(9.6, 0, 0.5) * ANG(0, rad(-18), 0)
	L.part(m, "OddsPost", V(0.6, 4.4, 0.6), oddsCF * CF(0, 2.2, -0.2), C.black)
	L.part(m, "OddsFrame", V(6, 8, 0.4), oddsCF * CF(0, 8.1, -0.25), C.goldD)
	local odds = L.part(m, "OddsBoard", V(5.6, 7.6, 0.4), oddsCF * CF(0, 8.1, 0), C.black, L.smooth())
	L.surface(odds, Enum.NormalId.Front, "Odds", 60)

	--== Panneau INFO ==--
	local infoCF = at(-9.2, 0, 2.5) * ANG(0, rad(22), 0)
	local info = L.model(m, "InfoSign")
	L.part(info, "LegL", V(0.35, 5.2, 0.35), infoCF * CF(-1.5, 2.5, -0.3) * ANG(rad(-8), 0, 0), C.woodD)
	L.part(info, "LegR", V(0.35, 5.2, 0.35), infoCF * CF(1.5, 2.5, -0.3) * ANG(rad(-8), 0, 0), C.woodD)
	L.part(info, "LegBack", V(0.35, 5.2, 0.35), infoCF * CF(0, 2.4, -1.2) * ANG(rad(18), 0, 0), C.woodD)
	L.part(info, "Frame", V(4.4, 4.8, 0.35), infoCF * CF(0, 4.4, 0) * ANG(rad(-8), 0, 0), C.goldD)
	local board = L.part(info, "Board", V(3.9, 4.3, 0.2), infoCF * CF(0, 4.4, 0.12) * ANG(rad(-8), 0, 0), C.cream, L.smooth())
	local isg = L.surface(board, Enum.NormalId.Front, "Info", 60)
	L.label(isg, "INFO", C.gold, { Size = UDim2.new(1, 0, 0.3, 0), Position = UDim2.fromScale(0, 0.04) })
	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.64)
	circle.Size = UDim2.fromScale(0.62, 0.56)
	circle.BackgroundColor3 = C.blue
	circle.Parent = isg
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(1, 0)
	cc.Parent = circle
	local cs = Instance.new("UIStroke")
	cs.Thickness = 6
	cs.Parent = circle
	local cg = Instance.new("UIGradient")
	cg.Rotation = 90
	cg.Color = ColorSequence.new(Color3.fromRGB(110, 190, 255), C.blueD)
	cg.Parent = circle
	L.label(circle, "i", Color3.new(1, 1, 1), { Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.12) })
	local infoAtt = Instance.new("Attachment")
	infoAtt.Name = "PromptAttachment"
	infoAtt.Position = V(0, -1.5, 0.6)
	infoAtt.Parent = board
	local infoPrompt = Instance.new("ProximityPrompt")
	infoPrompt.Name = "TraitInfoPrompt"
	infoPrompt.ActionText = "How it works"
	infoPrompt.ObjectText = "Trait Machine"
	infoPrompt.HoldDuration = 0
	infoPrompt.MaxActivationDistance = 10
	infoPrompt.RequiresLineOfSight = false
	infoPrompt.KeyboardKeyCode = Enum.KeyCode.F
	infoPrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
	infoPrompt.Parent = infoAtt

	--== Titre flottant, lumiere, prompt ==--
	local titleAtt = Instance.new("Attachment")
	titleAtt.Name = "TitleAttachment"
	titleAtt.Position = V(0, 8.4, 0)
	titleAtt.Parent = body
	local bb = Instance.new("BillboardGui")
	bb.Name = "Title"
	bb.Adornee = titleAtt
	bb.Size = UDim2.fromScale(14, 3.4)
	bb.LightInfluence = 0
	bb.MaxDistance = 180
	bb.Parent = body
	local tl = L.label(bb, "TRAITS", C.yellow)
	tl:FindFirstChildOfClass("UIStroke").Thickness = 5
	local tg = Instance.new("UIGradient")
	tg.Rotation = 90
	tg.Color = ColorSequence.new(Color3.fromRGB(255, 250, 150), Color3.fromRGB(255, 200, 0))
	tg.Parent = tl

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 110)
	light.Range = 18
	light.Brightness = 1.6
	light.Parent = body

	local att = Instance.new("Attachment")
	att.Name = "PromptAttachment"
	att.Position = V(0, -2.2, 3.4)
	att.Parent = body
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TraitMachinePrompt"
	end
	prompt.ActionText = "Roll Traits"
	prompt.ObjectText = "Trait Machine"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = att

	m.PrimaryPart = body
	if old then
		old:Destroy()
	end
	m.Parent = workspace
	return m
end

function M.run(): string
	local m = M.build()
	return ("TraitMachine reconstruite (%d parts)"):format(L.count(m))
end

return M
