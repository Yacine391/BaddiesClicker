--[[
	CombatBootstrap (codeur A, lot P1) : branche le côté client du combat SANS toucher
	Bootstrap.client.luau ni le HUD du codeur B (PR #1 ouverte).

	- DoorController : portes individuelles, partout (présentation seulement, l'accès est vérifié par le serveur).
	- Dans Studio uniquement : rendu de test des ennemis (Dev/DevCombatView) et panneau de combat de test
	  (Dev/DevCombatPanel : bouton ATTAQUER, touche F, PV, « rejouer »).

	Quand le HUD du codeur B gère le combat (flux StateController.onCombat + snapshot.combat),
	il démarre DoorController depuis son App et ce script est supprimé.
]]

local RunService = game:GetService("RunService")

local Controllers = script.Parent:WaitForChild("Controllers")
local StateController = require(Controllers:WaitForChild("StateController"))

require(Controllers:WaitForChild("DoorController")).start(StateController)

if RunService:IsStudio() then
	local Dev = script.Parent:WaitForChild("Dev")
	require(Dev:WaitForChild("DevCombatView")).start(StateController)
	require(Dev:WaitForChild("DevCombatPanel")).start(StateController)
end
