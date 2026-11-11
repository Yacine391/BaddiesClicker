--!strict
--[[
	Portrait : rendu 3D d'un personnage dans un ViewportFrame (Book, cartes du HUD, Style, Crew).
	Le modèle vient de ReplicatedStorage.Visuals.Characters (Controllers/Visuals) : aucun asset à uploader.
	- Mode "bust" : cadrage tête et épaules ; "full" : en pied.
	- Locked : silhouette noire (identité non découverte, §15), sans révéler la tenue.
	- Modèle absent : rien n'est affiché, le parent garde son fond (repli sobre, jamais d'erreur).
	Un ViewportFrame n'est redessiné que si son contenu change : coût nul au repos (§28).
]]

local Client = script.Parent.Parent.Parent
local Visuals = require(Client.Controllers.Visuals)
local peek = require(Client.Packages.Fusion).peek

export type Subject = { id: string, look: number? }

export type Props = {
	Subject: any, -- Subject?, ou état Fusion de Subject?
	Mode: ("bust" | "full")?,
	Locked: any?, -- boolean ou état
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	LayoutOrder: number?,
	Name: string?,
	Turn: number?, -- angle de présentation en degrés (0 = de face)
}

local FOV = 30

local function frameCamera(camera: Camera, model: Model, mode: string, turn: number)
	-- Le rig du kit : racine à 3 studs au-dessus des pieds, 5,3 studs de haut, regard vers -Z
	local scale = model:GetScale()
	local target: Vector3
	local distance: number
	if mode == "full" then
		target = Vector3.new(0, 2.9 * scale, 0)
		distance = 12.4 * scale
	else
		target = Vector3.new(0, 4.62 * scale, 0)
		distance = 4.4 * scale
	end
	local a = math.rad(turn)
	local direction = Vector3.new(math.sin(a), 0.05, -math.cos(a)).Unit
	camera.FieldOfView = FOV
	camera.CFrame = CFrame.lookAt(target + direction * distance, target)
end

return function(scope: any, props: Props): ViewportFrame
	local mode = props.Mode or "bust"
	local turn = props.Turn or (if mode == "full" then 16 else 20)
	local viewport: ViewportFrame = scope:New("ViewportFrame")({
		Name = props.Name or "Portrait",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
		Ambient = Color3.fromHex("#B9B2C9"),
		LightColor = Color3.fromHex("#FFF4EA"),
		LightDirection = Vector3.new(0.5, -1, 0.9),
	})
	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local subject = scope:Computed(function(use)
		return use(props.Subject)
	end)
	local locked = scope:Computed(function(use)
		return use(props.Locked) == true
	end)
	local shownKey = ""

	local function render()
		local s: Subject? = peek(subject)
		local key = if s then `{s.id}:{s.look or 1}` else ""
		viewport.ImageColor3 = if peek(locked) then Color3.new(0, 0, 0) else Color3.new(1, 1, 1)
		viewport.ImageTransparency = if peek(locked) then 0.25 else 0
		if key == shownKey then
			return
		end
		shownKey = key
		for _, child in viewport:GetChildren() do
			if child:IsA("Model") then
				child:Destroy()
			end
		end
		if s == nil then
			return
		end
		local model = Visuals.clone(s.id, s.look)
		if model == nil then
			return
		end
		model:PivotTo(CFrame.new(0, 3, 0))
		model.Parent = viewport
		frameCamera(camera, model, mode, turn)
	end
	render()
	scope:Observer(subject):onChange(render)
	scope:Observer(locked):onChange(render)
	return viewport
end
