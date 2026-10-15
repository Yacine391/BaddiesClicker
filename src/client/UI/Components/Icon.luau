--!strict
--[[
	Icon : icône maison (assets/ui/icons). Image uploadée teintée par `Color` (icônes de trait blanches),
	ou, tant que l'ID manque, repli simple : carré arrondi au contour de la couleur + initiale. Jamais d'emoji.
]]

local Theme = require(script.Parent.Parent.Theme)

export type Props = {
	Name: string, -- clé de Theme.Icons (book, crew, style, settings, chevron, bolt, arm, ticket, door, lock, eye, crown)
	Size: any, -- UDim2 ou état
	Position: any?,
	AnchorPoint: any?,
	Color: any?, -- Color3 ou état ; nil = couleurs d'origine (arm, ticket)
	ZIndex: number?,
}

-- Repli lisible : initiale ou symbole simple par icône
local FALLBACK: { [string]: string } = {
	book = "B",
	crew = "C",
	style = "S",
	settings = "R",
	chevron = ">",
	bolt = "+",
	arm = "P",
	ticket = "T",
	door = "N",
	lock = "X",
	eye = "O",
	crown = "K",
}

return function(scope: any, props: Props): GuiObject
	local id = (Theme.Icons :: any)[props.Name] or ""
	if id ~= "" then
		return scope:New("ImageLabel")({
			Name = "Icon_" .. props.Name,
			BackgroundTransparency = 1,
			Size = props.Size,
			Position = props.Position or UDim2.new(),
			AnchorPoint = props.AnchorPoint or Vector2.zero,
			Image = id,
			ImageColor3 = props.Color or Color3.new(1, 1, 1),
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = props.ZIndex or 2,
		})
	end
	local color = props.Color or Theme.Colors.Text
	return scope:New("TextLabel")({
		Name = "Icon_" .. props.Name,
		BackgroundTransparency = 1,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Text = FALLBACK[props.Name] or "?",
		FontFace = Theme.Fonts.Heavy,
		TextColor3 = color,
		TextScaled = true,
		ZIndex = props.ZIndex or 2,
		[scope.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
			scope:New("UIStroke")({
				Color = color,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0.18, 0),
				PaddingBottom = UDim.new(0.18, 0),
				PaddingLeft = UDim.new(0.18, 0),
				PaddingRight = UDim.new(0.18, 0),
			}),
		},
	})
end
