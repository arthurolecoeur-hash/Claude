--[[
	MasteryShared
	-------------
	Mastery = points gagnes a chaque YEET (plus on lance loin, plus on en
	gagne). Ils achetent des skins "old Roblox" pour le NOOB QU'ON LANCE
	(modele tenu / en vol + apparence apres l'atterrissage). Passif : la
	FORCE gagnee est multipliee (x1.5 -> x20) par le meilleur skin possede.
]]

local MasteryShared = {}

MasteryShared.ICON = "⭐"
MasteryShared.NAME = "MASTERY"

-- Points par lancer : 1 + 1 par PER_STUDS studs parcourus, plafonne.
MasteryShared.PER_STUDS = 150
MasteryShared.MAX_PER_YEET = 60

local C = Color3.fromRGB

-- colors : couleurs de corps du noob lance (modele en vol + perso apres
-- l'atterrissage). hat : chapeau en blocs sur le noob en vol. userId :
-- l'avatar de ce compte est applique au joueur a l'atterrissage.
MasteryShared.SKINS = {
	{ key = "Noob", name = "Noob", cost = 25, mult = 1.5, color = C(255, 215, 50), trail = C(255, 230, 90),
		colors = { head = C(245, 205, 48), torso = C(13, 105, 172), arms = C(245, 205, 48), legs = C(164, 189, 71) } },
	{ key = "Guest", name = "Guest", cost = 100, mult = 2.5, color = C(200, 200, 210), trail = C(235, 235, 245),
		colors = { head = C(242, 243, 243), torso = C(27, 42, 53), arms = C(242, 243, 243), legs = C(99, 95, 98) },
		hat = { kind = "cap", color = C(27, 42, 53) } },
	{ key = "JohnDoe", name = "John Doe", cost = 350, mult = 4, color = C(90, 170, 255), trail = C(90, 170, 255), userId = 2,
		colors = { head = C(245, 205, 48), torso = C(27, 42, 53), arms = C(245, 205, 48), legs = C(13, 105, 172) } },
	{ key = "JaneDoe", name = "Jane Doe", cost = 1000, mult = 7, color = C(255, 110, 190), trail = C(255, 120, 200), userId = 3,
		colors = { head = C(245, 205, 48), torso = C(196, 40, 28), arms = C(245, 205, 48), legs = C(13, 105, 172) },
		hat = { kind = "hair", color = C(105, 64, 40) } },
	{ key = "Shedletsky", name = "Shedletsky", cost = 3000, mult = 12, color = C(255, 90, 60), trail = C(255, 110, 60), userId = 261,
		colors = { head = C(234, 184, 146), torso = C(255, 176, 0), arms = C(234, 184, 146), legs = C(27, 42, 53) },
		hat = { kind = "hair", color = C(40, 30, 25) } },
	{ key = "Builderman", name = "Builderman", cost = 8000, mult = 20, color = C(255, 180, 0), trail = C(255, 200, 40), userId = 156,
		colors = { head = C(234, 184, 146), torso = C(255, 176, 0), arms = C(234, 184, 146), legs = C(13, 105, 172) },
		hat = { kind = "hardhat", color = C(255, 205, 0) } },
}

local byKey = {}
for i, s in ipairs(MasteryShared.SKINS) do
	s.rank = i
	byKey[s.key] = s
end

function MasteryShared.Get(key: any)
	return type(key) == "string" and byKey[key] or nil
end

function MasteryShared.PointsForDistance(distance: number): number
	return math.clamp(1 + math.floor(math.max(0, distance) / MasteryShared.PER_STUDS), 1, MasteryShared.MAX_PER_YEET)
end

-- Meilleur multiplicateur parmi les skins possedes ({ [key] = true }).
function MasteryShared.BestMult(owned: { [string]: boolean }?): number
	local best = 1
	for _, s in ipairs(MasteryShared.SKINS) do
		if owned and owned[s.key] and s.mult > best then
			best = s.mult
		end
	end
	return best
end

function MasteryShared.FormatMult(m: number): string
	if m % 1 == 0 then
		return ("x%d"):format(m)
	end
	return ("x%.1f"):format(m)
end

return MasteryShared
