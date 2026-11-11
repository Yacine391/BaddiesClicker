--!strict
--[[
	CounterPill : compteur empilé en bas à gauche (puissance, tickets, pièces) — style simulateur :
	icône pleine 40 + chiffre FredokaOne 34 contouré. « Pop » du chiffre quand `Pulse` change (coupé en effets réduits).
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Motion = require(UI.Motion)
local Icon = require(script.Parent.Icon)

export type Props = {
	Icon: string,
	Text: any, -- état de string
	Glow: boolean?, -- ignoré (style mix A)
	Pulse: any?, -- état de number : chaque changement déclenche le pop
	LayoutOrder: number?,
	Name: string?,
}

return function(scope: any, props: Props): Frame
	local scale = scope:New("UIScale")({ Scale = 1 })
	if props.Pulse ~= nil then
		table.insert(
			scope,
			scope:Observer(props.Pulse):onChange(function()
				if Motion.reduced() then
					return
				end
				scale.Scale = 1.12
				Motion.tween(scale, Motion.Release, { Scale = 1 })
			end)
		)
	end

	-- Style simulateur : pas de pastille, icône pleine + gros chiffre contouré (spec §4.1)
	return scope:New("Frame")({
		Name = props.Name or ("Counter_" .. props.Icon),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = props.LayoutOrder or 0,
		[scope.Children] = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Icon(scope, { Name = props.Icon, Size = UDim2.fromOffset(40, 40) }),
			scope:New("TextLabel")({
				Name = "Value",
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 40),
				Text = props.Text,
				FontFace = Theme.Fonts.Main,
				TextSize = 34,
				TextColor3 = Theme.Colors.Text,
				[scope.Children] = {
					scale,
					scope:New("UIStroke")({
						Color = Theme.Colors.Ink,
						Thickness = Theme.Stroke.Text,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
					}),
				},
			}),
		},
	}) :: Frame
end
