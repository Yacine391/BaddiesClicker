--!strict
--[[
	Balance : tous les chiffres ajustables du jeu (dossier v4, « paramètres proposés »).

	- Source unique : le serveur calcule avec ces valeurs, le client peut les afficher.
	- Aucun require, aucune API Roblox : testable hors Studio (tests/run.luau avec Lune).
	- Modifier un chiffre ici ne doit jamais changer une RÈGLE CONFIRMÉE
	  (ex. drop boss 10 % sans garantie, aucun transfert de baddie entre slots).
]]

local Balance = {
	version = "v4-p1", -- p1 : équilibrage du 15/10 (docs/BALANCE.md, tools/simulate.luau)

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
		-- §12 : récompenses « à équilibrer contre l'entraînement ». Le dossier proposait 2 × et 10 × niveau ;
		-- rejouer une vague devenait alors 30 % plus rapide que s'entraîner (simulateur). Ici, à égalité.
		minionPowerPerLevel = 1, -- sbire = 1 × niveau
		bossPowerPerLevel = 5, -- boss = 5 × niveau
		bossDropChance = 0.10, -- RÈGLE CONFIRMÉE : 10 %, sans pity ni garantie
		recommendedAttacks = 60, -- §09 : puissance conseillée = finir la rencontre en ~60 coups (~15 s)
		-- §25 : déplacements contrôlés pendant un combat (Rules/Movement). Tolérant : un pic de latence
		-- donne au plus UNE anomalie ; seule la répétition invalide la rencontre (aucun bannissement).
		movement = {
			speedTolerance = 1.25, -- × WalkSpeed du Humanoid lue côté serveur (16 par défaut)
			extraStudsPerSecond = 4, -- marge fixe : sauts, glissades, arrondis de réplication
			burstSeconds = 2, -- réserve : rattrape 2 s de positions retenues par la latence
			slackStuds = 8, -- dépassement toléré au-delà de la réserve
			strikeWindowSeconds = 20,
			maxStrikes = 3, -- 3 anomalies en 20 s : rencontre invalidée, ses gains retirés
			restartDelaySeconds = 5, -- délai avant qu'une nouvelle vague puisse démarrer
		},
		-- Sbire : frappe lente sur la position du joueur
		minion = {
			speed = 10,
			engageDistance = 5,
			telegraphSeconds = 1.0,
			recoverySeconds = 1.6,
			radius = 6,
			damageBase = 10,
			damagePerLevel = 4, -- 14 au niveau 1, 50 au niveau 10 : deux erreurs avant la troisième fatale
		},
		-- Boss : frappe en cercle autour de lui
		boss = {
			speed = 7,
			engageDistance = 7,
			telegraphSeconds = 1.3,
			recoverySeconds = 2.2,
			radius = 11,
			damageBase = 20,
			damagePerLevel = 6, -- 26 au niveau 1, 80 au niveau 10 : jamais mort d'un seul coup à PV pleins
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

	-- §09 : dix niveaux dans cinq quartiers. Le niveau 1 garde 3 × 50 et 250 (demandé par le dossier).
	-- Ensuite, PV ≈ ce qu'un joueur occasionnel atteint en s'entraînant (3/s) pour un parcours de ~27 min :
	-- puissance visée ≈ 8 × secondes écoulées, sbire ≈ 6,5 × et boss ≈ 33 × cette puissance (×1,2 aux
	-- paliers 5 et 10), soit une rencontre d'environ 60 coups. Réglage à confirmer par les statistiques.
	levels = {
		{ district = "Street Block", minions = 3, minionHP = 50, boss = "jade", bossHP = 250 },
		{ district = "Street Block", minions = 3, minionHP = 6200, boss = "iris", bossHP = 32000 },
		{ district = "Shopping Avenue", minions = 4, minionHP = 14000, boss = "jade", bossHP = 71000 },
		{ district = "Shopping Avenue", minions = 4, minionHP = 23000, boss = "iris", bossHP = 119000 },
		{ district = "Festival Park", minions = 4, minionHP = 34000, boss = "sienna", bossHP = 209000 },
		{ district = "Festival Park", minions = 4, minionHP = 45000, boss = "nova", bossHP = 230000 },
		{ district = "Skyline Rooftop", minions = 5, minionHP = 56000, boss = "sienna", bossHP = 285000 },
		{ district = "Skyline Rooftop", minions = 5, minionHP = 69000, boss = "nova", bossHP = 348000 },
		{ district = "World Stage", minions = 5, minionHP = 81000, boss = "zuri", bossHP = 412000 },
		{ district = "World Stage", minions = 5, minionHP = 94000, boss = "vega", bossHP = 570000 },
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
