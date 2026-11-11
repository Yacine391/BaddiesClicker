--!strict
--[[
	Podium : la vitrine du lobby (§05). Maya présente ses trois looks, puis la nouveauté mise en avant
	(Cherry), un look toutes les 6 s avec un demi-tour au changement. Rendu local : aucun coût serveur.
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local LookRotation = require(Client.Logic.LookRotation)
local FX = require(script.Parent.FX)
local Visuals = require(script.Parent.Visuals)
local VisualsModel = require(Client.Logic.VisualsModel)

local Podium = {}

local PERIOD = 6
local FEATURED = "cherry" -- nouveauté présentée après Maya

-- StreamingEnabled : le podium peut arriver après le démarrage du client (§28) → on l'attend sans bloquer
function Podium.start(scope: any, deps: any)
	task.spawn(Podium._setup, scope, deps)
end

function Podium._setup(scope: any, deps: any)
	local stand = Workspace:WaitForChild("Lobby"):WaitForChild("Podium"):WaitForChild("Stand")
	if not stand:IsA("BasePart") then
		warn("[Podium] Lobby.Podium.Stand n'est pas une pièce")
		return
	end
	local standPart = stand :: BasePart
	local showcase = VisualsModel.showcase(deps.Catalog, FEATURED)

	-- Point d'ancrage au-dessus du socle (racine du rig à 3 studs des pieds), tourné vers le spawn et
	-- l'allée centrale (sud-ouest) : les modèles regardent vers -Z au repos
	local base = CFrame.new(standPart.Position + Vector3.new(0, standPart.Size.X / 2 + 3, 0))
		* CFrame.Angles(0, math.rad(135), 0)
	local current: Model? = nil
	local currentIndex = 0
	local angle = Instance.new("NumberValue")
	angle.Value = 0
	table.insert(scope, angle)

	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(420, 50)
	label.StudsOffsetWorldSpace = Vector3.new(0, 4.5, 0)
	label.MaxDistance = 90
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.TextScaled = true
	text.FontFace = Font.fromName("LuckiestGuy")
	text.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("#1B1530")
	stroke.Thickness = 3
	stroke.Parent = text
	text.Parent = label
	label.Adornee = standPart
	label.Parent = standPart
	table.insert(scope, label)

	local function show(index: number)
		if current then
			current:Destroy()
			current = nil
		end
		currentIndex = index
		local entry = showcase[index]
		local model = if entry then Visuals.clone(entry.id, entry.look) else nil
		if entry == nil or model == nil then
			return
		end
		model.Name = "PodiumShowcase"
		FX.attach(model, entry.id)
		model.Parent = Workspace
		Visuals.animate(model)
		current = model
		text.Text = entry.title
		angle.Value = 180
		TweenService:Create(angle, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Value = 0 }):Play()
	end

	table.insert(
		scope,
		RunService.RenderStepped:Connect(function()
			local index = LookRotation.index(os.clock(), PERIOD, math.max(1, #showcase))
			if index ~= currentIndex then
				show(index)
			end
			if current then
				current:PivotTo(base * CFrame.Angles(0, math.rad(angle.Value), 0))
			end
		end)
	)
	table.insert(scope, function()
		if current then
			current:Destroy()
		end
	end)
end

return Podium
