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

print("Runner")
test("smoke", function()
	eq(1 + 1, 2)
end)

print(`\n{passed} réussi(s), {failed} échec(s)`)
if failed > 0 then
	process.exit(1)
end
