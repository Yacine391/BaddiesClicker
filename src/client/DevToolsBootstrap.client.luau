--[[
	DevToolsBootstrap (codeur A, lot P2) : outils de test du client, dans Studio UNIQUEMENT.
	Ne touche ni Bootstrap.client.luau ni le HUD du codeur B.

	- Dev/DevSlotsPanel : slots, relances, drops en attente, renaissance (touche F4).
	À supprimer quand les écrans Slots / Drops / Rebirth du codeur B sont branchés.
]]

local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local Controllers = script.Parent:WaitForChild("Controllers")
local StateController = require(Controllers:WaitForChild("StateController"))

require(script.Parent:WaitForChild("Dev"):WaitForChild("DevSlotsPanel")).start(StateController)
