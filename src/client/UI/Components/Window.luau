--!strict
--[[
	Window : fenêtre du style V3 (Book, Style, Crew, Réglages).
	Bord lumineux à dégradé tournant, titre en pilule qui déborde, croix rouge, contenu défilant.
	Le fond plein écran capte les clics (rien ne traverse vers le jeu, §21) ; Échap ferme.
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Text = require(UI.Text)
local Metrics = require(UI.Metrics)

export type Props = {
	Title: string,
	Icon: { image: string, fallback: string },
	Content: { Instance },
	OnClose: () -> (),
	Size: UDim2?,
}

return function(scope: any, props: Props): Instance
	local rotation = scope:Value(0)
	local closeSide = Metrics.touch(scope, Theme.MinTouch)
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			rotation:set((scope.peek(rotation) + dt * 40) % 360)
		end)
	)
	table.insert(
		scope,
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode.Escape then
				props.OnClose()
			end
		end)
	)

	local pillChildren: { any } = Theme.bevel(scope, Theme.Colors.Violet, 16)
	table.insert(
		pillChildren,
		Text.icon(scope, props.Icon, UDim2.fromOffset(40, 40), UDim2.fromOffset(10, 4))
	)
	table.insert(
		pillChildren,
		Text.label(scope, {
			Text = props.Title,
			TextColor = Color3.fromHex("#FFD84A"),
			Size = UDim2.new(1, -64, 1, -10),
			Position = UDim2.fromOffset(56, 5),
			XAlignment = Enum.TextXAlignment.Left,
			StrokeSize = 4,
		})
	)

	return scope:New("TextButton")({
		Name = "WindowBackdrop",
		Text = "",
		AutoButtonColor = false,
		Active = true,
		BackgroundColor3 = Color3.fromHex("#140E28"),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		[scope.Children] = {
			scope:New("Frame")({
				Name = "Border",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0.5, 44),
				Size = props.Size or UDim2.fromOffset(760, 500),
				BackgroundColor3 = Color3.new(1, 1, 1),
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 22) }),
					scope:New("UIGradient")({
						Rotation = rotation,
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromHex("#FF5FD2")),
							ColorSequenceKeypoint.new(0.4, Color3.fromHex("#A86BFF")),
							ColorSequenceKeypoint.new(1, Color3.fromHex("#5FE2FF")),
						}),
					}),
					scope:New("Frame")({
						Name = "Inner",
						Position = UDim2.fromOffset(6, 6),
						Size = UDim2.new(1, -12, 1, -12),
						BackgroundColor3 = Color3.fromHex("#2B1F63"),
						ClipsDescendants = true,
						[scope.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 17) }),
							scope:New("UIStroke")({
								Color = Theme.Colors.Contour,
								Thickness = Theme.Stroke.Frame,
							}),
							scope:New("ScrollingFrame")({
								Name = "Content",
								BackgroundTransparency = 1,
								Position = UDim2.fromOffset(16, 44),
								Size = UDim2.new(1, -32, 1, -56),
								CanvasSize = UDim2.new(),
								AutomaticCanvasSize = Enum.AutomaticSize.Y,
								ScrollBarThickness = 6,
								BorderSizePixel = 0,
								[scope.Children] = {
									scope:New("UIListLayout")({
										Padding = UDim.new(0, 10),
										SortOrder = Enum.SortOrder.LayoutOrder,
									}),
									scope:New("UIPadding")({
										PaddingTop = UDim.new(0, 6),
										PaddingLeft = UDim.new(0, 4),
										PaddingRight = UDim.new(0, 10),
									}),
									props.Content,
								},
							}),
						},
					}),
					scope:New("Frame")({
						Name = "TitlePill",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, -26),
						Size = UDim2.fromOffset(240, 52),
						BackgroundColor3 = Color3.new(1, 1, 1),
						ZIndex = 12,
						[scope.Children] = pillChildren,
					}),
					scope:New("TextButton")({
						Name = "Close",
						Text = "X",
						FontFace = Theme.Fonts.Display,
						TextSize = 26,
						TextColor3 = Theme.Colors.Blanc,
						AutoButtonColor = false,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(1, -4, 0, 4),
						Size = scope:Computed(function(use)
							local side = use(closeSide)
							return UDim2.fromOffset(side, side)
						end),
						BackgroundColor3 = Theme.Colors.Fermer,
						ZIndex = 12,
						[scope.OnEvent("Activated")] = props.OnClose,
						[scope.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
							scope:New("UIStroke")({
								Color = Theme.Colors.Contour,
								Thickness = Theme.Stroke.Frame,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							}),
						},
					}),
				},
			}),
		},
	})
end
