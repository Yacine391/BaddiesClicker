--[[
	CelebrationController : effets RGB (arc-en-ciel) quand le joueur franchit un cap.

	Purement visuel et local : il ne décide de rien. Il réagit :
	- aux événements Result du serveur (nouveau compagnon, ticket, et plus tard
	  niveau terminé, maîtrise, renaissance, nouvelle baddie) ;
	- aux paliers de puissance lus dans le snapshot (10, 25, 50, 100, 250…).

	Effets réduits (§21) : si le profil a settings.reducedEffects, seule la bannière reste.
	Le HUD du codeur B peut réutiliser rainbowGradient() et play().
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local Format = require(Shared:WaitForChild("Format"))
local Wardrobe = require(Shared:WaitForChild("Wardrobe"))

export type Celebration = { title: string, subtitle: string?, big: boolean }

local CelebrationController = {}

CelebrationController.RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 72)),
	ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 140, 0)),
	ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(255, 230, 0)),
	ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 230, 100)),
	ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 170, 255)),
	ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(150, 60, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 72)),
})

local NUIT = Color3.fromHex("#242036")
local SPARKLES = "rbxasset://textures/particles/sparkles_main.dds"

local player = Players.LocalPlayer
local reduced = false
local gui: ScreenGui
local gradients: { [UIGradient]: number } = {} -- dégradé animé -> vitesse (degrés/s)
local rainbowParts: { [BasePart]: boolean } = {}
local queue: { Celebration } = {}
local playing = false

-- Paliers de puissance : 10, 25, 50, 100, 250, 500, 1 K… (les puissances de 10 sont « grandes »)
local MILESTONES: { { value: number, big: boolean } } = {}
for exponent = 1, 15 do
	for _, mantissa in { 1, 2.5, 5 } do
		table.insert(MILESTONES, { value = mantissa * 10 ^ exponent, big = mantissa == 1 })
	end
end

-- Ajoute un dégradé arc-en-ciel animé à un GuiObject ou à un UIStroke
function CelebrationController.rainbowGradient(parent: Instance, speed: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = CelebrationController.RAINBOW
	gradient.Parent = parent
	gradients[gradient] = speed or 180
	return gradient
end

local function rootPart(): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function burst(count: number)
	local root = rootPart()
	if root == nil then
		return
	end
	local attachment = Instance.new("Attachment")
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLES
	emitter.Color = CelebrationController.RAINBOW
	emitter.LightEmission = 1
	emitter.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Speed = NumberRange.new(10, 22)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Rate = 0
	emitter.Parent = attachment
	attachment.Parent = root
	emitter:Emit(count)
	Debris:AddItem(attachment, 2)
end

local function shockwave()
	local root = rootPart()
	if root == nil then
		return
	end
	local ring = Instance.new("Part")
	ring.Name = "BC_Shockwave"
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Transparency = 0.25
	ring.Size = Vector3.new(0.2, 4, 4)
	ring.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	rainbowParts[ring] = true
	TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.2, 34, 34),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 1)
end

