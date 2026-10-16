--!strict
--[[
	CrewModel : règles d'affichage des actions de la fenêtre Crew (§16). Module pur, testé.
	Le serveur revérifie tout (Rules/Crew) ; ici on ne propose que des boutons qui ont un sens.
]]

local CrewModel = {}

-- Copies à dépenser pour passer au niveau suivant (L + 1), nil au niveau maximum
function CrewModel.upgradeCost(level: number, maxLevel: number): number?
	if level >= maxLevel then
		return nil
	end
	return level + 1
end

function CrewModel.canUpgrade(entry: { [string]: any }, maxLevel: number): boolean
	local cost = CrewModel.upgradeCost(tonumber(entry.level) or 1, maxLevel)
	return cost ~= nil and (tonumber(entry.copies) or 0) >= cost
end

-- Nouvelle liste d'équipe (EquipCrew remplace la liste) ; nil si l'équipe est pleine
function CrewModel.toggleEquip(equipped: { string }, id: string, max: number): { string }?
	local ids = table.clone(equipped)
	local index = table.find(ids, id)
	if index ~= nil then
		table.remove(ids, index)
		return ids
	end
	if #ids >= max then
		return nil
	end
	table.insert(ids, id)
	return ids
end

function CrewModel.equippedIds(snapshot: { [string]: any }?): { string }
	local ids = {}
	for _, entry in (snapshot and snapshot.crewOwned) or {} do
		if entry.equipped == true then
			table.insert(ids, entry.id)
		end
	end
	return ids
end

function CrewModel.chestText(snapshot: { [string]: any }?): string
	local tickets = tonumber(snapshot and snapshot.tickets and snapshot.tickets.crew) or 0
	local chest = (snapshot and snapshot.crewChest) or {}
	local guarantee = if chest.complete
		then "collection complète"
		elseif tonumber(chest.untilGuarantee) == 1 then "le prochain est garanti"
		else `garanti dans {chest.untilGuarantee or "?"}`
	return `{tickets} ticket{if tickets > 1 then "s" else ""} compagnon · {guarantee}`
end

return CrewModel
