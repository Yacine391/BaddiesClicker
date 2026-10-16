--!strict
--[[
	Règles de combat (module pur, testé dans tests/run.luau). Dossier §08 à §14 et §26.

	- Accès : niveau 1 toujours ouvert ; niveau N seulement si le boss N-1 est vaincu dans ce parcours.
	- Récompenses : sbire = 2 × niveau, boss = 10 × niveau ; XP de maîtrise à la principale.
	- Victoire boss : porte ouverte même sans drop, +1 ticket au premier passage,
	  tirage UNIQUE à 10 % sans pity ni garantie (seul `roll` décide).
	- Mort : portes refermées et tentative +1 ; puissance, slots, drops et Baddies Book conservés.

	Les niveaux terminés sont indexés par chaîne ("1", "2"…) : pas de tableau à trous dans le profil.
]]

export type LevelConfig = {
	levelId: number,
	district: string,
	minions: number,
	minionHP: number,
	minionDamage: number,
	boss: string,
	bossHP: number,
	bossDamage: number,
}

export type Reward = { power: number, xp: number, masteryBaddie: string?, masteryUp: number? }

export type Victory = {
	power: number,
	xp: number,
	masteryBaddie: string?,
	masteryUp: number?,
	firstClear: boolean,
	baddieTickets: number,
	drop: string?,
}

local Combat = {}

function Combat.key(levelId: number): string
	return tostring(levelId)
end

function Combat.isValidLevelId(levelId: any, ctx: any): boolean
	return type(levelId) == "number"
		and levelId == math.floor(levelId)
		and levelId >= 1
		and levelId <= #ctx.Balance.levels
end

function Combat.levelConfig(levelId: number, ctx: any): LevelConfig?
	if not Combat.isValidLevelId(levelId, ctx) then
		return nil
	end
	local level = ctx.Balance.levels[levelId]
	local c = ctx.Balance.combat
	return {
		levelId = levelId,
		district = level.district,
		minions = level.minions,
		minionHP = level.minionHP,
		minionDamage = c.minion.damageBase + c.minion.damagePerLevel * levelId,
		boss = level.boss,
		bossHP = level.bossHP,
		bossDamage = c.boss.damageBase + c.boss.damagePerLevel * levelId,
	}
end

function Combat.isCleared(data: any, levelId: number): boolean
	return data.run.clearedLevels[Combat.key(levelId)] == true
end

function Combat.isAccessible(data: any, levelId: number, ctx: any): boolean
	if not Combat.isValidLevelId(levelId, ctx) then
		return false
	end
	return levelId == 1 or Combat.isCleared(data, levelId - 1)
end

-- Liste triée des niveaux terminés (pour le snapshot client)
function Combat.clearedList(data: any): { number }
	local list = {}
	for key, value in data.run.clearedLevels do
		local levelId = tonumber(key)
		if value == true and levelId ~= nil then
			table.insert(list, levelId)
		end
	end
	table.sort(list)
	return list
end

