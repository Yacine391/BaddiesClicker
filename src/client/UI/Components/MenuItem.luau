--!strict
--[[
	MenuItem : entrée du menu de gauche (Book, Crew, Style, Réglages).
	full : 236 × 54, icône teintée, libellé, chevron ; actif = contour coloré + barre gauche + halo.
	compact (petits écrans) : tuile carrée, icône au-dessus d'un petit libellé.
	La hauteur suit Metrics.touch pour rester ≥ 48 px réels à l'écran (§21).
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Text = require(UI.Text)
local Metrics = require(UI.Metrics)
local Panel = require(script.Parent.Panel)
local Icon = require(script.Parent.Icon)

export type Props = {
	Icon: string,
	Label: string,
	Color: Color3,
	Mode: any, -- état de "full" | "compact"
	Active: any, -- état de boolean
	Badge: any?, -- état de string ; "" = pas de badge
	OnClick: () -> (),
	LayoutOrder: number?,
}

return function(scope: any, props: Props): Instance
	local height = Metrics.touch(scope, 54)
	local compact = scope:Computed(function(use)
		return use(props.Mode) == "compact"
	end)
	local function pick(full: any, small: any): any
		return scope:Computed(function(use)
			return if use(compact) then small else full
		end)
	end

	local children: { any } = {
		-- barre gauche de l'entrée active
		scope:New("Frame")({
			Name = "ActiveBar",
			BackgroundColor3 = props.Color,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(-2, 8),
			Size = UDim2.new(0, 4, 1, -16),
			ZIndex = 3,
			Visible = props.Active,
			[scope.Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, 2) }) },
		}),
		Icon(scope, {
			Name = props.Icon,
			Color = props.Color,
			Size = pick(UDim2.fromOffset(30, 30), UDim2.fromOffset(28, 28)),
			Position = pick(UDim2.new(0, 14, 0.5, 0), UDim2.new(0.5, 0, 0, 5)),
			AnchorPoint = pick(Vector2.new(0, 0.5), Vector2.new(0.5, 0)),
		}),
		Text.label(scope, {
			Name = "Title",
			Text = props.Label,
			Weight = "ExtraBold",
			Size = pick(UDim2.new(1, -96, 0, 22), UDim2.new(1, -4, 0, 12)),
			Position = pick(UDim2.new(0, 58, 0.5, 0), UDim2.new(0.5, 0, 1, -4)),
			AnchorPoint = pick(Vector2.new(0, 0.5), Vector2.new(0.5, 1)),
			XAlignment = pick(Enum.TextXAlignment.Left, Enum.TextXAlignment.Center),
			ZIndex = 2,
		}),
		scope:New("Frame")({
			Name = "Chevron",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(16, 16),
			Visible = scope:Computed(function(use)
				return not use(compact)
			end),
			[scope.Children] = {
				Icon(scope, {
					Name = "chevron",
					Size = UDim2.fromScale(1, 1),
					Color = scope:Computed(function(use)
						return if use(props.Active) then props.Color else Theme.Colors.TextDim
					end),
				}),
			},
		}),
	}
	if props.Badge ~= nil then
		table.insert(
			children,
			scope:New("Frame")({
				Name = "Badge",
				BackgroundColor3 = Theme.Colors.Accent2,
				AnchorPoint = pick(Vector2.new(1, 0.5), Vector2.new(1, 0)),
				Position = pick(UDim2.new(1, -38, 0.5, 0), UDim2.new(1, 6, 0, -6)),
				Size = UDim2.fromOffset(34, 16),
				ZIndex = 4,
				Visible = scope:Computed(function(use)
					local b = use(props.Badge)
					return b ~= nil and b ~= ""
				end),
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
					Text.label(scope, {
						Text = props.Badge,
						Weight = "ExtraBold",
						Color = Theme.Colors.Ink,
						Size = UDim2.new(1, -6, 1, -3),
						Position = UDim2.fromScale(0.5, 0.5),
						AnchorPoint = Vector2.new(0.5, 0.5),
						ZIndex = 5,
					}),
				},
			})
		)
	end

	return scope:New("TextButton")({
		Name = "Menu_" .. props.Icon,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		Size = scope:Computed(function(use)
			local h = use(height)
			return if use(compact) then UDim2.fromOffset(h, h) else UDim2.fromOffset(236, h)
		end),
		[scope.OnEvent("Activated")] = props.OnClick,
		[scope.Children] = {
			Panel(scope, {
				Size = UDim2.fromScale(1, 1),
				Line = scope:Computed(function(use)
					return if use(props.Active) then props.Color else Theme.Colors.PanelLine
				end),
				LineTransparency = scope:Computed(function(use)
					return if use(props.Active) then 0 else Theme.Transparency.PanelLine
				end),
				Glow = props.Color,
				GlowVisible = props.Active,
				Children = children,
			}),
		},
	})
end
