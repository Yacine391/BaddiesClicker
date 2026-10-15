--!strict
--[[
	CounterPill : compteur du haut à droite (puissance, tickets) — panneau 46 px de haut,
	largeur ajustée au texte, icône 32 + chiffre ExtraBold 25. « Pop » du chiffre quand `Pulse` change.
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Panel = require(script.Parent.Panel)
local Icon = require(script.Parent.Icon)

export type Props = {
	Icon: string,
	Text: any, -- état de string
	Glow: boolean,
	Pulse: any?, -- état de number : chaque changement déclenche le pop
	LayoutOrder: number?,
	Name: string?,
}

return function(scope: any, props: Props): Frame
	local target = scope:Value(1)
	if props.Pulse ~= nil then
		table.insert(
			scope,
			scope:Observer(props.Pulse):onChange(function()
				target:set(1.12)
				task.delay(0.08, function()
					target:set(1)
				end)
			end)
		)
	end
	local pop = scope:Spring(target, 40, 0.5)

	return Panel(scope, {
		Name = props.Name or ("Counter_" .. props.Icon),
		Size = UDim2.fromOffset(0, 46),
		AutomaticSize = Enum.AutomaticSize.X,
		Glow = if props.Glow then Theme.Colors.Accent else nil,
		LayoutOrder = props.LayoutOrder,
		Children = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 10),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 16) }),
			Icon(scope, { Name = props.Icon, Size = UDim2.fromOffset(32, 32) }),
			scope:New("TextLabel")({
				Name = "Value",
				LayoutOrder = 1,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = UDim2.fromOffset(0, 32),
				Text = props.Text,
				FontFace = Theme.Fonts.ExtraBold,
				TextSize = 25,
				TextColor3 = Theme.Colors.Text,
				[scope.Children] = { scope:New("UIScale")({ Scale = pop }) },
			}),
		},
	})
end
