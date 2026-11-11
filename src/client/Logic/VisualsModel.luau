--!strict
--[[
	VisualsModel : où trouver le modèle d'une identité dans ReplicatedStorage.Visuals.Characters
	(généré par assets/visuals/export-characters). Pur : Catalog passé en paramètre, testé avec Lune.

	  baddie      Characters.<code>_<nom>.Look01 … Look03   (ex. B09_Cherry.Look02)
	  compagnon   Characters.<code>_<nom>.Base              (ex. C02_Malik.Base)
	  test        Characters.TEST.TEST_B99                  (Studio ; absente du Catalog client)
	  sbire       Characters.Minions.<archétype>
]]

export type Path = { folder: string, model: string }

local VisualsModel = {}

local TEST: { [string]: Path } = {
	test_b99 = { folder = "TEST", model = "TEST_B99" },
}

local MINIONS = { "Street", "Runner", "Heavy" }

function VisualsModel.folderName(def: any): string
	return `{def.code}_{def.name}`
end

function VisualsModel.lookName(look: number?): string
	local index = math.clamp(math.floor(tonumber(look) or 1), 1, 3)
	return string.format("Look%02d", index)
end

-- "baddie" | "crew" | nil (identité inconnue du catalogue public et des identités de test)
function VisualsModel.kindOf(catalog: any, id: any): string?
	if type(id) ~= "string" then
		return nil
	end
	if catalog.baddies[id] ~= nil or TEST[id] ~= nil then
		return "baddie"
	elseif catalog.crew[id] ~= nil then
		return "crew"
	end
	return nil
end

function VisualsModel.path(catalog: any, id: any, look: number?): Path?
	if type(id) ~= "string" then
		return nil
	end
	if TEST[id] ~= nil then
		return TEST[id]
	end
	local baddie = catalog.baddies[id]
	if baddie ~= nil then
		return { folder = VisualsModel.folderName(baddie), model = VisualsModel.lookName(look) }
	end
	local crew = catalog.crew[id]
	if crew ~= nil then
		return { folder = VisualsModel.folderName(crew), model = "Base" }
	end
	return nil
end

-- Archétype de sbire d'un niveau : varie d'un niveau à l'autre, stable pour un niveau donné
function VisualsModel.minion(levelId: number?): Path
	local index = ((math.max(1, math.floor(tonumber(levelId) or 1)) - 1) % #MINIONS) + 1
	return { folder = "Minions", model = MINIONS[index] }
end

-- Vitrine du podium (§05) : les trois looks de Maya, puis la nouveauté mise en avant
export type Showcase = { id: string, look: number, title: string }
function VisualsModel.showcase(catalog: any, featured: string?): { Showcase }
	local list: { Showcase } = {}
	local function addLooks(id: string, prefix: string)
		local def = catalog.baddies[id]
		if def == nil then
			return
		end
		for look = 1, 3 do
			local name = def.looks and def.looks[look]
			table.insert(list, {
				id = id,
				look = look,
				title = `{prefix}{def.name} · Look {look}{if name then " · " .. name else ""}`,
			})
		end
	end
	addLooks("maya", "")
	if featured ~= nil and featured ~= "maya" then
		addLooks(featured, "NOUVEAU · ")
	end
	return list
end

return VisualsModel
