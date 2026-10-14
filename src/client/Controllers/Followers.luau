--!strict
--[[
	Followers : la principale, les exposées et le crew suivent leur joueur (§28).
	Rendu 100 % local : joueur local depuis le snapshot, autres joueurs depuis leurs attributs BC_*.
	Aucune collision, pas de Humanoid ; arrêter une animation ne change aucun gain.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent
local Formation = require(Client.Logic.Formation)
local FX = require(script.Parent.FX)

local Followers = {}

local IDLE_ANIM = "rbxassetid://507766666"
local WALK_ANIM = "rbxassetid://507777826"
local WALK_SPEED = 2
local OTHERS_MAX_DISTANCE = 120
local MAX_ANIMATED = 20

-- ID du catalogue → dossier dans Visuals.Characters ; les baddies ont des looks, le crew un « Base »
local VISUALS: { [string]: { folder: string, crew: boolean } } = {
	maya = { folder = "B01_Maya", crew = false },
	malik = { folder = "C02_Malik", crew = true },
	test_b99 = { folder = "TEST", crew = false },
}

type Member = { id: string, kind: "baddie" | "crew" }
type Follower = {
	member: Member,
	model: Model,
	pos: Formation.Point,
	idle: AnimationTrack?,
	walk: AnimationTrack?,
}
type Team = { signature: string, followers: { Follower } }

local teams: { [Player]: Team } = {}
local folder: Folder
local deps: any
local pendingEntrance: { [string]: boolean } = {}

local function lookIndexFor(player: Player, id: string): number
	if player == Players.LocalPlayer then
		local s = deps.peek(deps.Store.snapshot)
		local looks = s and s.collection and s.collection.looks and s.collection.looks[id]
		return if looks and looks.selected then looks.selected else 1
	end
	if player:GetAttribute("BC_ActiveBaddie") == id then
		return tonumber(player:GetAttribute("BC_ActiveLook")) or 1
	end
	return 1
end

local function grey(): Model
	local m = Instance.new("Model")
	local p = Instance.new("Part")
	p.Name = "HumanoidRootPart"
	p.Size = Vector3.new(2, 5, 1)
	p.Color = Color3.fromHex("#7D7A88")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = m
	m.PrimaryPart = p
	return m
end

local function buildModel(player: Player, member: Member): Model?
	local entry = VISUALS[member.id]
	if entry == nil then
		warn(`[Followers] identité inconnue ignorée : {member.id}`)
		return nil
	end
	local characters = ReplicatedStorage:FindFirstChild("Visuals")
		and (ReplicatedStorage :: any).Visuals:FindFirstChild("Characters")
	local dir = characters and characters:FindFirstChild(entry.folder)
	local source: Instance? = nil
	if dir then
		if member.id == "test_b99" then
			source = dir:FindFirstChild("TEST_B99")
		elseif entry.crew then
			source = dir:FindFirstChild("Base")
		else
			source = dir:FindFirstChild(string.format("Look%02d", lookIndexFor(player, member.id)))
				or dir:FindFirstChild("Look01")
		end
	end
	if source == nil or not source:IsA("Model") then
		warn(`[Followers] modèle absent pour {member.id} : silhouette grise`)
		return grey()
	end
	local model = source:Clone()
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	FX.attach(model, member.id)
	return model
end

local function playAnims(follower: Follower)
	local controller = follower.model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if animator == nil then
		return
	end
	local idle = Instance.new("Animation")
	idle.AnimationId = IDLE_ANIM
	local walk = Instance.new("Animation")
	walk.AnimationId = WALK_ANIM
	follower.idle = animator:LoadAnimation(idle)
	follower.walk = animator:LoadAnimation(walk)
	if follower.idle then
		follower.idle:Play()
	end
end

local function membersOf(player: Player): { Member }
	if player == Players.LocalPlayer then
		local s = deps.peek(deps.Store.snapshot)
		if s == nil then
			return {}
		end
		local crew = {}
		for _, entry in s.crew or {} do
			table.insert(crew, entry.id)
		end
		local display = s.collection and s.collection.display or {}
		return Formation.members(s.active and s.active.baddieId, display, crew)
	end
	if
		player:GetAttribute("BC_Ready") ~= true or not deps.peek(deps.UiState.settings.showOthersFollowers)
	then
		return {}
	end
	local function split(value: any): { string }
		local list = {}
		if type(value) == "string" then
			for id in string.gmatch(value, "[^,]+") do
				table.insert(list, id)
			end
		end
		return list
	end
	local active = player:GetAttribute("BC_ActiveBaddie")
	return Formation.members(
		if type(active) == "string" and active ~= "" then active else nil,
		split(player:GetAttribute("BC_Display")),
		split(player:GetAttribute("BC_EquippedCrew"))
	)
end

local function signatureOf(player: Player, members: { Member }): string
	local parts = {}
	for _, m in members do
		table.insert(parts, `{m.id}:{if m.kind == "baddie" then lookIndexFor(player, m.id) else 0}`)
	end
	return table.concat(parts, ",")
end

local function clearTeam(player: Player)
	local team = teams[player]
	if team then
		for _, f in team.followers do
			f.model:Destroy()
		end
		teams[player] = nil
	end
end

local function refresh(player: Player)
	local members = membersOf(player)
	local signature = signatureOf(player, members)
	local team = teams[player]
	if team and team.signature == signature then
		return
	end
	clearTeam(player)
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local origin = if hrp then (hrp :: BasePart).Position else Vector3.zero
	local followers = {}
	for _, member in members do
		local model = buildModel(player, member)
		if model then
			local start = origin
			if player == Players.LocalPlayer and pendingEntrance[member.id] then
				pendingEntrance[member.id] = nil
				start = origin + Vector3.new(0, 8, 0) -- petite entrée en scène : il descend rejoindre l'équipe
			end
			model.Name = `{player.Name}_{member.id}`
			model:PivotTo(CFrame.new(start))
			model.Parent = folder
			local f: Follower =
				{ member = member, model = model, pos = { x = start.X, y = start.Y, z = start.Z } }
			playAnims(f)
			table.insert(followers, f)
		end
	end
	teams[player] = { signature = signature, followers = followers }
end

local function floatAbove(model: Model, text: string)
	local anchor = model:FindFirstChild("NameTagAttachment", true)
	if anchor == nil then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 40)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor :: Attachment
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0.5, 0)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.FontFace = Font.fromName("LuckiestGuy")
	label.TextColor3 = Color3.fromHex("#5FE2FF")
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("#1B1530")
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = folder
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, 3, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	task.delay(0.9, function()
		gui:Destroy()
	end)
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local animated = 0
	for player, team in teams do
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if hrp == nil then
			continue
		end
		local far = player ~= Players.LocalPlayer
			and (hrp.Position - camera.CFrame.Position).Magnitude > OTHERS_MAX_DISTANCE
		local moving = Vector3.new(hrp.AssemblyLinearVelocity.X, 0, hrp.AssemblyLinearVelocity.Z).Magnitude
			> WALK_SPEED
		local facing = hrp.CFrame - hrp.Position
		for index, f in team.followers do
			f.model.Parent = if far then nil else folder
			if far then
				continue
			end
			local offset = Formation.offset(index)
			local target = (hrp.CFrame * CFrame.new(offset.x, 0, offset.z)).Position
			f.pos = Formation.step(f.pos, { x = target.X, y = target.Y, z = target.Z }, dt)
			f.model:PivotTo(CFrame.new(f.pos.x, f.pos.y, f.pos.z) * facing)
			animated += 1
			local allowed = animated <= MAX_ANIMATED
			if f.idle and f.walk then
				local wantWalk = allowed and moving
				local wantIdle = allowed and not moving
				if wantWalk and not f.walk.IsPlaying then
					f.walk:Play(0.2)
				elseif not wantWalk and f.walk.IsPlaying then
					f.walk:Stop(0.2)
				end
				if wantIdle and not f.idle.IsPlaying then
					f.idle:Play(0.2)
				elseif not wantIdle and f.idle.IsPlaying then
					f.idle:Stop(0.2)
				end
			end
		end
	end
