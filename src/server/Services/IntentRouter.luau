--[[
	IntentRouter : point d'entrée UNIQUE des actions client (RemoteEvent « Intent »).
	Valide le type des arguments, applique la limite de cadence par action, puis
	appelle le service concerné. Toute entrée invalide est ignorée sans erreur.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

export type Route = {
	rate: number,
	burst: number,
	handler: (Player, { [any]: any }?) -> (),
}

local IntentRouter = {}

function IntentRouter.init(_context, deps, routes: { [string]: Route })
	local intent = Net.remote(Net.INTENT)
	intent.OnServerEvent:Connect(function(player: Player, action: unknown, payload: unknown)
		if typeof(action) ~= "string" then
			return
		end
		local route = routes[action :: string]
		if route == nil then
			return
		end
		if payload ~= nil and typeof(payload) ~= "table" then
			return
		end

		local session = deps.Sessions.get(player)
		if session == nil then
			return -- profil pas encore prêt : le serveur enverra l'état au chargement
		end

		local bucket = deps.Sessions.bucket(session, action :: string, route.rate, route.burst)
		if not RateLimiter.allow(bucket, os.clock()) then
			return
		end

		route.handler(player, payload :: { [any]: any }?)
	end)
end

return IntentRouter