local function flash()
	local frame = Instance.new("Frame")
	frame.Name = "Flash"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.BackgroundTransparency = 0.6
	frame.BorderSizePixel = 0
	frame.ZIndex = 1
	CelebrationController.rainbowGradient(frame, 360)
	frame.Parent = gui
	TweenService:Create(frame, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(frame, 0.8)
end

local function textLabel(text: string, size: number, font: Enum.Font, rainbow: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, size + 10)
	label.Font = font
	label.TextSize = size
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = text
	label.ZIndex = 5
	local stroke = Instance.new("UIStroke")
	stroke.Color = NUIT
	stroke.Thickness = 3
	stroke.Parent = label
	if rainbow then
		CelebrationController.rainbowGradient(label, 240)
	end
	return label
end

-- Affiche une bannière ; renvoie la durée totale
local function banner(item: Celebration): number
	local hold = if item.big then 2.2 else 1.2

	local frame = Instance.new("Frame")
	frame.Name = "Banner"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.3)
	frame.Size = UDim2.fromOffset(760, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.ZIndex = 5
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = frame

	local labels = { textLabel(item.title, if item.big then 64 else 40, Enum.Font.GothamBlack, true) }
	if item.subtitle then
		local sub = textLabel(item.subtitle, if item.big then 28 else 22, Enum.Font.GothamBold, false)
		sub.LayoutOrder = 2
		table.insert(labels, sub)
	end
	for _, label in labels do
		label.Parent = frame
	end
	frame.Parent = gui

	TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	task.delay(hold, function()
		local fade = TweenInfo.new(0.35)
		for _, label in labels do
			TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
			local stroke = label:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
			end
		end
		Debris:AddItem(frame, 0.4)
	end)

	return hold + 0.4
end

local function runQueue()
	playing = true
	while #queue > 0 do
		local item = table.remove(queue, 1) :: Celebration
		if not reduced then
			burst(if item.big then 70 else 25)
			if item.big then
				shockwave()
				flash()
			end
		end
		task.wait(banner(item) * 0.75)
	end
	playing = false
end

-- Joue une célébration (mise en file si une autre est en cours)
function CelebrationController.play(item: Celebration)
	table.insert(queue, item)
	if not playing then
		task.spawn(runQueue)
	end
end

local function onResult(event: { [string]: any })
	local kind = event.kind
	if kind == "crewJoined" then
		local def = Catalog.crew[event.crewId]
		local isCopy = event.isNew == false -- doublon d'un coffre : une copie de plus
		CelebrationController.play({
			title = if isCopy then "+1 COPIE" else "NOUVEAU CREW !",
			subtitle = if def then `{def.name} · {def.role}` else event.crewId,
			big = not isCopy,
		})
	elseif kind == "ticket" then
		local what = if event.ticket == "baddie" then "BADDIE" else "COMPAGNON"
		CelebrationController.play({ title = `+{event.amount} TICKET {what}`, big = false })
	elseif kind == "levelCleared" then
		CelebrationController.play({
			title = `NIVEAU {event.level} TERMINÉ !`,
			subtitle = "La porte s'ouvre",
			big = true,
		})
		if event.drop ~= nil then
			local def = Catalog.baddies[event.drop]
			local rarity = if def then Catalog.rarities[def.rarity] else nil
			CelebrationController.play({
				title = `DROP : {if def then string.upper(def.name) else event.drop} !`,
				subtitle = `{if rarity then rarity.label else ""} · dans tes drops en attente`,
				big = true,
			})
		end
	elseif kind == "masteryUp" then
		local def = Catalog.baddies[event.baddieId]
		CelebrationController.play({
			title = `MAÎTRISE {event.level}`,
			subtitle = if def then def.name else nil,
			big = true,
		})
	elseif kind == "crewLevelUp" then
		local def = Catalog.crew[event.crewId]
		CelebrationController.play({
			title = `{if def then string.upper(def.name) else "CREW"} NIVEAU {event.level}`,
			big = true,
		})
	elseif kind == "rebirth" then
		CelebrationController.play({ title = `RENAISSANCE {event.count} !`, big = true })
	elseif kind == "achievement" then
		local def = Wardrobe.achievements[event.id]
		local rewards = {}
		for _, id in event.items or {} do
			local item = Wardrobe.items[id]
			table.insert(rewards, if item then item.name else id)
		end
		for _, id in event.titles or {} do
			local title = Wardrobe.titles[id]
			table.insert(rewards, `titre « {if title then title.name else id} »`)
		end
		CelebrationController.play({
			title = `SUCCÈS : {if def then string.upper(def.name) else event.id}`,
			subtitle = if #rewards > 0 then `Débloqué : {table.concat(rewards, " · ")}` else nil,
			big = true,
		})
	elseif kind == "discovery" then
		local def = Catalog.baddies[event.baddieId]
		CelebrationController.play({
			title = "NOUVELLE BADDIE !",
			subtitle = if def then def.name else nil,
			big = true,
		})
	end
end

local lastPower: number? = nil

local function onState(snapshot: { [string]: any })
	reduced = snapshot.settings ~= nil and snapshot.settings.reducedEffects == true

	local power = snapshot.power
	local previous = lastPower
	lastPower = power
	if previous == nil or power <= previous then
		return -- premier état reçu ou puissance en baisse (rebirth) : rien à fêter
	end
	local crossed = nil
	for _, milestone in MILESTONES do
		if previous < milestone.value and power >= milestone.value then
			crossed = milestone
		end
	end
	if crossed then
		CelebrationController.play({
			title = `PALIER {Format.number(crossed.value)}`,
			subtitle = "de puissance",
			big = crossed.big,
		})
	end
end

function CelebrationController.start(state)
	gui = Instance.new("ScreenGui")
	gui.Name = "Celebrations"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	RunService.RenderStepped:Connect(function(dt)
		for gradient, speed in gradients do
			if gradient.Parent == nil then
				gradients[gradient] = nil
			else
				gradient.Rotation = (gradient.Rotation + speed * dt) % 360
			end
		end
		local hue = (os.clock() * 0.8) % 1
		for part in rainbowParts do
			if part.Parent == nil then
				rainbowParts[part] = nil
			else
				part.Color = Color3.fromHSV(hue, 0.9, 1)
			end
		end
	end)

	state.onState(onState)
	state.onResult(onResult)
end

return CelebrationController
