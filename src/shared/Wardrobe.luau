--!strict
--[[
	Wardrobe : garde-robe, titres et succès du joueur (dossier §19). Lu par le serveur ET le client.

	- L'avatar garde son identité Roblox ; la garde-robe AJOUTE des accessoires par emplacement
	  (cou, poignet, visage, tête, aura, trail, pose, cadre) pour limiter les conflits.
	- Déblocages permanents (mort et rebirth n'enlèvent rien), changeables hors combat.
	- Titres : affichés au-dessus de l'avatar (aucun texte libre), distincts du score du classement.
	- Succès : conditions vérifiées par le serveur (Rules/Achievements). Les listes « V1 » sont FIGÉES :
	  « Collection V1 complète » reste acquise si une V2 ajoute des personnages.
	- IDs stables : ne jamais renommer un ID publié.
	- Aucun require, aucune API Roblox : testable avec Lune.
]]

local Wardrobe = {
	-- Emplacements, dans l'ordre d'affichage
	slots = { "neck", "wrist", "face", "head", "aura", "trail", "pose", "frame" },
	slotLabels = {
		neck = "Cou",
		wrist = "Poignet",
		face = "Visage",
		head = "Tête",
		aura = "Aura",
		trail = "Trail",
		pose = "Pose",
		frame = "Cadre",
	},

	-- Cosmétiques du lot V1. `source` : succès qui le débloque, ou nil (source annoncée plus tard)
	items = {
		frame_simple = { slot = "frame", name = "Cadre simple", source = "first_training" },
		pose_photo = { slot = "pose", name = "Pose photo", source = "first_look" },
		headset_player = { slot = "head", name = "Casque de joueur", source = "first_crew" },
		chain_silver = { slot = "neck", name = "Chaîne argentée", source = "first_rebirth" },
		frame_crew = { slot = "frame", name = "Cadre Crew", source = "book_crew_v1" },
		aura_spark = { slot = "aura", name = "Aura Spark", source = "mythic_found" },
		chain_gold = { slot = "neck", name = "Chaîne dorée", source = "collection_v1" },
		frame_v1 = { slot = "frame", name = "Cadre V1", source = "collection_v1" },
		-- Sources ajoutées le 11/11 (exploits permanents, §32) : aucun cosmétique annoncé sans source
		watch = { slot = "wrist", name = "Montre", source = "daily_week" },
		glasses = { slot = "face", name = "Lunettes", source = "wheel_fan" },
		aura_neon = { slot = "aura", name = "Aura Neon", source = "mastery_five" },
		trail_stars = { slot = "trail", name = "Trail d'étoiles", source = "rebirth_three" },
	},
	itemOrder = {
		"frame_simple",
		"pose_photo",
		"headset_player",
		"chain_silver",
		"frame_crew",
		"aura_spark",
		"chain_gold",
		"frame_v1",
		"watch",
		"glasses",
		"aura_neon",
		"trail_stars",
	},

	-- Titres au-dessus de l'avatar
	titles = {
		boss_manager = { name = "Gérant de Baddies", source = "first_boss" },
		baddie_pro = { name = "Baddie Professionnel", source = "run_complete" },
		baddie_expert = { name = "Expert en Baddies", source = "book_baddies_v1" },
	},
	titleOrder = { "boss_manager", "baddie_pro", "baddie_expert" },

	-- Succès internes (§19) ; `rewards` = cosmétiques et titres débloqués une seule fois
	achievements = {
		first_training = {
			name = "Premier entraînement",
			condition = "20 actions d'entraînement acceptées",
			rewards = { items = { "frame_simple" } },
		},
		first_look = {
			name = "Premier look",
			condition = "Maya au niveau de maîtrise 1",
			rewards = { items = { "pose_photo" } },
		},
		first_boss = {
			name = "Premier boss",
			condition = "Boss du niveau 1 vaincu",
			rewards = { titles = { "boss_manager" } },
		},
		first_crew = {
			name = "Premier crew",
			condition = "Malik obtenu",
			rewards = { items = { "headset_player" } },
		},
		run_complete = {
			name = "Parcours terminé",
			condition = "Boss du niveau 10 vaincu",
			rewards = { titles = { "baddie_pro" } },
		},
		first_rebirth = {
			name = "Première renaissance",
			condition = "Renaissance 1 enregistrée",
			rewards = { items = { "chain_silver" } },
		},
		book_baddies_v1 = {
			name = "Book Baddies V1",
			condition = "Les 8 baddies du lot V1 découvertes",
			rewards = { titles = { "baddie_expert" } },
		},
		book_crew_v1 = {
			name = "Book Crew V1",
			condition = "Les 6 compagnons du lot V1 obtenus",
			rewards = { items = { "frame_crew" } },
		},
		mythic_found = {
			name = "Mythic découverte",
			condition = "Vega réellement récupérée (relance ou drop accepté)",
			rewards = { items = { "aura_spark" } },
		},
		collection_v1 = {
			name = "Collection V1 complète",
			condition = "Les deux Books V1 complets",
			rewards = { items = { "chain_gold", "frame_v1" } },
		},
		-- Exploits permanents ajoutés le 11/11 (badges Roblox à créer : Config/BadgesConfig)
		daily_week = {
			name = "Une semaine fidèle",
			condition = "7 récompenses de connexion réclamées",
			rewards = { items = { "watch" } },
		},
		wheel_fan = {
			name = "Tour de chance",
			condition = "10 tours de roue",
			rewards = { items = { "glasses" } },
		},
		mastery_five = {
			name = "Signature",
			condition = "Une baddie au niveau de maîtrise 5 (look 3 débloqué)",
			rewards = { items = { "aura_neon" } },
		},
		rebirth_three = {
			name = "Troisième renaissance",
			condition = "Renaissance 3 enregistrée",
			rewards = { items = { "trail_stars" } },
		},
	},
	achievementOrder = {
		"first_training",
		"first_look",
		"first_boss",
		"first_crew",
		"run_complete",
		"first_rebirth",
		"book_baddies_v1",
		"book_crew_v1",
		"mythic_found",
		"collection_v1",
		"daily_week",
		"wheel_fan",
		"mastery_five",
		"rebirth_three",
	},

	-- Listes FIGÉES du lot V1 (ne pas les relier au catalogue courant : une V2 ne doit rien retirer)
	lotV1 = {
		baddies = { "maya", "lina", "jade", "iris", "sienna", "nova", "zuri", "vega" },
		crew = { "enzo", "malik", "rafael", "dario", "kenji", "amine" },
	},
}

local function deepFreeze(t: any)
	for _, value in t do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	table.freeze(t)
end
deepFreeze(Wardrobe)

return Wardrobe
