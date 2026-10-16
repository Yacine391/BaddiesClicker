--[[
	Combat : rendu du combat individuel (§08, §21) à partir du flux `Combat` du serveur
	(StateController.onCombat) et du snapshot. Remplace Dev/DevCombatView et Dev/DevCombatPanel.

	- Monde : sbires (silhouettes violettes), boss (modèle de baddie de Visuals.Characters, sinon bloc
	  à sa couleur), plaques de nom et PV, zones de danger qui se remplissent jusqu'à l'impact,
	  chiffres de dégâts. Positions interpolées ; aucune collision, aucune logique de jeu.
	- Interface : barre du haut (vague puis PV du boss), PV du joueur, flash rouge quand un coup touche,
	  « puissance conseillée » hors combat, bouton REJOUER dans l'arène d'un niveau terminé.
	- Toasts de fin de rencontre (victoire, mort, abandon, combat annulé).
	L'attaque elle-même passe par le bouton principal du HUD (Input / PrimaryAction), ou la touche F.
]]

local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local Text = require(Client.UI.Text)
local Metrics = require(Client.UI.Metrics)
local Panel = require(Client.UI.Components.Panel)
local Toast = require(Client.UI.Components.Toast)
local CombatModel = require(Client.Logic.CombatModel)

local Combat = {}

local BOSS_SCALE = 1.5
local BAR_WIDTH = 380

type View = { model: Model, target: Vector3, fill: Frame, maxHP: number, height: number, lift: number }

local deps: any
local state = CombatModel.new()
local views: { [string]: View } = {}
local folder: Folder? = nil

local function container(): Folder
	if folder == nil or folder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "BC_Combat"
		f.Parent = workspace
		folder = f
	end
	return folder :: Folder
end

local function clearWorld()
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
	table.clear(views)
end

local function ghost(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None -- la plaque est la nôtre
		end
	end
end

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

-- Sbire : silhouette stylisée (corps, tête, visière néon rose), origine aux pieds
local function minionModel(): Model
	local model = Instance.new("Model")
	model.Name = "Minion"
	local body = part(model, {
		Name = "Body",
		Size = Vector3.new(2.2, 2.8, 1.4),
		CFrame = CFrame.new(0, 1.6, 0),
		Color = Color3.fromHex("#2B2440"),
	})
	part(model, {
		Name = "Head",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.6, 1.6, 1.6),
		CFrame = CFrame.new(0, 3.75, 0),
		Color = Color3.fromHex("#3A3150"),
	})
	part(model, {
		Name = "Visor",
		Size = Vector3.new(1.2, 0.3, 0.2),
		CFrame = CFrame.new(0, 3.85, -0.75),
		Color = Theme.Colors.Accent2,
		Material = Enum.Material.Neon,
	})
	model.PrimaryPart = body
	return model
end

-- Boss : modèle de baddie (P1 : Maya en boss de test tant que les autres modèles manquent), sinon bloc
local function bossModel(baddieId: string?): Model
	local visuals = ReplicatedStorage:FindFirstChild("Visuals")
	local characters = visuals and visuals:FindFirstChild("Characters")
	local dir = characters and characters:FindFirstChild("B01_Maya")
	local source = dir and (dir:FindFirstChild("Look03") or dir:FindFirstChild("Look01"))
	if source ~= nil and source:IsA("Model") then
		local model = source:Clone()
		ghost(model)
		model:ScaleTo(BOSS_SCALE)
		return model
	end
	local def = if baddieId then deps.Catalog.baddies[baddieId] else nil
	local model = Instance.new("Model")
	model.Name = "Boss"
	local body = part(model, {
		Name = "Body",
		Size = Vector3.new(4, 8, 2.4),
		CFrame = CFrame.new(0, 4, 0),
		Color = if def
				and def.palette
				and def.palette[1]
			then Color3.fromHex(def.palette[1])
			else Theme.Colors.Ink,
	})
	model.PrimaryPart = body
	return model
end

