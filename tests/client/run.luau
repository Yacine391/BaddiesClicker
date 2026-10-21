--[[
	Tests des modules purs du client (src/client/Logic), sans Studio.
	Depuis la racine du repo :  lune run tests/client/run

	Même style que tests/run.luau (codeur A). Les modules testés n'utilisent aucune
	API Roblox : Catalog et Format.number leur sont passés en paramètres.
]]

local process = require("@lune/process")

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

local function near(actual: number, expected: number, eps: number, what: string?)
	if math.abs(actual - expected) > eps then
		error(`{what or "valeur"} : attendu {expected} ± {eps}, obtenu {actual}`, 2)
	end
end

local Catalog = require("../../src/shared/Catalog")
local Format = require("../../src/shared/Format")
local HudModel = require("../../src/client/Logic/HudModel")
local WindowModel = require("../../src/client/Logic/WindowModel")
local Formation = require("../../src/client/Logic/Formation")
local LookRotation = require("../../src/client/Logic/LookRotation")
local HoldPolicy = require("../../src/client/Logic/HoldPolicy")
local TouchSize = require("../../src/client/Logic/TouchSize")
local PrimaryAction = require("../../src/client/Logic/PrimaryAction")
local LayoutMode = require("../../src/client/Logic/LayoutMode")
local StyleModel = require("../../src/client/Logic/StyleModel")
local Wardrobe = require("../../src/shared/Wardrobe")
local BookModel = require("../../src/client/Logic/BookModel")
local CombatModel = require("../../src/client/Logic/CombatModel")
local SlotsModel = require("../../src/client/Logic/SlotsModel")
local CrewModel = require("../../src/client/Logic/CrewModel")
local RankingModel = require("../../src/client/Logic/RankingModel")

print("Runner")
test("smoke", function()
	eq(1 + 1, 2)
end)

-- Snapshot de référence : exemple de docs/CONTRACT.md (v1)
local function baseSnapshot(): { [string]: any }
	return {
		v = 1,
		mode = "rest",
		power = 12.4,
		gainPerTrain = 1,
		passivePerSecond = 0.6,
		trainingBonus = 1,
		rebirths = 0,
		tickets = { baddie = 10, crew = 0 },
		active = { slotId = "s1", baddieId = "maya", multiplier = 1, masteryLevel = 0, damagePerClick = 12.4 },
		crew = { { id = "malik", level = 1, copies = 0, perSecond = 0.6 } },
		stats = { trainActions = 14, crewPowerEarned = 2.4 },
		tutorial = { crewUnlocked = true, progress = 10, needed = 10 },
	}
end

local function with(changes: { [string]: any }): { [string]: any }
	local s = baseSnapshot()
	for key, value in changes do
		s[key] = value
	end
	return s
end

local function build(snapshot: { [string]: any }?)
	return HudModel.build(snapshot, Catalog, Format.number)
end

