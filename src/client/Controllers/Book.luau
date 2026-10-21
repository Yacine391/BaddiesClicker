--!strict
--[[
	Book : Baddies Book (§15), style mix A (maquette windows-mixA.html).
	Onglet BADDIES : grille 4 colonnes + fiche de 250 px + barre COLLECTION n / 8.
	Onglet CREW : compagnons possédés (lignes du Crew).
	Distingue PRINCIPALE (seule source de multiplicateur) et EXPOSÉE (apparence uniquement).
	EXPOSER / RETIRER seulement si le serveur envoie `collection` ; sinon lecture seule, sans faux bouton.
	Les textes viennent de BookModel (pur, testé).
]]

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local Text = require(Client.UI.Text)
local Metrics = require(Client.UI.Metrics)
local WindowHost = require(Client.UI.WindowHost)
local BookModel = require(Client.Logic.BookModel)
local Chip = require(Client.UI.Components.Chip)
local Crew = require(script.Parent.Crew)

local Book = {}

local DETAIL_WIDTH = 250
local CARD_HEIGHT = 150
local COLUMNS = 4
local LOCKED = Color3.fromHex("#0B0A14")
local CARD_TOP = Color3.fromHex("#262044")
local CARD_BOTTOM = Color3.fromHex("#16132A")

local function chipColor(key: string): Color3
	return (Theme.Colors :: any)[key] or Theme.Colors.TextDim
end

local function silhouette(scope: any, color: Color3, size: UDim2, position: UDim2): Instance
	return scope:New("Frame")({
		Name = "Silhouette",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = position,
		Size = size,
		BackgroundColor3 = color,
		[scope.Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0.4, 0) }) },
	})
end

local function signature(snapshot: any): string
	if snapshot == nil then
		return "none"
	end
	local c = snapshot.collection
	local active = snapshot.active or {}
	return table.concat({
		tostring(active.baddieId),
		tostring(active.slotId),
		tostring(active.masteryLevel),
		tostring(snapshot.mode),
		if c then table.concat(c.discovered or {}, ",") else "v1",
		if c then table.concat(c.display or {}, ",") else "",
	}, "|")
end

local function card(scope: any, data: BookModel.Card, selected: any, order: number): Instance
	local isSelected = scope:Computed(function(use)
		return use(selected) == data.id
	end)
	local children: { any } = {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Panel) }),
		scope:New("UIGradient")({ Rotation = 90, Color = ColorSequence.new(CARD_TOP, CARD_BOTTOM) }),
		scope:New("UIStroke")({
			Color = scope:Computed(function(use)
				return if use(isSelected) then Theme.Colors.Accent else Theme.Colors.PanelLine
			end),
			Transparency = scope:Computed(function(use)
				return if use(isSelected) then 0 else Theme.Transparency.PanelLine
			end),
			Thickness = scope:Computed(function(use)
				return if use(isSelected) and Theme.Glow == "" then 3 else 2
			end),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		silhouette(
			scope,
			if data.discovered then Color3.fromHex(data.color) else LOCKED,
			UDim2.fromOffset(44, 74),
			UDim2.new(0.5, 0, 0, 96)
		),
		scope:New("Frame")({
			Name = "Rarity",
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(0, 15),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = Color3.fromHex(data.rarityColor),
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
				scope:New("UIPadding")({ PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
				scope:New("TextLabel")({
					BackgroundTransparency = 1,
					AutomaticSize = Enum.AutomaticSize.X,
					Size = UDim2.fromOffset(0, 15),
					Text = string.upper(data.rarityLabel),
					FontFace = Theme.Fonts.ExtraBold,
					TextSize = 10,
					TextColor3 = Theme.Colors.Ink,
				}),
			},
		}),
		Text.label(scope, {
			Name = "Name",
			Text = data.name,
			Weight = "ExtraBold",
			Color = if data.discovered then Theme.Colors.Text else Theme.Colors.TextDim,
			Size = UDim2.new(1, -12, 0, 18),
			Position = UDim2.new(0.5, 0, 1, -26),
			AnchorPoint = Vector2.new(0.5, 1),
		}),
	}
	if data.chip then
		table.insert(
			children,
			scope:New("TextLabel")({
				Name = "Status",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -5),
				Size = UDim2.new(1, -12, 0, 16),
				BackgroundColor3 = chipColor(data.chip.colorKey),
				BackgroundTransparency = if data.chip.colorKey == "TextDim" then 0.85 else 0,
				Text = data.chip.text,
				FontFace = Theme.Fonts.ExtraBold,
				TextSize = 10,
				TextColor3 = if data.chip.colorKey == "TextDim"
					then Theme.Colors.TextDim
					else Theme.Colors.Ink,
				[scope.Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }) },
			})
		)
	end
	return scope:New("TextButton")({
		Name = "Card_" .. data.id,
		Text = "",
		AutoButtonColor = false,
		LayoutOrder = order,
		BackgroundColor3 = Color3.new(1, 1, 1),
		[scope.OnEvent("Activated")] = function()
			selected:set(data.id)
		end,
		[scope.Children] = children,
	})
