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
local RewardsModel = require(Client.Logic.RewardsModel)
local LayoutMode = require(Client.Logic.LayoutMode)
local HudLayout = require(Client.Logic.HudLayout)
local WindowModel = require(Client.Logic.WindowModel)
local Theme = require(Client.UI.Theme)
local Motion = require(Client.UI.Motion)
local Text = require(Client.UI.Text)
local Metrics = require(Client.UI.Metrics)
local Components = Client.UI.Components
local CounterPill = require(Components.CounterPill)
local MenuItem = require(Components.MenuItem)
local CharacterCard = require(Components.CharacterCard)
local ProgressCard = require(Components.ProgressCard)
local PrimaryButton = require(Components.PrimaryButton)
local Tile = require(Components.Tile)
local Icon = require(Components.Icon)
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
	-- Badge NEW du Crew : un compagnon arrivé depuis la dernière ouverture du Crew
	local crewBadge = scope:Value("")
	-- Badge du menu SLOTS : nombre de drops en attente (une décision attend le joueur)
	local slotsBadge = scope:Computed(function(use)
		local snapshot = use(deps.Store.snapshot)
		local drops = 0
		for _, count in (snapshot and snapshot.pendingDrops) or {} do
			drops += tonumber(count) or 0
		end
		return if drops > 0 then tostring(drops) else ""
	end)
	-- Badge du menu BONUS : tour gratuit, connexion du jour et paliers de temps de jeu à prendre
	local bonusBadge = scope:Computed(function(use)
		return RewardsModel.badge(use(deps.Store.snapshot))
	end)
	scope:Observer(UiState.openWindow):onChange(function()
		local name = deps.peek(UiState.openWindow)
		if name ~= nil then
			lastOpened:set(name)
		end
		if name == "Book" then
			bookBadge:set("")
		elseif name == "Crew" then
			crewBadge:set("")
		end
	end)
	-- Un combat qui commence ferme la fenêtre ouverte (elle cacherait l'arène)
	local playMode = scope:Computed(function(use)
		local snapshot = use(Store.snapshot)
		return snapshot and snapshot.mode
	end)
	scope:Observer(playMode):onChange(function()
		if WindowModel.closesOnMode(deps.peek(playMode)) then
			UiState.openWindow:set(nil)
		end
	end)

	local function menuItem(
		order: number,
		name: string,
		icon: string,
		label: string,
		gradient: { top: Color3, bottom: Color3 },
		badge: any?
	)
		return MenuItem(scope, {
			Icon = icon,
			Label = label,
			Gradient = gradient,
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
			Subject = scope:Computed(function(use)
				local c = use(data)
				return if c then { id = c.id, look = c.look } else nil
			end),
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

	-- Tuiles du menu : 96 (compact 72), jamais sous 48 px réels (même calcul que MenuItem)
	local touch = Metrics.touch(scope, Theme.MinTouch)
	local tileSide = scope:Computed(function(use)
		return math.max(if use(compact) then 72 else 96, use(touch) :: number)
	end)
	-- Barre « prochain ticket » au-dessus du bouton (stats.trainActions, Balance.tickets)
	local ticketProgress = scope:Computed(function(use)
		return HudModel.ticketProgress(use(Store.snapshot), deps.Balance.tickets.baddieEveryTrainActions)
	end)
	local ticketRatio = scope:Tween(
		scope:Computed(function(use)
			local p = use(ticketProgress)
			return if p.max > 0 then p.value / p.max else 0
		end),
		Motion.Fill
	)
	-- Tuile cadeau : secondes écoulées depuis le dernier snapshot (un seul compteur, 1 s)
	-- remis à zéro seulement quand le serveur envoie de nouvelles secondes de jeu (tick de 5 s),
	-- pas à chaque snapshot d'entraînement : sinon le minuteur se fige pendant les clics
	local since = scope:Value(0)
	local lastPlaytime: number? = nil
	scope:Observer(Store.snapshot):onChange(function()
		local seconds = RewardsModel.playtimeSeconds(deps.peek(Store.snapshot))
		if seconds ~= lastPlaytime then
			lastPlaytime = seconds
			since:set(0)
		end
	end)
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	task.spawn(function()
		while alive do
			task.wait(1)
			if alive then
				since:set(deps.peek(since) + 1)
			end
		end
	end)
	-- Positions calculées depuis les tailles réelles (téléphone : tuiles et bouton plus grands)
	local buttonHeight = Metrics.touch(scope, 84)
	local giftSide = scope:Computed(function(use)
		return math.max(76, use(touch) :: number)
	end)
	local layout = scope:Computed(function(use)
		local size: UDim2 = use(canvas)
		return HudLayout.compute(size.Y.Offset, use(tileSide), use(buttonHeight), use(giftSide))
	end)
	local giftText = scope:Computed(function(use)
		return RewardsModel.giftText(use(Store.snapshot), deps.Balance, use(since))
	end)
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
					-- Compteurs empilés en bas à gauche (spec §4.1)
					scope:New("Frame")({
						Name = "Counters",
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0, 16, 1, -14),
						Size = UDim2.fromOffset(300, 200),
						[scope.Children] = {
							scope:New("UIListLayout")({
								VerticalAlignment = Enum.VerticalAlignment.Bottom,
								Padding = UDim.new(0, 6),
								SortOrder = Enum.SortOrder.LayoutOrder,
							}),
							CounterPill(scope, {
								Name = "Power",
								Icon = "power",
								Pulse = UiState.trainPulse,
								LayoutOrder = 1,
								Text = scope:Computed(function(use)
									return use(view).powerText
								end),
							}),
							CounterPill(scope, {
								Name = "Tickets",
								Icon = "ticket",
								LayoutOrder = 2,
								Text = scope:Computed(function(use)
									return use(view).ticketText
								end),
							}),
							CounterPill(scope, {
								Name = "CrewTickets",
								Icon = "companionTicket",
								LayoutOrder = 3,
								Text = scope:Computed(function(use)
									return use(view).crewTicketText
								end),
							}),
							CounterPill(scope, {
								Name = "Coins",
								Icon = "coin",
								LayoutOrder = 4,
								Text = scope:Computed(function(use)
									return RewardsModel.coinsText(use(Store.snapshot), deps.Format.number)
								end),
							}),
						},
					}),
					-- Tuile cadeau (haut droite) : minuteur du prochain palier de temps de jeu, ouvre BONUS
					scope:New("TextButton")({
						Name = "Gift",
						Text = "",
						AutoButtonColor = false,
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(1, 0),
						Position = UDim2.new(1, -16, 0, 14),
						Size = scope:Computed(function(use)
							local side = use(giftSide)
							return UDim2.fromOffset(side, side)
						end),
						Visible = scope:Computed(function(use)
							return use(giftText) ~= ""
						end),
						[scope.OnEvent("Activated")] = function()
							UiState.openWindow:set("Bonus")
						end,
						[scope.Children] = {
							Tile(scope, {
								Gradient = Theme.Gradients.Bonus,
								Size = UDim2.fromScale(1, 1),
								Children = {
									Icon(scope, {
										Name = "gift",
										Size = UDim2.fromScale(0.66, 0.66),
										Position = UDim2.fromScale(0.5, 0.4),
										AnchorPoint = Vector2.new(0.5, 0.5),
										ZIndex = 3,
									}),
								},
							}),
							Text.label(scope, {
								Name = "Timer",
								Text = giftText,
								Weight = "Heavy",
								Stroke = true,
								Size = UDim2.new(1.2, 0, 0, 24),
								Position = UDim2.new(0.5, 0, 1, 8),
								AnchorPoint = Vector2.new(0.5, 1),
								ZIndex = 4,
							}),
						},
					}),
					scope:New("Frame")({
						Name = "Menu",
						BackgroundTransparency = 1,
						Position = scope:Computed(function(use)
							return UDim2.fromOffset(16, use(layout).menuTop)
						end),
						Size = scope:Computed(function(use)
							local side = use(tileSide) :: number
							return UDim2.fromOffset(side * 2 + 12, side * 3 + 28)
						end),
						[scope.Children] = {
							-- grille 2 × 3 de tuiles carrées (spec §4.1) ; 14 px entre lignes pour les libellés
							scope:New("UIGridLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								CellPadding = UDim2.fromOffset(12, 14),
								FillDirectionMaxCells = 2,
								CellSize = scope:Computed(function(use)
									local side = use(tileSide)
									return UDim2.fromOffset(side, side)
								end),
							}),
							menuItem(1, "Book", "book", "BOOK", Theme.Gradients.Book, bookBadge),
							menuItem(2, "Style", "style", "STYLE", Theme.Gradients.Style),
							menuItem(3, "Crew", "crew", "CREW", Theme.Gradients.Crew, crewBadge),
							menuItem(4, "Slots", "slots", "ÉQUIPE", Theme.Gradients.Slots, slotsBadge),
							menuItem(5, "Bonus", "bonus", "BONUS", Theme.Gradients.Bonus, bonusBadge),
							menuItem(6, "Settings", "settings", "RÉGLAGES", Theme.Gradients.Settings),
						},
					}),
					scope:New("Frame")({
						Name = "Cards",
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(1, 0),
						Position = scope:Computed(function(use)
							return UDim2.new(1, -16, 0, use(layout).cardsTop)
						end),
						Size = UDim2.fromOffset(150, 470),
						[scope.Children] = cards,
					}),
					ProgressCard(scope, {
						Model = scope:Computed(function(use)
							return use(view).progress
						end),
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 112),
					}),
					-- Barre « prochain ticket » au-dessus du bouton ENTRAÎNER
					scope:New("Frame")({
						Name = "TicketBar",
						AnchorPoint = Vector2.new(0.5, 1),
						Position = scope:Computed(function(use)
							return UDim2.new(0.5, 0, 1, use(layout).ticketBarOffset)
						end),
						Size = UDim2.fromOffset(260, 22),
						BackgroundColor3 = Theme.Colors.Panel,
						[scope.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
							scope:New("UIStroke")({
								Color = Theme.Colors.Ink,
								Thickness = Theme.Stroke.Frame,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							}),
							scope:New("Frame")({
								Name = "Fill",
								BackgroundColor3 = Color3.new(1, 1, 1),
								BorderSizePixel = 0,
								Size = scope:Computed(function(use)
									return UDim2.fromScale(math.clamp(use(ticketRatio), 0, 1), 1)
								end),
								[scope.Children] = {
									scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
									scope:New("UIGradient")({
										Rotation = 90,
										Color = ColorSequence.new(
											Theme.Gradients.Style.top,
											Theme.Gradients.Style.bottom
										),
									}),
								},
							}),
							Text.label(scope, {
								Name = "Label",
								Text = scope:Computed(function(use)
									local p = use(ticketProgress)
									return `Prochain ticket {p.value}/{p.max}`
								end),
								Weight = "Heavy",
								Stroke = true,
								StrokeThickness = Theme.Stroke.List,
								Size = UDim2.new(1, -12, 1, -4),
								Position = UDim2.fromScale(0.5, 0.5),
								AnchorPoint = Vector2.new(0.5, 0.5),
								ZIndex = 2,
							}),
						},
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
		if Motion.reduced() then
			return
		end
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
		elseif event.kind == "crewJoined" and deps.peek(UiState.openWindow) ~= "Crew" then
			crewBadge:set("NEW")
		end
		local text = HudModel.toastFor(event, deps.Catalog)
		if text then
			Toast.show(root, text, TOAST_ICON[event.kind])
		end
	end)
end

return HUD
