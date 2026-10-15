--!strict
--[[
	TestCatalog : identités de TEST, chargées UNIQUEMENT dans Studio (proposition contrat v2 du codeur B, §5).
	Jamais dans le lot public, jamais tirées en relance, jamais comptées dans le Baddies Book ni le classement.
	Servent à tester l'exposition et les looks sans produire d'autres personnages (§02, §13).
]]

local TestCatalog = {
	baddies = {
		test_b99 = {
			code = "T99",
			name = "Test B99",
			rarity = "common",
			multiplier = 1.0,
			rollChance = 0,
			looks = { "Silhouette" }, -- un seul look
			palette = { "#9C98A8", "#F4EEE7", "#242036" }, -- silhouette grise
			test = true,
		},
	},
	order = { "test_b99" },
}

local function deepFreeze(t: any)
	for _, value in t do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	table.freeze(t)
end

--[[
	Catalogue de Studio : le catalogue public + les identités de test, rangées à part.
	`baddieOrder` reste PUBLIC (relances, garantie et Baddies Book n'utilisent que lui) ;
	les IDs de test sont listés dans `testOrder` (après les publics dans la vue du Book).
]]
local function merge(catalog: any): any
	local merged = table.clone(catalog)
	local baddies = table.clone(catalog.baddies)
	for id, def in TestCatalog.baddies do
		assert(baddies[id] == nil, `identité de test en double : {id}`)
		baddies[id] = def
	end
	merged.baddies = table.freeze(baddies)
	merged.testOrder = TestCatalog.order
	return table.freeze(merged)
end

deepFreeze(TestCatalog)

return table.freeze({
	baddies = TestCatalog.baddies,
	order = TestCatalog.order,
	merge = merge,
})
