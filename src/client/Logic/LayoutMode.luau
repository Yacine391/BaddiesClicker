--!strict
--[[
	LayoutMode : disposition du HUD selon l'échelle de l'interface (spec refonte §4).
	Sous 0,6 (téléphone), le menu passe en tuiles et les cartes se réduisent : « compact ».
	Pur, testé par tests/client/run.luau.
]]

local COMPACT_BELOW = 0.6

local LayoutMode = {}

function LayoutMode.mode(scale: number): "full" | "compact"
	if scale ~= scale or scale <= 0 then
		return "full"
	end
	return if scale < COMPACT_BELOW then "compact" else "full"
end

return LayoutMode
