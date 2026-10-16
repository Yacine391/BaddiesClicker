--[[
	Simulateur d'équilibrage (dossier §29) : rejoue des parties complètes avec les VRAIES règles du
	serveur (Rules/Training, Crew, Combat, Encounter, Slots, Formulas) et un joueur modélisé.

	Depuis la racine du repo :
	  lune run tools/simulate                          rapport complet (valeurs du dossier, puis Balance actuelle)
	  lune run tools/simulate --runs 50 --hours 6      moins de parties, plus court
	  lune run tools/simulate --variant current        seulement la Balance actuelle
	  lune run tools/simulate --out docs/BALANCE-SIM.md

	Ce n'est PAS du code de jeu (rien n'est publié dans Studio). Les chiffres dépendent du joueur
	modélisé (PROFILES ci-dessous) : ils servent à comparer deux réglages, pas à prédire au jeu près.
]]

local fs = require("@lune/fs")
local process = require("@lune/process")

local BaseBalance = require("../src/shared/Balance")
local Catalog = require("../src/shared/Catalog")
local Formulas = require("../src/shared/Formulas")
local Wardrobe = require("../src/shared/Wardrobe")
local ProfileTemplate = require("../src/server/Rules/ProfileTemplate")
local Training = require("../src/server/Rules/Training")
local Crew = require("../src/server/Rules/Crew")
local CombatRules = require("../src/server/Rules/Combat")
local Encounter = require("../src/server/Rules/Encounter")
local Slots = require("../src/server/Rules/Slots")

--[[ Options ]]

local options = { runs = 100, hours = 10, seed = 20261015, out = nil :: string?, variant = "both" }
do
	local args = process.args
	local i = 1
	while i <= #args do
		local key, value = args[i], args[i + 1]
		if key == "--" then
			i -= 1 -- séparateur facultatif
		elseif key == "--runs" then
			options.runs = assert(tonumber(value), "--runs N")
		elseif key == "--hours" then
			options.hours = assert(tonumber(value), "--hours H")
		elseif key == "--seed" then
			options.seed = assert(tonumber(value), "--seed S")
		elseif key == "--out" then
			options.out = value
		elseif key == "--variant" then
			options.variant = value
		else
			error(`option inconnue : {key}`)
		end
		i += 2
	end
end

--[[ Joueurs modélisés : hypothèses à confronter aux statistiques réelles (Creator Hub) ]]

local PROFILES = {
	{
		id = "casual",
		label = "Occasionnel",
		trainRate = 3, -- maintien du bouton (§07, Balance.training.holdActionsPerSecond)
		attackRate = 4, -- clics par seconde en combat
		notice = 0.85, -- probabilité de voir une zone de danger à temps
		reactionMin = 0.25, -- délai avant de bouger (s)
		reactionMax = 0.6,
		walkSpeed = 16, -- WalkSpeed Roblox par défaut
		readyAttacks = 60, -- part au combat quand la rencontre tient en ~60 coups
		afterSetback = 0.6, -- après une mort ou un abandon : s'entraîne pour 40 % de coups en moins
		keepAt = 1.8, -- garde une principale à partir d'Iris (×1,8) : ne la relance plus
		lobbyToLevel1 = 15, -- trajet lobby → arène 1 (s)
		walkBetweenLevels = 8, -- porte → arène suivante (s)
		menuSeconds = 3, -- une relance, un coffre ou un drop (lecture + confirmation)
	},
	{
		id = "rushed",
		label = "Pressé",
		trainRate = 3,
		attackRate = 4,
		notice = 0.85,
		reactionMin = 0.25,
		reactionMax = 0.6,
		walkSpeed = 16,
		readyAttacks = 150, -- comme l'occasionnel, mais part au combat bien plus tôt (rencontres plus longues)
		afterSetback = 0.6,
		keepAt = 1.8,
		lobbyToLevel1 = 15,
		walkBetweenLevels = 8,
		menuSeconds = 3,
	},
	{
		id = "engaged",
		label = "Investi",
		trainRate = 6,
		attackRate = 7,
		notice = 0.95,
		reactionMin = 0.2,
		reactionMax = 0.4,
		walkSpeed = 16,
		readyAttacks = 80,
		afterSetback = 0.6,
		keepAt = 2.5,
		lobbyToLevel1 = 12,
		walkBetweenLevels = 6,
		menuSeconds = 2.5,
	},
	{
		id = "farmer",
		label = "Farmeur",
		farm = true, -- comme l'occasionnel, mais rejoue le dernier niveau terminé au lieu de s'entraîner
		trainRate = 3,
		attackRate = 4,
		notice = 0.85,
		reactionMin = 0.25,
		reactionMax = 0.6,
		walkSpeed = 16,
		readyAttacks = 60,
		afterSetback = 0.6,
		keepAt = 1.8,
		lobbyToLevel1 = 15,
		walkBetweenLevels = 8,
		menuSeconds = 3,
		replaySeconds = 3, -- relancer la vague depuis l'arène (bouton « rejouer »)
	},
}

