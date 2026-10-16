--[[
	Decisions : envoi des décisions durables (Roll, AcceptDrop, RefuseDrop, Rebirth, OpenChest),
	contrat « Décisions durables » de docs/CONTRACT.md.

	- Un requestId par décision (GUID), RÉUTILISÉ pour la renvoyer : jamais deux effets pour un clic.
	- Réponse `saving`, `error` ou écriture non confirmée : nouvel essai automatique avec le même
	  requestId (3 fois, toutes les 2 s), puis abandon avec un message.
	- Une seule décision en vol à la fois : les clics suivants sont ignorés tant qu'elle n'a pas répondu.
	- `onResult(fn)` : chaque réponse finale (succès ou refus définitif), pour les toasts et les écrans.
]]

local HttpService = game:GetService("HttpService")

local Decisions = {}

local RETRY_SECONDS = 2
local MAX_RETRIES = 3
local TIMEOUT_SECONDS = 15

type Pending = { action: string, payload: { [string]: any }, tries: number, sentAt: number }

local deps: any
local pending: Pending? = nil
local listeners: { (event: { [string]: any }) -> () } = {}

local function emit(event: { [string]: any })
	for _, fn in listeners do
		task.spawn(fn, event)
	end
end

local function transmit(current: Pending)
	current.sentAt = os.clock()
	deps.StateController.send(deps.Actions[current.action] or current.action, current.payload)
end

function Decisions.busy(): boolean
	return pending ~= nil
end

-- Envoie une décision ; false si une autre est encore en vol
function Decisions.send(action: string, payload: { [string]: any }): boolean
	if pending ~= nil then
		return false
	end
	local body = table.clone(payload)
	body.requestId = HttpService:GenerateGUID(false)
	local current: Pending = { action = action, payload = body, tries = 0, sentAt = 0 }
	pending = current
	transmit(current)
	return true
end

function Decisions.onResult(fn: (event: { [string]: any }) -> ())
	table.insert(listeners, fn)
end

function Decisions.start(_scope: any, dependencies: any)
	deps = dependencies
	deps.StateController.onResult(function(event)
		local current = pending
		if event.kind ~= "mutation" or current == nil or event.requestId ~= current.payload.requestId then
			return
		end
		local retryable = (not event.ok and (event.reason == "saving" or event.reason == "error"))
			or (event.ok and event.confirmed == false)
		if retryable and current.tries < MAX_RETRIES then
			current.tries += 1
			task.delay(RETRY_SECONDS, function()
				if pending == current then
					transmit(current)
				end
			end)
			return
		end
		pending = nil
		emit(event)
	end)
	-- Sans réponse (déconnexion du remote, serveur figé) : on libère et on prévient
	task.spawn(function()
		while true do
			task.wait(1)
			local current = pending
			if current ~= nil and os.clock() - current.sentAt > TIMEOUT_SECONDS then
				pending = nil
				emit({ kind = "mutation", action = current.action, ok = false, reason = "error" })
			end
		end
	end)
end

return Decisions
