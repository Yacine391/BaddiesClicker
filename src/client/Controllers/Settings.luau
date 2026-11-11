--!strict
--[[
	Settings : réglages (§21, §22) — effets réduits, suiveurs des autres, maintien du clic, sons, musique.
	Lignes à interrupteur (Accent OUI / gris NON). Sauvegardés : relus dans `snapshot.settings` au premier
	état reçu, puis chaque changement part au serveur (intention SetSetting). L'effet est immédiat et local.
]]

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local WindowHost = require(Client.UI.WindowHost)
local ListRow = require(Client.UI.Components.ListRow)

local Settings = {}

local ENTRIES = {
	{
		key = "reducedEffects",
		label = "EFFETS RÉDUITS",
		hint = "Auras et particules atténuées, halo lumineux (bloom) coupé",
	},
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
	{
		key = "sound",
		label = "SONS",
		hint = "Effets sonores du jeu",
	},
	{
		key = "music",
		label = "MUSIQUE",
		hint = "Musique d'ambiance du lobby et des combats",
	},
}

function Settings.start(scope: any, deps: any)
	local settings = deps.UiState.settings

	-- Premier snapshot : les choix sauvegardés remplacent les valeurs par défaut locales (une seule fois,
	-- ensuite ce client est le seul à les changer)
	local synced = false
	local function sync()
		local snapshot = deps.peek(deps.Store.snapshot)
		local saved = snapshot and snapshot.settings
		if synced or type(saved) ~= "table" then
			return
		end
		synced = true
		for _, entry in ENTRIES do
			if type(saved[entry.key]) == "boolean" then
				settings[entry.key]:set(saved[entry.key])
			end
		end
	end
	sync()
	scope:Observer(deps.Store.snapshot):onChange(sync)
	WindowHost.mount(scope, deps, deps.HudRoot, {
		name = "Settings",
		gradient = Theme.Gradients.Settings,
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
								local value = not deps.peek(settings[entry.key])
								settings[entry.key]:set(value)
								deps.StateController.send(
									deps.Actions.SetSetting or "SetSetting",
									{ key = entry.key, value = value }
								)
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
