--!strict
--[[
	BadgesConfig : vrais IDs des badges Roblox de chaque succès (dossier §19, §36).
	Créer les badges dans le Creator Dashboard (Expérience → Associated Items → Badges), puis coller ici
	leur ID. 0 = badge pas encore créé : le succès reste en attente (`pendingBadges`) et sera attribué
	automatiquement dès que l'ID est renseigné et la version publiée. Les récompenses internes, elles,
	sont déjà données : un badge n'est jamais la seule source de vérité du profil.
]]

return table.freeze({
	first_training = 0,
	first_look = 0,
	first_boss = 0,
	first_crew = 0,
	run_complete = 0,
	first_rebirth = 0,
	book_baddies_v1 = 0,
	book_crew_v1 = 0,
	mythic_found = 0,
	collection_v1 = 0,
} :: { [string]: number })
