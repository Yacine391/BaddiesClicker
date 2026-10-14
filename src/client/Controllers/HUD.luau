--!strict
--[[
	HUD : écran principal du style V3 (maquette hud-v3c).
	Tous les textes viennent de HudModel.build(snapshot) : le HUD n'invente aucun chiffre.
	Le clic donne un retour immédiat (bouton qui s'écrase, « +1 ») ; la puissance affichée
	ne change qu'à l'arrivée du snapshot suivant.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local HudModel = require(Client.Logic.HudModel)
local Theme = require(Client.UI.Theme)
local Text = require(Client.UI.Text)
local Components = Client.UI.Components
local MenuTile = require(Components.MenuTile)
local BigStat = require(Components.BigStat)
local ActionButton = require(Components.ActionButton)
local FloatingNumber = require(Components.FloatingNumber)
local Toast = require(Components.Toast)

local HUD = {}

HUD.gui = nil :: ScreenGui?

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

local function principalPill(scope: any, view: any)
	local children: { any } = Theme.bevel(scope, Theme.Colors.Orange, 32)
	table.insert(
		children,
		scope:New("TextLabel")({
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.fromOffset(52, 52),
			BackgroundColor3 = Color3.fromHex("#3A2617"),
			Text = scope:Computed(function(use)
				local p = use(view).principal
				return if p then string.sub(p.name, 1, 1) else "?"
			end),
			TextScaled = true,
			FontFace = Theme.Fonts.Display,
			TextColor3 = Theme.Colors.Blanc,
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				scope:New("UIStroke")({
					Color = Theme.Colors.Contour,
					Thickness = Theme.Stroke.Frame,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			},
		})
	)
	table.insert(
		children,
		Text.label(scope, {
			Text = scope:Computed(function(use)
				local p = use(view).principal
				return if p then `{string.upper(p.name)} {p.multiplierText}` else ""
			end),
			Size = UDim2.new(1, -80, 0, 28),
			Position = UDim2.fromOffset(68, 6),
			XAlignment = Enum.TextXAlignment.Left,
		})
	)
	table.insert(
		children,
		Text.label(scope, {
			Text = scope:Computed(function(use)
				local p = use(view).principal
				return if p then `● {p.rarityLabel} · {p.slotText} · Principale` else ""
			end),
			Font = Theme.Fonts.Body,
			Size = UDim2.new(1, -80, 0, 18),
			Position = UDim2.fromOffset(68, 38),
			XAlignment = Enum.TextXAlignment.Left,
			StrokeSize = 2,
		})
	)
	return scope:New("Frame")({
		Name = "Principal",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(360, 64),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = scope:Computed(function(use)
			return use(view).principal ~= nil
		end),
		[scope.Children] = children,
	})
end

local function tutorialBar(scope: any, view: any)
	return scope:New("Frame")({
		Name = "Tutorial",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -136),
		Size = UDim2.fromOffset(240, 34),
		BackgroundColor3 = Theme.Colors.Nuit,
		Visible = scope:Computed(function(use)
			return use(view).tutorial.visible
		end),
		[scope.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }),
			scope:New("UIStroke")({ Color = Theme.Colors.Contour, Thickness = Theme.Stroke.Frame }),
			scope:New("Frame")({
				Name = "Fill",
				BackgroundColor3 = Theme.Colors.Cyan,
				Size = scope:Spring(
					scope:Computed(function(use)
						return UDim2.fromScale(use(view).tutorial.ratio, 1)
					end),
					25,
					0.8
				),
				[scope.Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, 12) }) },
			}),
			Text.label(scope, {
				Text = scope:Computed(function(use)
					return use(view).tutorial.text
				end),
				Font = Theme.Fonts.Body,
				Size = UDim2.new(1, -16, 1, -8),
				Position = UDim2.fromOffset(8, 4),
				ZIndex = 2,
			}),
		},
	})
end

