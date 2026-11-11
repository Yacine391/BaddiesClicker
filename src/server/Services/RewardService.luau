--[[
	RewardService : pièces, roue, connexion quotidienne et temps de jeu. Toute la règle vit dans Rules/Rewards.

	Décisions durables (réponse Result { kind = "mutation" }, voir MutationService) :
	- SpinWheel { requestId, pay = "free" | "token" | "coins" }   3 s entre deux tours ; le client choisit
	  COMMENT il paie (jamais de dépense par surprise), le serveur vérifie qu'il le peut et tire le gain.
	- ClaimDaily { requestId }                                   une fois par jour UTC
	- ClaimPlaytime { requestId, index }                         palier du jour atteint, pas encore réclamé
	Le jour vient de l'horloge du serveur (os.time), jamais du client.

	Temps de jeu : compteur du jour crédité ici toutes les 5 s tant que le profil est chargé.
	Tour payant : proposé seulement si le produit est configuré (Config/ProductsConfig) et si le pays du
	joueur n'interdit pas les objets aléatoires payants (PolicyService ; inconnu = non proposé).
]]

local PolicyService = game:GetService("PolicyService")

local ProductsConfig = require(script.Parent.Parent.Config.ProductsConfig)
local Rewards = require(script.Parent.Parent.Rules.Rewards)

local RewardService = {}

local ctx
local deps
local rng = Random.new()

function RewardService.init(context, dependencies)
	ctx = context
	deps = dependencies
end

-- { productId, allowed } pour Rules/Rewards.view : tour payant proposé ou non à ce joueur
function RewardService.paidInfo(player: Player): { productId: number?, allowed: boolean }
	local session = deps.Sessions.get(player)
	local productId = ProductsConfig.wheelSpin.id
	return {
		productId = if productId > 0 then productId else nil,
		allowed = session ~= nil and session.paidRandomAllowed == true,
	}
end

-- Lit la politique du pays du joueur (appel réseau) ; tant qu'elle est inconnue, rien de payant n'est proposé
function RewardService.onProfileLoaded(player: Player)
	task.spawn(function()
		local ok, info = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		local session = deps.Sessions.get(player)
		if session == nil then
			return
		end
		session.paidRandomAllowed = ok
			and type(info) == "table"
			and info.ArePaidRandomItemsRestricted == false
		session.policyKnown = true
		if not ok then
			warn(`[RewardService] politique illisible pour {player.UserId} : tour payant masqué`)
		end
		deps.State.markDirty(player)
	end)
end

local function announce(player: Player, data, kind: string, result: { [string]: any })
	local event = table.clone(result)
	event.kind = kind
	deps.State.notify(player, event)
	deps.Metrics.reward(player, data, kind, result)
end

-- Intention « SpinWheel »
function RewardService.onSpinWheel(player: Player, payload: { [any]: any }?)
	if payload == nil then
		return
	end
	local pay = payload.pay
	deps.Mutations.run(player, "SpinWheel", payload.requestId, function(data, session)
		local now = os.clock()
		if session.lastSpinAt ~= nil and now - session.lastSpinAt < ctx.Balance.wheel.minIntervalSeconds then
			return "cooldown"
		end
		local day = Rewards.day(os.time())
		local reason = Rewards.checkSpin(data, pay, day, ctx)
		if reason ~= nil then
			return reason
		end
		session.lastSpinAt = now
		return nil, Rewards.applySpin(data, pay, day, rng:NextNumber(), rng:NextNumber(), ctx)
	end, function(target: Player, data, result)
		deps.Metrics.reward(target, data, "wheel", result)
	end)
end

-- Intention « ClaimDaily »
function RewardService.onClaimDaily(player: Player, payload: { [any]: any }?)
	if payload == nil then
		return
	end
	deps.Mutations.run(player, "ClaimDaily", payload.requestId, function(data)
		local day = Rewards.day(os.time())
		local reason = Rewards.checkDaily(data, day)
		if reason ~= nil then
			return reason
		end
		return nil, Rewards.applyDaily(data, day, ctx)
	end, function(target: Player, data, result)
		announce(target, data, "dailyReward", result)
	end)
end

-- Intention « ClaimPlaytime »
function RewardService.onClaimPlaytime(player: Player, payload: { [any]: any }?)
	if payload == nil then
		return
	end
	local index = payload.index
	deps.Mutations.run(player, "ClaimPlaytime", payload.requestId, function(data)
		local day = Rewards.day(os.time())
		local reason = Rewards.checkPlaytime(data, index, day, ctx)
		if reason ~= nil then
			return reason
		end
		return nil, Rewards.applyPlaytime(data, index, day, ctx)
	end, function(target: Player, data, result)
		announce(target, data, "playtimeReward", result)
	end)
end

local function tick()
	local now = os.clock()
	local day = Rewards.day(os.time())
	for player, session in deps.Sessions.all() do
		local last = session.lastPlaytimeAt or now
		local data = deps.Profiles.get(player)
		-- pas pendant une décision durable : le compteur rattrape au tick suivant (borné par maxTickSeconds)
		if data ~= nil and not session.mutating then
			session.lastPlaytimeAt = now
			local previousDay = data.rewards.playtime.day
			local ready = Rewards.tickPlaytime(data, day, now - last, ctx)
			if ready then
				deps.State.notify(player, { kind = "playtimeReady" })
			end
			if ready or previousDay ~= day then
				deps.State.markDirty(player) -- nouveau palier, ou nouveau jour (tour gratuit, connexion)
			end
		end
	end
end

function RewardService.start()
	task.spawn(function()
		while true do
			task.wait(ctx.Balance.playtime.tickSeconds)
			local ok, err = pcall(tick)
			if not ok then
				warn(`[RewardService] erreur du temps de jeu : {err}`)
			end
		end
	end)
end

return RewardService
