--[[
	StateService : envoie au client un snapshot de son état (contrat : docs/CONTRACT.md).
	- markDirty() regroupe les changements ; l'envoi part au plus toutes les 0,1 s.
	- notify() envoie un événement ponctuel (toast, ticket, nouveau compagnon…).
	- Les attributs BC_* du Player servent à afficher les suiveurs de TOUS les joueurs.
	Le client ne décide jamais de rien : il affiche ce que le serveur calcule.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local CrewRules = require(script.Parent.Parent.Rules.Crew)

local StateService = {}

local ctx
local deps
local stateRemote: RemoteEvent
local resultRemote: RemoteEvent
local dirty: { [Player]: boolean } = {}

function StateService.init(context, dependencies)
	ctx = context
	deps = dependencies
	stateRemote = Net.remote(Net.STATE)
	resultRemote = Net.remote(Net.RESULT)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < ctx.Balance.net.statePushSeconds then
			return
		end
		elapsed = 0
		for player in dirty do
			dirty[player] = nil
			StateService.pushNow(player)
		end
	end)
end

function StateService.snapshot(player: Player, data): { [string]: any }
	local B, C, F = ctx.Balance, ctx.Catalog, ctx.Formulas
	local session = deps.Sessions.get(player)

	local slot = data.slots[data.activeSlotId]
	local baddieId = if slot then slot.baddieId else nil
	local baddie = if baddieId then C.baddies[baddieId] else nil
	local multiplier = if baddie then baddie.multiplier else 0
	local masteryLevel = F.masteryLevel(if baddieId then data.masteryXP[baddieId] or 0 else 0, B.mastery)
	local bonus = F.trainingBonus(data.rebirths, B.training)

	local crew = {}
	for _, item in CrewRules.equippedRates(data, ctx) do
		local entry = data.crew[item.id]
		table.insert(crew, {
			id = item.id,
			level = entry.level,
			copies = entry.copies,
			perSecond = item.rate * bonus,
		})
	end

	local needed = B.tutorial.crewUnlockAfterTrainActions
	return {
		v = 1,
		mode = if session and session.inCombat then "combat" else "rest",
		power = data.power,
		gainPerTrain = F.manualGain(data.rebirths, B.training),
		passivePerSecond = CrewRules.passivePerSecond(data, ctx),
		trainingBonus = bonus,
		rebirths = data.rebirths,
		tickets = { baddie = data.tickets.baddie, crew = data.tickets.crew },
		active = {
			slotId = data.activeSlotId,
			baddieId = baddieId,
			multiplier = multiplier,
			masteryLevel = masteryLevel,
			damagePerClick = F.damagePerClick(data.power, multiplier, masteryLevel, B.mastery),
		},
		crew = crew,
		stats = { trainActions = data.stats.trainActions, crewPowerEarned = data.stats.crewPowerEarned },
		tutorial = {
			crewUnlocked = data.tutorial.crewUnlocked,
			progress = math.min(data.stats.trainActions, needed),
			needed = needed,
		},
	}
end

function StateService.pushNow(player: Player)
	local data = deps.Profiles.get(player)
	if data == nil then
		return
	end
	stateRemote:FireClient(player, StateService.snapshot(player, data))
end

function StateService.markDirty(player: Player)
	dirty[player] = true
end

function StateService.notify(player: Player, event: { [string]: any })
	resultRemote:FireClient(player, event)
end

function StateService.refreshAttributes(player: Player, data)
	local slot = data.slots[data.activeSlotId]
	player:SetAttribute("BC_ActiveBaddie", if slot then slot.baddieId else "")
	player:SetAttribute("BC_EquippedCrew", table.concat(data.equippedCrew, ","))
	player:SetAttribute("BC_Ready", true)
end

function StateService.onPlayerReady(player: Player, data)
	StateService.refreshAttributes(player, data)
	StateService.pushNow(player)
end

function StateService.forget(player: Player)
	dirty[player] = nil
end

-- Intention « Hello » : le client vient de brancher ses écouteurs
function StateService.onHello(player: Player)
	StateService.pushNow(player)
end

return StateService
