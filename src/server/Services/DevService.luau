--[[
	DevService : outils de TEST, actifs UNIQUEMENT dans Studio (proposition contrat v2 §5, dossier §02, §13, §30).

	- Au chargement : les identités de Shared/TestCatalog (test_b99) entrent dans le Baddies Book du profil
	  Studio (store Studio séparé, jamais importé en production) ; elles restent hors du compte public.
	- DevSetMastery { baddieId, xp }       : fixe l'XP de maîtrise d'une identité découverte (tester les looks).
	- DevGrant { what = "tickets" }        : +10 tickets baddie (tester les relances et la garantie).
	- DevGrant { what = "crewTickets" }    : +5 tickets compagnon (tester les coffres).
	- DevGrant { what = "drop", baddieId } : ajoute un drop en attente (tester accepter / refuser).
	- DevGrant { what = "finishRun" }      : marque les 10 niveaux terminés (tester la renaissance).
	Hors Studio, ces intentions ne sont même pas déclarées (Bootstrap.server) et chaque fonction refuse.
]]

local RunService = game:GetService("RunService")

local DevService = {}

local ctx
local deps

local MAX_XP = 1e6

function DevService.init(context, dependencies)
	ctx = context
	deps = dependencies
end

function DevService.enabled(): boolean
	return RunService:IsStudio()
end

-- Appelé au chargement d'un profil, avant le premier snapshot
function DevService.onProfileLoaded(_player: Player, data)
	if not DevService.enabled() then
		return
	end
	for _, id in ctx.Catalog.testOrder or {} do
		data.discoveredBaddies[id] = true
		if data.masteryXP[id] == nil then
			data.masteryXP[id] = 0
		end
	end
end

local function changed(player: Player, data)
	deps.State.refreshAttributes(player, data)
	deps.State.markDirty(player)
end

function DevService.onSetMastery(player: Player, payload: { [any]: any }?)
	local data = deps.Profiles.get(player)
	if not DevService.enabled() or payload == nil or data == nil then
		return
	end
	local id, xp = payload.baddieId, payload.xp
	if type(id) ~= "string" or ctx.Catalog.baddies[id] == nil or data.discoveredBaddies[id] ~= true then
		return
	end
	if type(xp) ~= "number" or xp ~= xp or xp < 0 or xp > MAX_XP then
		return
	end
	data.masteryXP[id] = xp
	changed(player, data)
end

function DevService.onGrant(player: Player, payload: { [any]: any }?)
	local data = deps.Profiles.get(player)
	local session = deps.Sessions.get(player)
	if not DevService.enabled() or payload == nil or data == nil or session == nil or session.mutating then
		return
	end
	local what = payload.what
	if what == "tickets" then
		data.tickets.baddie += 10
	elseif what == "crewTickets" then
		data.tickets.crew += 5
	elseif what == "drop" then
		local id = payload.baddieId
		-- identités publiques seulement : un drop vient toujours d'un boss du lot
		if type(id) ~= "string" or table.find(ctx.Catalog.baddieOrder, id) == nil then
			return
		end
		data.pendingDrops[id] = (data.pendingDrops[id] or 0) + 1
		data.pendingRevision += 1
	elseif what == "finishRun" then
		for levelId = 1, #ctx.Balance.levels do
			data.run.clearedLevels[tostring(levelId)] = true
		end
	else
		return
	end
	changed(player, data)
end

return DevService
