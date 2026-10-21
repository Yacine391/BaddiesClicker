--!strict
--[[
	WindowModel : règles pures des fenêtres (testées par tests/client/run.luau).
	- Un combat qui commence ferme la fenêtre ouverte : elle cacherait l'arène pendant les coups.
	- Les onglets se recalculent en direct, mais ne sont reconstruits que si un libellé ou un
	  compteur change (pas à chaque tick de puissance).
]]

local WindowModel = {}

function WindowModel.closesOnMode(mode: string?): boolean
	return mode == "combat"
end

function WindowModel.tabsSignature(tabs: { { id: string, label: string, count: string? } }?): string
	if tabs == nil then
		return ""
	end
	local parts = {}
	for _, tab in tabs do
		table.insert(parts, `{tab.id}:{tab.label}:{tab.count or ""}`)
	end
	return table.concat(parts, "|")
end

return WindowModel
