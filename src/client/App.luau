--!strict
--[[
	App : démarre le vrai client (HUD V3, fenêtres, suiveurs) quand Flags.DEV_HUD est faux.
	Un seul scope Fusion pour toute l'application ; chaque contrôleur reçoit `deps`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Fusion = require(script.Parent.Packages.Fusion)

local Store = require(script.Parent.Store)
local UiState = require(script.Parent.UiState)
local Controllers = script.Parent.Controllers
local Input = require(Controllers.Input)

local App = {}

-- Contrôleurs visuels, démarrés dans cet ordre (chacun expose start(scope, deps))
local VISUAL_CONTROLLERS: { string } = { "HUD" }

function App.start(stateController: any)
	local scope = Fusion.scoped(Fusion)
	local deps = {
		peek = Fusion.peek,
		Fusion = Fusion,
		StateController = stateController,
		Actions = require(Shared:WaitForChild("Net")).Actions,
		Balance = require(Shared:WaitForChild("Balance")),
		Catalog = require(Shared:WaitForChild("Catalog")),
		Format = require(Shared:WaitForChild("Format")),
		Store = Store,
		UiState = UiState,
		Input = Input,
	}

	-- L'état doit exister avant que StateController ne pousse le premier snapshot
	UiState.init(scope)
	Store.init(scope, stateController)
	Input.init(deps)

	for _, name in VISUAL_CONTROLLERS do
		require(Controllers:WaitForChild(name)).start(scope, deps)
	end
	App.deps = deps
	return scope
end

App.deps = nil :: any

return App
