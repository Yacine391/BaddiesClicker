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

local ctx = { Balance = Balance, Catalog = Catalog, Formulas = Formulas }

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

print(`\n{passed} réussi(s), {failed} échec(s)`)
process.exit(if failed > 0 then 1 else 0)
