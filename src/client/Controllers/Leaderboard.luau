--[[
	Leaderboard : écran « CLASSEMENT » du lobby (Workspace.Lobby.Ranking.Screen, §15).
	Rendu local (SurfaceGui côté client) du classement calculé par le serveur (snapshot.ranking) ;
	alterne BADDIES et CREW toutes les 8 s ; le joueur local est surligné. Le panneau « prototype »
	posé par LobbyBuilder est masqué localement.
]]

local Players = game:GetService("Players")

local Client = script.Parent.Parent
local Theme = require(Client.UI.Theme)
local RankingModel = require(Client.Logic.RankingModel)

local Leaderboard = {}

local LINES = 5
local SWITCH_SECONDS = 8

local function textLabel(parent: Instance, name: string, props: { [string]: any }): TextLabel
	local t = Instance.new("TextLabel")
	t.Name = name
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.FontFace = Theme.Fonts.Heavy
	t.TextColor3 = Theme.Colors.Text
	for k, v in props do
		(t :: any)[k] = v
	end
	t.Parent = parent
	return t
end

local function build(screen: BasePart): (Frame, TextLabel, TextLabel, {
	{
		rank: TextLabel,
		name: TextLabel,
		score: TextLabel,
		bar: Frame,
	}
})
	for _, child in screen:GetChildren() do
		if child:IsA("SurfaceGui") then
			child.Enabled = false -- panneau « prototype » du lobby
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LiveRanking"
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = screen

	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = gui
	local title = textLabel(root, "Title", {
		Position = UDim2.fromScale(0.04, 0.03),
		Size = UDim2.fromScale(0.92, 0.16),
		TextColor3 = Theme.Colors.Accent,
	})
	local subtitle = textLabel(root, "Subtitle", {
		Position = UDim2.fromScale(0.04, 0.19),
		Size = UDim2.fromScale(0.92, 0.08),
		FontFace = Theme.Fonts.Bold,
		TextColor3 = Theme.Colors.TextDim,
	})
	local rows = {}
	for i = 1, LINES do
		local y = 0.3 + (i - 1) * 0.136
		local bar = Instance.new("Frame")
		bar.Name = "Line" .. i
		bar.BackgroundColor3 = Theme.Colors.Accent
		bar.BackgroundTransparency = 1
		bar.BorderSizePixel = 0
		bar.Position = UDim2.fromScale(0.03, y)
		bar.Size = UDim2.fromScale(0.94, 0.12)
		bar.Parent = root
		rows[i] = {
			bar = bar,
			rank = textLabel(bar, "Rank", {
				Position = UDim2.fromScale(0.01, 0.1),
				Size = UDim2.fromScale(0.14, 0.8),
				TextColor3 = Theme.Colors.Slots,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			name = textLabel(bar, "Name", {
				Position = UDim2.fromScale(0.16, 0.1),
				Size = UDim2.fromScale(0.6, 0.8),
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			score = textLabel(bar, "Score", {
				Position = UDim2.fromScale(0.78, 0.1),
				Size = UDim2.fromScale(0.21, 0.8),
				TextColor3 = Theme.Colors.Accent,
				TextXAlignment = Enum.TextXAlignment.Right,
			}),
		}
	end
	return root, title, subtitle, rows
end

function Leaderboard.start(scope: any, deps: any)
	-- Le lobby peut arriver après le client (streaming) : on attend sans bloquer les autres contrôleurs
	task.spawn(Leaderboard.mount, scope, deps)
end

function Leaderboard.mount(scope: any, deps: any)
	local lobby = workspace:WaitForChild("Lobby", 30)
	local ranking = lobby and lobby:WaitForChild("Ranking", 10)
	local screen = ranking and ranking:WaitForChild("Screen", 10)
	if screen == nil or not screen:IsA("BasePart") then
		warn("[Leaderboard] Lobby.Ranking.Screen introuvable : pas de tableau")
		return
	end
	local _, title, subtitle, rows = build(screen)
	local tab = "baddies"
	local me = Players.LocalPlayer.UserId

	local function render()
		local snapshot = deps.peek(deps.Store.snapshot)
		local board = RankingModel.board(snapshot and snapshot.ranking, tab, LINES, me)
		title.Text = board.title
		subtitle.Text = board.empty or board.subtitle
		for i, row in rows do
			local line = board.lines[i]
			row.bar.Visible = line ~= nil
			if line then
				row.rank.Text = line.rank
				row.name.Text = line.name
				row.score.Text = line.score
				row.bar.BackgroundTransparency = if line.isMe then 0.82 else 1
				row.name.TextColor3 = if line.isMe then Theme.Colors.Accent else Theme.Colors.Text
			end
		end
	end

	scope:Observer(deps.Store.snapshot):onChange(render)
	render()
	task.spawn(function()
		while screen.Parent ~= nil do
			task.wait(SWITCH_SECONDS)
			tab = if tab == "baddies" then "crew" else "baddies"
			render()
		end
	end)
end

return Leaderboard
