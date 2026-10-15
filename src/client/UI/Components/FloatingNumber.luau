--!strict
--[[
	FloatingNumber : « +1 » / « +0,6 » qui monte de 80 px et disparaît en 0,9 s, puis se détruit.
	Instances simples (pas de scope Fusion) : l'objet vit moins d'une seconde.
]]

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)

local FloatingNumber = {}

local DURATION = 0.9

function FloatingNumber.spawn(parent: Instance, text: string, position: UDim2, color: Color3?)
	local label = Instance.new("TextLabel")
	label.Name = "FloatingNumber"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(120, 48)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = position
	label.Text = text
	label.TextScaled = true
	label.FontFace = Theme.Fonts.Display
	label.TextColor3 = color or Theme.Colors.Blanc
	label.Rotation = math.random(-8, 8)
	label.ZIndex = 20

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Colors.Contour
	stroke.Thickness = Theme.Stroke.Text
	stroke.Parent = label
	label.Parent = parent

	local info = TweenInfo.new(DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(label, info, {
		Position = position - UDim2.fromOffset(0, 80),
		TextTransparency = 1,
	}):Play()
	TweenService:Create(stroke, info, { Transparency = 1 }):Play()
	task.delay(DURATION, function()
		label:Destroy()
	end)
end

return FloatingNumber
