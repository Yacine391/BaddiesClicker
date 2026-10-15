--!strict
--[[
	Règles des compagnons (module pur, testé dans tests/run.luau). Dossier §16.
	- Collection permanente ; premier exemplaire au niveau 1, chaque doublon ajoute une copie.
	- Niveau L → L+1 : dépenser L+1 copies, niveau 10 maximum ; les copies au maximum restent stockées.
	- Deux identités distinctes maximum équipées ; un seul exemplaire de chacune.
	- Coffre : 1 ticket compagnon ; toutes les 20 ouvertures, un compagnon MANQUANT tiré uniformément
	  (sinon la table normale). Compteur global, conservé après mort et rebirth, séparé des baddies.
	- Production passive côté serveur ; les compagnons n'attaquent pas en V1.
]]

export type GrantResult = { isNew: boolean, equipped: boolean, level: number, copies: number }
export type Rate = { id: string, rate: number }

local Crew = {}

function Crew.grant(data: any, crewId: string, ctx: any): GrantResult
	assert(ctx.Catalog.crew[crewId] ~= nil, `compagnon inconnu : {crewId}`)

	local entry = data.crew[crewId]
	local isNew = entry == nil
	if isNew then
		entry = { level = 1, copies = 0 }
		data.crew[crewId] = entry
	else
		entry.copies += 1
	end

	local equipped = false
	local canEquip = #data.equippedCrew < ctx.Balance.crew.maxEquipped
	if isNew and canEquip and table.find(data.equippedCrew, crewId) == nil then
		table.insert(data.equippedCrew, crewId)
		equipped = true
	end

	return { isNew = isNew, equipped = equipped, level = entry.level, copies = entry.copies }
end

-- Taux de chaque compagnon équipé, AVANT le bonus de rebirth
function Crew.equippedRates(data: any, ctx: any): { Rate }
	local list: { Rate } = {}
	for _, id in data.equippedCrew do
		local entry = data.crew[id]
		local def = ctx.Catalog.crew[id]
		if entry ~= nil and def ~= nil then
			local rate = ctx.Formulas.crewRate(def.basePowerPerSecond, entry.level, ctx.Balance.crew)
			table.insert(list, { id = id, rate = rate })
		end
	end
	return list
end

-- Production totale par seconde, bonus de rebirth inclus
function Crew.passivePerSecond(data: any, ctx: any): number
	local rates = {}
	for _, item in Crew.equippedRates(data, ctx) do
		table.insert(rates, item.rate)
	end
	return ctx.Formulas.passivePerSecond(rates, data.rebirths, ctx.Balance.training)
end

-- Crédite la production de `dt` secondes ; renvoie la puissance réellement ajoutée
function Crew.applyPassive(data: any, dt: number, ctx: any): number
	if dt <= 0 then
		return 0
	end
	local seconds = math.min(dt, ctx.Balance.crew.maxTickSeconds)
	local gained = Crew.passivePerSecond(data, ctx) * seconds
	if gained > 0 then
		data.power += gained
		data.stats.crewPowerEarned += gained
	end
	return gained
end

