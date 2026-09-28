--[[
	WeatherShared
	-------------
	ModuleScript partage (ReplicatedStorage).

	Une meteo = mutation `key` x`boost` de chance pendant `duration` s.
	Etat courant : attributs de workspace "Weather" (cle, "" = aucune) et
	"WeatherEndsAt" (workspace:GetServerTimeNow()).

	`icon` : rbxassetid d'une image (ton decal). Vide = `emoji` dessine a la place.
	`weight` : poids du tirage de la meteo suivante.
]]

local WeatherShared = {}

WeatherShared.BOOST = 10
WeatherShared.DEFAULT_ICON = "rbxassetid://105501739154353"
WeatherShared.INTERVAL_MIN = 15 * 60
WeatherShared.INTERVAL_MAX = 15 * 60
WeatherShared.DURATION = 150

WeatherShared.LIST = {
	{ key = "Lava",    name = "Lava Weather",    weight = 45, icon = "", emoji = "🌋", color = Color3.fromRGB(255, 85, 0),    tint = Color3.fromRGB(255, 205, 170) },
	{ key = "Galaxy",  name = "Galaxy Weather",  weight = 30, icon = "", emoji = "🌌", color = Color3.fromRGB(140, 70, 255),  tint = Color3.fromRGB(210, 190, 255) },
	{ key = "Hacker",  name = "Hacker Weather",  weight = 18, icon = "", emoji = "💻", color = Color3.fromRGB(0, 220, 80),    tint = Color3.fromRGB(185, 255, 200) },
	{ key = "Rainbow", name = "Rainbow Weather", weight = 7,  icon = "", emoji = "🌈", color = Color3.fromRGB(255, 255, 255), tint = Color3.fromRGB(255, 240, 255), rainbow = true },
	-- weight 0 : jamais tiree au hasard, seulement lancee par un admin.
	{ key = "Admin",   name = "ADMIN ABUSE",     weight = 0,  icon = "", emoji = "👑", color = Color3.fromRGB(255, 30, 45),   tint = Color3.fromRGB(255, 200, 200), boost = 400, adminOnly = true },
}

function WeatherShared.Get(key: string?)
	if not key or key == "" then
		return nil
	end
	for _, w in ipairs(WeatherShared.LIST) do
		if w.key == key then
			return w
		end
	end
	return nil
end

function WeatherShared.GetCurrent()
	local w = WeatherShared.Get(workspace:GetAttribute("Weather"))
	if not w then
		return nil, 0
	end
	local left = (workspace:GetAttribute("WeatherEndsAt") or 0) - workspace:GetServerTimeNow()
	if left <= 0 then
		return nil, 0
	end
	return w, left
end

function WeatherShared.GetMutationBoost(mutationKey: string): number
	local w = WeatherShared.GetCurrent()
	if w and w.key == mutationKey then
		return w.boost or WeatherShared.BOOST
	end
	return 1
end

return WeatherShared
