--[[
	AdminGrants
	-----------
	Registre des "Give" du panneau admin. Chaque service qui sait donner
	quelque chose s'enregistre ici (pas de require croise entre Scripts) :

		AdminGrants.Register("Lucky", function(player, amount) ... return true end)

	AdminService appelle ensuite AdminGrants.Grant(kind, player, arg).
]]

local AdminGrants = {}

local handlers = {}

function AdminGrants.Register(kind: string, fn: (Player, any) -> boolean)
	handlers[kind] = fn
end

function AdminGrants.Has(kind: string): boolean
	return handlers[kind] ~= nil
end

function AdminGrants.Grant(kind: string, player: Player, arg: any): boolean
	local fn = handlers[kind]
	if not fn then
		return false
	end
	local ok, result = pcall(fn, player, arg)
	if not ok then
		warn(("AdminGrants[%s]: %s"):format(kind, tostring(result)))
		return false
	end
	return result == true
end

return AdminGrants
