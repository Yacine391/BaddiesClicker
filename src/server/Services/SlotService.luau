--[[
	SlotService : intentions des slots (lot P2). Toute la règle vit dans Rules/Slots.

	Décisions durables (réponse Result { kind = "mutation" }, voir MutationService) :
	- Roll { requestId, slotId, slotRevision }               hors combat, ticket, verrou, 2 s entre deux
	- AcceptDrop { requestId, baddieId, slotRevision, pendingRevision }   hors combat, temporaire exact
	- RefuseDrop { requestId, baddieId, pendingRevision }    à tout moment, retire une seule unité
	- Rebirth { requestId, expectedRunId }                   hors combat, niveau 10 terminé
	Choix immédiats (ignorés sans réponse s'ils sont invalides, comme Train) :
	- SetActive { slotId }                                   hors combat, slot rempli
	- SetRollLock { slotId, locked }                         à tout moment

	Le tirage est fait ici, UNE fois, côté serveur ; le client ne fournit jamais de résultat.
]]

local Players = game:GetService("Players")

local SlotRules = require(script.Parent.Parent.Rules.Slots)

local SlotService = {}

local ctx
local deps
local rng = Random.new()

function SlotService.init(context, dependencies)
	ctx = context
	deps = dependencies
end

local function inCombat(session): boolean
	return session.inCombat == true or session.encounter ~= nil
end

local function onDiscovery(player: Player, _data, result)
	if result.isNew then
		deps.State.notify(player, { kind = "discovery", baddieId = result.baddieId })
	end
end

-- Intention « Roll »
function SlotService.onRoll(player: Player, payload: { [any]: any }?)
	if payload == nil then
		return
	end
	deps.Mutations.run(player, "Roll", payload.requestId, function(data, session)
		if inCombat(session) then
			return "in_combat"
		end
		local now = os.clock()
		if session.lastRollAt ~= nil and now - session.lastRollAt < ctx.Balance.rolls.minIntervalSeconds then
			return "cooldown"
		end
		local reason = SlotRules.checkRoll(data, payload.slotId, payload.slotRevision)
		if reason ~= nil then
			return reason
		end
		session.lastRollAt = now
		return nil, SlotRules.applyRoll(data, payload.slotId, rng:NextNumber(), ctx)
	end, function(target: Player, data, result)
		onDiscovery(target, data, result)
		deps.Metrics.rolled(target, data, result)
	end)
end

-- Intention « AcceptDrop »
function SlotService.onAcceptDrop(player: Player, payload: { [any]: any }?)
	if payload == nil then
		return
	end
	deps.Mutations.run(player, "AcceptDrop", payload.requestId, function(data, session)
		if inCombat(session) then
			return "in_combat"
		end
		local reason = SlotRules.checkAcceptDrop(
			data,
			payload.baddieId,
			payload.slotRevision,
			payload.pendingRevision,
			ctx
		)
		if reason ~= nil then
			return reason
		end
		return nil, SlotRules.applyAcceptDrop(data, payload.baddieId, ctx)
	end, function(target: Player, data, result)
		onDiscovery(target, data, result)
		deps.Metrics.dropDecided(target, data, "accepter", result.baddieId)
	end)
end

-- Intention « RefuseDrop »
function SlotService.onRefuseDrop(player: Player, payload: { [any]: any }?)
	if payload == nil then
		return
	end
	deps.Mutations.run(player, "RefuseDrop", payload.requestId, function(data)
		local reason = SlotRules.checkRefuseDrop(data, payload.baddieId, payload.pendingRevision)
		if reason ~= nil then
			return reason
		end
		return nil, SlotRules.applyRefuseDrop(data, payload.baddieId)
	end, function(target: Player, data, result)
		deps.Metrics.dropDecided(target, data, "refuser", result.baddieId)
	end)
end

-- Nouveau parcours : retour au lobby (le joueur est souvent encore dans l'arène 10, portes refermées)
local function respawnLater(player: Player)
	task.delay(ctx.Balance.combat.respawnDelay, function()
		if player.Parent == Players then
			local ok, err = pcall(function()
				player:LoadCharacterAsync()
			end)
			if not ok then
				warn(`[SlotService] retour au lobby impossible pour {player.Name} : {err}`)
			end
		end
	end)
end

-- Intention « Rebirth »
function SlotService.onRebirth(player: Player, payload: { [any]: any }?)
	if payload == nil then
		return
	end
	deps.Mutations.run(player, "Rebirth", payload.requestId, function(data, session)
		if inCombat(session) then
			return "in_combat"
		end
		local reason = SlotRules.checkRebirth(data, payload.expectedRunId, ctx)
		if reason ~= nil then
			return reason
		end
		local result = SlotRules.applyRebirth(data, ctx)
		respawnLater(player) -- task.delay ne fait pas attendre : l'application reste d'un bloc
		return nil, result
	end, function(target: Player, data, result)
		deps.State.notify(target, { kind = "rebirth", count = result.count })
		deps.Metrics.reborn(target, data, result)
	end)
end

-- Intention « SetActive » : change seulement activeSlotId (aucun déplacement de baddie)
function SlotService.onSetActive(player: Player, payload: { [any]: any }?)
	local data = deps.Profiles.get(player)
	local session = deps.Sessions.get(player)
	if payload == nil or data == nil or session == nil or inCombat(session) then
		return
	end
	if SlotRules.setActive(data, payload.slotId, ctx) == nil then
		deps.State.refreshAttributes(player, data)
		deps.State.markDirty(player)
	end
end

-- Intention « SetRollLock »
function SlotService.onSetRollLock(player: Player, payload: { [any]: any }?)
	local data = deps.Profiles.get(player)
	if payload == nil or data == nil then
		return
	end
	if SlotRules.setRollLock(data, payload.slotId, payload.locked) == nil then
		deps.State.markDirty(player)
	end
end

return SlotService
