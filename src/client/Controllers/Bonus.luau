--[[
	Bonus : fenêtre BONUS — roue du jour, connexion quotidienne et temps de jeu (décision du 11/11).

	- ROUE : un tour gratuit par jour, puis un jeton en réserve, puis des pièces ; les chances de chaque
	  part sont affichées avant le tour. Le serveur tire le gain ; la roue ne fait que s'arrêter dessus.
	  Une baddie gagnée arrive dans les DROPS (fenêtre SLOTS), jamais directement dans un slot.
	  Tour payant (Robux) proposé seulement si le serveur envoie `rewards.wheel.productId`.
	- CONNEXION : une récompense par jour, cycle de 7 jours.
	- TEMPS DE JEU : paliers du jour à réclamer.
	Les décisions passent par Controllers/Decisions ; textes et états viennent de Logic/RewardsModel (pur,
	testé). Les refus (« pas assez de pièces »…) sont annoncés par le toast commun des décisions (Slots).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local Text = require(Client.UI.Text)
local Metrics = require(Client.UI.Metrics)
local WindowHost = require(Client.UI.WindowHost)
local Chip = require(Client.UI.Components.Chip)
local ListRow = require(Client.UI.Components.ListRow)
local Toast = require(Client.UI.Components.Toast)
local RewardsModel = require(Client.Logic.RewardsModel)
local Decisions = require(script.Parent.Decisions)

local Bonus = {}

local SPIN_SECONDS = 3.2
local SPIN_TURNS = 5
local WHEEL = 330
local GOLD = Color3.fromHex("#D7A746")

Bonus.tab = nil :: any -- Value<string> : "wheel" | "daily" | "playtime" (LobbyWheel ouvre sur la roue)

local function signature(snapshot: any): string
	if snapshot == nil or snapshot.rewards == nil then
		return "none"
	end
	local r = snapshot.rewards
	local parts = {
		tostring(snapshot.coins),
		tostring(snapshot.saving),
		table.concat(snapshot.maintenance or {}, ","),
		tostring(r.day),
		tostring(r.wheel and r.wheel.free),
		tostring(r.wheel and r.wheel.tokens),
		tostring(r.wheel and r.wheel.productId),
		tostring(r.daily and r.daily.claimed),
		tostring(r.daily and r.daily.streak),
		-- minute par minute : les compteurs des listes n'ont pas besoin de plus
		tostring(math.floor((tonumber(r.playtime and r.playtime.seconds) or 0) / 20)),
		tostring(math.floor((tonumber(r.resetIn) or 0) / 60)),
	}
	for _, m in (r.playtime and r.playtime.milestones) or {} do
		table.insert(parts, `{m.claimed}:{m.ready}`)
	end
	return table.concat(parts, "|")
end

-- Bouton large (dégradé Accent, ou couleur donnée) ; grisé et inactif si `enabled` est faux
local function wideButton(scope: any, props: any): Instance
	local height = Metrics.touch(scope, props.Height or 44)
	return scope:New("TextButton")({
		Name = props.Name,
		LayoutOrder = props.LayoutOrder,
		Text = props.Text,
		FontFace = Theme.Fonts.Heavy,
		TextSize = props.TextSize or 18,
		TextColor3 = Theme.Colors.Ink,
		AutoButtonColor = props.Enabled,
		Active = props.Enabled,
		BackgroundColor3 = props.Color or Theme.Colors.Accent,
		BackgroundTransparency = if props.Enabled then 0 else 0.65,
		Visible = if props.Visible == nil then true else props.Visible,
		Size = scope:Computed(function(use)
			return UDim2.new(1, 0, 0, use(height))
		end),
		[scope.OnEvent("Activated")] = function()
			if props.Enabled then
				props.OnClick()
			end
		end,
		[scope.Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Button) }) },
	})
end

