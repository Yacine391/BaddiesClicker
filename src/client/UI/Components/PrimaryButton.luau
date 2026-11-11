--!strict
--[[
	PrimaryButton : le gros bouton du bas (ENTRAÎNER vert / ATTAQUER rouge), tuile simulateur 200 × 56.
	Icône éclair pleine, libellé FredokaOne contouré. S'écrase pendant l'appui (Motion.press, interruptible). Appui par InputBegan, relâchement suivi globalement par
	UserInputService.InputEnded, jamais par le survol du bouton (§21).
]]

local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Metrics = require(UI.Metrics)
local Icon = require(script.Parent.Icon)
local Tile = require(script.Parent.Tile)
local Motion = require(UI.Motion)
local peek = require(UI.Parent.Packages.Fusion).peek

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

-- ColorKey de HudModel → dégradé simulateur (Accent = ENTRAÎNER vert, Accent2 = ATTAQUER rouge)
local GRADIENT = {
	Accent = Theme.Gradients.Action,
	Accent2 = Theme.Gradients.Attack,
}

return function(scope: any, props: Props): Instance
	local height = Metrics.touch(scope, 56)
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
	local scale = scope:New("UIScale")({ Scale = 1 })
	table.insert(
		scope,
		scope:Observer(pressed):onChange(function()
			Motion.press(scale, peek(pressed))
		end)
	)
	local gradient = scope:Computed(function(use)
		return GRADIENT[use(props.ColorKey)] or GRADIENT.Accent
	end)

	local children: { any } = {
		scale,
		Tile(scope, {
			Name = "Tile",
			Gradient = gradient,
			Size = UDim2.fromScale(1, 1),
			Radius = 16,
			Transparency = scope:Computed(function(use)
				return if use(props.Enabled) then 0 else 0.45
			end),
			Children = {
				scope:New("Frame")({
					Name = "Content",
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 3,
					[scope.Children] = {
						scope:New("UIListLayout")({
							FillDirection = Enum.FillDirection.Horizontal,
							HorizontalAlignment = Enum.HorizontalAlignment.Center,
							VerticalAlignment = Enum.VerticalAlignment.Center,
							Padding = UDim.new(0, 12),
							SortOrder = Enum.SortOrder.LayoutOrder,
						}),
						Icon(scope, { Name = "power", Size = UDim2.fromOffset(34, 34), ZIndex = 3 }),
						scope:New("TextLabel")({
							Name = "Label",
							LayoutOrder = 1,
							BackgroundTransparency = 1,
							AutomaticSize = Enum.AutomaticSize.X,
							Size = UDim2.fromOffset(0, 34),
							Text = props.Label,
							FontFace = Theme.Fonts.Main,
							TextSize = 28,
							TextColor3 = Theme.Colors.Text,
							ZIndex = 3,
							[scope.Children] = {
								scope:New("UIStroke")({
									Color = Theme.Colors.Ink,
									Thickness = Theme.Stroke.Text,
									ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
								}),
							},
						}),
					},
				}),
			},
		}),
	}
	-- hauteur ≥ 48 px réels même en très petite échelle (§21)
	local size = scope:Computed(function(use)
		return UDim2.fromOffset(200, use(height))
	end)

	local button = scope:New("TextButton")({
		Name = "PrimaryButton",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		Size = size,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Active = props.Enabled,
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
	return button
end
