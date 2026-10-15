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
local Formation = require("../../src/client/Logic/Formation")
local LookRotation = require("../../src/client/Logic/LookRotation")
local HoldPolicy = require("../../src/client/Logic/HoldPolicy")
local TouchSize = require("../../src/client/Logic/TouchSize")
local PrimaryAction = require("../../src/client/Logic/PrimaryAction")
local LayoutMode = require("../../src/client/Logic/LayoutMode")
local StyleModel = require("../../src/client/Logic/StyleModel")
local Wardrobe = require("../../src/shared/Wardrobe")

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
	eq(HudModel.toastFor({ kind = "ticket", ticket = "baddie", amount = 2 }, Catalog), "+2 ticket baddie")
end)
test("toast inconnu", function()
	eq(HudModel.toastFor({ kind = "passiveTick", amount = 0.6 }, Catalog), nil)
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

print("LookRotation")
test("index", function()
	eq(LookRotation.index(0, 6, 3), 1)
	eq(LookRotation.index(6.1, 6, 3), 2)
	eq(LookRotation.index(12, 6, 3), 3)
	eq(LookRotation.index(18, 6, 3), 1)
end)

print(`\n{passed} réussi(s), {failed} échec(s)`)
if failed > 0 then
	process.exit(1)
end