--[[ Réglages comparés ]]

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local copy = {}
	for k, v in t do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Valeurs de test d'origine du dossier v4 (§09, §12), avant l'équilibrage d'octobre (docs/BALANCE.md)
local function dossierValues(B: any)
	B.version = "v4-p0"
	B.combat.minion.damagePerLevel = 5
	B.combat.boss.damagePerLevel = 8
	B.combat.minionPowerPerLevel = 2
	B.combat.bossPowerPerLevel = 10
	B.levels = {
		{ district = "Street Block", minions = 3, minionHP = 50, boss = "jade", bossHP = 250 },
		{ district = "Street Block", minions = 3, minionHP = 90, boss = "iris", bossHP = 450 },
		{ district = "Shopping Avenue", minions = 4, minionHP = 150, boss = "jade", bossHP = 800 },
		{ district = "Shopping Avenue", minions = 4, minionHP = 250, boss = "iris", bossHP = 1400 },
		{ district = "Festival Park", minions = 4, minionHP = 400, boss = "sienna", bossHP = 2500 },
		{ district = "Festival Park", minions = 4, minionHP = 650, boss = "nova", bossHP = 4000 },
		{ district = "Skyline Rooftop", minions = 5, minionHP = 1000, boss = "sienna", bossHP = 6500 },
		{ district = "Skyline Rooftop", minions = 5, minionHP = 1600, boss = "nova", bossHP = 10000 },
		{ district = "World Stage", minions = 5, minionHP = 2500, boss = "zuri", bossHP = 16000 },
		{ district = "World Stage", minions = 5, minionHP = 4000, boss = "vega", bossHP = 25000 },
	}
end

local VARIANTS = {
	{ id = "dossier", label = "Avant : valeurs de test du dossier", apply = dossierValues :: any },
	{ id = "current", label = "Après : Balance actuelle", apply = nil :: any },
}

local function makeCtx(apply: any)
	local B = deepCopy(BaseBalance)
	if apply ~= nil then
		apply(B)
	end
	return { Balance = B, Catalog = Catalog, Formulas = Formulas, Wardrobe = Wardrobe }
end

