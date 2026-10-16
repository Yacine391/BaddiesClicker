--!strict
--[[
	CombatModel : état d'affichage du combat, construit à partir du flux `Combat` du serveur
	(docs/CONTRACT.md « Flux Combat ») et du snapshot. Module pur, testé dans tests/client/run.luau.
	Le client ne décide de rien : il range ce que le serveur annonce (ennemis, PV, phase) et en
	tire les textes des barres, des toasts et du bouton « rejouer ».
]]

local CombatModel = {}

export type Enemy = {
	id: string,
	kind: string, -- "minion" | "boss"
	baddieId: string?,
	hp: number,
	maxHP: number,
	x: number,
	z: number,
}

export type State = {
	encounterId: string?,
	levelId: number?,
	floorY: number,
	boss: string?, -- baddieId du boss annoncé au début
	minionsTotal: number,
	minionsKilled: number,
	bossId: string?, -- id de l'ennemi boss une fois apparu
	enemies: { [string]: Enemy },
}

export type Bar = { visible: boolean, title: string, ratio: number, text: string, isBoss: boolean }
export type PlayerBar = { visible: boolean, ratio: number, text: string, low: boolean }
export type Hint = { visible: boolean, text: string, ready: boolean }

local LOW_HP = 0.3

function CombatModel.new(): State
	return {
		encounterId = nil,
		levelId = nil,
		floorY = 0,
		boss = nil,
		minionsTotal = 0,
		minionsKilled = 0,
		bossId = nil,
		enemies = {},
	}
end

local function number(value: any, default: number): number
	local n = tonumber(value)
	if n == nil or n ~= n then
		return default
	end
	return n
end

-- Applique un message du flux Combat ; renvoie l'ennemi concerné (spawn, hit) s'il y en a un
function CombatModel.apply(state: State, message: { [string]: any }): Enemy?
	local t = message.t
	if t == "start" then
		state.encounterId = message.encounterId
		state.levelId = tonumber(message.levelId)
		state.floorY = number(message.floorY, 0)
		state.boss = message.boss
		state.minionsTotal = number(message.minionsTotal, 0)
		state.minionsKilled = 0
		state.bossId = nil
		table.clear(state.enemies)
		return nil
	elseif t == "spawn" then
		local e = message.enemy
		if type(e) ~= "table" or type(e.id) ~= "string" then
			return nil
		end
		local enemy: Enemy = {
			id = e.id,
			kind = if e.kind == "boss" then "boss" else "minion",
			baddieId = e.baddieId,
			hp = number(e.hp, 0),
			maxHP = math.max(1, number(e.maxHP, 1)),
			x = number(e.x, 0),
			z = number(e.z, 0),
		}
		state.enemies[enemy.id] = enemy
		if enemy.kind == "boss" then
			state.bossId = enemy.id
		end
		return enemy
	elseif t == "pos" then
		for _, item in message.list or {} do
			local enemy = state.enemies[item[1]]
			if enemy ~= nil then
				enemy.x = number(item[2], enemy.x)
				enemy.z = number(item[3], enemy.z)
			end
		end
		return nil
	elseif t == "hit" then
		local enemy = state.enemies[message.targetId]
		if enemy == nil then
			return nil
		end
		enemy.hp = math.max(0, number(message.hp, enemy.hp))
		if message.killed then
			state.enemies[enemy.id] = nil
			if enemy.kind == "minion" then
				state.minionsKilled += 1
			end
		end
		return enemy
	elseif t == "end" then
		state.encounterId = nil
		state.levelId = nil
		state.bossId = nil
		table.clear(state.enemies)
		return nil
	end
	return nil
end

function CombatModel.active(state: State): boolean
	return state.encounterId ~= nil
end

local function bossName(id: string?, catalog: any): string
	local def = if id ~= nil then catalog.baddies[id] else nil
	return if def ~= nil then string.upper(def.name) else "BOSS"
end

