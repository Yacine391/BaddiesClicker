--!strict
--[[
	StyleModel : onglets et lignes de la fenêtre Style (spec refonte §5).
	LOOKS si la principale est connue ; AURA si une aura est débloquée ; ACCESSOIRES si un autre cosmétique
	l'est ; TITRE si un titre l'est ; SUCCÈS toujours (comment obtenir chaque récompense, §19).
	`parsePublic` lit l'attribut BC_Style des autres joueurs (Controllers/Wearables).
	Données : snapshot.style (contrat v3) et Shared/Wardrobe, passés en paramètres.
	Pur, testé par tests/client/run.luau.
]]

export type Tab = { id: "looks" | "aura" | "gear" | "title" | "achievements", label: string, count: string? }
export type Row = { id: string, name: string, equipped: boolean, slot: string?, slotLabel: string? }
export type AchievementRow = { id: string, name: string, condition: string, reward: string, earned: boolean }
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

-- Cosmétiques possédés hors aura (cou, poignet, visage, tête, trail, pose, cadre), un porté par emplacement
function StyleModel.gearRows(snapshot: any, wardrobe: any): { Row }
	local style = styleOf(snapshot)
	local owned: { [string]: boolean } = {}
	for _, id in (if type(style.items) == "table" then style.items else {}) do
		owned[id] = true
	end
	local equipped = if type(style.equipped) == "table" then style.equipped else {}
	local rows: { Row } = {}
	for _, id in wardrobe.itemOrder do
		local item = wardrobe.items[id]
		if owned[id] and item and item.slot ~= "aura" then
			table.insert(rows, {
				id = id,
				name = item.name,
				equipped = equipped[item.slot] == id,
				slot = item.slot,
				slotLabel = wardrobe.slotLabels[item.slot] or item.slot,
			})
		end
	end
	return rows
end

-- Tous les succès, obtenus ou non, avec leur condition et ce qu'ils débloquent
function StyleModel.achievementRows(snapshot: any, wardrobe: any): { AchievementRow }
	local style = styleOf(snapshot)
	local earned: { [string]: boolean } = {}
	for _, id in (if type(style.achievements) == "table" then style.achievements else {}) do
		earned[id] = true
	end
	local rows: { AchievementRow } = {}
	for _, id in wardrobe.achievementOrder do
		local def = wardrobe.achievements[id]
		if def then
			local rewards = {}
			for _, item in def.rewards.items or {} do
				local d = wardrobe.items[item]
				table.insert(rewards, if d then d.name else item)
			end
			for _, title in def.rewards.titles or {} do
				local d = wardrobe.titles[title]
				table.insert(rewards, `titre « {if d then d.name else title} »`)
			end
			table.insert(rows, {
				id = id,
				name = def.name,
				condition = def.condition,
				reward = table.concat(rewards, " + "),
				earned = earned[id] == true,
			})
		end
	end
	return rows
end

-- Attribut BC_Style d'un joueur (« neck=chain_gold,frame=frame_v1 ») → emplacement -> cosmétique connu
function StyleModel.parsePublic(value: any, wardrobe: any): { [string]: string }
	local result: { [string]: string } = {}
	if type(value) ~= "string" then
		return result
	end
	for pair in string.gmatch(value, "[^,]+") do
		local slot, id = string.match(pair, "^([%w_]+)=([%w_]+)$")
		local item = if id then wardrobe.items[id] else nil
		if slot and id and item and item.slot == slot then
			result[slot] = id
		end
	end
	return result
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
	if #StyleModel.gearRows(snapshot, wardrobe) > 0 then
		table.insert(tabs, { id = "gear", label = "ACCESSOIRES" })
	end
	if #StyleModel.titleRows(snapshot, wardrobe) > 0 then
		table.insert(tabs, { id = "title", label = "TITRE" })
	end
	local earned = 0
	local rows = StyleModel.achievementRows(snapshot, wardrobe)
	for _, row in rows do
		if row.earned then
			earned += 1
		end
	end
	table.insert(tabs, { id = "achievements", label = "SUCCÈS", count = `{earned}/{#rows}` })
	return tabs
end

return StyleModel
