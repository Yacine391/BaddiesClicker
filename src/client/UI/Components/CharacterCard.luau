--!strict
--[[
	CharacterCard : carte de droite (principale, compagnons équipés).
	full : 150 × 158 — zone portrait 96 (dégradé + silhouette teintée), pastille de rareté, nom, deux lignes.
	compact : bandeau 150 × 46 (nom + Line1).
	Le portrait est une silhouette tant que les rendus des personnages n'existent pas.
]]

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Text = require(UI.Text)
local Panel = require(script.Parent.Panel)
local Icon = require(script.Parent.Icon)

export type Props = {
	Rarity: any, -- { label: string, color: Color3 | string } ou état ; nil = pas de pastille
	Name: any, -- string ou état
	Line1: any, -- string ou état (ex. « ×1 · Slot 1 » ou « +0,6/s »)
	Line2: any?, -- string ou état
	Accent: any, -- Color3 ou état
	Mode: any, -- état de "full" | "compact"
	LayoutOrder: number?,
	Visible: any?,
}

local function toColor(c: any): Color3
	if typeof(c) == "Color3" then
		return c
	elseif type(c) == "string" then
		return Color3.fromHex(c)
	end
	return Theme.Colors.TextDim
end

return function(scope: any, props: Props): Frame
	local compact = scope:Computed(function(use)
		return use(props.Mode) == "compact"
	end)
	local full = scope:Computed(function(use)
		return not use(compact)
	end)
	local rarity = scope:Computed(function(use)
		return use(props.Rarity)
	end)
	local rarityColor = scope:Computed(function(use)
		local r = use(rarity)
		return toColor(if type(r) == "table" then r.color else nil)
	end)

	local portrait = scope:New("Frame")({
		Name = "Portrait",
		Size = UDim2.new(1, 0, 0, 96),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Visible = full,
		ClipsDescendants = true,
		[scope.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Panel) }),
			scope:New("UIGradient")({
				Rotation = 90,
				Color = ColorSequence.new(Color3.fromHex("#2A2147"), Color3.fromHex("#151226")),
			}),
			-- silhouette provisoire
			scope:New("Frame")({
				Name = "Silhouette",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.fromScale(0.5, 1),
				Size = UDim2.fromOffset(56, 76),
				BackgroundColor3 = props.Accent,
				BackgroundTransparency = 0.35,
				[scope.Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0.4, 0) }) },
			}),
			scope:New("Frame")({
				Name = "Rarity",
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(0, 16),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = rarityColor,
				Visible = scope:Computed(function(use)
					return type(use(rarity)) == "table"
				end),
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
					scope:New("TextLabel")({
						BackgroundTransparency = 1,
						AutomaticSize = Enum.AutomaticSize.X,
						Size = UDim2.fromOffset(0, 16),
						Text = scope:Computed(function(use)
							local r = use(rarity)
							return if type(r) == "table" then string.upper(tostring(r.label)) else ""
						end),
						FontFace = Theme.Fonts.ExtraBold,
						TextSize = 11,
						TextColor3 = Theme.Colors.Ink,
					}),
				},
			}),
		},
	})

	local body = scope:New("Frame")({
		Name = "Body",
		BackgroundTransparency = 1,
		Position = scope:Computed(function(use)
			return if use(compact) then UDim2.fromOffset(10, 4) else UDim2.fromOffset(10, 100)
		end),
		Size = UDim2.new(1, -20, 0, 54),
		[scope.Children] = {
			Text.label(scope, {
				Name = "Name",
				Text = props.Name,
				Weight = "ExtraBold",
				Size = UDim2.new(1, 0, 0, 20),
				XAlignment = Enum.TextXAlignment.Left,
			}),
			Icon(scope, {
				Name = "bolt",
				Color = Theme.Colors.Accent,
				Size = UDim2.fromOffset(16, 16),
				Position = UDim2.fromOffset(0, 21),
			}),
			Text.label(scope, {
				Name = "Line1",
				Text = props.Line1,
				Weight = "ExtraBold",
				Color = Theme.Colors.Accent,
				Size = UDim2.new(1, -20, 0, 17),
				Position = UDim2.fromOffset(20, 21),
				XAlignment = Enum.TextXAlignment.Left,
			}),
			Text.label(scope, {
				Name = "Line2",
				Text = props.Line2 or "",
				Weight = "Bold",
				Color = Theme.Colors.TextDim,
				Size = UDim2.new(1, 0, 0, 13),
				Position = UDim2.fromOffset(0, 40),
				XAlignment = Enum.TextXAlignment.Left,
				Visible = full,
			}),
		},
	})

	return Panel(scope, {
		Name = "CharacterCard",
		Size = scope:Computed(function(use)
			return if use(compact) then UDim2.fromOffset(150, 46) else UDim2.fromOffset(150, 158)
		end),
		Line = props.Accent,
		LineTransparency = 0.35,
		LayoutOrder = props.LayoutOrder,
		Visible = props.Visible,
		Children = { portrait, body },
	})
end
