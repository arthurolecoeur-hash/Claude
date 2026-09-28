--[[
	ShopBuildMain
	-------------
	Depuis la Command Bar (Studio, mode Edit), puis Ctrl+S :

	Tout d'un coup (Trait Machine + podiums + mutation Admin) :
		local f = game.ServerStorage.ShopBuild_Generateurs:Clone() f.Parent = game.ServerStorage print(require(f.ShopBuildMain).run()) f:Destroy()

	Ou une seule partie : remplace .run() par .machine(), .podiums() ou .admin()
]]

local G = script.Parent

local M = {}

function M.machine(): string
	return require(G.TraitMachineBuild).run()
end

function M.podiums(): string
	return require(G.PodiumBuild).run()
end

function M.admin(): string
	return require(G.AdminMutationBuild).run()
end

function M.run(): string
	local out = {}
	for _, fn in ipairs({ M.machine, M.podiums, M.admin }) do
		local ok, res = pcall(fn)
		table.insert(out, ok and res or ("ERREUR : " .. tostring(res)))
	end
	return table.concat(out, "\n")
end

return M
