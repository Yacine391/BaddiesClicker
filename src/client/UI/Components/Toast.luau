--!strict
--[[
	Toast : message court en haut de l'écran (+1 copie, ticket…), visible 2 s.
	Panneau mix A au contour Accent. Les toasts simultanés s'empilent (58 px par toast visible)
	et remontent quand le premier part. Chaque toast a son propre scope Fusion, nettoyé à la fin.
]]

local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent.Parent
local Fusion = require(Client.Packages.Fusion)
local UI = script.Parent.Parent
local Theme = require(UI.Theme)
local Text = require(UI.Text)
local Panel = require(script.Parent.Panel)
local Icon = require(script.Parent.Icon)

local Toast = {}

local SHOW_SECONDS = 2
local TOP = 96
local STEP = 58
local HIDDEN = UDim2.new(0.5, 0, 0, -60)

local MAX_VISIBLE = 4
local active: { Frame } = {}

local function slotPosition(index: number): UDim2
	return UDim2.new(0.5, 0, 0, TOP + (index - 1) * STEP)
end

local function relayout()
	local slide = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	for i, frame in active do
		TweenService:Create(frame, slide, { Position = slotPosition(i) }):Play()
	end
end

function Toast.show(parent: Instance, text: string, icon: string?)
	local scope = Fusion.scoped(Fusion)
	local children: { any } = {
		Text.label(scope, {
			Text = text,
			Weight = "ExtraBold",
			Size = UDim2.new(1, if icon then -66 else -24, 0, 26),
			Position = UDim2.new(0, if icon then 54 else 12, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			XAlignment = if icon then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center,
			ZIndex = 31,
		}),
	}
	if icon then
		table.insert(
			children,
			Icon(scope, {
				Name = icon,
				Color = Theme.Colors.Accent,
				Size = UDim2.fromOffset(30, 30),
				Position = UDim2.new(0, 14, 0.5, 0),
				AnchorPoint = Vector2.new(0, 0.5),
				ZIndex = 31,
			})
		)
	end
	local frame = Panel(scope, {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = HIDDEN,
		Size = UDim2.fromOffset(420, 50),
		Line = Theme.Colors.Accent,
		ZIndex = 30,
		Children = children,
	})
	frame.Parent = parent
	table.insert(active, frame)
	-- Le plus ancien part tout de suite (son départ normal ne trouvera plus sa place dans la liste)
	while #active > MAX_VISIBLE do
		local oldest = table.remove(active, 1) :: Frame
		oldest.Visible = false
	end
	relayout()

	task.delay(SHOW_SECONDS, function()
		local index = table.find(active, frame)
		if index then
			table.remove(active, index)
		end
		relayout()
		local out = TweenService:Create(frame, TweenInfo.new(0.25), { Position = HIDDEN })
		out:Play()
		out.Completed:Wait()
		frame:Destroy()
		Fusion.doCleanup(scope)
	end)
end

return Toast
