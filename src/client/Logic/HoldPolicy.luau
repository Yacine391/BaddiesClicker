--!strict
--[[
	HoldPolicy : quand le maintien du clic doit continuer (§07, §21).
	Pur, testé par tests/client/run.luau. Le maintien ne dépend jamais du survol :
	il s'arrête au relâchement réel, à l'ouverture d'une fenêtre ou si le réglage est coupé.
]]

export type HoldState = { holdEnabled: boolean, pressed: boolean, windowOpen: boolean }

local HoldPolicy = {}

function HoldPolicy.keepHolding(state: HoldState): boolean
	return state.holdEnabled and state.pressed and not state.windowOpen
end

return HoldPolicy
