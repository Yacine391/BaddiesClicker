--!strict
--[[
	Wearables : cosmétiques de la garde-robe portés par l'avatar de chaque joueur (§19).
	Le serveur publie l'attribut BC_Style (« neck=chain_gold,head=headset_player… », cosmétiques débloqués
	et portés) ; ce contrôleur les dessine localement sur le personnage : pièces simples soudées, sans
	collision. Apparence uniquement : aucun effet sur les gains, et un échec d'affichage n'arrête rien.

	  cou      chaîne argentée / dorée           tête     casque de joueur
	  poignet  montre                            visage   lunettes
	  aura     Spark / Neon (Controllers/FX)     trail    traînée d'étoiles
	  cadre    liseré autour du titre (Controllers/Titles)        pose : pas encore d'animation
	« Effets réduits » atténue les auras (FX) et coupe la traînée.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent
local StyleModel = require(Client.Logic.StyleModel)
local FX = require(script.Parent.FX)
local Wardrobe = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Wardrobe"))

local Wearables = {}

local FOLDER = "BC_Wearables"
local SILVER = Color3.fromHex("#C9CCD3")
local GOLD = Color3.fromHex("#D7A746")
local DARK = Color3.fromHex("#1B1B1F")

local reducedEffects = false

-- Pièce décorative soudée à `body`, placée à `offset` dans son repère
local function piece(
	folder: Instance,
	body: BasePart,
	name: string,
	shape: Enum.PartType,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = body.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	return p
end

local function find(character: Model, ...: string): BasePart?
	for _, name in { ... } do
		local part = character:FindFirstChild(name)
		if part ~= nil and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- Chaîne : perles en U sur le haut du torse (R15 : UpperTorso ; R6 : Torso)
local function chain(folder: Instance, character: Model, color: Color3)
	local torso = find(character, "UpperTorso", "Torso")
	if torso == nil then
		return
	end
	local s = torso.Size
	local top = s.Y / 2
	local front = -(s.Z / 2 + 0.04)
	for i = -4, 4 do
		local t = i / 4
		local x = t * s.X * 0.22
		local y = top - 0.12 - (1 - t * t) * s.Y * 0.28
		piece(
			folder,
			torso,
			"Chain",
			Enum.PartType.Ball,
			Vector3.new(0.14, 0.14, 0.14),
			CFrame.new(x, y, front),
			color,
			Enum.Material.Metal
		)
	end
end

local function headset(folder: Instance, character: Model)
	local head = find(character, "Head")
	if head == nil then
		return
	end
	local s = head.Size
	local side = math.min(s.X, 2) / 2 + 0.08
	for _, sign in { -1, 1 } do
		piece(
			folder,
			head,
			"HeadsetCup",
			Enum.PartType.Cylinder,
			Vector3.new(0.22, 0.62, 0.62),
			CFrame.new(sign * side, 0, 0),
			DARK
		)
		piece(
			folder,
			head,
			"HeadsetGlow",
			Enum.PartType.Cylinder,
			Vector3.new(0.05, 0.36, 0.36),
			CFrame.new(sign * (side + 0.12), 0, 0),
			Color3.fromHex("#3EE6C8"),
			Enum.Material.Neon
		)
		piece(
			folder,
			head,
			"HeadsetArm",
			Enum.PartType.Block,
			Vector3.new(0.12, s.Y * 0.55, 0.16),
			CFrame.new(sign * side, s.Y * 0.3, 0),
			DARK
		)
	end
	piece(
		folder,
		head,
		"HeadsetBand",
		Enum.PartType.Block,
		Vector3.new(side * 2 + 0.12, 0.12, 0.2),
		CFrame.new(0, s.Y * 0.58, 0),
		DARK
	)
end

local function glasses(folder: Instance, character: Model)
	local head = find(character, "Head")
	if head == nil then
		return
	end
	local s = head.Size
	local front = -(math.min(s.Z, 1.4) / 2 + 0.03)
	for _, sign in { -1, 1 } do
		piece(
			folder,
			head,
			"Lens",
			Enum.PartType.Block,
			Vector3.new(0.4, 0.22, 0.05),
			CFrame.new(sign * 0.26, s.Y * 0.1, front),
			DARK
		).Reflectance =
			0.3
	end
	piece(
		folder,
		head,
		"Bridge",
		Enum.PartType.Block,
		Vector3.new(0.14, 0.05, 0.05),
		CFrame.new(0, s.Y * 0.12, front),
		DARK
	)
end

local function watch(folder: Instance, character: Model)
	local arm = find(character, "LeftLowerArm", "Left Arm")
	if arm == nil then
		return
	end
	local s = arm.Size
	local y = -s.Y / 2 + 0.22
	piece(
		folder,
		arm,
		"WatchBand",
		Enum.PartType.Block,
		Vector3.new(s.X + 0.06, 0.16, s.Z + 0.06),
		CFrame.new(0, y, 0),
		DARK
	)
	piece(
		folder,
		arm,
		"WatchFace",
		Enum.PartType.Cylinder,
		Vector3.new(0.06, 0.3, 0.3),
		CFrame.new(-(s.X / 2 + 0.05), y, 0),
		GOLD,
		Enum.Material.Metal
	)
end

local function aura(folder: Instance, character: Model, id: string)
	local root = find(character, "HumanoidRootPart")
	if root == nil then
		return
	end
	-- FX.attach cherche un « AuraAttachment » : on en pose un dans le dossier des cosmétiques
	local holder =
		piece(folder, root, "AuraHolder", Enum.PartType.Block, Vector3.new(0.2, 0.2, 0.2), CFrame.new(), DARK)
	holder.Transparency = 1
	local attachment = Instance.new("Attachment")
	attachment.Name = "AuraAttachment"
	attachment.Parent = holder
	FX.attach(holder, id)
end

local function trail(folder: Instance, character: Model)
	local root = find(character, "HumanoidRootPart")
	if root == nil or reducedEffects then
		return
	end
	local holder = piece(
		folder,
		root,
		"TrailHolder",
		Enum.PartType.Block,
		Vector3.new(0.2, 0.2, 0.2),
		CFrame.new(0, 0, 0.6),
		DARK
	)
	holder.Transparency = 1
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.9, 0)
	top.Parent = holder
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.9, 0)
	bottom.Parent = holder
	local t = Instance.new("Trail")
	t.Attachment0 = top
	t.Attachment1 = bottom
	t.Lifetime = 0.7
	t.MinLength = 0.1
	t.LightEmission = 1
	t.FaceCamera = true
	t.Color = ColorSequence.new(Color3.fromHex("#FFE9A8"), Color3.fromHex("#D7A746"))
	t.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	t.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0) })
	t.Parent = holder
