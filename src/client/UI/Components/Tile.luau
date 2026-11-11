--!strict
--[[
	Tile : forme commune du style simulateur (tuiles du menu, bouton principal, onglets).
	Dégradé vertical de la fonction, coins 12, contour Ink 3 px, ombre Ink décalée de 4 px vers le bas,
	reflet blanc sur le tiers haut. `Gradient` et `StrokeColor` acceptent une valeur ou un état Fusion.
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)

export type Gradient = { top: Color3, bottom: Color3 }

export type Props = {
	Gradient: any, -- Gradient ou état
	Size: any,
	Children: { any }?,
	Name: string?,
	Radius: number?,
	StrokeColor: any?, -- Color3 ou état ; défaut Ink
	StrokeThickness: any?, -- number ou état ; défaut Theme.Stroke.Frame
	Transparency: any?, -- number ou état (désactivé) ; défaut 0
	Position: any?,
	AnchorPoint: any?,
	ZIndex: number?,
}

return function(scope: any, props: Props): Frame
	local radius = UDim.new(0, props.Radius or 12)
	local z = props.ZIndex or 1
	local color = scope:Computed(function(use)
		local g = use(props.Gradient)
		return ColorSequence.new(g.top, g.bottom)
	end)
	local transparency = props.Transparency or 0
	local body: { any } = {
		scope:New("UICorner")({ CornerRadius = radius }),
		scope:New("UIGradient")({ Rotation = 90, Color = color }),
		scope:New("UIStroke")({
			Color = props.StrokeColor or Theme.Colors.Ink,
			Thickness = props.StrokeThickness or Theme.Stroke.Frame,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = transparency,
		}),
		scope:New("Frame")({
			Name = "Shine",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.75,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(4, 3),
			Size = UDim2.new(1, -8, 0.34, 0),
			ZIndex = z + 1,
			[scope.Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, (props.Radius or 12) - 3) }) },
		}),
	}
	for _, child in props.Children or {} do
		table.insert(body, child)
	end
	return scope:New("Frame")({
		Name = props.Name or "Tile",
		BackgroundTransparency = 1,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = z,
		[scope.Children] = {
			scope:New("Frame")({
				Name = "Shadow",
				BackgroundColor3 = Theme.Colors.Ink,
				BackgroundTransparency = scope:Computed(function(use)
					return 0.15 + 0.85 * (use(transparency) :: number)
				end),
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 4),
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
				[scope.Children] = { scope:New("UICorner")({ CornerRadius = radius }) },
			}),
			scope:New("Frame")({
				Name = "Body",
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = transparency,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
				[scope.Children] = body,
			}),
		},
	}) :: Frame
end
