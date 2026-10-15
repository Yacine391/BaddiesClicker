--[[
	Bootstrap serveur : construit le contexte, initialise les services dans l'ordre
	et déclare les intentions acceptées. Toute la logique vit dans Services/ et Rules/.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")

local ctx = table.freeze({
	Balance = require(Shared.Balance),
	Catalog = require(Shared.Catalog),
	Formulas = require(Shared.Formulas),
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

local deps = table.freeze({
	Profiles = Profiles,
	Sessions = Sessions,
	State = State,
	World = World,
})

Profiles.init(ctx)
World.init(ctx)
State.init(ctx, deps)
Training.init(ctx, deps)
Crew.init(ctx, deps)
Combat.init(ctx, deps)

IntentRouter.init(ctx, deps, {
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
})

Profiles.onLoaded(function(player, data)
	Sessions.create(player)
	State.onPlayerReady(player, data)
end)

Profiles.onReleasing(function(player)
	Sessions.remove(player)
	State.forget(player)
end)

Crew.start()
Combat.start()
Profiles.start()

print(`[BaddieClicker] serveur prêt (balance {ctx.Balance.version})`)
