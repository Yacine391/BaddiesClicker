--[[
	StateService : envoie au client un snapshot de son état (contrat : docs/CONTRACT.md).
	- markDirty() regroupe les changements ; l'envoi part au plus toutes les 0,1 s.
	- notify() envoie un événement ponctuel (toast, ticket, nouveau compagnon…).
	- Les attributs BC_* du Player servent à afficher les suiveurs de TOUS les joueurs.
	- Pendant une décision durable (MutationService), les snapshots attendent la fin de l'écriture :
	  le joueur ne voit le résultat d'une relance qu'après sa confirmation (§26).
	Le client ne décide jamais de rien : il affiche ce que le serveur calcule.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = require(ReplicatedStorage.Shared.Net)
local CollectionRules = require(script.Parent.Parent.Rules.Collection)
local CombatRules = require(script.Parent.Parent.Rules.Combat)
local CrewRules = require(script.Parent.Parent.Rules.Crew)
local SlotRules = require(script.Parent.Parent.Rules.Slots)

local StateService = {}

local ctx
local deps
local stateRemote: RemoteEvent
local resultRemote: RemoteEvent
local dirty: { [Player]: boolean } = {}
local sequence: { [Player]: number } = {}

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
			local session = deps.Sessions.get(player)
			if session == nil or not session.mutating then
				dirty[player] = nil
				StateService.pushNow(player)
			end
		end
	end)
end

function StateService.snapshot(player: Player, data): { [string]: any }
	local B, C, F = ctx.Balance, ctx.Catalog, ctx.Formulas
	local session = deps.Sessions.get(player)

	local slot = data.slots[data.activeSlotId]
	local baddieId = if slot and not SlotRules.isEmpty(slot) then slot.baddieId else nil
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

	local maxHP = B.combat.playerHP
	local encounter = if session then session.encounter else nil
	local combat
	if encounter ~= nil then
		combat = {
			active = true,
			encounterId = encounter.id,
			levelId = encounter.levelId,
			phase = encounter.phase,
			hp = session.hp,
			maxHP = maxHP,
			minionsKilled = encounter.minionsKilled,
			minionsTotal = encounter.minionsTotal,
			boss = encounter.cfg.boss,
		}
	else
		combat = { active = false, hp = maxHP, maxHP = maxHP }
	end

	local pendingDrops = table.clone(data.pendingDrops)

	local missing = SlotRules.missingBaddies(data, ctx)
	local crewMissing = CrewRules.missing(data, ctx)
	local promotesNext = SlotRules.rebirthPromotes(data.rebirths + 1, ctx)

	local needed = B.tutorial.crewUnlockAfterTrainActions
	return {
		v = 2,
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
			look = if baddieId then CollectionRules.selectedLook(data, baddieId, ctx) else 1,
		},
		crew = crew, -- compagnons ÉQUIPÉS (inchangé depuis le v1)
		crewOwned = CrewRules.ownedView(data, ctx), -- toute la collection possédée (P2)
		crewChest = {
			opened = data.rolls.crew, -- coffres ouverts (compteur global)
			guaranteeEvery = B.rolls.crewGuaranteeEvery,
			untilGuarantee = CrewRules.untilChestGuarantee(data, ctx), -- 1 = le prochain est garanti
			missing = crewMissing,
			complete = #crewMissing == 0,
		},
		stats = { trainActions = data.stats.trainActions, crewPowerEarned = data.stats.crewPowerEarned },
		settings = { reducedEffects = data.settings.reducedEffects == true },
		combat = combat,
		clearedLevels = CombatRules.clearedList(data),
		run = { id = data.run.id, attempt = data.run.attempt },
		pendingDrops = pendingDrops,
		pendingRevision = data.pendingRevision,
		-- Lot P2 : slots, relances, Baddies Book, renaissance
		slots = SlotRules.view(data),
		rolls = {
			baddie = data.rolls.baddie, -- relances effectuées (compteur global)
			guaranteeEvery = B.rolls.baddieGuaranteeEvery,
			untilGuarantee = SlotRules.untilGuarantee(data, ctx), -- 1 = la prochaine est garantie
			bookComplete = #missing == 0,
			missing = missing, -- ouverture garantie : chance égale pour chacune
		},
		collection = CollectionRules.view(data, ctx),
		saving = session ~= nil and session.mutating == true,
		maintenance = deps.Maintenance.disabledList(), -- décisions coupées : griser leurs boutons
		rebirth = {
			count = data.rebirths,
			available = SlotRules.rebirthAvailable(data, ctx),
			promotesNext = promotesNext,
			temporarySlotId = SlotRules.temporaryId(data),
			baddieTickets = B.rebirth.baddieTickets,
			crewTickets = B.rebirth.crewTickets,
		},
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
	local snapshot = StateService.snapshot(player, data)
	sequence[player] = (sequence[player] or 0) + 1
	snapshot.seq = sequence[player] -- croissant : le client ignore un état plus ancien que le dernier reçu
	stateRemote:FireClient(player, snapshot)
end

function StateService.markDirty(player: Player)
	dirty[player] = true
end

function StateService.notify(player: Player, event: { [string]: any })
	resultRemote:FireClient(player, event)
end

function StateService.refreshAttributes(player: Player, data)
	local slot = data.slots[data.activeSlotId]
	local baddieId = if slot and not SlotRules.isEmpty(slot) then slot.baddieId else ""
	player:SetAttribute("BC_ActiveBaddie", baddieId)
	player:SetAttribute(
		"BC_ActiveLook",
		if baddieId ~= "" then CollectionRules.selectedLook(data, baddieId, ctx) else 1
	)
	player:SetAttribute("BC_Display", table.concat(CollectionRules.displayList(data, ctx), ","))
	player:SetAttribute("BC_BookCount", (CollectionRules.bookCount(data, ctx)))
	player:SetAttribute("BC_EquippedCrew", table.concat(data.equippedCrew, ","))
	player:SetAttribute("BC_Ready", true)
end

function StateService.onPlayerReady(player: Player, data)
	StateService.refreshAttributes(player, data)
	StateService.pushNow(player)
end

function StateService.forget(player: Player)
	dirty[player] = nil
	sequence[player] = nil
end

-- Intention « Hello » : le client vient de brancher ses écouteurs
function StateService.onHello(player: Player)
	StateService.pushNow(player)
end

return StateService
