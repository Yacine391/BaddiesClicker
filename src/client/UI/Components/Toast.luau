--!strict
--[[
	Toast : message court en haut de l'écran (nouveau compagnon, ticket…), visible 2 s.
	Instances simples, détruites à la fin.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)

local Toast = {}

local SHOW_SECONDS = 2

function Toast.show(parent: Instance, text: string)
	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, -60)
	frame.Size = UDim2.fromOffset(420, 52)
	frame.BackgroundColor3 = Theme.Colors.Violet
	frame.ZIndex = 30

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Contour
	stroke.Thickness = Theme.Stroke.Frame
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -24, 1, -12)
	label.Position = UDim2.fromOffset(12, 6)
	label.Text = text
	label.TextScaled = true
	label.FontFace = Theme.Fonts.Body
	label.TextColor3 = Theme.Colors.Blanc
	label.ZIndex = 31
	local textStroke = Instance.new("UIStroke")
	textStroke.Color = Theme.Colors.Contour
	textStroke.Thickness = Theme.Stroke.Text
	textStroke.Parent = label
	label.Parent = frame
	frame.Parent = parent

	local slide = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(frame, slide, { Position = UDim2.new(0.5, 0, 0, 96) }):Play()
	task.delay(SHOW_SECONDS, function()
		local out = TweenService:Create(frame, TweenInfo.new(0.25), { Position = UDim2.new(0.5, 0, 0, -60) })
		out:Play()
		out.Completed:Wait()
		frame:Destroy()
	end)
end

return Toast
