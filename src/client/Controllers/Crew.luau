--!strict
--[[
	Crew : compagnons (§16) — rareté, nom · rôle, production réelle par seconde, niveau, copies,
	puce ÉQUIPÉ. Collection complète (`crewOwned`) si le snapshot la donne, sinon les équipés (`crew`).
	Les compagnons n'attaquent pas en V1 : ils entraînent en continu. Aucun bouton (pas de faux bouton).
]]

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local WindowHost = require(Client.UI.WindowHost)
local ListRow = require(Client.UI.Components.ListRow)
local Chip = require(Client.UI.Components.Chip)

local Crew = {}

local function entriesOf(snapshot: any): ({ any }, boolean)
	if snapshot and type(snapshot.crewOwned) == "table" then
		return snapshot.crewOwned, true
	end
	return (snapshot and snapshot.crew) or {}, false
end

local function crewRows(scope: any, deps: any, snapshot: any): { Instance }
	local rows: { Instance } = {}
	local entries, owned = entriesOf(snapshot)
	if #entries == 0 then
		local tutorial = snapshot and snapshot.tutorial or {}
		table.insert(
			rows,
			ListRow(scope, {
				Portrait = "?",
				Name = "AUCUN COMPAGNON",
				Chips = {
					Chip(scope, {
						Text = `Entraîne-toi : {tutorial.progress or 0}/{tutorial.needed or 0}`,
						Color = Theme.Colors.Accent,
					}),
				},
				Description = "Malik te rejoint après tes premiers entraînements.",
				Dimmed = true,
			})
		)
		return rows
	end
	for index, entry in entries do
		local def = deps.Catalog.crew[entry.id]
		if def then
			local rarity = deps.Catalog.rarities[def.rarity]
			local equipped = if owned then entry.equipped == true else true
			local chips = {
				Chip(scope, {
					Text = if rarity then rarity.label else def.rarity,
					Color = if rarity then Color3.fromHex(rarity.color) else Theme.Colors.TextDim,
				}),
				Chip(scope, {
					Text = `+{deps.Format.number(entry.perSecond or def.basePowerPerSecond)}/s`,
					Color = Theme.Colors.Accent,
				}),
				Chip(scope, { Text = `Niv. {entry.level or 1}`, Color = Theme.Colors.TextDim }),
				Chip(scope, { Text = `Copies : {entry.copies or 0}`, Color = Theme.Colors.TextDim }),
			}
			if equipped then
				table.insert(chips, Chip(scope, { Text = "ÉQUIPÉ", Color = Theme.Colors.Principal }))
			end
			table.insert(
				rows,
				ListRow(scope, {
					Portrait = string.sub(def.name, 1, 1),
					PortraitColor = Theme.Colors.Crew,
					Name = `{string.upper(def.name)} · {string.upper(def.role)}`,
					Chips = chips,
					Selected = equipped,
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
	local entries = entriesOf(snapshot)
	for _, entry in entries do
		table.insert(parts, `{entry.id}:{entry.level}:{entry.copies}:{entry.perSecond}:{entry.equipped}`)
	end
	local tutorial = snapshot.tutorial or {}
	table.insert(parts, tostring(tutorial.progress))
	return table.concat(parts, "|")
end

function Crew.start(scope: any, deps: any)
	WindowHost.mount(scope, deps, deps.HudRoot, {
		name = "Crew",
		title = "CREW",
		icon = "crew",
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
