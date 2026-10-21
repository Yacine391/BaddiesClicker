--!strict
--[[
	BadgesConfig : vrais IDs des badges Roblox de chaque succès (dossier §19, §36).
	Créer les badges dans le Creator Dashboard (Expérience → Associated Items → Badges), puis coller ici
	leur ID. 0 = badge pas encore créé : le succès reste en attente (`pendingBadges`) et sera attribué
	automatiquement dès que l'ID est renseigné et la version publiée. Les récompenses internes, elles,
	sont déjà données : un badge n'est jamais la seule source de vérité du profil.

	Expérience « Click For u Baddies » (universe 10770935031). Icônes : assets/badges/ (tools/make_badges.py).
	Les 10 badges existent (5 le 15/10, 5 le 16/10 ; 5 gratuits par 24 h GMT, 100 Robux au-delà).
]]

return table.freeze({
	first_training = 3003701461600669,
	first_look = 2205159100902387,
	first_boss = 1304157737291845,
	first_crew = 1315516787837261,
	run_complete = 3967999521664107,
	first_rebirth = 608418536267242,
	book_baddies_v1 = 2687933298613433,
	book_crew_v1 = 1396893262067907,
	mythic_found = 2811471966761546,
	collection_v1 = 1916248291929445,
} :: { [string]: number })
