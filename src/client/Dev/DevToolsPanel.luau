--[[
	DevToolsPanel : outils de TEST, Studio uniquement (touche F4 pour l'afficher / le masquer).
	Les écrans de jeu (slots, drops, renaissance, crew, classement, style) sont dans le vrai HUD ;
	il ne reste ici que les raccourcis serveur DevGrant / DevSetMastery (refusés hors Studio).
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local DevToolsPanel = {}

local NUIT = Color3.fromHex("#242036")
local CREME = Color3.fromHex("#F4EEE7")

function DevToolsPanel.start(state)
	local snapshot: { [string]: any }? = nil
	state.onState(function(s)
		snapshot = s
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "DevToolsPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0, 1)
	panel.Position = UDim2.new(0, 12, 1, -150)
	panel.Size = UDim2.fromOffset(200, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = NUIT
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
	pad.Parent = panel
	panel.Parent = gui

	local order = 0
	local function button(text: string, onClick: () -> ())
		order += 1
		local b = Instance.new("TextButton")
		b.LayoutOrder = order
		b.Size = UDim2.new(1, 0, 0, 30)
		b.BackgroundColor3 = Color3.fromHex("#3A3355")
		b.TextColor3 = CREME
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.Text = text
		b.Activated:Connect(onClick)
		b.Parent = panel
	end
	local function grant(what: string, extra: { [string]: any }?)
		local payload: { [string]: any } = if extra then table.clone(extra) else {}
		payload.what = what
		state.send(Net.Actions.DevGrant, payload)
	end

	button("OUTILS STUDIO (F4)", function() end)
	button("+10 TICKETS", function()
		grant("tickets")
	end)
	button("+5 TICKETS CREW", function()
		grant("crewTickets")
	end)
	button("+5 000 PUISSANCE", function()
		grant("power")
	end)
	button("DROP VEGA", function()
		grant("drop", { baddieId = "vega" })
	end)
	button("FINIR LE PARCOURS", function()
		grant("finishRun")
	end)
	button("MAÎTRISE 5 (principale)", function()
		local active = snapshot and snapshot.active
		if active and active.baddieId then
			state.send(Net.Actions.DevSetMastery, { baddieId = active.baddieId, xp = 250 })
		end
	end)
	button("TÉLÉPORT ×1 (en combat, §25)", function()
		grant("teleport", { times = 1 })
	end)
	button("TÉLÉPORT ×3 (combat annulé)", function()
		grant("teleport", { times = 3 })
	end)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	ContextActionService:BindAction("BC_DevTools", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			panel.Visible = not panel.Visible
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F4)
end

return DevToolsPanel