function HUD.start(scope: any, deps: any)
	local Store, UiState, Input = deps.Store, deps.UiState, deps.Input
	local view = scope:Computed(function(use)
		return HudModel.build(use(Store.snapshot), deps.Catalog, deps.Format.number)
	end)
	local function textOf(field: string)
		return scope:Computed(function(use)
			return use(view)[field] or ""
		end)
	end
	local guiSize = scope:Value(Workspace.CurrentCamera.ViewportSize)
	local scale, canvas = viewportScale(scope, guiSize)

	local function open(name: string)
		return function()
			UiState.openWindow:set(name)
		end
	end

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
					principalPill(scope, view),
					scope:New("Frame")({
						Name = "Tiles",
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(24, 190),
						Size = UDim2.fromOffset(180, 200),
						[scope.Children] = {
							MenuTile(scope, {
								Name = "BOOK",
								Icon = Theme.Icons.Book,
								Color = Theme.Colors.Cyan,
								Position = UDim2.fromOffset(0, 0),
								OnClick = open("Book"),
							}),
							MenuTile(scope, {
								Name = "CREW",
								Icon = Theme.Icons.Crew,
								Color = Theme.Colors.Violet,
								Position = UDim2.fromOffset(92, 0),
								OnClick = open("Crew"),
							}),
							MenuTile(scope, {
								Name = "STYLE",
								Icon = Theme.Icons.Style,
								Color = Theme.Colors.Or,
								Position = UDim2.fromOffset(0, 104),
								OnClick = open("Style"),
							}),
							MenuTile(scope, {
								Name = "RÉGLAGES",
								Icon = Theme.Icons.Settings,
								Color = Theme.Colors.Gris,
								Position = UDim2.fromOffset(92, 104),
								OnClick = open("Settings"),
							}),
						},
					}),
					scope:New("Frame")({
						Name = "Stats",
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.new(0, 24, 1, -24),
						Size = UDim2.fromOffset(340, 140),
						[scope.Children] = {
							BigStat(scope, {
								Icon = Theme.Icons.Power,
								Text = textOf("powerText"),
								Pulse = UiState.trainPulse,
								Height = 56,
								Position = UDim2.fromOffset(0, 0),
							}),
							scope:New("Frame")({
								BackgroundTransparency = 1,
								Size = UDim2.fromOffset(340, 34),
								Position = UDim2.fromOffset(0, 64),
								Visible = scope:Computed(function(use)
									return use(view).productionText ~= nil
								end),
								[scope.Children] = {
									BigStat(scope, {
										Icon = Theme.Icons.DJ,
										Text = textOf("productionText"),
										Height = 34,
										Font = Theme.Fonts.Body,
									}),
								},
							}),
							BigStat(scope, {
								Icon = Theme.Icons.Ticket,
								Text = textOf("ticketText"),
								Height = 30,
								Font = Theme.Fonts.Body,
								Position = UDim2.fromOffset(0, 104),
							}),
						},
					}),
					tutorialBar(scope, view),
					ActionButton(scope, {
						Label = scope:Computed(function(use)
							return use(view).button.label
						end),
						Sub = scope:Computed(function(use)
							local s = use(Store.snapshot)
							return `+{deps.Format.number(if s then s.gainPerTrain or 0 else 0)} puissance`
						end),
						Icon = Theme.Icons.Power,
						Color = scope:Computed(function(use)
							return Theme.Colors[use(view).button.colorKey]
						end),
						Enabled = scope:Computed(function(use)
							return use(view).ready
						end),
						AnchorPoint = Vector2.new(1, 1),
						Position = UDim2.new(1, -24, 1, -24),
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
						BackgroundColor3 = Theme.Colors.Nuit,
						BackgroundTransparency = 0.3,
						Text = "Chargement…",
						FontFace = Theme.Fonts.Display,
						TextSize = 40,
						TextColor3 = Theme.Colors.Blanc,
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

	-- « +gain » qui s'envole au-dessus du bouton à chaque entraînement envoyé
	scope:Observer(UiState.trainPulse):onChange(function()
		local s = deps.peek(Store.snapshot)
		local gain = if s then s.gainPerTrain or 1 else 1
		FloatingNumber.spawn(
			root,
			"+" .. deps.Format.number(gain),
			UDim2.new(1, -144 + math.random(-30, 30), 1, -150)
		)
	end)

	deps.StateController.onResult(function(event)
		if event.kind == "crewJoined" then
			local def = deps.Catalog.crew[event.crewId]
			Toast.show(root, `{if def then def.name else "Un compagnon"} rejoint ton crew !`)
		elseif event.kind == "ticket" then
			local what = if event.ticket == "crew" then "compagnon" else "baddie"
			Toast.show(root, `+{event.amount or 1} ticket {what}`)
		end
	end)
end

return HUD
