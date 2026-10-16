--!strict
--[[
	SlotsModel : textes et états des écrans Slots, Drops et Renaissance (§11, §13, §14, §26).
	Module pur (testé dans tests/client/run.luau) : il lit le snapshot, ne décide de rien.
	Le serveur reste seul juge (tickets, révisions, combat, maintenance) ; ces textes servent à
	griser un bouton avant l'envoi et à expliquer un refus après.
]]

local SlotsModel = {}

export type SlotRow = {
	id: string,
	label: string, -- « SLOT 1 »
	kind: string, -- « TEMPORAIRE » | « CONSERVÉ »
	baddieId: string?,
	name: string,
	rarityLabel: string?,
	rarityColor: string?,
	multiplierText: string,
	active: boolean,
	rollLocked: boolean,
	revision: number,
	canRoll: boolean,
	rollHint: string,
}

export type DropRow = {
	baddieId: string,
	count: number,
	name: string,
	rarityLabel: string?,
	rarityColor: string?,
	multiplierText: string,
	isNew: boolean,
	canAccept: boolean,
	replaceText: string,
	slotRevision: number,
	pendingRevision: number,
}

export type RebirthView = {
	available: boolean,
	runId: number,
	title: string,
	keep: string,
	lose: string,
	rewards: string,
}

SlotsModel.REASONS = table.freeze({
	busy = "une décision est déjà en cours",
	saving = "sauvegarde en cours, nouvel essai automatique",
	cooldown = "attends 2 secondes",
	in_combat = "impossible en combat",
	stale = "l'écran n'était plus à jour : vérifie et recommence",
	locked = "slot verrouillé",
	no_ticket = "pas de ticket",
	no_drop = "ce drop n'est plus en attente",
	no_temporary = "aucun slot temporaire",
	not_finished = "termine d'abord le niveau 10",
	unknown_slot = "slot inconnu",
	invalid = "demande invalide",
	duplicate = "déjà traité",
	error = "erreur serveur, nouvel essai automatique",
	maintenance = "coupé temporairement pour maintenance",
})

function SlotsModel.reasonText(reason: string?): string
	if reason == nil then
		return "refusé"
	end
	return SlotsModel.REASONS[reason] or reason
end

-- Raison commune de griser une décision durable (avant tout envoi)
function SlotsModel.blocked(snapshot: { [string]: any }?, action: string): string?
	if snapshot == nil then
		return "chargement"
	end
	if snapshot.mode == "combat" then
		return SlotsModel.REASONS.in_combat
	end
	if snapshot.saving == true then
		return "sauvegarde en cours"
	end
	for _, name in snapshot.maintenance or {} do
		if name == action then
			return SlotsModel.REASONS.maintenance
		end
	end
	return nil
end

local function multiplierText(def: any, format: (number) -> string): string
	return if def then "×" .. format(def.multiplier) else "—"
end

local function rarityOf(def: any, catalog: any): (string?, string?)
	local rarity = if def then catalog.rarities[def.rarity] else nil
	if rarity == nil then
		return nil, nil
	end
	return rarity.label, rarity.color
end

local function nameOf(id: string?, catalog: any): string
	local def = if id then catalog.baddies[id] else nil
	return if def then string.upper(def.name) else "VIDE"
end

local function temporaryOf(snapshot: { [string]: any }): any?
	for _, slot in snapshot.slots or {} do
		if slot.temporary == true then
			return slot
		end
	end
	return nil
end

function SlotsModel.slotRows(
	snapshot: { [string]: any }?,
	catalog: any,
	format: (number) -> string
): { SlotRow }
	local rows: { SlotRow } = {}
	if snapshot == nil then
		return rows
	end
	local tickets = tonumber(snapshot.tickets and snapshot.tickets.baddie) or 0
	local rolls = snapshot.rolls or {}
	local blocked = SlotsModel.blocked(snapshot, "Roll")
	local guarantee = if rolls.bookComplete
		then "Book complet : table normale"
		elseif tonumber(rolls.untilGuarantee) == 1 then "la prochaine est garantie"
		else `garantie dans {rolls.untilGuarantee or "?"}`
	for _, slot in snapshot.slots or {} do
		local def = if slot.baddieId then catalog.baddies[slot.baddieId] else nil
		local rarityLabel, rarityColor = rarityOf(def, catalog)
		local hint
		if slot.rollLocked then
			hint = "verrouillé : déverrouille pour relancer"
		elseif blocked then
			hint = blocked
		elseif tickets < 1 then
			hint = "pas de ticket"
		else
			hint = `1 ticket · {guarantee}`
		end
		table.insert(rows, {
			id = slot.id,
			label = `SLOT {slot.order or "?"}`,
			kind = if slot.temporary then "TEMPORAIRE" else "CONSERVÉ",
			baddieId = slot.baddieId,
			name = nameOf(slot.baddieId, catalog),
			rarityLabel = rarityLabel,
			rarityColor = rarityColor,
			multiplierText = multiplierText(def, format),
			active = slot.active == true,
			rollLocked = slot.rollLocked == true,
			revision = tonumber(slot.revision) or 0,
			canRoll = not slot.rollLocked and blocked == nil and tickets >= 1,
			rollHint = hint,
		})
	end
	return rows
