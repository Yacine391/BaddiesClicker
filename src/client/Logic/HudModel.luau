--!strict
--[[
	HudModel : transforme le snapshot serveur (docs/CONTRACT.md) en textes prêts à afficher.
	Pur : aucune API Roblox, aucun require. Catalog et Format.number sont passés en paramètres,
	ce qui le rend testable avec Lune (tests/client/run.luau).
	Tout champ absent du snapshot prend une valeur neutre : le HUD ne plante jamais.
]]

export type Principal = {
	name: string,
	rarityLabel: string,
	rarityColor: string,
	multiplierText: string,
	slotText: string,
}

export type Progress =
	{ visible: boolean, kind: "tutorial" | "run", title: string, value: number, max: number }

export type Card = {
	kind: "principal" | "crew",
	name: string,
	rarity: { label: string, color: string },
	line1: string,
	line2: string,
	accent: string,
}

export type HudView = {
	ready: boolean,
	powerText: string,
	productionText: string?,
	ticketText: string,
	principal: Principal?,
	tutorial: { visible: boolean, text: string, ratio: number },
	button: { label: string, colorKey: "Accent" | "Accent2" },
	progress: Progress,
	cards: { Card },
	bookCount: { discovered: number, total: number },
}

local HudModel = {}

local function principalOf(active: any, catalog: any, format: (number) -> string): Principal?
	if type(active) ~= "table" or type(active.baddieId) ~= "string" then
		return nil
	end
	local baddie = catalog.baddies[active.baddieId]
	if baddie == nil then
		return nil
	end
	local rarity = catalog.rarities[baddie.rarity]
	local slotNumber = if type(active.slotId) == "string" then tonumber(string.sub(active.slotId, 2)) else nil
	return {
		name = baddie.name,
		rarityLabel = if rarity then rarity.label else baddie.rarity,
		rarityColor = if rarity then rarity.color else "#FFFFFF",
		multiplierText = "×" .. format(tonumber(active.multiplier) or baddie.multiplier),
		slotText = "Slot " .. tostring(slotNumber or 1),
	}
end

local function productionOf(snapshot: any, catalog: any, format: (number) -> string): string?
	local crew = snapshot.crew
	if type(crew) ~= "table" or #crew == 0 then
		return nil
	end
	local rate = "+" .. format(tonumber(snapshot.passivePerSecond) or 0) .. "/s "
	if #crew == 1 then
		local def = catalog.crew[crew[1].id]
		return rate .. (if def then def.name else "Crew")
	end
	return rate .. "Crew"
end

local function discoveredCount(snapshot: any, catalog: any): number
	local collection = snapshot.collection
	if type(collection) == "table" and type(collection.discovered) == "table" then
		local count = 0
		for _, id in collection.discovered do
			if catalog.baddies[id] ~= nil then
				count += 1
			end
		end
		return count
	end
	local active = snapshot.active
	if type(active) == "table" and active.baddieId ~= nil and catalog.baddies[active.baddieId] ~= nil then
		return 1
	end
	return 0
end

-- Cartes de droite : principale puis jusqu'à 2 compagnons équipés (spec refonte §4)
local MAX_CREW_CARDS = 2
local function rarityOf(catalog: any, id: string): { label: string, color: string }
	local r = catalog.rarities[id]
	return if r then { label = r.label, color = r.color } else { label = id, color = "#FFFFFF" }
end

