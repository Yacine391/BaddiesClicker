--[[
	DoorController : portes individuelles (§08). Le serveur dit quels niveaux sont terminés
	(snapshot.clearedLevels) ; la porte du niveau N s'ouvre UNIQUEMENT pour ce joueur,
	localement (collision coupée côté client). Ce n'est qu'une présentation : l'accès réel
	à une arène est vérifié par le serveur.
]]

local DoorController = {}

local lastKey: string? = nil
local lastLevels: Instance? = nil

local function apply(cleared: { number })
	local levels = workspace:FindFirstChild("Levels")
	if levels == nil then
		return
	end
	local key = table.concat(cleared, ",")
	if key == lastKey and levels == lastLevels then
		return
	end
	lastKey = key
	lastLevels = levels

	local open: { [number]: boolean } = {}
	for _, levelId in cleared do
		open[levelId] = true
	end
	for _, folder in levels:GetChildren() do
		local levelId = tonumber(string.match(folder.Name, "^Level(%d+)$"))
		local door = folder:FindFirstChild("Door")
		if levelId ~= nil and door ~= nil and door:IsA("BasePart") then
			local isOpen = open[levelId] == true
			door.CanCollide = not isOpen
			door.LocalTransparencyModifier = if isOpen then 0.85 else 0
		end
	end
end

function DoorController.start(state)
	local latest: { number } = {}
	state.onState(function(snapshot)
		latest = snapshot.clearedLevels or {}
		apply(latest)
	end)
	-- La carte peut arriver après le premier état (streaming, carte de test construite au lancement)
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "Levels" then
			task.wait(0.5)
			apply(latest)
		end
	end)
end

return DoorController
