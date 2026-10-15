--!strict
--[[
	Règles des slots, des relances, des drops et de la renaissance (module pur, testé dans tests/run.luau).
	Dossier §10, §11, §13, §14, §26.

	- Chaque slot garde son identité : AUCUNE opération ne déplace une baddie d'un slot vers un autre.
	- Le contenu d'un slot ne change que par : une relance, une acceptation de drop (temporaire seulement),
	  le reset du temporaire au rebirth, ou la procédure de secours (Maya dans le temporaire, voir applyRebirth).
	  Chacune incrémente slotRevision : une confirmation affichée avant ce changement devient périmée.
	- Un slot vide a baddieId = "" (jamais nil, voir ProfileTemplate) ; la vue client le traduit en nil.
	- Le hasard est injecté (`roll` ∈ [0, 1[) : le service tire UNE seule fois, les tests choisissent la valeur.
	- « Conservé » veut dire « survit au rebirth », jamais « protégé d'une relance » ; seul le verrou protège.

	Les validations renvoient une raison (string) ou nil si tout est bon. Raisons possibles :
	"invalid", "unknown_slot", "stale", "locked", "no_ticket", "empty_slot", "no_drop", "no_temporary",
	"not_finished".
]]

export type SlotView = {
	id: string,
	order: number,
	conserved: boolean,
	temporary: boolean,
	baddieId: string?,
	revision: number,
	rollLocked: boolean,
	active: boolean,
}

export type RollResult = {
	slotId: string,
	baddieId: string,
	previousId: string?,
	guaranteed: boolean,
	isNew: boolean,
	slotRevision: number,
	rollNumber: number,
}

export type AcceptResult = {
	slotId: string,
	baddieId: string,
	previousId: string?,
	isNew: boolean,
	slotRevision: number,
	remaining: number,
	isActive: boolean,
}

export type RefuseResult = { baddieId: string, remaining: number }

export type RebirthResult = {
	count: number,
	runId: number,
	promotedSlotId: string?,
	newSlotId: string?,
	clearedSlotId: string?,
	lostBaddieId: string?,
	activeSlotId: string,
	fallback: string?, -- nil | "conserved" | "maya"
	baddieTickets: number,
	crewTickets: number,
}

local Slots = {}

Slots.EMPTY = ""

function Slots.isEmpty(slot: any): boolean
	return slot.baddieId == nil or slot.baddieId == Slots.EMPTY
end

-- IDs des slots triés par ordre (s1, s2, …)
function Slots.orderedIds(data: any): { string }
	local ids = {}
	for id in data.slots do
		table.insert(ids, id)
	end
	table.sort(ids, function(a, b)
		return data.slots[a].order < data.slots[b].order
	end)
	return ids
end

-- Le slot temporaire : le seul non conservé (s'il y en avait plusieurs, le plus récent)
function Slots.temporaryId(data: any): string?
	local found, foundOrder = nil, -math.huge
	for id, slot in data.slots do
		if slot.conserved ~= true and slot.order > foundOrder then
			found, foundOrder = id, slot.order
		end
	end
	return found
end

function Slots.maxOrder(data: any): number
	local max = 0
	for _, slot in data.slots do
		max = math.max(max, slot.order)
	end
	return max
end

-- Vue pour le snapshot client : tableau ordonné, baddieId nil si vide
function Slots.view(data: any): { SlotView }
	local list: { SlotView } = {}
	for _, id in Slots.orderedIds(data) do
		local slot = data.slots[id]
		table.insert(list, {
			id = id,
			order = slot.order,
			conserved = slot.conserved == true,
			temporary = slot.conserved ~= true,
			baddieId = if Slots.isEmpty(slot) then nil else slot.baddieId,
			revision = slot.slotRevision,
			rollLocked = slot.rollLocked == true,
			active = id == data.activeSlotId,
		})
	end
	return list
end

-- Baddies Book : identités PUBLIQUES du lot encore manquantes, dans l'ordre du catalogue.
-- Les identités de test (Studio) n'y figurent jamais.
function Slots.missingBaddies(data: any, ctx: any): { string }
	local list = {}
	for _, id in ctx.Catalog.baddieOrder do
		if data.discoveredBaddies[id] ~= true then
			table.insert(list, id)
		end
	end
	return list
end

function Slots.isBookComplete(data: any, ctx: any): boolean
	return #Slots.missingBaddies(data, ctx) == 0
end

-- Table standard (§13) : chances du catalogue, roll ∈ [0, 1[
function Slots.pickStandard(roll: number, ctx: any): string
	local order = ctx.Catalog.baddieOrder
	local total = 0
	for _, id in order do
		total += ctx.Catalog.baddies[id].rollChance
	end
	local target = roll * total
	local acc = 0
	local last = order[1]
	for _, id in order do
		local chance = ctx.Catalog.baddies[id].rollChance
		if chance > 0 then
			acc += chance
			last = id
			if target < acc then
				return id
			end
		end
	end
	return last -- garde-fou des arrondis quand roll est très proche de 1
end

-- Ouverture garantie : tirage uniforme parmi les identités manquantes
function Slots.pickUniform(roll: number, list: { string }): string
	local index = math.clamp(math.floor(roll * #list) + 1, 1, #list)
	return list[index]
end

-- La relance numéro `rollNumber` (compteur global, 1 = la toute première) est-elle une ouverture garantie ?
function Slots.isGuaranteeRoll(rollNumber: number, ctx: any): boolean
	return rollNumber % ctx.Balance.rolls.baddieGuaranteeEvery == 0
end

-- Relances restantes avant la prochaine ouverture garantie (1 = la prochaine)
function Slots.untilGuarantee(data: any, ctx: any): number
	local every = ctx.Balance.rolls.baddieGuaranteeEvery
	return every - (data.rolls.baddie % every)
end

-- Inscrit une découverte au Baddies Book et initialise sa maîtrise ; renvoie true si elle est nouvelle
function Slots.discover(data: any, baddieId: string): boolean
	if data.masteryXP[baddieId] == nil then
		data.masteryXP[baddieId] = 0
	end
	if data.discoveredBaddies[baddieId] == true then
		return false
	end
	data.discoveredBaddies[baddieId] = true
	return true
end

-- Remplace le contenu d'un slot (seul point d'écriture de baddieId avec applyRebirth)
local function replace(slot: any, baddieId: string): string?
	local previous = if Slots.isEmpty(slot) then nil else slot.baddieId
	slot.baddieId = baddieId
	slot.slotRevision += 1
	return previous
end

--[[ Relance (§13, §26) ]]

function Slots.checkRoll(data: any, slotId: any, slotRevision: any): string?
	if type(slotId) ~= "string" or type(slotRevision) ~= "number" then
		return "invalid"
	end
	local slot = data.slots[slotId]
	if slot == nil then
		return "unknown_slot"
	end
	if slotRevision ~= slot.slotRevision then
		return "stale" -- le joueur a confirmé un autre contenu que celui du slot
	end
	if slot.rollLocked == true then
		return "locked"
	end
	if data.tickets.baddie < 1 then
		return "no_ticket"
	end
	return nil
end

-- À appeler après checkRoll : un ticket, compteur global +1, garantie toutes les 50 si le Book est incomplet
function Slots.applyRoll(data: any, slotId: string, roll: number, ctx: any): RollResult
	local slot = data.slots[slotId]
	assert(slot ~= nil, `slot inconnu : {slotId}`)

	data.tickets.baddie -= 1
	data.rolls.baddie += 1
	local rollNumber = data.rolls.baddie

	local missing = Slots.missingBaddies(data, ctx)
	local guaranteed = Slots.isGuaranteeRoll(rollNumber, ctx) and #missing > 0
	local baddieId = if guaranteed then Slots.pickUniform(roll, missing) else Slots.pickStandard(roll, ctx)

	local previous = replace(slot, baddieId)
	local isNew = Slots.discover(data, baddieId)

	return {
		slotId = slotId,
		baddieId = baddieId,
		previousId = previous,
		guaranteed = guaranteed,
		isNew = isNew,
		slotRevision = slot.slotRevision,
		rollNumber = rollNumber,
	}
end

--[[ Drops de boss en attente (§14, §26) ]]

function Slots.checkAcceptDrop(
	data: any,
	baddieId: any,
	slotRevision: any,
	pendingRevision: any,
	ctx: any
): string?
	if type(baddieId) ~= "string" or type(slotRevision) ~= "number" or type(pendingRevision) ~= "number" then
		return "invalid"
	end
	if ctx.Catalog.baddies[baddieId] == nil then
		return "invalid"
	end
	if (data.pendingDrops[baddieId] or 0) < 1 then
		return "no_drop"
	end
	if pendingRevision ~= data.pendingRevision then
		return "stale"
	end
	local tempId = Slots.temporaryId(data)
	if tempId == nil then
		return "no_temporary"
	end
	if slotRevision ~= data.slots[tempId].slotRevision then
		return "stale" -- « Vega remplacera Lina dans s2 » ne vaut que pour le contenu affiché
	end
	return nil
end

-- Retire UNE unité et remplace le temporaire (jamais un slot conservé), puis débloque le Book
function Slots.applyAcceptDrop(data: any, baddieId: string, _ctx: any): AcceptResult
	local tempId = Slots.temporaryId(data)
	assert(tempId ~= nil, "aucun slot temporaire")
	local slot = data.slots[tempId]

	local remaining = data.pendingDrops[baddieId] - 1
	data.pendingDrops[baddieId] = if remaining > 0 then remaining else nil
	data.pendingRevision += 1

	local previous = replace(slot, baddieId)
	local isNew = Slots.discover(data, baddieId)

	return {
		slotId = tempId,
		baddieId = baddieId,
		previousId = previous,
		isNew = isNew,
		slotRevision = slot.slotRevision,
		remaining = remaining,
		isActive = data.activeSlotId == tempId,
	}
end

function Slots.checkRefuseDrop(data: any, baddieId: any, pendingRevision: any): string?
	if type(baddieId) ~= "string" or type(pendingRevision) ~= "number" then
		return "invalid"
	end
	if (data.pendingDrops[baddieId] or 0) < 1 then
		return "no_drop"
	end
	if pendingRevision ~= data.pendingRevision then
		return "stale"
	end
	return nil
end

-- Supprime UNE unité, sans autre effet (ni découverte, ni compteur de relance)
function Slots.applyRefuseDrop(data: any, baddieId: string): RefuseResult
	local remaining = data.pendingDrops[baddieId] - 1
	data.pendingDrops[baddieId] = if remaining > 0 then remaining else nil
	data.pendingRevision += 1
	return { baddieId = baddieId, remaining = remaining }
end

--[[ Choix immédiats (sans écriture prioritaire) ]]

-- Changer de principale : seulement activeSlotId change, le slot doit être rempli
function Slots.setActive(data: any, slotId: any, ctx: any): string?
	if type(slotId) ~= "string" then
		return "invalid"
	end
	local slot = data.slots[slotId]
	if slot == nil then
		return "unknown_slot"
	end
	if Slots.isEmpty(slot) or ctx.Catalog.baddies[slot.baddieId] == nil then
		return "empty_slot"
	end
	data.activeSlotId = slotId
	return nil
end

-- Verrou manuel de relance (protège des relances accidentelles, pas du reset du temporaire au rebirth)
function Slots.setRollLock(data: any, slotId: any, locked: any): string?
	if type(slotId) ~= "string" or type(locked) ~= "boolean" then
		return "invalid"
	end
	local slot = data.slots[slotId]
	if slot == nil then
		return "unknown_slot"
	end
	if locked and Slots.isEmpty(slot) then
		return "empty_slot"
	end
	slot.rollLocked = locked
	return nil
end

--[[ Renaissance (§10, §11, §12, §26)

	- Condition : le niveau 10 est terminé dans le parcours en cours (et le client confirme le bon run.id).
	- Paliers 1, 3 et 6 : le temporaire devient conservé AVEC son contenu et un nouveau temporaire vide s'ouvre.
	  Aux autres renaissances : le temporaire est vidé (son verrou de relance aussi).
	- Récompenses une seule fois (+5 tickets baddie, +1 ticket compagnon) ; puissance à 1 ; nouveau parcours
	  (portes et récompenses de premier passage remises à zéro).
	- Conservés : drops en attente, Baddies Book, looks, maîtrise, compagnons, tickets et compteurs.
	- Principale valide : si le rebirth l'efface, on prend le slot conservé rempli au plus fort multiplicateur
	  (proposition : le dossier dit « un slot rempli conservé ») ; s'il n'y en a aucun, Maya est installée
	  dans le temporaire (procédure de secours, §11).
]]

-- Le parcours est fini : boss du dernier niveau vaincu dans ce run
function Slots.rebirthAvailable(data: any, ctx: any): boolean
	return data.run.clearedLevels[tostring(#ctx.Balance.levels)] == true
end

-- La renaissance numéro `count` promeut-elle le temporaire ?
function Slots.rebirthPromotes(count: number, ctx: any): boolean
	return table.find(ctx.Balance.rebirth.promotionAt, count) ~= nil
end

function Slots.checkRebirth(data: any, expectedRunId: any, ctx: any): string?
	if type(expectedRunId) ~= "number" then
		return "invalid"
	end
	if expectedRunId ~= data.run.id then
		return "stale" -- confirmation affichée pour un autre parcours
	end
	if not Slots.rebirthAvailable(data, ctx) then
		return "not_finished"
	end
	return nil
end

-- Slot conservé et rempli au plus fort multiplicateur (à égalité : le plus ancien)
local function bestConserved(data: any, ctx: any): string?
	local best, bestMultiplier = nil, -math.huge
	for _, id in Slots.orderedIds(data) do
		local slot = data.slots[id]
		local def = if Slots.isEmpty(slot) then nil else ctx.Catalog.baddies[slot.baddieId]
		if slot.conserved == true and def ~= nil and def.multiplier > bestMultiplier then
			best, bestMultiplier = id, def.multiplier
		end
	end
	return best
end

-- À appeler après check : applique toute la transition d'un coup
function Slots.applyRebirth(data: any, ctx: any): RebirthResult
	local B = ctx.Balance
	local count = data.rebirths + 1
	local tempId = Slots.temporaryId(data)

	-- 1. Promotion du temporaire (paliers 1/3/6) et ouverture d'un nouveau temporaire vide
	local promotedSlotId, newSlotId = nil, nil
	if tempId ~= nil and Slots.rebirthPromotes(count, ctx) then
		data.slots[tempId].conserved = true
		promotedSlotId = tempId
		local order = Slots.maxOrder(data) + 1
		local id = `s{order}`
		while data.slots[id] ~= nil do
			order += 1
			id = `s{order}`
		end
		data.slots[id] =
			{ order = order, conserved = false, baddieId = Slots.EMPTY, slotRevision = 0, rollLocked = false }
		newSlotId = id
	end

	-- 2. Reset des temporaires non promus (le verrou ne protège pas de ce reset)
	local clearedSlotId, lostBaddieId = nil, nil
	for id, slot in data.slots do
		if slot.conserved ~= true and id ~= newSlotId then
			clearedSlotId = id
			if not Slots.isEmpty(slot) then
				lostBaddieId = slot.baddieId
			end
			slot.baddieId = Slots.EMPTY
			slot.slotRevision += 1
			slot.rollLocked = false
		end
	end

	-- 3. Récompenses et nouveau parcours
	data.rebirths = count
	data.tickets.baddie += B.rebirth.baddieTickets
	data.tickets.crew += B.rebirth.crewTickets
	data.power = B.power.start
	data.run = { id = data.run.id + 1, attempt = 1, clearedLevels = {}, firstClearRewards = {} }

	-- 4. Principale valide
	local fallback = nil
	local active = data.slots[data.activeSlotId]
	if active == nil or Slots.isEmpty(active) or ctx.Catalog.baddies[active.baddieId] == nil then
		local best = bestConserved(data, ctx)
		if best ~= nil then
			data.activeSlotId = best
			fallback = "conserved"
		else
			local target = Slots.temporaryId(data) or Slots.orderedIds(data)[1]
			local slot = data.slots[target]
			local starter = B.tutorial.starterBaddieId
			slot.baddieId = starter
			slot.slotRevision += 1
			Slots.discover(data, starter)
			data.activeSlotId = target
			fallback = "maya"
		end
	end

	return {
		count = count,
		runId = data.run.id,
		promotedSlotId = promotedSlotId,
		newSlotId = newSlotId,
		clearedSlotId = clearedSlotId,
		lostBaddieId = lostBaddieId,
		activeSlotId = data.activeSlotId,
		fallback = fallback,
		baddieTickets = B.rebirth.baddieTickets,
		crewTickets = B.rebirth.crewTickets,
	}
end

return Slots