print("HudModel")
test("pas de snapshot", function()
	local v = build(nil)
	eq(v.ready, false)
	eq(v.powerText, "—")
end)
test("puissance formatée", function()
	eq(build({ power = 1248.6 }).powerText, "1,25 K")
end)
test("production Malik", function()
	eq(build(baseSnapshot()).productionText, "+0,6/s Malik")
end)
test("sans compagnon", function()
	eq(build(with({ crew = {}, passivePerSecond = 0 })).productionText, nil)
end)
test("deux compagnons", function()
	local two = with({
		crew = {
			{ id = "malik", level = 1, copies = 0, perSecond = 0.6 },
			{ id = "enzo", level = 1, copies = 0, perSecond = 0.4 },
		},
		passivePerSecond = 1.0,
	})
	eq(build(two).productionText, "+1/s Crew")
end)
test("principale", function()
	local p = build(baseSnapshot()).principal
	assert(p, "principale attendue")
	eq(p.name, "Maya")
	eq(p.multiplierText, "×1")
	eq(p.slotText, "Slot 1")
	eq(p.rarityLabel, "Common")
	eq(p.rarityColor, Catalog.rarities.common.color)
end)
test("slot vide", function()
	eq(build(with({ active = { slotId = "s1", multiplier = 0, masteryLevel = 0 } })).principal, nil)
end)
test("ID inconnu", function()
	eq(
		build(with({ active = { slotId = "s1", baddieId = "ghost", multiplier = 1, masteryLevel = 0 } })).principal,
		nil
	)
end)
test("tutoriel", function()
	local t = build(with({ tutorial = { crewUnlocked = false, progress = 7, needed = 10 } })).tutorial
	eq(t.visible, true)
	eq(t.text, "Malik arrive : 7/10")
	near(t.ratio, 0.7, 1e-9)
end)
test("tutoriel terminé", function()
	eq(build(baseSnapshot()).tutorial.visible, false)
end)
test("bouton repos", function()
	local b = build(baseSnapshot()).button
	eq(b.label, "ENTRAÎNER")
	eq(b.colorKey, "Accent")
end)
test("bouton combat", function()
	local b = build(with({ mode = "combat" })).button
	eq(b.label, "ATTAQUER")
	eq(b.colorKey, "Accent2")
end)
test("tickets", function()
	eq(build(baseSnapshot()).ticketText, "10")
end)
test("Book ignore test_b99", function()
	local s = with({ collection = { discovered = { "maya", "test_b99" }, display = {}, looks = {} } })
	eq(build(s).bookCount.discovered, 1)
	eq(build(baseSnapshot()).bookCount.total, 8)
end)
test("Book en v1 : la principale compte", function()
	eq(build(baseSnapshot()).bookCount.discovered, 1)
end)
test("puissance NaN", function()
	eq(build({ power = 0 / 0 }).powerText, "—")
end)
test("puissance énorme", function()
	eq(build({ power = 1e15 }).powerText, Format.number(1e15))
end)

