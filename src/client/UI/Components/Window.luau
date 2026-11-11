--!strict
--[[
	Window : fenêtre du style simulateur (spec docs/superpowers/specs/2026-11-11-ui-lobby-simulateur-design.md §3.3, §5).
	Fond Panel, coins 14, contour Ink 4 px ; bandeau titre de 64 au dégradé du menu (icône + titre contouré),
	croix carrée rouge de 52 collée au bandeau. Onglets dans le bandeau ("header") ou en colonne à droite ("side").
	Le fond plein écran assombrit le jeu et capte les clics (rien ne traverse vers le jeu, §21) ; Échap ferme.
	Ouverture : Motion.open (0,9 → 1) ; la fermeture est immédiate pour rester interruptible.
	Layout "list" (défaut) : contenu en liste défilante. "free" : le contenu reçoit tout le corps.
]]

local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Metrics = require(UI.Metrics)
local Motion = require(UI.Motion)
local Icon = require(script.Parent.Icon)
local Tile = require(script.Parent.Tile)

export type Tab = { id: string, label: string, count: string? }
export type Gradient = { top: Color3, bottom: Color3 }

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
	Gradient: Gradient?, -- défaut Theme.Gradients.Book
	TabsPlacement: ("header" | "side")?,
}

local HEADER = 64
local INACTIVE: Gradient = { top = Theme.Colors.PanelInner, bottom = Theme.Colors.PanelInner }

local function stroke(scope: any, thickness: number)
	return scope:New("UIStroke")({
		Color = Theme.Colors.Ink,
		Thickness = thickness,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

local function tabButton(scope: any, props: Props, gradient: Gradient, tab: Tab, order: number, side: boolean)
	local active = scope:Computed(function(use)
		return props.ActiveTab ~= nil and use(props.ActiveTab) == tab.id
	end)
	local hit = Metrics.touch(scope, Theme.MinTouch)
	local text = if tab.count then `{tab.label}  {tab.count}` else tab.label
	-- largeur fixe calculée sur le texte : pas d'AutomaticSize (le fond à l'échelle le ferait gonfler)
	local width = TextService:GetTextSize(text, 18, Enum.Font.FredokaOne, Vector2.new(1000, 40)).X + 32
	return scope:New("TextButton")({
		Name = "Tab_" .. tab.id,
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Size = scope:Computed(function(use)
			local h = math.max(if side then 56 else 42, use(hit) :: number)
			return UDim2.fromOffset(if side then math.max(170, width) else width, h)
		end),
		[scope.OnEvent("Activated")] = function()
			if props.OnTab then
				props.OnTab(tab.id)
			end
		end,
		[scope.Children] = {
			Tile(scope, {
				Name = "Pill",
				Gradient = scope:Computed(function(use)
					return if use(active) then gradient else INACTIVE
				end),
				Size = UDim2.new(1, 0, 1, -6),
				Radius = 6,
			}),
			scope:New("TextLabel")({
				Name = "Label",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, -6),
				Text = text,
				FontFace = Theme.Fonts.Main,
				TextSize = 18,
				TextColor3 = scope:Computed(function(use)
					return if use(active) then Theme.Colors.Text else Theme.Colors.TextDim
				end),
				ZIndex = 4,
				[scope.Children] = { stroke(scope, Theme.Stroke.List) },
			}),
		},
	})
end

