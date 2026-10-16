--!strict
--[[
	Movement : contrôle serveur des déplacements pendant un combat (dossier §25, module pur).

	Le client possède la physique de son personnage (propriété réseau Roblox) : il peut déplacer son
	avatar plus vite que permis ou se téléporter. Le serveur compare chaque position reçue à la
	précédente, dans le plan horizontal (les zones de danger sont en 2D : voler n'esquive rien).

	Seau de distance : la réserve se remplit à la vitesse permise (WalkSpeed SERVEUR × tolérance + marge)
	et chaque déplacement la vide. Un pic de latence (positions retenues puis rattrapées d'un coup) est
	couvert par la réserve de `burstSeconds`. Au-delà de la réserve et d'une marge `slackStuds`, c'est
	une anomalie : la réserve repart de zéro (la même avance n'est pas comptée deux fois).

	Une anomalie isolée ne fait rien de visible (jamais de bannissement sur un pic, §25). `maxStrikes`
	anomalies en `strikeWindowSeconds` invalident la rencontre : le service la ferme sans récompense.
]]

export type Point = { x: number, y: number, z: number }

export type Config = {
	speedTolerance: number,
	extraStudsPerSecond: number,
	burstSeconds: number,
	slackStuds: number,
	strikeWindowSeconds: number,
	maxStrikes: number,
}

export type Tracker = {
	pos: Point,
	at: number,
	budget: number, -- studs horizontaux encore permis avant une anomalie
	strikes: { number }, -- instants des anomalies récentes
}

export type Observation = {
	status: string, -- "ok" | "strike" | "invalid"
	distance: number, -- déplacement horizontal depuis l'observation précédente
	seconds: number, -- temps écoulé depuis l'observation précédente
	excess: number, -- studs au-delà de la réserve et de la marge (0 si « ok »)
	strikes: number, -- anomalies dans la fenêtre, celle-ci comprise
}

local Movement = {}

-- Vitesse permise (studs/s) pour une WalkSpeed lue CÔTÉ SERVEUR
function Movement.allowedSpeed(walkSpeed: number, cfg: Config): number
	local speed = if walkSpeed == walkSpeed and walkSpeed > 0 then walkSpeed else 0
	return speed * cfg.speedTolerance + cfg.extraStudsPerSecond
end

function Movement.capacity(walkSpeed: number, cfg: Config): number
	return Movement.allowedSpeed(walkSpeed, cfg) * cfg.burstSeconds
end

function Movement.horizontalDistance(a: Point, b: Point): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- Début du suivi (début de rencontre) : réserve pleine
function Movement.new(pos: Point, now: number, walkSpeed: number, cfg: Config): Tracker
	return { pos = pos, at = now, budget = Movement.capacity(walkSpeed, cfg), strikes = {} }
end

-- Déplacement voulu par le serveur (téléportation du jeu, nouveau personnage) : on repart de là,
-- réserve pleine, sans effacer les anomalies déjà comptées.
function Movement.reset(tracker: Tracker, pos: Point, now: number, walkSpeed: number, cfg: Config)
	tracker.pos = pos
	tracker.at = now
	tracker.budget = Movement.capacity(walkSpeed, cfg)
end

local function forget(tracker: Tracker, now: number, cfg: Config)
	local kept = {}
	for _, at in tracker.strikes do
		if now - at < cfg.strikeWindowSeconds then
			table.insert(kept, at)
		end
	end
	tracker.strikes = kept
end

function Movement.observe(
	tracker: Tracker,
	pos: Point,
	now: number,
	walkSpeed: number,
	cfg: Config
): Observation
	local seconds = math.max(0, now - tracker.at)
	local distance = Movement.horizontalDistance(tracker.pos, pos)
	if distance ~= distance then
		distance = math.huge -- position illisible (NaN) : traitée comme une téléportation
	end
	tracker.pos = pos
	tracker.at = now

	local refill = Movement.allowedSpeed(walkSpeed, cfg) * seconds
	local budget = math.min(Movement.capacity(walkSpeed, cfg), tracker.budget + refill) - distance
	forget(tracker, now, cfg)

	if budget >= -cfg.slackStuds then
		tracker.budget = budget
		return {
			status = "ok",
			distance = distance,
			seconds = seconds,
			excess = 0,
			strikes = #tracker.strikes,
		}
	end

	tracker.budget = 0
	table.insert(tracker.strikes, now)
	local strikes = #tracker.strikes
	return {
		status = if strikes >= cfg.maxStrikes then "invalid" else "strike",
		distance = distance,
		seconds = seconds,
		excess = -budget - cfg.slackStuds,
		strikes = strikes,
	}
end

return Movement
