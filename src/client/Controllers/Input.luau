--!strict
--[[
	Input : le bouton principal côté client. Envoie seulement des intentions, jamais de montant :
	« Train » au repos, « Attack » en combat.
	Rien n'est envoyé sans snapshot ni quand une fenêtre est ouverte (§21).
	Maintien accessible : Balance.training.holdActionsPerSecond actions/s (§07). Il s'arrête au
	relâchement réel de l'entrée qui l'a commencé (souris ou doigt, où qu'il soit relâché),
	à l'ouverture d'une fenêtre ou si le réglage est coupé — jamais sur une simple perte de survol.
]]

local UserInputService = game:GetService("UserInputService")

local HoldPolicy = require(script.Parent.Parent.Logic.HoldPolicy)
local PrimaryAction = require(script.Parent.Parent.Logic.PrimaryAction)

local Input = {}

local deps: any
local holding = false
local holdInput: InputObject? = nil
local holdToken = 0

local function sameInput(a: InputObject, b: InputObject): boolean
	if a == b then
		return true
	end
	-- La souris ne garde pas toujours le même InputObject entre l'appui et le relâchement
	return a.UserInputType == Enum.UserInputType.MouseButton1
		and b.UserInputType == Enum.UserInputType.MouseButton1
end

function Input.init(dependencies: any, scope: any)
	deps = dependencies
	table.insert(
		scope,
		UserInputService.InputEnded:Connect(function(input)
			if holdInput ~= nil and sameInput(input, holdInput) then
				Input.endHold()
			end
		end)
	)
end

-- Bouton principal : « Train » au repos, « Attack » en combat (PrimaryAction, §07)
function Input.train()
	local peek = deps.peek
	if peek(deps.UiState.openWindow) ~= nil then
		return
	end
	local intent = PrimaryAction.intent(peek(deps.Store.snapshot))
	if intent == nil then
		return
	end
	-- Net.Actions.Attack n'existe qu'à partir du P1 du codeur A : le nom du contrat sert de repli
	deps.StateController.send(deps.Actions[intent.action] or intent.action, intent.payload)
	if intent.action == "Train" then
		deps.UiState.trainPulse:set(peek(deps.UiState.trainPulse) + 1)
	end
end

local function keepHolding(): boolean
	return HoldPolicy.keepHolding({
		holdEnabled = deps.peek(deps.UiState.settings.holdToTrain),
		pressed = holding,
		windowOpen = deps.peek(deps.UiState.openWindow) ~= nil,
	})
end

function Input.beginHold(input: InputObject?)
	if holding or not deps.peek(deps.UiState.settings.holdToTrain) then
		return
	end
	holding = true
	holdInput = input
	holdToken += 1
	local token = holdToken
	local interval = 1 / deps.Balance.training.holdActionsPerSecond
	task.spawn(function()
		while token == holdToken and keepHolding() do
			Input.train()
			task.wait(interval)
		end
		if token == holdToken then
			Input.endHold()
		end
	end)
end

function Input.endHold()
	holding = false
	holdInput = nil
end

function Input.isHolding(): boolean
	return holding
end

return Input
