--[[
	Bootstrap serveur : construit le contexte, initialise les services dans l'ordre
	et déclare les intentions acceptées. Toute la logique vit dans Services/ et Rules/.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")

-- Dans Studio seulement, le catalogue inclut les identités de test (Shared/TestCatalog, jamais en relance)
local Catalog = require(Shared.Catalog)
if RunService:IsStudio() then
	Catalog = require(Shared.TestCatalog).merge(Catalog)
end

local ctx = table.freeze({
	Balance = require(Shared.Balance),
	Catalog = Catalog,
	Formulas = require(Shared.Formulas),
	Wardrobe = require(Shared.Wardrobe),
})

local Services = script.Parent.Services
local Profiles = require(Services.Profiles)
local Sessions = require(Services.Sessions)
local State = require(Services.StateService)
local Training = require(Services.TrainingService)
local Crew = require(Services.CrewService)
local IntentRouter = require(Services.IntentRouter)
local World = require(Services.WorldService)
local Combat = require(Services.CombatService)
local Mutations = require(Services.MutationService)
local Maintenance = require(Services.MaintenanceService)
local Ranking = require(Services.RankingService)
local Wardrobe = require(Services.WardrobeService)
local Metrics = require(Services.MetricsService)
local Slots = require(Services.SlotService)
local Book = require(Services.BookService)
local Dev = require(Services.DevService)

local deps = table.freeze({
	Profiles = Profiles,
	Sessions = Sessions,
	State = State,
	World = World,
	Mutations = Mutations,
	Maintenance = Maintenance,
	Ranking = Ranking,
	Metrics = Metrics,
})

Profiles.init(ctx)
Maintenance.init(ctx)
World.init(ctx)
State.init(ctx, deps)
Training.init(ctx, deps)
Crew.init(ctx, deps)
Combat.init(ctx, deps)
Mutations.init(ctx, deps)
Slots.init(ctx, deps)
Book.init(ctx, deps)
Dev.init(ctx, deps)
Ranking.init(ctx, deps)
Wardrobe.init(ctx, deps)
Metrics.init(ctx, deps)

-- Décisions durables : la file de MutationService les sérialise ; la cadence ne fait que borner le spam
local MUTATION_RATE = 4
-- Choix immédiats (principale, verrou, exposition, look) : 4/s (§25)
local CHOICE_RATE = 4

local routes: { [string]: IntentRouter.Route } = {
	Hello = {
		rate = ctx.Balance.net.helloPerSecond,
		burst = 2,
		handler = State.onHello,
	},
	Train = {
		rate = ctx.Balance.training.maxActionsPerSecond,
		burst = ctx.Balance.training.burst,
		handler = Training.onTrain,
	},
	Attack = {
		rate = ctx.Balance.combat.maxActionsPerSecond,
		burst = ctx.Balance.combat.maxActionsPerSecond,
		handler = Combat.onAttack,
	},
	StartWave = {
		rate = 1,
		burst = 2,
		handler = Combat.onStartWave,
	},
	Roll = { rate = MUTATION_RATE, burst = MUTATION_RATE, handler = Slots.onRoll },
	AcceptDrop = { rate = MUTATION_RATE, burst = MUTATION_RATE, handler = Slots.onAcceptDrop },
	RefuseDrop = { rate = MUTATION_RATE, burst = MUTATION_RATE, handler = Slots.onRefuseDrop },
	Rebirth = { rate = 1, burst = 1, handler = Slots.onRebirth },
	OpenChest = { rate = MUTATION_RATE, burst = MUTATION_RATE, handler = Crew.onOpenChest },
	SetActive = { rate = CHOICE_RATE, burst = CHOICE_RATE, handler = Slots.onSetActive },
	SetRollLock = { rate = CHOICE_RATE, burst = CHOICE_RATE, handler = Slots.onSetRollLock },
	SetDisplay = { rate = CHOICE_RATE, burst = CHOICE_RATE, handler = Book.onSetDisplay },
	SetLook = { rate = CHOICE_RATE, burst = CHOICE_RATE, handler = Book.onSetLook },
	UpgradeCrew = { rate = CHOICE_RATE, burst = CHOICE_RATE, handler = Crew.onUpgrade },
	EquipCrew = { rate = CHOICE_RATE, burst = CHOICE_RATE, handler = Crew.onEquip },
	SetStyle = { rate = CHOICE_RATE, burst = CHOICE_RATE, handler = Wardrobe.onSetStyle },
}
if Dev.enabled() then
	routes.DevSetMastery = { rate = CHOICE_RATE, burst = CHOICE_RATE, handler = Dev.onSetMastery }
	routes.DevGrant = { rate = CHOICE_RATE, burst = CHOICE_RATE, handler = Dev.onGrant }
end
IntentRouter.init(ctx, deps, routes)

Profiles.onLoaded(function(player, data)
	Sessions.create(player)
	Dev.onProfileLoaded(player, data)
	Metrics.profileLoaded(player, data)
	State.onPlayerReady(player, data)
end)

Profiles.onReleasing(function(player)
	Metrics.releasing(player, Profiles.get(player)) -- temps de jeu cumulé, écrit avec la sauvegarde de départ
	Sessions.remove(player)
	State.forget(player)
end)

Maintenance.start()
Ranking.start()
Wardrobe.start()
Crew.start()
Combat.start()
Profiles.start()

print(`[BaddieClicker] serveur prêt (balance {ctx.Balance.version})`)
