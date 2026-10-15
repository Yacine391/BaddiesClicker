--!strict
--[[
	Panel : panneau du style mix A — fond nuit translucide, coins 10 px, contour 2 px.
	`Glow` ajoute un halo coloré derrière (image 9-slice Theme.Glow) ; tant que l'image n'est pas
	uploadée, le halo est remplacé par un contour plus épais de la même couleur.
	Roblox n'a pas d'ombre portée : le halo est une image.
]]

local Theme = require(script.Parent.Parent.Theme)

export type Props = {
	Size: any,
	Position: any?,
	AnchorPoint: Vector2?,
	Glow: any?, -- Color3 ou état de Color3 (nil = pas de halo)
	Line: any?, -- couleur du contour (défaut PanelLine), Color3 ou état
	LineTransparency: any?, -- nombre ou état (défaut : 0 si Line/Glow, sinon PanelLine)
	GlowVisible: any?, -- état de boolean : halo allumé/éteint (défaut : toujours si Glow)
	Children: { any }?,
	Name: string?,
	ZIndex: number?,
	LayoutOrder: number?,
	Visible: any?,
	AutomaticSize: Enum.AutomaticSize?,
}

return function(scope: any, props: Props): Frame
	local hasGlowImage = Theme.Glow ~= ""
	local lineColor = props.Line or props.Glow or Theme.Colors.PanelLine
	local lineTransparency = props.LineTransparency
		or (if props.Line or props.Glow then 0 else Theme.Transparency.PanelLine)
	local glowOn = props.GlowVisible
	local thickness: any = 2
	if props.Glow and not hasGlowImage then
		thickness = if glowOn
			then scope:Computed(function(use)
				return if use(glowOn) then 3 else 2
			end)
			else 3
	end

	local children: { any } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Panel) }),
		scope:New("UIStroke")({
			Color = lineColor,
			Transparency = lineTransparency,
			Thickness = thickness,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	}
	if props.Glow and hasGlowImage then
		table.insert(
			children,
			scope:New("ImageLabel")({
				Name = "Glow",
				BackgroundTransparency = 1,
				Image = Theme.Glow,
				ImageColor3 = props.Glow,
				ImageTransparency = 0.4,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Theme.GlowSlice,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 24, 1, 24),
				ZIndex = (props.ZIndex or 1) - 1,
				Visible = if glowOn then glowOn else true,
			})
		)
	end
	for _, child in props.Children or {} do
		table.insert(children, child)
	end

	return scope:New("Frame")({
		Name = props.Name or "Panel",
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = Theme.Transparency.Panel,
		ZIndex = props.ZIndex or 1,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = if props.Visible == nil then true else props.Visible,
		AutomaticSize = props.AutomaticSize or Enum.AutomaticSize.None,
		[scope.Children] = children,
	}) :: Frame
end
