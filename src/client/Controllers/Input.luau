--!strict
--[[
	Input : l'entraînement côté client. Envoie seulement l'intention « Train » (aucun montant).
	Rien n'est envoyé sans snapshot ni quand une fenêtre est ouverte (§21).
	Maintien accessible : Balance.training.holdActionsPerSecond actions/s (§07).
]]

local Input = {}

local deps: any
local holding = false
local holdToken = 0

function Input.init(dependencies: any)
	deps = dependencies
end

function Input.train()
	local peek = deps.peek
	if peek(deps.Store.snapshot) == nil or peek(deps.UiState.openWindow) ~= nil then
		return
	end
	deps.StateController.send(deps.Actions.Train)
	deps.UiState.trainPulse:set(peek(deps.UiState.trainPulse) + 1)
end

function Input.beginHold()
	if holding or not deps.peek(deps.UiState.settings.holdToTrain) then
		return
	end
	holding = true
	holdToken += 1
	local token = holdToken
	local interval = 1 / deps.Balance.training.holdActionsPerSecond
	task.spawn(function()
		while holding and token == holdToken do
			Input.train()
			task.wait(interval)
		end
	end)
end

function Input.endHold()
	holding = false
end

function Input.isHolding(): boolean
	return holding
end

return Input
