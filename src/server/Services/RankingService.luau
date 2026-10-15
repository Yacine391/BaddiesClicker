--[[
	RankingService : classement du lobby, calculé par le serveur pour les joueurs présents (§15).
	Rafraîchissement groupé (Balance.ranking.refreshSeconds) : une découverte, une arrivée ou un départ
	se voient en quelques secondes, et l'état n'est renvoyé aux joueurs que si le classement change.
	Règles dans Rules/Ranking ; score Baddies = Rules/Collection.bookCount, score Crew = compagnons possédés.
]]

local Players = game:GetService("Players")

local CollectionRules = require(script.Parent.Parent.Rules.Collection)
local CrewRules = require(script.Parent.Parent.Rules.Crew)
local RankingRules = require(script.Parent.Parent.Rules.Ranking)

local RankingService = {}

local ctx
local deps
local current = nil
local lastSignature = ""

function RankingService.init(context, dependencies)
	ctx = context
	deps = dependencies
	current = {
		lot = ctx.Catalog.lot,
		total = #ctx.Catalog.baddieOrder,
		crewTotal = #ctx.Catalog.crewOrder,
		baddies = {},
		crew = {},
	}
end

-- Classement courant (le même pour tous les joueurs du serveur)
function RankingService.view()
	return current
end

function RankingService.refresh()
	local baddies, crew = {}, {}
	for _, player in Players:GetPlayers() do
		local data = deps.Profiles.get(player)
		if data ~= nil then
			local book = CollectionRules.bookCount(data, ctx)
			local owned = #ctx.Catalog.crewOrder - #CrewRules.missing(data, ctx)
			table.insert(baddies, { userId = player.UserId, name = player.DisplayName, score = book })
			table.insert(crew, { userId = player.UserId, name = player.DisplayName, score = owned })
		end
	end
	local rankedBaddies = RankingRules.rank(baddies)
	local rankedCrew = RankingRules.rank(crew)
	local signature = RankingRules.signature(rankedBaddies) .. "#" .. RankingRules.signature(rankedCrew)
	if signature == lastSignature then
		return
	end
	lastSignature = signature
	current = {
		lot = ctx.Catalog.lot,
		total = #ctx.Catalog.baddieOrder,
		crewTotal = #ctx.Catalog.crewOrder,
		baddies = rankedBaddies,
		crew = rankedCrew,
	}
	for _, player in Players:GetPlayers() do
		deps.State.markDirty(player)
	end
end

function RankingService.start()
	task.spawn(function()
		while true do
			local ok, err = pcall(RankingService.refresh)
			if not ok then
				warn(`[RankingService] {err}`)
			end
			task.wait(ctx.Balance.ranking.refreshSeconds)
		end
	end)
end

return RankingService
