--[[
	CrewService : production passive des compagnons, calculée par le serveur (§04, §16).
	Arrêter une animation côté client ne change rien aux gains. Production uniquement
	tant que le joueur est connecté et que son profil est chargé.
]]

local CrewRules = require(script.Parent.Parent.Rules.Crew)

local CrewService = {}

local ctx
local deps

function CrewService.init(context, dependencies)
	ctx = context
	deps = dependencies
end

local function tick()
	local now = os.clock()
	for player, session in deps.Sessions.all() do
		local dt = now - session.lastPassiveAt
		session.lastPassiveAt = now
		local data = deps.Profiles.get(player)
		if data ~= nil then
			local gained = CrewRules.applyPassive(data, dt, ctx)
			if gained > 0 then
				deps.State.markDirty(player)
				deps.State.notify(player, { kind = "passiveTick", amount = gained })
			end
		end
	end
end

function CrewService.start()
	task.spawn(function()
		while true do
			task.wait(ctx.Balance.crew.tickSeconds)
			tick()
		end
	end)
end

return CrewService
