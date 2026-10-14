--[[
	HUD DEV du codeur A : juste assez d'interface pour tester le serveur en Play.
	Ce n'est PAS le HUD du jeu. Le codeur B le remplace, puis passe Flags.DEV_HUD à false.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared:WaitForChild("Balance"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Format = require(Shared:WaitForChild("Format"))
local Net = require(Shared:WaitForChild("Net"))

local NUIT = Color3.fromHex("#242036")
local VIOLET = Color3.fromHex("#7642A3")
local CYAN = Color3.fromHex("#13A6B5")
local OR = Color3.fromHex("#D7A746")
local CREME = Color3.fromHex("#F4EEE7")

local DevHUD = {}

local function make(className: string, props: { [string]: any }, children: { Instance }?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if children ~= nil then
		for _, child in children do
			child.Parent = instance
		end
	end
	return instance
end

local function corner(radius: number)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function padding(px: number)
	return make("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
	})
end

local function line(order: number, size: number, color: Color3, font: Enum.Font)
	return make("TextLabel", {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = font,
		TextSize = size,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Text = "",
	})
end

local function crewLabel(id: string): string
	local def = Catalog.crew[id]
	return if def then `{def.name} ({def.role})` else id
end

function DevHUD.start(state)
	local player = Players.LocalPlayer

	local gui = make("ScreenGui", {
		Name = "DevHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})

	-- Panneau d'état (haut gauche)
	local panel = make("Frame", {
		Name = "Panel",
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(360, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = NUIT,
		BackgroundTransparency = 0.08,
	}, {
		corner(12),
		padding(12),
		make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }),
	})
	panel.Parent = gui

	local title = line(1, 12, VIOLET, Enum.Font.GothamBold)
	title.Text = "HUD DEV · codeur A · pas le HUD final"
	local power = line(2, 30, OR, Enum.Font.GothamBlack)
	power.Text = "Chargement du profil…"
	local gains = line(3, 15, CREME, Enum.Font.GothamMedium)
	local principal = line(4, 15, CREME, Enum.Font.GothamMedium)
	local crewLine = line(5, 15, CREME, Enum.Font.GothamMedium)
	local tickets = line(6, 14, CREME, Enum.Font.Gotham)
	for _, label in { title, power, gains, principal, crewLine, tickets } do
		label.Parent = panel
	end

	-- Bouton d'entraînement (bas centre), grande cible tactile
	local scale = make("UIScale", { Scale = 1 })
	local button = make("TextButton", {
		Name = "Train",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(300, 84),
		BackgroundColor3 = VIOLET,
		AutoButtonColor = true,
		Font = Enum.Font.GothamBlack,
		TextSize = 28,
		TextColor3 = CREME,
		Text = "ENTRAÎNER",
	}, {
		corner(18),
		scale,
		make("UIStroke", {
			Color = CREME,
			Thickness = 2,
			Transparency = 0.6,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
	})
	button.Parent = gui

	-- Pile de toasts (haut centre)
	local toasts = make("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(440, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
	}, {
		make("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			Padding = UDim.new(0, 6),
		}),
	})
	toasts.Parent = gui

	local toastCount = 0
	local function toast(text: string, color: Color3)
		toastCount += 1
		local item = make("TextLabel", {
			LayoutOrder = toastCount,
			Size = UDim2.fromOffset(440, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = NUIT,
			BackgroundTransparency = 0.05,
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			TextColor3 = color,
			TextWrapped = true,
			Text = text,
		}, { corner(10), padding(10) })
		item.Parent = toasts
		task.delay(4, function()
			item:Destroy()
		end)
	end

	gui.Parent = player:WaitForChild("PlayerGui")

	-- Affichage de l'état serveur
	state.onState(function(s)
		power.Text = `PUISSANCE  {Format.number(s.power)}`
		gains.Text = `+{Format.number(s.gainPerTrain)} / entraînement  ·  +{Format.number(
			s.passivePerSecond
		)}/s crew`

		local baddie = if s.active.baddieId then Catalog.baddies[s.active.baddieId] else nil
		principal.Text = `Principale : {string.upper(s.active.slotId)} · {if baddie
			then baddie.name
			else "—"}` .. ` · ×{Format.number(s.active.multiplier)} · {Format.number(
			s.active.damagePerClick
		)} dégâts/clic`

		if #s.crew == 0 then
			local left = s.tutorial.needed - s.tutorial.progress
			crewLine.Text = `Crew : entraîne-toi encore {left} fois pour débloquer ton premier DJ`
				.. ` ({s.tutorial.progress}/{s.tutorial.needed})`
		else
			local parts = {}
			for _, c in s.crew do
				table.insert(parts, `{crewLabel(c.id)} niv.{c.level} · +{Format.number(c.perSecond)}/s`)
			end
			crewLine.Text =
				`Crew : {table.concat(parts, "  |  ")}  ·  gagné {Format.number(s.stats.crewPowerEarned)}`
		end

		tickets.Text = `Tickets : {s.tickets.baddie} baddie · {s.tickets.crew} compagnon`
			.. `  ·  entraînements : {s.stats.trainActions}  ·  mode : {s.mode}`
		button.Text = `ENTRAÎNER  +{Format.number(s.gainPerTrain)}`
	end)

	-- Événements ponctuels
	state.onResult(function(event)
		if event.kind == "crewJoined" then
			local def = Catalog.crew[event.crewId]
			local name = if def then `{def.name} le {def.role}` else event.crewId
			toast(`{name} rejoint ton crew ! Il s'entraîne pour toi, même pendant les combats.`, CYAN)
		elseif event.kind == "ticket" then
			local what = if event.ticket == "baddie" then "baddie" else "compagnon"
			toast(`+{event.amount} ticket {what}`, OR)
		elseif event.kind == "passiveTick" then
			crewLine.TextColor3 = CYAN
			task.delay(0.2, function()
				crewLine.TextColor3 = CREME
			end)
		end
	end)

	-- Entrée : clic/toucher = 1 action ; maintien = 3 actions/s (option accessible du §07)
	local minInterval = 1 / Balance.training.maxActionsPerSecond
	local lastSent = 0
	local bounce = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)

	local function train()
		local now = os.clock()
		if now - lastSent < minInterval then
			return
		end
		lastSent = now
		state.send(Net.Actions.Train)
		TweenService:Create(scale, bounce, { Scale = 0.94 }):Play()
	end

	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
	end

	local holding = false
	local holdId = 0
	button.InputBegan:Connect(function(input)
		if not isPress(input) then
			return
		end
		holding = true
		holdId += 1
		local myHold = holdId
		train()
		task.delay(0.35, function()
			while holding and holdId == myHold do
				train()
				task.wait(1 / Balance.training.holdActionsPerSecond)
			end
		end)
	end)
	UserInputService.InputEnded:Connect(function(input)
		if isPress(input) then
			holding = false
		end
	end)
end

return DevHUD
