--[[
	DevWorld : carte grise de TEST (lot P1), construite au lancement DANS STUDIO si Workspace.Levels
	n'existe pas. Dix arènes en ligne vers le nord (-Z), reliées par des portes.
	Si le lobby du codeur B (Workspace.Lobby) est présent, l'arène 1 commence juste au nord de lui
	et la barrière « lot P1 » de sa rue est ouverte (en test uniquement, son fichier n'est pas modifié).

	Contrat pour la vraie carte du codeur B (mêmes noms, mêmes rôles) :
	  Workspace.Levels.LevelN.Arena  zone de combat : Part invisible, alignée sur les axes,
	                                 sans collision ; son volume délimite l'arène du niveau N
	  Workspace.Levels.LevelN.Door   porte vers le niveau N+1 : ouverte localement pour le joueur
	                                 qui a vaincu le boss N (Controllers/DoorController)
	L'entrée d'une arène est au sud (+Z), les ennemis apparaissent au nord (-Z).
]]

local ARENA = 64 -- côté d'une arène (studs)
local WALL_HEIGHT = 14
local WALL = 2 -- épaisseur
local GAP = 16 -- largeur de l'entrée et de la porte
local DEFAULT_SOUTH_EDGE = -58 -- sans lobby : entrée de l'arène 1 à 58 studs du spawn du Baseplate

local FLOOR_COLORS = {
	Color3.fromRGB(110, 112, 120),
	Color3.fromRGB(96, 98, 108),
}

local DevWorld = {}

local function part(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function wall(parent: Instance, center: Vector3, size: Vector3)
	part(parent, {
		Name = "Wall",
		Size = size,
		Position = center,
		Color = Color3.fromRGB(70, 66, 84),
		Material = Enum.Material.Concrete,
	})
end

local function label(parent: BasePart, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(260, 50)
	gui.StudsOffset = Vector3.new(0, 10, 0)
	gui.MaxDistance = 140
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.4
	t.Text = text
	t.Parent = gui
	gui.Parent = parent
end

-- Mur horizontal (axe X) à la profondeur z, avec une ouverture centrale de largeur GAP
local function wallWithGap(parent: Instance, z: number): ()
	local segment = (ARENA - GAP) / 2
	wall(
		parent,
		Vector3.new(-(GAP / 2 + segment / 2), WALL_HEIGHT / 2, z),
		Vector3.new(segment, WALL_HEIGHT, WALL)
	)
	wall(
		parent,
		Vector3.new(GAP / 2 + segment / 2, WALL_HEIGHT / 2, z),
		Vector3.new(segment, WALL_HEIGHT, WALL)
	)
end

-- Bord nord du lobby du codeur B (Workspace.Lobby), s'il existe
local function lobbyNorthEdge(): number?
	local lobby = workspace:FindFirstChild("Lobby")
	if lobby ~= nil and lobby:IsA("Model") then
		local cframe, size = lobby:GetBoundingBox()
		return cframe.Position.Z - size.Z / 2
	end
	return nil
end

-- La rue du lobby se termine par une barrière « lot P1 » : on l'ouvre pour tester (Studio uniquement)
local function openLobbyBarrier()
	local lobby = workspace:FindFirstChild("Lobby")
	local street = if lobby then lobby:FindFirstChild("Street") else nil
	local barrier = if street then street:FindFirstChild("Barrier") else nil
	if barrier ~= nil and barrier:IsA("BasePart") then
		barrier.CanCollide = false
		barrier.Transparency = 1
		for _, child in barrier:GetDescendants() do
			if child:IsA("SurfaceGui") then
				child.Enabled = false
			end
		end
		print("[BaddieClicker] barrière de la rue du lobby ouverte pour le test du P1")
	end
end

function DevWorld.build(ctx: any): Folder
	local levels = Instance.new("Folder")
	levels.Name = "Levels"

	local southEdge = lobbyNorthEdge() or DEFAULT_SOUTH_EDGE
	local FIRST_Z = southEdge - ARENA / 2
	openLobbyBarrier()

	-- Passerelle entre la sortie (lobby ou spawn) et l'entrée de l'arène 1
	local bridge = Instance.new("Folder")
	bridge.Name = "Approach"
	part(bridge, {
		Name = "Bridge",
		Size = Vector3.new(GAP + 4, 1, 10),
		Position = Vector3.new(0, -0.45, southEdge + 5),
		Color = Color3.fromRGB(110, 112, 120),
		Material = Enum.Material.Concrete,
	})
	bridge.Parent = levels

	for levelId, level in ctx.Balance.levels do
		local cz = FIRST_Z - (levelId - 1) * ARENA
		local folder = Instance.new("Folder")
		folder.Name = `Level{levelId}`

		part(folder, {
			Name = "Floor",
			Size = Vector3.new(ARENA, 1, ARENA),
			Position = Vector3.new(0, -0.45, cz),
			Color = FLOOR_COLORS[(levelId - 1) % 2 + 1],
			Material = Enum.Material.Concrete,
		})

		part(folder, {
			Name = "Arena",
			Size = Vector3.new(ARENA - 2 * WALL, 24, ARENA - 2 * WALL),
			Position = Vector3.new(0, 12, cz),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})

		-- Murs ouest et est
		wall(
			folder,
			Vector3.new(-ARENA / 2 + WALL / 2, WALL_HEIGHT / 2, cz),
			Vector3.new(WALL, WALL_HEIGHT, ARENA)
		)
		wall(
			folder,
			Vector3.new(ARENA / 2 - WALL / 2, WALL_HEIGHT / 2, cz),
			Vector3.new(WALL, WALL_HEIGHT, ARENA)
		)

		-- Mur sud : seulement pour l'arène 1 (entrée). Les suivantes partagent le mur nord précédent.
		if levelId == 1 then
			wallWithGap(folder, cz + ARENA / 2 - WALL / 2)
		end

		-- Mur nord + porte vers le niveau suivant
		local northZ = cz - ARENA / 2 + WALL / 2
		wallWithGap(folder, northZ)
		local door = part(folder, {
			Name = "Door",
			Size = Vector3.new(GAP, WALL_HEIGHT, WALL),
			Position = Vector3.new(0, WALL_HEIGHT / 2, northZ),
			Color = Color3.fromHex("#7642A3"),
			Material = Enum.Material.Neon,
			Transparency = 0.3,
		})
		local nextText = if levelId < #ctx.Balance.levels
			then `NIVEAU {levelId + 1} · bats le boss pour ouvrir`
			else "FIN DU PARCOURS"
		label(door, nextText, Color3.fromHex("#F4EEE7"))

		-- Panneau d'entrée du niveau
		local sign = part(folder, {
			Name = "Sign",
			Size = Vector3.new(1, 1, 1),
			Position = Vector3.new(0, 1, cz + ARENA / 2 - 4),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
		label(sign, `NIVEAU {levelId} · {level.district}`, Color3.fromHex("#D7A746"))

		folder.Parent = levels
	end

	levels.Parent = workspace
	return levels
end

return DevWorld
