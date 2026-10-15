--[[
	TrainingService : traite l'intention « Train ».
	Le client n'envoie AUCUN montant : le serveur recalcule tout depuis le profil (§25).
]]

local TrainingRules = require(script.Parent.Parent.Rules.Training)
local CrewRules = require(script.Parent.Parent.Rules.Crew)

local TrainingService = {}

local ctx
local deps

function TrainingService.init(context, dependencies)
	ctx = context
	deps = dependencies
end

function TrainingService.onTrain(player: Player)
	local data = deps.Profiles.get(player)
	local session = deps.Sessions.get(player)
	if data == nil or session == nil then
		return
	end
	if not TrainingRules.canTrain(session) then
		return
	end

	local result = TrainingRules.apply(data, ctx)

	if result.crewUnlocked ~= nil then
		local grant = CrewRules.grant(data, result.crewUnlocked, ctx)
		deps.State.refreshAttributes(player, data)
		deps.State.notify(player, {
			kind = "crewJoined",
			crewId = result.crewUnlocked,
			isNew = grant.isNew,
			equipped = grant.equipped,
		})
	end
	if result.baddieTickets > 0 then
		deps.State.notify(player, { kind = "ticket", ticket = "baddie", amount = result.baddieTickets })
	end
	if result.crewTickets > 0 then
		deps.State.notify(player, { kind = "ticket", ticket = "crew", amount = result.crewTickets })
	end

	deps.Metrics.trained(player, data, result)
	deps.State.markDirty(player)
end

return TrainingService
