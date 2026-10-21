--!strict
--[[
	BookModel : Baddies Book (§15, spec refonte §5) — cartes de la grille, fiche de détail,
	exposition. Distingue PRINCIPALE (seule source de multiplicateur) et EXPOSÉE (apparence
	uniquement). Sans `collection` (contrat v1), seule la principale est découverte et
	l'exposition n'est pas proposée (pas de faux bouton).
	Pur : Catalog et Format.number sont passés en paramètres (tests/client/run.luau).
]]

export type Chip = { text: string, colorKey: "Principal" | "Accent" | "TextDim" }

export type Card = {
	id: string,
	name: string,
	discovered: boolean,
	rarityLabel: string,
	rarityColor: string,
	color: string, -- couleur de la silhouette (palette du Catalog)
	chip: Chip?,
}

export type Detail = {
	id: string,
	name: string,
	discovered: boolean,
	rarityLabel: string,
	rarityColor: string,
	color: string,
	isPrincipal: boolean,
	slotText: string,
	multiplierText: string,
	masteryText: string,
	masteryRatio: number,
	looksText: string,
	displayed: boolean,
	canToggleDisplay: boolean,
	displayFullText: string?,
	chanceText: string?,
}

local BookModel = {}

local MAX_DISPLAY = 3
local MAX_MASTERY = 10
local UNKNOWN_COLOR = "#8A84A3"

local function testName(id: string): string
	return string.upper((string.gsub(id, "_", " ")))
end

local function collectionOf(snapshot: any): any?
	return if type(snapshot.collection) == "table" then snapshot.collection else nil
end

local function discoveredOf(snapshot: any): { string }
	local collection = collectionOf(snapshot)
	if collection and type(collection.discovered) == "table" then
		return collection.discovered
	end
	local active = snapshot.active
	if type(active) == "table" and type(active.baddieId) == "string" then
		return { active.baddieId }
	end
	return {}
end

local function displayOf(snapshot: any): { string }
	local collection = collectionOf(snapshot)
	return if collection and type(collection.display) == "table" then collection.display else {}
end

local function principalOf(snapshot: any): (string?, string)
	local active = snapshot.active
	if type(active) ~= "table" or type(active.baddieId) ~= "string" then
		return nil, ""
	end
	local slot = if type(active.slotId) == "string" then string.upper(active.slotId) else "S1"
	return active.baddieId, slot
end

local function identity(catalog: any, id: string): (string, string, string, string)
	local def = catalog.baddies[id]
	if def == nil then
		return testName(id), "Test", UNKNOWN_COLOR, UNKNOWN_COLOR
	end
	local rarity = catalog.rarities[def.rarity]
	local rarityColor = if rarity then rarity.color else UNKNOWN_COLOR
	local color = if def.palette then def.palette[#def.palette] else rarityColor
	return string.upper(def.name), if rarity then rarity.label else def.rarity, rarityColor, color
end

-- Grille : ordre du catalogue, puis identités de test découvertes (Studio)
function BookModel.cards(snapshot: any, catalog: any, format: (number) -> string): { Card }
	local discovered = discoveredOf(snapshot)
	local display = displayOf(snapshot)
	local principal, slot = principalOf(snapshot)
	local ids = table.clone(catalog.baddieOrder)
	for _, id in discovered do
		if catalog.baddies[id] == nil and not table.find(ids, id) then
			table.insert(ids, id)
		end
	end
	local cards: { Card } = {}
	for _, id in ids do
		local name, rarityLabel, rarityColor, color = identity(catalog, id)
		local found = table.find(discovered, id) ~= nil
		local chip: Chip? = nil
		if id == principal then
			chip = { text = "PRINCIPALE · " .. slot, colorKey = "Principal" }
		elseif found and table.find(display, id) then
			chip = { text = "EXPOSÉE", colorKey = "Accent" }
		elseif not found then
			chip = { text = format(catalog.baddies[id].rollChance) .. " %", colorKey = "TextDim" }
		end
		table.insert(cards, {
			id = id,
			name = if found then name else "???",
			discovered = found,
			rarityLabel = rarityLabel,
			rarityColor = rarityColor,
			color = color,
			chip = chip,
		})
	end
	return cards
end

function BookModel.detail(snapshot: any, catalog: any, format: (number) -> string, id: string): Detail
	local discovered = table.find(discoveredOf(snapshot), id) ~= nil
	local display = displayOf(snapshot)
	local collection = collectionOf(snapshot)
	local principal, slot = principalOf(snapshot)
	local isPrincipal = id == principal
	local def = catalog.baddies[id]
	local name, rarityLabel, rarityColor, color = identity(catalog, id)

	local multiplier = if def then def.multiplier else 1
	local mastery = 0
	if isPrincipal then
		multiplier = tonumber(snapshot.active.multiplier) or multiplier
		mastery = tonumber(snapshot.active.masteryLevel) or 0
	end
	local totalLooks = if def and def.looks then #def.looks else 0
	local looks = collection and type(collection.looks) == "table" and collection.looks[id]
	local unlocked = if looks and type(looks.unlocked) == "table"
		then #looks.unlocked
		else math.min(1, totalLooks)
	local displayed = table.find(display, id) ~= nil

	return {
		id = id,
		name = if discovered then name else "???",
		discovered = discovered,
		rarityLabel = rarityLabel,
		rarityColor = rarityColor,
		color = color,
		isPrincipal = isPrincipal,
		slotText = slot,
		multiplierText = "×" .. format(multiplier),
		masteryText = if isPrincipal then "Niv. " .. tostring(mastery) else "—",
		masteryRatio = if isPrincipal then math.clamp(mastery / MAX_MASTERY, 0, 1) else 0,
		looksText = if totalLooks > 0 then `{unlocked}/{totalLooks}` else "—",
		displayed = displayed,
		-- SetDisplay est refusé par le serveur en combat : pas de bouton EXPOSER à ce moment-là
		canToggleDisplay = discovered
			and collection ~= nil
			and snapshot.mode ~= "combat"
			and (displayed or #display < MAX_DISPLAY),
		-- Exposition pleine : bouton grisé « EXPOSITION PLEINE 3/3 » (il faut d'abord en retirer une)
		displayFullText = if discovered
				and collection ~= nil
				and snapshot.mode ~= "combat"
				and not displayed
				and #display >= MAX_DISPLAY
			then `EXPOSITION PLEINE {#display}/{MAX_DISPLAY}`
			else nil,
		chanceText = if def and not discovered then format(def.rollChance) .. " %" else nil,
	}
end

-- Nouvelle liste d'exposition (SetDisplay remplace toute la liste)
function BookModel.toggleDisplay(display: { string }, id: string): { string }
	local ids = table.clone(display)
	local index = table.find(ids, id)
	if index then
		table.remove(ids, index)
	else
		table.insert(ids, id)
	end
	return ids
end

function BookModel.counts(
	snapshot: any,
	catalog: any
): { baddies: number, baddiesTotal: number, crew: number, crewTotal: number }
	local baddies = 0
	for _, id in discoveredOf(snapshot) do
		if catalog.baddies[id] ~= nil then
			baddies += 1
		end
	end
	local crewList = if type(snapshot.crewOwned) == "table"
		then snapshot.crewOwned
		elseif type(snapshot.crew) == "table" then snapshot.crew
		else {}
	return {
		baddies = baddies,
		baddiesTotal = #catalog.baddieOrder,
		crew = #crewList,
		crewTotal = #catalog.crewOrder,
	}
end

return BookModel
