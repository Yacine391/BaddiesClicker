--[[
	Tests des règles pures (dossier v4 §29-30), sans Studio.
	Depuis la racine du repo :  lune run tests/run

	Balance, Catalog, Formulas, Format, Rules/* et Util/RateLimiter n'utilisent
	aucune API Roblox : on peut donc les tester ici, en quelques millisecondes.
]]

local process = require("@lune/process")

local Balance = require("../src/shared/Balance")
local Catalog = require("../src/shared/Catalog")
local Formulas = require("../src/shared/Formulas")
local Format = require("../src/shared/Format")
local ProfileTemplate = require("../src/server/Rules/ProfileTemplate")
local Training = require("../src/server/Rules/Training")
local Crew = require("../src/server/Rules/Crew")
local RateLimiter = require("../src/server/Util/RateLimiter")
local CombatRules = require("../src/server/Rules/Combat")
local Encounter = require("../src/server/Rules/Encounter")
local Slots = require("../src/server/Rules/Slots")
local Collection = require("../src/server/Rules/Collection")
local Receipts = require("../src/server/Rules/Receipts")
local TestCatalog = require("../src/shared/TestCatalog")
local ProfileGuard = require("../src/server/Rules/ProfileGuard")
local Ranking = require("../src/server/Rules/Ranking")
local Achievements = require("../src/server/Rules/Achievements")
local Metrics = require("../src/server/Rules/Metrics")
local profileV4P0 = require("./fixtures/profile_v4_p0")

local Wardrobe = require("../src/shared/Wardrobe")
local ctx = { Balance = Balance, Catalog = Catalog, Formulas = Formulas, Wardrobe = Wardrobe }

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
		print(`  ok   {name}`)
	else
		failed += 1
		print(`  FAIL {name}\n         {err}`)
	end
end

local function eq(actual: any, expected: any, what: string?)
	if actual ~= expected then
		error(`{what or "valeur"} : attendu {tostring(expected)}, obtenu {tostring(actual)}`, 2)
	end
end

local function near(actual: number, expected: number, what: string?, eps: number?)
	if math.abs(actual - expected) > (eps or 1e-9) then
		error(`{what or "valeur"} : attendu ≈{expected}, obtenu {actual}`, 2)
	end
end

local function newProfile()
	return ProfileTemplate.new(ctx)
end

local function trainTimes(data, n: number)
	local last
	for _ = 1, n do
		last = Training.apply(data, ctx)
	end
	return last
end

print("Catalogue et équilibrage")

test("chances de relance baddies = 100 %", function()
	local sum = 0
	for _, id in Catalog.baddieOrder do
		sum += Catalog.baddies[id].rollChance
	end
	near(sum, 100, "somme")
end)

test("chances de coffre compagnons = 100 %", function()
	local sum = 0
	for _, id in Catalog.crewOrder do
		sum += Catalog.crew[id].chestChance
	end
	near(sum, 100, "somme")
end)

test("ordres du catalogue complets et cohérents", function()
	local count = 0
	for id in Catalog.baddies do
		count += 1
		assert(table.find(Catalog.baddieOrder, id), `{id} absent de baddieOrder`)
		assert(Catalog.rarities[Catalog.baddies[id].rarity], `rareté inconnue pour {id}`)
	end
	eq(count, #Catalog.baddieOrder, "nombre de baddies")
	eq(count, 8, "lot V1")
	local crewCount = 0
	for id in Catalog.crew do
		crewCount += 1
		assert(table.find(Catalog.crewOrder, id), `{id} absent de crewOrder`)
	end
	eq(crewCount, 6, "compagnons V1")
end)

test("dix niveaux, chaque boss existe dans le catalogue", function()
	eq(#Balance.levels, 10, "niveaux")
	for i, level in Balance.levels do
		assert(Catalog.baddies[level.boss], `boss inconnu au niveau {i}`)
	end
	eq(Balance.levels[1].minionHP, 50, "sbire niveau 1")
	eq(Balance.levels[1].bossHP, 250, "boss niveau 1")
	eq(Balance.levels[10].boss, "vega", "boss niveau 10")
end)

test("Balance et Catalog sont gelés", function()
	assert(table.isfrozen(Balance) and table.isfrozen(Balance.training), "Balance non gelé")
	assert(table.isfrozen(Catalog.baddies.maya), "Catalog non gelé")
end)

print("Formules (§12, §29)")

test("bonus d'entraînement : 1 → ×3 plafonné au rebirth 20", function()
	near(Formulas.trainingBonus(0, Balance.training), 1)
	near(Formulas.trainingBonus(1, Balance.training), 1.1)
	near(Formulas.trainingBonus(20, Balance.training), 3)
	near(Formulas.trainingBonus(35, Balance.training), 3)
end)

test("exemple §29 : 100 puissance, Nova ×2,5, maîtrise 10 → 375 dégâts/clic", function()
	near(Formulas.damagePerClick(100, Catalog.baddies.nova.multiplier, 10, Balance.mastery), 375)
end)

test("exemples §29 : coups pour tuer un sbire de 50 HP et le boss 1", function()
	local m = Balance.mastery
	eq(Formulas.hitsToKill(50, Formulas.damagePerClick(1, 1, 0, m)), 50, "puissance 1, Maya")
	eq(Formulas.hitsToKill(50, Formulas.damagePerClick(10, 1, 0, m)), 5, "puissance 10, Maya")
	eq(
		Formulas.hitsToKill(50, Formulas.damagePerClick(10, Catalog.baddies.vega.multiplier, 0, m)),
		2,
		"puissance 10, Vega"
	)
	eq(Formulas.hitsToKill(250, 10), 25, "boss 250 HP à 10/clic")
end)

test("boss 10 % : 65,1 % après 10 victoires, 87,8 % après 20", function()
	near(Formulas.chanceAtLeastOne(Balance.combat.bossDropChance, 10), 0.6513, "10 victoires", 1e-4)
	near(Formulas.chanceAtLeastOne(Balance.combat.bossDropChance, 20), 0.8784, "20 victoires", 1e-4)
end)

test("maîtrise : seuil 10 × L², plafond 10", function()
	local m = Balance.mastery
	eq(Formulas.masteryLevel(0, m), 0)
	eq(Formulas.masteryLevel(9, m), 0)
	eq(Formulas.masteryLevel(10, m), 1, "premier look évolué à 10 XP")
	eq(Formulas.masteryLevel(39, m), 1)
	eq(Formulas.masteryLevel(40, m), 2)
	eq(Formulas.masteryLevel(250, m), 5, "look 3 à maîtrise 5")
	eq(Formulas.masteryLevel(1000, m), 10)
	eq(Formulas.masteryLevel(999999, m), 10)
end)

test("taux compagnon : base × (1 + 0,10 × (L - 1)), borné", function()
	near(Formulas.crewRate(0.6, 1, Balance.crew), 0.6)
	near(Formulas.crewRate(0.6, 10, Balance.crew), 1.14)
	near(Formulas.crewRate(0.6, 15, Balance.crew), 1.14)
end)

print("Profil neuf (§24)")

test("profil neuf conforme au schéma 4", function()
	local p = newProfile()
	eq(p.schemaVersion, 4, "schemaVersion")
	eq(p.power, 1, "puissance")
	eq(p.tickets.baddie, 10, "tickets baddie")
	eq(p.slots.s1.baddieId, "maya", "slot 1")
	eq(p.activeSlotId, "s1", "principale")
	eq(p.discoveredBaddies.maya, true, "Maya découverte")
	eq(#p.equippedCrew, 0, "aucun compagnon équipé")
end)

test("deux profils neufs ne partagent aucune table", function()
	local a, b = newProfile(), newProfile()
	a.tickets.baddie = 0
	eq(b.tickets.baddie, 10, "tickets du second profil")
end)

print("Entraînement")

test("une action : +1 puissance, compteurs à 1", function()
	local p = newProfile()
	local r = Training.apply(p, ctx)
	near(r.gained, 1)
	near(p.power, 2)
	eq(p.stats.trainActions, 1)
	eq(p.trainCounters.baddie, 1)
end)

test("rebirth 20 : une action donne ×3", function()
	local p = newProfile()
	p.rebirths = 20
	near(Training.apply(p, ctx).gained, 3)
end)

test("ticket baddie toutes les 250 actions, compagnon toutes les 500", function()
	local p = newProfile()
	trainTimes(p, 249)
	eq(p.tickets.baddie, 10, "avant 250")
	local r = Training.apply(p, ctx)
	eq(r.baddieTickets, 1, "250e action")
	eq(p.tickets.baddie, 11)
	eq(p.trainCounters.baddie, 0, "compteur remis à zéro")
	trainTimes(p, 250)
	eq(p.tickets.baddie, 12)
	eq(p.tickets.crew, 1, "ticket compagnon à 500")
end)

test("impossible de s'entraîner en combat", function()
	eq((Training.canTrain({ inCombat = true })), false)
	eq((Training.canTrain({ inCombat = false })), true)
end)

test("tutoriel : Malik débloqué à la 10e action, une seule fois", function()
	local p = newProfile()
	local r = trainTimes(p, 9)
	eq(r.crewUnlocked, nil, "9e action")
	r = Training.apply(p, ctx)
	eq(r.crewUnlocked, "malik", "10e action")
	r = Training.apply(p, ctx)
	eq(r.crewUnlocked, nil, "11e action")
end)

print("Compagnons (§16)")

test("Malik obtenu : niveau 1, équipé, 0,6/s", function()
	local p = newProfile()
	local g = Crew.grant(p, "malik", ctx)
	eq(g.isNew, true)
	eq(g.equipped, true)
	eq(p.crew.malik.level, 1)
	near(Crew.passivePerSecond(p, ctx), 0.6)
end)

test("doublon : +1 copie, toujours un seul Malik actif", function()
	local p = newProfile()
	Crew.grant(p, "malik", ctx)
	local g = Crew.grant(p, "malik", ctx)
	eq(g.isNew, false)
	eq(g.copies, 1)
	eq(#p.equippedCrew, 1)
end)

test("deux compagnons équipés au maximum", function()
	local p = newProfile()
	Crew.grant(p, "malik", ctx)
	Crew.grant(p, "enzo", ctx)
	local g = Crew.grant(p, "rafael", ctx)
	eq(g.equipped, false, "3e compagnon")
	eq(#p.equippedCrew, 2)
	near(Crew.passivePerSecond(p, ctx), 1.0, "0,6 + 0,4")
end)

test("production passive : réelle, bonus de rebirth, plafond par tick", function()
	local p = newProfile()
	Crew.grant(p, "malik", ctx)
	near(Crew.applyPassive(p, 1, ctx), 0.6, "1 s")
	near(p.power, 1.6)
	near(p.stats.crewPowerEarned, 0.6)
	eq(Crew.applyPassive(p, 0, ctx), 0, "dt nul")
	near(Crew.applyPassive(p, 60, ctx), 3.0, "tick plafonné à 5 s")
	p.rebirths = 20
	near(Crew.passivePerSecond(p, ctx), 1.8, "rebirth 20")
end)

test("sans compagnon : aucune production", function()
	local p = newProfile()
	eq(Crew.applyPassive(p, 1, ctx), 0)
end)

print("Réseau et affichage")

test("limite de cadence : 8 d'un coup, puis 8/s", function()
	local b = RateLimiter.new(8, 8)
	local ok = 0
	for _ = 1, 20 do
		if RateLimiter.allow(b, 0) then
			ok += 1
		end
	end
	eq(ok, 8, "rafale")
	ok = 0
	for _ = 1, 20 do
		if RateLimiter.allow(b, 0.5) then
			ok += 1
		end
	end
	eq(ok, 4, "après 0,5 s")
end)

test("format français des nombres", function()
	eq(Format.number(0.6), "0,6")
	eq(Format.number(12), "12")
	eq(Format.number(12.44), "12,4")
	eq(Format.number(999), "999")
	eq(Format.number(1530), "1,53 K")
	eq(Format.number(2000000), "2 M")
	eq(Format.number(0 / 0), "—")
end)

print("Combat : règles (§09 à §14, §26, §30)")

local BOUNDS = { minX = -30, maxX = 30, minZ = -120, maxZ = -60 }
local INSIDE = { x = 0, z = -90 }

local function newEncounter()
	return Encounter.new("t", 1, CombatRules.levelConfig(1, ctx), BOUNDS, 0)
end

local function run(enc, from: number, to: number, player)
	local events = {}
	local t = from
	while t <= to + 1e-9 do
		for _, e in Encounter.step(enc, t, player, ctx) do
			table.insert(events, e)
		end
		t += 0.1
	end
	return events
end

local function countType(events, kind: string): number
	local n = 0
	for _, e in events do
		if e.type == kind then
			n += 1
		end
	end
	return n
end

-- Tue tous les sbires (en laissant le temps aux apparitions) ; renvoie l'instant atteint
local function clearMinions(enc, t: number): number
	while true do
		run(enc, t, t + 1, INSIDE)
		t += 1.1
		if enc.phase ~= "wave" then
			return t -- le boss vient d'apparaître : on ne le touche pas ici
		end
		for _ = 1, #enc.alive do
			Encounter.attack(enc, nil, INSIDE, 1e9, 1000)
		end
	end
end

test("niveau 1 : 3 sbires de 50 PV puis Jade 250 PV", function()
	local cfg = CombatRules.levelConfig(1, ctx)
	assert(cfg ~= nil)
	eq(cfg.minions, 3, "sbires")
	eq(cfg.minionHP, 50, "PV sbire")
	eq(cfg.boss, "jade", "boss")
	eq(cfg.bossHP, 250, "PV boss")
	eq(CombatRules.levelConfig(11, ctx), nil, "niveau 11")
end)

test("accès : niveau 1 ouvert, niveau 2 seulement après le boss 1", function()
	local p = newProfile()
	eq(CombatRules.isAccessible(p, 1, ctx), true, "niveau 1")
	eq(CombatRules.isAccessible(p, 2, ctx), false, "niveau 2 fermé")
	p.run.clearedLevels["1"] = true
	eq(CombatRules.isAccessible(p, 2, ctx), true, "niveau 2 ouvert")
	eq(CombatRules.isAccessible(p, 0, ctx), false, "niveau 0")
	eq(CombatRules.isAccessible(p, 1.5, ctx), false, "niveau 1,5")
end)

test("jamais plus de 2 sbires en même temps, puis le boss", function()
	local enc = newEncounter()
	local events = run(enc, 0, 5, INSIDE)
	eq(countType(events, "spawn"), 2, "apparitions")
	eq(#enc.alive, 2, "sbires vivants")
	Encounter.attack(enc, nil, INSIDE, 1e9, 1000)
	events = run(enc, 5.1, 7, INSIDE)
	eq(countType(events, "spawn"), 1, "3e sbire")
	clearMinions(enc, 7.1)
	eq(enc.phase, "boss", "phase")
	eq(enc.minionsKilled, 3, "sbires tués")
	eq(enc.enemies[enc.alive[1]].kind, "boss", "boss présent")
end)

test("attaque : cible la plus proche à portée, refusée hors de portée", function()
	local enc = newEncounter()
	run(enc, 0, 0.5, INSIDE)
	local result, reason = Encounter.attack(enc, nil, { x = 0, z = 500 }, 10, 28)
	eq(result, nil, "hors de portée")
	eq(reason, "noTarget")
	result = Encounter.attack(enc, nil, INSIDE, 10, 28)
	assert(result ~= nil, "attaque à portée refusée")
	eq(result.damage, 10, "dégâts")
	eq(result.hp, 40, "PV restants")
end)

test("deux requêtes de victoire : une seule récompense", function()
	local enc = newEncounter()
	clearMinions(enc, 0)
	local first = Encounter.attack(enc, nil, INSIDE, 1e9, 1000)
	assert(first ~= nil and first.killed and first.kind == "boss", "boss non tué")
	eq(enc.phase, "finalizing", "phase")
	local second, reason = Encounter.attack(enc, nil, INSIDE, 1e9, 1000)
	eq(second, nil, "seconde victoire")
	eq(reason, "phase")
end)

test("esquive : touché si on reste dans la zone, épargné si on en sort", function()
	local enc = newEncounter()
	local t, telegraph = 0, nil
	while telegraph == nil and t < 20 do
		for _, e in Encounter.step(enc, t, INSIDE, ctx) do
			if e.type == "telegraph" then
				telegraph = e
			end
		end
		t += 0.1
	end
	assert(telegraph ~= nil, "aucune télégraphie")
	local impacts = {}
	for _, e in run(enc, t, t + 1.5, INSIDE) do
		if e.type == "impact" and e.enemyId == telegraph.enemyId then
			table.insert(impacts, e)
		end
	end
	eq(impacts[1].hit, true, "resté dans la zone")
	eq(impacts[1].damage, 15, "dégâts sbire niveau 1")

	local enc2 = newEncounter()
	t, telegraph = 0, nil
	while telegraph == nil and t < 20 do
		for _, e in Encounter.step(enc2, t, INSIDE, ctx) do
			if e.type == "telegraph" then
				telegraph = e
			end
		end
		t += 0.1
	end
	assert(telegraph ~= nil)
	local away = { x = INSIDE.x + 12, z = INSIDE.z }
	for _, e in run(enc2, t, t + 1.05, away) do
		if e.type == "impact" and e.enemyId == telegraph.enemyId then
			eq(e.hit, false, "sorti de la zone")
		end
	end
end)

test("dernier coup contre mort : aucun impact après la victoire", function()
	local enc = newEncounter()
	local t = clearMinions(enc, 0)
	local bossTelegraph = false
	while not bossTelegraph and t < 60 do
		for _, e in Encounter.step(enc, t, INSIDE, ctx) do
			if e.type == "telegraph" then
				bossTelegraph = true
			end
		end
		t += 0.1
	end
	assert(bossTelegraph, "le boss n'a pas télégraphié")
	Encounter.attack(enc, nil, INSIDE, 1e9, 1000)
	eq(countType(run(enc, t, t + 3, INSIDE), "impact"), 0, "impacts après victoire")
end)

test("sbire vaincu : +2 puissance et +1 XP au niveau 1", function()
	local p = newProfile()
	local reward = CombatRules.applyMinionKill(p, 1, ctx)
	eq(reward.power, 2)
	near(p.power, 3)
	eq(p.masteryXP.maya, 1)
end)

test("boss vaincu sans drop : la porte s'ouvre quand même", function()
	local p = newProfile()
	local v = CombatRules.applyBossVictory(p, 1, 0.5, ctx)
	eq(v.drop, nil, "drop")
	eq(CombatRules.isCleared(p, 1), true, "porte 1")
	eq(v.power, 10, "récompense boss")
	eq(p.masteryXP.maya, 5, "XP boss")
	eq(p.encounteredBosses.jade, true, "Jade rencontrée")
	eq(p.discoveredBaddies.jade, nil, "rencontrée n'est pas découverte")
end)

test("drop à 10 % : Jade part dans les drops en attente", function()
	local p = newProfile()
	local v = CombatRules.applyBossVictory(p, 1, 0.05, ctx)
	eq(v.drop, "jade")
	eq(p.pendingDrops.jade, 1, "drops en attente")
	eq(p.pendingRevision, 1, "révision")
	eq(p.discoveredBaddies.jade, nil, "pas découverte avant acceptation")
	eq(CombatRules.applyBossVictory(p, 1, 0.10, ctx).drop, nil, "0,10 n'est pas < 10 %")
end)

test("ticket de premier passage : une seule fois par parcours", function()
	local p = newProfile()
	eq(CombatRules.applyBossVictory(p, 1, 0.5, ctx).baddieTickets, 1, "premier passage")
	eq(CombatRules.applyBossVictory(p, 1, 0.5, ctx).baddieTickets, 0, "rejouer")
	eq(p.tickets.baddie, 11)
end)

test("20 échecs boss : toujours 10 %, aucune garantie", function()
	local p = newProfile()
	for _ = 1, 20 do
		eq(CombatRules.applyBossVictory(p, 1, 0.5, ctx).drop, nil)
	end
	eq(CombatRules.applyBossVictory(p, 1, 0.11, ctx).drop, nil, "21e victoire à 0,11")
	eq(CombatRules.applyBossVictory(p, 1, 0.09, ctx).drop, "jade", "0,09")
end)

test("mort au niveau 8 : puissance gardée, toutes les portes fermées", function()
	local p = newProfile()
	for level = 1, 7 do
		CombatRules.applyBossVictory(p, level, 0.5, ctx)
	end
	p.pendingDrops.jade = 1
	local power = p.power
	CombatRules.applyDeath(p, ctx)
	eq(#CombatRules.clearedList(p), 0, "portes")
	eq(p.run.attempt, 2, "tentative")
	near(p.power, power, "puissance")
	eq(p.pendingDrops.jade, 1, "drop en attente")
	eq(p.run.firstClearRewards["1"], true, "premier passage conservé")
	eq(CombatRules.isAccessible(p, 2, ctx), false, "niveau 2 refermé")
end)

test("maîtrise : le 10e XP fait passer Maya au niveau 1", function()
	local p = newProfile()
	p.masteryXP.maya = 9
	local reward = CombatRules.applyMinionKill(p, 1, ctx)
	eq(reward.masteryBaddie, "maya")
	eq(reward.masteryUp, 1)
end)

test("dégâts d'attaque : puissance × multiplicateur × maîtrise", function()
	local p = newProfile()
	p.power = 10
	near(CombatRules.attackDamage(p, ctx), 10, "Maya, maîtrise 0")
	p.masteryXP.maya = 1000
	near(CombatRules.attackDamage(p, ctx), 15, "Maya, maîtrise 10")
end)

print("Slots et relances (§11, §13)")

local function finishRun(p)
	p.run.clearedLevels[tostring(#Balance.levels)] = true
end

-- valeur de tirage qui tombe sur une identité précise de la table standard
local function rollFor(id: string): number
	local acc = 0
	for _, other in Catalog.baddieOrder do
		if other == id then
			return (acc + Catalog.baddies[id].rollChance / 2) / 100
		end
		acc += Catalog.baddies[other].rollChance
	end
	error(`inconnue : {id}`)
end

test("profil neuf : s1 temporaire avec Maya, principale, sans reçu", function()
	local p = newProfile()
	local view = Slots.view(p)
	eq(#view, 1, "slots")
	eq(view[1].id, "s1")
	eq(view[1].temporary, true, "temporaire")
	eq(view[1].baddieId, "maya")
	eq(view[1].active, true, "principale")
	eq(Slots.temporaryId(p), "s1")
	eq(Receipts.find(p, "x"), nil, "aucun reçu")
end)

test("table standard : bornes des chances (Maya 32 %, Lina 25 %… Vega 0,5 %)", function()
	eq(Slots.pickStandard(0, ctx), "maya")
	eq(Slots.pickStandard(0.3199, ctx), "maya")
	eq(Slots.pickStandard(0.32, ctx), "lina")
	eq(Slots.pickStandard(0.58, ctx), "jade")
	eq(Slots.pickStandard(0.994, ctx), "zuri")
	eq(Slots.pickStandard(0.995, ctx), "vega")
	eq(Slots.pickStandard(0.99999999, ctx), "vega")
end)

test("relance : coûte un ticket, remplace le contenu, révision +1, découverte", function()
	local p = newProfile()
	eq(Slots.checkRoll(p, "s1", 0), nil)
	local r = Slots.applyRoll(p, "s1", rollFor("jade"), ctx)
	eq(r.baddieId, "jade")
	eq(r.previousId, "maya")
	eq(r.isNew, true, "nouvelle")
	eq(r.guaranteed, false)
	eq(r.slotRevision, 1)
	eq(p.slots.s1.baddieId, "jade", "slot")
	eq(p.tickets.baddie, Balance.tickets.startBaddie - 1, "tickets")
	eq(p.rolls.baddie, 1, "compteur")
	eq(p.discoveredBaddies.maya, true, "Maya reste dans le Book")
	eq(p.masteryXP.jade, 0, "maîtrise initialisée")
	eq(Slots.applyRoll(p, "s1", rollFor("jade"), ctx).isNew, false, "doublon")
end)

test("relance refusée : révision périmée, verrou, sans ticket, slot inconnu", function()
	local p = newProfile()
	eq(Slots.checkRoll(p, "s1", 3), "stale")
	eq(Slots.checkRoll(p, "s9", 0), "unknown_slot")
	eq(Slots.checkRoll(p, "s1", "0"), "invalid")
	eq(Slots.setRollLock(p, "s1", true), nil)
	eq(Slots.checkRoll(p, "s1", 0), "locked")
	eq(Slots.setRollLock(p, "s1", false), nil)
	p.tickets.baddie = 0
	eq(Slots.checkRoll(p, "s1", 0), "no_ticket")
end)

test("garantie : la 50e relance donne une identité manquante (uniforme)", function()
	local p = newProfile()
	eq(Slots.untilGuarantee(p, ctx), 50)
	p.rolls.baddie = 49
	eq(Slots.untilGuarantee(p, ctx), 1, "la prochaine")
	-- 0,0 donnerait Maya dans la table standard ; ici la première manquante (Lina)
	local r = Slots.applyRoll(p, "s1", 0, ctx)
	eq(r.guaranteed, true, "garantie")
	eq(r.baddieId, "lina")
	eq(r.rollNumber, 50)
	eq(Slots.untilGuarantee(p, ctx), 50, "compteur relancé")
	p.rolls.baddie = 99
	eq(Slots.applyRoll(p, "s1", 0.999, ctx).baddieId, "vega", "dernière manquante")
end)

test("garantie : le lot V1 complet en 350 relances au plus, même avec un tirage malchanceux", function()
	local p = newProfile()
	p.tickets.baddie = 1000
	local rolls = 0
	while not Slots.isBookComplete(p, ctx) do
		Slots.applyRoll(p, "s1", 0, ctx) -- 0 : toujours Maya hors garantie
		rolls += 1
		assert(rolls <= 400, "boucle")
	end
	eq(rolls, 350, "relances")
	-- Book complet : la table standard reprend, même à la 400e
	p.rolls.baddie = 399
	local r = Slots.applyRoll(p, "s1", 0, ctx)
	eq(r.guaranteed, false)
	eq(r.baddieId, "maya")
end)

test("garantie : un drop accepté retire l'identité des manquantes, sans toucher au compteur", function()
	local p = newProfile()
	p.pendingDrops.jade = 1
	Slots.applyAcceptDrop(p, "jade", ctx)
	eq(table.find(Slots.missingBaddies(p, ctx), "jade"), nil, "Jade découverte")
	eq(p.rolls.baddie, 0, "compteur de relances inchangé")
end)

print("Drops en attente (§14)")

test("accepter : une unité d'une pile, dans le temporaire seulement", function()
	local p = newProfile()
	p.pendingDrops.nova = 2
	p.pendingRevision = 2
	eq(Slots.checkAcceptDrop(p, "nova", 0, 2, ctx), nil)
	local r = Slots.applyAcceptDrop(p, "nova", ctx)
	eq(r.slotId, "s1", "temporaire")
	eq(r.previousId, "maya")
	eq(r.remaining, 1, "reste")
	eq(r.isNew, true)
	eq(r.isActive, true, "la principale change avec le temporaire")
	eq(p.pendingDrops.nova, 1)
	eq(p.pendingRevision, 3)
	eq(p.discoveredBaddies.nova, true)
	Slots.applyAcceptDrop(p, "nova", ctx)
	eq(p.pendingDrops.nova, nil, "pile vide supprimée")
end)

test("accepter refusé : sans drop, révisions périmées", function()
	local p = newProfile()
	eq(Slots.checkAcceptDrop(p, "nova", 0, 0, ctx), "no_drop")
	p.pendingDrops.nova = 1
	p.pendingRevision = 1
	eq(Slots.checkAcceptDrop(p, "nova", 0, 0, ctx), "stale", "pendingRevision")
	eq(Slots.checkAcceptDrop(p, "nova", 5, 1, ctx), "stale", "slotRevision")
	eq(Slots.checkAcceptDrop(p, "bob", 0, 1, ctx), "invalid")
end)

test("refuser : retire une unité, rien d'autre", function()
	local p = newProfile()
	p.pendingDrops.vega = 2
	eq(Slots.checkRefuseDrop(p, "vega", 0), nil)
	local r = Slots.applyRefuseDrop(p, "vega")
	eq(r.remaining, 1)
	eq(p.discoveredBaddies.vega, nil, "pas de découverte")
	eq(p.slots.s1.baddieId, "maya", "slot inchangé")
	eq(p.rolls.baddie, 0, "compteur inchangé")
	eq(Slots.checkRefuseDrop(p, "vega", 0), "stale")
end)

test("principale : seulement un slot rempli ; aucun transfert de slot", function()
	local p = newProfile()
	finishRun(p)
	Slots.applyRebirth(p, ctx) -- s1 conservé (Maya), s2 temporaire vide
	eq(Slots.setActive(p, "s2", ctx), "empty_slot")
	eq(Slots.setActive(p, "s9", ctx), "unknown_slot")
	p.pendingDrops.vega = 1
	local r = Slots.applyAcceptDrop(p, "vega", ctx)
	eq(r.slotId, "s2", "le drop va dans le temporaire")
	eq(r.isActive, false)
	eq(p.slots.s1.baddieId, "maya", "le conservé n'est pas touché")
	eq(Slots.setActive(p, "s2", ctx), nil)
	eq(p.activeSlotId, "s2")
	eq(p.slots.s1.baddieId, "maya", "s1 garde Maya")
	near(CombatRules.attackDamage(p, ctx), 4, "dégâts de Vega ×4")
end)

print("Renaissance (§10, §11)")

test("renaissance refusée : parcours non fini ou run.id périmé", function()
	local p = newProfile()
	eq(Slots.checkRebirth(p, 1, ctx), "not_finished")
	finishRun(p)
	eq(Slots.checkRebirth(p, 2, ctx), "stale")
	eq(Slots.checkRebirth(p, "1", ctx), "invalid")
	eq(Slots.checkRebirth(p, 1, ctx), nil)
end)

test(
	"renaissance 1 : s1 conservé avec son contenu, s2 temporaire, récompenses, nouveau parcours",
	function()
		local p = newProfile()
		for level = 1, 10 do
			CombatRules.applyBossVictory(p, level, 0.5, ctx)
		end
		p.pendingDrops.jade = 1
		p.masteryXP.maya = 40
		local tickets, crewTickets = p.tickets.baddie, p.tickets.crew
		local r = Slots.applyRebirth(p, ctx)
		eq(r.count, 1)
		eq(r.promotedSlotId, "s1")
		eq(r.newSlotId, "s2")
		eq(r.clearedSlotId, nil, "rien de vidé")
		eq(r.fallback, nil)
		eq(p.slots.s1.conserved, true)
		eq(p.slots.s1.baddieId, "maya", "contenu gardé")
		eq(p.slots.s2.conserved, false)
		eq(p.slots.s2.baddieId, "", "nouveau temporaire vide")
		eq(p.slots.s2.order, 2)
		eq(p.activeSlotId, "s1")
		eq(p.rebirths, 1)
		eq(p.tickets.baddie, tickets + 5, "tickets baddie")
		eq(p.tickets.crew, crewTickets + 1, "ticket compagnon")
		near(p.power, 1, "puissance remise à 1")
		eq(p.run.id, 2, "nouveau parcours")
		eq(#CombatRules.clearedList(p), 0, "portes")
		eq(p.run.firstClearRewards["1"], nil, "premiers passages remis à zéro")
		eq(p.pendingDrops.jade, 1, "drops en attente conservés")
		eq(p.masteryXP.maya, 40, "maîtrise conservée")
		near(Formulas.trainingBonus(p.rebirths, Balance.training), 1.1, "bonus +10 %")
	end
)

test("renaissance 2 : le temporaire est vidé ; la principale perdue retombe sur un conservé", function()
	local p = newProfile()
	finishRun(p)
	Slots.applyRebirth(p, ctx)
	p.pendingDrops.vega = 1
	Slots.applyAcceptDrop(p, "vega", ctx)
	Slots.setActive(p, "s2", ctx)
	Slots.setRollLock(p, "s2", true) -- le verrou ne protège pas du reset
	finishRun(p)
	local r = Slots.applyRebirth(p, ctx)
	eq(r.count, 2)
	eq(r.promotedSlotId, nil, "pas de palier")
	eq(r.newSlotId, nil, "pas de nouveau slot")
	eq(r.clearedSlotId, "s2")
	eq(r.lostBaddieId, "vega")
	eq(r.fallback, "conserved")
	eq(p.slots.s2.baddieId, "", "s2 vidé")
	eq(p.slots.s2.rollLocked, false, "verrou retiré")
	eq(p.activeSlotId, "s1", "principale valide")
	eq(p.discoveredBaddies.vega, true, "Vega reste dans le Book")
end)

test("renaissance 3 avec Vega dans s2 : s2 devient conservé avec Vega, s3 s'ouvre", function()
	local p = newProfile()
	for _ = 1, 2 do
		finishRun(p)
		Slots.applyRebirth(p, ctx)
	end
	p.pendingDrops.vega = 1
	Slots.applyAcceptDrop(p, "vega", ctx)
	finishRun(p)
	local r = Slots.applyRebirth(p, ctx)
	eq(r.count, 3)
	eq(r.promotedSlotId, "s2")
	eq(r.newSlotId, "s3")
	eq(p.slots.s2.conserved, true)
	eq(p.slots.s2.baddieId, "vega", "Vega gardée dans s2")
	eq(p.slots.s3.conserved, false)
	eq(Slots.temporaryId(p), "s3")
end)

test("renaissances 6 et 7 : s4 s'ouvre au palier 6, puis le temporaire est seulement vidé", function()
	local p = newProfile()
	for _ = 1, 6 do
		finishRun(p)
		Slots.applyRebirth(p, ctx)
	end
	eq(#Slots.view(p), 4, "quatre slots")
	eq(Slots.temporaryId(p), "s4")
	eq(p.slots.s3.conserved, true)
	p.slots.s4.baddieId = "lina"
	finishRun(p)
	local r = Slots.applyRebirth(p, ctx)
	eq(r.newSlotId, nil)
	eq(#Slots.view(p), 4, "toujours quatre")
	eq(p.slots.s4.baddieId, "", "temporaire vidé")
end)

test("secours : aucun conservé rempli → Maya installée dans le temporaire", function()
	local p = newProfile()
	finishRun(p)
	Slots.applyRebirth(p, ctx)
	p.slots.s1.baddieId = "" -- profil abîmé : conservé vide
	p.slots.s2.baddieId = "lina"
	p.activeSlotId = "s2"
	finishRun(p)
	local r = Slots.applyRebirth(p, ctx)
	eq(r.fallback, "maya")
	eq(r.lostBaddieId, "lina")
	eq(p.activeSlotId, "s2")
	eq(p.slots.s2.baddieId, "maya")
	assert(CombatRules.attackDamage(p, ctx) > 0, "progression possible")
end)

print("Baddies Book, exposition et looks (§03, §15)")

local studioCtx =
	{ Balance = Balance, Catalog = TestCatalog.merge(Catalog), Formulas = Formulas, Wardrobe = Wardrobe }

test("looks débloqués par la maîtrise : XP 0 → {1}, 10 → {1, 2}, 250 → {1, 2, 3}", function()
	local p = newProfile()
	eq(table.concat(Collection.unlockedLooks(p, "maya", ctx), ","), "1")
	p.masteryXP.maya = 10
	eq(table.concat(Collection.unlockedLooks(p, "maya", ctx), ","), "1,2")
	p.masteryXP.maya = 249
	eq(table.concat(Collection.unlockedLooks(p, "maya", ctx), ","), "1,2")
	p.masteryXP.maya = 250
	eq(table.concat(Collection.unlockedLooks(p, "maya", ctx), ","), "1,2,3")
	eq(#Collection.unlockedLooks(p, "jade", ctx), 0, "non découverte")
end)

test("look : verrouillé refusé, choix gardé, repli sur le plus haut débloqué", function()
	local p = newProfile()
	eq(Collection.setLook(p, "maya", 2, ctx), "locked")
	eq(Collection.setLook(p, "jade", 1, ctx), "undiscovered")
	eq(Collection.setLook(p, "bob", 1, ctx), "unknown")
	eq(Collection.setLook(p, "maya", 1.5, ctx), "invalid")
	eq(Collection.selectedLook(p, "maya", ctx), 1, "défaut")
	p.masteryXP.maya = 250
	eq(Collection.setLook(p, "maya", 3, ctx), nil)
	eq(Collection.selectedLook(p, "maya", ctx), 3)
	p.masteryXP.maya = 10 -- garde-fou : maîtrise plus basse que le choix
	eq(Collection.selectedLook(p, "maya", ctx), 2, "repli")
end)

test("exposition : 3 places, sans doublon, découvertes seulement", function()
	local p = newProfile()
	p.discoveredBaddies.jade = true
	p.discoveredBaddies.nova = true
	p.discoveredBaddies.vega = true
	eq(Collection.setDisplay(p, { "maya", "jade", "nova", "vega" }, ctx), "too_many")
	eq(Collection.setDisplay(p, { "jade", "jade" }, ctx), "duplicate")
	eq(Collection.setDisplay(p, { "zuri" }, ctx), "undiscovered")
	eq(Collection.setDisplay(p, { "bob" }, ctx), "unknown")
	eq(Collection.setDisplay(p, { 1 }, ctx), "invalid")
	eq(Collection.setDisplay(p, { a = "jade" }, ctx), "invalid")
	eq(Collection.setDisplay(p, "jade", ctx), "invalid")
	eq(Collection.setDisplay(p, { "vega", "jade" }, ctx), nil)
	eq(table.concat(Collection.view(p, ctx).display, ","), "vega,jade")
	eq(Collection.setDisplay(p, {}, ctx), nil, "tout retirer")
	eq(#p.displayBaddies, 0)
end)

test("exposer Vega ×4 ne change ni la principale ni les dégâts", function()
	local p = newProfile()
	p.power = 10
	p.discoveredBaddies.vega = true
	local before = CombatRules.attackDamage(p, ctx)
	Collection.setDisplay(p, { "vega" }, ctx)
	near(CombatRules.attackDamage(p, ctx), before, "dégâts")
	eq(p.slots[p.activeSlotId].baddieId, "maya", "principale")
end)

test("identités de test : Studio seulement, après les publiques, hors Baddies Book", function()
	eq(Catalog.baddies.test_b99, nil, "absente du catalogue public")
	eq(studioCtx.Catalog.baddies.test_b99.test, true, "présente en Studio")
	eq(table.find(studioCtx.Catalog.baddieOrder, "test_b99"), nil, "jamais tirée en relance")
	local p = newProfile()
	p.discoveredBaddies.test_b99 = true
	p.discoveredBaddies.jade = true
	local view = Collection.view(p, studioCtx)
	eq(table.concat(view.discovered, ","), "maya,jade,test_b99", "ordre")
	eq(view.bookCount, 2, "Book public seulement")
	eq(view.bookTotal, 8)
	eq(table.concat(view.looks.test_b99.unlocked, ","), "1", "un seul look")
	eq(Collection.setDisplay(p, { "test_b99" }, studioCtx), nil, "exposable en Studio")
	eq(table.concat(Collection.view(p, ctx).display, ","), "", "filtrée hors Studio")
	eq(table.find(Slots.missingBaddies(p, studioCtx), "test_b99"), nil, "jamais « manquante »")
end)

print("Reçus des décisions durables (§26)")

test("requestId : chaîne de 1 à 64 caractères", function()
	eq(Receipts.isValidRequestId("abc"), true)
	eq(Receipts.isValidRequestId(""), false)
	eq(Receipts.isValidRequestId(string.rep("x", 65)), false)
	eq(Receipts.isValidRequestId(12), false)
end)

test("reçu : le même requestId retrouve le même résultat, sans nouvel effet", function()
	local p = newProfile()
	local result = Slots.applyRoll(p, "s1", rollFor("iris"), ctx)
	local receipt = Receipts.record(p, "req-1", "Roll", result)
	eq(receipt.revision, 1, "révision globale")
	local tickets = p.tickets.baddie
	local found = Receipts.find(p, "req-1")
	assert(found ~= nil, "reçu introuvable")
	eq(found.result.baddieId, "iris", "même résultat")
	eq(p.tickets.baddie, tickets, "aucun ticket de plus")
	eq(Receipts.find(p, "req-2"), nil)
	eq(Receipts.isSaved({ lastMutation = { requestId = "req-1" } }, "req-1"), true)
	eq(Receipts.isSaved({ lastMutation = {} }, "req-1"), false)
end)

print("Coffres et niveaux des compagnons (§16)")

local function withMalik()
	local p = newProfile()
	Crew.grant(p, "malik", ctx)
	return p
end

test("table des coffres : Enzo 30 %, Malik 25 %… Amine 5 %", function()
	eq(Crew.pickChest(0, ctx), "enzo")
	eq(Crew.pickChest(0.31, ctx), "malik")
	eq(Crew.pickChest(0.56, ctx), "rafael")
	eq(Crew.pickChest(0.76, ctx), "dario")
	eq(Crew.pickChest(0.88, ctx), "kenji")
	eq(Crew.pickChest(0.96, ctx), "amine")
	eq(Crew.pickChest(0.99999999, ctx), "amine")
end)

test("coffre : 1 ticket compagnon, compteur +1, nouveau compagnon équipé s'il reste une place", function()
	local p = withMalik()
	eq(Crew.checkOpenChest(p), "no_ticket")
	p.tickets.crew = 2
	eq(Crew.checkOpenChest(p), nil)
	local r = Crew.applyOpenChest(p, 0.6, ctx) -- Rafael
	eq(r.crewId, "rafael")
	eq(r.isNew, true)
	eq(r.equipped, true, "deuxième place libre")
	eq(r.level, 1)
	eq(r.openNumber, 1)
	eq(p.tickets.crew, 1, "ticket dépensé")
	eq(p.rolls.baddie, 0, "compteur des baddies séparé")
	local again = Crew.applyOpenChest(p, 0.6, ctx)
	eq(again.isNew, false, "doublon")
	eq(again.copies, 1, "une copie")
end)

test("coffre : la 20e ouverture donne un compagnon manquant (uniforme)", function()
	local p = withMalik()
	p.tickets.crew = 1
	p.rolls.crew = 19
	eq(Crew.untilChestGuarantee(p, ctx), 1, "la prochaine")
	-- 0,3 donnerait Malik dans la table normale ; parmi les 5 manquants, le 2e : Rafael
	local r = Crew.applyOpenChest(p, 0.3, ctx)
	eq(r.guaranteed, true)
	eq(r.crewId, "rafael")
	eq(Crew.untilChestGuarantee(p, ctx), 20)
end)

test("coffre : les 6 compagnons en 100 ouvertures au plus, puis la table normale", function()
	local p = withMalik()
	p.tickets.crew = 1000
	local opens = 0
	while #Crew.missing(p, ctx) > 0 do
		Crew.applyOpenChest(p, 0.3, ctx) -- 0,3 : toujours Malik hors garantie
		opens += 1
		assert(opens <= 120, "boucle")
	end
	eq(opens, 100, "ouvertures")
	p.rolls.crew = 119
	local r = Crew.applyOpenChest(p, 0.3, ctx)
	eq(r.guaranteed, false, "collection complète")
	eq(r.crewId, "malik")
end)

test("niveau : L → L+1 coûte L+1 copies, maximum 10, copies gardées au maximum", function()
	local p = withMalik()
	eq(Crew.upgradeCost(1, ctx), 2)
	eq(Crew.upgradeCost(9, ctx), 10)
	eq(Crew.upgradeCost(10, ctx), nil)
	eq(Crew.upgrade(p, "malik", ctx), "not_enough_copies")
	eq(Crew.upgrade(p, "enzo", ctx), "not_owned")
	eq(Crew.upgrade(p, "bob", ctx), "unknown")
	p.crew.malik.copies = 2
	local reason, level = Crew.upgrade(p, "malik", ctx)
	eq(reason, nil)
	eq(level, 2)
	eq(p.crew.malik.copies, 0, "copies dépensées")
	near(Crew.passivePerSecond(p, ctx), 0.66, "0,6 × 1,1")
	-- niveau 2 → 10 : 3 + 4 + … + 10 = 52 copies (54 depuis le niveau 1)
	p.crew.malik.copies = 60
	for _ = 3, 10 do
		eq(Crew.upgrade(p, "malik", ctx), nil)
	end
	eq(p.crew.malik.level, 10)
	eq(p.crew.malik.copies, 8, "copies restantes gardées")
	eq(Crew.upgrade(p, "malik", ctx), "max_level")
end)

test("équipe : 2 compagnons possédés maximum, sans doublon", function()
	local p = withMalik()
	Crew.grant(p, "enzo", ctx)
	Crew.grant(p, "amine", ctx) -- possédé mais pas équipé (2 places prises)
	eq(table.concat(p.equippedCrew, ","), "malik,enzo")
	eq(Crew.setEquipped(p, { "malik", "enzo", "amine" }, ctx), "too_many")
	eq(Crew.setEquipped(p, { "amine", "amine" }, ctx), "duplicate")
	eq(Crew.setEquipped(p, { "kenji" }, ctx), "not_owned")
	eq(Crew.setEquipped(p, { "bob" }, ctx), "invalid")
	eq(Crew.setEquipped(p, { x = "amine" }, ctx), "invalid")
	eq(Crew.setEquipped(p, { "amine", "malik" }, ctx), nil)
	near(Crew.passivePerSecond(p, ctx), 2.6, "2,0 + 0,6")
	eq(Crew.setEquipped(p, {}, ctx), nil, "aucun")
	near(Crew.passivePerSecond(p, ctx), 0, "plus de production")
end)

test("vue de la collection : ordre du catalogue, coût, amélioration possible, équipé", function()
	local p = withMalik()
	Crew.grant(p, "amine", ctx)
	p.crew.malik.copies = 2
	p.rebirths = 1
	local view = Crew.ownedView(p, ctx)
	eq(#view, 2)
	eq(view[1].id, "malik", "ordre du catalogue")
	eq(view[1].upgradeCost, 2)
	eq(view[1].canUpgrade, true)
	eq(view[1].equipped, true)
	near(view[1].perSecond, 0.66, "bonus de rebirth inclus")
	eq(view[2].id, "amine")
	eq(view[2].canUpgrade, false)
end)

print("Garde-fous du profil (§24, §36)")

-- Même comportement que Profile:Reconcile() de ProfileStore : complète les clés absentes, récursivement
local function reconcile(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = if type(value) == "table" then table.clone(value) else value
		elseif type(target[key]) == "table" and type(value) == "table" then
			reconcile(target[key], value)
		end
	end
	return target
end

local function load(raw)
	local data = reconcile(raw, newProfile())
	local ok, err = ProfileGuard.migrate(data, ctx)
	assert(ok, err)
	return data, ProfileGuard.repair(data, ctx)
end

test("fixture P0/P1 (schéma 4) : ouverte sans correction ni perte", function()
	local data, issues = load(profileV4P0())
	eq(#issues, 0, `corrections : {table.concat(issues, " ; ")}`)
	near(data.power, 76.9, "puissance")
	eq(data.slots.s1.baddieId, "jade", "principale")
	eq(data.pendingDrops.jade, 1, "drop en attente")
	eq(data.crew.malik.level, 1)
	eq(type(data.lastMutation), "table", "reçu ajouté par Reconcile")
	eq(type(data.selectedLooks), "table", "looks ajoutés par Reconcile")
	eq(#ProfileGuard.repair(data, ctx), 0, "idempotent")
end)

test("migrations : schéma plus récent ou migration manquante → chargement refusé", function()
	local data = newProfile()
	data.schemaVersion = 5
	eq((ProfileGuard.migrate(data, ctx)), false, "plus récent")
	data.schemaVersion = 3
	eq((ProfileGuard.migrate(data, ctx)), false, "3 → 4 inconnue")
	data.schemaVersion = "4"
	eq((ProfileGuard.migrate(data, ctx)), false, "type")
	-- une migration déclarée est appliquée puis la version avance
	ProfileGuard.migrations[3] = function(d)
		d.migratedFrom3 = true
	end
	data.schemaVersion = 3
	local ok = ProfileGuard.migrate(data, ctx)
	ProfileGuard.migrations[3] = nil
	eq(ok, true)
	eq(data.schemaVersion, 4)
	eq(data.migratedFrom3, true)
end)

test("nombres impossibles : NaN, infini, négatifs et décimales corrigés", function()
	local raw = profileV4P0()
	raw.power = 0 / 0
	raw.tickets.baddie = math.huge
	raw.tickets.crew = -4
	raw.rolls.baddie = 2.7
	raw.masteryXP.jade = -1
	raw.crew.malik = { level = 15, copies = -3 }
	local data, issues = load(raw)
	near(data.power, 1, "puissance de départ")
	eq(data.tickets.baddie, 0)
	eq(data.tickets.crew, 0)
	eq(data.rolls.baddie, 2)
	eq(data.masteryXP.jade, 0)
	eq(data.crew.malik.level, 10)
	eq(data.crew.malik.copies, 0)
	assert(#issues >= 6, `journal : {#issues}`)
end)

test("slots : un seul temporaire, principale remplie, possédée = découverte", function()
	local raw = profileV4P0()
	raw.rebirths = 1
	raw.slots.s1.conserved = false
	raw.slots.s2 = { order = 2, conserved = false, baddieId = "nova", slotRevision = 0, rollLocked = false }
	raw.activeSlotId = "s3" -- n'existe pas
	local data = load(raw)
	eq(data.slots.s1.conserved, true, "le plus ancien devient conservé")
	eq(data.slots.s2.conserved, false, "le plus récent reste temporaire")
	eq(data.discoveredBaddies.nova, true, "Nova possédée → découverte")
	eq(data.activeSlotId, "s2", "principale : plus fort multiplicateur (Nova ×2,5)")
end)

test("slots : aucun temporaire → un temporaire vide s'ouvre", function()
	local raw = profileV4P0()
	raw.slots.s1.conserved = true
	local data, issues = load(raw)
	eq(data.slots.s2.conserved, false)
	eq(data.slots.s2.baddieId, "")
	eq(data.activeSlotId, "s1")
	assert(string.find(table.concat(issues, " "), "capacité"), "capacité signalée")
end)

test("identité inconnue : archivée dans son slot, jamais principale ; Maya de secours", function()
	local raw = profileV4P0()
	raw.rebirths = 1
	raw.slots.s1 =
		{ order = 1, conserved = true, baddieId = "ancienne_b42", slotRevision = 0, rollLocked = false }
	raw.slots.s2 = { order = 2, conserved = false, baddieId = "", slotRevision = 0, rollLocked = false }
	raw.discoveredBaddies.ancienne_b42 = true
	raw.pendingDrops.ancienne_b42 = 2
	local data = load(raw)
	eq(data.discoveredBaddies.ancienne_b42, true, "découverte conservée")
	eq(data.pendingDrops.ancienne_b42, 2, "drop conservé")
	eq(data.slots.s1.baddieId, "ancienne_b42", "conservé non vidé")
	eq(data.slots.s2.baddieId, "maya", "Maya dans le temporaire vide")
	eq(data.activeSlotId, "s2")
	assert(CombatRules.attackDamage(data, ctx) > 0, "progression possible")
	-- seul slot = le temporaire : la procédure de secours y installe Maya (journalisé)
	local single = profileV4P0()
	single.slots.s1.baddieId = "ancienne_b42"
	local data2, issues = load(single)
	eq(data2.slots.s1.baddieId, "maya")
	assert(string.find(table.concat(issues, " "), "installée"), "secours journalisé")
end)

test("listes : exposition, équipe, drops, portes et looks nettoyés", function()
	local raw = profileV4P0()
	raw.displayBaddies = { "jade", "jade", "vega", "bob", "maya", "lina" }
	raw.equippedCrew = { "malik", "malik", "amine", "enzo" }
	raw.pendingDrops = { jade = 2.5, iris = 0, nova = -1, sienna = 0 / 0 }
	raw.run.clearedLevels = { ["1"] = true, ["11"] = true, ["2"] = false, x = true }
	raw.selectedLooks = { maya = 2, jade = 7 }
	local data = load(raw)
	eq(table.concat(data.displayBaddies, ","), "jade,maya", "découvertes, sans doublon")
	eq(table.concat(data.equippedCrew, ","), "malik", "possédés, sans doublon")
	eq(data.pendingDrops.jade, 2)
	eq(data.pendingDrops.iris, nil)
	eq(data.pendingDrops.nova, nil)
	eq(data.pendingDrops.sienna, nil)
	eq(table.concat(CombatRules.clearedList(data), ","), "1")
	eq(data.selectedLooks.maya, 2)
	eq(data.selectedLooks.jade, nil)
end)

print("Décisions durables : renvois et pannes (§26, §27, §30)")

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Faux DataStore : `saved` est la dernière copie écrite ; crash() recharge le serveur depuis elle
local function harness()
	local h: any = { replies = {}, saveOk = true, disabled = {}, confirmed = 0 }
	h.data = newProfile()
	h.saved = deepCopy(h.data)
	h.session = { mutating = false }
	h.env = {
		getData = function()
			return h.data
		end,
		save = function(id)
			if not h.saveOk then
				return false
			end
			h.saved = deepCopy(h.data)
			return Receipts.isSaved(h.saved, id)
		end,
		reply = function(event)
			table.insert(h.replies, event)
		end,
		isDisabled = function(action)
			return h.disabled[action] == true
		end,
		clock = function()
			return 0
		end,
	}
	function h.crash()
		h.data = deepCopy(h.saved)
		h.session = { mutating = false }
	end
	function h.last()
		return h.replies[#h.replies]
	end
	function h.onConfirmed()
		h.confirmed += 1
	end
	return h
end

-- Mêmes étapes que SlotService.onRoll / onAcceptDrop (le client n'envoie jamais de résultat)
local function sendRoll(h, requestId: string, slotRevision: number, rollValue: number)
	Receipts.run(h.env, h.session, "Roll", requestId, function(data)
		local reason = Slots.checkRoll(data, "s1", slotRevision)
		if reason ~= nil then
			return reason
		end
		return nil, Slots.applyRoll(data, "s1", rollValue, ctx)
	end, h.onConfirmed)
end

local function sendAccept(h, requestId: string, slotRevision: number, pendingRevision: number)
	Receipts.run(h.env, h.session, "AcceptDrop", requestId, function(data)
		local reason = Slots.checkAcceptDrop(data, "vega", slotRevision, pendingRevision, ctx)
		if reason ~= nil then
			return reason
		end
		return nil, Slots.applyAcceptDrop(data, "vega", ctx)
	end, h.onConfirmed)
end

test("même requestId de relance répété : même résultat, un seul ticket", function()
	local h = harness()
	sendRoll(h, "r1", 0, rollFor("nova"))
	local first = h.last()
	eq(first.ok, true)
	eq(first.confirmed, true)
	eq(first.result.baddieId, "nova")
	eq(h.confirmed, 1, "annonce après écriture")
	sendRoll(h, "r1", 0, rollFor("vega")) -- un second tirage ne doit jamais avoir lieu
	local again = h.last()
	eq(again.replay, true)
	eq(again.result.baddieId, "nova", "même résultat")
	eq(h.data.tickets.baddie, Balance.tickets.startBaddie - 1, "un seul ticket")
	eq(h.confirmed, 1, "pas de seconde annonce")
	sendRoll(h, "r2", 0, rollFor("vega"))
	eq(h.last().reason, "stale", "nouvelle demande sur une révision périmée")
end)

test("une décision à la fois ; maintenance ; erreur", function()
	local h = harness()
	h.session.mutating = true
	sendRoll(h, "r1", 0, 0)
	eq(h.last().reason, "busy")
	h.session.mutating = false
	h.disabled.Roll = true
	sendRoll(h, "r1", 0, 0)
	eq(h.last().reason, "maintenance")
	eq(h.data.tickets.baddie, Balance.tickets.startBaddie, "aucun ticket dépensé")
	h.disabled.Roll = nil
	Receipts.run(h.env, h.session, "Roll", "r3", function()
		error("panne simulée")
	end)
	eq(h.last().reason, "error")
	eq(h.session.mutating, false, "file libérée")
	sendRoll(h, "r4", 0, 0)
	eq(h.last().ok, true)
	h.disabled.Roll = true
	sendRoll(h, "r4", 0, 0)
	eq(h.last().replay, true, "un reçu reste servi pendant la maintenance")
end)

test(
	"arrêt serveur pendant une récupération (écriture perdue) : ni double consommation ni double personnage",
	function()
		local h = harness()
		h.data.pendingDrops.vega = 1
		h.data.pendingRevision = 1
		h.saved = deepCopy(h.data)
		h.saveOk = false
		sendAccept(h, "a1", 0, 1)
		eq(h.last().ok, true)
		eq(h.last().confirmed, false, "écriture incertaine")
		eq(h.confirmed, 0, "pas d'annonce sans écriture")
		h.crash() -- le serveur tombe : la mémoire est perdue
		eq(h.data.pendingDrops.vega, 1, "le drop est toujours là")
		eq(h.data.slots.s1.baddieId, "maya", "temporaire inchangé")
		h.saveOk = true
		sendAccept(h, "a1", 0, 1) -- le client renvoie la même décision
		eq(h.last().ok, true)
		eq(h.last().confirmed, true)
		eq(h.data.pendingDrops.vega, nil, "une seule unité consommée")
		eq(h.data.slots.s1.baddieId, "vega", "un seul personnage")
		eq(h.saved.slots.s1.baddieId, "vega", "écrit")
	end
)

test("arrêt serveur après l'écriture (réponse perdue) : le renvoi rend le même reçu", function()
	local h = harness()
	h.data.pendingDrops.vega = 2
	h.data.pendingRevision = 1
	h.saved = deepCopy(h.data)
	sendAccept(h, "a1", 0, 1)
	h.crash() -- la réponse n'est jamais arrivée au client
	sendAccept(h, "a1", 0, 1)
	eq(h.last().replay, true)
	eq(h.data.pendingDrops.vega, 1, "une seule unité consommée sur deux")
	eq(h.data.slots.s1.slotRevision, 1, "un seul remplacement")
end)

test("écriture incertaine : la décision suivante attend sa confirmation", function()
	local h = harness()
	h.saveOk = false
	sendRoll(h, "r1", 0, rollFor("jade"))
	eq(h.last().confirmed, false)
	sendRoll(h, "r2", 1, rollFor("iris"))
	eq(h.last().reason, "saving", "bloquée tant que r1 n'est pas écrite")
	eq(h.data.slots.s1.baddieId, "jade", "r2 sans effet")
	h.saveOk = true
	sendRoll(h, "r2", 1, rollFor("iris"))
	eq(h.confirmed, 2, "r1 confirmée puis r2")
	eq(h.last().ok, true)
	eq(h.last().result.baddieId, "iris")
	eq(h.saved.lastMutation.requestId, "r2")
end)

print("Cas restants du dossier (§30, §37)")

test("§37 : poids positifs et finis, codes uniques, catalogues non vides", function()
	local codes = {}
	for _, id in Catalog.baddieOrder do
		local chance = Catalog.baddies[id].rollChance
		assert(chance > 0 and chance < math.huge, `chance de {id}`)
		assert(codes[Catalog.baddies[id].code] == nil, `code en double : {id}`)
		codes[Catalog.baddies[id].code] = true
	end
	for _, id in Catalog.crewOrder do
		local chance = Catalog.crew[id].chestChance
		assert(chance > 0 and chance < math.huge, `chance de {id}`)
		assert(codes[Catalog.crew[id].code] == nil, `code en double : {id}`)
		codes[Catalog.crew[id].code] = true
	end
	assert(#Catalog.baddieOrder > 0 and #Catalog.crewOrder > 0, "catalogues vides")
end)

test(
	"§37 : Maya puissance 1 maîtrise 0 = 1 dégât ; Vega puissance 1 maîtrise 10 = 6 dégâts",
	function()
		local p = newProfile()
		near(CombatRules.attackDamage(p, ctx), 1, "Maya")
		p.slots.s1.baddieId = "vega"
		p.masteryXP.vega = 1000
		near(CombatRules.attackDamage(p, ctx), 6, "Vega")
		p.rebirths = 20
		near(CombatRules.attackDamage(p, ctx), 6, "le rebirth ne multiplie pas les dégâts")
	end
)

test("drop non accepté : aucun multiplicateur, exposition ni score de Book", function()
	local p = newProfile()
	p.pendingDrops.vega = 1
	near(CombatRules.attackDamage(p, ctx), 1, "dégâts")
	eq(Collection.setDisplay(p, { "vega" }, ctx), "undiscovered", "exposition")
	eq(Collection.view(p, ctx).bookCount, 1, "Book")
end)

test("mort, reconnexion puis rebirth avec un drop : le drop reste en attente", function()
	local p = newProfile()
	p.pendingDrops.vega = 1
	CombatRules.applyDeath(p, ctx)
	local reloaded = newProfile()
	for key, value in p do
		reloaded[key] = value -- reconnexion : même profil sauvegardé
	end
	eq(#ProfileGuard.repair(reloaded, ctx), 0, "profil sain")
	finishRun(reloaded)
	Slots.applyRebirth(reloaded, ctx)
	eq(reloaded.pendingDrops.vega, 1)
end)

test("relance d'un conservé : ancienne baddie remplacée, Book intact", function()
	local p = newProfile()
	p.slots.s1.baddieId = "nova"
	p.discoveredBaddies.nova = true
	finishRun(p)
	Slots.applyRebirth(p, ctx) -- s1 conservé avec Nova
	local r = Slots.applyRoll(p, "s1", rollFor("lina"), ctx)
	eq(r.previousId, "nova")
	eq(p.slots.s1.baddieId, "lina", "conservé ≠ protégé d'une relance")
	eq(p.discoveredBaddies.nova, true, "Nova reste au Book")
end)

test("rebirth 1 avec Nova en s1 : Nova reste en s1 conservé, s2 temporaire ouvert", function()
	local p = newProfile()
	p.slots.s1.baddieId = "nova"
	finishRun(p)
	Slots.applyRebirth(p, ctx)
	eq(p.slots.s1.baddieId, "nova")
	eq(p.slots.s1.conserved, true)
	eq(p.slots.s2.conserved, false)
end)

test("deux slots avec Nova : une seule principale, pas de cumul", function()
	local p = newProfile()
	finishRun(p)
	Slots.applyRebirth(p, ctx)
	p.slots.s1.baddieId = "nova"
	p.slots.s2.baddieId = "nova"
	near(CombatRules.attackDamage(p, ctx), 2.5, "×2,5 une seule fois")
end)

print("Classement du lobby (§15)")

test("rangs partagés : 7, 7, 5 → 1, 1, 3 ; ordre alphabétique à égalité", function()
	local list = Ranking.rank({
		{ userId = 3, name = "zoe", score = 5 },
		{ userId = 2, name = "Bob", score = 7 },
		{ userId = 1, name = "alex", score = 7 },
		{ userId = 4, name = "Mia", score = 0 },
	})
	eq(list[1].name, "alex")
	eq(list[1].rank, 1)
	eq(list[2].name, "Bob")
	eq(list[2].rank, 1, "égalité")
	eq(list[3].rank, 3, "saut après l'égalité")
	eq(list[4].rank, 4)
	eq(#Ranking.rank({}), 0, "serveur vide")
end)

test("score Book : doublons, looks, boss rencontrés, drops et identités de test ne comptent pas", function()
	local p = newProfile()
	p.pendingDrops.vega = 3
	p.encounteredBosses.vega = true
	p.masteryXP.maya = 250 -- looks débloqués
	p.discoveredBaddies.test_b99 = true
	p.discoveredBaddies.ancienne_b42 = true
	finishRun(p)
	Slots.applyRebirth(p, ctx)
	p.slots.s2.baddieId = "maya" -- doublon possédé
	eq((Collection.bookCount(p, studioCtx)), 1, "Maya seule")
	p.discoveredBaddies.jade = true
	eq((Collection.bookCount(p, studioCtx)), 2)
end)

test("signature : change seulement si le classement change", function()
	local a = Ranking.rank({ { userId = 1, name = "a", score = 1 } })
	local b = Ranking.rank({ { userId = 1, name = "a", score = 1 } })
	local c = Ranking.rank({ { userId = 1, name = "a", score = 2 } })
	eq(Ranking.signature(a), Ranking.signature(b))
	assert(Ranking.signature(a) ~= Ranking.signature(c), "score modifié")
end)

print("Garde-robe, titres et succès (§19)")

test("profil neuf : aucun succès ; 20 entraînements → Premier entraînement, Cadre simple", function()
	local p = newProfile()
	eq(#Achievements.check(p, ctx), 0)
	p.stats.trainActions = 20
	local earned = Achievements.check(p, ctx)
	eq(#earned, 1)
	eq(earned[1].id, "first_training")
	eq(earned[1].items[1], "frame_simple")
	eq(p.wardrobe.frame_simple, true)
	eq(p.pendingBadges.first_training, true, "badge Roblox en attente")
	eq(#Achievements.check(p, ctx), 0, "une seule fois")
end)

test("Malik, Maya maîtrise 1, renaissance : succès et titres correspondants", function()
	local p = newProfile()
	Crew.grant(p, "malik", ctx)
	p.masteryXP.maya = 10
	finishRun(p)
	Slots.applyRebirth(p, ctx)
	local ids = {}
	for _, e in Achievements.check(p, ctx) do
		table.insert(ids, e.id)
	end
	eq(table.concat(ids, ","), "first_look,first_boss,first_crew,run_complete,first_rebirth")
	eq(p.wardrobe.headset_player, true)
	eq(p.wardrobe.pose_photo, true)
	eq(p.wardrobe.chain_silver, true)
	eq(p.titles.boss_manager, true)
	eq(p.titles.baddie_pro, true)
end)

test("Mythic : un drop de Vega en attente ne compte pas ; accepté, oui", function()
	local p = newProfile()
	p.pendingDrops.vega = 1
	eq(#Achievements.check(p, ctx), 0)
	Slots.applyAcceptDrop(p, "vega", ctx)
	local earned = Achievements.check(p, ctx)
	eq(earned[1].id, "mythic_found")
	eq(p.wardrobe.aura_spark, true)
end)

test("Collection V1 complète : acquise, et le reste si une V2 ajoute des personnages", function()
	local p = newProfile()
	for _, id in Catalog.baddieOrder do
		p.discoveredBaddies[id] = true
	end
	for _, id in Catalog.crewOrder do
		Crew.grant(p, id, ctx)
	end
	local ids = {}
	for _, e in Achievements.check(p, ctx) do
		table.insert(ids, e.id)
	end
	assert(table.find(ids, "book_baddies_v1") and table.find(ids, "book_crew_v1"), "Books V1")
	assert(table.find(ids, "collection_v1"), "collection V1")
	eq(p.wardrobe.chain_gold, true)
	eq(p.wardrobe.frame_v1, true)
	-- Une V2 ajoute une baddie : le Book public n'est plus complet, mais le succès V1 reste
	local v2Catalog = table.clone(Catalog)
	v2Catalog.baddieOrder = table.clone(Catalog.baddieOrder)
	table.insert(v2Catalog.baddieOrder, "nouvelle_v2")
	local v2 = { Balance = Balance, Catalog = v2Catalog, Formulas = Formulas, Wardrobe = Wardrobe }
	eq(Slots.isBookComplete(p, v2), false, "Book public V2 incomplet")
	eq(p.achievements.collection_v1, true, "succès V1 conservé")
	eq(#Achievements.check(p, v2), 0, "rien à reprendre ni redonner")
end)

test("style : seulement débloqué, au bon emplacement ; retirer ; titre", function()
	local p = newProfile()
	eq(Achievements.setStyle(p, "neck", "chain_gold", ctx), "locked")
	p.wardrobe.chain_gold = true
	eq(Achievements.setStyle(p, "frame", "chain_gold", ctx), "wrong_slot")
	eq(Achievements.setStyle(p, "neck", "bob", ctx), "unknown")
	eq(Achievements.setStyle(p, "pieds", "chain_gold", ctx), "invalid")
	eq(Achievements.setStyle(p, "neck", "chain_gold", ctx), nil)
	eq(Achievements.publicStyle(p, ctx), "neck=chain_gold")
	eq(Achievements.setStyle(p, "neck", nil, ctx), nil, "retirer")
	eq(p.style.neck, nil)
	eq(Achievements.setStyle(p, "title", "baddie_pro", ctx), "locked")
	p.titles.baddie_pro = true
	eq(Achievements.setStyle(p, "title", "baddie_pro", ctx), nil)
	eq(Achievements.view(p, ctx).title, "baddie_pro")
end)

test(
	"mort et renaissance : la garde-robe reste ; profil abîmé : sélection non débloquée retirée",
	function()
		local p = newProfile()
		p.wardrobe.chain_silver = true
		Achievements.setStyle(p, "neck", "chain_silver", ctx)
		CombatRules.applyDeath(p, ctx)
		finishRun(p)
		Slots.applyRebirth(p, ctx)
		eq(p.style.neck, "chain_silver", "porté après rebirth")
		p.style.face = "chain_gold" -- mauvais emplacement et non débloqué
		p.style.title = "baddie_expert"
		p.wardrobe.ancien_objet = true
		local issues = ProfileGuard.repair(p, ctx)
		eq(p.style.face, nil)
		eq(p.style.title, nil)
		eq(p.style.neck, "chain_silver")
		eq(p.wardrobe.ancien_objet, true, "objet inconnu archivé")
		eq(#issues, 2)
	end
)

test("configuration de la garde-robe cohérente (sources, récompenses, lot V1 figé)", function()
	for _, id in Wardrobe.itemOrder do
		local item = Wardrobe.items[id]
		assert(item ~= nil and Wardrobe.slotLabels[item.slot] ~= nil, `objet {id}`)
		assert(item.source == nil or Wardrobe.achievements[item.source] ~= nil, `source de {id}`)
	end
	for _, id in Wardrobe.achievementOrder do
		local def = Wardrobe.achievements[id]
		assert(def ~= nil and Achievements.conditions[id] ~= nil, `succès {id}`)
		for _, item in def.rewards.items or {} do
			assert(Wardrobe.items[item] ~= nil, `récompense {item}`)
		end
		for _, title in def.rewards.titles or {} do
			assert(Wardrobe.titles[title] ~= nil, `titre {title}`)
		end
	end
	eq(Catalog.lot, "V1")
	eq(table.concat(Wardrobe.lotV1.baddies, ","), table.concat(Catalog.baddieOrder, ","), "lot V1 baddies")
	eq(table.concat(Wardrobe.lotV1.crew, ","), table.concat(Catalog.crewOrder, ","), "lot V1 crew")
end)

print("Statistiques de jeu (§29)")

test("étapes d'accueil : chacune une seule fois, mémorisée dans le profil", function()
	local p = newProfile()
	eq(Metrics.once(p, "o1"), true)
	eq(Metrics.once(p, "o1"), false, "pas deux fois")
	eq(Metrics.once(p, "o2"), true)
	local steps = {}
	for _, step in Metrics.ONBOARDING do
		steps[step.step] = step.name
	end
	for i = 1, 8 do
		assert(steps[i] ~= nil, `étape {i} manquante`)
	end
end)

test("temps de jeu : sessions cumulées, durée du parcours depuis la renaissance", function()
	local p = newProfile()
	eq(Metrics.playSeconds(p, 30.7), 30)
	Metrics.closeSession(p, 100)
	Metrics.closeSession(p, 50)
	eq(Metrics.playSeconds(p, 10), 160, "100 + 50 + 10")
	Metrics.startRun(p, 160)
	eq(Metrics.runSeconds(p, 400), 240)
	Metrics.closeSession(p, -5) -- horloge incohérente : ignorée
	eq(Metrics.playSeconds(p, 0), 150)
end)

test("relances jusqu'à découverte : compteur remis à zéro à chaque nouvelle identité", function()
	local p = newProfile()
	eq(Metrics.onRoll(p, false), nil)
	eq(Metrics.onRoll(p, false), nil)
	eq(Metrics.onRoll(p, true), 3, "3 relances pour découvrir")
	eq(Metrics.onRoll(p, true), 1)
end)

test("paquets de puissance lisibles", function()
	eq(Metrics.powerBucket(3), "<10")
	eq(Metrics.powerBucket(37), "20+")
	eq(Metrics.powerBucket(76.9), "50+")
	eq(Metrics.powerBucket(1190), "1000+")
	eq(Metrics.powerBucket(250000), "200000+")
end)

test("profil P0 sans statistiques : complété par Reconcile, réparé si illisible", function()
	local raw = profileV4P0()
	raw.analytics = { once = { o1 = "oui" }, playSeconds = 0 / 0 }
	local data = load(raw)
	eq(data.analytics.once.o1, nil, "valeur illisible retirée")
	eq(data.analytics.playSeconds, 0)
	eq(data.analytics.rollsSinceDiscovery, 0)
end)

print(`\n{passed} réussi(s), {failed} échec(s)`)
process.exit(if failed > 0 then 1 else 0)
