--!strict
--[[
	ProfileGuard : migrations et garde-fous du profil au chargement (module pur, testé). Dossier §24, §27, §36.
	Profiles l'appelle juste après Reconcile, avant que le moindre service ne lise le profil.

	- migrate : applique les migrations EXPLICITES depuis `schemaVersion` jusqu'à la version courante.
	  Le schéma 4 est le premier réellement utilisé : aucune migration de vrais joueurs n'est inventée.
	  Une migration manquante ou un schéma plus récent → refus du chargement (jamais de profil abîmé).
	- repair : vérifie les invariants et corrige ce qui est sûr. Ne supprime JAMAIS en silence une découverte,
	  un drop en attente ou une baddie : une identité inconnue du catalogue reste archivée dans le profil
	  (et ignorée par le jeu) ; seuls des nombres impossibles et des listes incohérentes sont corrigés.
	  Renvoie la liste des corrections, pour le journal serveur.

	Invariants (§24) : nombres finis et bornés (ni NaN ni infini) ; un seul temporaire ; la principale est un
	slot rempli d'une identité connue ; toute baddie possédée est découverte ; exposition = 3 identités
	découvertes sans doublon ; équipe = 2 compagnons possédés distincts ; quantités jamais négatives ;
	cosmétiques et titre portés = débloqués et au bon emplacement.
]]

export type Migration = (data: any, ctx: any) -> ()

local ProfileGuard = {}

-- [n] = fonction qui fait passer un profil du schéma n au schéma n + 1 (tester chaque entrée avec une fixture)
ProfileGuard.migrations = {} :: { [number]: Migration }

function ProfileGuard.migrate(data: any, ctx: any): (boolean, string?)
	local target = ctx.Balance.save.schemaVersion
	local version = data.schemaVersion
	if type(version) ~= "number" or version ~= math.floor(version) or version < 1 then
		return false, `schemaVersion invalide : {tostring(version)}`
	end
	if version > target then
		return false, `schéma {version} plus récent que le serveur ({target})`
	end
	while version < target do
		local step = ProfileGuard.migrations[version]
		if step == nil then
			return false, `migration manquante : schéma {version} → {version + 1}`
		end
		step(data, ctx)
		version += 1
		data.schemaVersion = version
	end
	return true, nil
end

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Nombre fini, borné et (si demandé) entier ; sinon valeur corrigée et note au journal
local function number(
	issues: { string },
	label: string,
	value: any,
	min: number,
	max: number,
	integer: boolean,
	default: number
): number
	if not isFinite(value) then
		table.insert(issues, `{label} invalide ({tostring(value)}) → {default}`)
		return default
	end
	local fixed = if integer then math.floor(value) else value
	fixed = math.clamp(fixed, min, max)
	if fixed ~= value then
		table.insert(issues, `{label} {value} → {fixed}`)
	end
	return fixed
end

local function isEmpty(slot: any): boolean
	return slot.baddieId == nil or slot.baddieId == ""
end

local function tableOr(issues: { string }, label: string, value: any): { [any]: any }
	if type(value) ~= "table" then
		table.insert(issues, `{label} absent → vide`)
		return {}
	end
	return value
end

