--!strict
--[[
	Récompenses (module pur, testé dans tests/run.luau) : pièces, roue, connexion quotidienne, temps de jeu.
	Décision du 11/11, hors dossier v4 ; chiffres dans Shared/Balance (coins, wheel, daily, playtime).

	- Le « jour » est un numéro de jour UTC calculé par le SERVEUR (os.time() // 86400) : rien ne dépend de
	  l'horloge du client. Une horloge serveur qui reculerait ne redonne jamais un tour ni une récompense.
	- Roue : un tour gratuit par jour, puis un jeton en réserve (acheté ou offert), puis des pièces. Le
	  tirage est fait une seule fois par le serveur. Une baddie gagnée est un DROP EN ATTENTE (§14) : elle
	  ne compte ni au Book, ni au classement, ni dans les dégâts tant qu'elle n'est pas acceptée.
	- Connexion quotidienne : une récompense par jour ; hier → série +1, sinon retour au jour 1.
	- Temps de jeu : compteur du jour, paliers réclamés un par un.
	- Achats : chaque reçu Roblox (PurchaseId) n'est crédité qu'une fois.
	Les résultats ne contiennent que des chaînes, nombres et booléens (reçus durables, Rules/Receipts).
]]

export type Bundle = { coins: number?, baddieTickets: number?, crewTickets: number?, wheelTokens: number? }

local Rewards = {}

local DAY = 86400

function Rewards.day(now: number): number
	return math.floor(now / DAY)
end

function Rewards.secondsUntilReset(now: number): number
	return DAY - (math.floor(now) % DAY)
end

-- Crédite un lot (pièces, tickets, jetons de roue) ; renvoie ce qui a été donné, en champs plats
function Rewards.grant(data: any, bundle: Bundle): { [string]: number }
	local given: { [string]: number } = {}
	if bundle.coins and bundle.coins > 0 then
		data.coins += bundle.coins
		given.coins = bundle.coins
	end
	if bundle.baddieTickets and bundle.baddieTickets > 0 then
		data.tickets.baddie += bundle.baddieTickets
		given.baddieTickets = bundle.baddieTickets
	end
	if bundle.crewTickets and bundle.crewTickets > 0 then
		data.tickets.crew += bundle.crewTickets
		given.crewTickets = bundle.crewTickets
	end
	if bundle.wheelTokens and bundle.wheelTokens > 0 then
		data.rewards.wheel.tokens += bundle.wheelTokens
		given.wheelTokens = bundle.wheelTokens
	end
	return given
end

----------------------------------------------------------------------------------------------------
-- Roue
----------------------------------------------------------------------------------------------------

function Rewards.freeSpinAvailable(data: any, day: number): boolean
	return data.rewards.wheel.lastFreeDay < day
end

-- Part tirée pour `roll` dans [0, 1) : (index, part)
function Rewards.pickSegment(roll: number, ctx: any): (number, any)
	local segments = ctx.Balance.wheel.segments
	local total = 0
	for _, segment in segments do
		total += segment.weight
	end
	local target = math.clamp(roll, 0, 0.999999999) * total
	local cumulative = 0
	for index, segment in segments do
		cumulative += segment.weight
		if target < cumulative then
			return index, segment
		end
	end
	return #segments, segments[#segments]
end

-- Baddies publiques d'une rareté, dans l'ordre du catalogue
function Rewards.baddiesOfRarity(rarity: string, ctx: any): { string }
	local list = {}
	for _, id in ctx.Catalog.baddieOrder do
		if ctx.Catalog.baddies[id].rarity == rarity then
			table.insert(list, id)
		end
	end
	return list
end

-- Identité gagnée pour une part « baddie » : chance égale entre les baddies de cette rareté
function Rewards.pickBaddie(rarity: string, roll: number, ctx: any): string?
	local list = Rewards.baddiesOfRarity(rarity, ctx)
	if #list == 0 then
		return nil
	end
	return list[math.clamp(math.floor(math.clamp(roll, 0, 0.999999999) * #list) + 1, 1, #list)]
end

-- Raisons : "invalid", "no_free", "no_token", "no_coins"
function Rewards.checkSpin(data: any, pay: any, day: number, ctx: any): string?
	if pay == "free" then
		return if Rewards.freeSpinAvailable(data, day) then nil else "no_free"
	elseif pay == "token" then
		return if data.rewards.wheel.tokens >= 1 then nil else "no_token"
	elseif pay == "coins" then
		return if data.coins >= ctx.Balance.wheel.spinCostCoins then nil else "no_coins"
	end
	return "invalid"
end

-- Paie le tour puis applique le gain. `roll` choisit la part, `roll2` l'identité d'une part « baddie ».
function Rewards.applySpin(
	data: any,
	pay: string,
	day: number,
	roll: number,
	roll2: number,
	ctx: any
): { [string]: any }
	local wheel = data.rewards.wheel
	if pay == "free" then
		wheel.lastFreeDay = day
	elseif pay == "token" then
		wheel.tokens -= 1
	else
		data.coins -= ctx.Balance.wheel.spinCostCoins
	end
	wheel.spins += 1

	local index, segment = Rewards.pickSegment(roll, ctx)
	local result: { [string]: any } = {
		pay = pay,
		index = index,
		segmentId = segment.id,
		prize = segment.kind,
		spinNumber = wheel.spins,
	}
	if segment.kind == "coins" then
		data.coins += segment.amount
		result.amount = segment.amount
	elseif segment.kind == "baddieTicket" then
		data.tickets.baddie += segment.amount
		result.amount = segment.amount
	elseif segment.kind == "crewTicket" then
		data.tickets.crew += segment.amount
		result.amount = segment.amount
	elseif segment.kind == "baddie" then
		local baddieId = Rewards.pickBaddie(segment.rarity, roll2, ctx)
		if baddieId ~= nil then
			-- drop en attente (§14) : inutilisable tant qu'il n'est pas accepté dans le temporaire
			data.pendingDrops[baddieId] = (data.pendingDrops[baddieId] or 0) + 1
			data.pendingRevision += 1
			result.baddieId = baddieId
			result.rarity = segment.rarity
		end
	end
	result.coins = data.coins
	result.tokens = wheel.tokens
	return result
end

----------------------------------------------------------------------------------------------------
-- Connexion quotidienne
----------------------------------------------------------------------------------------------------

function Rewards.dailyClaimed(data: any, day: number): boolean
	return data.rewards.daily.lastClaimDay >= day
end

-- Série que donnerait (ou qu'a donnée) la récompense d'aujourd'hui
function Rewards.dailyStreak(data: any, day: number): number
	local daily = data.rewards.daily
	if daily.lastClaimDay >= day then
		return math.max(1, daily.streak)
	elseif daily.lastClaimDay == day - 1 then
		return daily.streak + 1
	end
	return 1
end

-- Case du cycle (1 à 7) pour une série
function Rewards.dailyIndex(streak: number, ctx: any): number
	return (math.max(1, streak) - 1) % #ctx.Balance.daily.cycle + 1
end

function Rewards.checkDaily(data: any, day: number): string?
	return if Rewards.dailyClaimed(data, day) then "already" else nil
end

function Rewards.applyDaily(data: any, day: number, ctx: any): { [string]: any }
	local daily = data.rewards.daily
	local streak = Rewards.dailyStreak(data, day)
	local index = Rewards.dailyIndex(streak, ctx)
	daily.streak = streak
	daily.lastClaimDay = day
	daily.claims += 1
	local result: { [string]: any } = Rewards.grant(data, ctx.Balance.daily.cycle[index])
	result.streak = streak
	result.dayIndex = index
	return result
end

----------------------------------------------------------------------------------------------------
-- Temps de jeu du jour
----------------------------------------------------------------------------------------------------

-- Secondes jouées aujourd'hui (0 si le compteur date d'un autre jour)
function Rewards.playtimeSeconds(data: any, day: number): number
	local playtime = data.rewards.playtime
	return if playtime.day == day then playtime.seconds else 0
end

local function playtimeClaimed(data: any, index: number, day: number): boolean
	local playtime = data.rewards.playtime
	return playtime.day == day and playtime.claimed[tostring(index)] == true
end

-- Ajoute `dt` secondes au compteur du jour (borné) ; true si un palier vient de devenir réclamable
function Rewards.tickPlaytime(data: any, day: number, dt: number, ctx: any): boolean
	local playtime = data.rewards.playtime
	if playtime.day ~= day then
		playtime.day = day
		playtime.seconds = 0
		playtime.claimed = {}
	end
	if dt ~= dt or dt <= 0 then
		return false
	end
	local before = playtime.seconds
	playtime.seconds = math.min(DAY, before + math.min(dt, ctx.Balance.playtime.maxTickSeconds))
	for _, milestone in ctx.Balance.playtime.milestones do
		local needed = milestone.minutes * 60
		if before < needed and playtime.seconds >= needed then
			return true
		end
	end
	return false
end

-- Raisons : "invalid", "not_ready", "already"
function Rewards.checkPlaytime(data: any, index: any, day: number, ctx: any): string?
	local milestones = ctx.Balance.playtime.milestones
	if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > #milestones then
		return "invalid"
	end
	if playtimeClaimed(data, index, day) then
		return "already"
	end
	if Rewards.playtimeSeconds(data, day) < milestones[index].minutes * 60 then
		return "not_ready"
	end
	return nil
end

function Rewards.applyPlaytime(data: any, index: number, _day: number, ctx: any): { [string]: any }
	local playtime = data.rewards.playtime
	local milestone = ctx.Balance.playtime.milestones[index]
	playtime.claimed[tostring(index)] = true
	local result: { [string]: any } = Rewards.grant(data, milestone)
	result.index = index
	result.minutes = milestone.minutes
	return result
end

----------------------------------------------------------------------------------------------------
-- Achats (ProcessReceipt)
----------------------------------------------------------------------------------------------------

function Rewards.hasPurchase(data: any, purchaseId: string): boolean
	local rewards = data.rewards
	return type(rewards) == "table"
		and type(rewards.purchaseIds) == "table"
		and table.find(rewards.purchaseIds, purchaseId) ~= nil
end

-- Crédite un achat une seule fois ; false s'il était déjà crédité
function Rewards.applyPurchase(data: any, purchaseId: string, bundle: Bundle, ctx: any): boolean
	if Rewards.hasPurchase(data, purchaseId) then
		return false
	end
	Rewards.grant(data, bundle)
	local ids = data.rewards.purchaseIds
	table.insert(ids, purchaseId)
	while #ids > ctx.Balance.purchases.rememberedIds do
		table.remove(ids, 1)
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- Vue du client (snapshot.rewards)
----------------------------------------------------------------------------------------------------

-- `paid` : { productId: number?, allowed: boolean } — tour payant proposé seulement si les deux sont bons
function Rewards.view(data: any, now: number, ctx: any, paid: any?): { [string]: any }
	local B = ctx.Balance
	local day = Rewards.day(now)
	local wheel = data.rewards.wheel
	local free = Rewards.freeSpinAvailable(data, day)
	local dailyClaimed = Rewards.dailyClaimed(data, day)
	local streak = Rewards.dailyStreak(data, day)
	local seconds = Rewards.playtimeSeconds(data, day)

	local claimable = (if free then 1 else 0) + (if dailyClaimed then 0 else 1)
	local milestones = {}
	for index, milestone in B.playtime.milestones do
		local claimed = playtimeClaimed(data, index, day)
		local ready = not claimed and seconds >= milestone.minutes * 60
		if ready then
			claimable += 1
		end
		table.insert(milestones, { minutes = milestone.minutes, claimed = claimed, ready = ready })
	end

	local productId = if paid and paid.allowed == true then paid.productId else nil
	return {
		day = day,
		resetIn = Rewards.secondsUntilReset(now),
		claimable = claimable, -- pastille du menu : tour gratuit + connexion du jour + paliers prêts
		wheel = {
			free = free,
			tokens = wheel.tokens,
			cost = B.wheel.spinCostCoins,
			spins = wheel.spins,
			productId = productId, -- nil : tour payant non proposé (produit absent ou pays restreint)
			robux = if productId then B.wheel.robuxPerSpin else nil,
		},
		daily = {
			claimed = dailyClaimed,
			streak = streak,
			dayIndex = Rewards.dailyIndex(streak, ctx),
		},
		playtime = { seconds = seconds, milestones = milestones },
	}
end

return Rewards
