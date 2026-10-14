--!strict
--[[
	Catalog : identités publiques du lot V1 (baddies et compagnons).

	- Les IDs sont STABLES : ne jamais renommer un ID publié (profils, drops, Book en dépendent).
	- Couleurs en hex, à convertir côté client avec Color3.fromHex.
	- Aucun require, aucune API Roblox : testable avec Lune.
]]

local Catalog = {
	lot = "V1",

	-- §20 : nom et symbole complètent la couleur
	rarities = {
		common = { order = 1, label = "Common", symbol = "cercle", color = "#9C98A8" },
		silver = { order = 2, label = "Silver", symbol = "losange", color = "#A7C3E6" },
		gold = { order = 3, label = "Gold", symbol = "étoile", color = "#D7A746" },
		legendary = { order = 4, label = "Legendary", symbol = "double étoile", color = "#7642A3" },
		mythic = { order = 5, label = "Mythic", symbol = "prisme", color = "#13A6B5" },
	},

	-- §13 : multiplicateur et chance standard de relance (total 100 %)
	baddies = {
		maya = {
			code = "B01",
			name = "Maya",
			rarity = "common",
			multiplier = 1.0,
			rollChance = 32,
			looks = { "Street Start", "Street Match", "Street Signature" },
			palette = { "#3B5B8C", "#F4EEE7", "#F2A65A" }, -- denim, crème, orange doux
		},
		lina = {
			code = "B02",
			name = "Lina",
			rarity = "common",
			multiplier = 1.2,
			rollChance = 25,
			looks = {},
			palette = { "#8FA98B", "#F4F1EA", "#3A3A40" }, -- vert sauge, blanc cassé, anthracite
		},
		jade = {
			code = "B03",
			name = "Jade",
			rarity = "silver",
			multiplier = 1.5,
			rollChance = 17,
			looks = {},
			palette = { "#151517", "#13A6B5", "#C0C4CC" }, -- noir, cyan, argent
		},
		iris = {
			code = "B04",
			name = "Iris",
			rarity = "silver",
			multiplier = 1.8,
			rollChance = 12,
			looks = {},
			palette = { "#B9A3D9", "#F4EEE7", "#D6336C" }, -- lilas, crème, rose framboise
		},
		sienna = {
			code = "B05",
			name = "Sienna",
			rarity = "gold",
			multiplier = 2.2,
			rollChance = 7,
			looks = {},
			palette = { "#B87333", "#E8A0A8", "#FFFFFF" }, -- cuivre, rose, blanc
		},
		nova = {
			code = "B06",
			name = "Nova",
			rarity = "gold",
			multiplier = 2.5,
			rollChance = 5,
			looks = {},
			palette = { "#1B2A4A", "#D7A746", "#FFFFF0" }, -- bleu nuit, or, ivoire
		},
		zuri = {
			code = "B07",
			name = "Zuri",
			rarity = "legendary",
			multiplier = 3.2,
			rollChance = 1.5,
			looks = {},
			palette = { "#4B1D7A", "#C0C4CC", "#111111" }, -- violet profond, argent, noir
		},
		vega = {
			code = "B08",
			name = "Vega",
			rarity = "mythic",
			multiplier = 4.0,
			rollChance = 0.5,
			looks = {},
			palette = { "#FFFFFF", "#30D5C8", "#7642A3" }, -- blanc, turquoise, violet
		},
	},
	baddieOrder = { "maya", "lina", "jade", "iris", "sienna", "nova", "zuri", "vega" },

	-- §16 : production de base et chance de coffre (total 100 %)
	crew = {
		enzo = {
			code = "C01",
			name = "Enzo",
			role = "danseur",
			rarity = "common",
			basePowerPerSecond = 0.4,
			chestChance = 30,
		},
		malik = {
			code = "C02",
			name = "Malik",
			role = "DJ",
			rarity = "common",
			basePowerPerSecond = 0.6,
			chestChance = 25,
			palette = { "#2B2B30", "#13A6B5", "#C0C4CC" }, -- anthracite, cyan, argent
		},
		rafael = {
			code = "C03",
			name = "Rafael",
			role = "sportif",
			rarity = "silver",
			basePowerPerSecond = 0.8,
			chestChance = 20,
		},
		dario = {
			code = "C04",
			name = "Dario",
			role = "chic",
			rarity = "gold",
			basePowerPerSecond = 1.2,
			chestChance = 12,
		},
		kenji = {
			code = "C05",
			name = "Kenji",
			role = "danseur techno",
			rarity = "legendary",
			basePowerPerSecond = 1.6,
			chestChance = 8,
		},
		amine = {
			code = "C06",
			name = "Amine",
			role = "scène",
			rarity = "mythic",
			basePowerPerSecond = 2.0,
			chestChance = 5,
		},
	},
	crewOrder = { "enzo", "malik", "rafael", "dario", "kenji", "amine" },
}

local function deepFreeze(t: any)
	for _, value in t do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	table.freeze(t)
end
deepFreeze(Catalog)

return Catalog
