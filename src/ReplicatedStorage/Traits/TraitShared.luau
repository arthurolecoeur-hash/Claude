--[[
	TraitShared
	-----------
	Traits des brainrots (Trait Machine). Un brainrot a AU PLUS un trait
	(attribut "Trait" sur sa part / le Handle de son Tool). Un roll ne
	remplace le trait que s'il est MEILLEUR (garde le meilleur).

	`odds` = 1 chance sur N. `icon` = rbxassetid a coller plus tard (vide =
	emoji affiche).

	LUCK_PRODUCTS : Developer Products "10x Luck" (id 0 = gratuit dans
	Studio, "COMING SOON" en jeu publie).
]]

local TraitShared = {}

-- `key` = identifiant sauvegarde (NE PAS changer), `name` = nom affiche.
TraitShared.TRAITS = {
	{ key = "Leaf",    name = "Diamond",   mult = 1.5, odds = 1,     emoji = "💎", icon = "rbxassetid://89180650993961", color = Color3.fromRGB(70, 190, 255) },
	{ key = "Storm",   name = "Fire",      mult = 2,   odds = 10,    emoji = "🔥", icon = "rbxassetid://108339982275412", color = Color3.fromRGB(255, 100, 40) },
	{ key = "Fire",    name = "Star",      mult = 3,   odds = 50,    emoji = "⭐", icon = "rbxassetid://139001506143613", color = Color3.fromRGB(80, 140, 255) },
	{ key = "Star",    name = "Gold",      mult = 4,   odds = 200,   emoji = "🥇", icon = "rbxassetid://127220309921782", color = Color3.fromRGB(255, 210, 40) },
	{ key = "Cosmic",  name = "Coin",      mult = 5,   odds = 1000,  emoji = "🪙", icon = "rbxassetid://119118441475467", color = Color3.fromRGB(255, 160, 20) },
	{ key = "Diamond", name = "Heart",     mult = 6,   odds = 7500,  emoji = "💛", icon = "rbxassetid://116947936406383", color = Color3.fromRGB(255, 120, 150) },
	{ key = "Monkey",  name = "Tralalero", mult = 7,   odds = 15000, emoji = "🦈", icon = "rbxassetid://136159973697586", color = Color3.fromRGB(120, 230, 255) },
}

TraitShared.MAX_SELECTED = 4
TraitShared.COST_SECONDS = 90
TraitShared.MIN_COST = 500
TraitShared.LUCK_MULT = 10
TraitShared.AUTO_DELAY = 1.35

TraitShared.LUCK_PRODUCTS = {
	{ rolls = 1,   id = 0, price = 19 },
	{ rolls = 25,  id = 0, price = 299 },
	{ rolls = 100, id = 0, price = 1199 },
}

local byKey = {}
for i, t in ipairs(TraitShared.TRAITS) do
	t.rank = i
	byKey[t.key] = t
end

-- Image de l'icone (ou "" si aucune : afficher `emoji`).
function TraitShared.Image(t): string
	return t and t.icon or ""
end

function TraitShared.Get(key: any)
	if type(key) ~= "string" then
		return nil
	end
	return byKey[key]
end

local function traitPart(inst: Instance?): Instance?
	if not inst then
		return nil
	end
	if inst:IsA("Tool") then
		return inst:FindFirstChild("Handle")
	end
	return inst
end

function TraitShared.GetTrait(inst: Instance?)
	local part = traitPart(inst)
	return part and TraitShared.Get(part:GetAttribute("Trait")) or nil
end

function TraitShared.GetMultiplier(inst: Instance?): number
	local t = TraitShared.GetTrait(inst)
	return t and t.mult or 1
end

function TraitShared.GetRank(inst: Instance?): number
	local t = TraitShared.GetTrait(inst)
	return t and t.rank or 0
end

-- Tirage : du plus rare au plus commun, chaque trait teste avec luck/odds.
function TraitShared.Roll(rng: Random, luck: number?)
	local l = luck or 1
	for i = #TraitShared.TRAITS, 1, -1 do
		local t = TraitShared.TRAITS[i]
		if rng:NextNumber() < l / t.odds then
			return t
		end
	end
	return TraitShared.TRAITS[1]
end

function TraitShared.FormatMult(m: number): string
	if m % 1 == 0 then
		return ("%dx"):format(m)
	end
	return ("%.1fx"):format(m)
end

function TraitShared.GetProduct(rolls: number)
	for _, p in ipairs(TraitShared.LUCK_PRODUCTS) do
		if p.rolls == rolls then
			return p
		end
	end
	return nil
end

return TraitShared
