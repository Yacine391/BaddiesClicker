--!strict
--[[
	ListRow : ligne d'une fenêtre (compagnon du Crew, réglage, look…), style mix A.
	Panneau à contour PanelLine (Accent si `Selected`), portrait carré arrondi 54, nom ExtraBold 20,
	puces, description facultative ; à droite soit un mini bouton Accent (`ActionLabel`), soit un
	interrupteur (`Toggle`). `Dimmed` = ligne atténuée (fond à 45 % de transparence, texte TextDim).
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Text = require(UI.Text)
local Metrics = require(UI.Metrics)

export type Props = {
	Portrait: string, -- initiale tant qu'il n'y a pas de rendu
	PortraitColor: Color3?,
	Name: string,
	Chips: { Instance },
	Description: string?,
	ActionLabel: string?,
	OnAction: (() -> ())?,
	Toggle: boolean?, -- nil = pas d'interrupteur
	Selected: boolean?,
	LayoutOrder: number?,
	Dimmed: boolean?,
}

local OFF = Color3.fromHex("#4A4560")

local function actionButton(scope: any, props: Props, height: any): Instance
	return scope:New("TextButton")({
		Name = "Action",
		Text = props.ActionLabel,
		FontFace = Theme.Fonts.Heavy,
		TextSize = 18,
		TextColor3 = Theme.Colors.Ink,
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = scope:Computed(function(use)
			return UDim2.fromOffset(130, use(height))
		end),
		[scope.OnEvent("Activated")] = function()
			if props.OnAction then
				props.OnAction()
			end
		end,
		[scope.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
			scope:New("UIGradient")({
				Rotation = 90,
				Color = ColorSequence.new(Theme.Colors.AccentLight, Theme.Colors.Accent),
			}),
		},
	})
end

local function toggle(scope: any, props: Props, height: any): Instance
	local on = props.Toggle == true
	return scope:New("TextButton")({
		Name = "Toggle",
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = scope:Computed(function(use)
			return UDim2.fromOffset(96, use(height))
		end),
		[scope.OnEvent("Activated")] = function()
			if props.OnAction then
				props.OnAction()
			end
		end,
		[scope.Children] = {
			scope:New("Frame")({
				Name = "Track",
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(88, 34),
				BackgroundColor3 = if on then Theme.Colors.Accent else OFF,
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					scope:New("Frame")({
						Name = "Knob",
						AnchorPoint = Vector2.new(if on then 1 else 0, 0.5),
						Position = UDim2.new(if on then 1 else 0, if on then -4 else 4, 0.5, 0),
						Size = UDim2.fromOffset(26, 26),
						BackgroundColor3 = if on then Theme.Colors.Ink else Theme.Colors.TextDim,
						[scope.Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }) },
					}),
					Text.label(scope, {
						Text = if on then "OUI" else "NON",
						Weight = "Heavy",
						Color = if on then Theme.Colors.Ink else Theme.Colors.TextDim,
						Size = UDim2.new(1, -40, 0, 18),
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, if on then 10 else 32, 0.5, 0),
					}),
				},
			}),
		},
	})
end

return function(scope: any, props: Props): Instance
	local controlHeight = Metrics.touch(scope, 44)
	local hasControl = props.ActionLabel ~= nil or props.Toggle ~= nil
	local baseHeight = if props.Description and #props.Chips > 0 then 92 else 74
	local textWidth = if props.ActionLabel then -240 elseif props.Toggle ~= nil then -200 else -96

	local chipChildren: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 6),
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for i, chip in props.Chips do
		if chip:IsA("GuiObject") and chip.LayoutOrder == 0 then
			chip.LayoutOrder = i
		end
		table.insert(chipChildren, chip)
	end

	local children: { any } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Panel) }),
		scope:New("UIStroke")({
			Color = if props.Selected then Theme.Colors.Accent else Theme.Colors.PanelLine,
			Transparency = if props.Selected then 0 else Theme.Transparency.PanelLine,
			Thickness = 2,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		scope:New("UIGradient")({
			Color = ColorSequence.new(Color3.fromHex("#262044"), Color3.fromHex("#16132A")),
		}),
		scope:New("TextLabel")({
			Name = "Portrait",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 12, 0.5, 0),
			Size = UDim2.fromOffset(54, 54),
			BackgroundColor3 = Color3.fromHex("#120F22"),
			Text = props.Portrait,
			TextScaled = true,
			FontFace = Theme.Fonts.Heavy,
			TextColor3 = props.PortraitColor or Theme.Colors.Text,
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
				scope:New("UIStroke")({
					Color = props.PortraitColor or Theme.Colors.PanelLine,
					Transparency = 0.4,
					Thickness = 2,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, 10),
					PaddingBottom = UDim.new(0, 10),
				}),
			},
		}),
		Text.label(scope, {
			Name = "Title",
			Text = props.Name,
			Weight = "ExtraBold",
			Color = if props.Dimmed then Theme.Colors.TextDim else nil,
			Size = UDim2.new(1, textWidth, 0, 24),
			Position = UDim2.fromOffset(80, 12),
			XAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("Frame")({
			Name = "Chips",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(80, 42),
			Size = UDim2.new(1, textWidth, 0, 20),
			[scope.Children] = chipChildren,
		}),
	}
	if props.Description then
		table.insert(
			children,
			Text.label(scope, {
				Name = "Description",
				Text = props.Description,
				Weight = "Bold",
				Color = Theme.Colors.TextDim,
				Size = UDim2.new(1, textWidth, 0, 16),
				Position = UDim2.fromOffset(80, if #props.Chips > 0 then 66 else 42),
				XAlignment = Enum.TextXAlignment.Left,
			})
		)
	end
	if props.ActionLabel then
		table.insert(children, actionButton(scope, props, controlHeight))
	elseif props.Toggle ~= nil then
		table.insert(children, toggle(scope, props, controlHeight))
	end

	return scope:New("Frame")({
		Name = props.Name,
		LayoutOrder = props.LayoutOrder or 0,
		Size = scope:Computed(function(use)
			local needed = if hasControl then use(controlHeight) + 20 else 0
			return UDim2.new(1, 0, 0, math.max(baseHeight, needed))
		end),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = if props.Dimmed then 0.45 else 0,
		[scope.Children] = children,
	})
end
