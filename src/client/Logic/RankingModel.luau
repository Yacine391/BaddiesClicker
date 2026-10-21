--!strict
--[[
	RankingModel : lignes du tableau du lobby (§15) et texte des titres au-dessus des avatars (§19).
	Module pur, testé. Le classement est calculé par le serveur (snapshot.ranking, joueurs présents) :
	ici on ne fait que le mettre en forme.
]]

local RankingModel = {}

export type Line = { rank: string, name: string, score: string, isMe: boolean }
export type Board = { title: string, subtitle: string, lines: { Line }, empty: string? }

local MAX_NAME = 16

local function shorten(name: string): string
	if utf8.len(name) ~= nil and (utf8.len(name) :: number) > MAX_NAME then
		local cut = utf8.offset(name, MAX_NAME) :: number
		return string.sub(name, 1, cut - 1) .. "…"
	end
	return name
end

-- tab : "baddies" | "crew" ; max : nombre de lignes ; myUserId : surligner le joueur local
function RankingModel.board(ranking: { [string]: any }?, tab: string, max: number, myUserId: number?): Board
	local isCrew = tab == "crew"
	local total = if ranking then tonumber(if isCrew then ranking.crewTotal else ranking.total) else nil
	local board: Board = {
		title = if isCrew then "CLASSEMENT · CREW" else "CLASSEMENT · BADDIES",
		subtitle = if isCrew
			then "compagnons possédés"
			else `identités découvertes (lot {ranking and ranking.lot or "V1"})`,
		lines = {},
		empty = nil,
	}
	local entries = if ranking then (if isCrew then ranking.crew else ranking.baddies) else nil
	if type(entries) ~= "table" or #entries == 0 then
		board.empty = "En attente des joueurs du serveur…"
		return board
	end
	local mine: Line? = nil
	for index, entry in entries do
		local line: Line = {
			rank = `#{entry.rank or index}`,
			name = shorten(tostring(entry.name or "?")),
			score = if total then `{entry.score or 0}/{total}` else tostring(entry.score or 0),
			isMe = myUserId ~= nil and entry.userId == myUserId,
		}
		if index <= max then
			table.insert(board.lines, line)
		elseif line.isMe then
			mine = line
		end
	end
	-- Le joueur local hors du haut du tableau : sa ligne remplace la dernière
	if mine ~= nil and #board.lines == max then
		board.lines[max] = mine
	end
	return board
end

-- Titre affiché au-dessus d'un avatar (attribut BC_Title) ; nil = rien à afficher
function RankingModel.titleText(titleId: any, wardrobe: any): string?
	if type(titleId) ~= "string" or titleId == "" then
		return nil
	end
	local def = wardrobe.titles[titleId]
	return if def then def.name else nil
end

return RankingModel
