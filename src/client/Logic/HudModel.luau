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

export type HudView = {
	ready: boolean,
	powerText: string,
	productionText: string?,
	ticketText: string,
	principal: Principal?,
	tutorial: { visible: boolean, text: string, ratio: number },
	button: { label: string, colorKey: "Action" | "Fermer" },
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
			button = { label = "ENTRAÎNER", colorKey = "Action" },
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
			then { label = "ATTAQUER", colorKey = "Fermer" }
			else { label = "ENTRAÎNER", colorKey = "Action" },
		bookCount = { discovered = discoveredCount(snapshot, catalog), total = total },
	}
end

return HudModel
