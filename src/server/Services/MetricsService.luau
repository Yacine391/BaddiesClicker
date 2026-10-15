--[[
	MetricsService : statistiques de jeu envoyées par le SERVEUR à AnalyticsService (dossier §29, §36, [R7]).
	Tableau de bord : Creator Hub → l'expérience → Analytics (Onboarding, Progression, Economy, Custom).
	Règles (quoi, quand) : Rules/Metrics. Dans Studio, rien n'est envoyé : une ligne « [Metrics] … »
	s'affiche dans la sortie pour vérifier les branchements.

	- Accueil (onboarding, une fois par joueur) : profil chargé → premier entraînement → Malik → premier combat
	  → premier boss → deuxième quartier → parcours terminé → première renaissance.
	- Progression « Parcours » par niveau : début, échec (mort), réussite.
	- Économie : tickets baddie et compagnon gagnés (entraînement, premier passage, renaissance) et dépensés.
	- Personnalisés : temps jusqu'au premier combat / boss, durée du parcours, puissance à la mort,
	  reprise après une mort, relances jusqu'à une découverte, décisions sur les drops, baddie effacée au rebirth.
]]

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local MetricsRules = require(script.Parent.Parent.Rules.Metrics)

local MetricsService = {}

local ctx
local deps
local IS_STUDIO = RunService:IsStudio()
local PATH = "Parcours"
local GAMEPLAY = Enum.AnalyticsEconomyTransactionType.Gameplay.Name
local FIELD = {
	Enum.AnalyticsCustomFieldKeys.CustomField01.Name,
	Enum.AnalyticsCustomFieldKeys.CustomField02.Name,
}

function MetricsService.init(context, dependencies)
	ctx = context
	deps = dependencies
end

local function fields(f1: string?, f2: string?): { [string]: string }?
	if f1 == nil and f2 == nil then
		return nil
	end
	local map = {}
	if f1 ~= nil then
		map[FIELD[1]] = f1
	end
	if f2 ~= nil then
		map[FIELD[2]] = f2
	end
	return map
end

local function studioLog(line: string)
	print(`[Metrics] {line}`)
end

-- Envoi protégé : une statistique ne doit jamais casser le jeu
local function send(description: string, fn: () -> ())
	if IS_STUDIO then
		studioLog(description)
		return
	end
	local ok, err = pcall(fn)
	if not ok then
		warn(`[Metrics] {description} : {err}`)
	end
end

local function playSeconds(player: Player, data): number
	local session = deps.Sessions.get(player)
	local elapsed = if session ~= nil then os.clock() - session.startedAt else 0
	return MetricsRules.playSeconds(data, elapsed)
end

local function onboarding(player: Player, data, key: string)
	local step = MetricsRules.ONBOARDING[key]
	if step == nil or not MetricsRules.once(data, `o{step.step}`) then
		return
	end
	send(`accueil {step.step} · {step.name}`, function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step.step, step.name)
	end)
end

local function custom(player: Player, name: string, value: number, f1: string?, f2: string?)
	send(`{name} = {value}{if f1 then ` · {f1}` else ""}{if f2 then ` · {f2}` else ""}`, function()
		AnalyticsService:LogCustomEvent(player, name, value, fields(f1, f2))
	end)
end

local function tickets(player: Player, data, kind: "baddie" | "crew", amount: number, sku: string)
	if amount == 0 then
		return
	end
	local currency = if kind == "baddie" then "TicketBaddie" else "TicketCrew"
	local flow = if amount > 0
		then Enum.AnalyticsEconomyFlowType.Source
		else Enum.AnalyticsEconomyFlowType.Sink
	local balance = data.tickets[kind]
	send(`{currency} {if amount > 0 then "+" else ""}{amount} ({sku}) → {balance}`, function()
		AnalyticsService:LogEconomyEvent(player, flow, currency, math.abs(amount), balance, GAMEPLAY, sku)
	end)
end

local function levelName(levelId: number): string
	local level = ctx.Balance.levels[levelId]
	return `Niveau {levelId} · {if level then level.district else "?"}`
end

--[[ Branchements (appelés par les autres services) ]]

function MetricsService.profileLoaded(player: Player, data)
	onboarding(player, data, "joined")
end

-- Avant la fin de session : cumule le temps de jeu dans le profil (écrit avec la sauvegarde de départ)
function MetricsService.releasing(player: Player, data)
	local session = deps.Sessions.get(player)
	if session ~= nil and data ~= nil then
		MetricsRules.closeSession(data, os.clock() - session.startedAt)
	end