end

local function statRow(scope: any, label: string, value: string, order: number): Instance
	return scope:New("Frame")({
		Name = "Stat",
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 18),
		[scope.Children] = {
			Text.label(scope, {
				Text = label,
				Weight = "Bold",
				Color = Theme.Colors.TextDim,
				Size = UDim2.fromScale(0.6, 1),
				XAlignment = Enum.TextXAlignment.Left,
			}),
			Text.label(scope, {
				Text = value,
				Weight = "ExtraBold",
				Size = UDim2.fromScale(0.4, 1),
				Position = UDim2.fromScale(0.6, 0),
				XAlignment = Enum.TextXAlignment.Right,
			}),
		},
	})
end

local function button(scope: any, label: string, primary: boolean, order: number, onClick: () -> ()): Instance
	local height = Metrics.touch(scope, 44)
	local children: { any } = { scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }) }
	if primary then
		table.insert(
			children,
			scope:New("UIGradient")({
				Rotation = 90,
				Color = ColorSequence.new(Theme.Colors.AccentLight, Theme.Colors.Accent),
			})
		)
	else
		table.insert(
			children,
			scope:New("UIStroke")({
				Color = Theme.Colors.PanelLine,
				Transparency = 0.5,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			})
		)
	end
	return scope:New("TextButton")({
		Name = "Button",
		LayoutOrder = order,
		Text = label,
		FontFace = Theme.Fonts.Heavy,
		TextSize = 18,
		TextColor3 = if primary then Theme.Colors.Ink else Theme.Colors.Text,
		AutoButtonColor = false,
		BackgroundColor3 = if primary then Color3.new(1, 1, 1) else Theme.Colors.Text,
		BackgroundTransparency = if primary then 0 else 0.94,
		Size = scope:Computed(function(use)
			return UDim2.new(1, 0, 0, use(height))
		end),
		[scope.OnEvent("Activated")] = onClick,
		[scope.Children] = children,
	})
end