-- La roue : disque fixe, rotor (parts et séparations) qui tourne, pointeur en haut
local function wheelView(scope: any, segments: { RewardsModel.Segment }, rotation: any): Instance
	local count = #segments
	local rotorChildren: { any } = {}
	for _, segment in segments do
		local color = Color3.fromHex(segment.color)
		local angle = RewardsModel.segmentAngle(segment.index, count)
		-- rayon : un cadre centré sur le moyeu, tourné de `angle`, dont seule la moitié haute porte la part
		table.insert(
			rotorChildren,
			scope:New("Frame")({
				Name = "Spoke_" .. segment.id,
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, 76, 1, 0),
				Rotation = angle,
				[scope.Children] = {
					scope:New("Frame")({
						Name = "Prize",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 12),
						Size = UDim2.fromOffset(70, 58),
						BackgroundColor3 = color,
						BackgroundTransparency = 0.12,
						[scope.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, 10) }),
							scope:New("UIStroke")({
								Color = Theme.Colors.Ink,
								Thickness = 2,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							}),
							Text.label(scope, {
								Name = "Short",
								Text = segment.short,
								Weight = "Heavy",
								Color = Theme.Colors.Ink,
								Size = UDim2.new(1, -8, 0, 26),
								Position = UDim2.fromOffset(4, 6),
							}),
							Text.label(scope, {
								Name = "Caption",
								Text = segment.caption,
								Weight = "ExtraBold",
								Color = Theme.Colors.Ink,
								Size = UDim2.new(1, -6, 0, 13),
								Position = UDim2.fromOffset(3, 38),
							}),
						},
					}),
				},
			})
		)
		-- séparation entre cette part et la suivante
		table.insert(
			rotorChildren,
			scope:New("Frame")({
				Name = "Divider",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(0, 2, 1, -8),
				Rotation = angle + 180 / count,
				[scope.Children] = {
					scope:New("Frame")({
						Name = "Line",
						BorderSizePixel = 0,
						BackgroundColor3 = Theme.Colors.PanelLine,
						BackgroundTransparency = 0.55,
						Size = UDim2.fromScale(1, 0.5),
					}),
				},
			})
		)
	end

	return scope:New("Frame")({
		Name = "Wheel",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(22, 14),
		Size = UDim2.fromOffset(WHEEL, WHEEL),
		[scope.Children] = {
			scope:New("Frame")({
				Name = "Disc",
				Size = UDim2.fromScale(1, 1),
				BackgroundColor3 = Color3.fromHex("#16132A"),
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					scope:New("UIStroke")({
						Color = Theme.Colors.Accent,
						Thickness = 4,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
					scope:New("Frame")({
						Name = "Rotor",
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						Rotation = rotation,
						[scope.Children] = rotorChildren,
					}),
					scope:New("Frame")({
						Name = "Hub",
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(74, 74),
						BackgroundColor3 = Theme.Colors.Ink,
						ZIndex = 3,
						[scope.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
							scope:New("UIStroke")({
								Color = Theme.Colors.Accent2,
								Thickness = 3,
								ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
							}),
							Text.label(scope, {
								Text = "BONUS",
								Weight = "Heavy",
								Color = Theme.Colors.Accent,
								Size = UDim2.new(1, -14, 0, 18),
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								ZIndex = 4,
							}),
						},
					}),
				},
			}),
			-- pointeur fixe : losange rose qui mord le bord supérieur
			scope:New("Frame")({
				Name = "Pointer",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 0, 0, 4),
				Size = UDim2.fromOffset(26, 26),
				Rotation = 45,
				BackgroundColor3 = Theme.Colors.Accent2,
				ZIndex = 5,
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 5) }),
					scope:New("UIStroke")({
						Color = Theme.Colors.Ink,
						Thickness = 3,
						ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
					}),
				},
			}),
		},
	})
end

