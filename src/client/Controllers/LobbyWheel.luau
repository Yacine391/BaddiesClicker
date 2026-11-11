--!strict
--[[
	LobbyWheel : la roue du jour posée près du spawn (Workspace.Lobby.Wheel, construite par LobbyBuilder).
	- Le rotor tourne lentement, côté client (décor : aucun coût serveur, aucun effet sur les gains).
	- Marcher sur la dalle ouvre la fenêtre BONUS à l'onglet ROUE ; il faut en sortir pour la rouvrir ainsi
	  (fermer la fenêtre ne la fait pas réapparaître). Rien ne s'ouvre en combat ni par-dessus une fenêtre.
	- Une étiquette « TOUR GRATUIT » flotte au-dessus tant que le tour du jour n'est pas pris.
	Le tour lui-même reste une décision serveur (Controllers/Bonus) : la roue 3D n'est qu'une invitation.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local Bonus = require(script.Parent.Bonus)

local LobbyWheel = {}

local DEGREES_PER_SECOND = 24
local MAX_DISTANCE = 140 -- au-delà, le rotor ne tourne plus (personne ne le voit)
local CHECK_SECONDS = 0.2

-- StreamingEnabled : la roue peut arriver après le démarrage du client → on l'attend sans bloquer
function LobbyWheel.start(scope: any, deps: any)
	task.spawn(LobbyWheel._setup, scope, deps)
end

function LobbyWheel._setup(scope: any, deps: any)
	local wheel = Workspace:WaitForChild("Lobby"):WaitForChild("Wheel", 60)
	if wheel == nil then
		return -- place sans la roue (ancien Lobby.rbxm) : le menu BONUS reste disponible
	end
	local rotor = wheel:WaitForChild("Rotor", 10)
	local pad = wheel:WaitForChild("Pad", 10)
	if rotor == nil or not rotor:IsA("Model") or pad == nil or not pad:IsA("BasePart") then
		warn("[LobbyWheel] Lobby.Wheel incomplet (Rotor, Pad)")
		return
	end
	local rotorModel = rotor :: Model
	local padPart = pad :: BasePart
	local base = rotorModel:GetPivot()
	local radius = math.max(padPart.Size.Y, padPart.Size.Z) / 2

	-- Étiquette au-dessus de la roue
	local tag = Instance.new("BillboardGui")
	tag.Name = "FreeSpin"
	tag.Size = UDim2.fromOffset(240, 44)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 8.6, 0)
	tag.MaxDistance = 110
	tag.LightInfluence = 0
	tag.Enabled = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.TextScaled = true
	label.FontFace = Theme.Fonts.Heavy
	label.TextColor3 = Theme.Colors.Accent
	label.Text = "TOUR GRATUIT !"
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Ink
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = tag
	tag.Adornee = rotorModel.PrimaryPart
	tag.Parent = wheel
	table.insert(scope, tag)

	local function refreshTag()
		local snapshot = deps.peek(deps.Store.snapshot)
		local rewards = snapshot and snapshot.rewards
		tag.Enabled = rewards ~= nil and rewards.wheel ~= nil and rewards.wheel.free == true
	end
	refreshTag()
	scope:Observer(deps.Store.snapshot):onChange(refreshTag)

	local angle = 0
	local sinceCheck = 0
	local wasOnPad = true -- vrai au départ : apparaître sur la dalle n'ouvre rien
	table.insert(
		scope,
		RunService.Heartbeat:Connect(function(dt)
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root == nil or not root:IsA("BasePart") then
				return
			end
			local position = (root :: BasePart).Position
			if (position - base.Position).Magnitude <= MAX_DISTANCE then
				angle = (angle + DEGREES_PER_SECOND * dt) % 360
				rotorModel:PivotTo(base * CFrame.Angles(math.rad(angle), 0, 0))
			end

			sinceCheck += dt
			if sinceCheck < CHECK_SECONDS then
				return
			end
			sinceCheck = 0
			local offset = position - padPart.Position
			local onPad = Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and math.abs(offset.Y) < 8
			if onPad and not wasOnPad then
				local snapshot = deps.peek(deps.Store.snapshot)
				local free = snapshot ~= nil
					and snapshot.mode ~= "combat"
					and deps.peek(deps.UiState.openWindow) == nil
				if free then
					if Bonus.tab ~= nil then
						Bonus.tab:set("wheel")
					end
					deps.UiState.openWindow:set("Bonus")
				end
			end
			wasOnPad = onPad
		end)
	)
end

return LobbyWheel
