--!strict
--[[
	Visuals : accès aux modèles de ReplicatedStorage.Visuals.Characters (suiveurs, podium, boss, portraits).
	Les chemins viennent de Logic/VisualsModel. Un modèle absent renvoie nil : l'appelant affiche son repli.
	Rendu local uniquement : aucune collision, aucune requête, pas de Humanoid.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent
local VisualsModel = require(Client.Logic.VisualsModel)
local Catalog = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Catalog"))

local Visuals = {}

local IDLE_ANIM = "rbxassetid://507766666" -- animations R15 de Roblox (le rig du kit reprend les noms R15)
local WALK_ANIM = "rbxassetid://507777826"

local function characters(): Instance?
	local visuals = ReplicatedStorage:FindFirstChild("Visuals")
	return visuals and visuals:FindFirstChild("Characters")
end

local function resolve(path: VisualsModel.Path?): Model?
	local root = characters()
	if root == nil or path == nil then
		return nil
	end
	local folder = root:FindFirstChild(path.folder)
	local model = folder and (folder:FindFirstChild(path.model) or folder:FindFirstChild("Look01"))
	return if model ~= nil and model:IsA("Model") then model else nil
end

-- Modèle source (à cloner) d'une baddie (look 1 à 3) ou d'un compagnon
function Visuals.source(id: string, look: number?): Model?
	return resolve(VisualsModel.path(Catalog, id, look))
end

function Visuals.minionSource(levelId: number?): Model?
	return resolve(VisualsModel.minion(levelId))
end

local function soften(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

function Visuals.clone(id: string, look: number?): Model?
	local source = Visuals.source(id, look)
	if source == nil then
		return nil
	end
	local model = source:Clone()
	soften(model)
	return model
end

function Visuals.cloneMinion(levelId: number?): Model?
	local source = Visuals.minionSource(levelId)
	if source == nil then
		return nil
	end
	local model = source:Clone()
	soften(model)
	return model
end

export type Tracks = { idle: AnimationTrack?, walk: AnimationTrack? }

-- Charge idle et marche sur l'Animator du modèle (nil si le modèle n'en a pas) ; joue l'idle
function Visuals.animate(model: Model): Tracks
	local controller = model:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	if animator == nil then
		return {}
	end
	local idle = Instance.new("Animation")
	idle.AnimationId = IDLE_ANIM
	local walk = Instance.new("Animation")
	walk.AnimationId = WALK_ANIM
	local tracks: Tracks = {}
	local ok = pcall(function()
		tracks.idle = animator:LoadAnimation(idle)
		tracks.walk = animator:LoadAnimation(walk)
	end)
	if ok and tracks.idle then
		tracks.idle:Play()
	end
	return tracks
end

-- Bascule idle / marche avec un fondu
function Visuals.setMoving(tracks: Tracks, moving: boolean)
	local idle, walk = tracks.idle, tracks.walk
	if idle == nil or walk == nil then
		return
	end
	if moving and not walk.IsPlaying then
		walk:Play(0.2)
	elseif not moving and walk.IsPlaying then
		walk:Stop(0.2)
	end
	if not moving and not idle.IsPlaying then
		idle:Play(0.2)
	elseif moving and idle.IsPlaying then
		idle:Stop(0.2)
	end
end

return Visuals
