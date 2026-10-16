--[[
	Slots : fenêtre SLOTS (§11, §13, §14, §26) — onglets SLOTS, DROPS et RENAISSANCE.
	Remplace la partie « slots / drops / renaissance » du panneau de test F4.

	- Slots : principale, verrou de relance, RELANCER (1 ticket) avec confirmation du remplacement.
	- Drops en attente : ACCEPTER 1 (remplace le slot temporaire) ou REFUSER 1, avec confirmation.
	- Renaissance : ce qui est gardé, perdu et gagné, puis confirmation (run.id envoyé tel quel).
	Les décisions durables passent par Controllers/Decisions (requestId réutilisé, nouvel essai
	automatique) ; textes et états viennent de Logic/SlotsModel (pur, testé).
]]

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local Text = require(Client.UI.Text)
local Metrics = require(Client.UI.Metrics)
local WindowHost = require(Client.UI.WindowHost)
local Panel = require(Client.UI.Components.Panel)
local Chip = require(Client.UI.Components.Chip)
local Toast = require(Client.UI.Components.Toast)
local SlotsModel = require(Client.Logic.SlotsModel)
local Decisions = require(script.Parent.Decisions)

local Slots = {}

local CONFIRM_SECONDS = 4

type Button = { label: string, color: Color3, enabled: boolean, onClick: () -> () }

local function signature(snapshot: any): string
	if snapshot == nil then
		return "none"
	end
	local parts = {
		tostring(snapshot.mode),
		tostring(snapshot.saving),
		table.concat(snapshot.maintenance or {}, ","),
		tostring(snapshot.tickets and snapshot.tickets.baddie),
		tostring(snapshot.pendingRevision),
		tostring(snapshot.run and snapshot.run.id),
	}
	for _, slot in snapshot.slots or {} do
		table.insert(parts, `{slot.id}:{slot.baddieId}:{slot.revision}:{slot.rollLocked}:{slot.active}`)
	end
	local rebirth = snapshot.rebirth or {}
	table.insert(parts, `{rebirth.count}:{rebirth.available}:{rebirth.promotesNext}`)
	local rolls = snapshot.rolls or {}
	table.insert(parts, `{rolls.untilGuarantee}:{rolls.bookComplete}`)
	return table.concat(parts, "|")
end

-- Ligne : nom, puces, description et jusqu'à trois boutons à droite
local function row(
	scope: any,
	order: number,
	title: string,
	chips: { Instance },
	description: string,
	buttons: { Button },
	selected: boolean?
): Instance
	local height = Metrics.touch(scope, 40)
	local buttonViews = {}
	for index, b in buttons do
		table.insert(
			buttonViews,
			scope:New("TextButton")({
				Name = "Button" .. index,
				LayoutOrder = index,
				AutoButtonColor = b.enabled,
				Active = b.enabled,
				BackgroundColor3 = b.color,
				BackgroundTransparency = if b.enabled then 0 else 0.65,
				Size = scope:Computed(function(use)
					return UDim2.fromOffset(118, use(height))
				end),
				Text = b.label,
				FontFace = Theme.Fonts.Heavy,
				TextSize = 15,
				TextColor3 = Theme.Colors.Ink,
				[scope.OnEvent("Activated")] = function()
					if b.enabled then
						b.onClick()
					end
				end,
				[scope.Children] = {
					scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Button) }),
				},
			})
		)
	end
	table.insert(
		buttonViews,
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		})
	)
	local chipRow = table.clone(chips)
	table.insert(
		chipRow,
		scope:New("UIListLayout")({
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 6),
		})
	)
	return Panel(scope, {
		Name = "Row" .. order,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 104),
		Line = if selected then Theme.Colors.Accent else nil,
		Children = {
			Text.label(scope, {
				Name = "Title",
				Position = UDim2.fromOffset(14, 10),
				Size = UDim2.new(1, -420, 0, 24),
				Weight = "ExtraBold",
				XAlignment = Enum.TextXAlignment.Left,
				Text = title,
			}),
			scope:New("Frame")({
				Name = "Chips",
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(14, 40),
				Size = UDim2.new(1, -420, 0, 24),
				[scope.Children] = chipRow,
			}),
			Text.label(scope, {
				Name = "Description",
				Position = UDim2.fromOffset(14, 72),
				Size = UDim2.new(1, -420, 0, 18),
				Weight = "Bold",
				Color = Theme.Colors.TextDim,
				XAlignment = Enum.TextXAlignment.Left,
				Text = description,
			}),
			scope:New("Frame")({
				Name = "Buttons",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -12, 0.5, 0),
				Size = UDim2.new(0, 390, 1, -16),
				[scope.Children] = buttonViews,
			}),
		},
	})
