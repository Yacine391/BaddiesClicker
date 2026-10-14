--!strict
--[[
	Règles d'entraînement (module pur, testé dans tests/run.luau).
	Hors combat, chaque action acceptée donne +gainManuel de puissance, fait avancer
	les compteurs de tickets et le tutoriel (premier compagnon garanti).
]]

export type Result = {
	gained: number,
	baddieTickets: number,
	crewTickets: number,
	crewUnlocked: string?,
}

local Training = {}

function Training.canTrain(session: { inCombat: boolean }): (boolean, string?)
	if session.inCombat then
		return false, "inCombat" -- en combat, le clic attaque : jamais les deux (§07)
	end
	return true, nil
end

function Training.apply(data: any, ctx: any): Result
	local B = ctx.Balance
	local gained = ctx.Formulas.manualGain(data.rebirths, B.training)
	data.power += gained
	data.stats.trainActions += 1

	local result: Result = { gained = gained, baddieTickets = 0, crewTickets = 0, crewUnlocked = nil }

	local counters = data.trainCounters
	counters.baddie += 1
	if counters.baddie >= B.tickets.baddieEveryTrainActions then
		counters.baddie -= B.tickets.baddieEveryTrainActions
		data.tickets.baddie += 1
		result.baddieTickets = 1
	end
	counters.crew += 1
	if counters.crew >= B.tickets.crewEveryTrainActions then
		counters.crew -= B.tickets.crewEveryTrainActions
		data.tickets.crew += 1
		result.crewTickets = 1
	end

	if
		not data.tutorial.crewUnlocked
		and data.stats.trainActions >= B.tutorial.crewUnlockAfterTrainActions
	then
		data.tutorial.crewUnlocked = true
		result.crewUnlocked = B.tutorial.starterCrewId
	end

	return result
end

return Training
