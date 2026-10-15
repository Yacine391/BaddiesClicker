--!strict
--[[
	Succès internes et garde-robe (module pur, testé dans tests/run.luau). Dossier §19.
	Configuration (noms, récompenses, listes V1 figées) : Shared/Wardrobe, passé dans ctx.Wardrobe.

	- Un succès est accordé UNE fois : ses récompenses (cosmétiques, titres) sont permanentes,
	  et il est mis en attente de badge Roblox (pendingBadges) sans jamais redonner les récompenses.
	- Conditions lues sur le profil, côté serveur uniquement ; le client n'annonce jamais un succès.
	- Style : un cosmétique par emplacement, possédé et du bon emplacement ; un titre possédé.
]]

export type Earned = { id: string, items: { string }, titles: { string } }

local Achievements = {}

local function all(list: { string }, has: (string) -> boolean): boolean
	for _, id in list do
		if not has(id) then
			return false
		end
	end
	return true
end

local function bookV1(data: any, ctx: any): boolean
	return all(ctx.Wardrobe.lotV1.baddies, function(id)
		return data.discoveredBaddies[id] == true
	end)
end

local function crewV1(data: any, ctx: any): boolean
	return all(ctx.Wardrobe.lotV1.crew, function(id)
		return data.crew[id] ~= nil
	end)
end

-- Conditions serveur (lecture seule). Une renaissance implique les étapes du parcours précédent.
Achievements.conditions = {
	first_training = function(data: any, ctx: any): boolean
		return data.stats.trainActions >= ctx.Balance.achievements.trainActions
	end,
	first_look = function(data: any, ctx: any): boolean
		local xp = data.masteryXP[ctx.Balance.tutorial.starterBaddieId] or 0
		return ctx.Formulas.masteryLevel(xp, ctx.Balance.mastery) >= ctx.Balance.achievements.lookMastery
	end,
	first_boss = function(data: any, _ctx: any): boolean
		return data.run.firstClearRewards["1"] == true or data.rebirths >= 1
	end,
	first_crew = function(data: any, ctx: any): boolean
		return data.crew[ctx.Balance.tutorial.starterCrewId] ~= nil
	end,
	run_complete = function(data: any, ctx: any): boolean
		return data.run.clearedLevels[tostring(#ctx.Balance.levels)] == true or data.rebirths >= 1
	end,
	first_rebirth = function(data: any, _ctx: any): boolean
		return data.rebirths >= 1
	end,
	book_baddies_v1 = bookV1,
	book_crew_v1 = crewV1,
	mythic_found = function(data: any, _ctx: any): boolean
		return data.discoveredBaddies.vega == true -- un drop en attente ne compte pas
	end,
	collection_v1 = function(data: any, ctx: any): boolean
		return bookV1(data, ctx) and crewV1(data, ctx)
	end,
} :: { [string]: (any, any) -> boolean }

-- Accorde un succès et ses récompenses (une seule fois)
function Achievements.grant(data: any, id: string, ctx: any): Earned
	local def = ctx.Wardrobe.achievements[id]
	assert(def ~= nil, `succès inconnu : {id}`)
	data.achievements[id] = true
	data.pendingBadges[id] = true -- badge Roblox à attribuer s'il est configuré (réessayé sans redonner)
	local items, titles = {}, {}
	for _, item in def.rewards.items or {} do
		if data.wardrobe[item] ~= true then
			data.wardrobe[item] = true
			table.insert(items, item)
		end
	end
	for _, title in def.rewards.titles or {} do
		if data.titles[title] ~= true then
			data.titles[title] = true
			table.insert(titles, title)
		end
	end
	return { id = id, items = items, titles = titles }
end

-- Vérifie tous les succès pas encore obtenus ; renvoie ceux accordés maintenant
function Achievements.check(data: any, ctx: any): { Earned }
	local earned: { Earned } = {}
	for _, id in ctx.Wardrobe.achievementOrder do
		local condition = Achievements.conditions[id]
		if data.achievements[id] ~= true and condition ~= nil and condition(data, ctx) then
			table.insert(earned, Achievements.grant(data, id, ctx))
		end
	end
	return earned
end

--[[ Style : SetStyle { slot, id? } — slot = un emplacement de Wardrobe.slots, ou "title" ]]

-- Raisons : "invalid", "unknown", "wrong_slot", "locked"
function Achievements.setStyle(data: any, slot: any, id: any, ctx: any): string?
	local W = ctx.Wardrobe
	if type(slot) ~= "string" or (slot ~= "title" and W.slotLabels[slot] == nil) then
		return "invalid"
	end
	if id == nil or id == "" then
		data.style[slot] = nil -- retirer
		return nil
	end
	if type(id) ~= "string" then
		return "invalid"
	end
	if slot == "title" then
		if W.titles[id] == nil then
			return "unknown"
		end
		if data.titles[id] ~= true then
			return "locked"
		end
	else
		local item = W.items[id]
		if item == nil then
			return "unknown"
		end
		if item.slot ~= slot then
			return "wrong_slot"
		end
		if data.wardrobe[id] ~= true then
			return "locked"
		end
	end
	data.style[slot] = id
	return nil
end

export type StyleView = {
	items: { string },
	titles: { string },
	equipped: { [string]: string },
	title: string?,
	achievements: { string },
	achievementTotal: number,
}

-- Vue du client : possédés et succès dans l'ordre de la configuration, sélection courante
function Achievements.view(data: any, ctx: any): StyleView
	local W = ctx.Wardrobe
	local items, titles, earned = {}, {}, {}
	for _, id in W.itemOrder do
		if data.wardrobe[id] == true then
			table.insert(items, id)
		end
	end
	for _, id in W.titleOrder do
		if data.titles[id] == true then
			table.insert(titles, id)
		end
	end
	for _, id in W.achievementOrder do
		if data.achievements[id] == true then
			table.insert(earned, id)
		end
	end
	local equipped = {}
	for _, slot in W.slots do
		if data.style[slot] ~= nil then
			equipped[slot] = data.style[slot]
		end
	end
	return {
		items = items,
		titles = titles,
		equipped = equipped,
		title = data.style.title,
		achievements = earned,
		achievementTotal = #W.achievementOrder,
	}
end

-- Pour les autres joueurs (attribut BC_Style) : "neck=chain_gold,frame=frame_v1"
function Achievements.publicStyle(data: any, ctx: any): string
	local parts = {}
	for _, slot in ctx.Wardrobe.slots do
		if data.style[slot] ~= nil then
			table.insert(parts, `{slot}={data.style[slot]}`)
		end
	end
	return table.concat(parts, ",")
end

return Achievements
