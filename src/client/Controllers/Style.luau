--!strict
--[[
	Style : les trois looks de la principale (§03). Look 2 à maîtrise 1, look 3 à maîtrise 5.
	Choisir un look n'est possible que si le serveur envoie `collection.looks` (contrat v2).
]]

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local WindowHost = require(Client.UI.WindowHost)
local ListRow = require(Client.UI.Components.ListRow)
local Chip = require(Client.UI.Components.Chip)

local Style = {}

-- Seuils proposés au contrat v2 (Balance.looks.unlockAtMastery quand le codeur A l'aura ajouté)
local DEFAULT_UNLOCK_AT = { 0, 1, 5 }

local function lookRows(scope: any, deps: any, snapshot: any): { Instance }
	local rows: { Instance } = {}
	local active = snapshot and snapshot.active
	local id = active and active.baddieId
	local def = id and deps.Catalog.baddies[id]
	if not def then
		return rows
	end
	local thresholds = (deps.Balance.looks and deps.Balance.looks.unlockAtMastery) or DEFAULT_UNLOCK_AT
	local collection = snapshot.collection
	local looks = collection and collection.looks and collection.looks[id]
	local unlocked: { number } = if looks and looks.unlocked then looks.unlocked else { 1 }
	local selected: number = if looks and looks.selected then looks.selected else 1

	for index, lookName in def.looks do
		local isUnlocked = table.find(unlocked, index) ~= nil
		local isSelected = index == selected
		local chips: { any } = {}
		if isSelected then
			table.insert(chips, Chip(scope, { Text = "PORTÉ", Color = Theme.Colors.Action }))
		end
		if not isUnlocked then
			table.insert(
				chips,
				Chip(scope, { Text = `Maîtrise {thresholds[index] or "?"}`, Color = Theme.Colors.Creme })
			)
		end
		table.insert(
			rows,
			ListRow(scope, {
				Color = if isSelected then Theme.Colors.Orange else Theme.Colors.Violet,
				Portrait = tostring(index),
				Name = `LOOK {index} · {string.upper(lookName)}`,
				Chips = chips,
				ActionLabel = if looks ~= nil and isUnlocked and not isSelected then "PORTER" else nil,
				OnAction = function()
					deps.StateController.send(
						deps.Actions.SetLook or "SetLook",
						{ baddieId = id, look = index }
					)
				end,
				Dimmed = not isUnlocked,
				LayoutOrder = index,
			})
		)
	end
	return rows
end

local function signature(snapshot: any): string
	if snapshot == nil then
		return "none"
	end
	local active = snapshot.active or {}
	local c = snapshot.collection
	local looks = c and c.looks and active.baddieId and c.looks[active.baddieId]
	return table.concat({
		tostring(active.baddieId),
		if looks then table.concat(looks.unlocked or {}, ",") .. ":" .. tostring(looks.selected) else "v1",
	}, "|")
end

function Style.start(scope: any, deps: any)
	WindowHost.mount(scope, deps, deps.HudRoot, {
		name = "Style",
		title = "STYLE",
		icon = Theme.Icons.Style,
		content = function(inner)
			return {
				WindowHost.rows(inner, deps, signature, function(rowsScope, snapshot)
					return lookRows(rowsScope, deps, snapshot)
				end),
			}
		end,
	})
end

return Style