local function detailPanel(scope: any, deps: any, snapshot: any, id: string): { any }
	local d = BookModel.detail(snapshot, deps.Catalog, deps.Format.number, id)
	local chips: { any } = {
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			Wraps = true,
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
		Chip(
			scope,
			{ Text = string.upper(d.rarityLabel), Color = Color3.fromHex(d.rarityColor), LayoutOrder = 1 }
		),
	}
	if d.isPrincipal then
		table.insert(
			chips,
			Chip(
				scope,
				{ Text = "PRINCIPALE · " .. d.slotText, Color = Theme.Colors.Principal, LayoutOrder = 2 }
			)
		)
	end
	if d.displayed then
		table.insert(chips, Chip(scope, { Text = "EXPOSÉE", Color = Theme.Colors.Accent, LayoutOrder = 3 }))
	end

	local items: { any } = {
		scope:New("UIListLayout")({ Padding = UDim.new(0, 9), SortOrder = Enum.SortOrder.LayoutOrder }),
		scope:New("Frame")({
			Name = "Portrait",
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 140),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ClipsDescendants = true,
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Panel) }),
				scope:New("UIGradient")({ Rotation = 90, Color = ColorSequence.new(CARD_TOP, CARD_BOTTOM) }),
				scope:New("UIStroke")({
					Color = Theme.Colors.PanelLine,
					Transparency = Theme.Transparency.PanelLine,
					Thickness = 2,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
				silhouette(
					scope,
					if d.discovered then Color3.fromHex(d.color) else LOCKED,
					UDim2.fromOffset(62, 112),
					UDim2.fromScale(0.5, 1)
				),
			},
		}),
		Text.label(scope, {
			Text = d.name,
			Weight = "Heavy",
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 28),
			XAlignment = Enum.TextXAlignment.Left,
		}),
		scope:New("Frame")({
			Name = "Chips",
			LayoutOrder = 3,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 18),
			AutomaticSize = Enum.AutomaticSize.Y,
			[scope.Children] = chips,
		}),
	}
	if not d.discovered then
		table.insert(items, statRow(scope, "Chance de relance", d.chanceText or "—", 4))
		return items
	end
	table.insert(items, statRow(scope, "Multiplicateur", d.multiplierText, 4))
	table.insert(items, statRow(scope, "Maîtrise", d.masteryText, 5))
	table.insert(
		items,
		scope:New("Frame")({
			Name = "MasteryBar",
			LayoutOrder = 6,
			Size = UDim2.new(1, 0, 0, 8),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.9,
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
				scope:New("Frame")({
					Size = UDim2.fromScale(d.masteryRatio, 1),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BorderSizePixel = 0,
					[scope.Children] = {
						scope:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
						scope:New("UIGradient")({
							Color = ColorSequence.new(Theme.Colors.Accent2, Theme.Colors.Accent),
						}),
					},
				}),
			},
		})
	)
	table.insert(items, statRow(scope, "Looks", d.looksText, 7))
	-- Le Style montre les looks de la principale : le bouton n'apparaît que pour elle
	if d.isPrincipal then
		table.insert(
			items,
			button(scope, "VOIR LES LOOKS", true, 8, function()
				deps.UiState.openWindow:set("Style")
			end)
		)
	end
	if d.canToggleDisplay then
		table.insert(
			items,
			button(scope, if d.displayed then "RETIRER" else "EXPOSER", false, 9, function()
				local display = snapshot.collection and snapshot.collection.display or {}
				deps.StateController.send(
					deps.Actions.SetDisplay or "SetDisplay",
					{ ids = BookModel.toggleDisplay(display, id) }
				)
			end)
		)
	elseif d.displayFullText then
		local full = button(scope, d.displayFullText, false, 9, function() end) :: TextButton
		full.Active = false
		full.AutoButtonColor = false
		full.TextTransparency = 0.45
		table.insert(items, full)
	end
	return items
end

