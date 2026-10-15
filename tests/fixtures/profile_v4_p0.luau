--[[
	Fixture : profil de schéma 4 tel que l'écrivait le lot P0/P1 (avant `selectedLooks` et `lastMutation`).
	Sert à vérifier que Reconcile + ProfileGuard ouvrent un ancien profil sans rien perdre (§24).
	Renvoie une fonction : chaque test reçoit une copie neuve.
]]

return function()
	return {
		schemaVersion = 4,
		revision = 0,
		power = 76.9,
		rebirths = 0,
		activeSlotId = "s1",
		slots = {
			s1 = { order = 1, conserved = false, baddieId = "jade", slotRevision = 3, rollLocked = false },
		},
		run = {
			id = 1,
			attempt = 2,
			clearedLevels = { ["1"] = true, ["2"] = true },
			firstClearRewards = { ["1"] = true, ["2"] = true },
		},
		tickets = { baddie = 22, crew = 0 },
		rolls = { baddie = 0, crew = 0 },
		trainCounters = { baddie = 150, crew = 400 },
		pendingDrops = { jade = 1 },
		pendingRevision = 1,
		discoveredBaddies = { maya = true, jade = true },
		encounteredBosses = { jade = true, iris = true },
		masteryXP = { maya = 12, jade = 30 },
		crew = { malik = { level = 1, copies = 0 } },
		equippedCrew = { "malik" },
		displayBaddies = {},
		wardrobe = {},
		titles = {},
		tutorial = { crewUnlocked = true },
		collectionAwards = {},
		eventClaims = {},
		settings = { reducedEffects = false },
		pendingBadges = {},
		stats = { trainActions = 400, crewPowerEarned = 513 },
	}
end
