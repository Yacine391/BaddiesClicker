--[[
	Titles : titre choisi affiché au-dessus de l'avatar de chaque joueur (§19).
	Le serveur publie l'attribut BC_Title (ID de titre débloqué et porté, ou "") ; le nom vient de
	Shared/Wardrobe. Rendu local (BillboardGui sur la tête), réduit avec la distance, rien si vide.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local RankingModel = require(Client.Logic.RankingModel)
local StyleModel = require(Client.Logic.StyleModel)
local Wardrobe = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Wardrobe"))

local Titles = {}

local MAX_DISTANCE = 80
local FRAME_COLORS: { [string]: Color3 } = {
	frame_simple = Color3.fromHex("#FFFFFF"),
	frame_crew = Color3.fromHex("#B48CF0"),
	frame_v1 = Color3.fromHex("#D7A746"),
}

local function apply(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head == nil or not head:IsA("BasePart") then
		return
	end
	local text = RankingModel.titleText(player:GetAttribute("BC_Title"), Wardrobe)
	local frame = StyleModel.parsePublic(player:GetAttribute("BC_Style"), Wardrobe).frame
	local gui = head:FindFirstChild("BC_Title")
	if text == nil then
		if gui then
			gui:Destroy()
		end
		return
	end
	if gui == nil then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "BC_Title"
		billboard.Size = UDim2.fromOffset(220, 30)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		billboard.MaxDistance = MAX_DISTANCE
		billboard.LightInfluence = 0
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.TextScaled = true
		label.FontFace = Theme.Fonts.Heavy
		label.TextColor3 = Theme.Colors.Slots
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.Colors.Ink
		stroke.Thickness = Theme.Stroke.Text
		stroke.Parent = label
		label.Parent = billboard
		-- cadre de profil (cosmétique « cadre ») : liseré autour du titre
		local border = Instance.new("Frame")
		border.Name = "ProfileFrame"
		border.BackgroundColor3 = Theme.Colors.Ink
		border.BackgroundTransparency = 0.45
		border.Size = UDim2.fromScale(1, 1)
		border.ZIndex = 0
		border.Visible = false
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = border
		local outline = Instance.new("UIStroke")
		outline.Name = "Outline"
		outline.Thickness = 2
		outline.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		outline.Parent = border
		border.Parent = billboard
		billboard.Adornee = head
		billboard.Parent = head
		gui = billboard
	end
	(gui :: any).Text.Text = text
	local border = (gui :: any):FindFirstChild("ProfileFrame")
	if border ~= nil then
		border.Visible = frame ~= nil
		border.Outline.Color = FRAME_COLORS[frame or ""] or Theme.Colors.Text
	end
end

local function watch(scope: any, player: Player)
	table.insert(
		scope,
		player:GetAttributeChangedSignal("BC_Title"):Connect(function()
			apply(player)
		end)
	)
	table.insert(
		scope,
		player:GetAttributeChangedSignal("BC_Style"):Connect(function()
			apply(player)
		end)
	)
	table.insert(
		scope,
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("Head", 10)
			apply(player)
		end)
	)
	apply(player)
end

function Titles.start(scope: any, _deps: any)
	for _, player in Players:GetPlayers() do
		watch(scope, player)
	end
	table.insert(
		scope,
		Players.PlayerAdded:Connect(function(player)
			watch(scope, player)
		end)
	)
end

return Titles