local function baddiesTab(inner: any, deps: any, selected: any): Instance
	local sig = inner:Computed(function(use)
		return signature(use(deps.Store.snapshot))
	end)
	local grid = WindowHost.rows(inner, deps, signature, function(rowsScope, snapshot)
		local rows: { Instance } = {}
		if snapshot == nil then
			return rows
		end
		for i, data in BookModel.cards(snapshot, deps.Catalog, deps.Format.number) do
			table.insert(rows, card(rowsScope, data, selected, i))
		end
		return rows
	end)
	local detail = inner:Computed(function(use, detailScope)
		use(sig)
		local snapshot = deps.peek(deps.Store.snapshot)
		local id = use(selected)
		if snapshot == nil or id == nil then
			return {}
		end
		return detailPanel(detailScope, deps, snapshot, id)
	end)
	local collection = inner:Computed(function(use)
		local snapshot = use(deps.Store.snapshot)
		return if snapshot then BookModel.counts(snapshot, deps.Catalog) else nil
	end)

	return inner:New("Frame")({
		Name = "Baddies",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		[inner.Children] = {
			inner:New("ScrollingFrame")({
				Name = "Grid",
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.new(1, -DETAIL_WIDTH, 1, -40),
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 6,
				ScrollBarImageColor3 = Theme.Colors.PanelLine,
				[inner.Children] = {
					inner:New("UIPadding")({
						PaddingTop = UDim.new(0, 14),
						PaddingLeft = UDim.new(0, 16),
						PaddingRight = UDim.new(0, 16),
						PaddingBottom = UDim.new(0, 8),
					}),
					inner:New("UIGridLayout")({
						CellPadding = UDim2.fromOffset(10, 10),
						CellSize = UDim2.new(1 / COLUMNS, -8, 0, CARD_HEIGHT),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					grid,
				},
			}),
			inner:New("Frame")({
				Name = "Footer",
				BackgroundTransparency = 1,
				Position = UDim2.new(0, 16, 1, -34),
				Size = UDim2.new(1, -DETAIL_WIDTH - 32, 0, 24),
				[inner.Children] = {
					Text.label(inner, {
						Text = inner:Computed(function(use)
							local c = use(collection)
							return if c
								then `COLLECTION <font color="#FFFFFF">{c.baddies} / {c.baddiesTotal}</font>`
								else ""
						end),
						Weight = "ExtraBold",
						Color = Theme.Colors.TextDim,
						Size = UDim2.new(0, 150, 1, -6),
						RichText = true,
						Position = UDim2.fromOffset(0, 3),
						XAlignment = Enum.TextXAlignment.Left,
					}),
					inner:New("Frame")({
						Name = "Bar",
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 160, 0.5, 0),
						Size = UDim2.new(1, -160, 0, 8),
						BackgroundColor3 = Color3.new(1, 1, 1),
						BackgroundTransparency = 0.9,
						[inner.Children] = {
							inner:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
							inner:New("Frame")({
								BackgroundColor3 = Theme.Colors.Accent,
								BorderSizePixel = 0,
								Size = inner:Computed(function(use)
									local c = use(collection)
									local ratio = if c and c.baddiesTotal > 0
										then c.baddies / c.baddiesTotal
										else 0
									return UDim2.fromScale(ratio, 1)
								end),
								[inner.Children] = {
									inner:New("UICorner")({ CornerRadius = UDim.new(0, 4) }),
								},
							}),
						},
					}),
				},
			}),
			inner:New("Frame")({
				Name = "DetailLine",
				Position = UDim2.new(1, -DETAIL_WIDTH, 0, 0),
				Size = UDim2.new(0, 2, 1, 0),
				BackgroundColor3 = Theme.Colors.PanelLine,
				BackgroundTransparency = 0.82,
				BorderSizePixel = 0,
				ZIndex = 2,
			}),
			inner:New("ScrollingFrame")({
				Name = "Detail",
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, DETAIL_WIDTH, 1, 0),
				BackgroundColor3 = Theme.Colors.Accent,
				BackgroundTransparency = 0.96,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				ScrollBarThickness = 4,
				ScrollBarImageColor3 = Theme.Colors.PanelLine,
				[inner.Children] = {
					inner:New("UIPadding")({
						PaddingTop = UDim.new(0, 14),
						PaddingBottom = UDim.new(0, 14),
						PaddingLeft = UDim.new(0, 14),
						PaddingRight = UDim.new(0, 14),
					}),
					detail,
				},
			}),
		},
	})
end

local function crewTab(inner: any, deps: any): Instance
	return inner:New("ScrollingFrame")({
		Name = "Crew",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.PanelLine,
		[inner.Children] = {
			inner:New("UIListLayout")({ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
			inner:New("UIPadding")({
				PaddingTop = UDim.new(0, 14),
				PaddingBottom = UDim.new(0, 14),
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 18),
			}),
			WindowHost.rows(inner, deps, Crew.signature, function(rowsScope, snapshot)
				return Crew.rows(rowsScope, deps, snapshot)
			end),
		},
	})
end

function Book.start(scope: any, deps: any)
	local tab = scope:Value("baddies")
	local selected = scope:Value(nil)
	-- À chaque ouverture : onglet BADDIES, fiche de la principale
	scope:Observer(deps.UiState.openWindow):onChange(function()
		if deps.peek(deps.UiState.openWindow) == "Book" then
			tab:set("baddies")
			local snapshot = deps.peek(deps.Store.snapshot)
			local active = snapshot and snapshot.active
			selected:set(if type(active) == "table" then active.baddieId else nil)
		end
	end)

	WindowHost.mount(scope, deps, deps.HudRoot, {
		name = "Book",
		title = "BOOK",
		icon = "book",
		layout = "free",
		tabs = function(snapshot)
			local c = if snapshot
				then BookModel.counts(snapshot, deps.Catalog)
				else {
					baddies = 0,
					baddiesTotal = #deps.Catalog.baddieOrder,
					crew = 0,
					crewTotal = #deps.Catalog.crewOrder,
				}
			return {
				{ id = "baddies", label = "BADDIES", count = `{c.baddies}/{c.baddiesTotal}` },
				{ id = "crew", label = "CREW", count = `{c.crew}/{c.crewTotal}` },
			}
		end,
		activeTab = tab,
		onTab = function(id)
			tab:set(id)
		end,
		content = function(inner)
			return {
				inner:Computed(function(use, tabScope)
					return if use(tab) == "crew"
						then crewTab(tabScope, deps)
						else baddiesTab(tabScope, deps, selected)
				end),
			}
		end,
	})
end

return Book