-- Liste défilante dans une fenêtre en disposition libre (mêmes marges que le gabarit Window)
local function scrollList(scope: any, rows: { any }): Instance
	return scope:New("ScrollingFrame")({
		Name = "List",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.PanelLine,
		BorderSizePixel = 0,
		[scope.Children] = {
			scope:New("UIListLayout")({ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
			scope:New("UIPadding")({
				PaddingTop = UDim.new(0, 14),
				PaddingBottom = UDim.new(0, 14),
				PaddingLeft = UDim.new(0, 16),
				PaddingRight = UDim.new(0, 18),
			}),
			rows,
		},
	})
end

local function note(scope: any, order: number, text: string): Instance
	return Text.label(scope, {
		Name = "Note",
		Text = text,
		Weight = "Bold",
		Color = Theme.Colors.TextDim,
		Size = UDim2.new(1, 0, 0, 18),
		XAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = order,
	})
end

function Bonus.start(scope: any, deps: any)
	local peek = deps.peek
	local tab = scope:Value("wheel")
	Bonus.tab = tab
	local segments = RewardsModel.segments(deps.Balance, deps.Catalog, deps.Format.number)
	local rotation = scope:Value(0) -- cible ; l'affichage la rejoint par un tween
	-- Créé une seule fois, hors du contenu de la fenêtre : le snapshot qui suit le tour reconstruit
	-- l'onglet, et un tween recréé à ce moment-là sauterait directement à la position finale
	local shown =
		scope:Tween(rotation, TweenInfo.new(SPIN_SECONDS, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))
	local spinning = scope:Value(false)
	local prize = scope:Value("")

	local function blocked(): boolean
		local snapshot = peek(deps.Store.snapshot)
		return snapshot == nil or snapshot.saving == true or Decisions.busy()
	end

	local function isOff(action: string): boolean
		local snapshot = peek(deps.Store.snapshot)
		return snapshot ~= nil and table.find(snapshot.maintenance or {}, action) ~= nil
	end

	local function spin(pay: string)
		if peek(spinning) or blocked() then
			return
		end
		if Decisions.send("SpinWheel", { pay = pay }) then
			spinning:set(true)
			prize:set("")
		end
	end

	local function wheelTab(tabScope: any, snapshot: any): { any }
		local view = RewardsModel.wheel(snapshot, deps.Balance, deps.Format.number)
		local off = isOff("SpinWheel")
		local idle = tabScope:Computed(function(use)
			return not use(spinning)
		end)
		local odds: { any } = {
			tabScope:New("UIListLayout")({ Padding = UDim.new(0, 1), SortOrder = Enum.SortOrder.LayoutOrder }),
		}
		for _, segment in segments do
			table.insert(
				odds,
				tabScope:New("Frame")({
					Name = "Odd_" .. segment.id,
					LayoutOrder = segment.index,
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 15),
					[tabScope.Children] = {
						tabScope:New("Frame")({
							Name = "Dot",
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.fromScale(0, 0.5),
							Size = UDim2.fromOffset(9, 9),
							BackgroundColor3 = Color3.fromHex(segment.color),
							[tabScope.Children] = {
								tabScope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
							},
						}),
						Text.label(tabScope, {
							Text = segment.label,
							Weight = "Bold",
							Color = Theme.Colors.TextDim,
							Size = UDim2.new(1, -74, 1, 0),
							Position = UDim2.fromOffset(16, 0),
							XAlignment = Enum.TextXAlignment.Left,
						}),
						Text.label(tabScope, {
							Text = segment.chance,
							Weight = "ExtraBold",
							Size = UDim2.new(0, 56, 1, 0),
							AnchorPoint = Vector2.new(1, 0),
							Position = UDim2.fromScale(1, 0),
							XAlignment = Enum.TextXAlignment.Right,
						}),
					},
				})
			)
		end

		local column: { any } = {
			tabScope:New("UIListLayout")({ Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }),
			Text.label(tabScope, {
				Text = "ROUE DU JOUR",
				Weight = "Heavy",
				Size = UDim2.new(1, 0, 0, 26),
				XAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 1,
			}),
			Text.label(tabScope, {
				Text = if off then "Roue coupée temporairement pour maintenance." else view.freeText,
				Weight = "Bold",
				Color = Theme.Colors.TextDim,
				Size = UDim2.new(1, 0, 0, 16),
				XAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 2,
			}),
			Text.label(tabScope, {
				Text = view.balanceText,
				Weight = "ExtraBold",
				Color = GOLD,
				Size = UDim2.new(1, 0, 0, 18),
				XAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 3,
			}),
			tabScope:Computed(function(use, buttonScope)
				local free = use(idle) and not off
				local buttons: { any } = {
					wideButton(buttonScope, {
						Name = "Spin",
						LayoutOrder = 4,
						Text = view.primary.label,
						Height = 50,
						TextSize = 21,
						Enabled = free and view.primary.enabled,
						OnClick = function()
							spin(view.primary.pay)
						end,
					}),
				}
				local coinsOption = view.coinsOption
				if coinsOption ~= nil then
					table.insert(
						buttons,
						wideButton(buttonScope, {
							Name = "SpinCoins",
							LayoutOrder = 5,
							Text = coinsOption.label,
							Color = GOLD,
							Height = 40,
							Enabled = free and coinsOption.enabled,
							OnClick = function()
								spin(coinsOption.pay)
							end,
						})
					)
				end
				local productId = view.productId
				if view.buyLabel ~= nil and productId ~= nil then
					table.insert(
						buttons,
						wideButton(buttonScope, {
							Name = "Buy",
							LayoutOrder = 6,
							Text = view.buyLabel,
							Color = Theme.Colors.Accent2,
							Height = 40,
							Enabled = free,
							OnClick = function()
								-- Roblox affiche sa propre confirmation d'achat ; le jeton arrive après le reçu
								MarketplaceService:PromptProductPurchase(Players.LocalPlayer, productId)
							end,
						})
					)
				end
				return buttons
			end),
			Text.label(tabScope, {
				Text = "CHANCES DE CHAQUE PART",
				Weight = "ExtraBold",
				Color = Theme.Colors.Accent,
				Size = UDim2.new(1, 0, 0, 15),
				XAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = 7,
			}),
			tabScope:New("Frame")({
				Name = "Odds",
				LayoutOrder = 8,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, #segments * 16),
				[tabScope.Children] = odds,
			}),
		}

		return {
			wheelView(tabScope, segments, shown),
			Text.label(tabScope, {
				Name = "Prize",
				Text = tabScope:Computed(function(use)
					local text = use(prize)
					if use(spinning) then
						return "La roue tourne…"
					end
					return if text ~= "" then text else "Une baddie gagnée arrive dans tes DROPS (SLOTS)."
				end),
				Weight = "ExtraBold",
				Color = tabScope:Computed(function(use)
					return if use(prize) ~= "" and not use(spinning)
						then Theme.Colors.Accent
						else Theme.Colors.TextDim
				end),
				Size = UDim2.fromOffset(WHEEL + 20, 20),
				Position = UDim2.fromOffset(12, WHEEL + 26),
			}),
			tabScope:New("Frame")({
				Name = "Column",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(WHEEL + 52, 12),
				Size = UDim2.new(1, -(WHEEL + 72), 1, -20),
				[tabScope.Children] = column,
			}),
		}
	end

	local STATE_CHIP = {
		claimed = { text = "REÇU", color = Theme.Colors.TextDim },
		today = { text = "AUJOURD'HUI", color = Theme.Colors.Principal },
		upcoming = { text = "À VENIR", color = Theme.Colors.TextDim },
		ready = { text = "PRÊT", color = Theme.Colors.Principal },
		locked = { text = "EN COURS", color = Theme.Colors.TextDim },
	}

	local function dailyTab(tabScope: any, snapshot: any): { any }
		local view = RewardsModel.daily(snapshot, deps.Balance)
		local off = isOff("ClaimDaily")
		local rows: { any } = { note(tabScope, 0, `{view.streakText} · {view.nextText}`) }
		for _, day in view.rows do
			local chip = STATE_CHIP[day.state]
			local claimable = day.state == "today" and view.canClaim and not off
			table.insert(
				rows,
				ListRow(tabScope, {
					Portrait = tostring(day.day),
					PortraitColor = if day.state == "today"
						then Theme.Colors.Accent
						else Theme.Colors.TextDim,
					Name = `JOUR {day.day}`,
					Chips = {
						Chip(tabScope, { Text = day.reward, Color = GOLD }),
						Chip(tabScope, { Text = chip.text, Color = chip.color }),
					},
					Selected = day.state == "today",
					Dimmed = day.state ~= "today",
					ActionLabel = if claimable then "RÉCLAMER" else nil,
					OnAction = function()
						if not blocked() then
							Decisions.send("ClaimDaily", {})
						end
					end,
					LayoutOrder = day.day,
				})
			)
		end
		return { scrollList(tabScope, rows) }
	end

	local function playtimeTab(tabScope: any, snapshot: any): { any }
		local off = isOff("ClaimPlaytime")
		local rows: { any } = {
			note(tabScope, 0, "Temps joué aujourd'hui. Les paliers repartent de zéro à minuit (UTC)."),
		}
		for _, row in RewardsModel.playtime(snapshot, deps.Balance) do
			local chip = STATE_CHIP[row.state]
			table.insert(
				rows,
				ListRow(tabScope, {
					Portrait = tostring(row.index),
					PortraitColor = if row.state == "ready"
						then Theme.Colors.Accent
						else Theme.Colors.TextDim,
					Name = row.title,
					Chips = {
						Chip(tabScope, { Text = row.reward, Color = GOLD }),
						Chip(tabScope, { Text = chip.text, Color = chip.color }),
					},
					Description = row.progress,
					Selected = row.state == "ready",
					Dimmed = row.state == "claimed",
					ActionLabel = if row.state == "ready" and not off then "RÉCLAMER" else nil,
					OnAction = function()
						if not blocked() then
							Decisions.send("ClaimPlaytime", { index = row.index })
						end
					end,
					LayoutOrder = row.index,
				})
			)
		end
		return { scrollList(tabScope, rows) }
	end

	WindowHost.mount(scope, deps, deps.HudRoot, {
		name = "Bonus",
		title = "BONUS",
		icon = "crown",
		layout = "free",
		tabs = function(snapshot)
			local rewards = (snapshot and snapshot.rewards) or {}
			local ready = 0
			for _, m in (rewards.playtime and rewards.playtime.milestones) or {} do
				if m.ready then
					ready += 1
				end
			end
			return {
				{
					id = "wheel",
					label = "ROUE",
					count = if rewards.wheel and rewards.wheel.free then "1" else nil,
				},
				{
					id = "daily",
					label = "CONNEXION",
					count = if rewards.daily and rewards.daily.claimed == false then "1" else nil,
				},
				{
					id = "playtime",
					label = "TEMPS DE JEU",
					count = if ready > 0 then tostring(ready) else nil,
				},
			}
		end,
		activeTab = tab,
		onTab = function(id)
			tab:set(id)
		end,
		content = function(inner)
			local sig = inner:Computed(function(use)
				return signature(use(deps.Store.snapshot))
			end)
			return {
				inner:Computed(function(use, tabScope)
					use(sig)
					local snapshot = peek(deps.Store.snapshot)
					local current = use(tab)
					if current == "daily" then
						return dailyTab(tabScope, snapshot)
					elseif current == "playtime" then
						return playtimeTab(tabScope, snapshot)
					end
					return wheelTab(tabScope, snapshot)
				end),
			}
		end,
	})

	-- Résultat du tour : la roue s'arrête sur la part tirée par le serveur, puis le gain est annoncé
	Decisions.onResult(function(event)
		if event.action ~= "SpinWheel" then
			return
		end
		local result = event.result
		if not event.ok or type(result) ~= "table" then
			spinning:set(false)
			return
		end
		rotation:set(RewardsModel.landingRotation(peek(rotation), result.index, #segments, SPIN_TURNS))
		task.delay(SPIN_SECONDS, function()
			local text = RewardsModel.prizeText(result, deps.Catalog)
			prize:set(text)
			spinning:set(false)
			if deps.HudRoot ~= nil and text ~= "" then
				Toast.show(deps.HudRoot, `Roue : {text}`, "ticket")
			end
		end)
	end)

	-- Récompenses réclamées, palier prêt, achat reçu
	deps.StateController.onResult(function(event)
		local text = RewardsModel.toastFor(event)
		if text ~= nil and deps.HudRoot ~= nil then
			Toast.show(deps.HudRoot, text, "ticket")
		end
	end)
end

return Bonus
