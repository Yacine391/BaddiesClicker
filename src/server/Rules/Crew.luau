--!strict
--[[
	Règles des compagnons (module pur, testé dans tests/run.luau). Dossier §16.
	- Collection permanente ; premier exemplaire au niveau 1, chaque doublon ajoute une copie.
	- Deux identités distinctes maximum équipées ; un seul exemplaire de chacune.
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

return Crew
