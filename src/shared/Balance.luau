--!strict
--[[
	Balance : tous les chiffres ajustables du jeu (dossier v4, « paramètres proposés »).

	- Source unique : le serveur calcule avec ces valeurs, le client peut les afficher.
	- Aucun require, aucune API Roblox : testable hors Studio (tests/run.luau avec Lune).
	- Modifier un chiffre ici ne doit jamais changer une RÈGLE CONFIRMÉE
	  (ex. drop boss 10 % sans garantie, aucun transfert de baddie entre slots).
]]

local Balance = {
	version = "v4-p0",

	power = {
		start = 1, -- puissance de départ (et après rebirth)
	},

	-- §12 : gainManuel = baseGain × bonusEntrainement
	training = {
		baseGain = 1,
		rebirthBonusPerRebirth = 0.10, -- bonusEntrainement = 1 + 0,10 × min(rebirths, 20)
		rebirthBonusCap = 20,
		maxActionsPerSecond = 8, -- limite serveur, séparée par action (§25)
		burst = 8, -- jetons disponibles d'un coup
		holdActionsPerSecond = 3, -- maintien accessible côté client (§07)
	},

	-- §12 : tickets
	tickets = {
		startBaddie = 10, -- une seule fois, à la création du profil
		startCrew = 0,
		baddieEveryTrainActions = 250,
		crewEveryTrainActions = 500,
	},

	-- §16 : compagnons
	crew = {
		maxEquipped = 2,
		maxLevel = 10,
		levelBonusPerLevel = 0.10, -- taux = base × (1 + 0,10 × (L - 1))
		tickSeconds = 1, -- cadence de la production passive côté serveur
		maxTickSeconds = 5, -- un tick ne crédite jamais plus (hoquet serveur)
	},

	-- §12 : maîtrise
	mastery = {
		maxLevel = 10,
		damageBonusPerLevel = 0.05, -- ×(1 + 0,05 × maîtrise) → ×1,5 au niveau 10
		xpThresholdFactor = 10, -- seuil total du niveau L = 10 × L²
		xpPerMinion = 1,
		xpPerBoss = 5,
	},

	-- §07 : première session
	tutorial = {
		starterBaddieId = "maya",
		starterCrewId = "malik", -- Malik remplace Enzo comme premier compagnon garanti
		crewUnlockAfterTrainActions = 10,
	},

	-- §27 : sauvegarde
	save = {
		schemaVersion = 4,
		autosaveSeconds = 60,
		storeName = "BC_Profiles_v1",
		studioStoreName = "BC_Profiles_STUDIO_v1", -- profils de test séparés
	},

	net = {
		statePushSeconds = 0.1, -- regroupe les envois d'état vers le client
		helloPerSecond = 2,
	},

	-- Lots P1 / P2 : données posées pour la suite, pas encore utilisées par le code.
	combat = {
		playerHP = 100,
		attackRange = 25,
		maxActionsPerSecond = 8,
		minionPowerPerLevel = 2, -- sbire = 2 × niveau
		bossPowerPerLevel = 10, -- boss = 10 × niveau
		bossDropChance = 0.10, -- RÈGLE CONFIRMÉE : 10 %, sans pity ni garantie
	},

	rolls = {
		baddieGuaranteeEvery = 50,
		crewGuaranteeEvery = 20,
	},

	rebirth = {
		baddieTickets = 5,
		crewTickets = 1,
		promotionAt = { 1, 3, 6 }, -- rebirths qui promeuvent le slot temporaire
	},

	-- §09 : dix niveaux dans cinq quartiers (paramètres de test, pas l'équilibre final)
	levels = {
		{ district = "Street Block", minions = 3, minionHP = 50, boss = "jade", bossHP = 250 },
		{ district = "Street Block", minions = 3, minionHP = 90, boss = "iris", bossHP = 450 },
		{ district = "Shopping Avenue", minions = 4, minionHP = 150, boss = "jade", bossHP = 800 },
		{ district = "Shopping Avenue", minions = 4, minionHP = 250, boss = "iris", bossHP = 1400 },
		{ district = "Festival Park", minions = 4, minionHP = 400, boss = "sienna", bossHP = 2500 },
		{ district = "Festival Park", minions = 4, minionHP = 650, boss = "nova", bossHP = 4000 },
		{ district = "Skyline Rooftop", minions = 5, minionHP = 1000, boss = "sienna", bossHP = 6500 },
		{ district = "Skyline Rooftop", minions = 5, minionHP = 1600, boss = "nova", bossHP = 10000 },
		{ district = "World Stage", minions = 5, minionHP = 2500, boss = "zuri", bossHP = 16000 },
		{ district = "World Stage", minions = 5, minionHP = 4000, boss = "vega", bossHP = 25000 },
	},
}

-- Gel profond : personne ne peut modifier l'équilibrage en cours de partie par erreur.
local function deepFreeze(t: any)
	for _, value in t do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	table.freeze(t)
end
deepFreeze(Balance)

return Balance
