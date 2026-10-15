--!strict
--[[
	Crew : compagnons équipés (§16) — nom, rôle, production réelle par seconde, niveau, copies.
	Les compagnons n'attaquent pas en V1 : ils entraînent en continu.
]]

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local WindowHost = require(Client.UI.WindowHost)
local ListRow = require(Client.UI.Components.ListRow)
local Chip = require(Client.UI.Components.Chip)

local Crew = {}

local function crewRows(scope: any, deps: any, snapshot: any): { Instance }
	local rows: { Instance } = {}
	local crew = snapshot and snapshot.crew or {}
	if #crew == 0 then
		local tutorial = snapshot and snapshot.tutorial or {}
		table.insert(
			rows,
			ListRow(scope, {
				Color = Theme.Colors.Nuit,
				Portrait = Theme.Icons.Unknown.fallback,
				Name = "AUCUN COMPAGNON",
				Chips = {
					Chip(scope, {
						Text = `Entraîne-toi : {tutorial.progress or 0}/{tutorial.needed or 0}`,
						Color = Theme.Colors.Cyan,
					}),
				},
				Dimmed = true,
			})
		)
		return rows
	end
	for index, entry in crew do
		local def = deps.Catalog.crew[entry.id]
		if def then
			table.insert(
				rows,
				ListRow(scope, {
					Color = Theme.Colors.Violet,
					Portrait = string.sub(def.name, 1, 1),
					Name = `{string.upper(def.name)} · {string.upper(def.role)}`,
					Chips = {
						Chip(scope, {
							Text = `+{deps.Format.number(entry.perSecond or 0)}/s`,
							Color = Theme.Colors.Action,
						}),
						Chip(scope, { Text = `Niv. {entry.level or 1}`, Color = Theme.Colors.Or }),
						Chip(scope, { Text = `Copies : {entry.copies or 0}`, Color = Theme.Colors.Creme }),
					},
					LayoutOrder = index,
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
	local parts = {}
	for _, entry in snapshot.crew or {} do
		table.insert(parts, `{entry.id}:{entry.level}:{entry.copies}:{entry.perSecond}`)
	end
	local tutorial = snapshot.tutorial or {}
	table.insert(parts, tostring(tutorial.progress))
	return table.concat(parts, "|")
end

function Crew.start(scope: any, deps: any)
	WindowHost.mount(scope, deps, deps.HudRoot, {
		name = "Crew",
		title = "CREW",
		icon = Theme.Icons.Crew,
		content = function(inner)
			return {
				WindowHost.rows(inner, deps, signature, function(rowsScope, snapshot)
					return crewRows(rowsScope, deps, snapshot)
				end),
			}
		end,
	})
end

return Crew
