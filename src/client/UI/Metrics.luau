--!strict
--[[
	Metrics : échelle courante de l'interface (UIScale du HUD), partagée avec les composants
	pour garder les cibles tactiles à au moins Theme.MinTouch px réels à l'écran (§21).
]]

local Theme = require(script.Parent.Theme)
local TouchSize = require(script.Parent.Parent.Logic.TouchSize)

local Metrics = {}

Metrics.scale = nil :: any -- état Fusion<number>, posé par le HUD

-- Taille (en px de référence) compensée pour rester ≥ MinTouch à l'écran ; état Fusion si l'échelle est connue
function Metrics.touch(scope: any, base: number): any
	local scale = Metrics.scale
	if scale == nil then
		return base
	end
	return scope:Computed(function(use)
		return TouchSize.offset(base, use(scale), Theme.MinTouch)
	end)
end

return Metrics
