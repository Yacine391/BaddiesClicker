--!strict
--[[
	MenuItem : tuile du menu de gauche (style simulateur, spec §3.3 et §4.1).
	full : 96 × 96 ; compact (petits écrans) : 72 × 72 ; toujours ≥ 48 px réels (Metrics.touch, §21).
	Icône pleine au centre, libellé contouré qui déborde en bas, pastille rouge (BadgeModel.pip) en haut à droite.
	Active (fenêtre ouverte) = contour blanc 4 px. Survol et pression passent par Motion (interruptibles).
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Text = require(UI.Text)
local Metrics = require(UI.Metrics)
local Motion = require(UI.Motion)
local Icon = require(script.Parent.Icon)
local Tile = require(script.Parent.Tile)
local BadgeModel = require(UI.Parent.Logic.BadgeModel)

export type Props = {
	Icon: string,
	Label: string,
	Gradient: { top: Color3, bottom: Color3 },
	Mode: any, -- état de "full" | "compact"
	Active: any, -- état de boolean
	Badge: any?, -- état de string ; "" = pas de badge
	OnClick: () -> (),
	LayoutOrder: number?,
}

return function(scope: any, props: Props): Instance
	local touch = Metrics.touch(scope, Theme.MinTouch)
	local side = scope:Computed(function(use)
		local base = if use(props.Mode) == "compact" then 72 else 96
		return math.max(base, use(touch) :: number)
	end)
	local scale = scope:New("UIScale")({ Scale = 1 })

	local children: { any } = {
		Icon(scope, {
			Name = props.Icon,
			Size = UDim2.fromScale(0.62, 0.62),
			Position = UDim2.fromScale(0.5, 0.42),
			AnchorPoint = Vector2.new(0.5, 0.5),
			ZIndex = 3,
		}),
		Text.label(scope, {
			Name = "Title",
			Text = props.Label,
			Weight = "Heavy",
			Stroke = true,
			Size = UDim2.fromScale(1.15, 0.26),
			Position = UDim2.new(0.5, 0, 1, 6),
			AnchorPoint = Vector2.new(0.5, 1),
			ZIndex = 4,
		}),
	}
	if props.Badge ~= nil then
		local pip = scope:Computed(function(use)
			return BadgeModel.pip(use(props.Badge))
		end)
		table.insert(
			children,
			scope:New("Frame")({
				Name = "Badge",
				BackgroundColor3 = Theme.Colors.Badge,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(1, -6, 0, 6),
				Size = UDim2.fromOffset(26, 26),
				ZIndex = 6,
				Visible = scope:Computed(function(use)
					return use(pip) ~= ""
				end),
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					scope:New("UIStroke")({
						Color = Theme.Colors.Ink,
						Thickness = 2,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					Text.label(scope, {
						Text = pip,
						Weight = "Heavy",
						Size = UDim2.new(1, -6, 1, -6),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						ZIndex = 7,
					}),
				},
			})
		)
	end

	local function isPointer(input: InputObject): boolean
		local kind = input.UserInputType
		return kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch
	end

	return scope:New("TextButton")({
		Name = "Menu_" .. props.Icon,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Size = scope:Computed(function(use)
			local s = use(side)
			return UDim2.fromOffset(s, s)
		end),
		[scope.OnEvent("Activated")] = props.OnClick,
		[scope.OnEvent("MouseEnter")] = function()
			Motion.hover(scale, true)
		end,
		[scope.OnEvent("MouseLeave")] = function()
			Motion.hover(scale, false)
		end,
		[scope.OnEvent("InputBegan")] = function(input: InputObject)
			if isPointer(input) then
				Motion.press(scale, true)
			end
		end,
		[scope.OnEvent("InputEnded")] = function(input: InputObject)
			if isPointer(input) then
				Motion.press(scale, false)
			end
		end,
		[scope.Children] = {
			scale,
			Tile(scope, {
				Name = "Tile",
				Gradient = props.Gradient,
				Size = UDim2.fromScale(1, 1),
				StrokeColor = scope:Computed(function(use)
					return if use(props.Active) then Color3.new(1, 1, 1) else Theme.Colors.Ink
				end),
				StrokeThickness = scope:Computed(function(use)
					return if use(props.Active) then 4 else Theme.Stroke.Frame
				end),
				Children = children,
			}),
		},
	})
end