return function(scope: any, props: Props): Instance
	local gradient = props.Gradient or Theme.Gradients.Book
	local side = props.TabsPlacement == "side"
	local closeSide = Metrics.touch(scope, 52)
	-- Sous une petite échelle, la croix (≥ 48 px réels) peut dépasser 64 px de référence : le bandeau grandit avec elle
	local headerHeight = scope:Computed(function(use)
		return math.max(HEADER, (use(closeSide) :: number) + 12)
	end)
	local bodySize = scope:Computed(function(use)
		return UDim2.new(1, 0, 1, -(use(headerHeight) :: number))
	end)
	local bodyPosition = scope:Computed(function(use)
		return UDim2.fromOffset(0, use(headerHeight))
	end)
	table.insert(
		scope,
		UserInputService.InputBegan:Connect(function(input, processed)
			if not processed and input.KeyCode == Enum.KeyCode.Escape then
				props.OnClose()
			end
		end)
	)

	local function tabsList(fill: Enum.FillDirection, padding: number): { any }
		return {
			scope:New("UIListLayout")({
				FillDirection = fill,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				Padding = UDim.new(0, padding),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			scope:Computed(function(use, inner)
				local buttons = {}
				for i, tab in use(props.Tabs) or {} do
					table.insert(buttons, tabButton(inner, props, gradient, tab, i, side))
				end
				return buttons
			end),
		}
	end

	local headerChildren: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = UDim.new(0, 12),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 16) }),
		Icon(scope, { Name = props.Icon, Size = UDim2.fromOffset(44, 44), ZIndex = 4 }),
		scope:New("TextLabel")({
			Name = "Title",
			LayoutOrder = 1,
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 40),
			Text = string.upper(props.Title),
			FontFace = Theme.Fonts.Main,
			TextSize = 32,
			TextColor3 = Theme.Colors.Text,
			ZIndex = 4,
			[scope.Children] = { stroke(scope, Theme.Stroke.Text) },
		}),
	}
	if props.Tabs ~= nil and not side then
		local tabs = tabsList(Enum.FillDirection.Horizontal, 8)
		table.insert(tabs, scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 8) }))
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
				ZIndex = 4,
				[scope.Children] = tabs,
			})
		)
	end

	local body: Instance
	if props.Layout == "free" then
		body = scope:New("Frame")({
			Name = "Content",
			BackgroundTransparency = 1,
			Position = bodyPosition,
			Size = bodySize,
			[scope.Children] = props.Content,
		})
	else
		body = scope:New("ScrollingFrame")({
			Name = "Content",
			BackgroundTransparency = 1,
			Position = bodyPosition,
			Size = bodySize,
			CanvasSize = UDim2.new(),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = 8,
			ScrollBarImageColor3 = Theme.Colors.PanelInner,
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
			Color = Theme.Colors.Ink,
			Thickness = 4,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		scope:New("Frame")({
			Name = "Header",
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			Size = scope:Computed(function(use)
				return UDim2.new(1, 0, 0, use(headerHeight))
			end),
			ZIndex = 2,
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 14) }),
				scope:New("UIGradient")({
					Rotation = 90,
					Color = ColorSequence.new(gradient.top, gradient.bottom),
				}),
				-- bas du bandeau carré (les coins arrondis ne restent qu'en haut)
				scope:New("Frame")({
					Name = "Square",
					BackgroundColor3 = gradient.bottom,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 14),
					ZIndex = 2,
				}),
				scope:New("Frame")({
					Name = "Line",
					BackgroundColor3 = Theme.Colors.Ink,
					BorderSizePixel = 0,
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, 4),
					ZIndex = 3,
				}),
				scope:New("Frame")({
					Name = "Row",
					BackgroundTransparency = 1,
					Size = scope:Computed(function(use)
						return UDim2.new(1, -((use(closeSide) :: number) + 24), 1, -4)
					end),
					ZIndex = 4,
					[scope.Children] = headerChildren,
				}),
			},
		}),
		body,
		scope:New("TextButton")({
			Name = "Close",
			Text = "X",
			FontFace = Theme.Fonts.Main,
			TextSize = 30,
			TextColor3 = Theme.Colors.Text,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = scope:Computed(function(use)
				return UDim2.new(1, -8, 0, ((use(headerHeight) :: number) - 4) / 2)
			end),
			Size = scope:Computed(function(use)
				local s = use(closeSide)
				return UDim2.fromOffset(s, s)
			end),
			BackgroundColor3 = Theme.Colors.Close,
			ZIndex = 5,
			[scope.OnEvent("Activated")] = props.OnClose,
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
				scope:New("UIStroke")({
					Color = Theme.Colors.Ink,
					Thickness = 3,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			},
		}),
	}
	if props.Tabs ~= nil and side then
		-- colonne d'onglets à droite de la fenêtre (spec §5.1)
		table.insert(
			frameChildren,
			scope:New("Frame")({
				Name = "SideTabs",
				BackgroundTransparency = 1,
				Position = scope:Computed(function(use)
					return UDim2.new(1, 14, 0, use(headerHeight))
				end),
				Size = UDim2.new(0, 220, 1, 0),
				[scope.Children] = tabsList(Enum.FillDirection.Vertical, 10),
			})
		)
	end

	local scale = scope:New("UIScale")({ Scale = 1 })
	table.insert(frameChildren, scale)
	local window = scope:New("Frame")({
		Name = "Border",
		AnchorPoint = Vector2.new(0.5, 0.5),
		-- avec onglets latéraux, la fenêtre se décale à gauche pour que l'ensemble reste centré
		Position = if side then UDim2.new(0.5, -92, 0.5, 0) else UDim2.fromScale(0.5, 0.5),
		Size = props.Size or UDim2.fromOffset(820, 500),
		BackgroundColor3 = Theme.Colors.Panel,
		ZIndex = 11,
		[scope.Children] = frameChildren,
	})
	Motion.open(scale)

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
