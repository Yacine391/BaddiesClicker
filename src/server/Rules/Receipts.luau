--!strict
--[[
	Reçus et protocole des décisions durables (module pur, testé dans tests/run.luau). Dossier §25, §26, §27, §36.

	`requestId` est une clé de reprise, pas une permission : le client en génère un par décision
	(relance, drop accepté/refusé, renaissance, coffre) et le RÉUTILISE s'il doit renvoyer la même
	décision après une erreur ambiguë. Le profil garde le reçu de la décision la plus récente (sauvegardé
	avec elle) : un renvoi du même requestId rend le même résultat, sans nouvel effet ni nouveau tirage.
	Seules les décisions réussies laissent un reçu. Les renvois plus anciens sont bloqués par les
	révisions (slotRevision, pendingRevision, run.id).

	`Receipts.run` déroule tout le protocole avec un environnement injecté (`env`) : MutationService
	branche ProfileStore et les remotes, les tests branchent un faux DataStore et simulent les pannes.
	1. Une seule décision à la fois par session : une autre reçoit "busy".
	2. Même requestId déjà traité → même résultat (replay), sans effet ; écriture en attente reconfirmée.
	3. Une décision précédente dont l'écriture est incertaine est d'abord re-sauvegardée ; échec → "saving".
	4. Interrupteur de maintenance (§36) → "maintenance" (les renvois de reçus restent servis).
	5. Validation + application d'un bloc (`apply`, sans yield), reçu, puis écriture attendue (`env.save`).
	6. Réponse après l'écriture ; `onConfirmed` (annonces) seulement une fois l'écriture confirmée.
]]

export type Receipt = { requestId: string, action: string, result: { [string]: any }, revision: number }
export type Apply = (data: any, session: any) -> (string?, { [string]: any }?)
export type OnConfirmed = (data: any, result: { [string]: any }) -> ()
export type Pending = {
	requestId: string,
	action: string,
	result: { [string]: any },
	onConfirmed: OnConfirmed?,
}

export type Env = {
	getData: () -> any?, -- profil actif, ou nil s'il n'est plus chargé
	save: (requestId: string) -> boolean, -- écriture prioritaire : true si la copie écrite contient ce reçu
	reply: (event: { [string]: any }) -> (), -- Result { kind = "mutation", ... }
	isDisabled: ((action: string) -> boolean)?, -- interrupteurs de maintenance
	begin: (() -> ())?, -- « sauvegarde en cours » (avant le travail)
	finish: (() -> ())?, -- état et attributs à jour (après la réponse)
	log: ((line: string) -> ())?,
	clock: (() -> number)?,
}

local Receipts = {}

Receipts.MAX_LENGTH = 64

function Receipts.isValidRequestId(requestId: any): boolean
	return type(requestId) == "string" and #requestId >= 1 and #requestId <= Receipts.MAX_LENGTH
end

-- Reçu enregistré pour ce requestId, ou nil
function Receipts.find(data: any, requestId: string): Receipt?
	local receipt = data.lastMutation
	if type(receipt) == "table" and receipt.requestId == requestId then
		return receipt :: Receipt
	end
	return nil
end

-- Après une décision réussie : révision globale +1 et reçu durable (écrit avec la décision)
function Receipts.record(data: any, requestId: string, action: string, result: { [string]: any }): Receipt
	data.revision += 1
	local receipt: Receipt =
		{ requestId = requestId, action = action, result = result, revision = data.revision }
	data.lastMutation = receipt
	return receipt
end

-- La copie sauvegardée contient-elle ce reçu ? (prédicat pour Profiles.saveAndWait)
function Receipts.isSaved(savedData: any, requestId: string): boolean
	return type(savedData) == "table"
		and type(savedData.lastMutation) == "table"
		and savedData.lastMutation.requestId == requestId
end

local function reply(
	env: Env,
	action: string,
	requestId: string,
	ok: boolean,
	reason: string?,
	result: { [string]: any }?,
	confirmed: boolean,
	replay: boolean?
)
	env.reply({
		kind = "mutation",
		action = action,
		requestId = requestId,
		ok = ok,
		reason = reason,
		result = result,
		confirmed = confirmed,
		replay = replay,
	})
end

