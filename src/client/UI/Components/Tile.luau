--!strict
--[[
	Tile : forme commune du style simulateur (tuiles du menu, bouton principal, onglets).
	Dégradé vertical de la fonction (haut éclairci), coins 6, contour Ink 2 px et liseré clair intérieur :
	rendu net des simulateurs de référence, sans ombre portée ni bande de reflet. `Gradient` et `StrokeColor` acceptent une valeur ou un état Fusion.
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
	local r = props.Radius or 6
	local z = props.ZIndex or 1
	-- dégradé à trois arrêts : haut éclairci, milieu à la couleur, bas plus sombre
	local color = scope:Computed(function(use)
		local g = use(props.Gradient)
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, g.top:Lerp(Color3.new(1, 1, 1), 0.18)),
			ColorSequenceKeypoint.new(0.45, g.top),
			ColorSequenceKeypoint.new(1, g.bottom),
		})
	end)
	local transparency = props.Transparency or 0
	local body: { any } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, r) }),
		scope:New("UIGradient")({ Rotation = 90, Color = color }),
		scope:New("UIStroke")({
			Color = props.StrokeColor or Theme.Colors.Ink,
			Thickness = props.StrokeThickness or 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			Transparency = transparency,
		}),
		-- liseré clair intérieur (effet biseau des simulateurs de référence)
		scope:New("Frame")({
			Name = "Rim",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(2, 2),
			Size = UDim2.new(1, -4, 1, -4),
			ZIndex = z,
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, math.max(r - 2, 0)) }),
				scope:New("UIStroke")({
					Color = Color3.new(1, 1, 1),
					Thickness = 1.5,
					Transparency = scope:Computed(function(use)
						return 0.55 + 0.45 * (use(transparency) :: number)
					end),
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			},
		}),
	}
	for _, child in props.Children or {} do
		table.insert(body, child)
	end
	return scope:New("Frame")({
		Name = props.Name or "Tile",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = z,
		[scope.Children] = body,
	}) :: Frame
end