-- dégâts/clic de la principale (aucune baddie exposée n'entre dans le calcul)
function Combat.attackDamage(data: any, ctx: any): number
	local slot = data.slots[data.activeSlotId]
	if slot == nil then
		return 0
	end
	local baddie = ctx.Catalog.baddies[slot.baddieId]
	if baddie == nil then
		return 0
	end
	local mastery = ctx.Formulas.masteryLevel(data.masteryXP[slot.baddieId] or 0, ctx.Balance.mastery)
	return ctx.Formulas.damagePerClick(data.power, baddie.multiplier, mastery, ctx.Balance.mastery)
end

-- Coups pour finir toute la rencontre d'un niveau (sbires puis boss) à `damage` par coup
function Combat.attacksToClear(levelId: number, damage: number, ctx: any): number
	local cfg = Combat.levelConfig(levelId, ctx)
	if cfg == nil or damage <= 0 or damage ~= damage then
		return math.huge
	end
	return cfg.minions * math.ceil(cfg.minionHP / damage) + math.ceil(cfg.bossHP / damage)
end

-- §09 « puissance recommandée » (un conseil, jamais une garantie) : plus petite puissance entière qui
-- finit la rencontre en `Balance.combat.recommendedAttacks` coups avec cette principale et cette maîtrise.
function Combat.recommendedPower(levelId: number, multiplier: number, masteryLevel: number, ctx: any): number?
	if Combat.levelConfig(levelId, ctx) == nil or multiplier <= 0 then
		return nil
	end
	local target = ctx.Balance.combat.recommendedAttacks
	local function fits(power: number): boolean
		local damage = ctx.Formulas.damagePerClick(power, multiplier, masteryLevel, ctx.Balance.mastery)
		return Combat.attacksToClear(levelId, damage, ctx) <= target
	end
	local low, high = 1, 1
	while not fits(high) do
		high *= 2
	end
	while low < high do
		local mid = (low + high) // 2
		if fits(mid) then
			high = mid
		else
			low = mid + 1
		end
	end
	return low
end

-- Prochain niveau à vaincre dans ce parcours (nil si le niveau 10 est déjà terminé)
function Combat.nextLevel(data: any, ctx: any): number?
	for levelId = 1, #ctx.Balance.levels do
		if not Combat.isCleared(data, levelId) then
			return levelId
		end
	end
	return nil
end

-- XP de maîtrise à la principale ; renvoie (baddieId, nouveau niveau si montée)
local function addMastery(data: any, xp: number, ctx: any): (string?, number?)
	local slot = data.slots[data.activeSlotId]
	if slot == nil then
		return nil, nil
	end
	local id = slot.baddieId
	local before = ctx.Formulas.masteryLevel(data.masteryXP[id] or 0, ctx.Balance.mastery)
	data.masteryXP[id] = (data.masteryXP[id] or 0) + xp
	local after = ctx.Formulas.masteryLevel(data.masteryXP[id], ctx.Balance.mastery)
	if after > before then
		return id, after
	end
	return id, nil
end

function Combat.applyMinionKill(data: any, levelId: number, ctx: any): Reward
	local power = ctx.Balance.combat.minionPowerPerLevel * levelId
	data.power += power
	local xp = ctx.Balance.mastery.xpPerMinion
	local baddie, up = addMastery(data, xp, ctx)
	return { power = power, xp = xp, masteryBaddie = baddie, masteryUp = up }
end

function Combat.applyBossVictory(data: any, levelId: number, roll: number, ctx: any): Victory
	local cfg = Combat.levelConfig(levelId, ctx)
	assert(cfg ~= nil, `niveau invalide : {levelId}`)

	local power = ctx.Balance.combat.bossPowerPerLevel * levelId
	data.power += power
	local xp = ctx.Balance.mastery.xpPerBoss
	local baddie, up = addMastery(data, xp, ctx)

	local key = Combat.key(levelId)
	data.run.clearedLevels[key] = true -- la porte s'ouvre, même sans drop
	data.encounteredBosses[cfg.boss] = true -- « rencontré » ne compte pas comme découverte

	local firstClear = data.run.firstClearRewards[key] ~= true
	local tickets = 0
	if firstClear then
		data.run.firstClearRewards[key] = true
		data.tickets.baddie += 1
		tickets = 1
	end

	local drop = nil
	if roll < ctx.Balance.combat.bossDropChance then
		drop = cfg.boss
		data.pendingDrops[cfg.boss] = (data.pendingDrops[cfg.boss] or 0) + 1
		data.pendingRevision += 1
	end

	return {
		power = power,
		xp = xp,
		masteryBaddie = baddie,
		masteryUp = up,
		firstClear = firstClear,
		baddieTickets = tickets,
		drop = drop,
	}
end

function Combat.applyDeath(data: any, _ctx: any)
	data.run.clearedLevels = {}
	data.run.attempt += 1
end

return Combat
