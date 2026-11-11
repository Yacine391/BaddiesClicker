--!strict
--[[
	ActionButton : bouton d'action des fenêtres au style simulateur (RELANCER, TOUR GRATUIT, PORTER…).
	Case Tile au dégradé de `Color` (plus sombre en bas), libellé blanc FredokaOne contouré.
	Désactivé : case à demi transparente, clics ignorés. Hauteur ≥ 48 px réels (Metrics.touch).
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Text = require(UI.Text)
local Tile = require(script.Parent.Tile)
local peek = require(UI.Parent.Packages.Fusion).peek

export type Props = {
	Text: any, -- string ou état
	Color: any?, -- Color3 ou état ; défaut vert action
	Enabled: any?, -- boolean ou état ; défaut true
	Size: any,
	OnClick: () -> (),
	Name: string?,
	LayoutOrder: number?,
	Visible: any?,
	TextSize: number?,
	Position: any?,
	AnchorPoint: any?,
}

return function(scope: any, props: Props): Instance
	local enabled = props.Enabled
	if enabled == nil then
		enabled = true
	end
	local gradient = scope:Computed(function(use)
		local c: Color3 = use(props.Color) or Theme.Colors.Accent
		return { top = c, bottom = c:Lerp(Color3.new(0, 0, 0), 0.22) }
	end)
	return scope:New("TextButton")({
		Name = props.Name or "ActionButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Visible = if props.Visible == nil then true else props.Visible,
		Active = enabled,
		Size = props.Size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		[scope.OnEvent("Activated")] = function()
			if peek(enabled) ~= false then
				props.OnClick()
			end
		end,
		[scope.Children] = {
			Tile(scope, {
				Gradient = gradient,
				Size = UDim2.fromScale(1, 1),
				Transparency = scope:Computed(function(use)
					return if use(enabled) == false then 0.55 else 0
				end),
				Children = {
					Text.label(scope, {
						Name = "Label",
						Text = props.Text,
						Weight = "Heavy",
						Stroke = true,
						StrokeThickness = Theme.Stroke.List,
						Size = UDim2.new(1, -14, 0, props.TextSize or 18),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						ZIndex = 3,
					}),
				},
			}),
		},
	})
end
