--!strict
--[[
	Classement du lobby (module pur, testé dans tests/run.luau). Dossier §15.

	- Joueurs PRÉSENTS dans le serveur ; le classement mondial reste hors V1.
	- Baddies : nombre d'identités du lot public découvertes (« Alex - 7/8 »). Doublons, looks, boss
	  rencontrés, drops non acceptés et identités de test ne changent pas le score.
	- Compagnons : onglet séparé, nombre de compagnons du lot possédés.
	- Égalités : rang partagé, puis saut (1, 1, 3). À égalité, ordre alphabétique pour un affichage stable.
	- Le serveur calcule tout depuis les profils ; le client n'envoie jamais de score.
]]

export type Entry = { userId: number, name: string, score: number }
export type Ranked = { userId: number, name: string, score: number, rank: number }

local Ranking = {}

function Ranking.rank(entries: { Entry }): { Ranked }
	local list = table.clone(entries)
	table.sort(list, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		local an, bn = string.lower(a.name), string.lower(b.name)
		if an ~= bn then
			return an < bn
		end
		return a.userId < b.userId
	end)
	local ranked: { Ranked } = {}
	local rank = 0
	for index, entry in list do
		if index == 1 or entry.score ~= list[index - 1].score then
			rank = index
		end
		table.insert(ranked, { userId = entry.userId, name = entry.name, score = entry.score, rank = rank })
	end
	return ranked
end

-- Empreinte d'un classement : on ne renvoie l'état aux joueurs que si elle change
function Ranking.signature(list: { Ranked }): string
	local parts = {}
	for _, entry in list do
		table.insert(parts, `{entry.userId}:{entry.name}:{entry.score}:{entry.rank}`)
	end
	return table.concat(parts, "|")
end

return Ranking