print("Formation")
test("principale exposée fusionnée", function()
	local m = Formation.members("maya", { "maya", "test_b99" }, { "malik" })
	eq(#m, 3)
	eq(m[1].id, "maya")
	eq(m[1].kind, "baddie")
	eq(m[2].id, "test_b99")
	eq(m[3].id, "malik")
	eq(m[3].kind, "crew")
end)
test("sans principale", function()
	eq(#Formation.members(nil, {}, { "malik" }), 1)
end)
test("plafond 1 + 3 + 2", function()
	eq(#Formation.members("a", { "b", "c", "d", "e" }, { "f", "g", "h" }), 6)
end)
test("offsets", function()
	local a, b, c = Formation.offset(1), Formation.offset(2), Formation.offset(3)
	eq(a.x, 0)
	eq(a.z, 4)
	eq(b.x, -3)
	eq(c.x, 3)
	eq(b.z, c.z)
	eq(b.z, a.z + 3)
end)
test("recalage au-delà de 40", function()
	local p = Formation.step({ x = 0, y = 0, z = 0 }, { x = 50, y = 0, z = 0 }, 0.016)
	eq(p.x, 50)
end)
test("interpolation", function()
	local p = Formation.step({ x = 0, y = 0, z = 0 }, { x = 10, y = 0, z = 0 }, 0.1)
	near(p.x, 10 * (1 - 0.001 ^ 0.1), 1e-9)
end)

print("HoldPolicy")
test("maintien : continue seulement si activé, appuyé et sans fenêtre", function()
	eq(HoldPolicy.keepHolding({ holdEnabled = true, pressed = true, windowOpen = false }), true)
end)
test("maintien : s'arrête quand une fenêtre s'ouvre", function()
	eq(HoldPolicy.keepHolding({ holdEnabled = true, pressed = true, windowOpen = true }), false)
end)
test("maintien : s'arrête quand le réglage est coupé", function()
	eq(HoldPolicy.keepHolding({ holdEnabled = false, pressed = true, windowOpen = false }), false)
end)
test("maintien : s'arrête au relâchement", function()
	eq(HoldPolicy.keepHolding({ holdEnabled = true, pressed = false, windowOpen = false }), false)
end)

print("PrimaryAction")
test("sans snapshot : aucune intention", function()
	eq(PrimaryAction.intent(nil), nil)
end)
test("au repos : Train", function()
	local i = PrimaryAction.intent({ mode = "rest" })
	assert(i, "intention attendue")
	eq(i.action, "Train")
	eq(i.payload, nil)
end)
test("combat inactif : Train", function()
	local i = PrimaryAction.intent({ combat = { active = false, hp = 100, maxHP = 100 } })
	assert(i, "intention attendue")
	eq(i.action, "Train")
end)
test("en combat : Attack avec la rencontre, jamais Train (§07)", function()
	local i = PrimaryAction.intent({ mode = "combat", combat = { active = true, encounterId = "123-4" } })
	assert(i and i.payload, "intention avec payload attendue")
	eq(i.action, "Attack")
	eq(i.payload.encounterId, "123-4")
end)
test("combat actif sans encounterId : aucune intention", function()
	eq(PrimaryAction.intent({ combat = { active = true } }), nil)
end)

print("TouchSize")
test("taille gardée si l'échelle la laisse au-dessus de 48 px", function()
	eq(TouchSize.offset(74, 1, 48), 74)
end)
test("taille compensée sous UIScale 0,5 (téléphone)", function()
	eq(TouchSize.offset(48, 0.5, 48), 96)
	eq(TouchSize.offset(74, 0.5, 48), 96)
end)
test("échelle nulle ou invalide : taille d'origine", function()
	eq(TouchSize.offset(48, 0, 48), 48)
	eq(TouchSize.offset(48, 0 / 0, 48), 48)
end)

print("LayoutMode")
test("seuil 0,6", function()
	eq(LayoutMode.mode(0.59), "compact")
	eq(LayoutMode.mode(0.6), "full")
end)
test("échelle invalide", function()
	eq(LayoutMode.mode(0 / 0), "full")
	eq(LayoutMode.mode(0), "full")
end)

print("HudModel v2")
test("progression tutoriel", function()
	local p = build(with({ tutorial = { crewUnlocked = false, progress = 7, needed = 10 } })).progress
	eq(p.visible, true)
	eq(p.kind, "tutorial")
	eq(p.title, "MALIK ARRIVE")
	eq(p.value, 7)
	eq(p.max, 10)
end)
test("progression parcours", function()
	local p = build(with({ clearedLevels = { 1, 2, 3 } })).progress
	eq(p.visible, true)
	eq(p.kind, "run")
	eq(p.title, "PARCOURS")
	eq(p.value, 3)
	eq(p.max, 10)
end)
test("progression absente", function()
	eq(build(baseSnapshot()).progress.visible, false)
end)
test("toast copie", function()
	eq(
		HudModel.toastFor({ kind = "crewJoined", crewId = "malik", isNew = false }, Catalog),
		"+1 copie : Malik"
	)
end)
test("pas de toast nouveau compagnon", function()
	eq(HudModel.toastFor({ kind = "crewJoined", crewId = "malik", isNew = true }, Catalog), nil)
end)
test("toast ticket", function()
	eq(HudModel.toastFor({ kind = "ticket", ticket = "crew", amount = 1 }, Catalog), "+1 ticket compagnon")
	eq(HudModel.toastFor({ kind = "ticket", ticket = "baddie", amount = 2 }, Catalog), "+2 tickets baddie")
end)
test("toast inconnu", function()
	eq(HudModel.toastFor({ kind = "passiveTick", amount = 0.6 }, Catalog), nil)
end)
test("cartes : principale puis compagnon", function()
	local cards = build(baseSnapshot()).cards
	eq(#cards, 2)
	eq(cards[1].name, "MAYA")
	eq(cards[1].rarity.label, "Common")
	eq(cards[1].line1, "×1 dégâts")
	eq(cards[1].line2, "Principale · Slot 1")
	eq(cards[1].accent, "#F2A65A")
	eq(cards[2].name, "MALIK")
	eq(cards[2].line1, "+0,6/s")
	eq(cards[2].line2, "DJ · Niv. 1")
	eq(cards[2].accent, "#13A6B5")
end)
test("cartes : 2 compagnons max, inconnus ignorés", function()
	local crew = {
		{ id = "malik", level = 2, perSecond = 0.66 },
		{ id = "inconnu", level = 1, perSecond = 1 },
		{ id = "enzo", level = 1, perSecond = 0.4 },
		{ id = "rafael", level = 1, perSecond = 0.8 },
	}
	local cards = build(with({ crew = crew })).cards
	eq(#cards, 3)
	eq(cards[3].name, "ENZO")
end)
test("cartes : sans principale ni crew", function()
	eq(#build(with({ active = false, crew = false })).cards, 0)
	eq(#build(nil).cards, 0)
end)

print("StyleModel")
test("sans style : looks seuls", function()
	local t = StyleModel.tabs(baseSnapshot(), Catalog, Wardrobe)
	eq(#t, 1)
	eq(t[1].id, "looks")
end)
test("aura et titre", function()
	local s = with({
		style = { items = { "aura_spark" }, titles = { "boss_manager" }, equipped = { aura = "aura_spark" } },
	})
	eq(#StyleModel.tabs(s, Catalog, Wardrobe), 3)
	eq(StyleModel.auraRows(s, Wardrobe)[1].equipped, true)
	eq(StyleModel.titleRows(s, Wardrobe)[1].name, "Gérant de Baddies")
	eq(StyleModel.titleRows(s, Wardrobe)[1].equipped, false)
end)

test("looks : porté, débloqué, verrouillé", function()
	local s = with({ collection = { looks = { maya = { unlocked = { 1, 2 }, selected = 2 } } } })
	local rows = StyleModel.lookRows(s, Catalog, { 0, 1, 5 })
	eq(#rows, 3)
	eq(rows[1].state, "unlocked")
	eq(rows[1].canWear, true)
	eq(rows[2].state, "worn")
	eq(rows[2].name, "STREET MATCH")
	eq(rows[3].state, "locked")
	eq(rows[3].mastery, 5)
	eq(rows[3].canWear, false)
end)
test("looks : v1 ou combat, aucune action", function()
	local rows = StyleModel.lookRows(baseSnapshot(), Catalog, { 0, 1, 5 })
	eq(rows[1].state, "worn")
	eq(rows[2].state, "locked")
	local s =
		with({ mode = "combat", collection = { looks = { maya = { unlocked = { 1, 2 }, selected = 1 } } } })
	eq(StyleModel.lookRows(s, Catalog, { 0, 1, 5 })[2].canWear, false)
	eq(StyleModel.canAct(s), false)
	eq(StyleModel.canAct(baseSnapshot()), true)
end)
test("looks : sans principale", function()
	eq(#StyleModel.lookRows(with({ active = false }), Catalog, { 0, 1, 5 }), 0)
end)

print("BookModel")
local function bookSnapshot(): { [string]: any }
	return with({
		collection = {
			discovered = { "maya", "nova", "test_b99" },
			display = { "nova" },
			looks = { maya = { unlocked = { 1, 2 }, selected = 2 } },
		},
	})
end
test("cartes : ordre du catalogue puis identités de test", function()
	local cards = BookModel.cards(bookSnapshot(), Catalog, Format.number)
	eq(#cards, 9)
	eq(cards[1].id, "maya")
	eq(cards[9].id, "test_b99")
	eq(cards[9].name, "TEST B99")
end)
test("cartes : puces principale, exposée, chance", function()
	local byId = {}
	for _, c in BookModel.cards(bookSnapshot(), Catalog, Format.number) do
		byId[c.id] = c
	end
	eq(byId.maya.chip.text, "PRINCIPALE · S1")
	eq(byId.maya.chip.colorKey, "Principal")
	eq(byId.nova.chip.text, "EXPOSÉE")
	eq(byId.nova.chip.colorKey, "Accent")
	eq(byId.lina.discovered, false)
	eq(byId.lina.name, "???")
	eq(byId.lina.chip.text, "25 %")
	eq(byId.test_b99.chip, nil)
end)
test("cartes : sans collection (v1), seule la principale est découverte", function()
	local cards = BookModel.cards(baseSnapshot(), Catalog, Format.number)
	eq(#cards, 8)
	eq(cards[1].discovered, true)
	eq(cards[2].discovered, false)
end)
test("fiche principale", function()
	local d = BookModel.detail(bookSnapshot(), Catalog, Format.number, "maya")
	eq(d.name, "MAYA")
	eq(d.isPrincipal, true)
	eq(d.multiplierText, "×1")
	eq(d.masteryText, "Niv. 0")
	eq(d.looksText, "2/3")
	eq(d.displayed, false)
	eq(d.canToggleDisplay, true)
end)
test("fiche exposée, autre baddie", function()
	local d = BookModel.detail(bookSnapshot(), Catalog, Format.number, "nova")
	eq(d.isPrincipal, false)
	eq(d.multiplierText, "×2,5")
	eq(d.masteryText, "—")
	eq(d.looksText, "—") -- Nova n'a pas encore de looks au Catalog
	eq(d.displayed, true)
	eq(d.canToggleDisplay, true)
end)
test("fiche : exposition pleine ou v1", function()
	local s = bookSnapshot()
	s.collection.display = { "nova", "test_b99", "maya" }
	s.collection.discovered = { "maya", "nova", "lina", "test_b99" }
	eq(BookModel.detail(s, Catalog, Format.number, "lina").canToggleDisplay, false)
	eq(BookModel.detail(baseSnapshot(), Catalog, Format.number, "maya").canToggleDisplay, false)
end)
test("fiche : pas d'exposition en combat", function()
	local s = bookSnapshot()
	s.mode = "combat"
	eq(BookModel.detail(s, Catalog, Format.number, "maya").canToggleDisplay, false)
	eq(BookModel.detail(s, Catalog, Format.number, "nova").canToggleDisplay, false)
	s.mode = "rest"
	eq(BookModel.detail(s, Catalog, Format.number, "nova").canToggleDisplay, true)
end)
test("fiche : exposition pleine → bouton grisé explicite", function()
	local s = bookSnapshot()
	s.collection.display = { "nova", "test_b99", "maya" }
	s.collection.discovered = { "maya", "nova", "lina", "test_b99" }
	eq(BookModel.detail(s, Catalog, Format.number, "lina").displayFullText, "EXPOSITION PLEINE 3/3")
	eq(BookModel.detail(s, Catalog, Format.number, "nova").displayFullText, nil, "déjà exposée : RETIRER")
	eq(BookModel.detail(bookSnapshot(), Catalog, Format.number, "maya").displayFullText, nil, "place libre")
end)
test("majuscules accentuées (annonces, titres)", function()
	eq(Format.upper("Première renaissance"), "PREMIÈRE RENAISSANCE")
	eq(Format.upper("Mythic découverte"), "MYTHIC DÉCOUVERTE")
	eq(Format.upper("Parcours terminé · scène"), "PARCOURS TERMINÉ · SCÈNE")
	eq(Format.upper("maya"), "MAYA")
end)
test("fiche non découverte", function()
	local d = BookModel.detail(bookSnapshot(), Catalog, Format.number, "vega")
	eq(d.discovered, false)
	eq(d.name, "???")
	eq(d.canToggleDisplay, false)
end)
test("liste d'exposition basculée", function()
	local ids = BookModel.toggleDisplay({ "nova" }, "maya")
	eq(#ids, 2)
	eq(ids[2], "maya")
	eq(#BookModel.toggleDisplay({ "nova", "maya" }, "nova"), 1)
end)
test("compteurs", function()
	local c = BookModel.counts(bookSnapshot(), Catalog)
	eq(c.baddies, 2)
	eq(c.baddiesTotal, 8)
	eq(c.crew, 1)
	eq(c.crewTotal, 6)
end)

print("WindowModel")
test("un combat qui commence ferme la fenêtre ouverte", function()
	eq(WindowModel.closesOnMode("combat"), true)
	eq(WindowModel.closesOnMode("lobby"), false)
	eq(WindowModel.closesOnMode(nil), false)
end)
test("signature des onglets : change seulement si un libellé ou un compteur change", function()
	local function tabs(drops: string)
		return {
			{ id = "slots", label = "SLOTS", count = "1" },
			{ id = "drops", label = "DROPS", count = drops },
		}
	end
	eq(WindowModel.tabsSignature(tabs("2")), WindowModel.tabsSignature(tabs("2")))
	eq(WindowModel.tabsSignature(tabs("2")) == WindowModel.tabsSignature(tabs("1")), false)
	local looks = { { id = "looks", label = "LOOKS" }, { id = "aura", label = "AURA" } }
	eq(WindowModel.tabsSignature(looks) == WindowModel.tabsSignature({ looks[1] }), false)
	eq(WindowModel.tabsSignature(nil), "")
end)

print("LookRotation")
test("index", function()
	eq(LookRotation.index(0, 6, 3), 1)
	eq(LookRotation.index(6.1, 6, 3), 2)
	eq(LookRotation.index(12, 6, 3), 3)
	eq(LookRotation.index(18, 6, 3), 1)
end)

print("Combat (flux serveur → affichage)")

local function startedCombat()
	local s = CombatModel.new()
	CombatModel.apply(
		s,
		{ t = "start", encounterId = "1-1", levelId = 2, floorY = 0.05, boss = "iris", minionsTotal = 3 }
	)
	CombatModel.apply(
		s,
		{ t = "spawn", enemy = { id = "1-1:1", kind = "minion", hp = 50, maxHP = 50, x = 0, z = -15 } }
	)
	return s
end

test("combat : vague puis boss, la barre suit le serveur", function()
	local s = startedCombat()
	eq(CombatModel.active(s), true)
	local bar = CombatModel.bar(s, Catalog, Format.number)
	eq(bar.visible, true)
	eq(bar.isBoss, false)
	eq(bar.text, "0 / 3 · puis IRIS")
	local hit = CombatModel.apply(s, { t = "hit", targetId = "1-1:1", damage = 50, hp = 0, killed = true })
	assert(hit ~= nil and hit.hp == 0, "ennemi touché renvoyé")
	eq(s.minionsKilled, 1)
	eq(s.enemies["1-1:1"], nil, "sbire retiré")
	CombatModel.apply(s, {
		t = "spawn",
		enemy = { id = "1-1:4", kind = "boss", baddieId = "iris", hp = 450, maxHP = 450, x = 0, z = -18 },
	})
	CombatModel.apply(s, { t = "hit", targetId = "1-1:4", damage = 225, hp = 225, killed = false })
	bar = CombatModel.bar(s, Catalog, Format.number)
	eq(bar.isBoss, true)
	eq(bar.title, "NIVEAU 2 · BOSS IRIS")
	near(bar.ratio, 0.5, 1e-9)
end)

test("combat : positions interpolées et fin de rencontre", function()
	local s = startedCombat()
	CombatModel.apply(s, { t = "pos", list = { { "1-1:1", 3.5, -8 }, { "inconnu", 1, 1 } } })
	eq(s.enemies["1-1:1"].x, 3.5)
	eq(s.enemies["1-1:1"].z, -8)
	CombatModel.apply(s, { t = "end", encounterId = "1-1", reason = "death" })
	eq(CombatModel.active(s), false)
	eq(next(s.enemies), nil)
	eq(CombatModel.bar(s, Catalog, Format.number).visible, false)
end)

test("combat : messages invalides ignorés", function()
	local s = CombatModel.new()
	eq(CombatModel.apply(s, { t = "spawn", enemy = "x" }), nil)
	eq(CombatModel.apply(s, { t = "hit", targetId = "absent", hp = 0, killed = true }), nil)
	eq(CombatModel.apply(s, { t = "inconnu" }), nil)
	eq(s.minionsKilled, 0)
end)

test("combat : PV du joueur depuis le snapshot", function()
	eq(CombatModel.playerBar(nil).visible, false)
	eq(CombatModel.playerBar({ combat = { active = false, hp = 100, maxHP = 100 } }).visible, false)
	local bar = CombatModel.playerBar({ combat = { active = true, hp = 25, maxHP = 100 } })
	eq(bar.visible, true)
	eq(bar.text, "25 PV")
	eq(bar.low, true)
	eq(CombatModel.playerBar({ combat = { active = true, hp = 80, maxHP = 100 } }).low, false)
end)

test("combat : rejouer seulement dans l'arène d'un niveau terminé, hors combat", function()
	local snap = { mode = "rest", clearedLevels = { 1, 2 } }
	eq(CombatModel.replayLevel(snap, 2), 2)
	eq(CombatModel.replayLevel(snap, 3), nil)
	eq(CombatModel.replayLevel(snap, nil), nil)
	eq(CombatModel.replayLevel({ mode = "combat", clearedLevels = { 1 } }, 1), nil)
end)

test("combat : puissance conseillée (§09), absente si le serveur ne l'envoie pas", function()
	local hint = CombatModel.hint(
		{ mode = "rest", power = 900, nextLevel = { levelId = 2, recommendedPower = 886 } },
		Format.number
	)
	eq(hint.visible, true)
	eq(hint.ready, true)
	eq(hint.text, "NIVEAU 2 · puissance conseillée 886")
	eq(
		CombatModel.hint(
			{ mode = "rest", power = 10, nextLevel = { levelId = 2, recommendedPower = 886 } },
			Format.number
		).ready,
		false
	)
	eq(CombatModel.hint({ mode = "rest", power = 10 }, Format.number).visible, false)
	eq(
		CombatModel.hint(
			{ mode = "combat", nextLevel = { levelId = 2, recommendedPower = 1 } },
			Format.number
		).visible,
		false
	)
end)

test("combat : toasts de fin de rencontre", function()
	local cleared = CombatModel.toastFor(
		{ kind = "levelCleared", level = 1, power = 15, firstClear = true, baddieTickets = 1 },
		Catalog,
		Format.number
	)
	eq(cleared, "Niveau 1 terminé : +15 puissance, +1 ticket · pas de drop (10 % par victoire)")
	local drop = CombatModel.toastFor(
		{ kind = "levelCleared", level = 1, power = 15, drop = "jade" },
		Catalog,
		Format.number
	)
	eq(drop, "Niveau 1 terminé : +15 puissance · drop de JADE en attente")
	assert(CombatModel.toastFor({ kind = "death" }, Catalog, Format.number) ~= nil, "mort")
	assert(
		CombatModel.toastFor({ kind = "combatInvalid", level = 1 }, Catalog, Format.number) ~= nil,
		"invalidé"
	)
	eq(CombatModel.toastFor({ kind = "ticket" }, Catalog, Format.number), nil, "laissé au HUD")
end)

print("Slots, drops, renaissance et crew")

local function slotsSnapshot()
	return {
		mode = "rest",
		saving = false,
		maintenance = {},
		tickets = { baddie = 3, crew = 2 },
		rolls = { untilGuarantee = 12, bookComplete = false },
		slots = {
			{
				id = "s1",
				order = 1,
				conserved = true,
				temporary = false,
				baddieId = "nova",
				revision = 4,
				rollLocked = true,
				active = true,
			},
			{
				id = "s2",
				order = 2,
				conserved = false,
				temporary = true,
				baddieId = "lina",
				revision = 2,
				rollLocked = false,
				active = false,
			},
		},
		pendingDrops = { vega = 1, jade = 2 },
		pendingRevision = 7,
		collection = { discovered = { "maya", "nova", "lina", "jade" } },
		rebirth = { count = 0, available = true, promotesNext = true, baddieTickets = 5, crewTickets = 1 },
		run = { id = 3 },
		crewOwned = {
			{ id = "malik", level = 2, copies = 3, equipped = true },
			{ id = "enzo", level = 1, copies = 1, equipped = false },
		},
		crewChest = { untilGuarantee = 1, complete = false },
	}
end

test("slots : verrou, ticket et garantie expliqués", function()
	local rows = SlotsModel.slotRows(slotsSnapshot(), Catalog, Format.number)
	eq(#rows, 2)
	eq(rows[1].kind, "CONSERVÉ")
	eq(rows[1].canRoll, false, "verrouillé")
	eq(rows[2].kind, "TEMPORAIRE")
	eq(rows[2].canRoll, true)
	eq(rows[2].rollHint, "1 ticket · garantie dans 12")
	eq(rows[2].multiplierText, "×1,2")
	local s = slotsSnapshot()
	s.tickets.baddie = 0
	eq(SlotsModel.slotRows(s, Catalog, Format.number)[2].canRoll, false, "sans ticket")
	s = slotsSnapshot()
	s.mode = "combat"
	eq(SlotsModel.slotRows(s, Catalog, Format.number)[2].rollHint, "impossible en combat")
	s = slotsSnapshot()
	s.maintenance = { "Roll" }
	eq(SlotsModel.slotRows(s, Catalog, Format.number)[2].canRoll, false, "maintenance")
end)

test("drops : ordre du catalogue, cible = slot temporaire, nouveauté", function()
	local rows = SlotsModel.dropRows(slotsSnapshot(), Catalog, Format.number)
	eq(#rows, 2)
	eq(rows[1].baddieId, "jade")
	eq(rows[1].count, 2)
	eq(rows[1].isNew, false)
	eq(rows[2].baddieId, "vega")
	eq(rows[2].isNew, true)
	eq(rows[2].replaceText, "remplacera LINA dans le SLOT 2")
	eq(rows[2].slotRevision, 2)
	eq(rows[2].pendingRevision, 7)
	eq(SlotsModel.dropCount(slotsSnapshot()), 3)
end)

test("renaissance : palier qui promeut, ou temporaire effacé", function()
	local view = SlotsModel.rebirthView(slotsSnapshot(), Catalog)
	eq(view.available, true)
	eq(view.runId, 3)
	eq(view.title, "RENAISSANCE 1")
	assert(string.find(view.lose, "devient CONSERVÉ", 1, true), view.lose)
	local s = slotsSnapshot()
	s.rebirth.promotesNext = false
	assert(
		string.find(
			SlotsModel.rebirthView(s, Catalog).lose,
			"LINA (SLOT 2, temporaire) sera effacée",
			1,
			true
		)
	)
	s.mode = "combat"
	eq(SlotsModel.rebirthView(s, Catalog).available, false, "pas en combat")
end)

test("décisions : textes de résultat et de refus", function()
	eq(
		SlotsModel.resultText({
			kind = "mutation",
			action = "Roll",
			ok = true,
			result = { previousId = "lina", baddieId = "vega", isNew = true },
		}, Catalog),
		"SLOT : LINA → VEGA · NOUVELLE !"
	)
	eq(
		SlotsModel.resultText(
			{ kind = "mutation", action = "Roll", ok = false, reason = "no_ticket" },
			Catalog
		),
		"Refusé : pas de ticket"
	)
	eq(
		SlotsModel.resultText({
			kind = "mutation",
			action = "OpenChest",
			ok = true,
			result = { crewId = "malik", isNew = false },
		}, Catalog),
		"Coffre : MALIK, +1 copie"
	)
	eq(SlotsModel.resultText({ kind = "ticket" }, Catalog), nil)
	eq(SlotsModel.reasonText("inconnue"), "inconnue")
end)

test("crew : amélioration, équipe de deux, coffre", function()
	eq(CrewModel.upgradeCost(1, 10), 2)
	eq(CrewModel.upgradeCost(10, 10), nil)
	eq(CrewModel.canUpgrade({ level = 2, copies = 3 }, 10), true)
	eq(CrewModel.canUpgrade({ level = 2, copies = 2 }, 10), false)
	local ids = CrewModel.toggleEquip({ "malik" }, "enzo", 2) :: { string }
	eq(#ids, 2)
	eq(CrewModel.toggleEquip({ "malik", "enzo" }, "rafael", 2), nil, "équipe pleine")
	eq(#(CrewModel.toggleEquip({ "malik", "enzo" }, "malik", 2) :: { string }), 1, "retirer")
	eq(#CrewModel.equippedIds(slotsSnapshot()), 1)
	eq(CrewModel.chestText(slotsSnapshot()), "2 tickets compagnon · le prochain est garanti")
end)

print("Classement du lobby et titres")

test("classement : top 5, scores sur le total, joueur local surligné ou ajouté", function()
	local ranking = { lot = "V1", total = 8, crewTotal = 6, baddies = {}, crew = {} }
	for i = 1, 7 do
		table.insert(ranking.baddies, { userId = i, name = `Joueur{i}`, score = 8 - i, rank = i })
	end
	local board = RankingModel.board(ranking, "baddies", 5, 2)
	eq(#board.lines, 5)
	eq(board.lines[1].rank, "#1")
	eq(board.lines[1].score, "7/8")
	eq(board.lines[2].isMe, true)
	local far = RankingModel.board(ranking, "baddies", 5, 7)
	eq(far.lines[5].name, "Joueur7", "joueur local hors du top 5 en dernière ligne")
	eq(far.lines[5].isMe, true)
	local crew = RankingModel.board(ranking, "crew", 5, 1)
	eq(crew.title, "CLASSEMENT · CREW")
	assert(crew.empty ~= nil, "onglet crew vide")
	eq(RankingModel.board(nil, "baddies", 5, 1).empty ~= nil, true)
	local long = RankingModel.board(
		{ total = 8, baddies = { { userId = 1, name = "UnTrèsLongPseudoRoblox", score = 1, rank = 1 } } },
		"baddies",
		5,
		nil
	)
	eq(long.lines[1].name, "UnTrèsLongPseud…")
end)

test("titres : nom du Wardrobe, rien si vide ou inconnu", function()
	eq(RankingModel.titleText("boss_manager", Wardrobe), "Gérant de Baddies")
	eq(RankingModel.titleText("", Wardrobe), nil)
	eq(RankingModel.titleText("inconnu", Wardrobe), nil)
	eq(RankingModel.titleText(nil, Wardrobe), nil)
end)

print(`\n{passed} réussi(s), {failed} échec(s)`)
if failed > 0 then
	process.exit(1)
end
