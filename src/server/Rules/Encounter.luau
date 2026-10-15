--!strict
--[[
	Encounter : une rencontre individuelle (vague de sbires puis boss), simulée par le serveur.
	Module pur : positions en 2D { x, z }, temps passé en argument. Testé dans tests/run.luau.

	Cycle d'un ennemi (§08) : approche → télégraphie → impact → récupération.
	- Sbire : frappe lente centrée sur la position du joueur au début de la télégraphie.
	- Boss : frappe en cercle centrée sur lui.
	Les zones et l'instant d'impact sont décidés ici ; le cercle au sol n'est qu'un rendu client.
	L'arène est orientée : entrée au sud (+Z), apparition des ennemis au nord (-Z).
]]

export type Vec2 = { x: number, z: number }
export type Bounds = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Telegraph = { center: Vec2, radius: number, impactAt: number }

export type Enemy = {
	id: string,
	kind: string, -- "minion" | "boss"
	baddieId: string?,
	hp: number,
	maxHP: number,
	pos: Vec2,
	state: string, -- "approach" | "telegraph" | "recover"
	stateUntil: number,
	telegraph: Telegraph?,
	damage: number,
}

export type Encounter = {
	id: string,
	levelId: number,
	phase: string, -- "wave" | "boss" | "finalizing" | "ended"
	enemies: { [string]: Enemy },
	alive: { string }, -- ordre d'apparition
	minionsToSpawn: number,
	minionsTotal: number,
	minionsKilled: number,
	nextSpawnAt: number,
	lastStepAt: number,
	bounds: Bounds,
	cfg: any,
	serial: number,
}

export type AttackResult = { targetId: string, damage: number, hp: number, killed: boolean, kind: string }

local Encounter = {}

local function distance(a: Vec2, b: Vec2): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end
Encounter.distance = distance

local function clampToBounds(p: Vec2, b: Bounds): Vec2
	return { x = math.clamp(p.x, b.minX + 2, b.maxX - 2), z = math.clamp(p.z, b.minZ + 2, b.maxZ - 2) }
end

function Encounter.isInside(b: Bounds, p: Vec2): boolean
	return p.x >= b.minX and p.x <= b.maxX and p.z >= b.minZ and p.z <= b.maxZ
end

function Encounter.new(id: string, levelId: number, cfg: any, bounds: Bounds, now: number): Encounter
	return {
		id = id,
		levelId = levelId,
		phase = "wave",
		enemies = {},
		alive = {},
		minionsToSpawn = cfg.minions,
		minionsTotal = cfg.minions,
		minionsKilled = 0,
		nextSpawnAt = now,
		lastStepAt = now,
		bounds = bounds,
		cfg = cfg,
		serial = 0,
	}
end

function Encounter.publicEnemy(e: Enemy): { [string]: any }
	return {
		id = e.id,
		kind = e.kind,
		baddieId = e.baddieId,
		hp = e.hp,
		maxHP = e.maxHP,
		x = e.pos.x,
		z = e.pos.z,
	}
end

local function spawn(enc: Encounter, kind: string, now: number): Enemy
	enc.serial += 1
	local b = enc.bounds
	local centerX = (b.minX + b.maxX) / 2
	local depth = b.maxZ - b.minZ
	local isBoss = kind == "boss"
	local offsets = { -10, 10, 0 }
	local pos = if isBoss
		then { x = centerX, z = b.minZ + depth * 0.2 }
		else { x = centerX + offsets[(enc.serial - 1) % 3 + 1], z = b.minZ + depth * 0.25 }
	local hp = if isBoss then enc.cfg.bossHP else enc.cfg.minionHP
	local enemy: Enemy = {
		id = `{enc.id}:{enc.serial}`,
		kind = kind,
		baddieId = if isBoss then enc.cfg.boss else nil,
		hp = hp,
		maxHP = hp,
		pos = pos,
		state = "approach",
		stateUntil = now,
		telegraph = nil,
		damage = if isBoss then enc.cfg.bossDamage else enc.cfg.minionDamage,
	}
	enc.enemies[enemy.id] = enemy
	table.insert(enc.alive, enemy.id)
	return enemy
end

