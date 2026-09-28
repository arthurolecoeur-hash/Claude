--[[
	ShopPodiumsClient
	-----------------
	Podiums du spawn (Workspace.ShopPodiums) :
	  - W Or L / 1x1x1x1 : panneau LIMITED / nom / prix Robux / revenu (calcule
	    sur TON meilleur brainrot) / "X LEFT" (stock global). [E] Buy.
	  - Strawberry Lucky Block : clic ou [E] -> ouvre le shop sur le Lucky Block.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local Shop = ReplicatedStorage:WaitForChild("Shop")
local ShopConfig = require(Shop:WaitForChild("ShopConfig"))
local NumberFormat = require(ReplicatedStorage:WaitForChild("NumberFormat"))
local UISounds = require(ReplicatedStorage:WaitForChild("UISounds"))
local openShopRequest = Shop:WaitForChild("OpenShopRequest")

local FONT_TITLE = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local ROBUX = utf8.char(0xE002)
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 50, 50)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 30)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(50, 255, 90)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(30, 180, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(190, 60, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 50)),
})

local animated = {}

local function line(bb: BillboardGui, name: string, order: number, height: number, str: string, color: Color3, font: Font?)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.LayoutOrder = order
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, height, 0)
	l.FontFace = font or FONT_TITLE
	l.Text = str
	l.TextScaled = true
	l.RichText = true
	l.TextColor3 = color
	l.Parent = bb
	local s = Instance.new("UIStroke")
	s.Thickness = 3.5
	s.Color = BLACK
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = l
	return l
end

-- Degrade haut clair -> bas plus sombre (style des panneaux de la ref).
local function shade(l: TextLabel, top: Color3, bottom: Color3)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(top, bottom)
	g.Parent = l
	return g
end

local function billboard(adornee: Instance, width: number, height: number)
	local bb = Instance.new("BillboardGui")
	bb.Name = "PodiumInfo"
	bb.Adornee = adornee
	bb.Size = UDim2.fromScale(width, height)
	bb.LightInfluence = 0
	bb.MaxDistance = 140
	bb.AlwaysOnTop = false
	bb.ResetOnSpawn = false
	bb.Parent = player:WaitForChild("PlayerGui")
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bb
	return bb
end

local function setupDirect(podium: Model, direct)
	local anchor = podium:WaitForChild("DisplayAnchor", 20)
	local att = anchor and anchor:WaitForChild("InfoAttachment", 10)
	if not att then
		return
	end
	local bb = billboard(att, 12, 10.5)
	local c = direct.color or WHITE
	local tier = line(bb, "Tier", 1, 0.13, direct.tier or "LIMITED", WHITE)
	shade(tier, c:Lerp(WHITE, 0.45), c)
	local rarity = line(bb, "Rarity", 2, 0.14, "EXCLUSIVE", WHITE)
	local g = Instance.new("UIGradient")
	g.Color = RAINBOW
	g.Parent = rarity
	table.insert(animated, g)
	local name = line(bb, "Name", 3, 0.17, direct.name, WHITE)
	shade(name, WHITE, Color3.fromRGB(215, 215, 225))
	local price = line(bb, "Price", 4, 0.12, ROBUX .. " " .. direct.price, Color3.fromRGB(205, 215, 205), FONT)
	local income = line(bb, "Income", 5, 0.14, "", Color3.fromRGB(150, 255, 60))
	shade(income, Color3.fromRGB(200, 255, 120), Color3.fromRGB(90, 220, 40))
	local left = line(bb, "Left", 6, 0.28, "", WHITE)
	shade(left, WHITE, Color3.fromRGB(215, 215, 225))
	table.insert(animated, { left = left, podium = podium })
	local pct = direct.percent or 100

	if direct.id ~= 0 then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(direct.id, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				price.Text = ROBUX .. " " .. info.PriceInRobux
			end
		end)
	end

	local function refreshIncome()
		local best = player:GetAttribute("BestIncome") or 0
		if best > 0 then
			income.Text = "💵 " .. NumberFormat.FormatPrice(math.max(1, math.floor(best * pct / 100 + 0.5))) .. "/s"
		else
			income.Text = ("💵 %d%% OF BEST"):format(pct)
		end
	end
	local function refreshStock()
		local n = ShopConfig.GetStockLeft(direct.key)
		if n == nil then
			left.Text = ""
		elseif n <= 0 then
			left.Text = "SOLD OUT"
			left.TextColor3 = Color3.fromRGB(255, 70, 70)
		else
			local prev = tonumber(left:GetAttribute("Shown"))
			left.Text = n .. " LEFT"
			left.TextColor3 = n <= 10 and Color3.fromRGB(255, 140, 90) or WHITE
			if prev and prev ~= n then
				left:SetAttribute("BumpAt", os.clock())
			end
			left:SetAttribute("Shown", n)
		end
		left:SetAttribute("Low", n ~= nil and n > 0 and n <= 10)
		local prompt = podium:FindFirstChild("PodiumBuyPrompt", true)
		if prompt then
			prompt.ActionText = (n ~= nil and n <= 0) and "Sold Out" or "Buy"
		end
	end
	player:GetAttributeChangedSignal("BestIncome"):Connect(refreshIncome)
	Shop:GetAttributeChangedSignal("StockLeft_" .. direct.key):Connect(refreshStock)
	refreshIncome()
	refreshStock()

	local function adjustHeight()
		local h = podium:GetAttribute("DisplayHeight")
		if type(h) == "number" then
			att.Position = Vector3.new(0, h + 4.2, 0)
		end
	end
	podium:GetAttributeChangedSignal("DisplayHeight"):Connect(adjustHeight)
	adjustHeight()