-- Barre du haut : progression de la vague, puis PV du boss
function CombatModel.bar(state: State, catalog: any, format: (number) -> string): Bar
	if state.encounterId == nil then
		return { visible = false, title = "", ratio = 0, text = "", isBoss = false }
	end
	local boss = if state.bossId ~= nil then state.enemies[state.bossId] else nil
	if boss ~= nil then
		return {
			visible = true,
			title = `NIVEAU {state.levelId or "?"} · BOSS {bossName(boss.baddieId, catalog)}`,
			ratio = math.clamp(boss.hp / boss.maxHP, 0, 1),
			text = `{format(boss.hp)} / {format(boss.maxHP)}`,
			isBoss = true,
		}
	end
	local total = math.max(1, state.minionsTotal)
	return {
		visible = true,
		title = `NIVEAU {state.levelId or "?"} · SBIRES`,
		ratio = math.clamp(state.minionsKilled / total, 0, 1),
		text = `{state.minionsKilled} / {state.minionsTotal} · puis {bossName(state.boss, catalog)}`,
		isBoss = false,
	}
end

-- PV du joueur (snapshot.combat, jamais calculés par le client)
function CombatModel.playerBar(snapshot: { [string]: any }?): PlayerBar
	local combat = if snapshot ~= nil then snapshot.combat else nil
	if type(combat) ~= "table" or combat.active ~= true then
		return { visible = false, ratio = 1, text = "", low = false }
	end
	local maxHP = math.max(1, number(combat.maxHP, 100))
	local hp = math.clamp(number(combat.hp, maxHP), 0, maxHP)
	local ratio = hp / maxHP
	return { visible = true, ratio = ratio, text = `{math.ceil(hp)} PV`, low = ratio <= LOW_HP }
end

-- Bouton « rejouer » : dans l'arène d'un niveau déjà terminé, hors combat
function CombatModel.replayLevel(snapshot: { [string]: any }?, arenaLevel: number?): number?
	if snapshot == nil or arenaLevel == nil or snapshot.mode == "combat" then
		return nil
	end
	for _, levelId in snapshot.clearedLevels or {} do
		if levelId == arenaLevel then
			return arenaLevel
		end
	end
	return nil
end

-- §09 « puissance conseillée » (champ nextLevel du snapshot, serveur v4-p1) : un conseil, jamais une garantie
function CombatModel.hint(snapshot: { [string]: any }?, format: (number) -> string): Hint
	local nextLevel = if snapshot ~= nil then snapshot.nextLevel else nil
	if snapshot == nil or snapshot.mode == "combat" or type(nextLevel) ~= "table" then
		return { visible = false, text = "", ready = false }
	end
	local recommended = tonumber(nextLevel.recommendedPower)
	local levelId = tonumber(nextLevel.levelId)
	if recommended == nil or levelId == nil then
		return { visible = false, text = "", ready = false }
	end
	local power = number(snapshot.power, 0)
	return {
		visible = true,
		text = `NIVEAU {levelId} · puissance conseillée {format(recommended)}`,
		ready = power >= recommended,
	}
end

-- Messages des Result liés au combat (les autres restent au HUD et aux bannières RGB)
function CombatModel.toastFor(event: { [string]: any }, catalog: any, format: (number) -> string): string?
	local kind = event.kind
	if kind == "levelCleared" then
		local text = `Niveau {event.level} terminé : +{format(number(event.power, 0))} puissance`
		if event.firstClear and number(event.baddieTickets, 0) > 0 then
			text ..= ", +1 ticket"
		end
		if event.drop ~= nil then
			return text .. ` · drop de {bossName(event.drop, catalog)} en attente`
		end
		return text .. " · pas de drop (10 % par victoire)"
	elseif kind == "death" then
		return "K.O. : retour au lobby. Puissance et baddies gardées, portes refermées."
	elseif kind == "combatLeft" then
		return "Combat abandonné : tu as quitté l'arène."
	elseif kind == "combatInvalid" then
		return "Combat annulé : déplacement anormal détecté."
	end
	return nil
end

return CombatModel