local function repairSlots(data: any, ctx: any, issues: { string })
	local C = ctx.Catalog
	data.slots = tableOr(issues, "slots", data.slots)
	local count = 0
	for id, slot in data.slots do
		if type(id) ~= "string" or type(slot) ~= "table" then
			table.insert(issues, `slot {tostring(id)} illisible → retiré`)
			data.slots[id] = nil
			continue
		end
		count += 1
		slot.order = number(issues, `{id}.order`, slot.order, 1, 99, true, count)
		if type(slot.baddieId) ~= "string" then
			table.insert(issues, `{id}.baddieId invalide → vide`)
			slot.baddieId = ""
		end
		slot.conserved = slot.conserved == true
		slot.rollLocked = slot.rollLocked == true
		slot.slotRevision = number(issues, `{id}.slotRevision`, slot.slotRevision, 0, 1e9, true, 0)
		local id2 = slot.baddieId
		if id2 ~= "" and C.baddies[id2] ~= nil and data.discoveredBaddies[id2] ~= true then
			table.insert(issues, `{id} contient {id2} non découverte → découverte`)
			data.discoveredBaddies[id2] = true
		end
		if id2 ~= "" and C.baddies[id2] ~= nil and data.masteryXP[id2] == nil then
			data.masteryXP[id2] = 0
		end
		if id2 ~= "" and C.baddies[id2] == nil then
			table.insert(issues, `{id} contient une identité inconnue ({id2}) : archivée, inutilisable`)
		end
	end

	-- Un seul temporaire : le plus récent garde ce rôle, les autres deviennent conservés (aucun contenu perdu)
	local temporaries = {}
	for id, slot in data.slots do
		if not slot.conserved then
			table.insert(temporaries, id)
		end
	end
	table.sort(temporaries, function(a, b)
		return data.slots[a].order > data.slots[b].order
	end)
	for i = 2, #temporaries do
		table.insert(issues, `{temporaries[i]} : second temporaire → conservé`)
		data.slots[temporaries[i]].conserved = true
	end
	if #temporaries == 0 then
		local order = 0
		for _, slot in data.slots do
			order = math.max(order, slot.order)
		end
		order += 1
		local id = `s{order}`
		while data.slots[id] ~= nil do
			order += 1
			id = `s{order}`
		end
		data.slots[id] =
			{ order = order, conserved = false, baddieId = "", slotRevision = 0, rollLocked = false }
		table.insert(issues, `aucun temporaire → {id} ouvert`)
	end

	-- Capacité attendue (§24) : signalée seulement, jamais corrigée en silence
	local expected = 0
	for _, at in ctx.Balance.rebirth.promotionAt do
		if data.rebirths >= at then
			expected += 1
		end
	end
	local conserved = 0
	for _, slot in data.slots do
		if slot.conserved then
			conserved += 1
		end
	end
	if conserved ~= expected then
		table.insert(
			issues,
			`capacité : {conserved} slot(s) conservé(s) pour {expected} attendu(s) (non corrigé)`
		)
	end

	-- Principale : un slot rempli d'une identité connue
	local active = data.slots[data.activeSlotId]
	if
		type(data.activeSlotId) ~= "string"
		or active == nil
		or isEmpty(active)
		or C.baddies[active.baddieId] == nil
	then
		local best, bestMultiplier = nil, -math.huge
		for id, slot in data.slots do
			local def = if isEmpty(slot) then nil else C.baddies[slot.baddieId]
			if
				def ~= nil
				and (
					def.multiplier > bestMultiplier
					or (
						def.multiplier == bestMultiplier
						and best ~= nil
						and slot.order < data.slots[best].order
					)
				)
			then
				best, bestMultiplier = id, def.multiplier
			end
		end
		if best == nil then
			-- Secours : Maya dans un slot vide (le temporaire de préférence), sinon dans le temporaire
			local starter = ctx.Balance.tutorial.starterBaddieId
			local target = nil
			for id, slot in data.slots do
				if isEmpty(slot) and (target == nil or not slot.conserved) then
					target = id
				end
			end
			if target == nil then
				for id, slot in data.slots do
					if not slot.conserved then
						target = id
					end
				end
			end
			assert(target ~= nil, "aucun slot")
			local slot = data.slots[target]
			slot.baddieId = starter
			slot.slotRevision += 1
			data.discoveredBaddies[starter] = true
			if data.masteryXP[starter] == nil then
				data.masteryXP[starter] = 0
			end
			best = target
			table.insert(issues, `aucune principale possible → {starter} installée dans {target}`)
		else
			table.insert(issues, `principale {tostring(data.activeSlotId)} invalide → {best}`)
		end
		data.activeSlotId = best
	end
end

