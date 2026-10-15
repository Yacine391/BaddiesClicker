--!strict
--[[
	Baddies Book, exposition et looks (module pur, testé dans tests/run.luau). Dossier §03, §15.
	Implémente la proposition « contrat v2 » du codeur B (docs/proposals/2026-10-14-contract-v2-collection.md).

	- Découvert : obtenu par le personnage initial, une relance ou un drop accepté. Jamais retiré.
	- Exposition : 3 places, sans doublon, identités découvertes seulement. APPARENCE UNIQUEMENT :
	  l'exposition n'entre dans aucune formule (dégâts, multiplicateur, gains).
	- Looks : le look 1 à la découverte, le 2 à maîtrise 1, le 3 à maîtrise 5 (Balance.looks.unlockAtMastery).
	  Les looks débloqués sont DÉRIVÉS de la maîtrise, jamais stockés ; seul le choix est stocké (selectedLooks).
	- Identités de test (Studio) : ajoutées après les identités publiques, jamais comptées dans le Book.
]]

export type LookState = { unlocked: { number }, selected: number }

export type View = {
	discovered: { string },
	display: { string },
	looks: { [string]: LookState },
	bookCount: number,
	bookTotal: number,
}

local Collection = {}

local MAX_ID_LENGTH = 32

-- Nombre de looks d'une identité : ses looks nommés (bornés aux paliers), sinon un par palier
function Collection.lookCount(def: any, ctx: any): number
	local thresholds = #ctx.Balance.looks.unlockAtMastery
	local named = if def ~= nil and def.looks ~= nil then #def.looks else 0
	return if named > 0 then math.min(named, thresholds) else thresholds
end

function Collection.unlockedLooks(data: any, baddieId: string, ctx: any): { number }
	local def = ctx.Catalog.baddies[baddieId]
	if def == nil or data.discoveredBaddies[baddieId] ~= true then
		return {}
	end
	local mastery = ctx.Formulas.masteryLevel(data.masteryXP[baddieId] or 0, ctx.Balance.mastery)
	local list = {}
	for index = 1, Collection.lookCount(def, ctx) do
		if mastery >= ctx.Balance.looks.unlockAtMastery[index] then
			table.insert(list, index)
		end
	end
	return list
end

-- Look porté : le choix stocké s'il est encore débloqué, sinon le plus haut débloqué (1 par défaut)
function Collection.selectedLook(data: any, baddieId: string, ctx: any): number
	local unlocked = Collection.unlockedLooks(data, baddieId, ctx)
	local wanted = data.selectedLooks[baddieId]
	if wanted == nil and #unlocked > 0 then
		return 1
	end
	if wanted ~= nil and table.find(unlocked, wanted) ~= nil then
		return wanted
	end
	return unlocked[#unlocked] or 1
end

-- Découvertes : ordre public du catalogue, puis identités de test (Studio uniquement)
function Collection.discoveredList(data: any, ctx: any): { string }
	local list = {}
	for _, id in ctx.Catalog.baddieOrder do
		if data.discoveredBaddies[id] == true then
			table.insert(list, id)
		end
	end
	for _, id in ctx.Catalog.testOrder or {} do
		if data.discoveredBaddies[id] == true then
			table.insert(list, id)
		end
	end
	return list
end

-- Progression du Baddies Book : identités publiques découvertes / total du lot
function Collection.bookCount(data: any, ctx: any): (number, number)
	local count = 0
	for _, id in ctx.Catalog.baddieOrder do
		if data.discoveredBaddies[id] == true then
			count += 1
		end
	end
	return count, #ctx.Catalog.baddieOrder
end

-- Exposition valide (filtre un profil ancien ou une identité de test absente du catalogue)
function Collection.displayList(data: any, ctx: any): { string }
	local list = {}
	for _, id in data.displayBaddies do
		if ctx.Catalog.baddies[id] ~= nil and data.discoveredBaddies[id] == true then
			table.insert(list, id)
		end
	end
	return list
end

function Collection.view(data: any, ctx: any): View
	local discovered = Collection.discoveredList(data, ctx)
	local looks: { [string]: LookState } = {}
	for _, id in discovered do
		looks[id] = {
			unlocked = Collection.unlockedLooks(data, id, ctx),
			selected = Collection.selectedLook(data, id, ctx),
		}
	end
	local count, total = Collection.bookCount(data, ctx)
	return {
		discovered = discovered,
		display = Collection.displayList(data, ctx),
		looks = looks,
		bookCount = count,
		bookTotal = total,
	}
end

-- SetDisplay { ids } : remplace toute la liste. Raisons : "invalid", "too_many", "unknown", "undiscovered", "duplicate"
function Collection.checkDisplay(data: any, ids: any, ctx: any): string?
	if type(ids) ~= "table" then
		return "invalid"
	end
	local keys = 0
	for _ in ids do
		keys += 1
	end
	if keys ~= #ids then
		return "invalid" -- pas un tableau simple
	end
	if #ids > ctx.Balance.collection.maxDisplay then
		return "too_many"
	end
	local seen = {}
	for _, id in ids do
		if type(id) ~= "string" or #id > MAX_ID_LENGTH then
			return "invalid"
		end
		if ctx.Catalog.baddies[id] == nil then
			return "unknown"
		end
		if data.discoveredBaddies[id] ~= true then
			return "undiscovered"
		end
		if seen[id] then
			return "duplicate"
		end
		seen[id] = true
	end
	return nil
end

function Collection.setDisplay(data: any, ids: any, ctx: any): string?
	local reason = Collection.checkDisplay(data, ids, ctx)
	if reason ~= nil then
		return reason
	end
	local list = {}
	for _, id in ids do
		table.insert(list, id)
	end
	data.displayBaddies = list
	return nil
end

-- SetLook { baddieId, look }. Raisons : "unknown", "undiscovered", "invalid", "locked"
function Collection.setLook(data: any, baddieId: any, look: any, ctx: any): string?
	if type(baddieId) ~= "string" or ctx.Catalog.baddies[baddieId] == nil then
		return "unknown"
	end
	if data.discoveredBaddies[baddieId] ~= true then
		return "undiscovered"
	end
	if type(look) ~= "number" or look ~= math.floor(look) then
		return "invalid"
	end
	if table.find(Collection.unlockedLooks(data, baddieId, ctx), look) == nil then
		return "locked"
	end
	data.selectedLooks[baddieId] = look
	return nil
end

return Collection
