--!strict
--[[
	RewardsModel : textes et états de la fenêtre BONUS (roue, connexion quotidienne, temps de jeu).
	Module pur (testé dans tests/client/run.luau) : il lit `snapshot.rewards`, `snapshot.coins` et
	Shared/Balance, ne décide de rien. Le serveur reste seul juge (Rules/Rewards).
]]

local RewardsModel = {}

export type Segment = {
	index: number,
	id: string,
	short: string, -- texte sur la roue (« 40 », « ×3 », « GOLD »)
	caption: string, -- sous-texte sur la roue (« PIÈCES », « TICKETS », « BADDIE »)
	label: string, -- ligne de la liste des chances
	chance: string, -- « 24 % »
	color: string, -- hex
}

export type SpinOption = { pay: string, label: string, enabled: boolean }

export type WheelView = {
	primary: SpinOption, -- bouton principal : gratuit, puis jeton, puis pièces
	coinsOption: SpinOption?, -- « tourner pour 100 pièces » quand le bouton principal est autre chose
	buyLabel: string?, -- « ACHETER 1 TOUR · 5 ROBUX » ; nil : tour payant non proposé
	productId: number?,
	balanceText: string,
	freeText: string,
}

export type DayRow = { day: number, reward: string, state: "claimed" | "today" | "upcoming" }
export type DailyView = {
	rows: { DayRow },
	canClaim: boolean,
	streakText: string,
	nextText: string,
}

export type MilestoneRow = {
	index: number,
	title: string,
	reward: string,
	state: "claimed" | "ready" | "locked",
	progress: string,
	ratio: number,
}

local COINS, TICKET, CREW = "#D7A746", "#3EE6C8", "#B48CF0"

local function plural(n: number, word: string): string
	return `{n} {word}{if n > 1 then "s" else ""}`
end

