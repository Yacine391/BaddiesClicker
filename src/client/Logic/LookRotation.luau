--!strict
--[[
	LookRotation : quel look de Maya le podium montre à l'instant t (dossier §05).
	Pur, testé par tests/client/run.luau.
]]

local LookRotation = {}

function LookRotation.index(t: number, period: number, count: number): number
	return math.floor(t / period) % count + 1
end

return LookRotation