end

local function openLucky()
	UISounds.Play("Click")
	openShopRequest:Fire("Lucky")
end

local function setupStrawberry(podium: Model)
	local anchor = podium:WaitForChild("DisplayAnchor", 20)
	local att = anchor and anchor:WaitForChild("InfoAttachment", 10)
	if att then
		local bb = billboard(att, 13, 6.8)
		local t = line(bb, "Title", 1, 0.3, "STRAWBERRY", Color3.fromRGB(255, 90, 140))
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(Color3.fromRGB(255, 180, 210), Color3.fromRGB(255, 40, 110))
		g.Rotation = 90
		g.Parent = t
		line(bb, "Sub", 2, 0.26, "LUCKY BLOCK", WHITE)
		local from = ShopConfig.LUCKY_BLOCK.packs[1]
		line(bb, "Price", 3, 0.2, "FROM " .. ROBUX .. " " .. (from and from.price or 99), Color3.fromRGB(215, 225, 215), FONT)
		local click = line(bb, "Click", 4, 0.2, "👆 CLICK TO BUY", Color3.fromRGB(255, 225, 70))
		table.insert(animated, { pulse = click })
	end

	local block = podium:WaitForChild("LuckyBlockDisplay", 10)
	local orbit = {}
	local center = (anchor and anchor.Position or podium:GetPivot().Position)
	-- Fraises / etincelles qui tournent autour du bloc (comme les chiffres
	-- du Lucky Block "hacked" de la ref).
	for i = 1, 8 do
		local holder = Instance.new("Part")
		holder.Name = "OrbitFx"
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Parent = workspace.CurrentCamera
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(1.8, 1.8)
		bb.LightInfluence = 0
		bb.MaxDistance = 120
		bb.Parent = holder
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.TextScaled = true
		t.Text = i % 3 == 0 and "✨" or (i % 3 == 1 and "🍓" or "💖")
		t.Parent = bb
		table.insert(orbit, { part = holder, label = t, phase = i / 8 * math.pi * 2, radius = 4.2 + (i % 2) * 1.2, height = 2 + (i % 4) * 1.3 })
	end
	local beam = podium:FindFirstChild("LightBeam", true)
	local base = block and block:GetPivot()
	local t0 = os.clock()
	RunService.RenderStepped:Connect(function()
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local far = root and (root.Position - center).Magnitude > 160
		for _, o in ipairs(orbit) do
			o.label.Visible = not far
		end
		if far then
			return
		end
		local t = os.clock() - t0
		if block and base then
			block:PivotTo(base * CFrame.new(0, math.sin(t * 2) * 0.6 + 0.6, 0) * CFrame.Angles(0, t * 0.8, math.sin(t * 1.3) * 0.06))
		end
		for _, o in ipairs(orbit) do
			local a = o.phase + t * 0.9
			o.part.CFrame = CFrame.new(center + Vector3.new(math.cos(a) * o.radius, o.height + math.sin(t * 2 + o.phase) * 0.6, math.sin(a) * o.radius))
			o.label.TextTransparency = 0.1 + (math.sin(t * 3 + o.phase) + 1) * 0.2
			o.label.Rotation = math.sin(t * 2 + o.phase) * 15
		end
		if beam and beam:IsA("Beam") then
			local k = 0.3 + (math.sin(t * 2.2) + 1) * 0.08
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, k),
				NumberSequenceKeypoint.new(0.6, 0.75),
				NumberSequenceKeypoint.new(1, 1),
			})
			beam.Width0 = 7 + math.sin(t * 1.7) * 0.6
		end
	end)

	for _, cd in ipairs(podium:GetDescendants()) do
		if cd:IsA("ClickDetector") then
			cd.MouseClick:Connect(function(who)
				if who == player then
					openLucky()
				end
			end)
		end
	end
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "PodiumShopPrompt" then
		openLucky()
	elseif prompt.Name == "PodiumBuyPrompt" then
		UISounds.Play("Click")
	end
end)

task.spawn(function()
	local folder = workspace:WaitForChild("ShopPodiums", 60)
	if not folder then
		return
	end
	for _, podium in ipairs(folder:GetChildren()) do
		local key = podium:GetAttribute("DirectKey")
		local direct = key and ShopConfig.GetDirect(key)
		if direct then
			task.spawn(setupDirect, podium, direct)
		elseif podium:GetAttribute("ShopSection") then
			task.spawn(setupStrawberry, podium)
		end
	end
end)

local clock = 0
RunService.RenderStepped:Connect(function(dt)
	clock += dt
	for _, a in ipairs(animated) do
		if typeof(a) == "Instance" then
			a.Offset = Vector2.new(math.sin(clock * 1.4) * 0.5, 0)
		elseif a.pulse then
			a.pulse.TextTransparency = 0.15 + math.abs(math.sin(clock * 3)) * 0.3
		elseif a.left then
			local sc = a.left:FindFirstChild("Pulse") or Instance.new("UIScale")
			sc.Name = "Pulse"
			sc.Parent = a.left
			local bump = math.max(0, 1 - (os.clock() - (tonumber(a.left:GetAttribute("BumpAt")) or 0)) / 0.5)
			sc.Scale = (a.left:GetAttribute("Low") and 1 + math.abs(math.sin(clock * 4)) * 0.08 or 1) + bump * 0.35
		end
	end
end)
