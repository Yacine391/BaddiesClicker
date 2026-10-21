--!strict
--[[
	StyleModel : onglets et lignes de la fenêtre Style (spec refonte §5).
	LOOKS si la principale est connue ; AURA si une aura est débloquée ; TITRE si un titre l'est.
	Données : snapshot.style (contrat v3) et Shared/Wardrobe, passés en paramètres.
	Pur, testé par tests/client/run.luau.
]]

export type Tab = { id: "looks" | "aura" | "title", label: string }
export type Row = { id: string, name: string, equipped: boolean }
export type LookRow = {
	index: number,
	name: string,
	state: "worn" | "unlocked" | "locked",
	mastery: number, -- maîtrise requise
	canWear: boolean,
}

local StyleModel = {}

local function styleOf(snapshot: any): any
	return if type(snapshot) == "table" and type(snapshot.style) == "table" then snapshot.style else {}
end

function StyleModel.auraRows(snapshot: any, wardrobe: any): { Row }
	local style = styleOf(snapshot)
	local owned: { [string]: boolean } = {}
	for _, id in (if type(style.items) == "table" then style.items else {}) do
		owned[id] = true
	end
	local equipped = if type(style.equipped) == "table" then style.equipped.aura else nil
	local rows: { Row } = {}
	for _, id in wardrobe.itemOrder do
		local item = wardrobe.items[id]
		if owned[id] and item and item.slot == "aura" then
			table.insert(rows, { id = id, name = item.name, equipped = equipped == id })
		end
	end
	return rows
end

function StyleModel.titleRows(snapshot: any, wardrobe: any): { Row }
	local style = styleOf(snapshot)
	local owned: { [string]: boolean } = {}
	for _, id in (if type(style.titles) == "table" then style.titles else {}) do
		owned[id] = true
	end
	local rows: { Row } = {}
	for _, id in wardrobe.titleOrder do
		local title = wardrobe.titles[id]
		if owned[id] and title then
			table.insert(rows, { id = id, name = title.name, equipped = style.title == id })
		end
	end
	return rows
end

-- Actions de style (SetLook, SetStyle) : hors combat seulement
function StyleModel.canAct(snapshot: any): boolean
	return type(snapshot) == "table" and snapshot.mode ~= "combat"
end

-- Looks de la principale. Sans collection.looks (contrat v1) : look 1 porté, aucune action.
function StyleModel.lookRows(snapshot: any, catalog: any, thresholds: { number }): { LookRow }
	local active = if type(snapshot) == "table" then snapshot.active else nil
	local id = if type(active) == "table" then active.baddieId else nil
	local def = if type(id) == "string" then catalog.baddies[id] else nil
	if def == nil then
		return {}
	end
	local collection = snapshot.collection
	local looks = if type(collection) == "table" and type(collection.looks) == "table"
		then collection.looks[id]
		else nil
	local unlocked: { number } = if looks and type(looks.unlocked) == "table" then looks.unlocked else { 1 }
	local selected: number = if looks and looks.selected then looks.selected else 1
	local rows: { LookRow } = {}
	for index, lookName in def.looks do
		local isUnlocked = table.find(unlocked, index) ~= nil
		local state = if index == selected then "worn" elseif isUnlocked then "unlocked" else "locked"
		table.insert(rows, {
			index = index,
			name = string.upper(lookName),
			state = state,
			mastery = thresholds[index] or 0,
			canWear = state == "unlocked" and looks ~= nil and StyleModel.canAct(snapshot),
		})
	end
	return rows
end

function StyleModel.tabs(snapshot: any, catalog: any, wardrobe: any): { Tab }
	local tabs: { Tab } = {}
	local active = if type(snapshot) == "table" then snapshot.active else nil
	if type(active) == "table" and type(active.baddieId) == "string" and catalog.baddies[active.baddieId] then
		table.insert(tabs, { id = "looks", label = "LOOKS" })
	end
	if #StyleModel.auraRows(snapshot, wardrobe) > 0 then
		table.insert(tabs, { id = "aura", label = "AURA" })
	end
	if #StyleModel.titleRows(snapshot, wardrobe) > 0 then
		table.insert(tabs, { id = "title", label = "TITRE" })
	end
	return tabs
end

return StyleModel
