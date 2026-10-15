--!strict
--[[
	ProfileTemplate : profil neuf, schéma 4 (dossier §24).
	Module pur : construit une NOUVELLE table à chaque appel (jamais partagée entre joueurs).

	Ajouts par rapport au dossier : `stats` (compteurs de vie, utiles au tutoriel et aux succès),
	`selectedLooks` (looks choisis) et `lastMutation` (reçu de la dernière décision durable, §26). Un slot vide a baddieId = "" (jamais nil : la réconciliation
	ProfileStore remettrait la valeur du modèle, « maya », dans le slot s1).
	Règles ProfileStore : pas de tableaux à trous, pas de tables mixtes, pas d'Instances/Vector3.
]]

local ProfileTemplate = {}

function ProfileTemplate.new(ctx: any): { [string]: any }
	local B = ctx.Balance
	local starter = B.tutorial.starterBaddieId

	return {
		schemaVersion = B.save.schemaVersion,
		revision = 0,
		power = B.power.start,
		rebirths = 0,
		activeSlotId = "s1",
		slots = {
			s1 = { order = 1, conserved = false, baddieId = starter, slotRevision = 0, rollLocked = false },
		},
		run = { id = 1, attempt = 1, clearedLevels = {}, firstClearRewards = {} },
		tickets = { baddie = B.tickets.startBaddie, crew = B.tickets.startCrew },
		rolls = { baddie = 0, crew = 0 },
		trainCounters = { baddie = 0, crew = 0 },
		pendingDrops = {}, -- baddieId -> quantité
		pendingRevision = 0,
		discoveredBaddies = { [starter] = true },
		encounteredBosses = {},
		masteryXP = { [starter] = 0 },
		crew = {}, -- crewId -> { level, copies }
		equippedCrew = {}, -- liste ordonnée d'IDs, 2 maximum
		displayBaddies = {}, -- exposition : liste d'IDs découverts, 3 max (§15)
		selectedLooks = {}, -- baddieId -> index de look choisi (proposition contrat v2 du codeur B)
		wardrobe = {},
		titles = {},
		tutorial = { crewUnlocked = false },
		collectionAwards = {},
		eventClaims = {},
		settings = { reducedEffects = false },
		pendingBadges = {},
		stats = { trainActions = 0, crewPowerEarned = 0 },
		lastMutation = {}, -- reçu durable de la dernière décision (Rules/Receipts), vide au départ
	}
end

return ProfileTemplate