-- « 1 h 05 », « 12 min », « 45 s » (durées courtes de l'interface)
function RewardsModel.duration(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return `{s // 3600} h {string.format("%02d", (s % 3600) // 60)}`
	elseif s >= 60 then
		return `{s // 60} min`
	end
	return `{s} s`
end

-- « 3:20 » (compteur du temps de jeu)
function RewardsModel.clock(seconds: number): string
	local s = math.max(0, math.floor(seconds))
	if s >= 3600 then
		return `{s // 3600}:{string.format("%02d", (s % 3600) // 60)}:{string.format("%02d", s % 60)}`
	end
	return `{s // 60}:{string.format("%02d", s % 60)}`
end

-- « 50 pièces + 1 jeton de roue »
function RewardsModel.bundleText(bundle: any): string
	local parts = {}
	if type(bundle) == "table" then
		if (tonumber(bundle.coins) or 0) > 0 then
			table.insert(parts, plural(bundle.coins, "pièce"))
		end
		if (tonumber(bundle.baddieTickets) or 0) > 0 then
			table.insert(parts, plural(bundle.baddieTickets, "ticket") .. " baddie")
		end
		if (tonumber(bundle.crewTickets) or 0) > 0 then
			table.insert(parts, plural(bundle.crewTickets, "ticket") .. " compagnon")
		end
		if (tonumber(bundle.wheelTokens) or 0) > 0 then
			table.insert(parts, plural(bundle.wheelTokens, "jeton") .. " de roue")
		end
	end
	return if #parts > 0 then table.concat(parts, " + ") else "—"
end

local function percent(weight: number, total: number, format: (number) -> string): string
	return format(math.round(weight / total * 1000) / 10) .. " %"
end

-- Parts de la roue dans l'ordre d'affichage, avec leur chance réelle (affichée avant chaque tour)
function RewardsModel.segments(balance: any, catalog: any, format: (number) -> string): { Segment }
	local source = balance.wheel.segments
	local total = 0
	for _, segment in source do
		total += segment.weight
	end
	local list: { Segment } = {}
	for index, segment in source do
		local short, caption, label, color
		if segment.kind == "coins" then
			short, caption, color = tostring(segment.amount), "PIÈCES", COINS
			label = plural(segment.amount, "pièce")
		elseif segment.kind == "baddieTicket" then
			short, caption, color = "×" .. tostring(segment.amount), "TICKET BADDIE", TICKET
			label = plural(segment.amount, "ticket") .. " baddie"
		elseif segment.kind == "crewTicket" then
			short, caption, color = "×" .. tostring(segment.amount), "TICKET CREW", CREW
			label = plural(segment.amount, "ticket") .. " compagnon"
		else
			local rarity = catalog.rarities[segment.rarity]
			local names = {}
			for _, id in catalog.baddieOrder do
				if catalog.baddies[id].rarity == segment.rarity then
					table.insert(names, catalog.baddies[id].name)
				end
			end
			short = string.upper(if rarity then rarity.label else segment.rarity)
			caption = "BADDIE"
			color = if rarity then rarity.color else "#FFFFFF"
			label = `Baddie {if rarity then rarity.label else segment.rarity} ({table.concat(names, " ou ")})`
		end
		table.insert(list, {
			index = index,
			id = segment.id,
			short = short,
			caption = caption,
			label = label,
			chance = percent(segment.weight, total, format),
			color = color,
		})
	end
	return list
end

-- Angle (degrés) du centre de la part `index`, 0 = en haut, sens horaire
function RewardsModel.segmentAngle(index: number, count: number): number
	return (index - 1) * 360 / math.max(1, count)
end

-- Rotation finale de la roue pour amener la part `index` sous le pointeur (en haut), après `turns`
-- tours complets, en repartant de `current` et en tournant toujours dans le sens horaire
function RewardsModel.landingRotation(current: number, index: number, count: number, turns: number): number
	local target = -RewardsModel.segmentAngle(index, count)
	local delta = (target - current) % 360
	return current + delta + 360 * turns
end

local function rewardsOf(snapshot: any): any?
	return if type(snapshot) == "table" and type(snapshot.rewards) == "table" then snapshot.rewards else nil
end

-- Nombre de récompenses à prendre (pastille du menu) ; "" si rien
function RewardsModel.badge(snapshot: any): string
	local rewards = rewardsOf(snapshot)
	local count = if rewards then tonumber(rewards.claimable) or 0 else 0
	return if count > 0 then tostring(count) else ""
end

function RewardsModel.coinsText(snapshot: any, format: (number) -> string): string
	return format(if type(snapshot) == "table" then tonumber(snapshot.coins) or 0 else 0)
end

function RewardsModel.wheel(snapshot: any, balance: any, format: (number) -> string): WheelView
	local rewards = rewardsOf(snapshot)
	local wheel = if rewards and type(rewards.wheel) == "table" then rewards.wheel else {}
	local coins = if type(snapshot) == "table" then tonumber(snapshot.coins) or 0 else 0
	local cost = tonumber(wheel.cost) or balance.wheel.spinCostCoins
	local tokens = tonumber(wheel.tokens) or 0
	local ready = rewards ~= nil
	local coinsOption: SpinOption = {
		pay = "coins",
		label = `TOURNER · {format(cost)} PIÈCES`,
		enabled = ready and coins >= cost,
	}
	local primary: SpinOption
	local secondary: SpinOption? = nil
	if wheel.free == true then
		primary = { pay = "free", label = "TOUR GRATUIT DU JOUR", enabled = true }
		secondary = coinsOption
	elseif tokens > 0 then
		primary = { pay = "token", label = `UTILISER 1 JETON ({tokens})`, enabled = true }
		secondary = coinsOption
	else
		primary = coinsOption
	end
	local productId = tonumber(wheel.productId)
	return {
		primary = primary,
		coinsOption = secondary,
		buyLabel = if productId
			then `ACHETER 1 TOUR · {wheel.robux or balance.wheel.robuxPerSpin} ROBUX`
			else nil,
		productId = productId,
		balanceText = `{format(coins)} pièces · {plural(tokens, "jeton")}`,
		freeText = if wheel.free == true
			then "Ton tour gratuit du jour t'attend."
			elseif rewards then `Prochain tour gratuit dans {RewardsModel.duration(
				tonumber(rewards.resetIn) or 0
			)}.`
			else "",
	}
end

-- Texte du gain d'un tour (résultat de la décision SpinWheel)
function RewardsModel.prizeText(result: any, catalog: any): string
	if type(result) ~= "table" then
		return ""
	end
	local amount = tonumber(result.amount) or 0
	if result.prize == "coins" then
		return `+{plural(amount, "pièce")}`
	elseif result.prize == "baddieTicket" then
		return `+{plural(amount, "ticket")} baddie`
	elseif result.prize == "crewTicket" then
		return `+{plural(amount, "ticket")} compagnon`
	elseif result.prize == "baddie" then
		local def = catalog.baddies[result.baddieId]
		local rarity = if def then catalog.rarities[def.rarity] else nil
		local name = if def then string.upper(def.name) else "?"
		return `DROP : {name}{if rarity then ` ({rarity.label})` else ""} — accepte-le dans SLOTS`
	end
	return ""
end

function RewardsModel.daily(snapshot: any, balance: any): DailyView
	local rewards = rewardsOf(snapshot)
	local daily = if rewards and type(rewards.daily) == "table" then rewards.daily else {}
	local claimed = daily.claimed == true
	local today = math.clamp(tonumber(daily.dayIndex) or 1, 1, #balance.daily.cycle)
	local streak = tonumber(daily.streak) or 1
	local rows: { DayRow } = {}
	for day, bundle in balance.daily.cycle do
		local state: "claimed" | "today" | "upcoming"
		if day < today or (day == today and claimed) then
			state = "claimed"
		elseif day == today then
			state = "today"
		else
			state = "upcoming"
		end
		table.insert(rows, { day = day, reward = RewardsModel.bundleText(bundle), state = state })
	end
	local resetIn = if rewards then tonumber(rewards.resetIn) or 0 else 0
	return {
		rows = rows,
		canClaim = rewards ~= nil and not claimed,
		streakText = if claimed then `Série : {plural(streak, "jour")}` else `Série en jeu : jour {streak}`,
		nextText = if claimed
			then `Reviens dans {RewardsModel.duration(resetIn)} : un jour manqué ramène la série au jour 1.`
			else "Une récompense par jour. Un jour manqué ramène la série au jour 1.",
	}
end

function RewardsModel.playtime(snapshot: any, balance: any): { MilestoneRow }
	local rewards = rewardsOf(snapshot)
	local playtime = if rewards and type(rewards.playtime) == "table" then rewards.playtime else {}
	local seconds = tonumber(playtime.seconds) or 0
	local states = if type(playtime.milestones) == "table" then playtime.milestones else {}
	local rows: { MilestoneRow } = {}
	for index, milestone in balance.playtime.milestones do
		local needed = milestone.minutes * 60
		local s = states[index]
		local state: "claimed" | "ready" | "locked"
		if type(s) == "table" and s.claimed == true then
			state = "claimed"
		elseif type(s) == "table" and s.ready == true then
			state = "ready"
		else
			state = "locked"
		end
		local title = if milestone.minutes >= 60
			then `{milestone.minutes // 60} HEURE{if milestone.minutes >= 120 then "S" else ""}`
			else `{milestone.minutes} MINUTES`
		table.insert(rows, {
			index = index,
			title = title,
			reward = RewardsModel.bundleText(milestone),
			state = state,
			progress = if state == "locked"
				then `{RewardsModel.clock(math.min(seconds, needed))} / {RewardsModel.clock(needed)}`
				elseif state == "ready" then "Prêt !"
				else "Reçu",
			ratio = math.clamp(seconds / needed, 0, 1),
		})
	end
	return rows
end

-- Secondes de jeu du jour telles qu'envoyées par le serveur (nil si absentes) : le HUD ne remet son
-- compte local à zéro que quand cette valeur change, pas à chaque snapshot
function RewardsModel.playtimeSeconds(snapshot: any): number?
	local rewards = rewardsOf(snapshot)
	if not rewards or type(rewards.playtime) ~= "table" then
		return nil
	end
	return tonumber(rewards.playtime.seconds)
end

-- Texte de la tuile cadeau : "PRÊT" si un palier attend, sinon le temps restant avant le prochain,
-- "" quand tout est reçu. `extraSeconds` = secondes écoulées depuis le snapshot (compte côté client).
function RewardsModel.giftText(snapshot: any, balance: any, extraSeconds: number): string
	local rewards = rewardsOf(snapshot)
	if not rewards or type(rewards.playtime) ~= "table" then
		return ""
	end
	local seconds = (tonumber(rewards.playtime.seconds) or 0) + math.max(0, extraSeconds)
	local states = if type(rewards.playtime.milestones) == "table" then rewards.playtime.milestones else {}
	local nextNeeded: number? = nil
	for index, milestone in balance.playtime.milestones do
		local s = states[index]
		if type(s) == "table" and s.ready == true and s.claimed ~= true then
			return "PRÊT"
		end
		if nextNeeded == nil and not (type(s) == "table" and s.claimed == true) then
			nextNeeded = milestone.minutes * 60
		end
	end
	if nextNeeded == nil then
		return ""
	end
	return RewardsModel.clock(math.max(0, nextNeeded - seconds))
end

-- Toast d'un événement Result des récompenses, ou nil
function RewardsModel.toastFor(event: { [string]: any }): string?
	if event.kind == "dailyReward" then
		return `Jour {event.dayIndex or 1} : {RewardsModel.bundleText(event)}`
	elseif event.kind == "playtimeReward" then
		return `Temps de jeu : {RewardsModel.bundleText(event)}`
	elseif event.kind == "playtimeReady" then
		return "Récompense de temps de jeu prête (BONUS)"
	elseif event.kind == "purchase" then
		return `Achat reçu : {tostring(event.product or "tour de roue")}`
	end
	return nil
end

return RewardsModel
