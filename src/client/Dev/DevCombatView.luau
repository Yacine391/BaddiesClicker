--[[
	Vue de combat DEV (codeur A) : rend localement les ennemis, leurs PV et les zones de danger
	envoyés par le serveur (remote Combat). Blocs gris et rouges, à remplacer par le codeur B
	(modèles Blender, animations, particules). Aucune logique de jeu ici : le serveur décide de tout.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))

local DANGER = Color3.fromRGB(255, 40, 60)

local LOOK = {
	minion = { size = Vector3.new(3, 5, 2), color = Color3.fromRGB(135, 138, 150) },
	boss = { size = Vector3.new(5, 9, 3), color = Color3.fromRGB(21, 21, 23) },
}

type View = { part: BasePart, target: Vector3, fill: Frame, maxHP: number, height: number }

local DevCombatView = {}

local folder: Folder? = nil
local floorY = 0
local views: { [string]: View } = {}

local function container(): Folder
	if folder == nil or folder.Parent == nil then
		local f = Instance.new("Folder")
		f.Name = "BC_DevCombat"
		f.Parent = workspace
		folder = f
	end
	return folder :: Folder
end

local function clear()
	if folder ~= nil then
		folder:Destroy()
		folder = nil
	end
	table.clear(views)
end

local function spawnEnemy(enemy: { [string]: any })
	local look = LOOK[enemy.kind] or LOOK.minion
	local def = if enemy.baddieId then Catalog.baddies[enemy.baddieId] else nil

	local part = Instance.new("Part")
	part.Name = enemy.id
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Size = look.size
	part.Material = Enum.Material.SmoothPlastic
	part.Color = if def and def.palette[1] then Color3.fromHex(def.palette[1]) else look.color
	part.CFrame = CFrame.new(enemy.x, floorY + look.size.Y / 2, enemy.z)

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffset = Vector3.new(0, look.size.Y / 2 + 1.6, 0)
	gui.AlwaysOnTop = true
	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0.55, 0)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBlack
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Text = if enemy.kind == "boss"
		then `BOSS · {if def then string.upper(def.name) else "?"}`
		else "Sbire"
	name.Parent = gui
	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromScale(0, 0.62)
	bar.Size = UDim2.fromScale(1, 0.3)
	bar.BackgroundColor3 = Color3.fromRGB(30, 28, 40)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(math.clamp(enemy.hp / enemy.maxHP, 0, 1), 1)
	fill.BackgroundColor3 = DANGER
	fill.BorderSizePixel = 0
	fill.Parent = bar
	gui.Parent = part

	part.Parent = container()
	views[enemy.id] =
		{ part = part, target = part.Position, fill = fill, maxHP = enemy.maxHP, height = look.size.Y }
end

local function disk(x: number, z: number, radius: number, color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.Size = Vector3.new(0.15, radius * 2, radius * 2)
	p.CFrame = CFrame.new(x, floorY + 0.12, z) * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = container()
	return p
end

-- Zone de danger : contour + remplissage qui grandit jusqu'à l'impact
local function telegraph(message: { [string]: any })
	local outline = disk(message.x, message.z, message.radius, DANGER, 0.7)
	local fill = disk(message.x, message.z, 0.3, DANGER, 0.35)
	TweenService:Create(fill, TweenInfo.new(message.duration, Enum.EasingStyle.Linear), {
		Size = Vector3.new(0.16, message.radius * 2, message.radius * 2),
	}):Play()
	Debris:AddItem(outline, message.duration + 0.05)
	Debris:AddItem(fill, message.duration + 0.05)
end

local function impact(message: { [string]: any })
	local flash =
		disk(message.x, message.z, message.radius, if message.hit then DANGER else Color3.new(1, 1, 1), 0.2)
	TweenService:Create(flash, TweenInfo.new(0.3), { Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.35)
end

local function onHit(message: { [string]: any })
	local view = views[message.targetId]
	if view == nil then
		return
	end
	view.fill.Size = UDim2.fromScale(math.clamp(message.hp / view.maxHP, 0, 1), 1)
	if message.killed then
		views[message.targetId] = nil
		TweenService:Create(view.part, TweenInfo.new(0.25), { Transparency = 1, Size = view.part.Size * 1.4 })
			:Play()
		Debris:AddItem(view.part, 0.3)
	end
end

function DevCombatView.start(state)
	state.onCombat(function(message)
		local t = message.t
		if t == "start" then
			clear()
			floorY = message.floorY
		elseif t == "spawn" then
			spawnEnemy(message.enemy)
		elseif t == "pos" then
			for _, item in message.list do
				local view = views[item[1]]
				if view ~= nil then
					view.target = Vector3.new(item[2], floorY + view.height / 2, item[3])
				end
			end
		elseif t == "telegraph" then
			telegraph(message)
		elseif t == "impact" then
			impact(message)
		elseif t == "hit" then
			onHit(message)
		elseif t == "end" then
			clear()
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		local alpha = math.clamp(dt * 12, 0, 1)
		for _, view in views do
			view.part.CFrame = CFrame.new(view.part.Position:Lerp(view.target, alpha))
		end
	end)
end

return DevCombatView
