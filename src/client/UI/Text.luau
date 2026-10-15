--!strict
--[[
	Text : texte « Roblox » du style V3 — blanc, gros contour sombre, ombre portée.
	L'ombre est une copie décalée de 3 px vers le bas, sous le texte principal.
]]

local Theme = require(script.Parent.Theme)

local Text = {}

export type LabelProps = {
	Text: any,
	Size: any,
	Position: any?,
	AnchorPoint: any?,
	Font: Font?,
	TextColor: any?,
	StrokeSize: number?,
	XAlignment: Enum.TextXAlignment?,
	ZIndex: number?,
}

local function layer(scope: any, props: LabelProps, offsetY: number, color: any): Instance
	return scope:New("TextLabel")({
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(0, offsetY),
		Text = props.Text,
		FontFace = props.Font or Theme.Fonts.Display,
		TextColor3 = color,
		TextScaled = true,
		TextXAlignment = props.XAlignment or Enum.TextXAlignment.Center,
		ZIndex = (props.ZIndex or 1) + (if offsetY == 0 then 1 else 0),
		[scope.Children] = {
			scope:New("UIStroke")({
				Color = Theme.Colors.Contour,
				Thickness = props.StrokeSize or Theme.Stroke.Text,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}),
		},
	})
end

function Text.label(scope: any, props: LabelProps): Frame
	return scope:New("Frame")({
		BackgroundTransparency = 1,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		[scope.Children] = {
			layer(scope, props, 3, Theme.Colors.Contour),
			layer(scope, props, 0, props.TextColor or Theme.Colors.Blanc),
		},
	}) :: Frame
end

-- Icône : image du rendu Blender si elle existe, sinon emoji de secours
function Text.icon(scope: any, icon: { image: string, fallback: string }, size: any, position: any?): Instance
	if icon.image ~= "" then
		return scope:New("ImageLabel")({
			BackgroundTransparency = 1,
			Size = size,
			Position = position or UDim2.new(),
			Image = icon.image,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		})
	end
	return scope:New("TextLabel")({
		BackgroundTransparency = 1,
		Size = size,
		Position = position or UDim2.new(),
		Text = icon.fallback,
		TextColor3 = Color3.new(1, 1, 1), -- sinon les emojis sont teintés par la couleur noire par défaut
		TextScaled = true,
		ZIndex = 3,
	})
end

return Text
