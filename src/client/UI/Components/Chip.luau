--!strict
--[[
	Chip : petite étiquette de statut (Common, PRINCIPALE · SLOT 1, EXPOSÉE…).
	Largeur automatique selon le texte.
]]

local Theme = require(script.Parent.Parent.Theme)

export type Props = {
	Text: string,
	Color: Color3,
	TextColor: Color3?,
}

return function(scope: any, props: Props): Instance
	return scope:New("TextLabel")({
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 22),
		BackgroundColor3 = props.Color,
		Text = props.Text,
		FontFace = Theme.Fonts.Body,
		TextSize = 14,
		TextColor3 = props.TextColor or Theme.Colors.Contour,
		[scope.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
			scope:New("UIStroke")({
				Color = Theme.Colors.Contour,
				Thickness = 3,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
		},
	})
end
