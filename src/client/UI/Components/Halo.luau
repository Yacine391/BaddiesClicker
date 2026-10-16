--!strict
--[[
	Halo : image 9-slice Theme.Glow affichée DERRIÈRE un élément (Panel, Window, PrimaryButton).

	Avec ZIndexBehavior.Sibling, un enfant s'affiche toujours au-dessus de son parent, quel que soit
	son ZIndex : un halo enfant du panneau le recouvrirait. Halo.host renvoie donc un cadre transparent
	qui porte le placement de l'élément (taille, position, ancre, ordre, visibilité) et contient deux
	frères : le halo (ZIndex 1) puis l'élément remis à 100 % du cadre (ZIndex 2).
	Tant que Theme.Glow est vide, les composants n'utilisent pas ce module (contour plus épais à la place).
]]

local Theme = require(script.Parent.Parent.Theme)

export type Placement = {
	Name: string?,
	Size: any, -- UDim2 ou état de UDim2
	Position: any?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	ZIndex: number?,
	Visible: any?,
	AutomaticSize: Enum.AutomaticSize?,
}

export type Look = {
	Color: any, -- Color3 ou état de Color3
	Transparency: number,
	Margin: number, -- débord total en px (24 = 12 de chaque côté)
	Visible: any?, -- état de boolean (défaut : toujours)
}

local Halo = {}

function Halo.enabled(): boolean
	return Theme.Glow ~= ""
end

-- Placement à donner à l'élément quand il est porté par Halo.host
Halo.FILL = table.freeze({
	Size = UDim2.fromScale(1, 1),
	Position = UDim2.new(),
	AnchorPoint = Vector2.zero,
	ZIndex = 2,
})

function Halo.host(scope: any, placement: Placement, look: Look, element: Instance): Frame
	return scope:New("Frame")({
		Name = placement.Name or "HaloHost",
		BackgroundTransparency = 1,
		Size = placement.Size,
		Position = placement.Position or UDim2.new(),
		AnchorPoint = placement.AnchorPoint or Vector2.zero,
		LayoutOrder = placement.LayoutOrder or 0,
		ZIndex = placement.ZIndex or 1,
		Visible = if placement.Visible == nil then true else placement.Visible,
		AutomaticSize = placement.AutomaticSize or Enum.AutomaticSize.None,
		[scope.Children] = {
			scope:New("ImageLabel")({
				Name = "Glow",
				BackgroundTransparency = 1,
				Image = Theme.Glow,
				ImageColor3 = look.Color,
				ImageTransparency = look.Transparency,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Theme.GlowSlice,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, look.Margin, 1, look.Margin),
				ZIndex = 1,
				Visible = if look.Visible == nil then true else look.Visible,
			}),
			element,
		},
	}) :: Frame
end

return Halo
