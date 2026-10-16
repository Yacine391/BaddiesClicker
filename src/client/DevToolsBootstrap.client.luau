--[[
	DevToolsBootstrap (codeur A, lot P2) : outils de test du client, dans Studio UNIQUEMENT.
	Ne touche ni Bootstrap.client.luau ni le HUD du codeur B.

	- Dev/DevToolsPanel (touche F4) : tickets, puissance, drop, fin de parcours, maîtrise, téléportation.
	Les écrans de jeu (slots, drops, renaissance, crew) sont dans le HUD (Controllers/Slots, Crew).
]]

local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local Controllers = script.Parent:WaitForChild("Controllers")
local StateController = require(Controllers:WaitForChild("StateController"))

require(script.Parent:WaitForChild("Dev"):WaitForChild("DevToolsPanel")).start(StateController)
