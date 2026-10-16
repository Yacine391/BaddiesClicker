--[[
	LevelsBuilder : construit les 10 arènes (5 quartiers, §09) dans un Folder « Levels ».
	Ce n'est PAS un script du jeu : `lune run assets/world/export-levels` l'exécute et écrit
	assets/world/Levels.rbxm, que Rojo synchronise dans Workspace.Levels.

	Contrat lu par le serveur (WorldService) et le client (DoorController, Combat) :
	  Levels.LevelN.Arena  Part invisible, sans collision, alignée sur les axes : son volume est l'arène N
	  Levels.LevelN.Door   porte vers le niveau N+1, fermée pour tous, ouverte LOCALEMENT au vainqueur du boss N
	Géométrie : arènes de 64 × 64 en ligne vers le nord (-Z) ; l'entrée de l'arène 1 touche le bout de la
	rue du lobby (Z = -78,5) ; sol à Y = 0,5 comme la rue. Décor sans collision, jamais dans l'aire de jeu.
	Ni ClickDetector, ni ProximityPrompt, ni faux bouton.
]]

local hex = Color3.fromHex

local ARENA = 64 -- côté d'une arène (studs)
local WALL = 2 -- épaisseur des murs
local WALL_HEIGHT = 14
local GAP = 16 -- largeur de l'entrée et de la porte
local FLOOR_TOP = 0.5 -- même hauteur que la rue du lobby
local SOUTH_EDGE = -78.5 -- bout de la rue du lobby
local INK = hex("#0D0B16")
local WHITE = hex("#FFFFFF")

-- Quartiers (§09, §20 « décor et renouvellement ») : sol, murs, néons, accessoire de décor
local DISTRICTS = {
	{
		name = "Street Block",
		floor = hex("#5B5866"),
		floorMaterial = Enum.Material.Concrete,
		wall = hex("#2A2438"),
		neon = hex("#3EE6C8"),
		accent = hex("#FF5FD2"),
		prop = "graffiti",
	},
	{
		name = "Shopping Avenue",
		floor = hex("#E8DCCB"),
		floorMaterial = Enum.Material.Marble,
		wall = hex("#4A3B5C"),
		neon = hex("#D7A746"),
		accent = hex("#F4EEE7"),
		prop = "vitrines",
	},
	{
		name = "Festival Park",
		floor = hex("#2E2547"),
		floorMaterial = Enum.Material.Grass,
		wall = hex("#24203A"),
		neon = hex("#FF5FD2"),
		accent = hex("#3EE6C8"),
		prop = "guirlandes",
	},
	{
		name = "Skyline Rooftop",
		floor = hex("#3B3F4A"),
		floorMaterial = Enum.Material.Asphalt,
		wall = hex("#1E2230"),
		neon = hex("#13A6B5"),
		accent = hex("#C0C4CC"),
		prop = "toits",
	},
	{
		name = "World Stage",
		floor = hex("#14111F"),
		floorMaterial = Enum.Material.Glass,
		wall = hex("#1B1530"),
		neon = hex("#7642A3"),
		accent = hex("#D7A746"),
		prop = "scene",
	},
}

