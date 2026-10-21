--!strict
--[[
	Window : fenêtre du style mix A (Book, Style, Crew, Réglages ; maquette windows-mixA.html).
	820 × 500, contour Accent + halo, en-tête 62 (icône, titre, onglets en pastilles), croix carrée.
	Le fond plein écran assombrit le jeu et capte les clics (rien ne traverse vers le jeu, §21) ;
	Échap ferme.
	Layout "list" (défaut) : contenu en liste défilante. "free" : le contenu reçoit tout le corps.
]]

local UserInputService = game:GetService("UserInputService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Halo = require(script.Parent.Halo)
local Metrics = require(UI.Metrics)
local Icon = require(script.Parent.Icon)

export type Tab = { id: string, label: string, count: string? }

export type Props = {
	Title: string,
	Icon: string,
	Tabs: any?, -- { Tab } ou état Fusion de { Tab } (compteurs en direct)
	ActiveTab: any?, -- état de string
	OnTab: ((id: string) -> ())?,
	Content: { any },
	Layout: ("list" | "free")?,
	OnClose: () -> (),
	Size: UDim2?,
}

local HEADER = 62

local function hex(c: Color3): string
	return "#" .. c:ToHex()
end

local function tabButton(scope: any, props: Props, tab: Tab, order: number): Instance
	local active = scope:Computed(function(use)
		return props.ActiveTab ~= nil and use(props.ActiveTab) == tab.id
	end)
	local hit = Metrics.touch(scope, Theme.MinTouch)
	local label = scope:New("TextLabel")({
		Name = "Label",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 34),
		RichText = true,
		Text = if tab.count
			then `{tab.label} <font color="{hex(Theme.Colors.Accent)}">{tab.count}</font>`
			else tab.label,
		FontFace = Theme.Fonts.ExtraBold,
		TextSize = 15,
		TextColor3 = scope:Computed(function(use)
			return if use(active) then Theme.Colors.Text else Theme.Colors.TextDim
		end),
	})
	return scope:New("TextButton")({
		Name = "Tab_" .. tab.id,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		AutomaticSize = Enum.AutomaticSize.X,
		-- zone de clic ≥ 48 px réels, pastille visible de 34 px centrée dedans
		Size = scope:Computed(function(use)
			return UDim2.fromOffset(0, use(hit))
		end),
		[scope.OnEvent("Activated")] = function()
			if props.OnTab then
				props.OnTab(tab.id)
			end
		end,
		[scope.Children] = {
			scope:New("Frame")({
				Name = "Pill",
				AutomaticSize = Enum.AutomaticSize.X,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(0, 34),
				BackgroundColor3 = scope:Computed(function(use)
					return if use(active) then Theme.Colors.Accent else Color3.new(1, 1, 1)
				end),
				BackgroundTransparency = scope:Computed(function(use)
					return if use(active) then 0.88 else 0.94
				end),
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
					scope:New("UIStroke")({
						Color = Theme.Colors.Accent,
						Thickness = 2,
						Transparency = scope:Computed(function(use)
							return if use(active) then 0 else 1
						end),
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
					label,
				},
			}),
		},
	})
end

return function(scope: any, props: Props): Instance
	local closeSide = Metrics.touch(scope, 42)
	-- Sous l'échelle ~0,77, les cibles tactiles (≥ 48 px réels) dépassent 62 px de référence :
	-- l'en-tête grandit avec elles au lieu de les laisser déborder
	local tabHit = Metrics.touch(scope, Theme.MinTouch)
	local headerHeight = scope:Computed(function(use)
		return math.max(HEADER, (use(closeSide) :: number) + 14, (use(tabHit) :: number) + 8)
	end)
	local function belowHeader(extra: number)
		return scope:Computed(function(use)
			return UDim2.fromOffset(0, (use(headerHeight) :: number) + extra)
		end)
	end
	local bodySize = scope:Computed(function(use)
		return UDim2.new(1, 0, 1, -((use(headerHeight) :: number) + 2))
	end)
	table.insert(
		scope,
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode.Escape then
				props.OnClose()
			end
		end)
	)

	local headerChildren: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 16) }),
		Icon(scope, { Name = props.Icon, Size = UDim2.fromOffset(30, 30), Color = Theme.Colors.Accent }),
		scope:New("TextLabel")({
			Name = "Title",
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			Text = props.Title,
			FontFace = Theme.Fonts.Heavy,
			TextSize = 28,
			TextColor3 = Theme.Colors.Text,
		}),
	}
	if props.Tabs ~= nil then
		local tabs: { any } = {
			scope:New("UIListLayout")({
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 4) }),
			scope:Computed(function(use, inner)
				local buttons = {}
				for i, tab in use(props.Tabs) or {} do
					table.insert(buttons, tabButton(inner, props, tab, i))
				end
				return buttons
			end),
		}
		table.insert(
			headerChildren,
			scope:New("Frame")({
				Name = "Tabs",
				LayoutOrder = 2,
				BackgroundTransparency = 1,
				AutomaticSize = Enum.AutomaticSize.X,
				Size = scope:Computed(function(use)
					return UDim2.fromOffset(0, use(headerHeight))
				end),
				[scope.Children] = tabs,
			})
		)
	end

	local body: Instance
	if props.Layout == "free" then
		body = scope:New("Frame")({
			Name = "Content",
			BackgroundTransparency = 1,
			Position = belowHeader(2),
			Size = bodySize,
			[scope.Children] = props.Content,
		})
	else
		body = scope:New("ScrollingFrame")({
			Name = "Content",
			BackgroundTransparency = 1,
			Position = belowHeader(2),
			Size = bodySize,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 6,
			ScrollBarImageColor3 = Theme.Colors.PanelLine,
			BorderSizePixel = 0,
			[scope.Children] = {
				scope:New("UIListLayout")({
					Padding = UDim.new(0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				scope:New("UIPadding")({
					PaddingTop = UDim.new(0, 14),
					PaddingBottom = UDim.new(0, 14),
					PaddingLeft = UDim.new(0, 16),
					PaddingRight = UDim.new(0, 18),
				}),
				props.Content,
			},
		})
	end

	local frameChildren: { any } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, 14) }),
		scope:New("UIStroke")({
			Color = Theme.Colors.Accent,
			Thickness = if Theme.Glow ~= "" then 2 else 3,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		scope:New("Frame")({
			Name = "Header",
			BackgroundColor3 = Theme.Colors.Accent,
			BackgroundTransparency = 0.88,
			BorderSizePixel = 0,
			Size = scope:Computed(function(use)
				return UDim2.new(1, 0, 0, use(headerHeight))
			end),
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 14) }),
				scope:New("UIGradient")({
					Transparency = NumberSequence.new({
						NumberSequenceKeypoint.new(0, 0),
						NumberSequenceKeypoint.new(0.6, 1),
						NumberSequenceKeypoint.new(1, 1),
					}),
				}),
				scope:New("Frame")({
					Name = "Row",
					BackgroundTransparency = 1,
					Size = scope:Computed(function(use)
						return UDim2.new(1, -((use(closeSide) :: number) + 30), 1, 0)
					end),
					[scope.Children] = headerChildren,
				}),
			},
		}),
		scope:New("Frame")({
			Name = "HeaderLine",
			BackgroundColor3 = Theme.Colors.PanelLine,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
			Position = belowHeader(0),
			Size = UDim2.new(1, 0, 0, 2),
		}),
		body,
		scope:New("TextButton")({
			Name = "Close",
			Text = "X",
			FontFace = Theme.Fonts.Heavy,
			TextSize = 22,
			TextColor3 = Theme.Colors.Text,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = scope:Computed(function(use)
				return UDim2.new(1, -12, 0, (use(headerHeight) :: number) / 2)
			end),
			Size = scope:Computed(function(use)
				local side = use(closeSide)
				return UDim2.fromOffset(side, side)
			end),
			BackgroundColor3 = Theme.Colors.Close,
			ZIndex = 3,
			[scope.OnEvent("Activated")] = props.OnClose,
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
				scope:New("UIStroke")({
					Color = Theme.Colors.Ink,
					Thickness = 2,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			},
		}),
	}
	local size = props.Size or UDim2.fromOffset(820, 500)
	local withHalo = Halo.enabled()
	local fill = Halo.FILL
	local border = scope:New("Frame")({
		Name = "Border",
		AnchorPoint = if withHalo then fill.AnchorPoint else Vector2.new(0.5, 0.5),
		Position = if withHalo then fill.Position else UDim2.fromScale(0.5, 0.5),
		Size = if withHalo then fill.Size else size,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.03,
		ZIndex = if withHalo then fill.ZIndex else 11,
		[scope.Children] = frameChildren,
	})
	-- halo cyan DERRIÈRE la fenêtre (frère de Border, jamais enfant : il la recouvrirait)
	local window = if withHalo
		then Halo.host(scope, {
			Name = "BorderHost",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = size,
			ZIndex = 11,
		}, { Color = Theme.Colors.Accent, Transparency = 0.5, Margin = 40 }, border)
		else border

	return scope:New("TextButton")({
		Name = "WindowBackdrop",
		Text = "",
		AutoButtonColor = false,
		Active = true,
		BackgroundColor3 = Theme.Colors.Ink,
		BackgroundTransparency = Theme.Transparency.Dim,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		[scope.Children] = { window },
	})
end