local function nameplate(adornee: BasePart, enemy: CombatModel.Enemy, offsetY: number): Frame
	local isBoss = enemy.kind == "boss"
	local def = if enemy.baddieId then deps.Catalog.baddies[enemy.baddieId] else nil
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = if isBoss then UDim2.fromOffset(190, 46) else UDim2.fromOffset(120, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	gui.LightInfluence = 0

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.fromScale(1, 0.55)
	name.FontFace = Theme.Fonts.Heavy
	name.TextScaled = true
	name.TextColor3 = if isBoss then Theme.Colors.Accent2Light else Theme.Colors.TextDim
	name.Text = if isBoss then `BOSS · {if def then string.upper(def.name) else "?"}` else "SBIRE"
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Ink
	stroke.Thickness = Theme.Stroke.Text
	stroke.Parent = name
	name.Parent = gui

	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromScale(0, 0.64)
	bar.Size = UDim2.fromScale(1, 0.28)
	bar.BackgroundColor3 = Theme.Colors.Panel
	bar.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(math.clamp(enemy.hp / enemy.maxHP, 0, 1), 1)
	fill.BackgroundColor3 = Theme.Colors.Danger
	fill.BorderSizePixel = 0
	corner:Clone().Parent = fill
	fill.Parent = bar
	bar.Parent = gui

	gui.Adornee = adornee
	gui.Parent = adornee
	return fill
end

local function playerPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function spawnEnemy(enemy: CombatModel.Enemy)
	local model = if enemy.kind == "boss" then bossModel(enemy.baddieId) else minionModel()
	model.Name = enemy.id
	-- Le pivot d'un modèle n'est pas à ses pieds : on mesure l'écart une fois, avant de le placer
	local box, size = model:GetBoundingBox()
	local bottom = box.Position.Y - size.Y / 2
	local lift = model:GetPivot().Position.Y - bottom
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if anchor == nil then
		return
	end
	local fill = nameplate(anchor, enemy, bottom + size.Y + 1.2 - anchor.Position.Y)
	local target = Vector3.new(enemy.x, state.floorY + lift, enemy.z)
	model:PivotTo(CFrame.new(target))
	model.Parent = container()
	views[enemy.id] =
		{ model = model, target = target, fill = fill, maxHP = enemy.maxHP, height = size.Y, lift = lift }
end

local function disk(x: number, z: number, radius: number, color: Color3, transparency: number): Part
	return part(container(), {
		Name = "Danger",
		Shape = Enum.PartType.Cylinder,
		CastShadow = false,
		Material = Enum.Material.Neon,
		Color = color,
		Transparency = transparency,
		Size = Vector3.new(0.15, radius * 2, radius * 2),
		CFrame = CFrame.new(x, state.floorY + 0.12, z) * CFrame.Angles(0, 0, math.rad(90)),
	})
end

-- Zone de danger : contour pâle + remplissage qui grandit jusqu'à l'instant d'impact (décidé par le serveur)
local function telegraph(message: { [string]: any })
	local outline = disk(message.x, message.z, message.radius, Theme.Colors.Danger, 0.75)
	local fill = disk(message.x, message.z, 0.3, Theme.Colors.Danger, 0.35)
	TweenService:Create(fill, TweenInfo.new(message.duration, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.16, message.radius * 2, message.radius * 2),
	}):Play()
	Debris:AddItem(outline, message.duration + 0.05)
	Debris:AddItem(fill, message.duration + 0.05)
end

