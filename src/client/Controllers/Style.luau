--!strict
--[[
	Style : garde-robe de la principale, style mix A (maquette windows-mixA.html).
	Onglets selon StyleModel.tabs : LOOKS (aperçu 300 px + 3 looks ; look 2 à maîtrise 1, look 3 à
	maîtrise 5), AURA et TITRE (lignes de la garde-robe débloquée, Shared/Wardrobe).
	Actions (SetLook, SetStyle) seulement hors combat et si le serveur envoie les données ;
	sinon lecture seule, sans faux bouton. Les états viennent de StyleModel (pur, testé).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local Text = require(Client.UI.Text)
local Metrics = require(Client.UI.Metrics)
local WindowHost = require(Client.UI.WindowHost)
local StyleModel = require(Client.Logic.StyleModel)
local ListRow = require(Client.UI.Components.ListRow)
local Chip = require(Client.UI.Components.Chip)
local ActionButton = require(Client.UI.Components.ActionButton)
local Icon = require(Client.UI.Components.Icon)
local Portrait = require(Client.UI.Components.Portrait)
local Wardrobe = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Wardrobe"))

local Style = {}

local DEFAULT_UNLOCK_AT = { 0, 1, 5 }
local PREVIEW_WIDTH = 300
local DARK = Color3.fromHex("#120F22")

local function thresholdsOf(deps: any): { number }
	return (deps.Balance.looks and deps.Balance.looks.unlockAtMastery) or DEFAULT_UNLOCK_AT
end

local function signature(snapshot: any): string
	if snapshot == nil then
		return "none"
	end
	local active = snapshot.active or {}
	local c = snapshot.collection
	local looks = c and c.looks and active.baddieId and c.looks[active.baddieId]
	local style = snapshot.style or {}
	local equippedKey = ""
	for _, slot in Wardrobe.slots do
		equippedKey ..= tostring(style.equipped and style.equipped[slot]) .. ";"
	end
	return table.concat({
		tostring(active.baddieId),
		tostring(snapshot.mode),
		if looks then table.concat(looks.unlocked or {}, ",") .. ":" .. tostring(looks.selected) else "v1",
		table.concat(style.items or {}, ","),
		table.concat(style.titles or {}, ","),
		tostring(style.title),
		tostring(#(style.achievements or {})),
		equippedKey,
	}, "|")
end

local function preview(scope: any, id: string, def: any, worn: StyleModel.LookRow?): Instance
	return scope:New("Frame")({
		Name = "Preview",
		Size = UDim2.new(0, PREVIEW_WIDTH, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		[scope.Children] = {
			scope:New("UIGradient")({
				Rotation = 90,
				Color = ColorSequence.new(Color3.fromHex("#221C3E"), DARK),
			}),
			Text.label(scope, {
				Text = string.upper(def.name),
				Weight = "Heavy",
				Size = UDim2.new(1, -32, 0, 32),
				Position = UDim2.fromOffset(16, 14),
				XAlignment = Enum.TextXAlignment.Left,
			}),
			Text.label(scope, {
				Text = if worn then `LOOK {worn.index} · {worn.name}` else "",
				Weight = "ExtraBold",
				Color = Theme.Colors.Accent,
				Size = UDim2.new(1, -32, 0, 15),
				Position = UDim2.fromOffset(16, 48),
				XAlignment = Enum.TextXAlignment.Left,
			}),
			-- socle néon
			scope:New("Frame")({
				Name = "Pedestal",
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -34),
				Size = UDim2.fromOffset(170, 22),
				BackgroundColor3 = Color3.fromHex("#2A2347"),
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
					scope:New("UIStroke")({ Color = Theme.Colors.Accent, Thickness = 2 }),
				},
			}),
			-- la principale en pied, dans le look porté
			Portrait(scope, {
				Subject = { id = id, look = if worn then worn.index else 1 },
				Mode = "full",
				Size = UDim2.new(1, 0, 1, -110),
				Position = UDim2.fromOffset(0, 66),
				Turn = 18,
			}),
		},
	})
end

local function lookRow(scope: any, deps: any, id: string, row: StyleModel.LookRow): Instance
	local height = Metrics.touch(scope, 44)
	local right: Instance
	if row.state == "worn" then
		right = scope:New("TextLabel")({
			Name = "Worn",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(84, 32),
			BackgroundColor3 = Theme.Colors.Accent,
			BackgroundTransparency = 0.85,
			Text = "PORTÉ",
			FontFace = Theme.Fonts.Heavy,
			TextSize = 14,
			TextColor3 = Theme.Colors.Accent,
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
				scope:New("UIStroke")({
					Color = Theme.Colors.Accent,
					Thickness = 2,
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				}),
			},
		})
	elseif row.state == "locked" then
		right = scope:New("Frame")({
			Name = "Locked",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = UDim2.fromOffset(130, 22),
			[scope.Children] = {
				Icon(scope, { Name = "lock", Size = UDim2.fromOffset(20, 20), Color = Theme.Colors.TextDim }),
				Text.label(scope, {
					Text = `MAÎTRISE {row.mastery}`,
					Weight = "ExtraBold",
					Color = Theme.Colors.TextDim,
					Size = UDim2.new(1, -28, 1, -4),
					Position = UDim2.fromOffset(28, 2),
					XAlignment = Enum.TextXAlignment.Left,
				}),
			},
		})
	elseif row.canWear then
		right = ActionButton(scope, {
			Name = "Wear",
			Text = "PORTER",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			Size = scope:Computed(function(use)
				return UDim2.fromOffset(120, use(height))
			end),
			OnClick = function()
				deps.StateController.send(deps.Actions.SetLook or "SetLook", { baddieId = id, look = row.index })
			end,
		})
	else
		-- débloqué mais action impossible (combat ou contrat v1) : pas de faux bouton
		right = Text.label(scope, {
			Text = "DÉBLOQUÉ",
			Weight = "ExtraBold",
			Color = Theme.Colors.TextDim,
			Size = UDim2.fromOffset(110, 18),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -14, 0.5, 0),
			XAlignment = Enum.TextXAlignment.Right,
		})
	end

	local worn = row.state == "worn"
	return scope:New("Frame")({
		Name = "Look" .. row.index,
		LayoutOrder = row.index,
		-- au moins la cible tactile + marges : sur petit téléphone, les boutons PORTER ne se chevauchent plus
		Size = scope:Computed(function(use)
			return UDim2.new(1, 0, 0, math.max(100, (use(height) :: number) + 16))
		end),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = if row.state == "locked" then 0.4 else 0,
		[scope.Children] = {
			scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Panel) }),
			scope:New("UIGradient")({
				Color = ColorSequence.new(Color3.fromHex("#262044"), Color3.fromHex("#16132A")),
			}),
			scope:New("UIStroke")({
				Color = if worn then Theme.Colors.Accent else Theme.Colors.PanelLine,
				Transparency = if worn then 0 else Theme.Transparency.PanelLine,
				Thickness = if worn and Theme.Glow == "" then 3 else 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			}),
			scope:New("Frame")({
				Name = "Thumb",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.5, 0),
				Size = UDim2.fromOffset(60, 84),
				BackgroundColor3 = DARK,
				ClipsDescendants = true,
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, 8) }),
					-- vignette du look : en pied ; verrouillé = silhouette noire (la tenue reste une surprise)
					Portrait(scope, {
						Subject = { id = id, look = row.index },
						Mode = "full",
						Locked = row.state == "locked",
					}),
				},
			}),
			Text.label(scope, {
				Text = `LOOK {row.index} · {row.name}`,
				Weight = "Heavy",
				Color = if row.state == "locked" then Theme.Colors.TextDim else Theme.Colors.Text,
				Size = UDim2.new(1, -240, 0, 24),
				Position = UDim2.fromOffset(86, 28),
				XAlignment = Enum.TextXAlignment.Left,
			}),
			Text.label(scope, {
				Text = if row.state == "locked"
					then `Débloqué à la maîtrise {row.mastery} de la principale`
					elseif row.index == 1 then "Look de départ"
					else `Débloqué à la maîtrise {row.mastery}`,
				Weight = "Bold",
				Color = Theme.Colors.TextDim,
				Size = UDim2.new(1, -240, 0, 15),
				Position = UDim2.fromOffset(86, 56),
				XAlignment = Enum.TextXAlignment.Left,
			}),
			right,
		},
	})
