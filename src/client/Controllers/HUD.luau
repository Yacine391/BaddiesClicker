--!strict
--[[
	HUD : écran principal du style mix A (maquette hud-mix.html, variante A ; spec refonte §4).
	Tous les textes viennent de HudModel.build(snapshot) : le HUD n'invente aucun chiffre.
	Le clic donne un retour immédiat (bouton qui s'écrase, « +1 puissance », compteur qui pop) ;
	la puissance affichée ne change qu'à l'arrivée du snapshot suivant.
	Mode compact (échelle < 0,6, LayoutMode) : menu en grille 2 × 2, cartes réduites au bandeau.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local HudModel = require(Client.Logic.HudModel)
local LayoutMode = require(Client.Logic.LayoutMode)
local Theme = require(Client.UI.Theme)
local Text = require(Client.UI.Text)
local Metrics = require(Client.UI.Metrics)
local Components = Client.UI.Components
local CounterPill = require(Components.CounterPill)
local MenuItem = require(Components.MenuItem)
local CharacterCard = require(Components.CharacterCard)
local ProgressCard = require(Components.ProgressCard)
local PrimaryButton = require(Components.PrimaryButton)
local FloatingNumber = require(Components.FloatingNumber)
local Toast = require(Components.Toast)

local HUD = {}

HUD.gui = nil :: ScreenGui?

local MAX_CARDS = 3 -- principale + 2 compagnons
local TOAST_ICON = { ticket = "ticket", crewJoined = "crew" }

-- `size` suit l'AbsoluteSize réelle du ScreenGui (zones sûres déjà retirées), pas la caméra
local function viewportScale(scope: any, size: any)
	local scale = scope:Computed(function(use)
		local v: Vector2 = use(size)
		return math.min(v.X / Theme.BaseResolution.X, v.Y / Theme.BaseResolution.Y)
	end)
	local canvas = scope:Computed(function(use)
		local v: Vector2 = use(size)
		local k = math.max(use(scale), 0.01)
		return UDim2.fromOffset(v.X / k, v.Y / k)
	end)
	return scale, canvas
end

-- Logo uploadé (assets/ui/png/logo.png) ; repli : « BADDIE » blanc + « CLICKER » cyan, incliné
local function logo(scope: any)
	if Theme.Logo ~= "" then
		return scope:New("ImageLabel")({
			Name = "Logo",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.fromOffset(300, 120),
			Image = Theme.Logo,
			ScaleType = Enum.ScaleType.Fit,
		})
	end
	return scope:New("Frame")({
		Name = "Logo",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.fromOffset(240, 96),
		Rotation = -6,
		[scope.Children] = {
			Text.label(scope, {
				Text = "BADDIE",
				Weight = "Heavy",
				Stroke = true,
				Size = UDim2.new(1, 0, 0, 54),
				XAlignment = Enum.TextXAlignment.Left,
			}),
			Text.label(scope, {
				Text = "CLICKER",
				Weight = "Heavy",
				Stroke = true,
				Color = Theme.Colors.Accent,
				Size = UDim2.new(0.8, 0, 0, 38),
				Position = UDim2.fromOffset(40, 52),
				XAlignment = Enum.TextXAlignment.Left,
			}),
		},
	})
end

function HUD.start(scope: any, deps: any)
	local Store, UiState, Input = deps.Store, deps.UiState, deps.Input
	local view = scope:Computed(function(use)
		return HudModel.build(use(Store.snapshot), deps.Catalog, deps.Format.number)
	end)
	local guiSize = scope:Value(Workspace.CurrentCamera.ViewportSize)
	local scale, canvas = viewportScale(scope, guiSize)
	Metrics.scale = scale
	local mode = scope:Computed(function(use)
		return LayoutMode.mode(use(scale))
	end)
	deps.LayoutMode = mode -- les fenêtres s'en servent aussi
	local compact = scope:Computed(function(use)
		return use(mode) == "compact"
	end)

	-- Entrée de menu active : la fenêtre ouverte, sinon la dernière ouverte
	local lastOpened = scope:Value(nil)
	-- Badge NEW du Book : une découverte arrivée depuis la dernière ouverture du Book
	local bookBadge = scope:Value("")
	-- Badge du menu SLOTS : nombre de drops en attente (une décision attend le joueur)
	local slotsBadge = scope:Computed(function(use)
		local snapshot = use(deps.Store.snapshot)
		local drops = 0
		for _, count in (snapshot and snapshot.pendingDrops) or {} do
			drops += tonumber(count) or 0
		end
		return if drops > 0 then tostring(drops) else ""
	end)
	scope:Observer(UiState.openWindow):onChange(function()
		local name = deps.peek(UiState.openWindow)
		if name ~= nil then
			lastOpened:set(name)
		end
		if name == "Book" then
			bookBadge:set("")
		end
	end)

	local function menuItem(
		order: number,
		name: string,
		icon: string,
		label: string,
		color: Color3,
		badge: any?
	)
		return MenuItem(scope, {
			Icon = icon,
			Label = label,
			Color = color,
			Mode = mode,
			Active = scope:Computed(function(use)
				return (use(UiState.openWindow) or use(lastOpened)) == name
			end),
			Badge = badge,
			LayoutOrder = order,
			OnClick = function()
				UiState.openWindow:set(name)
			end,
		})
	end

	local function card(index: number)
		local data = scope:Computed(function(use)
			return use(view).cards[index]
		end)
		local function field(key: string)
			return scope:Computed(function(use)
				local c = use(data)
				return if c then c[key] else ""
			end)
		end
		return CharacterCard(scope, {
			Rarity = scope:Computed(function(use)
				local c = use(data)
				return if c then c.rarity else nil
			end),
			Name = field("name"),
			Line1 = field("line1"),
			Line2 = field("line2"),
			Accent = scope:Computed(function(use)
				local c = use(data)
				return if c then Color3.fromHex(c.accent) else Theme.Colors.PanelLine
			end),
			Mode = mode,
			LayoutOrder = index,
			Visible = scope:Computed(function(use)
				return use(data) ~= nil
			end),
		})
	end
	local cards: { any } = {
		scope:New("UIListLayout")({
			Padding = UDim.new(0, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
		}),
	}
	for i = 1, MAX_CARDS do
		table.insert(cards, card(i))
	end

	local menuHeight = Metrics.touch(scope, 54)
	local root
	local gui = scope:New("ScreenGui")({
		Name = "HUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		[scope.Out("AbsoluteSize")] = guiSize,
		[scope.Children] = {
			scope:New("Frame")({
				Name = "Root",
				BackgroundTransparency = 1,
				Size = canvas,
				[scope.Children] = {
					scope:New("UIScale")({ Scale = scale }),
					logo(scope),
					scope:New("Frame")({
						Name = "Counters",
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -16, 0, 14),
						Size = UDim2.fromOffset(500, 46),
						[scope.Children] = {
							scope:New("UIListLayout")({
								FillDirection = Enum.FillDirection.Horizontal,
								HorizontalAlignment = Enum.HorizontalAlignment.Right,
								Padding = UDim.new(0, 10),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							CounterPill(scope, {
								Name = "Power",
								Icon = "arm",
								Glow = true,
								Pulse = UiState.trainPulse,
								LayoutOrder = 1,
								Text = scope:Computed(function(use)
									return use(view).powerText
								end),
							}),
							CounterPill(scope, {
								Name = "Tickets",
								Icon = "ticket",
								Glow = false,
								LayoutOrder = 2,
								Text = scope:Computed(function(use)
									return use(view).ticketText
								end),
							}),
						},
					}),
					scope:New("Frame")({
						Name = "Menu",
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(16, 150),
						Size = UDim2.fromOffset(240, 400),
						[scope.Children] = {
							-- full : une colonne de lignes 236 × h ; compact : grille 2 × 2 de tuiles h × h
							scope:New("UIGridLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								CellPadding = UDim2.fromOffset(10, 10),
								FillDirectionMaxCells = scope:Computed(function(use)
									return if use(compact) then 2 else 1
								end),
								CellSize = scope:Computed(function(use)
									local h = use(menuHeight)
									return if use(compact)
										then UDim2.fromOffset(h, h)
										else UDim2.fromOffset(236, h)
								end),
							}),
							menuItem(1, "Book", "book", "BOOK", Theme.Colors.Book, bookBadge),
							menuItem(2, "Slots", "ticket", "SLOTS", Theme.Colors.Slots, slotsBadge),
							menuItem(3, "Crew", "crew", "CREW", Theme.Colors.Crew),
							menuItem(4, "Style", "style", "STYLE", Theme.Colors.Style),
							menuItem(5, "Settings", "settings", "RÉGLAGES", Theme.Colors.Settings),
						},
					}),
					scope:New("Frame")({
						Name = "Cards",
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -16, 0, 74),
						Size = UDim2.fromOffset(150, 520),
						[scope.Children] = cards,
					}),
					ProgressCard(scope, {
						Model = scope:Computed(function(use)
							return use(view).progress
						end),
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0, 16, 1, -16),
					}),
					PrimaryButton(scope, {
						Label = scope:Computed(function(use)
							return use(view).button.label
						end),
						ColorKey = scope:Computed(function(use)
							return use(view).button.colorKey
						end),
						Enabled = scope:Computed(function(use)
							return use(view).ready
						end),
						AnchorPoint = Vector2.new(0.5, 1),
						Position = UDim2.new(0.5, 0, 1, -18),
						OnActivated = function()
							if not deps.peek(UiState.settings.holdToTrain) then
								Input.train()
							end
						end,
						OnPress = Input.beginHold,
						OnRelease = Input.endHold,
					}),
					scope:New("TextLabel")({
						Name = "Loading",
						Size = UDim2.fromScale(1, 1),
						BackgroundColor3 = Theme.Colors.Panel,
						BackgroundTransparency = 0.2,
						Text = "Chargement…",
						FontFace = Theme.Fonts.Heavy,
						TextSize = 40,
						TextColor3 = Theme.Colors.Text,
						ZIndex = 50,
						Visible = scope:Computed(function(use)
							return not use(view).ready
						end),
					}),
				},
			}),
		},
	}) :: ScreenGui
	root = gui:FindFirstChild("Root") :: Frame
	deps.HudRoot = root -- les fenêtres se montent ici (même UIScale que le HUD)
	HUD.gui = gui

	-- « +gain puissance » qui monte au-dessus du bouton à chaque entraînement envoyé
	scope:Observer(UiState.trainPulse):onChange(function()
		local s = deps.peek(Store.snapshot)
		local gain = if s then s.gainPerTrain or 1 else 1
		FloatingNumber.spawn(
			root,
			`+{deps.Format.number(gain)} puissance`,
			UDim2.new(0.5, math.random(-24, 24), 1, -120),
			Theme.Colors.Accent
		)
	end)

	-- Toasts : seulement « +1 copie » et tickets (le nouveau compagnon a la bannière RGB du codeur A)
	deps.StateController.onResult(function(event)
		if event.kind == "discovery" and deps.peek(UiState.openWindow) ~= "Book" then
			bookBadge:set("NEW")
		end
		local text = HudModel.toastFor(event, deps.Catalog)
		if text then
			Toast.show(root, text, TOAST_ICON[event.kind])
		end
	end)
end

return HUD
