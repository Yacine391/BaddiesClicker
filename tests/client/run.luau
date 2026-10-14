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
	eq(b.colorKey, "Action")
end)
test("bouton combat", function()
	local b = build(with({ mode = "combat" })).button
	eq(b.label, "ATTAQUER")
	eq(b.colorKey, "Fermer")
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

print(`\n{passed} réussi(s), {failed} échec(s)`)
if failed > 0 then
	process.exit(1)
end
