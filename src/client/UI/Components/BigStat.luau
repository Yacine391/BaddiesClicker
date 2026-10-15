--!strict
--[[
	BigStat : icône + chiffre géant sans panneau (puissance, production…).
	À chaque changement de `Pulse`, le chiffre « pop » (spring 1 → 1,2 → 1).
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Text = require(UI.Text)

export type Props = {
	Icon: { image: string, fallback: string },
	Text: any, -- état Fusion de string
	Pulse: any?, -- état Fusion de number
	Height: number?,
	Width: number?,
	Font: Font?,
	Position: any?,
}

return function(scope: any, props: Props): Instance
	local height = props.Height or 48
	local goal = scope:Value(1)
	if props.Pulse ~= nil then
		scope:Observer(props.Pulse):onChange(function()
			goal:set(1.2)
			task.delay(0.08, function()
				goal:set(1)
			end)
		end)
	end

	return scope:New("Frame")({
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(props.Width or 320, height),
		Position = props.Position or UDim2.new(),
		[scope.Children] = {
			Text.icon(scope, props.Icon, UDim2.fromOffset(height, height)),
			scope:New("Frame")({
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -(height + 8), 1, 0),
				Position = UDim2.fromOffset(height + 8, 0),
				[scope.Children] = {
					scope:New("UIScale")({ Scale = scope:Spring(goal, 40, 0.45) }),
					Text.label(scope, {
						Text = props.Text,
						Font = props.Font or Theme.Fonts.Display,
						Size = UDim2.fromScale(1, 1),
						XAlignment = Enum.TextXAlignment.Left,
					}),
				},
			}),
		},
	})
end
