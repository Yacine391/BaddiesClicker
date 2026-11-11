--!strict
--[[
	Panel : panneau du style simulateur — fond Panel plein, coins 8, contour Ink 3 px.
	`Line` / `Glow` donnent la couleur du contour (plus de halo : rendu net des simulateurs de référence).
	`GlowVisible` est conservé pour compatibilité et ignoré.
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
	-- style simulateur : pas de halo ; `Glow` (ou `Line`) colore seulement le contour
	local lineColor = props.Line or props.Glow or Theme.Colors.Ink
	local children: { any } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Panel) }),
		scope:New("UIStroke")({
			Color = lineColor,
			Transparency = props.LineTransparency or 0,
			Thickness = if props.Line or props.Glow then 3 else Theme.Stroke.Frame,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	}
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
