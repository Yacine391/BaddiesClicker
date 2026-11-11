--!strict
--[[
	Motion : durées et courbes communes de l'interface (spec simulateur §5.3).
	Un seul tween actif par instance : le nouveau annule l'ancien (clics rapides sans empilement).
	Effets réduits (UiState.settings.reducedEffects) : pas d'échelle, les cibles prennent leur valeur finale.
]]

local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local peek = require(Client.Packages.Fusion).peek
local UiState = require(Client.UiState)

local Motion = {}

Motion.Hover = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Motion.Press = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
Motion.Release = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Motion.Open = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
Motion.Close = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
Motion.Fill = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local active: { [Instance]: Tween } = setmetatable({}, { __mode = "k" }) :: any

function Motion.reduced(): boolean
	local settings = UiState.settings
	return settings ~= nil and peek(settings.reducedEffects) == true
end

-- Joue `goal` sur `target` en annulant le tween précédent de la même instance
function Motion.tween(target: Instance, info: TweenInfo, goal: { [string]: any })
	local previous = active[target]
	if previous then
		previous:Cancel()
	end
	local tween = TweenService:Create(target, info, goal)
	active[target] = tween
	tween:Play()
end

-- Échelle d'un UIScale ; en effets réduits, reste à 1
function Motion.scale(target: UIScale, value: number, info: TweenInfo)
	if Motion.reduced() then
		value = 1
	end
	Motion.tween(target, info, { Scale = value })
end

function Motion.hover(target: UIScale, on: boolean)
	Motion.scale(target, if on then 1.04 else 1, Motion.Hover)
end

function Motion.press(target: UIScale, down: boolean)
	Motion.scale(target, if down then 0.92 else 1, if down then Motion.Press else Motion.Release)
end

-- Ouverture d'une fenêtre : 0,9 → 1
function Motion.open(target: UIScale)
	if Motion.reduced() then
		target.Scale = 1
		return
	end
	target.Scale = 0.9
	Motion.tween(target, Motion.Open, { Scale = 1 })
end

return Motion
