--[[
	BaseSkinShared
	--------------
	ModuleScript partage client/serveur (ReplicatedStorage).

	Skins de base debloques par l'Index : completer REQUIRED_RATIO (50%)
	d'une page de mutation debloque la base de cette mutation (ex: 50% des
	brainrots Gold -> base en or). Normal est toujours disponible.

	Pour ajouter un skin : une entree ici (la cle = cle de mutation de
	BrainrotCatalog.MUTATIONS) + son rendu dans BaseSkinService.STYLES.
]]

local BaseSkinShared = {}

BaseSkinShared.REQUIRED_RATIO = 0.5

-- mult = multiplicateur de cash de la base equipee (sur tous les generateurs).
-- productId = Developer Product Robux (0 = pas encore cree : gratuit dans Studio).
-- price = prix affiche tant que productId vaut 0.
BaseSkinShared.SKINS = {
	{ key = "Normal",  name = "Normal Base",  color = Color3.fromRGB(175, 180, 195), mult = 1 },
	{ key = "Gold",    name = "Gold Base",    color = Color3.fromRGB(255, 196, 0),   mult = 1.25, productId = 3714893692, price = 199 },
	{ key = "Diamond", name = "Diamond Base", color = Color3.fromRGB(0, 190, 255),   mult = 1.5,  productId = 3714893619, price = 349 },
	{ key = "Ruby",    name = "Ruby Base",    color = Color3.fromRGB(255, 20, 75),   mult = 2,    productId = 3714893581, price = 499 },
	{ key = "Lava",    name = "Lava Base",    color = Color3.fromRGB(255, 85, 0),    mult = 2.5,  productId = 3714893539, price = 699 },
	{ key = "Galaxy",  name = "Galaxy Base",  color = Color3.fromRGB(140, 70, 255),  mult = 3.5,  productId = 3714893500, price = 799 },
	{ key = "Hacker",  name = "Hacker Base",  color = Color3.fromRGB(0, 220, 80),    mult = 4,    productId = 3714893456, price = 899 },
	{ key = "Rainbow", name = "Rainbow Base", color = Color3.fromRGB(255, 255, 255), mult = 5,    productId = 3714893413, price = 1399 },
	{ key = "Admin",   name = "Admin Base",   color = Color3.fromRGB(255, 30, 45),   mult = 7,    productId = 0,          price = 1999 },
}

--== Rendu de chaque skin (partage : serveur = vraie base, client = apercu UI) ==--
-- dark/light : couleur appliquee selon la luminosite d'origine de la Part.
-- accent : Parts fines (rebords, barreaux) dans un rendu a part.
BaseSkinShared.STYLES = {
	Gold    = { material = Enum.Material.Foil, dark = Color3.fromRGB(165, 105, 0), light = Color3.fromRGB(255, 215, 60) },
	Diamond = { material = Enum.Material.Glass, dark = Color3.fromRGB(0, 90, 165), light = Color3.fromRGB(90, 170, 215) },
	Ruby    = { material = Enum.Material.Glass, dark = Color3.fromRGB(100, 0, 25), light = Color3.fromRGB(200, 35, 70) },
	Lava    = { material = Enum.Material.CrackedLava, dark = Color3.fromRGB(90, 20, 0), light = Color3.fromRGB(255, 110, 0) },
	Galaxy  = {
		material = Enum.Material.Glass, dark = Color3.fromRGB(25, 10, 70), light = Color3.fromRGB(120, 60, 230),
		accent = { material = Enum.Material.Neon, color = Color3.fromRGB(200, 120, 255) },
	},
	Hacker  = {
		material = Enum.Material.SmoothPlastic, dark = Color3.fromRGB(5, 18, 8), light = Color3.fromRGB(15, 55, 25),
		accent = { material = Enum.Material.Neon, color = Color3.fromRGB(0, 255, 90) },
	},
	Rainbow = { material = Enum.Material.SmoothPlastic, rainbow = true },
	Admin   = {
		material = Enum.Material.Slate, dark = Color3.fromRGB(18, 6, 8), light = Color3.fromRGB(75, 14, 20),
		accent = { material = Enum.Material.Neon, color = Color3.fromRGB(255, 25, 45) },
	},
}

local function luminance(c: Color3): number
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function isThin(part: BasePart): boolean
	local s = part.Size
	local minS = math.min(s.X, s.Y, s.Z)
	local maxS = math.max(s.X, s.Y, s.Z)
	return minS <= 1 and maxS >= 3 and (s.X + s.Y + s.Z - minS - maxS) <= 1
end

-- Peint une Part pour le skin `key` a partir de sa couleur/matiere d'origine.
function BaseSkinShared.Paint(part: BasePart, key: string, origColor: Color3, origMat: Enum.Material)
	local style = BaseSkinShared.STYLES[key]
	if not style then
		part.Color = origColor
		part.Material = origMat
	elseif style.rainbow then
		local p = part.Position
		local hue = ((p.X + p.Z) / 90 + p.Y / 40) % 1
		local v = 0.65 + 0.35 * math.clamp(luminance(origColor) / 0.8, 0, 1)
		part.Color = Color3.fromHSV(hue, 0.8, v)
		part.Material = style.material
	elseif style.accent and isThin(part) then
		part.Color = style.accent.color
		part.Material = style.accent.material
	else
		local t = math.clamp((luminance(origColor) - 0.1) / 0.7, 0, 1)
		part.Color = style.dark:Lerp(style.light, t)
		part.Material = style.material
	end
end

function BaseSkinShared.Get(key: string)
	for _, s in ipairs(BaseSkinShared.SKINS) do
		if s.key == key then
			return s
		end
	end
	return nil
end

-- Multiplicateur de cash d'un skin (1 si inconnu).
function BaseSkinShared.GetMultiplier(key: string?): number
	local s = key and BaseSkinShared.Get(key)
	return s and s.mult or 1
end

-- Nombre de brainrots a avoir pour debloquer (arrondi au superieur).
function BaseSkinShared.GetRequired(total: number): number
	return math.ceil(total * BaseSkinShared.REQUIRED_RATIO)
end

return BaseSkinShared