local function floatingText(position: Vector3, text: string, color: Color3)
	local anchor = part(container(), {
		Name = "Float",
		Size = Vector3.new(0.2, 0.2, 0.2),
		Transparency = 1,
		CFrame = CFrame.new(position),
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 36)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.Fonts.Heavy
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Ink
	stroke.Thickness = Theme.Stroke.Text
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = anchor
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(anchor, info, { CFrame = CFrame.new(position + Vector3.new(0, 3, 0)) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	Debris:AddItem(anchor, 0.75)
end

local function onHit(message: { [string]: any }, enemy: CombatModel.Enemy?)
	local view = views[message.targetId]
	if view == nil or enemy == nil then
		return
	end
	view.fill.Size = UDim2.fromScale(math.clamp(enemy.hp / view.maxHP, 0, 1), 1)
	local above = view.target + Vector3.new(0, view.height - view.lift + 0.5, 0)
	floatingText(above, deps.Format.number(message.damage or 0), Theme.Colors.Text)
	if message.killed then
		views[message.targetId] = nil
		local sink = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, d in view.model:GetDescendants() do
			if d:IsA("BasePart") then
				TweenService:Create(d, sink, { Transparency = 1 }):Play()
			end
		end
		Debris:AddItem(view.model, 0.4)
	end
end

function Combat.start(scope: any, dependencies: any)
	deps = dependencies
	local version = scope:Value(0) -- incrémenté à chaque message : recalcule les barres
	local arenaLevel = scope:Value(nil :: number?)

	local function bump()
		version:set(deps.peek(version) + 1)
	end

	local hurtFrame: Frame? = nil
	local function hurt()
		if hurtFrame ~= nil then
			hurtFrame.BackgroundTransparency = 0.6
			TweenService:Create(hurtFrame, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
		end
	end

	local bar = scope:Computed(function(use)
		use(version)
		return CombatModel.bar(state, deps.Catalog, deps.Format.number)
	end)
	local playerBar = scope:Computed(function(use)
		return CombatModel.playerBar(use(deps.Store.snapshot))
	end)
	local hint = scope:Computed(function(use)
		return CombatModel.hint(use(deps.Store.snapshot), deps.Format.number)
	end)
	local replay = scope:Computed(function(use)
		return CombatModel.replayLevel(use(deps.Store.snapshot), use(arenaLevel))
	end)
	local buttonHeight = Metrics.touch(scope, 48)

	local function barFrame(name: string, order: number, ratio: any, color: any): Frame
		return scope:New("Frame")({
			Name = name,
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 14),
			BackgroundColor3 = Theme.Colors.Ink,
			BackgroundTransparency = 0.2,
			[scope.Children] = {
				scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }),
				scope:New("Frame")({
					Name = "Fill",
					BackgroundColor3 = color,
					Size = scope:Spring(
						scope:Computed(function(use)
							return UDim2.fromScale(use(ratio), 1)
						end),
						30,
						1
					),
					[scope.Children] = { scope:New("UICorner")({ CornerRadius = UDim.new(1, 0) }) },
				}),
			},
		})
	end

	local root
	scope:New("ScreenGui")({
		Name = "Combat",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		DisplayOrder = 2,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
		[scope.Children] = {
			scope:New("Frame")({
				Name = "Root",
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 1,
				[scope.Children] = {
					-- Barre de combat : vague puis boss, PV du joueur dessous
					Panel(scope, {
						Name = "CombatBar",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 12),
						Size = UDim2.fromOffset(BAR_WIDTH, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						Visible = scope:Computed(function(use)
							return use(bar).visible
						end),
						Line = Theme.Colors.Accent2,
						Children = {
							scope:New("UIPadding")({
								PaddingTop = UDim.new(0, 8),
								PaddingBottom = UDim.new(0, 10),
								PaddingLeft = UDim.new(0, 12),
								PaddingRight = UDim.new(0, 12),
							}),
							scope:New("UIListLayout")({
								SortOrder = Enum.SortOrder.LayoutOrder,
								Padding = UDim.new(0, 5),
							}),
							Text.label(scope, {
								Name = "Title",
								LayoutOrder = 1,
								Size = UDim2.new(1, 0, 0, 20),
								Weight = "Heavy",
								Text = scope:Computed(function(use)
									return use(bar).title
								end),
								Color = scope:Computed(function(use)
									return if use(bar).isBoss
										then Theme.Colors.Accent2Light
										else Theme.Colors.Text
								end),
							}),
							barFrame(
								"Enemy",
								2,
								scope:Computed(function(use)
									return use(bar).ratio
								end),
								scope:Computed(function(use)
									return if use(bar).isBoss
										then Theme.Colors.Danger
										else Theme.Colors.Accent2
								end)
							),
							Text.label(scope, {
								Name = "Detail",
								LayoutOrder = 3,
								Size = UDim2.new(1, 0, 0, 16),
								Weight = "Bold",
								Color = Theme.Colors.TextDim,
								Text = scope:Computed(function(use)
									return use(bar).text
								end),
							}),
							barFrame(
								"Player",
								4,
								scope:Computed(function(use)
									return use(playerBar).ratio
								end),
								scope:Computed(function(use)
									return if use(playerBar).low
										then Theme.Colors.Danger
										else Theme.Colors.Accent
								end)
							),
							Text.label(scope, {
								Name = "PlayerHP",
								LayoutOrder = 5,
								Size = UDim2.new(1, 0, 0, 16),
								Weight = "Bold",
								Color = scope:Computed(function(use)
									return if use(playerBar).low
										then Theme.Colors.Danger
										else Theme.Colors.Accent
								end),
								Text = scope:Computed(function(use)
									return `TOI · {use(playerBar).text}`
								end),
							}),
						},
					}),
					-- Hors combat : puissance conseillée pour le prochain niveau (§09)
					Panel(scope, {
						Name = "Hint",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 12),
						Size = UDim2.fromOffset(BAR_WIDTH, 34),
						Visible = scope:Computed(function(use)
							return use(hint).visible and not use(bar).visible
						end),
						Children = {
							Text.label(scope, {
								Name = "Text",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.new(1, -20, 0, 18),
								Weight = "Bold",
								Text = scope:Computed(function(use)
									return use(hint).text
								end),
								Color = scope:Computed(function(use)
									return if use(hint).ready
										then Theme.Colors.Accent
										else Theme.Colors.TextDim
								end),
							}),
						},
					}),
					-- Dans l'arène d'un niveau terminé : relancer la vague (intention StartWave)
					scope:New("TextButton")({
						Name = "Replay",
						AnchorPoint = Vector2.new(0.5, 0),
						Position = UDim2.new(0.5, 0, 0, 54),
						Size = scope:Computed(function(use)
							return UDim2.fromOffset(260, use(buttonHeight))
						end),
						AutoButtonColor = true,
						BackgroundColor3 = Theme.Colors.Accent2,
						Text = "",
						Visible = scope:Computed(function(use)
							return use(replay) ~= nil
						end),
						[scope.OnEvent("Activated")] = function()
							local levelId = deps.peek(replay)
							if levelId ~= nil then
								deps.StateController.send(
									deps.Actions.StartWave or "StartWave",
									{ levelId = levelId }
								)
							end
						end,
						[scope.Children] = {
							scope:New("UICorner")({ CornerRadius = UDim.new(0, Theme.Radius.Button) }),
							Text.label(scope, {
								Name = "Label",
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.new(1, -24, 0, 22),
								Weight = "Heavy",
								Color = Theme.Colors.Ink,
								Text = scope:Computed(function(use)
									local levelId = use(replay)
									return if levelId then `REJOUER LE NIVEAU {levelId}` else ""
								end),
							}),
						},
					}),
				},
			}),
		},
	})
	local gui = Players.LocalPlayer.PlayerGui:WaitForChild("Combat")
	root = gui:WaitForChild("Root")
	-- Flash rouge quand un coup touche (sous le reste de l'interface de combat)
	local frame = Instance.new("Frame")
	frame.Name = "Hurt"
	frame.BackgroundColor3 = Theme.Colors.Danger
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 0
	frame.Parent = gui
	hurtFrame = frame

	deps.StateController.onCombat(function(message)
		local enemy = CombatModel.apply(state, message)
		local t = message.t
		if t == "start" then
			clearWorld()
		elseif t == "spawn" and enemy ~= nil then
			spawnEnemy(enemy)
		elseif t == "pos" then
			for _, item in message.list or {} do
				local view = views[item[1]]
				if view ~= nil then
					view.target = Vector3.new(item[2], state.floorY + view.lift, item[3])
				end
			end
			return -- 10 fois/s : les barres ne changent pas
		elseif t == "telegraph" then
			telegraph(message)
			return
		elseif t == "impact" then
			local flashDisk = disk(
				message.x,
				message.z,
				message.radius,
				if message.hit then Theme.Colors.Danger else Theme.Colors.Text,
				0.25
			)
			TweenService:Create(flashDisk, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			Debris:AddItem(flashDisk, 0.35)
			if message.hit then
				hurt()
				local position = playerPosition()
				if position then
					floatingText(position + Vector3.new(0, 3, 0), `-{message.damage} PV`, Theme.Colors.Danger)
				end
			end
		elseif t == "hit" then
			onHit(message, enemy)
		elseif t == "end" then
			clearWorld()
		end
		bump()
	end)

	deps.StateController.onResult(function(event)
		local text = CombatModel.toastFor(event, deps.Catalog, deps.Format.number)
		if text ~= nil and root ~= nil then
			Toast.show(root, text)
		end
	end)

	-- Clavier : F = bouton principal (entraîner au repos, attaquer en combat), comme un clic
	ContextActionService:BindAction("BC_PrimaryAction", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			deps.Input.train()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F)

	-- Ennemis : interpolation vers la position serveur, tournés vers le joueur
	table.insert(
		scope,
		RunService.RenderStepped:Connect(function(dt)
			local alpha = math.clamp(dt * 12, 0, 1)
			local me = playerPosition()
			for _, view in views do
				local current = view.model:GetPivot().Position
				local nextPos = current:Lerp(view.target, alpha)
				local look = if me then Vector3.new(me.X, nextPos.Y, me.Z) else nextPos + Vector3.new(0, 0, 1)
				if (look - nextPos).Magnitude > 0.1 then
					view.model:PivotTo(CFrame.lookAt(nextPos, look))
				else
					view.model:PivotTo(CFrame.new(nextPos))
				end
			end
		end)
	)

	-- Arène où se trouve le joueur (bouton « rejouer ») : Workspace.Levels.LevelN.Arena
	task.spawn(function()
		while root ~= nil and root.Parent ~= nil do
			task.wait(0.5)
			local found: number? = nil
			local position = playerPosition()
			local levels = workspace:FindFirstChild("Levels")
			if position ~= nil and levels ~= nil then
				for _, levelFolder in levels:GetChildren() do
					local levelId = tonumber(string.match(levelFolder.Name, "^Level(%d+)$"))
					local zone = levelFolder:FindFirstChild("Arena")
					if levelId ~= nil and zone ~= nil and zone:IsA("BasePart") then
						local localPos = zone.CFrame:PointToObjectSpace(position)
						local half = zone.Size / 2
						if
							math.abs(localPos.X) <= half.X
							and math.abs(localPos.Y) <= half.Y + 6
							and math.abs(localPos.Z) <= half.Z
						then
							found = levelId
							break
						end
					end
				end
			end
			if found ~= deps.peek(arenaLevel) then
				arenaLevel:set(found)
			end
		end
	end)
end

return Combat