end

local function message(scope: any, order: number, text: string): Instance
	return Text.label(scope, {
		Name = "Message" .. order,
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 22),
		Weight = "Bold",
		Color = Theme.Colors.TextDim,
		XAlignment = Enum.TextXAlignment.Left,
		Text = text,
	})
end

function Slots.start(scope: any, deps: any)
	Decisions.start(scope, deps)
	local tab = scope:Value("slots")
	local confirming = scope:Value(nil :: string?)
	local confirmToken = 0

	-- Premier clic : demande confirmation ; second clic (même bouton, < 4 s) : exécute
	local function confirmThen(key: string, run: () -> ())
		if deps.peek(confirming) == key then
			confirming:set(nil)
			run()
			return
		end
		confirming:set(key)
		confirmToken += 1
		local token = confirmToken
		task.delay(CONFIRM_SECONDS, function()
			if token == confirmToken and deps.peek(confirming) == key then
				confirming:set(nil)
			end
		end)
	end

	local function label(key: string, normal: string, confirm: string): string
		return if deps.peek(confirming) == key then confirm else normal
	end

	scope:Observer(deps.UiState.openWindow):onChange(function()
		if deps.peek(deps.UiState.openWindow) == "Slots" then
			confirming:set(nil)
			tab:set(if SlotsModel.dropCount(deps.peek(deps.Store.snapshot)) > 0 then "drops" else "slots")
		end
	end)

	local function slotsTab(rowsScope: any, snapshot: any): { Instance }
		local views = {}
		for index, r in SlotsModel.slotRows(snapshot, deps.Catalog, deps.Format.number) do
			local chips = {
				Chip(rowsScope, {
					Text = r.kind,
					Color = if r.kind == "CONSERVÉ" then Theme.Colors.Accent else Theme.Colors.TextDim,
				}),
				Chip(rowsScope, { Text = r.multiplierText, Color = Theme.Colors.Accent }),
			}
			if r.rarityLabel then
				table.insert(
					chips,
					Chip(
						rowsScope,
						{ Text = r.rarityLabel, Color = Color3.fromHex(r.rarityColor or "#FFFFFF") }
					)
				)
			end
			if r.active then
				table.insert(chips, Chip(rowsScope, { Text = "PRINCIPALE", Color = Theme.Colors.Principal }))
			end
			local rollKey = "roll:" .. r.id
			table.insert(
				views,
				row(rowsScope, index, `{r.label} · {r.name}`, chips, r.rollHint, {
					{
						label = "PRINCIPALE",
						color = Theme.Colors.Principal,
						enabled = not r.active and r.baddieId ~= nil and snapshot.mode ~= "combat",
						onClick = function()
							deps.StateController.send(
								deps.Actions.SetActive or "SetActive",
								{ slotId = r.id }
							)
						end,
					},
					{
						label = if r.rollLocked then "DÉVERROUILLER" else "VERROUILLER",
						color = Theme.Colors.TextDim,
						enabled = true,
						onClick = function()
							deps.StateController.send(
								deps.Actions.SetRollLock or "SetRollLock",
								{ slotId = r.id, locked = not r.rollLocked }
							)
						end,
					},
					{
						label = label(rollKey, "RELANCER", "CONFIRMER ?"),
						color = if deps.peek(confirming) == rollKey
							then Theme.Colors.Accent2
							else Theme.Colors.Accent,
						enabled = r.canRoll,
						onClick = function()
							confirmThen(rollKey, function()
								Decisions.send("Roll", { slotId = r.id, slotRevision = r.revision })
							end)
						end,
					},
				}, r.active)
			)
		end
		table.insert(
			views,
			message(
				rowsScope,
				100,
				"Relancer remplace le contenu du slot (même conservé). Le verrou empêche une relance par erreur."
			)
		)
		return views
	end

	local function dropsTab(rowsScope: any, snapshot: any): { Instance }
		local views = {}
		local rows = SlotsModel.dropRows(snapshot, deps.Catalog, deps.Format.number)
		if #rows == 0 then
			table.insert(
				views,
				message(
					rowsScope,
					1,
					"Aucun drop en attente. Chaque victoire contre un boss : 10 % de chance, aucune garantie."
				)
			)
			return views
		end
		for index, r in rows do
			local chips = {
				Chip(rowsScope, { Text = `×{r.count} en attente`, Color = Theme.Colors.TextDim }),
				Chip(rowsScope, { Text = r.multiplierText, Color = Theme.Colors.Accent }),
			}
			if r.rarityLabel then
				table.insert(
					chips,
					Chip(
						rowsScope,
						{ Text = r.rarityLabel, Color = Color3.fromHex(r.rarityColor or "#FFFFFF") }
					)
				)
			end
			if r.isNew then
				table.insert(chips, Chip(rowsScope, { Text = "NOUVELLE", Color = Theme.Colors.Accent2 }))
			end
			local acceptKey, refuseKey = "accept:" .. r.baddieId, "refuse:" .. r.baddieId
			table.insert(
				views,
				row(rowsScope, index, r.name, chips, r.replaceText, {
					{
						label = label(refuseKey, "REFUSER 1", "SUPPRIMER ?"),
						color = if deps.peek(confirming) == refuseKey
							then Theme.Colors.Close
							else Theme.Colors.TextDim,
						enabled = SlotsModel.blocked(snapshot, "RefuseDrop") == nil,
						onClick = function()
							confirmThen(refuseKey, function()
								Decisions.send(
									"RefuseDrop",
									{ baddieId = r.baddieId, pendingRevision = r.pendingRevision }
								)
							end)
						end,
					},
					{
						label = label(acceptKey, "ACCEPTER 1", "CONFIRMER ?"),
						color = if deps.peek(confirming) == acceptKey
							then Theme.Colors.Accent2
							else Theme.Colors.Accent,
						enabled = r.canAccept,
						onClick = function()
							confirmThen(acceptKey, function()
								Decisions.send("AcceptDrop", {
									baddieId = r.baddieId,
									slotRevision = r.slotRevision,
									pendingRevision = r.pendingRevision,
								})
							end)
						end,
					},
				})
			)
		end
		table.insert(
			views,
			message(
				rowsScope,
				100,
				"Un drop n'expire jamais. Accepter remplace uniquement le slot temporaire."
			)
		)
		return views
	end

	local function rebirthTab(rowsScope: any, snapshot: any): { Instance }
		local view = SlotsModel.rebirthView(snapshot, deps.Catalog)
		local key = "rebirth"
		return {
			row(
				rowsScope,
				1,
				view.title,
				{
					Chip(rowsScope, {
						Text = if view.available then "DISPONIBLE" else "TERMINE LE NIVEAU 10",
						Color = if view.available then Theme.Colors.Principal else Theme.Colors.TextDim,
					}),
				},
				view.rewards,
				{
					{
						label = label(key, "RENAÎTRE", "CONFIRMER ?"),
						color = if deps.peek(confirming) == key
							then Theme.Colors.Accent2
							else Theme.Colors.Accent,
						enabled = view.available,
						onClick = function()
							confirmThen(key, function()
								Decisions.send("Rebirth", { expectedRunId = view.runId })
							end)
						end,
					},
				}
			),
			message(rowsScope, 2, view.keep),
			message(rowsScope, 3, view.lose),
		}
	end

	WindowHost.mount(scope, deps, deps.HudRoot, {
		name = "Slots",
		title = "SLOTS",
		icon = "ticket",
		tabs = function(snapshot)
			local drops = SlotsModel.dropCount(snapshot)
			return {
				{ id = "slots", label = "SLOTS", count = tostring(#((snapshot and snapshot.slots) or {})) },
				{ id = "drops", label = "DROPS", count = tostring(drops) },
				{ id = "rebirth", label = "RENAISSANCE" },
			}
		end,
		activeTab = tab,
		onTab = function(id)
			confirming:set(nil)
			tab:set(id)
		end,
		content = function(inner)
			local sig = inner:Computed(function(use)
				return signature(use(deps.Store.snapshot))
			end)
			return {
				inner:Computed(function(use, rowsScope)
					use(sig)
					use(confirming)
					local snapshot = deps.peek(deps.Store.snapshot)
					local current = use(tab)
					if current == "drops" then
						return dropsTab(rowsScope, snapshot)
					elseif current == "rebirth" then
						return rebirthTab(rowsScope, snapshot)
					end
					return slotsTab(rowsScope, snapshot)
				end),
			}
		end,
	})

	-- Réponses finales des décisions (après nouveaux essais éventuels)
	Decisions.onResult(function(event)
		local text = SlotsModel.resultText(event, deps.Catalog)
		if text ~= nil and deps.HudRoot ~= nil then
			Toast.show(deps.HudRoot, text, if event.action == "OpenChest" then "crew" else "ticket")
		end
	end)
end

return Slots
