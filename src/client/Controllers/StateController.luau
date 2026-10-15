--[[
	StateController : reçoit le snapshot serveur (State) et les événements (Result),
	et expose send() pour les intentions. C'est la seule porte réseau côté client :
	le HUD du codeur B s'abonne ici (voir docs/CONTRACT.md). Flux de combat : onCombat().
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local StateController = {}

StateController.current = nil :: { [string]: any }?

local stateListeners: { ({ [string]: any }) -> () } = {}
local resultListeners: { ({ [string]: any }) -> () } = {}
local combatListeners: { ({ [string]: any }) -> () } = {}
local intent: RemoteEvent

function StateController.start()
	intent = Net.remote(Net.INTENT)

	Net.remote(Net.STATE).OnClientEvent:Connect(function(snapshot)
		StateController.current = snapshot
		for _, fn in stateListeners do
			task.spawn(fn, snapshot)
		end
	end)

	Net.remote(Net.RESULT).OnClientEvent:Connect(function(event)
		for _, fn in resultListeners do
			task.spawn(fn, event)
		end
	end)

	Net.remote(Net.COMBAT).OnClientEvent:Connect(function(message)
		for _, fn in combatListeners do
			task.spawn(fn, message)
		end
	end)

	intent:FireServer(Net.Actions.Hello)
end

-- fn(message) pour le flux de la rencontre en cours { t = "start" | "spawn" | "pos" | ... }
function StateController.onCombat(fn: ({ [string]: any }) -> ())
	table.insert(combatListeners, fn)
end

-- fn(snapshot) à chaque nouvel état ; appelée tout de suite si un état existe déjà
function StateController.onState(fn: ({ [string]: any }) -> ())
	table.insert(stateListeners, fn)
	local current = StateController.current
	if current ~= nil then
		task.spawn(fn, current)
	end
end

-- fn(event) pour chaque événement ponctuel { kind = ... }
function StateController.onResult(fn: ({ [string]: any }) -> ())
	table.insert(resultListeners, fn)
end

function StateController.send(action: string, payload: { [string]: any }?)
	intent:FireServer(action, payload)
end

return StateController