--[[ Coffres (§16) — le hasard est injecté : roll ∈ [0, 1[ ]]

export type ChestResult = {
	crewId: string,
	isNew: boolean,
	equipped: boolean,
	level: number,
	copies: number,
	guaranteed: boolean,
	openNumber: number,
}

-- Compagnons du lot encore jamais obtenus, dans l'ordre du catalogue
function Crew.missing(data: any, ctx: any): { string }
	local list = {}
	for _, id in ctx.Catalog.crewOrder do
		if data.crew[id] == nil then
			table.insert(list, id)
		end
	end
	return list
end

-- Table normale des coffres (chances du catalogue)
function Crew.pickChest(roll: number, ctx: any): string
	local order = ctx.Catalog.crewOrder
	local total = 0
	for _, id in order do
		total += ctx.Catalog.crew[id].chestChance
	end
	local target = roll * total
	local acc = 0
	local last = order[1]
	for _, id in order do
		local chance = ctx.Catalog.crew[id].chestChance
		if chance > 0 then
			acc += chance
			last = id
			if target < acc then
				return id
			end
		end
	end
	return last
end

-- Ouvertures restantes avant la prochaine ouverture garantie (1 = la prochaine)
function Crew.untilChestGuarantee(data: any, ctx: any): number
	local every = ctx.Balance.rolls.crewGuaranteeEvery
	return every - (data.rolls.crew % every)
end

function Crew.checkOpenChest(data: any): string?
	if data.tickets.crew < 1 then
		return "no_ticket"
	end
	return nil
end

-- À appeler après checkOpenChest : un ticket, compteur +1, garantie toutes les 20 si un compagnon manque
function Crew.applyOpenChest(data: any, roll: number, ctx: any): ChestResult
	data.tickets.crew -= 1
	data.rolls.crew += 1
	local openNumber = data.rolls.crew

	local missing = Crew.missing(data, ctx)
	local guaranteed = openNumber % ctx.Balance.rolls.crewGuaranteeEvery == 0 and #missing > 0
	local crewId
	if guaranteed then
		crewId = missing[math.clamp(math.floor(roll * #missing) + 1, 1, #missing)]
	else
		crewId = Crew.pickChest(roll, ctx)
	end

	local grant = Crew.grant(data, crewId, ctx)
	return {
		crewId = crewId,
		isNew = grant.isNew,
		equipped = grant.equipped,
		level = grant.level,
		copies = grant.copies,
		guaranteed = guaranteed,
		openNumber = openNumber,
	}
end

--[[ Niveaux et équipe (§16, §25 « EquipCrew ») ]]

-- Copies à dépenser pour passer au niveau suivant, nil au niveau maximum
function Crew.upgradeCost(level: number, ctx: any): number?
	if level >= ctx.Balance.crew.maxLevel then
		return nil
	end
	return level + 1
end

-- UpgradeCrew { crewId }. Raisons : "unknown", "not_owned", "max_level", "not_enough_copies"
function Crew.upgrade(data: any, crewId: any, ctx: any): (string?, number?)
	if type(crewId) ~= "string" or ctx.Catalog.crew[crewId] == nil then
		return "unknown", nil
	end
	local entry = data.crew[crewId]
	if entry == nil then
		return "not_owned", nil
	end
	local cost = Crew.upgradeCost(entry.level, ctx)
	if cost == nil then
		return "max_level", nil
	end
	if entry.copies < cost then
		return "not_enough_copies", nil
	end
	entry.copies -= cost
	entry.level += 1
	return nil, entry.level
end

-- EquipCrew { ids } : remplace la liste. Raisons : "invalid", "too_many", "not_owned", "duplicate"
function Crew.setEquipped(data: any, ids: any, ctx: any): string?
	if type(ids) ~= "table" then
		return "invalid"
	end
	local keys = 0
	for _ in ids do
		keys += 1
	end
	if keys ~= #ids then
		return "invalid"
	end
	if #ids > ctx.Balance.crew.maxEquipped then
		return "too_many"
	end
	local seen = {}
	local list = {}
	for _, id in ids do
		if type(id) ~= "string" or ctx.Catalog.crew[id] == nil then
			return "invalid"
		end
		if data.crew[id] == nil then
			return "not_owned"
		end
		if seen[id] then
			return "duplicate"
		end
		seen[id] = true
		table.insert(list, id)
	end
	data.equippedCrew = list
	return nil
end

export type OwnedView = {
	id: string,
	level: number,
	copies: number,
	upgradeCost: number?,
	canUpgrade: boolean,
	equipped: boolean,
	perSecond: number,
}

-- Collection possédée pour le client (ordre du catalogue), taux bonus de rebirth inclus
function Crew.ownedView(data: any, ctx: any): { OwnedView }
	local bonus = ctx.Formulas.trainingBonus(data.rebirths, ctx.Balance.training)
	local list: { OwnedView } = {}
	for _, id in ctx.Catalog.crewOrder do
		local entry = data.crew[id]
		if entry ~= nil then
			local cost = Crew.upgradeCost(entry.level, ctx)
			local rate =
				ctx.Formulas.crewRate(ctx.Catalog.crew[id].basePowerPerSecond, entry.level, ctx.Balance.crew)
			table.insert(list, {
				id = id,
				level = entry.level,
				copies = entry.copies,
				upgradeCost = cost,
				canUpgrade = cost ~= nil and entry.copies >= cost,
				equipped = table.find(data.equippedCrew, id) ~= nil,
				perSecond = rate * bonus,
			})
		end
	end
	return list
end

return Crew