end

local function list(scope: any, children: { any }): Instance
	table.insert(
		children,
		scope:New("UIListLayout")({ Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder })
	)
	table.insert(
		children,
		scope:New("UIPadding")({
			PaddingTop = UDim.new(0, 14),
			PaddingBottom = UDim.new(0, 14),
			PaddingLeft = UDim.new(0, 16),
			PaddingRight = UDim.new(0, 18),
		})
	)
	return scope:New("ScrollingFrame")({
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.PanelLine,
		[scope.Children] = children,
	})
end

local function looksTab(scope: any, deps: any, snapshot: any): { Instance }
	local id = snapshot.active and snapshot.active.baddieId
	local def = id and deps.Catalog.baddies[id]
	if not def then
		return {}
	end
	local rows = StyleModel.lookRows(snapshot, deps.Catalog, thresholdsOf(deps))
	local worn: StyleModel.LookRow? = nil
	local items: { any } = {}
	for _, row in rows do
		if row.state == "worn" then
			worn = row
		end
		table.insert(items, lookRow(scope, deps, id, row))
	end
	local looks = list(scope, items)
	looks.Position = UDim2.fromOffset(PREVIEW_WIDTH + 2, 0)
	looks.Size = UDim2.new(1, -(PREVIEW_WIDTH + 2), 1, 0)
	return {
		preview(scope, id, def, worn),
		scope:New("Frame")({
			Name = "PreviewLine",
			Position = UDim2.fromOffset(PREVIEW_WIDTH, 0),
			Size = UDim2.new(0, 2, 1, 0),
			BackgroundColor3 = Theme.Colors.PanelLine,
			BackgroundTransparency = 0.82,
			BorderSizePixel = 0,
		}),
		looks,
	}
