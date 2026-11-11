--!strict
--[[
	Chip : petite étiquette de statut (Common, PRINCIPALE · SLOT 1, ÉQUIPÉ…), style simulateur :
	fond plein de la couleur, texte Ink FredokaOne 12, coins 4. Largeur automatique selon le texte.
]]

local Theme = require(script.Parent.Parent.Theme)

export type Props = {
	Text: any, -- string ou état
	Color: any, -- Color3 ou état
	TextColor: Color3?,
	LayoutOrder: number?,
}

return function(scope: any, props: Props): Instance
	return scope:New("TextLabel")({
		Name = "Chip",
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 18),
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = props.Color,
		Text = props.Text,
		FontFace = Theme.Fonts.Main,
		TextSize = 12,
		TextColor3 = props.TextColor or Theme.Colors.Ink,
		[scope.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }),
		},
	})
end