local function P(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	-- Position passe par CFrame : seule CFrame est enregistrée dans un .rbxm (export Lune)
	for k, v in props do
		if k ~= "Position" then
			(p :: any)[k] = v
		end
	end
	if props.Position then
		p.CFrame = CFrame.new(props.Position)
	end
	p.Parent = parent
	return p
end

-- Décor : aucune collision ni requête (ne gêne ni le joueur, ni les ennemis, ni les zones de danger)
local function D(parent: Instance, props: { [string]: any }): Part
	local p = P(parent, props)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function sign(part: BasePart, face: Enum.NormalId, text: string, color: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 2
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(0.94, 0.8)
	t.Position = UDim2.fromScale(0.03, 0.1)
	t.Text = text
	t.TextScaled = true
	t.FontFace = Font.fromName("RobotoCondensed", Enum.FontWeight.Heavy)
	t.TextColor3 = color
	t.Parent = gui
	gui.Parent = part
end

local function light(part: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
end

-- Mur le long de X à la profondeur z, ouvert au centre sur GAP studs
local function wallWithGap(parent: Instance, z: number, color: Color3)
	local segment = (ARENA - GAP) / 2
	for _, side in { -1, 1 } do
		P(parent, {
			Name = "Wall",
			Size = Vector3.new(segment, WALL_HEIGHT, WALL),
			Position = Vector3.new(side * (GAP / 2 + segment / 2), FLOOR_TOP + WALL_HEIGHT / 2, z),
			Color = color,
			Material = Enum.Material.Concrete,
		})
	end
end

-- Accessoires du quartier, plaqués contre les murs est et ouest (hors de l'aire de jeu)
local function props(parent: Instance, d: any, cz: number)
	local inner = ARENA / 2 - WALL -- face intérieure des murs latéraux
	for _, side in { -1, 1 } do
		for i = -1, 1 do
			local z = cz + i * 18
			local x = side * (inner - 0.3)
			if d.prop == "graffiti" then
				D(parent, {
					Name = "Graffiti",
					Size = Vector3.new(0.2, 6, 10),
					Position = Vector3.new(x, FLOOR_TOP + 5, z),
					Color = if (i + side) % 2 == 0 then d.neon else d.accent,
					Material = Enum.Material.Neon,
					Transparency = 0.55,
				})
			elseif d.prop == "vitrines" then
				local glass = D(parent, {
					Name = "Vitrine",
					Size = Vector3.new(0.3, 7, 11),
					Position = Vector3.new(x, FLOOR_TOP + 4.5, z),
					Color = hex("#BFD8E8"),
					Material = Enum.Material.Glass,
					Transparency = 0.35,
				})
				light(glass, d.neon, 14, 1.2)
				D(parent, {
					Name = "Store",
					Size = Vector3.new(0.4, 1.2, 12),
					Position = Vector3.new(x, FLOOR_TOP + 8.6, z),
					Color = d.accent,
				})
			elseif d.prop == "guirlandes" then
				for k = 0, 4 do
					local bulb = D(parent, {
						Name = "Bulb",
						Shape = Enum.PartType.Ball,
						Size = Vector3.new(0.8, 0.8, 0.8),
						Position = Vector3.new(
							x,
							FLOOR_TOP + WALL_HEIGHT - 1.5 - (k % 2) * 0.8,
							z - 8 + k * 4
						),
						Color = if k % 2 == 0 then d.neon else d.accent,
						Material = Enum.Material.Neon,
					})
					if k == 2 then
						light(bulb, d.neon, 16, 1)
					end
				end
			elseif d.prop == "toits" then
				D(parent, {
					Name = "Clim",
					Size = Vector3.new(3, 2.4, 4),
					Position = Vector3.new(side * (inner - 1.6), FLOOR_TOP + 1.2, z),
					Color = d.accent,
					Material = Enum.Material.Metal,
				})
			elseif d.prop == "scene" then
				local beam = D(parent, {
					Name = "Projecteur",
					Size = Vector3.new(0.6, WALL_HEIGHT - 2, 0.6),
					Position = Vector3.new(x, FLOOR_TOP + (WALL_HEIGHT - 2) / 2, z),
					Color = if i == 0 then d.accent else d.neon,
					Material = Enum.Material.Neon,
				})
				light(beam, beam.Color, 18, 1.4)
			end
		end
	end
end

local function level(levels: Instance, levelId: number, total: number, districtName: string, d: any)
	local cz = SOUTH_EDGE - ARENA / 2 - (levelId - 1) * ARENA
	local folder = Instance.new("Folder")
	folder.Name = `Level{levelId}`

	P(folder, {
		Name = "Floor",
		Size = Vector3.new(ARENA, 1, ARENA),
		Position = Vector3.new(0, FLOOR_TOP - 0.5, cz),
		Color = d.floor,
		Material = d.floorMaterial,
	})
	-- Zone de combat lue par le serveur : invisible, sans collision, alignée sur les axes
	P(folder, {
		Name = "Arena",
		Size = Vector3.new(ARENA - 2 * WALL, 24, ARENA - 2 * WALL),
		Position = Vector3.new(0, FLOOR_TOP + 12, cz),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})

	-- Murs ouest et est, liseré néon au sommet
	for _, side in { -1, 1 } do
		P(folder, {
			Name = "Wall",
			Size = Vector3.new(WALL, WALL_HEIGHT, ARENA),
			Position = Vector3.new(side * (ARENA / 2 - WALL / 2), FLOOR_TOP + WALL_HEIGHT / 2, cz),
			Color = d.wall,
			Material = Enum.Material.Concrete,
		})
		D(folder, {
			Name = "Neon",
			Size = Vector3.new(WALL + 0.2, 0.4, ARENA),
			Position = Vector3.new(side * (ARENA / 2 - WALL / 2), FLOOR_TOP + WALL_HEIGHT + 0.2, cz),
			Color = d.neon,
			Material = Enum.Material.Neon,
		})
	end

	-- Entrée : mur sud seulement pour l'arène 1 (les suivantes partagent le mur nord précédent)
	local southZ = cz + ARENA / 2 - WALL / 2
	if levelId == 1 then
		wallWithGap(folder, southZ, d.wall)
	end
	-- Fronton d'entrée lisible depuis le sud
	local banner = D(folder, {
		Name = "Banner",
		Size = Vector3.new(GAP + 8, 3.4, 1),
		Position = Vector3.new(0, FLOOR_TOP + WALL_HEIGHT + 2.2, southZ),
		Color = INK,
	})
	sign(banner, Enum.NormalId.Back, `NIVEAU {levelId} · {string.upper(districtName)}`, d.accent)
	D(folder, {
		Name = "BannerNeon",
		Size = Vector3.new(GAP + 8, 0.3, 1.1),
		Position = Vector3.new(0, FLOOR_TOP + WALL_HEIGHT + 0.35, southZ),
		Color = d.neon,
		Material = Enum.Material.Neon,
	})

	-- Mur nord et porte vers le niveau suivant (fermée ; DoorController l'ouvre au vainqueur du boss)
	local northZ = cz - ARENA / 2 + WALL / 2
	wallWithGap(folder, northZ, d.wall)
	local door = P(folder, {
		Name = "Door",
		Size = Vector3.new(GAP, WALL_HEIGHT, WALL),
		Position = Vector3.new(0, FLOOR_TOP + WALL_HEIGHT / 2, northZ),
		Color = hex("#7642A3"),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
	})
	local doorText = if levelId < total then `NIVEAU {levelId + 1} · BATS LE BOSS` else "FIN DU PARCOURS"
	sign(door, Enum.NormalId.Back, doorText, WHITE)

	-- Piliers d'angle éclairés
	for _, x in { -1, 1 } do
		for _, zSide in { -1, 1 } do
			local pillar = D(folder, {
				Name = "Pillar",
				Size = Vector3.new(1.2, WALL_HEIGHT + 3, 1.2),
				Position = Vector3.new(
					x * (ARENA / 2 - WALL - 0.6),
					FLOOR_TOP + (WALL_HEIGHT + 3) / 2,
					cz + zSide * (ARENA / 2 - WALL - 0.6)
				),
				Color = d.neon,
				Material = Enum.Material.Neon,
				Transparency = 0.2,
			})
			light(pillar, d.neon, 22, 1.1)
		end
	end

	props(folder, d, cz)
	folder.Parent = levels
end

-- levelsConfig : Balance.levels (district et boss par niveau)
return function(levels: Folder, levelsConfig: { any })
	levels:ClearAllChildren()
	local byName = {}
	for _, d in DISTRICTS do
		byName[d.name] = d
	end
	for levelId, cfg in levelsConfig do
		local d = byName[cfg.district] or DISTRICTS[1]
		level(levels, levelId, #levelsConfig, cfg.district, d)
	end
end
