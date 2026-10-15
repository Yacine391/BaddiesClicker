--!strict
--[[
	ProgressCard : carte du bas à gauche (290 × 62). Tutoriel « MALIK ARRIVE » (icône crew),
	puis « PARCOURS » des 10 niveaux (icône door). Barre dégradée Accent2 → Accent.
	Modèle : HudModel.progress ; invisible si `visible == false`.
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Text = require(UI.Text)
local Panel = require(script.Parent.Panel)
local Icon = require(script.Parent.Icon)

export type Props = {
	Model: any, -- état de HudModel.Progress
	Position: any?,
	AnchorPoint: Vector2?,
}

local function hex(c: Color3): string
	return "#" .. c:ToHex()
end

return function(scope: any, props: Props): Frame
	local kind = scope:Computed(function(use)
		return use(props.Model).kind
	end)
	local function iconFor(name: string, k: string): Instance
		return scope:New("Frame")({
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 14, 0.5, 0),
			Size = UDim2.fromOffset(34, 34),
			Visible = scope:Computed(function(use)
				return use(kind) == k
			end),
			[scope.Children] = {
				Icon(scope, {
					Name = name,
					Size = UDim2.fromScale(1, 1),
					Color = if k == "run" then Theme.Colors.Accent else Theme.Colors.Crew,
				}),
			},
		})
	end

	local title = Text.label(scope, {
		Name = "Title",
		Text = scope:Computed(function(use)
			return `{use(props.Model).title} <font color="{hex(Theme.Colors.TextDim)}">»</font>`
		end),
		Weight = "ExtraBold",
		Size = UDim2.new(1, -62, 0, 17),
		Position = UDim2.fromOffset(60, 10),
		XAlignment = Enum.TextXAlignment.Left,
	})
	title.RichText = true
	local value = Text.label(scope, {
		Name = "Value",
		Text = scope:Computed(function(use)
			local m = use(props.Model)
			return `<font color="{hex(Theme.Colors.Accent)}">{m.value}</font> / {m.max}`
		end),
		Weight = "ExtraBold",
		Size = UDim2.fromOffset(64, 20),
		Position = UDim2.fromOffset(60, 31),
		XAlignment = Enum.TextXAlignment.Left,
	})
	value.RichText = true

	return Panel(scope, {
		Name = "ProgressCard",
		Size = UDim2.fromOffset(290, 62),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Visible = scope:Computed(function(use)
			return use(props.Model).visible == true
		end),
		Children = {
			iconFor("door", "run"),
			iconFor("crew", "tutorial"),
			title,
			value,
			scope:New("Frame")({
				Name = "Bar",
				Position = UDim2.fromOffset(132, 37),
				Size = UDim2.new(1, -148, 0, 8),
				BackgroundColor3 = Color3.new(1, 1, 1),
				BackgroundTransparency = 0.88,
				ClipsDescendants = true,
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
					scope:New("Frame")({
						Name = "Fill",
						BackgroundColor3 = Color3.new(1, 1, 1),
						BorderSizePixel = 0,
						Size = scope:Spring(
							scope:Computed(function(use)
								local m = use(props.Model)
								local ratio = if m.max > 0 then math.clamp(m.value / m.max, 0, 1) else 0
								return UDim2.fromScale(ratio, 1)
							end),
							20,
							1
						),
						[scope.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
							scope:New("UIGradient")({
								Color = ColorSequence.new(Theme.Colors.Accent2, Theme.Colors.Accent),
							}),
						},
					}),
				},
			}),
		},
	})
end