local function cardsOf(snapshot: any, catalog: any, format: (number) -> string): { Card }
	local cards: { Card } = {}
	local active = snapshot.active
	if type(active) == "table" and type(active.baddieId) == "string" then
		local baddie = catalog.baddies[active.baddieId]
		if baddie then
			local rarity = rarityOf(catalog, baddie.rarity)
			local slotNumber = if type(active.slotId) == "string"
				then tonumber(string.sub(active.slotId, 2))
				else nil
			table.insert(cards, {
				kind = "principal",
				name = string.upper(baddie.name),
				rarity = rarity,
				line1 = "×" .. format(tonumber(active.multiplier) or baddie.multiplier) .. " dégâts",
				line2 = "Principale · Slot " .. tostring(slotNumber or 1),
				accent = if baddie.palette then baddie.palette[#baddie.palette] else rarity.color,
			})
		end
	end
	local crew = snapshot.crew
	if type(crew) == "table" then
		local shown = 0
		for _, member in crew do
			local def = if type(member) == "table" then catalog.crew[member.id] else nil
			if def and shown < MAX_CREW_CARDS then
				shown += 1
				local rarity = rarityOf(catalog, def.rarity)
				table.insert(cards, {
					kind = "crew",
					name = string.upper(def.name),
					rarity = rarity,
					line1 = "+" .. format(tonumber(member.perSecond) or def.basePowerPerSecond) .. "/s",
					line2 = def.role .. " · Niv. " .. tostring(tonumber(member.level) or 1),
					accent = if def.palette then def.palette[2] else rarity.color,
				})
			end
		end
	end
	return cards
end

-- Carte de progression : tutoriel (Malik) d'abord, puis parcours des 10 niveaux (spec refonte §4)
local LEVEL_COUNT = 10
local function progressOf(snapshot: any, tutorial: any, progress: number, needed: number): Progress
	if tutorial.crewUnlocked == false then
		return { visible = true, kind = "tutorial", title = "MALIK ARRIVE", value = progress, max = needed }
	end
	if type(snapshot.clearedLevels) == "table" then
		return {
			visible = true,
			kind = "run",
			title = "PARCOURS",
			value = #snapshot.clearedLevels,
			max = LEVEL_COUNT,
		}
	end
	return { visible = false, kind = "run", title = "", value = 0, max = 0 }
end

-- Texte d'un toast pour un événement Result, ou nil (accord avec le codeur A, CONTRACT.md « Effets RGB »)
function HudModel.toastFor(event: { [string]: any }, catalog: any): string?
	if event.kind == "crewJoined" and event.isNew == false then
		local def = catalog.crew[event.crewId]
		return "+1 copie : " .. (if def then def.name else "compagnon")
	elseif event.kind == "ticket" then
		local what = if event.ticket == "crew" then "compagnon" else "baddie"
		return `+{tonumber(event.amount) or 1} ticket {what}`
	end
	return nil
end

function HudModel.build(snapshot: { [string]: any }?, catalog: any, format: (number) -> string): HudView
	local total = #catalog.baddieOrder
	if snapshot == nil then
		return {
			ready = false,
			powerText = "—",
			productionText = nil,
			ticketText = "—",
			principal = nil,
			tutorial = { visible = false, text = "", ratio = 0 },
			button = { label = "ENTRAÎNER", colorKey = "Accent" },
			progress = { visible = false, kind = "run", title = "", value = 0, max = 0 },
			cards = {},
			bookCount = { discovered = 0, total = total },
		}
	end

	local tutorial = if type(snapshot.tutorial) == "table" then snapshot.tutorial else {}
	local progress = tonumber(tutorial.progress) or 0
	local needed = tonumber(tutorial.needed) or 0
	local tickets = if type(snapshot.tickets) == "table" then snapshot.tickets else {}
	local combat = snapshot.mode == "combat"

	return {
		ready = true,
		powerText = format(tonumber(snapshot.power) or 0),
		productionText = productionOf(snapshot, catalog, format),
		ticketText = format(tonumber(tickets.baddie) or 0),
		principal = principalOf(snapshot.active, catalog, format),
		tutorial = {
			visible = tutorial.crewUnlocked == false,
			text = `Malik arrive : {progress}/{needed}`,
			ratio = if needed > 0 then math.clamp(progress / needed, 0, 1) else 0,
		},
		button = if combat
			then { label = "ATTAQUER", colorKey = "Accent2" }
			else { label = "ENTRAÎNER", colorKey = "Accent" },
		progress = progressOf(snapshot, tutorial, progress, needed),
		cards = cardsOf(snapshot, catalog, format),
		bookCount = { discovered = discoveredCount(snapshot, catalog), total = total },
	}
end

return HudModel
