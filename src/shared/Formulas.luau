--!strict
--[[
	Formulas : calculs purs du dossier v4 (§12, §14, §16, §29).
	Les paramètres viennent de Balance, passés en argument : aucun require, testable avec Lune.
]]

export type TrainingCfg = { baseGain: number, rebirthBonusPerRebirth: number, rebirthBonusCap: number }
export type CrewCfg = { maxLevel: number, levelBonusPerLevel: number }
export type MasteryCfg = { maxLevel: number, damageBonusPerLevel: number, xpThresholdFactor: number }

local Formulas = {}

-- bonusEntrainement = 1 + 0,10 × min(rebirths, 20)
function Formulas.trainingBonus(rebirths: number, training: TrainingCfg): number
	local counted = math.clamp(rebirths, 0, training.rebirthBonusCap)
	return 1 + training.rebirthBonusPerRebirth * counted
end

-- gainManuel = 1 × bonusEntrainement
function Formulas.manualGain(rebirths: number, training: TrainingCfg): number
	return training.baseGain * Formulas.trainingBonus(rebirths, training)
end

-- Taux d'un compagnon : base × (1 + 0,10 × (L - 1)), L borné à [1, 10]
function Formulas.crewRate(basePerSecond: number, level: number, crew: CrewCfg): number
	local clamped = math.clamp(level, 1, crew.maxLevel)
	return basePerSecond * (1 + crew.levelBonusPerLevel * (clamped - 1))
end

-- gainPassif/s = somme des compagnons actifs × bonusEntrainement
function Formulas.passivePerSecond(rates: { number }, rebirths: number, training: TrainingCfg): number
	local sum = 0
	for _, rate in rates do
		sum += rate
	end
	return sum * Formulas.trainingBonus(rebirths, training)
end

-- Niveau de maîtrise : plus grand L tel que 10 × L² <= xp, plafonné à 10
function Formulas.masteryLevel(xp: number, mastery: MasteryCfg): number
	local level = 0
	while level < mastery.maxLevel and xp >= mastery.xpThresholdFactor * (level + 1) ^ 2 do
		level += 1
	end
	return level
end

-- dégâts/clic = puissance × multiplicateurPrincipale × (1 + 0,05 × maîtrisePrincipale)
function Formulas.damagePerClick(
	power: number,
	multiplier: number,
	masteryLevel: number,
	mastery: MasteryCfg
): number
	return power * multiplier * (1 + mastery.damageBonusPerLevel * masteryLevel)
end

function Formulas.hitsToKill(hp: number, damagePerHit: number): number
	return math.ceil(hp / damagePerHit)
end

-- §29 : chance d'au moins un succès en n essais indépendants (boss : 1 - 0,9^n)
function Formulas.chanceAtLeastOne(p: number, attempts: number): number
	return 1 - (1 - p) ^ attempts
end

return Formulas
