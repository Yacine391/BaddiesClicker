--[[
	CombatService : combat individuel côté serveur (dossier §08, §10, §25, §26).

	- Chaque joueur a SES ennemis : positions, PV, télégraphies et impacts sont calculés ici ;
	  les autres joueurs ne peuvent ni tuer sa cible ni subir ses dégâts.
	- Entrer dans l'arène d'un niveau accessible et non terminé lance la vague.
	  StartWave(levelId) relance un niveau déjà terminé depuis son arène.
	- Le client affiche (remote Combat) et envoie des intentions : il ne décide jamais
	  d'un dégât, d'une victoire ni d'un drop.
	- Mort : rencontre close sans récompense, portes refermées, retour au lobby.
	- Victoire boss : récompenses + tirage UNIQUE à 10 % + sauvegarde prioritaire.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local CombatRules = require(script.Parent.Parent.Rules.Combat)
local Encounter = require(script.Parent.Parent.Rules.Encounter)

local CombatService = {}

local ctx
local deps
local combatRemote: RemoteEvent
local rng = Random.new()
local serial = 0

function CombatService.init(context, dependencies)
	ctx = context
	deps = dependencies
	-- Déclaré dans default.project.json (ReplicatedStorage/Remotes) ; créé ici seulement s'il manque
	-- (place sans Rojo, ancien fichier .rbxl).
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	if remotes:FindFirstChild(Net.COMBAT) == nil then
		local remote = Instance.new("RemoteEvent")
		remote.Name = Net.COMBAT
		remote.Parent = remotes
	end
	combatRemote = Net.remote(Net.COMBAT)
end

local function send(player: Player, message: { [string]: any })
	combatRemote:FireClient(player, message)
end

-- Position d'un joueur vivant, ou nil (pas de personnage, ou mort)
local function livePosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return nil
	end
	return root.Position
end

local function flat(position: Vector3): Encounter.Vec2
	return { x = position.X, z = position.Z }
end

local function notifyMastery(player: Player, baddieId: string?, level: number?)
	if baddieId ~= nil and level ~= nil then
		deps.State.notify(player, { kind = "masteryUp", baddieId = baddieId, level = level })
	end
end

local function endEncounter(player: Player, session, reason: string)
	local encounter = session.encounter
	if encounter == nil then
		return
	end
	encounter.phase = "ended"
	session.encounter = nil
	session.inCombat = false
	session.hp = ctx.Balance.combat.playerHP -- PV restaurés hors combat
	session.outsideSince = nil
	send(player, { t = "end", encounterId = encounter.id, reason = reason })
	deps.State.markDirty(player)
end

function CombatService.startEncounter(player: Player, session, data, levelId: number): boolean
	if session.encounter ~= nil or not CombatRules.isAccessible(data, levelId, ctx) then
		return false
	end
	local arena = deps.World.arena(levelId)
	local position = livePosition(player)
	if arena == nil or position == nil or not deps.World.isInside(arena, position) then
		return false -- il faut être physiquement dans l'arène de ce niveau
	end
	local cfg = CombatRules.levelConfig(levelId, ctx)
	if cfg == nil then
		return false
	end

	serial += 1
	local id = `{player.UserId}-{serial}`
	session.encounter = Encounter.new(id, levelId, cfg, arena.bounds, os.clock())
	session.inCombat = true
	session.hp = ctx.Balance.combat.playerHP
	session.outsideSince = nil

	deps.Metrics.encounterStarted(player, data, session, levelId)
	send(player, {
		t = "start",
		encounterId = id,
		levelId = levelId,
		floorY = arena.floorY,
		hp = session.hp,
		maxHP = ctx.Balance.combat.playerHP,
		minionsTotal = cfg.minions,
		boss = cfg.boss,
	})
	deps.State.markDirty(player)
	return true
end

local function onDeath(player: Player, session, data, respawn: boolean)
	local levelId = if session.encounter ~= nil then session.encounter.levelId else nil
	endEncounter(player, session, "death")
	CombatRules.applyDeath(data, ctx)
	if levelId ~= nil then
		deps.Metrics.died(player, data, session, levelId)
	end
	deps.State.notify(player, { kind = "death" })
	deps.State.markDirty(player)
	if respawn then
		task.delay(ctx.Balance.combat.respawnDelay, function()
			if player.Parent == Players then
				local ok, err = pcall(function()
					player:LoadCharacterAsync() -- retour au spawn du lobby
				end)
				if not ok then
					warn(`[CombatService] respawn impossible pour {player.Name} : {err}`)
				end
			end
		end)
	end
end

local function onBossVictory(player: Player, session, data, encounter)
	-- La rencontre est déjà « finalizing » : plus aucune attaque ni impact n'est accepté.
	local victory = CombatRules.applyBossVictory(data, encounter.levelId, rng:NextNumber(), ctx)
	endEncounter(player, session, "victory")
	deps.Profiles.saveNow(player) -- écriture prioritaire (§27)
	deps.State.notify(player, {
		kind = "levelCleared",
		level = encounter.levelId,
		boss = encounter.cfg.boss,
		drop = victory.drop,
		firstClear = victory.firstClear,
		baddieTickets = victory.baddieTickets,
		power = victory.power,
	})
	notifyMastery(player, victory.masteryBaddie, victory.masteryUp)
	deps.Metrics.bossDefeated(player, data, encounter.levelId, victory)
end

-- Intention « Attack » : { encounterId: string, targetId: string? }
function CombatService.onAttack(player: Player, payload: { [any]: any }?)
	if payload == nil then
		return
	end
	local data = deps.Profiles.get(player)
	local session = deps.Sessions.get(player)
	if data == nil or session == nil then
		return
	end
	local encounter = session.encounter
	if encounter == nil or payload.encounterId ~= encounter.id then
		return
	end
	local targetId = payload.targetId
	if targetId ~= nil and type(targetId) ~= "string" then
		return
	end
	local position = livePosition(player)
	if position == nil then
		return
	end

	local C = ctx.Balance.combat
	local damage = CombatRules.attackDamage(data, ctx)
	local result =
		Encounter.attack(encounter, targetId, flat(position), damage, C.attackRange + C.rangeTolerance)
	if result == nil then
		return
	end

	send(player, {
		t = "hit",
		targetId = result.targetId,
		damage = result.damage,
		hp = result.hp,
		killed = result.killed,
	})
	if result.killed then
		if result.kind == "boss" then
			onBossVictory(player, session, data, encounter)
		else
			local reward = CombatRules.applyMinionKill(data, encounter.levelId, ctx)
			notifyMastery(player, reward.masteryBaddie, reward.masteryUp)
		end
	end
	deps.State.markDirty(player)
end

-- Intention « StartWave » : { levelId: number } (rejouer un niveau depuis son arène)
function CombatService.onStartWave(player: Player, payload: { [any]: any }?)
	if payload == nil or not CombatRules.isValidLevelId(payload.levelId, ctx) then
		return
	end
	local data = deps.Profiles.get(player)
	local session = deps.Sessions.get(player)
	if data == nil or session == nil then
		return
	end
	CombatService.startEncounter(player, session, data, payload.levelId)
end

local function tickPlayer(player: Player, session, now: number)
	local data = deps.Profiles.get(player)
	if data == nil then
		return
	end
	local position = livePosition(player)
	local encounter = session.encounter

	if encounter == nil then
		-- Entrée dans une arène accessible et non terminée : la vague commence
		if position ~= nil then
			local levelId = deps.World.levelAt(position)
			if levelId ~= nil and not CombatRules.isCleared(data, levelId) then
				CombatService.startEncounter(player, session, data, levelId)
			end
		end
		return
	end

	if position == nil then
		onDeath(player, session, data, false) -- chute ou reset : Roblox fait respawn le personnage
		return
	end

	local arena = deps.World.arena(encounter.levelId)
	if arena ~= nil and not deps.World.isInside(arena, position) then
		session.outsideSince = session.outsideSince or now
		if now - session.outsideSince >= ctx.Balance.combat.leaveArenaGraceSeconds then
			endEncounter(player, session, "left")
			deps.State.notify(player, { kind = "combatLeft" })
			return
		end
	else
		session.outsideSince = nil
	end

	local events = Encounter.step(encounter, now, flat(position), ctx)
	for _, event in events do
		if event.type == "spawn" then
			send(player, { t = "spawn", enemy = event.enemy })
		elseif event.type == "telegraph" then
			send(player, {
				t = "telegraph",
				enemyId = event.enemyId,
				x = event.x,
				z = event.z,
				radius = event.radius,
				duration = event.duration,
			})
		elseif event.type == "impact" then
			if event.hit then
				session.hp = math.max(0, session.hp - event.damage)
			end
			send(player, {
				t = "impact",
				enemyId = event.enemyId,
				x = event.x,
				z = event.z,
				radius = event.radius,
				hit = event.hit,
				damage = event.damage,
				hp = session.hp,
			})
			if session.hp <= 0 then
				onDeath(player, session, data, true)
				return
			end
		end
	end
	if #events > 0 then
		deps.State.markDirty(player)
	end

	local list = {}
	for _, id in encounter.alive do
		local enemy = encounter.enemies[id]
		table.insert(list, { id, math.round(enemy.pos.x * 10) / 10, math.round(enemy.pos.z * 10) / 10 })
	end
	if #list > 0 then
		send(player, { t = "pos", list = list })
	end
end

function CombatService.start()
	task.spawn(function()
		while true do
			task.wait(ctx.Balance.combat.tickSeconds)
			local now = os.clock()
			for player, session in deps.Sessions.all() do
				local ok, err = pcall(tickPlayer, player, session, now)
				if not ok then
					warn(`[CombatService] erreur pour {player.Name} : {err}`)
				end
			end
		end
	end)
end

return CombatService
