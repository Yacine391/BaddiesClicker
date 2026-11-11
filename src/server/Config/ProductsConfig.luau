--!strict
--[[
	ProductsConfig : produits développeur Roblox (achats en Robux). Décision du 11/11 (tour de roue payant).

	Créer le produit dans le Creator Dashboard (Expérience → Monetization → Developer Products), prix 5 Robux,
	puis coller son ID ici. 0 = produit pas encore créé : le tour payant n'est PAS proposé au joueur
	(aucun faux bouton), le reste de la roue fonctionne (tour gratuit du jour, jetons, pièces).

	Chaque produit crédite un lot (Rules/Rewards.grant) une seule fois par reçu (PurchaseService).
	Tirage payant : les chances sont affichées dans la fenêtre de la roue, et le tour payant est masqué
	dans les pays où Roblox restreint les objets aléatoires payants (PolicyService).
]]

export type Product = { id: number, bundle: { [string]: number }, label: string }

return table.freeze({
	wheelSpin = table.freeze({
		id = 0, -- À RENSEIGNER : ID du produit « 1 tour de roue » (5 Robux)
		bundle = table.freeze({ wheelTokens = 1 }),
		label = "1 tour de roue",
	}),
}) :: { [string]: Product }
