--!strict
--[[
	Store : le dernier snapshot du serveur, exposé en valeur Fusion.
	Seule source des chiffres affichés : rien n'est prédit côté client (§25, §28).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Store = {}

Store.snapshot = nil :: any -- Fusion Value<snapshot?>, créé dans init

function Store.init(scope: any, stateController: any)
	Store.snapshot = scope:Value(nil)
	stateController.onState(function(snapshot)
		Store.snapshot:set(snapshot)
	end)

	-- Studio seulement : point d'entrée pour les vérifications (MCP, barre de commande)
	if RunService:IsStudio() then
		local hook = Instance.new("BindableEvent")
		hook.Name = "BC_TestSnapshot"
		hook.Event:Connect(Store.applyForTest)
		hook.Parent = Players.LocalPlayer
		table.insert(scope, hook)
	end
end

-- Vérifications en Studio uniquement : affiche un snapshot fabriqué (ex. forme v2 du contrat).
-- N'envoie rien au serveur ; sans effet hors Studio.
function Store.applyForTest(snapshot: { [string]: any })
	if RunService:IsStudio() then
		Store.snapshot:set(snapshot)
	end
end

return Store
