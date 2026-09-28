--[[
	MasteryShared
	-------------
	Mastery = points gagnes a chaque YEET (plus on lance loin, plus on en
	gagne). Ils achetent des skins "old Roblox" qui multiplient la FORCE
	gagnee (x1.5 -> x20). Le bonus = le meilleur skin POSSEDE (on peut
	porter son propre avatar et garder le bonus).

	userId : compte Roblox dont on copie l'avatar. colors : skin dessine
	(Noob / Guest) a partir de couleurs de corps classiques.
]]

local MasteryShared = {}

MasteryShared.ICON = "⭐"
MasteryShared.NAME = "MASTERY"

-- Points par lancer : 1 + 1 par PER_STUDS studs parcourus, plafonne.
MasteryShared.PER_STUDS = 150
MasteryShared.MAX_PER_YEET = 60

local C = Color3.fromRGB

MasteryShared.SKINS = {
	{ key = "Noob", name = "Noob", cost = 25, mult = 1.5, color = C(255, 215, 50),
		colors = { head = C(245, 205, 48), torso = C(13, 105, 172), arms = C(245, 205, 48), legs = C(164, 189, 71) } },
	{ key = "Guest", name = "Guest", cost = 100, mult = 2.5, color = C(200, 200, 210),
		colors = { head = C(242, 243, 243), torso = C(27, 42, 53), arms = C(242, 243, 243), legs = C(99, 95, 98) } },
	{ key = "JohnDoe", name = "John Doe", cost = 350, mult = 4, color = C(90, 170, 255), userId = 2 },
	{ key = "JaneDoe", name = "Jane Doe", cost = 1000, mult = 7, color = C(255, 110, 190), userId = 3 },
	{ key = "Shedletsky", name = "Shedletsky", cost = 3000, mult = 12, color = C(255, 90, 60), userId = 261 },
	{ key = "Builderman", name = "Builderman", cost = 8000, mult = 20, color = C(255, 180, 0), userId = 156 },
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
