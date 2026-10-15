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
		opsStoreName = "BC_Ops_v1", -- interrupteurs de maintenance (§36)
		studioOpsStoreName = "BC_Ops_STUDIO_v1",
		maintenancePollSeconds = 60,
	},

	net = {
		statePushSeconds = 0.1, -- regroupe les envois d'état vers le client
		helloPerSecond = 2,
	},

	-- §08, §25, §26 : combat individuel (lot P1). Valeurs proposées, à régler en test.
	combat = {
		playerHP = 100, -- restaurés hors combat
		attackRange = 25, -- portée de départ (studs)
		rangeTolerance = 3, -- marge réseau sur la portée
		maxActionsPerSecond = 8,
		tickSeconds = 0.1, -- cadence de simulation des ennemis côté serveur
		maxSimultaneousMinions = 2, -- « un ou deux sbires simultanés »
		minionSpawnDelay = 0.8,
		leaveArenaGraceSeconds = 3, -- sortir de l'arène plus longtemps abandonne le combat
		dodgeTolerance = 0.75, -- marge en faveur du joueur sur les zones de danger (latence)
		respawnDelay = 1.5,
		minionPowerPerLevel = 2, -- sbire = 2 × niveau
		bossPowerPerLevel = 10, -- boss = 10 × niveau
		bossDropChance = 0.10, -- RÈGLE CONFIRMÉE : 10 %, sans pity ni garantie
		-- Sbire : frappe lente sur la position du joueur
		minion = {
			speed = 10,
			engageDistance = 5,
			telegraphSeconds = 1.0,
			recoverySeconds = 1.6,
			radius = 6,
			damageBase = 10,
			damagePerLevel = 5,
		},
		-- Boss : frappe en cercle autour de lui
		boss = {
			speed = 7,
			engageDistance = 7,
			telegraphSeconds = 1.3,
			recoverySeconds = 2.2,
			radius = 11,
			damageBase = 20,
			damagePerLevel = 8,
		},
	},

	rolls = {
		baddieGuaranteeEvery = 50, -- §13 : toutes les 50 relances, une identité manquante si le Baddies Book est incomplet
		crewGuaranteeEvery = 20,
		minIntervalSeconds = 2, -- §25 : une relance à la fois, 2 s minimum entre deux relances
	},

	-- §03 : look 1 à la découverte, look 2 à maîtrise 1, look 3 à maîtrise 5 (proposition contrat v2 du codeur B)
	looks = {
		unlockAtMastery = { 0, 1, 5 },
	},

	-- §15 : exposition = apparence seulement, aucun multiplicateur
	collection = {
		maxDisplay = 3,
	},

	-- §19 : succès internes (vérifiés par lots) et badges Roblox (réessayés sans redonner les récompenses)
	achievements = {
		checkSeconds = 2,
		trainActions = 20, -- « Premier entraînement »
		lookMastery = 1, -- « Premier look » : Maya maîtrise 1
		badgeRetrySeconds = 60,
	},

	-- §15 : classement des joueurs présents, rafraîchi par lots
	ranking = {
		refreshSeconds = 2,
	},

	-- §24 : bornes vérifiées au chargement de chaque profil (Rules/ProfileGuard) ; ni NaN ni infini
	limits = {
		maxPower = 1e15,
		maxTickets = 1e6,
		maxCopies = 1e6,
		maxCounter = 1e9, -- compteurs de relances, d'entraînements, révisions, parcours
		maxMasteryXP = 1e9,
		maxPendingPerBaddie = 1e4,
	},

	-- §27 : une décision durable (relance, drop, renaissance) n'est confirmée qu'après écriture
	mutations = {
		saveTimeoutSeconds = 12,
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
