--[[
	Panneau de combat de TEST (codeur A, Studio uniquement) : à droite de l'écran, visible en combat
	ou dans l'arène d'un niveau déjà terminé. Il existe parce que le HUD actuel n'envoie pas encore
	l'intention Attack ; le codeur B le remplacera par son vrai HUD de combat.

	- Bouton ATTAQUER (et touche F) : intention Attack { encounterId }, le serveur choisit la cible.
	- PV, progression de la vague, boss en cours.
	- REJOUER LE NIVEAU N : intention StartWave { levelId } depuis l'arène d'un niveau terminé.
	- Messages : mort, victoire et drop, combat abandonné, arrivée du boss.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared:WaitForChild("Balance"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local NUIT = Color3.fromHex("#242036")
local OR = Color3.fromHex("#D7A746")
local CREME = Color3.fromHex("#F4EEE7")
local ROUGE = Color3.fromRGB(205, 45, 70)

local DevCombatPanel = {}

local function baddieName(id: string?): string
	local def = if id then Catalog.baddies[id] else nil
	return if def then def.name else (id or "?")
end

-- Niveau dont l'arène contient la position (Workspace.Levels.LevelN.Arena)
local function arenaAt(position: Vector3): number?
	local levels = workspace:FindFirstChild("Levels")
	if levels == nil then
		return nil
	end
	for _, folder in levels:GetChildren() do
		local levelId = tonumber(string.match(folder.Name, "^Level(%d+)$"))
		local zone = folder:FindFirstChild("Arena")
		if levelId ~= nil and zone ~= nil and zone:IsA("BasePart") then
			local localPos = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if
				math.abs(localPos.X) <= half.X
				and math.abs(localPos.Y) <= half.Y + 6
				and math.abs(localPos.Z) <= half.Z
			then
				return levelId
			end
		end
	end
	return nil
end

local function label(parent: Instance, size: number, color: Color3, order: number): TextLabel
	local t = Instance.new("TextLabel")
	t.LayoutOrder = order
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0, 0)
	t.AutomaticSize = Enum.AutomaticSize.Y
	t.Font = Enum.Font.GothamBold
	t.TextSize = size
	t.TextColor3 = color
	t.TextWrapped = true
	t.Text = ""
	t.Parent = parent
	return t
end

local function button(
	parent: Instance,
	text: string,
	color: Color3,
	height: number,
	order: number
): TextButton
	local b = Instance.new("TextButton")
	b.LayoutOrder = order
	b.Size = UDim2.new(1, 0, 0, height)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBlack
	b.TextSize = if height >= 60 then 26 else 17
	b.TextColor3 = CREME
	b.Text = text
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = b
	b.Parent = parent
	return b
end

function DevCombatPanel.start(state)
	local player = Players.LocalPlayer

	local gui = Instance.new("ScreenGui")
	gui.Name = "DevCombatPanel"
	gui.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.fromOffset(250, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = NUIT
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel
	local pad = Instance.new("UIPadding")
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(pad :: any)[side] = UDim.new(0, 10)
	end
	pad.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = panel
	panel.Parent = gui

	local title = label(panel, 12, OR, 1)
	title.Text = "COMBAT DE TEST · codeur A"
	local status = label(panel, 17, CREME, 2)
	local attack = button(panel, "ATTAQUER (F)", ROUGE, 64, 3)
	local replay = button(panel, "", NUIT, 40, 4)

	local toasts = Instance.new("Frame")
	toasts.AnchorPoint = Vector2.new(0.5, 0)
	toasts.Position = UDim2.new(0.5, 0, 0, 120)
	toasts.Size = UDim2.fromOffset(480, 0)
	toasts.AutomaticSize = Enum.AutomaticSize.Y
	toasts.BackgroundTransparency = 1
	local toastLayout = Instance.new("UIListLayout")
	toastLayout.SortOrder = Enum.SortOrder.LayoutOrder
	toastLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	toastLayout.Padding = UDim.new(0, 6)
	toastLayout.Parent = toasts
	toasts.Parent = gui

	local toastCount = 0
	local function toast(text: string, color: Color3, seconds: number?)
		toastCount += 1
		local t = Instance.new("TextLabel")
		t.LayoutOrder = toastCount
		t.Size = UDim2.fromOffset(480, 0)
		t.AutomaticSize = Enum.AutomaticSize.Y
		t.BackgroundColor3 = NUIT
		t.Font = Enum.Font.GothamBold
		t.TextSize = 18
		t.TextColor3 = color
		t.TextWrapped = true
		t.Text = text
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 10)
		c.Parent = t
		local p = Instance.new("UIPadding")
		for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
			(p :: any)[side] = UDim.new(0, 10)
		end
		p.Parent = t
		t.Parent = toasts
		task.delay(seconds or 5, function()
			t:Destroy()
		end)
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	local current: { [string]: any }? = nil
	local replayLevel: number? = nil

	local function refresh()
		local s = current
		local inCombat = s ~= nil and s.combat ~= nil and s.combat.active
		attack.Visible = inCombat
		replay.Visible = not inCombat and replayLevel ~= nil
		panel.Visible = inCombat or replayLevel ~= nil
		if s ~= nil and inCombat then
			local c = s.combat
			local progress = if c.phase == "wave"
				then `sbires {c.minionsKilled}/{c.minionsTotal}`
				else `BOSS {string.upper(baddieName(c.boss))}`
			status.Text = `Niveau {c.levelId} · PV {Format.number(c.hp)}/{c.maxHP}\n{progress}`
			status.TextColor3 = if c.hp <= c.maxHP * 0.3 then ROUGE else CREME
			attack.Text = `ATTAQUER  {Format.number(s.active.damagePerClick)}  (F)`
		elseif replayLevel ~= nil then
			status.Text = `Niveau {replayLevel} terminé`
			status.TextColor3 = OR
			replay.Text = `REJOUER LE NIVEAU {replayLevel}`
		end
	end

	state.onState(function(s)
		current = s
		refresh()
	end)

	-- Attaque : clic, toucher ou touche F ; même limite que le serveur (8/s)
	local minInterval = 1 / Balance.combat.maxActionsPerSecond
	local lastSent = 0
	local function doAttack()
		local s = current
		if s == nil or s.combat == nil or not s.combat.active then
			return
		end
		local now = os.clock()
		if now - lastSent < minInterval then
			return
		end
		lastSent = now
		state.send(Net.Actions.Attack, { encounterId = s.combat.encounterId })
	end
	attack.Activated:Connect(doAttack)
	ContextActionService:BindAction("BC_DevAttack", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			doAttack()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F)

	replay.Activated:Connect(function()
		if replayLevel ~= nil then
			state.send(Net.Actions.StartWave, { levelId = replayLevel })
		end
	end)

	-- « Rejouer » : dans l'arène d'un niveau terminé, hors combat
	task.spawn(function()
		while gui.Parent ~= nil do
			task.wait(0.5)
			local s = current
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local found = nil
			if
				s ~= nil
				and s.combat ~= nil
				and not s.combat.active
				and root ~= nil
				and root:IsA("BasePart")
			then
				local levelId = arenaAt(root.Position)
				if levelId ~= nil and table.find(s.clearedLevels or {}, levelId) ~= nil then
					found = levelId
				end
			end
			if found ~= replayLevel then
				replayLevel = found
				refresh()
			end
		end
	end)

	state.onResult(function(event)
		local kind = event.kind
		if kind == "levelCleared" then
			local text =
				`Niveau {event.level} terminé : +{Format.number(event.power)} puissance, la porte s'ouvre.`
			if event.firstClear then
				text ..= " +1 ticket baddie (premier passage)."
			end
			if event.drop == nil then
				text ..= " Pas de drop cette fois : 10 % à chaque victoire, aucun drop garanti."
			else
				text ..= ` Drop de {baddieName(event.drop)} : il t'attend dans tes drops en attente.`
			end
			toast(text, OR, 7)
		elseif kind == "death" then
			toast("Retour au lobby. Ta puissance et tes baddies restent ; les portes se referment.", ROUGE, 6)
		elseif kind == "combatLeft" then
			toast("Combat abandonné : tu as quitté l'arène. Aucune récompense.", CREME)
		end
	end)

	state.onCombat(function(message)
		if message.t == "spawn" and message.enemy.kind == "boss" then
			toast(
				`BOSS : {baddieName(message.enemy.baddieId)} · 10 % de chance à chaque victoire. Aucun drop garanti.`,
				OR,
				5
			)
		end
	end)
end

return DevCombatPanel