--[[ Simulation d'une partie ]]

local ARENA = { minX = -30, maxX = 30, minZ = -30, maxZ = 30 } -- intérieur d'une arène de test (DevWorld)
local MAX_FIGHT = 240 -- au-delà, le joueur abandonne la rencontre
local PUBLIC = #Catalog.baddieOrder
local CREW_TOTAL = #Catalog.crewOrder

local function newSim(ctx, P, rng)
	return {
		ctx = ctx,
		P = P,
		rng = rng,
		data = ProfileTemplate.new(ctx),
		t = 0,
		trainCarry = 0,
		streak = 0, -- secondes d'entraînement depuis la dernière décision
		streaks = {},
		location = "lobby",
		runStart = 0,
		time = { training = 0, combat = 0, travel = 0, menus = 0 },
		power = { training = 0, passive = 0, combat = 0 },
		tickets = { start = ctx.Balance.tickets.startBaddie, training = 0, firstClear = 0, rebirth = 0 },
		crewTickets = { training = 0, rebirth = 0 },
		milestones = {},
		attempts = {},
		victories = {},
		deaths = {},
		abandons = {},
		fightSeconds = {},
		clearPower = {},
		deathPower = {},
		readiness = {},
		rollsSinceDiscovery = 0,
		rolls = 0,
		guaranteed = 0,
		drops = { received = 0, accepted = 0, refused = 0 },
		telegraphs = 0,
		hits = 0,
		runDurations = {},
		runDeaths = {},
		replays = 0,
		rollsAtBook = nil :: number?,
		run1Power = nil :: any,
	}
end

local function mark(sim, key: string)
	if sim.milestones[key] == nil then
		sim.milestones[key] = sim.t
	end
end

local function bump(map, key, amount: number?)
	map[key] = (map[key] or 0) + (amount or 1)
end

local function discovered(data): number
	local n = 0
	for _, id in Catalog.baddieOrder do
		if data.discoveredBaddies[id] == true then
			n += 1
		end
	end
	return n
end

local function crewOwned(data): number
	local n = 0
	for _ in data.crew do
		n += 1
	end
	return n
end

local function onDiscovery(sim, baddieId: string)
	local n = discovered(sim.data)
	mark(sim, `book{n}`)
	if n >= PUBLIC and sim.rollsAtBook == nil then
		sim.rollsAtBook = sim.rolls
	end
	if baddieId == "vega" then
		mark(sim, "vega")
	end
end

-- Le temps passe : production passive des compagnons, entraînement si `rate` > 0
local function elapse(sim, seconds: number, kind: string, rate: number)
	local data, ctx = sim.data, sim.ctx
	sim.time[kind] += seconds
	local left = seconds
	while left > 1e-9 do
		local dt = math.min(1, left)
		left -= dt
		sim.t += dt
		if rate > 0 then
			sim.trainCarry += rate * dt
			local n = math.floor(sim.trainCarry)
			sim.trainCarry -= n
			for _ = 1, n do
				local r = Training.apply(data, ctx)
				sim.power.training += r.gained
				sim.tickets.training += r.baddieTickets
				sim.crewTickets.training += r.crewTickets
				if r.crewUnlocked ~= nil then
					Crew.grant(data, r.crewUnlocked, ctx)
					mark(sim, "malik")
				end
			end
		end
		sim.power.passive += Crew.applyPassive(data, dt, ctx)
	end
end

local function train(sim, seconds: number)
	sim.streak += seconds
	elapse(sim, seconds, "training", sim.P.trainRate)
end

local function decide(sim)
	if sim.streak > 0 then
		table.insert(sim.streaks, sim.streak)
		sim.streak = 0
	end
end

local function spend(sim, seconds: number, kind: string)
	elapse(sim, seconds, kind, 0)
end

local function menu(sim)
	spend(sim, math.max(sim.P.menuSeconds, sim.ctx.Balance.rolls.minIntervalSeconds), "menus")
end

-- Multiplicateur effectif d'une identité (maîtrise comprise)
local function valueOf(sim, baddieId: string?): number
	local def = if baddieId ~= nil then Catalog.baddies[baddieId] else nil
	if def == nil then
		return 0
	end
	local B = sim.ctx.Balance
	local mastery = Formulas.masteryLevel(sim.data.masteryXP[baddieId] or 0, B.mastery)
	return def.multiplier * (1 + B.mastery.damageBonusPerLevel * mastery)
end

local function slotValue(sim, slotId: string): number
	local slot = sim.data.slots[slotId]
	if slot == nil or Slots.isEmpty(slot) then
		return 0
	end
	return valueOf(sim, slot.baddieId)
end

local function bestSlot(sim, except: string?): (string?, number)
	local best, bestValue = nil, 0
	for _, id in Slots.orderedIds(sim.data) do
		local value = slotValue(sim, id)
		if id ~= except and value > bestValue then
			best, bestValue = id, value
		end
	end
	return best, bestValue
end

local function chooseActive(sim)
	local best = bestSlot(sim, nil)
	if best ~= nil and best ~= sim.data.activeSlotId then
		Slots.setActive(sim.data, best, sim.ctx)
	end
end

-- Relancer le temporaire ? (le joueur protège une bonne principale, dépense tout avant un effacement)
local function wantsRoll(sim, beforeRebirth: boolean): boolean
	local data, ctx = sim.data, sim.ctx
	local tempId = Slots.temporaryId(data)
	if tempId == nil or data.tickets.baddie < 1 then
		return false
	end
	if beforeRebirth and not Slots.rebirthPromotes(data.rebirths + 1, ctx) then
		return true -- le temporaire va être vidé : autant découvrir
	end
	local _, otherBest = bestSlot(sim, tempId)
	if otherBest >= slotValue(sim, tempId) then
		return true -- le temporaire ne sert qu'à découvrir
	end
	local def = Catalog.baddies[data.slots[tempId].baddieId]
	return def == nil or def.multiplier < sim.P.keepAt
end

local function roll(sim)
	local data, ctx = sim.data, sim.ctx
	local tempId = Slots.temporaryId(data) :: string
	local slot = data.slots[tempId]
	if Slots.checkRoll(data, tempId, slot.slotRevision) ~= nil then
		return false
	end
	decide(sim)
	local result = Slots.applyRoll(data, tempId, sim.rng(), ctx)
	sim.rolls += 1
	sim.rollsSinceDiscovery += 1
	if result.guaranteed then
		sim.guaranteed += 1
	end
	if result.isNew then
		sim.rollsSinceDiscovery = 0
		onDiscovery(sim, result.baddieId)
	end
	menu(sim)
	return true
end

local function decideDrops(sim)
	local data, ctx = sim.data, sim.ctx
	local ids = {}
	for id in data.pendingDrops do
		table.insert(ids, id)
	end
	table.sort(ids)
	for _, id in ids do
		while (data.pendingDrops[id] or 0) > 0 do
			decide(sim)
			local tempId = Slots.temporaryId(data)
			local accept = false
			if tempId ~= nil then
				local tempValue = slotValue(sim, tempId)
				local _, otherBest = bestSlot(sim, tempId)
				local tempIsMain = tempValue > otherBest
				if valueOf(sim, id) > tempValue then
					accept = true
				elseif data.discoveredBaddies[id] ~= true and not tempIsMain then
					accept = true
				end
			end
			if
				accept
				and Slots.checkAcceptDrop(
						data,
						id,
						data.slots[tempId].slotRevision,
						data.pendingRevision,
						ctx
					)
					== nil
			then
				local result = Slots.applyAcceptDrop(data, id, ctx)
				sim.drops.accepted += 1
				if result.isNew then
					onDiscovery(sim, id)
				end
			else
				Slots.applyRefuseDrop(data, id)
				sim.drops.refused += 1
			end
			menu(sim)
		end
	end
end

local function manageCrew(sim)
	local data, ctx = sim.data, sim.ctx
	while data.tickets.crew >= 1 do
		decide(sim)
		Crew.applyOpenChest(data, sim.rng(), ctx)
		mark(sim, `crew{crewOwned(data)}`)
		menu(sim)
	end
	for id in data.crew do
		while Crew.upgrade(data, id, ctx) == nil do
		end
	end
	local owned = {}
	for id, entry in data.crew do
		local rate = Formulas.crewRate(Catalog.crew[id].basePowerPerSecond, entry.level, ctx.Balance.crew)
		table.insert(owned, { id = id, rate = rate })
	end
	table.sort(owned, function(a, b)
		return if a.rate == b.rate then a.id < b.id else a.rate > b.rate
	end)
	local ids = {}
	for i = 1, math.min(ctx.Balance.crew.maxEquipped, #owned) do
		table.insert(ids, owned[i].id)
	end
	Crew.setEquipped(data, ids, ctx)
end

-- Décisions hors combat : drops, relances, coffres, principale
local function manage(sim, beforeRebirth: boolean)
	decideDrops(sim)
	while wantsRoll(sim, beforeRebirth) do
		if not roll(sim) then
			break
		end
		chooseActive(sim)
	end
	manageCrew(sim)
	chooseActive(sim)
end

local function damage(sim): number
	return CombatRules.attackDamage(sim.data, sim.ctx)
end

local function estimatedAttacks(sim, levelId: number): number
	return CombatRules.attacksToClear(levelId, damage(sim), sim.ctx)
end

local function nextLevel(sim): number
	return CombatRules.nextLevel(sim.data, sim.ctx) or #sim.ctx.Balance.levels
end

local function stepPlayer(player, dx: number, dz: number)
	player.x = math.clamp(player.x + dx, ARENA.minX + 2, ARENA.maxX - 2)
	player.z = math.clamp(player.z + dz, ARENA.minZ + 2, ARENA.maxZ - 2)
end

-- Déplacement du joueur modélisé : esquive les zones vues, sinon se rapproche de la cible
local function movePlayer(sim, player, dangers, enc, now: number, dt: number, range: number)
	local C = sim.ctx.Balance.combat
	local speed = sim.P.walkSpeed * dt
	local dx, dz = 0, 0
	local threatened = false
	for i = #dangers, 1, -1 do
		local d = dangers[i]
		if now > d.impactAt then
			table.remove(dangers, i)
		elseif now >= d.moveAt then
			local safe = d.radius - C.dodgeTolerance + 0.75
			local ox, oz = player.x - d.x, player.z - d.z
			local dist = math.sqrt(ox * ox + oz * oz)
			if dist < safe then
				threatened = true
				if dist < 1e-6 then
					-- frappe centrée sur lui : il part vers le centre de l'arène (ou de côté)
					ox, oz = -player.x, -player.z
					local n = math.sqrt(ox * ox + oz * oz)
					if n < 1e-6 then
						ox, oz = 1, 0
					else
						ox, oz = ox / n, oz / n
					end
				else
					ox, oz = ox / dist, oz / dist
				end
				dx += ox
				dz += oz
			end
		end
	end
	if threatened then
		local n = math.sqrt(dx * dx + dz * dz)
		if n < 1e-6 then
			dx, dz, n = 1, 0, 1
		end
		local beforeX, beforeZ = player.x, player.z
		stepPlayer(player, dx / n * speed, dz / n * speed)
		local moved = math.sqrt((player.x - beforeX) ^ 2 + (player.z - beforeZ) ^ 2)
		if moved < speed * 0.5 then
			stepPlayer(player, -dz / n * speed, dx / n * speed) -- coincé contre un mur : longer le mur
		end
		return
	end
	local nearest, best = nil, math.huge
	for _, id in enc.alive do
		local e = enc.enemies[id]
		local dist = Encounter.distance(e.pos, player)
		if dist < best then
			nearest, best = e, dist
		end
	end
	if nearest ~= nil and best > range - 3 then
		local step = math.min(speed, best - (range - 3))
		stepPlayer(player, (nearest.pos.x - player.x) / best * step, (nearest.pos.z - player.z) / best * step)
	end
end

local function fight(sim, levelId: number): string
	local ctx, data, P, rng = sim.ctx, sim.data, sim.P, sim.rng
	local C = ctx.Balance.combat
	local cfg = CombatRules.levelConfig(levelId, ctx)
	local dt = C.tickSeconds
	local range = C.attackRange + C.rangeTolerance
	local enc = Encounter.new("sim", levelId, cfg, ARENA, 0)
	local player = { x = 0, z = ARENA.maxZ - 4 }
	local hp = C.playerHP
	local dangers = {}
	local attackCarry = 0
	local now = 0
	local outcome = nil

	decide(sim)
	mark(sim, "firstCombat")
	bump(sim.attempts, levelId)
	while outcome == nil do
		now += dt
		sim.power.passive += Crew.applyPassive(data, dt, ctx)
		movePlayer(sim, player, dangers, enc, now, dt, range)
		for _, event in Encounter.step(enc, now, player, ctx) do
			if event.type == "telegraph" then
				sim.telegraphs += 1
				if rng() < P.notice then
					table.insert(dangers, {
						x = event.x,
						z = event.z,
						radius = event.radius,
						impactAt = now + event.duration,
						moveAt = now + P.reactionMin + rng() * (P.reactionMax - P.reactionMin),
					})
				end
			elseif event.type == "impact" and event.hit then
				sim.hits += 1
				hp -= event.damage
			end
		end
		if hp <= 0 then
			outcome = "death"
			break
		end
		attackCarry += P.attackRate * dt
		while attackCarry >= 1 and outcome == nil do
			attackCarry -= 1
			local result = Encounter.attack(enc, nil, player, damage(sim), range)
			if result ~= nil and result.killed then
				if result.kind == "boss" then
					local victory = CombatRules.applyBossVictory(data, levelId, rng(), ctx)
					sim.power.combat += victory.power
					sim.tickets.firstClear += victory.baddieTickets
					if victory.drop ~= nil then
						sim.drops.received += 1
						mark(sim, "firstDrop")
					end
					outcome = "victory"
				else
					sim.power.combat += CombatRules.applyMinionKill(data, levelId, ctx).power
				end
			end
		end
		if outcome == nil and now >= MAX_FIGHT then
			outcome = "abandon"
		end
	end

	sim.t += now
	sim.time.combat += now
	if outcome == "victory" then
		bump(sim.victories, levelId)
		if sim.fightSeconds[levelId] == nil then
			sim.fightSeconds[levelId] = now -- première victoire
			sim.clearPower[levelId] = data.power
		end
		mark(sim, `L{levelId}`)
	elseif outcome == "death" then
		bump(sim.deaths, levelId)
		table.insert(sim.deathPower, { level = levelId, power = data.power })
		CombatRules.applyDeath(data, ctx)
		bump(sim.runDeaths, data.rebirths + 1)
		sim.readiness[levelId] = (sim.readiness[levelId] or 1) * P.afterSetback
	else
		bump(sim.abandons, levelId)
		sim.readiness[levelId] = (sim.readiness[levelId] or 1) * P.afterSetback
	end
	return outcome
end

local function rebirth(sim)
	manage(sim, true)
	decide(sim)
	local data, ctx = sim.data, sim.ctx
	assert(Slots.checkRebirth(data, data.run.id, ctx) == nil, "renaissance impossible")
	local result = Slots.applyRebirth(data, ctx)
	sim.tickets.rebirth += result.baddieTickets
	sim.crewTickets.rebirth += result.crewTickets
	mark(sim, `rebirth{result.count}`)
	if result.count == 1 then
		sim.run1Power = table.clone(sim.power)
	end
	sim.runStart = sim.t
	sim.location = "lobby"
	sim.readiness = {}
	chooseActive(sim)
end

local function finished(sim): boolean
	return discovered(sim.data) >= PUBLIC and crewOwned(sim.data) >= CREW_TOTAL and sim.data.rebirths >= 6
end

local function simulate(ctx, P, seed: number, maxSeconds: number)
	math.randomseed(seed)
	local sim = newSim(ctx, P, math.random)
	local levels = #ctx.Balance.levels
	while sim.t < maxSeconds and not finished(sim) do
		manage(sim, false)
		local data = sim.data
		if Slots.rebirthAvailable(data, ctx) then
			rebirth(sim)
			continue
		end
		local levelId = nextLevel(sim)
		local threshold = P.readyAttacks * (sim.readiness[levelId] or 1)
		if estimatedAttacks(sim, levelId) > threshold then
			if P.farm and levelId > 1 and sim.location == "corridor" then
				-- rejouer le dernier niveau terminé (récompenses à chaque sbire et boss, drop 10 %)
				spend(sim, P.replaySeconds, "travel")
				sim.replays += 1
				fight(sim, levelId - 1)
				if not CombatRules.isCleared(data, levelId - 1) then
					sim.location = "lobby" -- mort pendant la rejouée : portes refermées
					spend(sim, ctx.Balance.combat.respawnDelay, "travel")
				end
			else
				train(sim, 5)
			end
			continue
		end
		if sim.location == "lobby" then
			decide(sim)
			spend(sim, P.lobbyToLevel1, "travel")
			sim.location = "corridor"
		end
		local outcome = fight(sim, levelId)
		if outcome == "victory" then
			sim.readiness[levelId] = nil
			if levelId == levels then
				table.insert(sim.runDurations, sim.t - sim.runStart)
			end
			spend(sim, P.walkBetweenLevels, "travel")
		elseif outcome == "death" then
			spend(sim, ctx.Balance.combat.respawnDelay, "travel")
			sim.location = "lobby"
		else
			spend(sim, P.walkBetweenLevels, "travel")
		end
	end
	decide(sim)
	return sim
end

--[[ Agrégation ]]

local function quantile(list: { number }, q: number): number?
	if #list == 0 then
		return nil
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	local index = math.clamp(math.floor(q * (#sorted - 1) + 0.5) + 1, 1, #sorted)
	return sorted[index]
end

local function mean(list: { number }): number
	if #list == 0 then
		return 0
	end
	local sum = 0
	for _, v in list do
		sum += v
	end
	return sum / #list
end

local function duration(seconds: number?): string
	if seconds == nil then
		return "—"
	end
	local total = math.floor(seconds + 0.5)
	if total < 60 then
		return `{total} s`
	end
	if total < 3600 then
		local m, s = total // 60, total % 60
		return if s == 0 then `{m} min` else `{m} min {string.format("%02d", s)}`
	end
	local minutes = math.floor(total / 60 + 0.5)
	return `{minutes // 60} h {string.format("%02d", minutes % 60)}`
end

local function fmt(value: number, decimals: number?): string
	local d = decimals or 0
	local text = string.format(`%.{d}f`, value)
	text = string.gsub(text, "%.", ",")
	return text
end

local function pct(value: number): string
	return `{fmt(value * 100)} %`
end

local MILESTONES = {
	{ "malik", "Malik obtenu (tutoriel)" },
	{ "firstCombat", "Premier combat" },
	{ "L1", "Premier boss vaincu (niveau 1)" },
	{ "L3", "Deuxième quartier (niveau 3 terminé)" },
	{ "L5", "Niveau 5 terminé" },
	{ "L10", "Premier parcours terminé (niveau 10)" },
	{ "rebirth1", "Première renaissance" },
	{ "rebirth3", "3e renaissance" },
	{ "rebirth6", "6e renaissance (4 slots)" },
	{ "firstDrop", "Premier drop de boss" },
	{ "book4", "4 baddies au Baddies Book" },
	{ "book8", "Baddies Book complet (8)" },
	{ "vega", "Vega (Mythic) découverte" },
	{ "crew6", "Les 6 compagnons" },
}

local function report(ctx, P, sims, out: { string })
	local B = ctx.Balance
	local levels = #B.levels
	local n = #sims
	local function add(line: string)
		table.insert(out, line)
	end

	add(`### Joueur « {P.label} » ({n} parties de {duration(options.hours * 3600)} maximum)`)
	add("")
	add(
		`Entraînement {P.trainRate}/s, attaque {P.attackRate}/s, voit {pct(P.notice)} des zones `
			.. `(réaction {fmt(P.reactionMin, 2)}–{fmt(P.reactionMax, 2)} s), part au combat vers `
			.. `{P.readyAttacks} coups, garde une principale à partir de ×{fmt(P.keepAt, 1)}.`
	)
	add("")
	add("| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |")
	add("|---|---|---|---|---|")
	for _, item in MILESTONES do
		local key, label = item[1], item[2]
		local list = {}
		for _, sim in sims do
			if sim.milestones[key] ~= nil then
				table.insert(list, sim.milestones[key])
			end
		end
		add(
			`| {label} | {duration(quantile(list, 0.5))} | {duration(quantile(list, 0.1))} | `
				.. `{duration(quantile(list, 0.9))} | {pct(#list / n)} |`
		)
	end
	add("")

	-- Parcours successifs
	local runs = {}
	for _, sim in sims do
		for i, d in sim.runDurations do
			runs[i] = runs[i] or {}
			table.insert(runs[i], d)
		end
	end
	local runCells = {}
	for i = 1, math.min(6, #runs) do
		table.insert(runCells, `parcours {i} : {duration(quantile(runs[i], 0.5))}`)
	end
	add(
		`Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — {table.concat(
			runCells,
			" · "
		)}.`
	)
	add("")

	-- Niveaux
	add(
		"| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |"
	)
	add("|---|---|---|---|---|---|")
	for levelId = 1, levels do
		local attempts, deaths, abandons, secs, power = {}, {}, {}, {}, {}
		for _, sim in sims do
			table.insert(attempts, sim.attempts[levelId] or 0)
			table.insert(deaths, sim.deaths[levelId] or 0)
			table.insert(abandons, sim.abandons[levelId] or 0)
			if sim.fightSeconds[levelId] ~= nil then
				table.insert(secs, sim.fightSeconds[levelId])
				table.insert(power, sim.clearPower[levelId])
			end
		end
		add(
			`| {levelId} | {fmt(mean(attempts), 1)} | {fmt(mean(deaths), 2)} | {fmt(mean(abandons), 2)} | `
				.. `{duration(quantile(secs, 0.5))} | {fmt(quantile(power, 0.5) or 0)} |`
		)
	end
	add("")

	-- Temps, puissance, tickets
	local tTrain, tCombat, tTravel, tMenus = {}, {}, {}, {}
	local pTrain, pPassive, pCombat = {}, {}, {}
	local r1Train, r1Passive, r1Combat = {}, {}, {}
	local ticketTrain, ticketFirst, ticketRebirth, ticketStart = {}, {}, {}, {}
	local hitRate, longest, medianStreak, rollsBook, guaranteed = {}, {}, {}, {}, {}
	local dropsReceived, dropsAccepted, telegraphs = {}, {}, {}
	for _, sim in sims do
		local total = sim.time.training + sim.time.combat + sim.time.travel + sim.time.menus
		table.insert(tTrain, sim.time.training / total)
		table.insert(tCombat, sim.time.combat / total)
		table.insert(tTravel, sim.time.travel / total)
		table.insert(tMenus, sim.time.menus / total)
		local power = sim.power.training + sim.power.passive + sim.power.combat
		table.insert(pTrain, sim.power.training / power)
		table.insert(pPassive, sim.power.passive / power)
		table.insert(pCombat, sim.power.combat / power)
		local r1 = sim.run1Power
		if r1 ~= nil then
			local total1 = r1.training + r1.passive + r1.combat
			table.insert(r1Train, r1.training / total1)
			table.insert(r1Passive, r1.passive / total1)
			table.insert(r1Combat, r1.combat / total1)
		end
		local tickets = sim.tickets.start
			+ sim.tickets.training
			+ sim.tickets.firstClear
			+ sim.tickets.rebirth
		table.insert(ticketStart, sim.tickets.start / tickets)
		table.insert(ticketTrain, sim.tickets.training / tickets)
		table.insert(ticketFirst, sim.tickets.firstClear / tickets)
		table.insert(ticketRebirth, sim.tickets.rebirth / tickets)
		table.insert(hitRate, if sim.telegraphs > 0 then sim.hits / sim.telegraphs else 0)
		table.insert(longest, quantile(sim.streaks, 1) or 0)
		table.insert(medianStreak, quantile(sim.streaks, 0.5) or 0)
		if sim.rollsAtBook ~= nil then
			table.insert(rollsBook, sim.rollsAtBook)
		end
		table.insert(guaranteed, sim.guaranteed)
		table.insert(dropsReceived, sim.drops.received)
		table.insert(telegraphs, sim.telegraphs)
		table.insert(dropsAccepted, sim.drops.accepted)
	end
	add(
		`- Temps de jeu : entraînement {pct(mean(tTrain))}, combat {pct(mean(tCombat))}, `
			.. `trajets {pct(mean(tTravel))}, menus {pct(mean(tMenus))}.`
	)
	add(
		`- Puissance gagnée pendant le premier parcours : entraînement {pct(mean(r1Train))}, `
			.. `compagnons (passif) {pct(mean(r1Passive))}, combats {pct(mean(r1Combat))} ; sur toute la partie : `
			.. `{pct(mean(pTrain))}, {pct(mean(pPassive))}, {pct(mean(pCombat))}.`
	)
	add(
		`- Tickets baddie : départ {pct(mean(ticketStart))}, entraînement {pct(mean(ticketTrain))}, `
			.. `premiers passages {pct(mean(ticketFirst))}, renaissances {pct(mean(ticketRebirth))}.`
	)
	add(
		`- Entraînement d'affilée sans décision : médiane {duration(mean(medianStreak))}, `
			.. `plus long par partie {duration(quantile(longest, 0.5))} (médiane), {duration(
				quantile(longest, 0.9)
			)} (10 % des parties).`
	)
	add(
		`- Zones de danger : {fmt(mean(telegraphs))} par partie, {pct(mean(hitRate))} touchent ; drops reçus {fmt(
			mean(dropsReceived),
			1
		)}, ` .. `acceptés {fmt(mean(dropsAccepted), 1)} par partie.`
	)
	add(
		`- Relances quand le Book est complet : médiane {fmt(quantile(rollsBook, 0.5) or 0)}, `
			.. `90 % des parties sous {fmt(quantile(rollsBook, 0.9) or 0)} ; garanties utilisées {fmt(
				mean(guaranteed),
				1
			)} par partie.`
	)
	local deathsByPower = {}
	for _, sim in sims do
		for _, d in sim.deathPower do
			table.insert(deathsByPower, d.power)
		end
	end
	if P.farm then
		local replays = {}
		for _, sim in sims do
			table.insert(replays, sim.replays)
		end
		add(`- Vagues rejouées au lieu de s'entraîner : {fmt(mean(replays))} par partie.`)
	end
	if #deathsByPower > 0 then
		add(
			`- Puissance à la mort : médiane {fmt(quantile(deathsByPower, 0.5) or 0)} `
				.. `({#deathsByPower} morts sur {n} parties).`
		)
	end
	add("")
end

-- Tableau fixe (sans hasard) : ce que demande chaque niveau, avec Maya ×1 sans maîtrise
local function levelTable(ctx, out: { string })
	local B = ctx.Balance
	local function add(line: string)
		table.insert(out, line)
	end
	local function attacksAt(cfg, power: number): number
		return cfg.minions * math.ceil(cfg.minionHP / power) + math.ceil(cfg.bossHP / power)
	end
	local function powerFor(cfg, attacks: number): number
		local low, high = 1, 1
		while attacksAt(cfg, high) > attacks do
			high *= 2
		end
		while low < high do
			local mid = (low + high) // 2
			if attacksAt(cfg, mid) <= attacks then
				high = mid
			else
				low = mid + 1
			end
		end
		return low
	end
	add(
		"| Niveau | Sbires × PV | PV boss | Coup sbire / boss | Coups pour mourir | Puissance pour ~60 coups "
			.. "| Récompense de la vague | Rejouer avec la puissance du niveau suivant |"
	)
	add("|---|---|---|---|---|---|---|---|")
	local levels = #B.levels
	for levelId = 1, levels do
		local cfg = CombatRules.levelConfig(levelId, ctx) :: any
		local hp = B.combat.playerHP
		local need = powerFor(cfg, 60)
		local reward = cfg.minions * B.combat.minionPowerPerLevel * levelId
			+ B.combat.bossPowerPerLevel * levelId
		local yield = "—"
		if levelId < levels then
			local nextCfg = CombatRules.levelConfig(levelId + 1, ctx) :: any
			local seconds = attacksAt(cfg, powerFor(nextCfg, 60)) / 4 + 6 -- 4 clics/s + apparitions et relance
			yield = `{fmt(reward / seconds, 1)}/s`
		end
		add(
			`| {levelId} | {cfg.minions} × {cfg.minionHP} | {cfg.bossHP} | {cfg.minionDamage} / {cfg.bossDamage} | `
				.. `{math.ceil(hp / cfg.minionDamage)} / {math.ceil(hp / cfg.bossDamage)} | {need} | {reward} | {yield} |`
		)
	end
	add("")
	add(
		`Entraînement : {fmt(B.training.holdActionsPerSecond * B.training.baseGain, 1)} puissance/s au maintien `
			.. "(×1,1 par renaissance). Rendement d'une vague rejouée : 4 clics/s et 6 s d'apparitions, "
			.. "avec la puissance qui suffit au niveau suivant."
	)
	add("")
end

--[[ Rapport ]]

local out = {}
table.insert(out, "# Rapport du simulateur d'équilibrage (`lune run tools/simulate`)")
table.insert(out, "")
table.insert(
	out,
	`Généré par \`tools/simulate.luau\` : {options.runs} parties par joueur et par réglage, graine {options.seed}. `
		.. "Les règles sont celles du serveur ; seul le joueur est modélisé."
)
table.insert(out, "")

local started = os.clock()
for _, variant in VARIANTS do
	if options.variant == "both" or options.variant == variant.id then
		local ctx = makeCtx(variant.apply)
		table.insert(out, `## {variant.label} ({ctx.Balance.version})`)
		table.insert(out, "")
		levelTable(ctx, out)
		for _, P in PROFILES do
			local sims = {}
			for i = 1, options.runs do
				table.insert(sims, simulate(ctx, P, options.seed + i, options.hours * 3600))
			end
			report(ctx, P, sims, out)
		end
	end
end

local text = table.concat(out, "\n")
if options.out ~= nil then
	fs.writeFile(options.out, text .. "\n")
	print(`rapport écrit dans {options.out} ({string.format("%.1f", os.clock() - started)} s)`)
else
	print(text)
	print(`\n({string.format("%.1f", os.clock() - started)} s)`)
end
