--!strict
--[[
	ListRow : ligne colorée d'une fenêtre (fiche du Book, look du Style, compagnon du Crew).
	Portrait rond, nom contouré, chips de statut, description facultative, bouton d'action facultatif.
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Text = require(UI.Text)

export type Props = {
	Color: Color3,
	Portrait: string, -- emoji ou initiale tant qu'il n'y a pas de rendu
	Name: string,
	Chips: { Instance },
	Description: string?,
	ActionLabel: string?,
	OnAction: (() -> ())?,
	LayoutOrder: number?,
	Dimmed: boolean?,
}

return function(scope: any, props: Props): Instance
	local children: { any } = Theme.bevel(scope, props.Color, 14)
	table.insert(
		children,
		scope:New("TextLabel")({
			Name = "Portrait",
			Position = UDim2.fromOffset(10, 9),
			Size = UDim2.fromOffset(54, 54),
			BackgroundColor3 = Color3.fromHex("#3A2617"),
			Text = props.Portrait,
			TextScaled = true,
			FontFace = Theme.Fonts.Display,
			TextColor3 = Theme.Colors.Blanc,
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				scope:New("UIStroke")({
					Color = Theme.Colors.Contour,
					Thickness = Theme.Stroke.Frame,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			},
		})
	)
	local textWidth = if props.ActionLabel then -230 else -90
	table.insert(
		children,
		Text.label(scope, {
			Text = props.Name,
			Size = UDim2.new(1, textWidth, 0, 28),
			Position = UDim2.fromOffset(76, 6),
			XAlignment = Enum.TextXAlignment.Left,
		})
	)
	local chipChildren: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}
	for _, chip in props.Chips do
		table.insert(chipChildren, chip)
	end
	table.insert(
		children,
		scope:New("Frame")({
			Name = "Chips",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(76, 38),
			Size = UDim2.new(1, textWidth, 0, 26),
			[scope.Children] = chipChildren,
		})
	)
	if props.Description then
		table.insert(
			children,
			Text.label(scope, {
				Text = props.Description,
				Font = Theme.Fonts.Body,
				Size = UDim2.new(1, textWidth, 0, 18),
				Position = UDim2.fromOffset(76, 68),
				XAlignment = Enum.TextXAlignment.Left,
				StrokeSize = 2,
			})
		)
	end
	if props.ActionLabel then
		local buttonChildren: { any } = Theme.bevel(scope, Theme.Colors.Action, 12)
		table.insert(
			buttonChildren,
			Text.label(scope, {
				Text = props.ActionLabel,
				Font = Theme.Fonts.Body,
				Size = UDim2.new(1, -16, 1, -12),
				Position = UDim2.fromOffset(8, 6),
			})
		)
		table.insert(
			children,
			scope:New("TextButton")({
				Name = "Action",
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = Color3.new(1, 1, 1),
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.fromOffset(130, Theme.MinTouch),
				[scope.OnEvent("Activated")] = function()
					if props.OnAction then
						props.OnAction()
					end
				end,
				[scope.Children] = buttonChildren,
			})
		)
	end

	return scope:New("Frame")({
		Name = props.Name,
		LayoutOrder = props.LayoutOrder or 0,
		Size = UDim2.new(1, 0, 0, if props.Description then 94 else 72),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = if props.Dimmed then 0.35 else 0,
		[scope.Children] = children,
	})
end