function ProfileGuard.repair(data: any, ctx: any): { string }
	local B, C = ctx.Balance, ctx.Catalog
	local L = B.limits
	local issues: { string } = {}

	-- Nombres de premier niveau
	data.power = number(issues, "power", data.power, 0, L.maxPower, false, B.power.start)
	data.rebirths = number(issues, "rebirths", data.rebirths, 0, L.maxCounter, true, 0)
	data.revision = number(issues, "revision", data.revision, 0, L.maxCounter, true, 0)
	data.pendingRevision = number(issues, "pendingRevision", data.pendingRevision, 0, L.maxCounter, true, 0)

	data.tickets = tableOr(issues, "tickets", data.tickets)
	data.tickets.baddie = number(issues, "tickets.baddie", data.tickets.baddie, 0, L.maxTickets, true, 0)
	data.tickets.crew = number(issues, "tickets.crew", data.tickets.crew, 0, L.maxTickets, true, 0)
	data.rolls = tableOr(issues, "rolls", data.rolls)
	data.rolls.baddie = number(issues, "rolls.baddie", data.rolls.baddie, 0, L.maxCounter, true, 0)
	data.rolls.crew = number(issues, "rolls.crew", data.rolls.crew, 0, L.maxCounter, true, 0)
	data.trainCounters = tableOr(issues, "trainCounters", data.trainCounters)
	data.trainCounters.baddie =
		number(issues, "trainCounters.baddie", data.trainCounters.baddie, 0, L.maxCounter, true, 0)
	data.trainCounters.crew =
		number(issues, "trainCounters.crew", data.trainCounters.crew, 0, L.maxCounter, true, 0)
	data.stats = tableOr(issues, "stats", data.stats)
	data.stats.trainActions =
		number(issues, "stats.trainActions", data.stats.trainActions, 0, L.maxCounter, true, 0)
	data.stats.crewPowerEarned =
		number(issues, "stats.crewPowerEarned", data.stats.crewPowerEarned, 0, L.maxPower, false, 0)

	-- Parcours : portes et premiers passages = clés "1".."10" à true
	data.run = tableOr(issues, "run", data.run)
	data.run.id = number(issues, "run.id", data.run.id, 1, L.maxCounter, true, 1)
	data.run.attempt = number(issues, "run.attempt", data.run.attempt, 1, L.maxCounter, true, 1)
	for _, field in { "clearedLevels", "firstClearRewards" } do
		local map = tableOr(issues, `run.{field}`, data.run[field])
		data.run[field] = map
		for key, value in map do
			local levelId = tonumber(key)
			local valid = type(key) == "string"
				and levelId ~= nil
				and levelId == math.floor(levelId)
				and levelId >= 1
				and levelId <= #B.levels
				and value == true
			if not valid then
				table.insert(issues, `run.{field}[{tostring(key)}] invalide → retiré`)
				map[key] = nil
			end
		end
	end

	-- Baddies Book et maîtrise (les identités inconnues restent archivées)
	data.discoveredBaddies = tableOr(issues, "discoveredBaddies", data.discoveredBaddies)
	for id, value in data.discoveredBaddies do
		if value ~= true then
			table.insert(issues, `discoveredBaddies[{tostring(id)}] = {tostring(value)} → retiré`)
			data.discoveredBaddies[id] = nil
		end
	end
	data.masteryXP = tableOr(issues, "masteryXP", data.masteryXP)
	for id, xp in data.masteryXP do
		data.masteryXP[id] = number(issues, `masteryXP.{tostring(id)}`, xp, 0, L.maxMasteryXP, false, 0)
	end

	repairSlots(data, ctx, issues)

	-- Drops en attente : quantités entières positives ; une quantité nulle ou impossible n'est pas un drop
	data.pendingDrops = tableOr(issues, "pendingDrops", data.pendingDrops)
	for id, count in data.pendingDrops do
		if not isFinite(count) or count < 1 then
			table.insert(issues, `pendingDrops.{tostring(id)} = {tostring(count)} → retiré`)
			data.pendingDrops[id] = nil
		else
			data.pendingDrops[id] =
				number(issues, `pendingDrops.{id}`, count, 1, L.maxPendingPerBaddie, true, 1)
		end
		if C.baddies[id] == nil then
			table.insert(issues, `pendingDrops : identité inconnue ({tostring(id)}) archivée`)
		end
	end

	-- Exposition : 3 identités connues, découvertes, sans doublon
	local display, seen = {}, {}
	local rawDisplay = tableOr(issues, "displayBaddies", data.displayBaddies)
	for _, id in rawDisplay do
		if
			type(id) == "string"
			and C.baddies[id] ~= nil
			and data.discoveredBaddies[id] == true
			and not seen[id]
			and #display < B.collection.maxDisplay
		then
			seen[id] = true
			table.insert(display, id)
		end
	end
	if #display ~= #rawDisplay then
		table.insert(issues, `displayBaddies : {#rawDisplay} → {#display} identité(s)`)
	end
	data.displayBaddies = display

	data.selectedLooks = tableOr(issues, "selectedLooks", data.selectedLooks)
	for id, look in data.selectedLooks do
		if not isFinite(look) or look ~= math.floor(look) or look < 1 or look > #B.looks.unlockAtMastery then
			table.insert(issues, `selectedLooks.{tostring(id)} invalide → retiré`)
			data.selectedLooks[id] = nil
		end
	end

	-- Compagnons : niveaux 1..10, copies bornées ; équipe = 2 possédés distincts
	data.crew = tableOr(issues, "crew", data.crew)
	for id, entry in data.crew do
		if type(entry) ~= "table" then
			table.insert(issues, `crew.{tostring(id)} illisible → niveau 1`)
			entry = { level = 1, copies = 0 }
			data.crew[id] = entry
		end
		entry.level = number(issues, `crew.{id}.level`, entry.level, 1, B.crew.maxLevel, true, 1)
		entry.copies = number(issues, `crew.{id}.copies`, entry.copies, 0, L.maxCopies, true, 0)
	end
	local equipped, equippedSeen = {}, {}
	local rawEquipped = tableOr(issues, "equippedCrew", data.equippedCrew)
	for _, id in rawEquipped do
		if
			type(id) == "string"
			and C.crew[id] ~= nil
			and data.crew[id] ~= nil
			and not equippedSeen[id]
			and #equipped < B.crew.maxEquipped
		then
			equippedSeen[id] = true
			table.insert(equipped, id)
		end
	end
	if #equipped ~= #rawEquipped then
		table.insert(issues, `equippedCrew : {#rawEquipped} → {#equipped} compagnon(s)`)
	end
	data.equippedCrew = equipped

	-- Garde-robe (§19) : déblocages = maps à true (IDs inconnus archivés) ; sélection possédée et au bon emplacement
	for _, field in { "wardrobe", "titles", "achievements", "pendingBadges" } do
		local map = tableOr(issues, field, data[field])
		data[field] = map
		for id, value in map do
			if value ~= true then
				table.insert(issues, `{field}[{tostring(id)}] = {tostring(value)} → retiré`)
				map[id] = nil
			end
		end
	end
	data.style = tableOr(issues, "style", data.style)
	local W = ctx.Wardrobe
	if W ~= nil then
		for slot, id in data.style do
			local valid
			if slot == "title" then
				valid = type(id) == "string" and W.titles[id] ~= nil and data.titles[id] == true
			else
				local item = if type(id) == "string" then W.items[id] else nil
				valid = type(slot) == "string"
					and W.slotLabels[slot] ~= nil
					and item ~= nil
					and item.slot == slot
					and data.wardrobe[id] == true
			end
			if not valid then
				table.insert(issues, `style.{tostring(slot)} = {tostring(id)} non débloqué → retiré`)
				data.style[slot] = nil
			end
		end
	end

	if type(data.lastMutation) ~= "table" then
		data.lastMutation = {}
	end

	return issues
end

return ProfileGuard
