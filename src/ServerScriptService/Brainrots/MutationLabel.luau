--[[
	MutationLabel
	-------------
	Ligne "Gold", "Diamond"... affichee au-dessus du niveau sur les
	panneaux des brainrots, avec la couleur de la mutation. Le nom affiche
	perd son prefixe ("Gold Lirili Larila" -> "Lirili Larila").
]]

local MutationLabel = {}

local function seq(a: Color3, b: Color3, c: Color3)
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, a),
		ColorSequenceKeypoint.new(0.5, b),
		ColorSequenceKeypoint.new(1, c),
	})
end

MutationLabel.STYLES = {
	Gold    = { base = Color3.fromRGB(255, 196, 0),  color = seq(Color3.fromRGB(255, 245, 150), Color3.fromRGB(255, 200, 0), Color3.fromRGB(215, 130, 0)), rotation = 90 },
	Diamond = { base = Color3.fromRGB(0, 190, 255),  color = seq(Color3.fromRGB(215, 250, 255), Color3.fromRGB(0, 200, 255), Color3.fromRGB(0, 110, 230)), rotation = 90 },
	Ruby    = { base = Color3.fromRGB(255, 20, 75),  color = seq(Color3.fromRGB(255, 130, 160), Color3.fromRGB(255, 25, 80), Color3.fromRGB(170, 0, 45)), rotation = 90 },
	Lava    = { base = Color3.fromRGB(255, 85, 0),   color = seq(Color3.fromRGB(255, 220, 0), Color3.fromRGB(255, 95, 0), Color3.fromRGB(170, 20, 0)), rotation = 90 },
	Galaxy  = { base = Color3.fromRGB(140, 70, 255), color = seq(Color3.fromRGB(235, 190, 255), Color3.fromRGB(150, 80, 255), Color3.fromRGB(40, 20, 140)), rotation = 90, stroke = Color3.fromRGB(20, 8, 50) },
	Hacker  = { base = Color3.fromRGB(0, 235, 80),   color = seq(Color3.fromRGB(150, 255, 175), Color3.fromRGB(0, 225, 80), Color3.fromRGB(0, 110, 40)), rotation = 90 },
	Rainbow = { base = Color3.fromRGB(255, 255, 255), color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 40, 40)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 0)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(40, 235, 70)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 170, 255)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 50, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 40, 40)),
	}), rotation = 0, stroke = Color3.fromRGB(40, 20, 60) },
	Admin   = { base = Color3.fromRGB(30, 30, 34), color = seq(Color3.fromRGB(110, 110, 118), Color3.fromRGB(40, 40, 45), Color3.fromRGB(5, 5, 6)), rotation = 90, stroke = Color3.fromRGB(235, 235, 240) },
}

-- Renvoie (cleMutation ou nil, nom sans prefixe).
function MutationLabel.Get(part: Instance): (string?, string)
	local displayName = part:GetAttribute("DisplayName") or part.Name
	local key = part:GetAttribute("Mutation")
	if not (type(key) == "string" and MutationLabel.STYLES[key]) then
		key = nil
		-- Secours : prefixe dans le nom.
		for k in pairs(MutationLabel.STYLES) do
			if displayName:sub(1, #k + 1) == k .. " " then
				key = k
				break
			end
		end
	end
	if key and displayName:sub(1, #key + 1) == key .. " " then
		displayName = displayName:sub(#key + 2)
	end
	return key, displayName
end

-- Colore un TextLabel (blanc + UIGradient) et son UIStroke.
function MutationLabel.Style(label: TextLabel, key: string)
	local style = MutationLabel.STYLES[key]
	if not style then
		return
	end
	label.TextColor3 = Color3.new(1, 1, 1)
	local grad = Instance.new("UIGradient")
	grad.Color = style.color
	grad.Rotation = style.rotation
	grad.Parent = label
	local stroke = label:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = style.stroke or Color3.new(style.base.R * 0.4, style.base.G * 0.4, style.base.B * 0.4)
	end
end

return MutationLabel