end

function SlotsModel.dropCount(snapshot: { [string]: any }?): number
	local total = 0
	for _, count in (snapshot and snapshot.pendingDrops) or {} do
		total += tonumber(count) or 0
	end
	return total
end

function SlotsModel.dropRows(
	snapshot: { [string]: any }?,
	catalog: any,
	format: (number) -> string
): { DropRow }
	local rows: { DropRow } = {}
	if snapshot == nil then
		return rows
	end
	local temp = temporaryOf(snapshot)
	local blocked = SlotsModel.blocked(snapshot, "AcceptDrop")
	local discovered = {}
	for _, id in (snapshot.collection and snapshot.collection.discovered) or {} do
		discovered[id] = true
	end
	for _, id in catalog.baddieOrder do
		local count = tonumber((snapshot.pendingDrops or {})[id]) or 0
		if count > 0 then
			local def = catalog.baddies[id]
			local rarityLabel, rarityColor = rarityOf(def, catalog)
			local replaceText
			if temp == nil then
				replaceText = "aucun slot temporaire"
			elseif temp.baddieId == nil then
				replaceText = `ira dans le SLOT {temp.order} (vide)`
			else
				replaceText = `remplacera {nameOf(temp.baddieId, catalog)} dans le SLOT {temp.order}`
			end
			table.insert(rows, {
				baddieId = id,
				count = count,
				name = nameOf(id, catalog),
				rarityLabel = rarityLabel,
				rarityColor = rarityColor,
				multiplierText = multiplierText(def, format),
				isNew = discovered[id] ~= true,
				canAccept = temp ~= nil and blocked == nil,
				replaceText = replaceText,
				slotRevision = if temp then tonumber(temp.revision) or 0 else 0,
				pendingRevision = tonumber(snapshot.pendingRevision) or 0,
			})
		end
	end
	return rows
end

function SlotsModel.rebirthView(snapshot: { [string]: any }?, catalog: any): RebirthView
	local rebirth = (snapshot and snapshot.rebirth) or {}
	local run = (snapshot and snapshot.run) or {}
	local count = tonumber(rebirth.count) or 0
	local temp = if snapshot then temporaryOf(snapshot) else nil
	local lose
	if rebirth.promotesNext then
		lose = if temp and temp.baddieId
			then `Rien : {nameOf(temp.baddieId, catalog)} (SLOT {temp.order}) devient CONSERVÉ et un nouveau slot s'ouvre.`
			else "Rien : ton slot temporaire devient conservé et un nouveau slot s'ouvre."
	else
		lose = if temp and temp.baddieId
			then `{nameOf(temp.baddieId, catalog)} (SLOT {temp.order}, temporaire) sera effacée. Puissance remise à 1, portes refermées.`
			else "Puissance remise à 1, portes refermées."
	end
	return {
		available = rebirth.available == true and SlotsModel.blocked(snapshot, "Rebirth") == nil,
		runId = tonumber(run.id) or 0,
		title = `RENAISSANCE {count + 1}`,
		keep = "Tu gardes : slots conservés, Baddies Book, maîtrises, compagnons, drops en attente et tickets.",
		lose = if rebirth.promotesNext then lose else `Tu perds : {lose}`,
		rewards = `+{rebirth.baddieTickets or 0} tickets baddie, +{rebirth.crewTickets or 0} ticket compagnon, entraînement +10 %.`,
	}
end

-- Texte d'une réponse de décision durable (Result kind = "mutation")
function SlotsModel.resultText(event: { [string]: any }, catalog: any): string?
	if event.kind ~= "mutation" then
		return nil
	end
	if not event.ok then
		return `Refusé : {SlotsModel.reasonText(event.reason)}`
	end
	local r = event.result or {}
	local action = event.action
	if action == "Roll" then
		local new = if r.isNew then " · NOUVELLE !" else ""
		local guaranteed = if r.guaranteed then " (garantie)" else ""
		return `SLOT : {nameOf(r.previousId, catalog)} → {nameOf(r.baddieId, catalog)}{guaranteed}{new}`
	elseif action == "AcceptDrop" then
		return `{nameOf(r.baddieId, catalog)} rejoint ton slot temporaire`
	elseif action == "RefuseDrop" then
		return `Drop de {nameOf(r.baddieId, catalog)} refusé`
	elseif action == "OpenChest" then
		local def = catalog.crew[r.crewId]
		local name = if def then string.upper(def.name) else "?"
		return if r.isNew then `Coffre : {name} rejoint ton crew !` else `Coffre : {name}, +1 copie`
	elseif action == "Rebirth" then
		return `Renaissance {r.count} : nouveau parcours !`
	end
	return nil
end

return SlotsModel
