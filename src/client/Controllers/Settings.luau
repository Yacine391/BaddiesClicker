--!strict
--[[
	Settings : réglages locaux (§21, §22) — effets réduits, suiveurs des autres, maintien du clic.
	Lignes à interrupteur (Accent OUI / gris NON). Non sauvegardés en P0 (le contrat ne les transporte pas).
]]

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local WindowHost = require(Client.UI.WindowHost)
local ListRow = require(Client.UI.Components.ListRow)

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
		icon = "settings",
		content = function(inner)
			local rows = {}
			for index, entry in ENTRIES do
				table.insert(
					rows,
					inner:Computed(function(use, rowScope)
						local on: boolean = use(settings[entry.key])
						return ListRow(rowScope, {
							Portrait = string.sub(entry.label, 1, 1),
							PortraitColor = if on then Theme.Colors.Accent else Theme.Colors.TextDim,
							Name = entry.label,
							Chips = {},
							Description = entry.hint,
							Toggle = on,
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
