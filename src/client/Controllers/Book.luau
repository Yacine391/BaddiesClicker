--!strict
--[[
	Book : découvertes (§15). Distingue clairement PRINCIPALE (seule source de multiplicateur)
	et EXPOSÉE (apparence uniquement). Les actions d'exposition n'apparaissent que si le
	serveur envoie `collection` (contrat v2) ; en v1, lecture seule, sans faux bouton.
]]

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local WindowHost = require(Client.UI.WindowHost)
local HudModel = require(Client.Logic.HudModel)
local ListRow = require(Client.UI.Components.ListRow)
local Chip = require(Client.UI.Components.Chip)

local Book = {}

local MAX_DISPLAY = 3
local EXPOSED_TEXT = "Apparence uniquement · aucun multiplicateur"

local function displayName(catalog: any, id: string): string
	local def = catalog.baddies[id]
	if def then
		return string.upper(def.name)
	end
	return string.upper((string.gsub(id, "_", " "))) -- identités de test (Studio)
end

local function rarityChip(scope: any, catalog: any, id: string): Instance?
	local def = catalog.baddies[id]
	local rarity = def and catalog.rarities[def.rarity]
	if not rarity then
		return nil
	end
	return Chip(scope, { Text = "● " .. rarity.label, Color = Color3.fromHex(rarity.color) })
end

local function contains(list: { string }, id: string): boolean
	return table.find(list, id) ~= nil
end

local function baddieRows(scope: any, deps: any, snapshot: any): { Instance }
	local catalog, format = deps.Catalog, deps.Format.number
	local rows: { Instance } = {}
	if snapshot == nil then
		return rows
	end
	local view = HudModel.build(snapshot, catalog, format)
	local active = snapshot.active or {}
	local collection = snapshot.collection
	local display: { string } = if collection then collection.display or {} else {}
	local discovered: { string } = if collection
		then collection.discovered or {}
		else (if active.baddieId then { active.baddieId } else {})
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local tabs = {
		Chip(
			scope,
			{ Text = `BADDIES {view.bookCount.discovered}/{view.bookCount.total}`, Color = Theme.Colors.Or }
		),
		Chip(scope, {
			Text = `CREW {#(snapshot.crew or {})}/{#catalog.crewOrder}`,
			Color = Theme.Colors.Gris,
		}),
	}
	table.insert(
		rows,
		scope:New("Frame")({
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 26),
			LayoutOrder = nextOrder(),
			[scope.Children] = {
				scope:New("UIListLayout")({
					FillDirection = Enum.FillDirection.Horizontal,
					Padding = UDim.new(0, 8),
				}),
				tabs,
			},
		})
	)

	-- Principale
	if view.principal and active.baddieId then
		local id = active.baddieId
		local chips = { rarityChip(scope, catalog, id) :: any }
		table.insert(
			chips,
			Chip(scope, {
				Text = `PRINCIPALE · {string.upper(view.principal.slotText)}`,
				Color = Theme.Colors.Action,
			})
		)
		table.insert(chips, Chip(scope, { Text = view.principal.multiplierText, Color = Theme.Colors.Creme }))
		if contains(display, id) then
			table.insert(chips, Chip(scope, { Text = "EXPOSÉE", Color = Theme.Colors.Cyan }))
		end
		local looks = collection and collection.looks and collection.looks[id]
		local unlocked = if looks and looks.unlocked then #looks.unlocked else 1
		local total = #(catalog.baddies[id].looks or {})
		table.insert(
			rows,
			ListRow(scope, {
				Color = Theme.Colors.Orange,
				Portrait = string.sub(view.principal.name, 1, 1),
				Name = displayName(catalog, id),
				Chips = chips,
				ActionLabel = `LOOKS {unlocked}/{math.max(total, 1)}`,
				OnAction = function()
					deps.UiState.openWindow:set("Style")
				end,
				LayoutOrder = nextOrder(),
			})
		)
	end

	-- Autres découvertes (exposables si le contrat v2 est là)
	for _, id in discovered do
		if id ~= active.baddieId then
			local exposed = contains(display, id)
			local chips: { any } = {}
			local rc = rarityChip(scope, catalog, id)
			if rc then
				table.insert(chips, rc)
			end
			if exposed then
				table.insert(chips, Chip(scope, { Text = "EXPOSÉE", Color = Theme.Colors.Cyan }))
			end
			local canAct = collection ~= nil and (exposed or #display < MAX_DISPLAY)
			table.insert(
				rows,
				ListRow(scope, {
					Color = Theme.Colors.Gris,
					Portrait = string.sub(displayName(catalog, id), 1, 1),
					Name = displayName(catalog, id),
					Chips = chips,
					Description = if exposed then EXPOSED_TEXT else nil,
					ActionLabel = if canAct then (if exposed then "RETIRER" else "EXPOSER") else nil,
					OnAction = function()
						local ids = table.clone(display)
						if exposed then
							table.remove(ids, table.find(ids, id) :: number)
						else
							table.insert(ids, id)
						end
						deps.StateController.send(deps.Actions.SetDisplay or "SetDisplay", { ids = ids })
					end,
					LayoutOrder = nextOrder(),
				})
			)
		end
	end

	-- À découvrir (§15 : silhouette, rareté, chance)
	for _, id in catalog.baddieOrder do
		if not contains(discovered, id) then
			local def = catalog.baddies[id]
			local chips = { rarityChip(scope, catalog, id) :: any }
			table.insert(
				chips,
				Chip(scope, { Text = `{format(def.rollChance)} %`, Color = Theme.Colors.Creme })
			)
			table.insert(
				rows,
				ListRow(scope, {
					Color = Theme.Colors.Nuit,
					Portrait = Theme.Icons.Unknown.fallback,
					Name = "???",
					Chips = chips,
					Dimmed = true,
					LayoutOrder = nextOrder(),
				})
			)
		end
	end
	return rows
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
		tostring(#(snapshot.crew or {})),
		if c then table.concat(c.discovered or {}, ",") else "v1",
		if c then table.concat(c.display or {}, ",") else "",
	}, "|")
end

function Book.start(scope: any, deps: any)
	WindowHost.mount(scope, deps, deps.HudRoot, {
		name = "Book",
		title = "BOOK",
		icon = "book",
		content = function(inner)
			return {
				WindowHost.rows(inner, deps, signature, function(rowsScope, snapshot)
					return baddieRows(rowsScope, deps, snapshot)
				end),
			}
		end,
	})
end

return Book