local function log(env: Env, line: string)
	if env.log ~= nil then
		env.log(line)
	end
end

-- Confirme la décision en attente ; renvoie (plus rien en attente ?, décision tout juste confirmée)
local function resolvePending(env: Env, session: any): (boolean, Pending?)
	local pending: Pending? = session.unconfirmed
	if pending == nil then
		return true, nil
	end
	if not env.save(pending.requestId) then
		return false, nil
	end
	session.unconfirmed = nil
	log(env, `{pending.action} {pending.requestId} confirmée au second essai`)
	return true, pending
end

local function followUp(env: Env, pending: Pending?)
	local data = env.getData()
	if pending ~= nil and pending.onConfirmed ~= nil and data ~= nil then
		pending.onConfirmed(data, pending.result)
	end
end

local function process(
	env: Env,
	session: any,
	action: string,
	requestId: string,
	apply: Apply,
	onConfirmed: OnConfirmed?
)
	-- 2. Renvoi d'une décision déjà traitée (le reçu est toujours celui de la dernière décision)
	local data = env.getData()
	if data == nil then
		return
	end
	local receipt = Receipts.find(data, requestId)
	if receipt ~= nil then
		if receipt.action ~= action then
			reply(env, action, requestId, false, "duplicate", nil, true)
			return
		end
		local confirmed, resolved = resolvePending(env, session)
		reply(env, action, requestId, true, nil, receipt.result, confirmed, true)
		followUp(env, resolved)
		return
	end

	-- 3. Écriture précédente incertaine : la résoudre avant toute nouvelle décision
	local clear, resolved = resolvePending(env, session)
	followUp(env, resolved)
	if not clear then
		reply(env, action, requestId, false, "saving", nil, false)
		return
	end

	-- 4. Maintenance : la décision est refusée sans rien toucher (aucun drop n'est jamais supprimé)
	if env.isDisabled ~= nil and env.isDisabled(action) then
		reply(env, action, requestId, false, "maintenance", nil, true)
		return
	end

	-- 5. Validation + application, sans yield
	data = env.getData()
	if data == nil then
		return
	end
	local reason, result = apply(data, session)
	if reason ~= nil or result == nil then
		reply(env, action, requestId, false, reason or "invalid", nil, true)
		return
	end
	local recorded = Receipts.record(data, requestId, action, result)

	-- 6. Écriture prioritaire, puis réponse
	local clock = env.clock or os.clock
	local started = clock()
	local confirmed = env.save(requestId)
	local ms = math.round((clock() - started) * 1000)
	if confirmed then
		log(env, `{action} {requestId} rév. {recorded.revision} écrite en {ms} ms`)
	else
		session.unconfirmed =
			{ requestId = requestId, action = action, result = result, onConfirmed = onConfirmed }
		log(env, `{action} {requestId} rév. {recorded.revision} NON confirmée après {ms} ms`)
	end
	reply(env, action, requestId, true, nil, result, confirmed)
	if confirmed and onConfirmed ~= nil then
		onConfirmed(data, result)
	end
end

--[[
	Déroule une décision durable. `apply(data, session)` valide et applique d'un bloc (aucun yield)
	et renvoie (raison) en cas de refus, ou (nil, résultat) en cas de succès. Le résultat est stocké
	dans le reçu : uniquement des chaînes, nombres et booléens.
]]
function Receipts.run(
	env: Env,
	session: any,
	action: string,
	requestId: any,
	apply: Apply,
	onConfirmed: OnConfirmed?
)
	if not Receipts.isValidRequestId(requestId) then
		return -- sans clé de reprise, la réponse ne pourrait pas être reliée à la demande
	end
	if session.mutating then
		reply(env, action, requestId, false, "busy", nil, true)
		return
	end

	session.mutating = true
	if env.begin ~= nil then
		env.begin()
	end
	local ok, err = pcall(function()
		process(env, session, action, requestId :: string, apply, onConfirmed)
	end)
	session.mutating = false
	if not ok then
		log(env, `{action} {requestId} ERREUR : {err}`)
		-- même requestId à renvoyer : si la décision a été appliquée, son reçu la rendra telle quelle
		reply(env, action, requestId, false, "error", nil, false)
	end
	if env.finish ~= nil then
		env.finish()
	end
end

return Receipts
