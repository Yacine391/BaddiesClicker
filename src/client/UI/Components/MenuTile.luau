--!strict
--[[
	MenuTile : tuile carrée du HUD (Book, Crew, Style, Réglages).
	L'icône dépasse du haut de la tuile, le libellé contouré déborde en bas, badge « NEW! » facultatif.
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Text = require(UI.Text)

export type Props = {
	Name: string,
	Icon: { image: string, fallback: string },
	Color: Color3,
	Badge: any?, -- string ou état Fusion de string ; "" ou nil = pas de badge
	Position: any?,
	OnClick: () -> (),
}

return function(scope: any, props: Props): Instance
	local children: { any } = Theme.bevel(scope, props.Color, 14)
	table.insert(
		children,
		Text.icon(scope, props.Icon, UDim2.fromOffset(52, 52), UDim2.new(0.5, -26, 0, -18))
	)
	table.insert(
		children,
		Text.label(scope, {
			Text = props.Name,
			Font = Theme.Fonts.Body,
			Size = UDim2.new(1, 24, 0, 20),
			Position = UDim2.new(0.5, 0, 1, -8),
			AnchorPoint = Vector2.new(0.5, 0),
			ZIndex = 4,
		})
	)
	if props.Badge ~= nil then
		table.insert(
			children,
			scope:New("Frame")({
				BackgroundColor3 = Color3.fromHex("#FF3B5C"),
				Size = UDim2.fromOffset(44, 20),
				Position = UDim2.fromOffset(-12, -12),
				Rotation = -12,
				ZIndex = 5,
				Visible = scope:Computed(function(use)
					local b = use(props.Badge)
					return b ~= nil and b ~= ""
				end),
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 6) }),
					scope:New("UIStroke")({ Color = Theme.Colors.Contour, Thickness = 3 }),
					Text.label(scope, {
						Text = props.Badge,
						Font = Theme.Fonts.Body,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 5,
					}),
				},
			})
		)
	end

	return scope:New("TextButton")({
		Name = props.Name,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(74, 70),
		Position = props.Position or UDim2.new(),
		[scope.OnEvent("Activated")] = props.OnClick,
		[scope.Children] = children,
	})
end
