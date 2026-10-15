--!strict
--[[
	TouchSize : garde une cible tactile d'au moins `min` px à l'écran malgré le UIScale (§21).
	`base` est la taille voulue dans la résolution de référence (1280 × 720), `scale` l'UIScale courant.
	Pur, testé par tests/client/run.luau.
]]

local TouchSize = {}

function TouchSize.offset(base: number, scale: number, min: number): number
	if scale ~= scale or scale <= 0 then
		return base
	end
	return math.max(base, min / scale)
end

return TouchSize