end

function Followers.start(scope: any, dependencies: any)
	deps = dependencies
	folder = Instance.new("Folder")
	folder.Name = "Followers"
	folder.Parent = Workspace
	table.insert(scope, folder)

	local function watch(player: Player)
		table.insert(
			scope,
			player.AttributeChanged:Connect(function(name)
				if string.sub(name, 1, 3) == "BC_" then
					refresh(player)
				end
			end)
		)
		table.insert(
			scope,
			player.CharacterAdded:Connect(function()
				clearTeam(player) -- repartir près du nouvel avatar
				task.defer(refresh, player)
			end)
		)
		refresh(player)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	table.insert(scope, Players.PlayerAdded:Connect(watch))
	table.insert(scope, Players.PlayerRemoving:Connect(clearTeam))

	scope:Observer(deps.Store.snapshot):onChange(function()
		refresh(Players.LocalPlayer)
	end)
	scope:Observer(deps.UiState.settings.showOthersFollowers):onChange(function()
		for _, player in Players:GetPlayers() do
			if player ~= Players.LocalPlayer then
				refresh(player)
			end
		end
	end)

	deps.StateController.onResult(function(event)
		if event.kind == "crewJoined" and event.crewId then
			pendingEntrance[event.crewId] = true
		elseif event.kind == "passiveTick" then
			local team = teams[Players.LocalPlayer]
			if team == nil then
				return
			end
			for _, f in team.followers do
				if f.member.kind == "crew" then
					floatAbove(f.model, "+" .. deps.Format.number(event.amount or 0))
					break
				end
			end
		end
	end)

	table.insert(scope, RunService.RenderStepped:Connect(step))
	table.insert(scope, function()
		for player in teams do
			clearTeam(player)
		end
	end)
end

return Followers