end

local function wardrobeTab(scope: any, deps: any, snapshot: any, slot: "aura" | "gear" | "title"): { Instance }
	local rows = if slot == "aura"
		then StyleModel.auraRows(snapshot, Wardrobe)
		elseif slot == "gear" then StyleModel.gearRows(snapshot, Wardrobe)
		else StyleModel.titleRows(snapshot, Wardrobe)
	local canAct = StyleModel.canAct(snapshot)
	local wearLabel = if slot == "title" then "AFFICHER" else "PORTER"
	local onLabel = if slot == "aura" then "PORTÉE" elseif slot == "gear" then "PORTÉ" else "AFFICHÉ"
	local items: { any } = {}
	for i, row in rows do
		local chips = {}
		if row.slotLabel then
			table.insert(chips, Chip(scope, { Text = string.upper(row.slotLabel), Color = Theme.Colors.TextDim }))
		end
		if row.equipped then
			table.insert(chips, Chip(scope, { Text = onLabel, Color = Theme.Colors.Accent }))
		end
		table.insert(
			items,
			ListRow(scope, {
				Portrait = string.sub(row.name, 1, 1),
				PortraitColor = if slot == "aura" then Theme.Colors.Style else Theme.Colors.Crew,
				Name = deps.Format.upper(row.name),
				Chips = chips,
				Description = if slot == "title"
					then "Affiché au-dessus de ton personnage"
					else "Apparence uniquement · aucune puissance",
				Selected = row.equipped,
				ActionLabel = if canAct then (if row.equipped then "RETIRER" else wearLabel) else nil,
				OnAction = function()
					deps.StateController.send(
						deps.Actions.SetStyle or "SetStyle",
						-- un accessoire vise son propre emplacement (cou, poignet…), aura et titre le leur
						{ slot = row.slot or slot, id = if row.equipped then nil else row.id }
					)
				end,
				LayoutOrder = i,
			})
		)
	end
	return { list(scope, items) }
end

-- Tous les succès : obtenus en tête, puis ce qu'il reste à faire et ce que ça débloque (§19)
local function achievementsTab(scope: any, deps: any, snapshot: any): { Instance }
	local items: { any } = {}
	for i, row in StyleModel.achievementRows(snapshot, Wardrobe) do
		table.insert(
			items,
			ListRow(scope, {
				Portrait = if row.earned then "OK" else tostring(i),
				PortraitColor = if row.earned then Theme.Colors.Principal else Theme.Colors.TextDim,
				Name = deps.Format.upper(row.name),
				Chips = {
					Chip(scope, {
						Text = if row.earned then "OBTENU" else "À FAIRE",
						Color = if row.earned then Theme.Colors.Principal else Theme.Colors.TextDim,
					}),
					Chip(scope, { Text = row.reward, Color = Theme.Colors.Slots }),
				},
				Description = row.condition,
				Selected = row.earned,
				Dimmed = not row.earned,
				LayoutOrder = if row.earned then i else 100 + i,
			})
		)
	end
	return { list(scope, items) }
end

function Style.start(scope: any, deps: any)
	local tab = scope:Value("looks")
	scope:Observer(deps.UiState.openWindow):onChange(function()
		if deps.peek(deps.UiState.openWindow) == "Style" then
			local tabs = StyleModel.tabs(deps.peek(deps.Store.snapshot), deps.Catalog, Wardrobe)
			tab:set(if tabs[1] then tabs[1].id else "looks")
		end
	end)

	WindowHost.mount(scope, deps, deps.HudRoot, {
		name = "Style",
		gradient = Theme.Gradients.Style,
		title = "STYLE",
		icon = "style",
		layout = "free",
		tabs = function(snapshot)
			return StyleModel.tabs(snapshot, deps.Catalog, Wardrobe)
		end,
		activeTab = tab,
		onTab = function(id)
			tab:set(id)
		end,
		content = function(inner)
			-- reconstruit l'onglet quand il change ou quand les données de style changent
			local sig = inner:Computed(function(use)
				return signature(use(deps.Store.snapshot))
			end)
			return {
				inner:Computed(function(use, tabScope)
					local current = use(tab)
					use(sig)
					local snapshot = deps.peek(deps.Store.snapshot)
					if snapshot == nil then
						return {}
					end
					if current == "aura" or current == "title" or current == "gear" then
						return wardrobeTab(tabScope, deps, snapshot, current)
					elseif current == "achievements" then
						return achievementsTab(tabScope, deps, snapshot)
					end
					return looksTab(tabScope, deps, snapshot)
				end),
			}
		end,
	})
end

return Style
