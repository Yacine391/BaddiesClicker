--!strict
--[[
	Text : texte du style mix A — Roboto Condensed, sans ombre ; la lisibilité vient du fond des panneaux.
	`Stroke = true` ajoute un contour fin (2 px, Ink) pour les chiffres posés hors panneau (« +1 »).
	Accepte encore les anciennes props V3 (Font, TextColor, StrokeSize) pendant la transition.
]]

local Theme = require(script.Parent.Theme)

local Text = {}

export type LabelProps = {
	Text: any,
	Size: any,
	Position: any?,
	AnchorPoint: any?,
	Weight: ("Bold" | "ExtraBold" | "Heavy")?,
	Color: any?,
	XAlignment: Enum.TextXAlignment?,
	YAlignment: Enum.TextYAlignment?,
	Stroke: boolean?,
	ZIndex: number?,
	Name: string?,
	Visible: any?,
	LayoutOrder: number?,
	RichText: boolean?,
	-- transition (ancien style V3)
	Font: Font?,
	TextColor: any?,
	StrokeSize: number?,
}

function Text.label(scope: any, props: LabelProps): TextLabel
	local children = {}
	if props.Stroke or props.StrokeSize then
		table.insert(
			children,
			scope:New("UIStroke")({
				Color = Theme.Colors.Ink,
				Thickness = if props.Stroke then Theme.Stroke.Text else math.min(props.StrokeSize or 2, 2),
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			})
		)
	end
	return scope:New("TextLabel")({
		Name = props.Name or "Label",
		BackgroundTransparency = 1,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Text = props.Text,
		FontFace = props.Font or Theme.Fonts[props.Weight or "ExtraBold"],
		TextColor3 = props.Color or props.TextColor or Theme.Colors.Text,
		TextScaled = true,
		TextXAlignment = props.XAlignment or Enum.TextXAlignment.Center,
		TextYAlignment = props.YAlignment or Enum.TextYAlignment.Center,
		ZIndex = props.ZIndex or 1,
		Visible = if props.Visible == nil then true else props.Visible,
		LayoutOrder = props.LayoutOrder or 0,
		RichText = props.RichText == true,
		[scope.Children] = children,
	}) :: TextLabel
end

-- Transition (ancien style V3) : icône image ou initiale de repli, jamais d'emoji
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
		FontFace = Theme.Fonts.Heavy,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		ZIndex = 3,
	})
end

return Text
