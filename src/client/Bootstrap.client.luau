--[[
	Bootstrap client : branche l'état venant du serveur, puis l'interface.
	Le client affiche et envoie des intentions ; il ne décide jamais d'un gain.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Flags = require(Shared:WaitForChild("Flags"))

local Controllers = script.Parent:WaitForChild("Controllers")
local StateController = require(Controllers:WaitForChild("StateController"))
local CelebrationController = require(Controllers:WaitForChild("CelebrationController"))

CelebrationController.start(StateController)
StateController.start()

if Flags.DEV_HUD then
	local DevHUD = require(script.Parent:WaitForChild("Dev"):WaitForChild("DevHUD"))
	DevHUD.start(StateController, CelebrationController)
end
