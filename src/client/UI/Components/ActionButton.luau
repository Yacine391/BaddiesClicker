--!strict
--[[
	ActionButton : le gros bouton d'action (ENTRAÎNER / ATTAQUER).
	S'écrase pendant l'appui puis rebondit (spring sur UIScale). Libellé et couleur réactifs.
]]

local UserInputService = game:GetService("UserInputService")

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
	OnPress: ((InputObject) -> ())?,
	OnRelease: (() -> ())?,
}

return function(scope: any, props: Props): Instance
	local pressed = scope:Value(false)
	local pressedInput: InputObject? = nil
	table.insert(
		scope,
		UserInputService.InputEnded:Connect(function(input)
			local current = pressedInput
			if current == nil then
				return
			end
			local mouse = Enum.UserInputType.MouseButton1
			if input == current or (input.UserInputType == mouse and current.UserInputType == mouse) then
				pressedInput = nil
				pressed:set(false)
				if props.OnRelease then
					props.OnRelease()
				end
			end
		end)
	)
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
		-- Appui : souris ou doigt. Le relâchement est suivi globalement (UserInputService),
		-- jamais par le survol du bouton (§21).
		[scope.OnEvent("InputBegan")] = function(input: InputObject)
			local kind = input.UserInputType
			if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
				return
			end
			pressedInput = input
			pressed:set(true)
			if props.OnPress then
				props.OnPress(input)
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
