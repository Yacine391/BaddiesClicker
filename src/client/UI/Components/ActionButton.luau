--!strict
--[[
	ActionButton : le gros bouton d'action (ENTRAÎNER / ATTAQUER).
	S'écrase pendant l'appui puis rebondit (spring sur UIScale). Libellé et couleur réactifs.
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Text = require(UI.Text)

export type Props = {
	Label: any, -- état de string
	Sub: any, -- string ou état
	Icon: { image: string, fallback: string },
	Color: any, -- état de Color3
	Enabled: any, -- état de boolean
	Position: any?,
	AnchorPoint: Vector2?,
	OnActivated: (() -> ())?,
	OnPress: (() -> ())?,
	OnRelease: (() -> ())?,
}

return function(scope: any, props: Props): Instance
	local pressed = scope:Value(false)
	local scale = scope:Spring(
		scope:Computed(function(use)
			return if use(pressed) then 0.9 else 1
		end),
		45,
		0.5
	)

	local children: { any } = Theme.bevel(scope, props.Color, 20)
	table.insert(children, scope:New("UIScale")({ Scale = scale }))
	table.insert(children, Text.icon(scope, props.Icon, UDim2.fromOffset(56, 56), UDim2.new(0, 14, 0.5, -28)))
	table.insert(
		children,
		Text.label(scope, {
			Text = props.Label,
			Size = UDim2.new(1, -86, 0, 40),
			Position = UDim2.fromOffset(76, 14),
			XAlignment = Enum.TextXAlignment.Left,
			StrokeSize = 4,
		})
	)
	table.insert(
		children,
		Text.label(scope, {
			Text = props.Sub,
			Font = Theme.Fonts.Body,
			Size = UDim2.new(1, -86, 0, 22),
			Position = UDim2.fromOffset(76, 56),
			XAlignment = Enum.TextXAlignment.Left,
		})
	)

	return scope:New("TextButton")({
		Name = "ActionButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(240, 96),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Active = props.Enabled,
		BackgroundTransparency = scope:Computed(function(use)
			return if use(props.Enabled) then 0 else 0.4
		end),
		[scope.OnEvent("MouseButton1Down")] = function()
			pressed:set(true)
			if props.OnPress then
				props.OnPress()
			end
		end,
		[scope.OnEvent("MouseButton1Up")] = function()
			pressed:set(false)
			if props.OnRelease then
				props.OnRelease()
			end
		end,
		[scope.OnEvent("MouseLeave")] = function()
			if scope.peek(pressed) then
				pressed:set(false)
				if props.OnRelease then
					props.OnRelease()
				end
			end
		end,
		[scope.OnEvent("Activated")] = function()
			if props.OnActivated then
				props.OnActivated()
			end
		end,
		[scope.Children] = children,
	})
end
