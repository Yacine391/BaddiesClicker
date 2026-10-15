--!strict
--[[
	PrimaryButton : le gros bouton du bas (ENTRAÎNER cyan / ATTAQUER rose), 300 × 76.
	Contour 3 px dégradé Accent2 → Accent, remplissage dégradé clair → couleur, icône bolt et libellé Ink.
	S'écrase pendant l'appui (spring). Appui par InputBegan, relâchement suivi globalement par
	UserInputService.InputEnded, jamais par le survol du bouton (§21).
]]

local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Icon = require(script.Parent.Icon)

export type Props = {
	Label: any, -- état de string
	ColorKey: any, -- état de "Accent" | "Accent2"
	Enabled: any, -- état de boolean
	Position: any?,
	AnchorPoint: Vector2?,
	OnActivated: (() -> ())?,
	OnPress: ((InputObject) -> ())?,
	OnRelease: (() -> ())?,
}

local FILL = {
	Accent = { Theme.Colors.AccentLight, Theme.Colors.Accent },
	Accent2 = { Theme.Colors.Accent2Light, Theme.Colors.Accent2 },
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
			return if use(pressed) then 0.95 else 1
		end),
		45,
		0.5
	)
	local fill = scope:Computed(function(use)
		local pair = FILL[use(props.ColorKey)] or FILL.Accent
		return ColorSequence.new(pair[1], pair[2])
	end)
	local base = scope:Computed(function(use)
		return (FILL[use(props.ColorKey)] or FILL.Accent)[2]
	end)

	local children: { any } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Button) }),
		scope:New("UIGradient")({ Color = ColorSequence.new(Theme.Colors.Accent2, Theme.Colors.Accent) }),
		scope:New("UIScale")({ Scale = scale }),
		scope:New("Frame")({
			Name = "Fill",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -6, 1, -6),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Button - 3) }),
				scope:New("UIGradient")({ Rotation = 90, Color = fill }),
				scope:New("Frame")({
					Name = "Content",
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(1, 1),
					[scope.Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0, 14),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						Icon(
							scope,
							{ Name = "bolt", Size = UDim2.fromOffset(40, 40), Color = Theme.Colors.Ink }
						),
						scope:New("TextLabel")({
							Name = "Label",
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.fromOffset(0, 44),
							Text = props.Label,
							FontFace = Theme.Fonts.Heavy,
							TextSize = 38,
							TextColor3 = Theme.Colors.Ink,
						}),
					},
				}),
			},
		}),
	}
	if Theme.Glow ~= "" then
		table.insert(
			children,
			scope:New("ImageLabel")({
				Name = "Glow",
				BackgroundTransparency = 1,
				Image = Theme.Glow,
				ImageColor3 = base,
				ImageTransparency = 0.45,
				ScaleType = Enum.ScaleType.Slice,
				SliceCenter = Theme.GlowSlice,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 40, 1, 40),
				ZIndex = 0,
			})
		)
	end

	return scope:New("TextButton")({
		Name = "PrimaryButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromOffset(300, 76),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Active = props.Enabled,
		BackgroundTransparency = scope:Computed(function(use)
			return if use(props.Enabled) then 0 else 0.5
		end),
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
