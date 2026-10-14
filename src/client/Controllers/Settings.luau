--!strict
--[[
	Settings : réglages locaux (§21, §22) — effets réduits, suiveurs des autres, maintien du clic.
	Non sauvegardés en P0 (le contrat ne les transporte pas encore).
]]

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local WindowHost = require(Client.UI.WindowHost)
local ListRow = require(Client.UI.Components.ListRow)
local Chip = require(Client.UI.Components.Chip)

local Settings = {}

local ENTRIES = {
	{ key = "reducedEffects", label = "EFFETS RÉDUITS", hint = "Auras et particules atténuées" },
	{
		key = "showOthersFollowers",
		label = "SUIVEURS DES AUTRES",
		hint = "Afficher les équipes des autres joueurs",
	},
	{
		key = "holdToTrain",
		label = "MAINTIEN DU CLIC",
		hint = "Garder le bouton appuyé : 3 entraînements/s",
	},
}

function Settings.start(scope: any, deps: any)
	local settings = deps.UiState.settings
	WindowHost.mount(scope, deps, deps.HudRoot, {
		name = "Settings",
		title = "RÉGLAGES",
		icon = Theme.Icons.Settings,
		content = function(inner)
			local rows = {}
			for index, entry in ENTRIES do
				table.insert(
					rows,
					inner:Computed(function(use, rowScope)
						local on: boolean = use(settings[entry.key])
						return ListRow(rowScope, {
							Color = if on then Theme.Colors.Cyan else Theme.Colors.Gris,
							Portrait = if on then "✅" else "⬜",
							Name = entry.label,
							Chips = { Chip(rowScope, { Text = entry.hint, Color = Theme.Colors.Creme }) },
							ActionLabel = if on then "OUI" else "NON",
							OnAction = function()
								settings[entry.key]:set(not deps.peek(settings[entry.key]))
							end,
							LayoutOrder = index,
						})
					end)
				)
			end
			return rows
		end,
	})
end

return Settings