-- Avance la simulation jusqu'à `now` ; renvoie les événements (spawn, telegraph, impact)
function Encounter.step(enc: Encounter, now: number, player: Vec2, ctx: any): { { [string]: any } }
	local events = {}
	local dt = math.max(0, now - enc.lastStepAt)
	enc.lastStepAt = now
	if enc.phase ~= "wave" and enc.phase ~= "boss" then
		return events -- victoire en cours de finalisation ou rencontre close : plus aucun impact
	end
	local C = ctx.Balance.combat

	if enc.phase == "wave" then
		while enc.minionsToSpawn > 0 and #enc.alive < C.maxSimultaneousMinions and now >= enc.nextSpawnAt do
			enc.minionsToSpawn -= 1
			enc.nextSpawnAt = now + C.minionSpawnDelay
			table.insert(events, { type = "spawn", enemy = Encounter.publicEnemy(spawn(enc, "minion", now)) })
		end
		if enc.minionsToSpawn == 0 and #enc.alive == 0 then
			enc.phase = "boss"
			table.insert(events, { type = "spawn", enemy = Encounter.publicEnemy(spawn(enc, "boss", now)) })
		end
	end

	for _, id in enc.alive do
		local e = enc.enemies[id]
		local p = if e.kind == "boss" then C.boss else C.minion
		if e.state == "approach" then
			local d = distance(e.pos, player)
			if d > p.engageDistance then
				local stepLength = math.min(p.speed * dt, d - p.engageDistance)
				e.pos = clampToBounds({
					x = e.pos.x + (player.x - e.pos.x) / d * stepLength,
					z = e.pos.z + (player.z - e.pos.z) / d * stepLength,
				}, enc.bounds)
			else
				local center = if e.kind == "boss"
					then { x = e.pos.x, z = e.pos.z }
					else { x = player.x, z = player.z }
				e.state = "telegraph"
				e.telegraph = { center = center, radius = p.radius, impactAt = now + p.telegraphSeconds }
				table.insert(events, {
					type = "telegraph",
					enemyId = e.id,
					x = center.x,
					z = center.z,
					radius = p.radius,
					duration = p.telegraphSeconds,
				})
			end
		elseif e.state == "telegraph" then
			local t = e.telegraph
			if t ~= nil and now >= t.impactAt then
				local hit = distance(player, t.center) <= t.radius - C.dodgeTolerance
				table.insert(events, {
					type = "impact",
					enemyId = e.id,
					x = t.center.x,
					z = t.center.z,
					radius = t.radius,
					hit = hit,
					damage = if hit then e.damage else 0,
				})
				e.telegraph = nil
				e.state = "recover"
				e.stateUntil = now + p.recoverySeconds
			end
		elseif e.state == "recover" and now >= e.stateUntil then
			e.state = "approach"
		end
	end

	return events
end

-- Une action d'attaque : la cible choisie si elle est valide, sinon la plus proche à portée.
-- Une seule application de dégâts ; aucune après la mort du boss.
function Encounter.attack(
	enc: Encounter,
	targetId: string?,
	player: Vec2,
	damage: number,
	range: number
): (AttackResult?, string?)
	if enc.phase ~= "wave" and enc.phase ~= "boss" then
		return nil, "phase"
	end
	if damage <= 0 then
		return nil, "noDamage"
	end

	local target: Enemy? = nil
	if targetId ~= nil then
		local chosen = enc.enemies[targetId]
		if chosen ~= nil and chosen.hp > 0 and distance(chosen.pos, player) <= range then
			target = chosen
		end
	end
	if target == nil then
		local best = math.huge
		for _, id in enc.alive do
			local e = enc.enemies[id]
			local d = distance(e.pos, player)
			if d <= range and d < best then
				best = d
				target = e
			end
		end
	end
	if target == nil then
		return nil, "noTarget"
	end

	local dealt = math.min(damage, target.hp)
	target.hp -= dealt
	local killed = target.hp <= 0
	if killed then
		target.hp = 0
		enc.enemies[target.id] = nil
		local index = table.find(enc.alive, target.id)
		if index ~= nil then
			table.remove(enc.alive, index)
		end
		if target.kind == "boss" then
			enc.phase = "finalizing"
		else
			enc.minionsKilled += 1
		end
	end
	return { targetId = target.id, damage = dealt, hp = target.hp, killed = killed, kind = target.kind }, nil
end

return Encounter
