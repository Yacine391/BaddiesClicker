--[[
	MutationService : file des décisions DURABLES (relance, drop accepté ou refusé, renaissance). §25 à §27.

	Pour chaque intention { requestId, ... } :
	1. Une seule décision à la fois par joueur : une autre arrivée pendant l'écriture reçoit "busy".
	2. requestId déjà traité (reçu dans le profil) → le MÊME résultat est renvoyé, sans nouvel effet ni tirage.
	3. Une décision précédente dont l'écriture est incertaine est d'abord re-sauvegardée ; si cela échoue
	   encore, la nouvelle est refusée avec "saving" (on bloque l'opération suivante, §27).
	4. Validation + application SANS yield (le tirage a lieu une seule fois, ici), reçu durable,
	   puis attente de l'écriture DataStore (Profiles.saveAndWait).
	5. Réponse Result { kind = "mutation", action, requestId, ok, reason?, result?, confirmed, replay? }
	   APRÈS l'écriture (ou son délai), puis l'état et les annonces (découverte, renaissance).
	   Pendant l'écriture, StateService retient les snapshots : le joueur ne voit le résultat qu'après.

	confirmed = false : la décision est appliquée mais l'écriture n'est pas confirmée. Le client renvoie
	le MÊME requestId plus tard pour obtenir la confirmation, jamais un nouveau.
]]

local Receipts = require(script.Parent.Parent.Rules.Receipts)

export type Apply = (data: any, session: any) -> (string?, { [string]: any }?)
export type OnConfirmed = (player: Player, data: any, result: { [string]: any }) -> ()

type Pending = { requestId: string, result: { [string]: any }, onConfirmed: OnConfirmed? }

local MutationService = {}

local ctx
local deps

function MutationService.init(context, dependencies)
	ctx = context
	deps = dependencies
end

local function reply(
	player: Player,
	action: string,
	requestId: string,
	ok: boolean,
	reason: string?,
	result: { [string]: any }?,
	confirmed: boolean,
	replay: boolean?
)
	deps.State.notify(player, {
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

local function saveAndWait(player: Player, requestId: string): boolean
	return deps.Profiles.saveAndWait(player, function(saved)
		return Receipts.isSaved(saved, requestId)
	end, ctx.Balance.mutations.saveTimeoutSeconds)
end

-- Confirme la décision en attente ; renvoie (plus rien en attente ?, décision qui vient d'être confirmée)
local function resolvePending(player: Player, session): (boolean, Pending?)
	local pending: Pending? = session.unconfirmed
	if pending == nil then
		return true, nil
	end
	if not saveAndWait(player, pending.requestId) then
		return false, nil
	end
	session.unconfirmed = nil
	return true, pending
end

local function followUp(player: Player, pending: Pending?)
	local data = deps.Profiles.get(player)
	if pending ~= nil and pending.onConfirmed ~= nil and data ~= nil then
		pending.onConfirmed(player, data, pending.result)
	end
end

local function process(
	player: Player,
	session,
	action: string,
	requestId: string,
	apply: Apply,
	onConfirmed: OnConfirmed?
)
	-- 2. Renvoi d'une décision déjà traitée (le reçu est toujours celui de la dernière décision)
	local data = deps.Profiles.get(player)
	local receipt = if data ~= nil then Receipts.find(data, requestId) else nil
	if receipt ~= nil then
		if receipt.action ~= action then
			reply(player, action, requestId, false, "duplicate", nil, true)
			return
		end
		local confirmed, resolved = resolvePending(player, session)
		reply(player, action, requestId, true, nil, receipt.result, confirmed, true)
		followUp(player, resolved)
		return
	end

	-- 3. Écriture précédente incertaine : la résoudre avant toute nouvelle décision
	local clear, resolved = resolvePending(player, session)
	followUp(player, resolved)
	if not clear then
		reply(player, action, requestId, false, "saving", nil, false)
		return
	end

	-- 4. Validation + application, sans yield
	data = deps.Profiles.get(player)
	if data == nil then
		return
	end
	local reason, result = apply(data, session)
	if reason ~= nil or result == nil then
		reply(player, action, requestId, false, reason or "invalid", nil, true)
		return
	end
	Receipts.record(data, requestId, action, result)

	-- 5. Écriture prioritaire, puis réponse
	local confirmed = saveAndWait(player, requestId)
	if not confirmed then
		session.unconfirmed = { requestId = requestId, result = result, onConfirmed = onConfirmed } :: Pending
		warn(`[MutationService] écriture non confirmée pour {player.Name} ({action} {requestId})`)
	end
	reply(player, action, requestId, true, nil, result, confirmed)
	if confirmed and onConfirmed ~= nil then
		onConfirmed(player, data, result)
	end
end

--[[
	Exécute une décision durable. `apply(data, session)` valide et applique d'un bloc (aucun yield)
	et renvoie (raison) en cas de refus, ou (nil, résultat) en cas de succès. Le résultat est stocké
	dans le reçu : uniquement des chaînes, nombres et booléens. `onConfirmed` part après l'écriture.
]]
function MutationService.run(
	player: Player,
	action: string,
	requestId: any,
	apply: Apply,
	onConfirmed: OnConfirmed?
)
	local session = deps.Sessions.get(player)
	if session == nil or deps.Profiles.get(player) == nil then
		return
	end
	if not Receipts.isValidRequestId(requestId) then
		return -- sans clé de reprise, la réponse ne pourrait pas être reliée à la demande
	end
	if session.mutating then
		reply(player, action, requestId, false, "busy", nil, true)
		return
	end

	session.mutating = true
	deps.State.pushNow(player) -- « sauvegarde en cours » ; les snapshots suivants attendent la fin
	local ok, err = pcall(process, player, session, action, requestId :: string, apply, onConfirmed)
	session.mutating = false
	if not ok then
		warn(`[MutationService] erreur {action} pour {player.Name} : {err}`)
		-- même requestId à renvoyer : si la décision a été appliquée, son reçu la rendra telle quelle
		reply(player, action, requestId, false, "error", nil, false)
	end

	local data = deps.Profiles.get(player)
	if data ~= nil then
		deps.State.refreshAttributes(player, data)
		deps.State.pushNow(player)
	end
end

return MutationService
