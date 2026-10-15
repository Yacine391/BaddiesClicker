--[[
	CrewService : compagnons (§04, §16). Règles dans Rules/Crew.

	- Production passive calculée par le serveur ; arrêter une animation côté client ne change rien
	  aux gains. Production uniquement tant que le joueur est connecté et que son profil est chargé.
	- OpenChest { requestId } : décision durable (MutationService), hors combat, 2 s entre deux coffres.
	- UpgradeCrew { crewId } et EquipCrew { ids } : choix immédiats, ignorés s'ils sont invalides.
]]

local CrewRules = require(script.Parent.Parent.Rules.Crew)

local CrewService = {}

local ctx
local deps

function CrewService.init(context, dependencies)
	ctx = context
	deps = dependencies
end

local function tick()
	local now = os.clock()
	for player, session in deps.Sessions.all() do
		local dt = now - session.lastPassiveAt
		session.lastPassiveAt = now
		local data = deps.Profiles.get(player)
		if data ~= nil then
			local gained = CrewRules.applyPassive(data, dt, ctx)
			if gained > 0 then
				deps.State.markDirty(player)
				deps.State.notify(player, { kind = "passiveTick", amount = gained })
			end
		end
	end
end

local rng = Random.new()

-- Intention « OpenChest »
function CrewService.onOpenChest(player: Player, payload: { [any]: any }?)
	if payload == nil then
		return
	end
	deps.Mutations.run(player, "OpenChest", payload.requestId, function(data, session)
		if session.inCombat or session.encounter ~= nil then
			return "in_combat"
		end
		local now = os.clock()
		if
			session.lastChestAt ~= nil
			and now - session.lastChestAt < ctx.Balance.rolls.minIntervalSeconds
		then
			return "cooldown"
		end
		local reason = CrewRules.checkOpenChest(data)
		if reason ~= nil then
			return reason
		end
		session.lastChestAt = now
		return nil, CrewRules.applyOpenChest(data, rng:NextNumber(), ctx)
	end, function(target: Player, _data, result)
		deps.State.notify(target, {
			kind = "crewJoined",
			crewId = result.crewId,
			isNew = result.isNew,
			equipped = result.equipped,
		})
	end)
end

-- Intention « UpgradeCrew » : dépense niveau + 1 copies
function CrewService.onUpgrade(player: Player, payload: { [any]: any }?)
	local data = deps.Profiles.get(player)
	local session = deps.Sessions.get(player)
	if payload == nil or data == nil or session == nil or session.mutating then
		return
	end
	local reason, level = CrewRules.upgrade(data, payload.crewId, ctx)
	if reason == nil then
		deps.Profiles.saveNow(player) -- des copies ont été dépensées : écriture prioritaire
		deps.State.notify(player, { kind = "crewLevelUp", crewId = payload.crewId, level = level })
		deps.State.markDirty(player)
	end
end

-- Intention « EquipCrew » : remplace la liste des compagnons équipés
function CrewService.onEquip(player: Player, payload: { [any]: any }?)
	local data = deps.Profiles.get(player)
	if payload == nil or data == nil then
		return
	end
	if CrewRules.setEquipped(data, payload.ids, ctx) == nil then
		deps.State.refreshAttributes(player, data)
		deps.State.markDirty(player)
	end
end

function CrewService.start()
	task.spawn(function()
		while true do
			task.wait(ctx.Balance.crew.tickSeconds)
			tick()
		end
	end)
end

return CrewService