end

local function build(character: Model, style: { [string]: string })
	local old = character:FindFirstChild(FOLDER)
	if old ~= nil then
		old:Destroy()
	end
	if next(style) == nil then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER
	folder.Parent = character
	if style.neck == "chain_silver" then
		chain(folder, character, SILVER)
	elseif style.neck == "chain_gold" then
		chain(folder, character, GOLD)
	end
	if style.head == "headset_player" then
		headset(folder, character)
	end
	if style.face == "glasses" then
		glasses(folder, character)
	end
	if style.wrist == "watch" then
		watch(folder, character)
	end
	if style.aura ~= nil then
		aura(folder, character, style.aura)
	end
	if style.trail == "trail_stars" then
		trail(folder, character)
	end
end

local function apply(player: Player)
	local character = player.Character
	if character == nil then
		return
	end
	local style = StyleModel.parsePublic(player:GetAttribute("BC_Style"), Wardrobe)
	local ok, err = pcall(build, character, style)
	if not ok then
		warn(`[Wearables] cosmétiques de {player.Name} non affichés : {err}`)
	end
end

local function watchPlayer(scope: any, player: Player)
	table.insert(
		scope,
		player:GetAttributeChangedSignal("BC_Style"):Connect(function()
			apply(player)
		end)
	)
	table.insert(
		scope,
		player.CharacterAdded:Connect(function(character)
			-- les membres arrivent en plusieurs fois : on attend la racine et la tête
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Head", 10)
			apply(player)
		end)
	)
	apply(player)
end

function Wearables.start(scope: any, deps: any)
	local setting = deps.UiState.settings.reducedEffects
	reducedEffects = deps.peek(setting)
	scope:Observer(setting):onChange(function()
		reducedEffects = deps.peek(setting)
		for _, player in Players:GetPlayers() do
			apply(player) -- la traînée suit le réglage
		end
	end)
	for _, player in Players:GetPlayers() do
		watchPlayer(scope, player)
	end
	table.insert(
		scope,
		Players.PlayerAdded:Connect(function(player)
			watchPlayer(scope, player)
		end)
	)
end

return Wearables
