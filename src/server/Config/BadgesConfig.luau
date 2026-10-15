--!strict
--[[
	BadgesConfig : vrais IDs des badges Roblox de chaque succès (dossier §19, §36).
	Créer les badges dans le Creator Dashboard (Expérience → Associated Items → Badges), puis coller ici
	leur ID. 0 = badge pas encore créé : le succès reste en attente (`pendingBadges`) et sera attribué
	automatiquement dès que l'ID est renseigné et la version publiée. Les récompenses internes, elles,
	sont déjà données : un badge n'est jamais la seule source de vérité du profil.

	Expérience « Click For u Baddies » (universe 10770935031). Icônes : assets/badges/ (tools/make_badges.py).
	Roblox crée 5 badges gratuits par 24 h (GMT), 100 Robux au-delà : les 5 derniers restent à créer.
]]

return table.freeze({
	first_training = 3003701461600669,
	first_look = 2205159100902387,
	first_boss = 1304157737291845,
	first_crew = 1315516787837261,
	run_complete = 3967999521664107,
	first_rebirth = 0,
	book_baddies_v1 = 0,
	book_crew_v1 = 0,
	mythic_found = 0,
	collection_v1 = 0,
} :: { [string]: number })