end

function MetricsService.trained(player: Player, data, result)
	if data.stats.trainActions == 1 then
		onboarding(player, data, "firstTrain")
	end
	if result.crewUnlocked ~= nil then
		onboarding(player, data, "firstCrew")
	end
	tickets(player, data, "baddie", result.baddieTickets, "Entrainement")
	tickets(player, data, "crew", result.crewTickets, "Entrainement")
end

function MetricsService.encounterStarted(player: Player, data, session, levelId: number)
	if MetricsRules.once(data, "firstCombat") then
		custom(player, "TempsPremierCombat", playSeconds(player, data))
	end
	onboarding(player, data, "firstCombat")
	local level = ctx.Balance.levels[levelId]
	if level ~= nil and level.district ~= ctx.Balance.levels[1].district then
		onboarding(player, data, "secondDistrict")
	end
	if session.lastDeathAt ~= nil then
		-- reprise après un retour au lobby : combien de secondes pour retenter
		custom(player, "RepriseApresMort", math.floor(os.clock() - session.lastDeathAt), `niveau {levelId}`)
		session.lastDeathAt = nil
	end
	send(`progression début · {levelName(levelId)}`, function()
		AnalyticsService:LogProgressionStartEvent(player, PATH, levelId, levelName(levelId))
	end)
end

function MetricsService.died(player: Player, data, session, levelId: number)
	session.lastDeathAt = os.clock()
	custom(
		player,
		"PuissanceALaMort",
		math.floor(data.power),
		`niveau {levelId}`,
		MetricsRules.powerBucket(data.power)
	)
	send(`progression échec · {levelName(levelId)}`, function()
		AnalyticsService:LogProgressionFailEvent(player, PATH, levelId, levelName(levelId))
	end)
end

function MetricsService.bossDefeated(player: Player, data, levelId: number, victory)
	send(`progression réussite · {levelName(levelId)}`, function()
		AnalyticsService:LogProgressionCompleteEvent(player, PATH, levelId, levelName(levelId))
	end)
	if levelId == 1 and MetricsRules.once(data, "firstBoss") then
		custom(player, "TempsPremierBoss", playSeconds(player, data))
	end
	if levelId == 1 then
		onboarding(player, data, "firstBoss")
	end
	if levelId == #ctx.Balance.levels and victory.firstClear then
		onboarding(player, data, "runComplete")
		custom(
			player,
			"DureeParcours",
			MetricsRules.runSeconds(data, playSeconds(player, data)),
			`run {data.rebirths + 1}`
		)
	end
	tickets(player, data, "baddie", victory.baddieTickets, "PremierPassage")
	if victory.drop ~= nil then
		custom(player, "DropBoss", 1, victory.drop, `niveau {levelId}`)
	end
end

function MetricsService.rolled(player: Player, data, result)
	tickets(player, data, "baddie", -1, "Relance")
	local count = MetricsRules.onRoll(data, result.isNew)
	if count ~= nil then
		custom(
			player,
			"RelancesJusquaDecouverte",
			count,
			result.baddieId,
			if result.guaranteed then "garantie" else "table"
		)
	end
end

function MetricsService.dropDecided(player: Player, _data, decision: string, baddieId: string)
	custom(player, "DecisionDrop", 1, decision, baddieId)
end

function MetricsService.chestOpened(player: Player, data, result)
	tickets(player, data, "crew", -1, "Coffre")
	if result.isNew then
		custom(
			player,
			"NouveauCompagnon",
			result.openNumber,
			result.crewId,
			if result.guaranteed then "garantie" else "table"
		)
	end
end

function MetricsService.reborn(player: Player, data, result)
	if result.count == 1 then
		onboarding(player, data, "firstRebirth")
	end
	MetricsRules.startRun(data, playSeconds(player, data))
	tickets(player, data, "baddie", result.baddieTickets, "Renaissance")
	tickets(player, data, "crew", result.crewTickets, "Renaissance")
	if result.lostBaddieId ~= nil then
		local def = ctx.Catalog.baddies[result.lostBaddieId]
		custom(
			player,
			"BaddieEffaceeAuRebirth",
			result.count,
			result.lostBaddieId,
			if def then def.rarity else nil
		)
	end
end

return MetricsService
