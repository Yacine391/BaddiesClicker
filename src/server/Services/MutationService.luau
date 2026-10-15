--[[
	MutationService : branche le protocole des décisions DURABLES (Rules/Receipts.run) sur ProfileStore,
	les remotes et les interrupteurs de maintenance. §25 à §27, §36.

	Décisions concernées : Roll, AcceptDrop, RefuseDrop, Rebirth, OpenChest.
	- Réponse Result { kind = "mutation", action, requestId, ok, reason?, result?, confirmed, replay? }
	  APRÈS l'écriture DataStore (ou son délai) ; pendant l'écriture, StateService retient les snapshots.
	- confirmed = false : décision appliquée, écriture non confirmée → renvoyer le MÊME requestId.
	- Journal serveur : action, requestId, révision, durée d'écriture (identifiant Roblox, rien d'autre).
]]

local Receipts = require(script.Parent.Parent.Rules.Receipts)

export type OnConfirmed = (player: Player, data: any, result: { [string]: any }) -> ()

local MutationService = {}

local ctx
local deps

function MutationService.init(context, dependencies)
	ctx = context
	deps = dependencies
end

function MutationService.run(
	player: Player,
	action: string,
	requestId: any,
	apply: Receipts.Apply,
	onConfirmed: OnConfirmed?
)
	local session = deps.Sessions.get(player)
	if session == nil or deps.Profiles.get(player) == nil then
		return
	end

	local env: Receipts.Env = {
		getData = function()
			return deps.Profiles.get(player)
		end,
		save = function(id: string): boolean
			return deps.Profiles.saveAndWait(player, function(saved)
				return Receipts.isSaved(saved, id)
			end, ctx.Balance.mutations.saveTimeoutSeconds)
		end,
		reply = function(event)
			deps.State.notify(player, event)
		end,
		isDisabled = deps.Maintenance.isDisabled,
		begin = function()
			deps.State.pushNow(player) -- « sauvegarde en cours » ; les snapshots suivants attendent la fin
		end,
		finish = function()
			local data = deps.Profiles.get(player)
			if data ~= nil then
				deps.State.refreshAttributes(player, data)
				deps.State.pushNow(player)
			end
		end,
		log = function(line: string)
			local message = `[Mutation] {player.UserId} {line}`
			if string.find(line, "NON confirmée", 1, true) or string.find(line, "ERREUR", 1, true) then
				warn(message)
			else
				print(message)
			end
		end,
	}

	local confirmedHook = if onConfirmed ~= nil
		then function(data, result)
			onConfirmed(player, data, result)
		end
		else nil

	Receipts.run(env, session, action, requestId, apply, confirmedHook)
end

return MutationService
