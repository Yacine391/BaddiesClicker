--[[
	LobbyBuilder : construit le lobby mix A (spec refonte §7) dans un Model donné, en Studio (Edit).
	Ce n'est PAS un script du jeu : il sert à reconstruire le lobby avant de l'exporter vers
	assets/world/Lobby.rbxm (Rojo ne synchronise que ce .rbxm).

	Utilisation (barre de commande Studio ou MCP, en Edit) :
		local build = loadstring(<contenu de ce fichier>)()
		build(workspace.Lobby)   -- vide le Model puis le reconstruit

	Contraintes :
	- Empreinte inchangée : sol 90 × 70 centré sur l'origine, arche à Z = -35,5, bout de rue à Z = -78,5.
	  Le DevWorld du codeur A place le niveau 1 juste au nord de la boîte englobante du lobby :
	  aucun décor ne doit dépasser Z = -78,5 vers le nord.
	- Noms utilisés par le code : Lobby.Spawn (SpawnLocation), Lobby.Podium.Stand (cylindre à (28, 2, -4)).
	- Ni ClickDetector, ni ProximityPrompt, ni barrière. Décor lointain sans collision.
]]

local hex = Color3.fromHex
local CYAN, VIOLET, PINK, GOLD = hex("#3EE6C8"), hex("#7642A3"), hex("#FF5FD2"), hex("#D7A746")
local DARK, METAL, WHITE, DIM = hex("#14111F"), hex("#C0C4CC"), hex("#FFFFFF"), hex("#CFCAE6")
local FLAT = CFrame.Angles(0, 0, math.rad(90)) -- cylindre couché (axe vertical)

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

-- Décor lointain : aucune collision ni requête
local function far(parent: Instance, props: { [string]: any }): Part
	local p = P(parent, props)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function group(parent: Instance, className: string, name: string): Instance
	local g = Instance.new(className)
	g.Name = name
	g.Parent = parent
	return g
end

type Line = { text: string, color: Color3, h: number, weight: Enum.FontWeight? }
local function sign(part: BasePart, face: Enum.NormalId, lines: { Line }, pps: number?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pps or 40
	gui.LightInfluence = 0
	gui.Brightness = 2
	gui.Parent = part
	local list = Instance.new("UIListLayout")
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.Padding = UDim.new(0.02, 0)
	list.Parent = gui
	for _, l in lines do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.92, l.h)
		t.Text = l.text
		t.TextScaled = true
		t.FontFace = Font.fromName("RobotoCondensed", l.weight or Enum.FontWeight.Heavy)
		t.TextColor3 = l.color
		t.Parent = gui
	end
end

local function lamp(parent: Instance, x: number, z: number, height: number, color: Color3)
	P(parent, {
		Name = "LampPost",
		Size = Vector3.new(0.4, height, 0.4),
		Position = Vector3.new(x, height / 2 + 0.5, z),
		Color = DARK,
		Material = Enum.Material.Metal,
	})
	local head = P(parent, {
		Name = "LampHead",
		Size = Vector3.new(1.3, 0.45, 1.3),
		Position = Vector3.new(x, height + 0.7, z),
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 17
	light.Brightness = 1.2
	light.Parent = head
end

-- Sol, allée, couronne au sol, murs bas, spawn
local function ground(lobby: Instance)
	P(lobby, {
		Name = "Floor",
		Size = Vector3.new(90, 1, 70),
		Position = Vector3.zero,
		Color = hex("#2B2640"),
		Material = Enum.Material.Concrete,
	})
	P(lobby, {
		Name = "Walkway",
		Size = Vector3.new(14, 0.1, 70),
		Position = Vector3.new(0, 0.55, 0),
		Color = hex("#4A4268"),
	})
	for _, x in { -7.2, 7.2 } do
		P(lobby, {
			Name = "WalkwayEdge",
			Size = Vector3.new(0.3, 0.12, 70),
			Position = Vector3.new(x, 0.56, 0),
			Color = CYAN,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end

	local crown = group(lobby, "Model", "Crown")
	local cz, y, w = -6, 0.62, 6
	local function bar(name: string, a: Vector3, b: Vector3)
		local mid = (a + b) / 2
		local p = P(crown, {
			Name = name,
			Size = Vector3.new((b - a).Magnitude, 0.06, 0.45),
			Color = CYAN,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		p.CFrame = CFrame.lookAt(mid, mid + (b - a)) * CFrame.Angles(0, math.rad(90), 0)
	end
	bar("Base", Vector3.new(-w, y, cz + 3), Vector3.new(w, y, cz + 3))
	local pts = {
		Vector3.new(-w, y, cz + 3),
		Vector3.new(-w, y, cz - 4),
		Vector3.new(-w / 2, y, cz - 0.5),
		Vector3.new(0, y, cz - 5),
		Vector3.new(w / 2, y, cz - 0.5),
		Vector3.new(w, y, cz - 4),
		Vector3.new(w, y, cz + 3),
	}
	for i = 1, #pts - 1 do
		bar("Edge" .. i, pts[i], pts[i + 1])
	end

	local walls = group(lobby, "Folder", "Walls")
	local H = 3
	local function wall(name: string, pos: Vector3, size: Vector3)
		P(walls, {
			Name = name,
			Size = size,
			Position = pos,
			Color = hex("#241D3A"),
			Material = Enum.Material.Brick,
		})
		P(walls, {
			Name = name .. "Trim",
			Size = Vector3.new(size.X + 0.1, 0.3, size.Z + 0.1),
			Position = pos + Vector3.new(0, size.Y / 2 + 0.15, 0),
			Color = CYAN,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	wall("West", Vector3.new(-45.5, H / 2 + 0.5, 0), Vector3.new(1, H, 72))
	wall("East", Vector3.new(45.5, H / 2 + 0.5, 0), Vector3.new(1, H, 72))
	wall("South", Vector3.new(0, H / 2 + 0.5, 35.5), Vector3.new(90, H, 1))
	wall("NorthW", Vector3.new(-28.5, H / 2 + 0.5, -35.5), Vector3.new(33, H, 1))
	wall("NorthE", Vector3.new(28.5, H / 2 + 0.5, -35.5), Vector3.new(33, H, 1))
	local tags = { PINK, CYAN, VIOLET, GOLD }
	for i, z in { -24, -8, 8, 24 } do
		P(walls, {
			Name = "TagW",
			Size = Vector3.new(0.15, 2, 6),
			Position = Vector3.new(-44.9, 2, z),
			Color = tags[i],
			CanCollide = false,
		})
		P(walls, {
			Name = "TagE",
			Size = Vector3.new(0.15, 2, 6),
			Position = Vector3.new(44.9, 2, z),
			Color = tags[(i % 4) + 1],
			CanCollide = false,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.6, 25) -- face au nord (-Z)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = hex("#3A3358")
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	spawn.Parent = lobby
	-- disque néon juste sous le dessus du spawn : seul un anneau dépasse
	P(lobby, {
		Name = "SpawnRing",
		Size = Vector3.new(0.2, 9, 9),
		CFrame = CFrame.new(0, 0.98, 25) * FLAT,
		Shape = Enum.PartType.Cylinder,
		Color = CYAN,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
end

-- Arche de sortie et rue ouverte vers le niveau 1 (pas de barrière)
local function exitAndStreet(lobby: Instance)
	local exit = group(lobby, "Model", "Exit")
	for _, x in { -11, 11 } do
		P(exit, {
			Name = "Pillar",
			Size = Vector3.new(2, 14, 2),
			Position = Vector3.new(x, 7.5, -35.5),
			Color = VIOLET,
		})
		P(exit, {
			Name = "PillarNeon",
			Size = Vector3.new(0.3, 13, 0.3),
			Position = Vector3.new(x + (if x < 0 then 1.05 else -1.05), 7.5, -34.45),
			Color = CYAN,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	local beam = P(exit, {
		Name = "Sign",
		Size = Vector3.new(24, 3, 1.5),
		Position = Vector3.new(0, 15.5, -35.5),
		Color = hex("#1B1530"),
	})
	sign(beam, Enum.NormalId.Back, { { text = "VERS LE NIVEAU 1  ›", color = WHITE, h = 0.8 } })
	P(exit, {
		Name = "Glow",
		Size = Vector3.new(24, 0.4, 1.6),
		Position = Vector3.new(0, 13.8, -35.5),
		Color = CYAN,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	P(exit, {
		Name = "GlowTop",
		Size = Vector3.new(24, 0.3, 1.6),
		Position = Vector3.new(0, 17.15, -35.5),
		Color = PINK,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})

	local street = group(lobby, "Model", "Street")
	P(street, {
		Name = "Road",
		Size = Vector3.new(20, 1, 43.5),
		Position = Vector3.new(0, 0, -56.75),
		Color = hex("#1E1A2E"),
		Material = Enum.Material.Asphalt,
	})
	for i = 0, 5 do
		P(street, {
			Name = "Dash",
			Size = Vector3.new(0.5, 0.06, 3),
			Position = Vector3.new(0, 0.53, -39 - i * 7),
			Color = GOLD,
			CanCollide = false,
		})
	end
	for _, side in { -1, 1 } do
		P(street, {
			Name = "Sidewalk",
			Size = Vector3.new(4, 1.4, 43.5),
			Position = Vector3.new(side * 12, 0.2, -56.75),
			Color = hex("#3A3358"),
			Material = Enum.Material.Concrete,
		})
		P(street, {
			Name = "Wall",
			Size = Vector3.new(1, 10, 43.5),
			Position = Vector3.new(side * 14.5, 5.5, -56.75),
			Color = hex("#241D3A"),
			Material = Enum.Material.Brick,
		})
		P(street, {
			Name = "WallTrim",
			Size = Vector3.new(1.1, 0.3, 43.5),
			Position = Vector3.new(side * 14.5, 10.65, -56.75),
			Color = CYAN,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	local words = { "BADDIE", "CLICK", "STREET", "RUN", "WORLD" }
	local colors = { PINK, CYAN, VIOLET, GOLD, PINK }
	for i, z in { -42, -50, -58, -66, -74 } do
		local side = if i % 2 == 0 then 1 else -1
		local g = P(street, {
			Name = "Graffiti",
			Size = Vector3.new(0.2, 4, 6),
			Position = Vector3.new(side * 13.9, 4.5, z),
			Color = hex("#2E2548"),
			CanCollide = false,
		})
		sign(
			g,
			if side < 0 then Enum.NormalId.Right else Enum.NormalId.Left,
			{ { text = words[i], color = colors[i], h = 0.7 } },
			30
		)
	end
	for _, z in { -46, -62 } do
		lamp(street, -11, z, 8, CYAN)
		lamp(street, 11, z, 8, CYAN)
	end
end

-- Street Gym (ouest)
local function gym(lobby: Instance)
	local g = group(lobby, "Model", "Training")
	P(g, {
		Name = "Mat",
		Size = Vector3.new(22, 0.2, 18),
		Position = Vector3.new(-32, 0.6, 2),
		Color = hex("#1A1726"),
		Material = Enum.Material.Fabric,
	})
	for _, s in
		{
			{ Vector3.new(22, 0.12, 0.3), Vector3.new(-32, 0.72, -7) },
			{ Vector3.new(22, 0.12, 0.3), Vector3.new(-32, 0.72, 11) },
			{ Vector3.new(0.3, 0.12, 18), Vector3.new(-43, 0.72, 2) },
			{ Vector3.new(0.3, 0.12, 18), Vector3.new(-21, 0.72, 2) },
		}
	do
		P(g, {
			Name = "Frame",
			Size = s[1],
			Position = s[2],
			Color = VIOLET,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	for _, z in { -2, 6 } do
		for _, dx in { -3, 3 } do
			P(g, {
				Name = "RackPost",
				Size = Vector3.new(0.4, 5, 0.4),
				Position = Vector3.new(-36 + dx, 3.2, z),
				Color = DARK,
			})
		end
		P(g, {
			Name = "Bar",
			Size = Vector3.new(8, 0.25, 0.25),
			Position = Vector3.new(-36, 4.6, z),
			Color = METAL,
			Material = Enum.Material.Metal,
		})
		for _, dx in { -3.6, 3.6 } do
			P(g, {
				Name = "Plate",
				Size = Vector3.new(0.5, 2.2, 2.2),
				Position = Vector3.new(-36 + dx, 4.6, z),
				Shape = Enum.PartType.Cylinder,
				Color = if z < 0 then PINK else CYAN,
			})
		end
		P(g, {
			Name = "Bench",
			Size = Vector3.new(1.6, 0.6, 5),
			Position = Vector3.new(-26, 1.6, z),
			Color = hex("#2E2548"),
		})
		P(g, {
			Name = "BenchLeg",
			Size = Vector3.new(1, 1, 0.4),
			Position = Vector3.new(-26, 0.9, z - 2),
			Color = DARK,
		})
		P(g, {
			Name = "BenchLeg",
			Size = Vector3.new(1, 1, 0.4),
			Position = Vector3.new(-26, 0.9, z + 2),
			Color = DARK,
		})
	end
	for _, z in { -5, 9 } do
		P(g, {
			Name = "DummyPost",
			Size = Vector3.new(0.5, 3, 0.5),
			Position = Vector3.new(-41, 2.2, z),
			Color = DARK,
		})
		P(g, {
			Name = "DummyBody",
			Size = Vector3.new(2.4, 1.6, 1.6),
			CFrame = CFrame.new(-41, 4.2, z) * FLAT,
			Shape = Enum.PartType.Cylinder,
			Color = hex("#B48CF0"),
		})
	end
	local board = P(g, {
		Name = "Sign",
		Size = Vector3.new(0.4, 2.4, 12),
		Position = Vector3.new(-44.6, 4.4, 2),
		Color = DARK,
	})
	sign(board, Enum.NormalId.Right, { { text = "STREET GYM", color = hex("#B48CF0"), h = 0.8 } })
	P(g, {
		Name = "SignGlow",
		Size = Vector3.new(0.3, 0.2, 12),
		Position = Vector3.new(-44.4, 5.75, 2),
		Color = VIOLET,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
end

-- La Scène (est) : Podium.Stand doré, anneau néon, écran LED, projecteurs, cabine DJ
local function stage(lobby: Instance)
	local s = group(lobby, "Model", "Stage")
	P(s, {
		Name = "Deck",
		Size = Vector3.new(20, 0.6, 22),
		Position = Vector3.new(34, 0.8, -4),
		Color = hex("#1B1530"),
	})
	P(s, {
		Name = "DeckEdge",
		Size = Vector3.new(0.3, 0.2, 22),
		Position = Vector3.new(23.9, 1.05, -4),
		Color = PINK,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})

	local podium = group(lobby, "Model", "Podium")
	P(podium, {
		Name = "Base",
		Size = Vector3.new(2, 12, 12),
		CFrame = CFrame.new(28, 1, -4) * FLAT,
		Shape = Enum.PartType.Cylinder,
		Color = hex("#2A2347"),
	})
	P(podium, {
		Name = "Ring",
		Size = Vector3.new(0.3, 12.4, 12.4),
		CFrame = CFrame.new(28, 1.55, -4) * FLAT,
		Shape = Enum.PartType.Cylinder,
		Color = CYAN,
		Material = Enum.Material.Neon,
	})
	P(podium, {
		Name = "Stand",
		Size = Vector3.new(1, 9, 9),
		CFrame = CFrame.new(28, 2, -4) * FLAT,
		Shape = Enum.PartType.Cylinder,
		Color = GOLD,
		Material = Enum.Material.Metal,
	})

	local screen = P(s, {
		Name = "LookScreen",
		Size = Vector3.new(0.6, 9, 16),
		Position = Vector3.new(43.8, 6.6, -4),
		Color = hex("#0D0B16"),
	})
	sign(screen, Enum.NormalId.Left, {
		{ text = "LA SCÈNE", color = CYAN, h = 0.3 },
		{ text = "TON LOOK, TA BADDIE", color = WHITE, h = 0.18, weight = Enum.FontWeight.Bold },
	}, 30)
	P(s, {
		Name = "ScreenFrame",
		Size = Vector3.new(0.4, 9.6, 16.6),
		Position = Vector3.new(44.15, 6.6, -4),
		Color = PINK,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	for _, z in { -14, 6 } do
		P(s, {
			Name = "Truss",
			Size = Vector3.new(0.6, 12, 0.6),
			Position = Vector3.new(42, 7, z),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
		local spot = P(s, {
			Name = "Spot",
			Size = Vector3.new(1.4, 1.4, 1.4),
			CFrame = CFrame.lookAt(Vector3.new(41, 12.5, z), Vector3.new(28, 2, -4)),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
		local lens = P(s, {
			Name = "Lens",
			Size = Vector3.new(1, 1, 0.2),
			CFrame = spot.CFrame * CFrame.new(0, 0, -0.75),
			Color = hex("#FFE9B0"),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Angle = 35
		light.Range = 24
		light.Brightness = 3
		light.Color = hex("#FFE9B0")
		light.Parent = lens
	end
	P(s, {
		Name = "TrussTop",
		Size = Vector3.new(0.6, 0.6, 21),
		Position = Vector3.new(42, 13, -4),
		Color = DARK,
		Material = Enum.Material.Metal,
	})
	P(s, {
		Name = "DJBooth",
		Size = Vector3.new(3, 3, 7),
		Position = Vector3.new(38, 2.6, -15),
		Color = hex("#1B1530"),
	})
	P(s, {
		Name = "DJFront",
		Size = Vector3.new(0.2, 2.4, 6.6),
		Position = Vector3.new(36.45, 2.6, -15),
		Color = CYAN,
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.2,
	})
	for _, z in { -17, -13 } do
		P(s, {
			Name = "Turntable",
			Size = Vector3.new(0.2, 1.8, 1.8),
			CFrame = CFrame.new(38, 4.2, z) * FLAT,
			Shape = Enum.PartType.Cylinder,
			Color = hex("#0D0B16"),
		})
	end
end

-- Classement (nord-ouest, rempli en direct par Controllers/Leaderboard) et vitrine Style (nord-est)
local function boards(lobby: Instance)
	local ranking = group(lobby, "Model", "Ranking")
	for _, x in { -37, -23 } do
		P(ranking, {
			Name = "Leg",
			Size = Vector3.new(0.6, 4, 0.6),
			Position = Vector3.new(x, 2.5, -31),
			Color = DARK,
			Material = Enum.Material.Metal,
		})
	end
	local led = P(ranking, {
		Name = "Screen",
		Size = Vector3.new(16, 8, 0.6),
		Position = Vector3.new(-30, 8, -31),
		Color = hex("#0D0B16"),
	})
	sign(led, Enum.NormalId.Back, {
		{ text = "CLASSEMENT", color = CYAN, h = 0.22 },
		{ text = "BADDIES DÉCOUVERTES", color = WHITE, h = 0.12, weight = Enum.FontWeight.Bold },
		{ text = "JOUEURS PRÉSENTS SUR LE SERVEUR", color = DIM, h = 0.1, weight = Enum.FontWeight.Bold },
	}, 30)
	P(ranking, {
		Name = "Frame",
		Size = Vector3.new(16.6, 8.6, 0.4),
		Position = Vector3.new(-30, 8, -31.35),
		Color = CYAN,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})

	local vitrine = group(lobby, "Model", "StyleShowcase")
	P(vitrine, {
		Name = "Base",
		Size = Vector3.new(14, 1, 5),
		Position = Vector3.new(30, 1, -31.5),
		Color = hex("#1B1530"),
	})
	P(vitrine, {
		Name = "Back",
		Size = Vector3.new(14, 8, 0.4),
		Position = Vector3.new(30, 5.5, -33.8),
		Color = hex("#241D3A"),
	})
	P(vitrine, {
		Name = "Roof",
		Size = Vector3.new(14, 0.4, 5),
		Position = Vector3.new(30, 9.7, -31.5),
		Color = hex("#1B1530"),
	})
	P(vitrine, {
		Name = "Glass",
		Size = Vector3.new(14, 8, 0.2),
		Position = Vector3.new(30, 5.5, -29.1),
		Color = hex("#FFB3E8"),
		Material = Enum.Material.Glass,
		Transparency = 0.75,
	})
	for _, dx in { -7.1, 7.1 } do
		P(vitrine, {
			Name = "NeonSide",
			Size = Vector3.new(0.3, 8.4, 0.3),
			Position = Vector3.new(30 + dx, 5.5, -29),
			Color = PINK,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	P(vitrine, {
		Name = "NeonTop",
		Size = Vector3.new(14.5, 0.3, 0.3),
		Position = Vector3.new(30, 9.7, -29),
		Color = PINK,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local outfits = { { hex("#3B5B8C"), hex("#F4EEE7") }, { hex("#2B2B30"), CYAN }, { PINK, hex("#F4EEE7") } }
	for i, x in { 25.5, 30, 34.5 } do
		P(vitrine, {
			Name = "Mannequin",
			Size = Vector3.new(1.6, 3, 1),
			Position = Vector3.new(x, 4.2, -31.8),
			Color = outfits[i][1],
		})
		P(vitrine, {
			Name = "Mannequin",
			Size = Vector3.new(1.4, 2, 0.9),
			Position = Vector3.new(x, 2.1, -31.8),
			Color = outfits[i][2],
		})
		P(vitrine, {
			Name = "Head",
			Size = Vector3.new(1, 1, 1),
			Position = Vector3.new(x, 6.3, -31.8),
			Shape = Enum.PartType.Ball,
			Color = hex("#E8D5C4"),
		})
	end
	local top = P(
		vitrine,
		{ Name = "Sign", Size = Vector3.new(10, 1.6, 0.3), Position = Vector3.new(30, 11, -31), Color = DARK }
	)
	sign(top, Enum.NormalId.Back, { { text = "STYLE · LOOKS ET TITRES", color = PINK, h = 0.8 } })
end

-- Palmiers, bancs, lampadaires néon, demi-terrain de basket
local function decor(lobby: Instance)
	local deco = group(lobby, "Folder", "Deco")
	local function palm(x: number, z: number)
		for i = 0, 4 do
			P(deco, {
				Name = "PalmTrunk",
				Size = Vector3.new(1.2 - i * 0.1, 2.4, 1.2 - i * 0.1),
				Position = Vector3.new(x + i * 0.25, 1.7 + i * 2.3, z),
				Color = hex("#5A3E2B"),
				Material = Enum.Material.Wood,
			})
		end
		local top = Vector3.new(x + 1.2, 12.6, z)
		for k = 0, 5 do
			local leaf = P(deco, {
				Name = "PalmLeaf",
				Size = Vector3.new(1.4, 0.3, 6),
				Color = hex("#2E8B57"),
				Material = Enum.Material.Grass,
				CanCollide = false,
			})
			leaf.CFrame = CFrame.new(top)
				* CFrame.Angles(0, math.rad(k * 60), 0)
				* CFrame.Angles(math.rad(-22), 0, 0)
				* CFrame.new(0, 0, -3)
		end
	end
	palm(-41, -29)
	palm(41, 31)
	palm(-41, 31)
	palm(19, -30)
	local function bench(x: number, z: number, ry: number)
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(ry), 0)
		P(deco, {
			Name = "Bench",
			Size = Vector3.new(5, 0.4, 1.4),
			CFrame = cf * CFrame.new(0, 1.6, 0),
			Color = hex("#7A5232"),
			Material = Enum.Material.Wood,
		})
		P(deco, {
			Name = "Bench",
			Size = Vector3.new(5, 1.4, 0.3),
			CFrame = cf * CFrame.new(0, 2.4, 0.6),
			Color = hex("#7A5232"),
			Material = Enum.Material.Wood,
		})
		for _, dx in { -2, 2 } do
			P(deco, {
				Name = "BenchLeg",
				Size = Vector3.new(0.3, 1.1, 1.2),
				CFrame = cf * CFrame.new(dx, 0.95, 0),
				Color = DARK,
			})
		end
	end
	bench(-14, 12, 90)
	bench(14, 12, -90)
	bench(-14, -18, 90)
	bench(14, -18, -90)
	for _, z in { -26, -6, 14 } do
		lamp(deco, -9.5, z, 8, if z == -6 then PINK else CYAN)
		lamp(deco, 9.5, z, 8, if z == -6 then PINK else CYAN)
	end

	local court = group(deco, "Model", "Court")
	P(court, {
		Name = "CourtFloor",
		Size = Vector3.new(20, 0.12, 14),
		Position = Vector3.new(32, 0.56, 24),
		Color = hex("#3B2E6B"),
	})
	for _, s in
		{
			{ Vector3.new(20, 0.06, 0.25), Vector3.new(32, 0.65, 17.1) },
			{ Vector3.new(20, 0.06, 0.25), Vector3.new(32, 0.65, 30.9) },
			{ Vector3.new(0.25, 0.06, 14), Vector3.new(22.1, 0.65, 24) },
			{ Vector3.new(0.25, 0.06, 6), Vector3.new(36, 0.65, 24) },
			{ Vector3.new(6, 0.06, 0.25), Vector3.new(39, 0.65, 21) },
			{ Vector3.new(6, 0.06, 0.25), Vector3.new(39, 0.65, 27) },
		}
	do
		P(court, { Name = "Line", Size = s[1], Position = s[2], Color = WHITE, CanCollide = false })
	end
	P(court, {
		Name = "HoopPole",
		Size = Vector3.new(0.5, 10, 0.5),
		Position = Vector3.new(43.5, 5.5, 24),
		Color = DARK,
		Material = Enum.Material.Metal,
	})
	P(court, {
		Name = "Backboard",
		Size = Vector3.new(0.3, 3, 5),
		Position = Vector3.new(42.8, 9.5, 24),
		Color = WHITE,
	})
	P(court, {
		Name = "Rim",
		Size = Vector3.new(0.2, 2, 2),
		CFrame = CFrame.new(41.6, 8.6, 24) * FLAT,
		Shape = Enum.PartType.Cylinder,
		Color = hex("#E06A1F"),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
end

-- Ville et voie surélevée au loin (est, ouest, sud ; jamais au nord de la rue)
local function skyline(lobby: Instance)
	local city = group(lobby, "Folder", "Skyline")
	local rng = Random.new(42)
	local neons = { CYAN, PINK, VIOLET, GOLD }
	local walls = { hex("#1B1530"), hex("#221B3A"), hex("#2A2347") }
	local function tower(x: number, z: number)
		local h, w, d = rng:NextInteger(18, 60), rng:NextInteger(8, 14), rng:NextInteger(8, 14)
		far(city, {
			Name = "Tower",
			Size = Vector3.new(w, h, d),
			Position = Vector3.new(x, h / 2, z),
			Color = walls[rng:NextInteger(1, 3)],
		})
		far(city, {
			Name = "TowerTrim",
			Size = Vector3.new(w + 0.2, 0.5, d + 0.2),
			Position = Vector3.new(x, h - 1.5, z),
			Color = neons[rng:NextInteger(1, 4)],
			Material = Enum.Material.Neon,
		})
		for k = 1, math.floor(h / 12) do
			far(city, {
				Name = "Windows",
				Size = Vector3.new(w + 0.1, 0.6, d + 0.1),
				Position = Vector3.new(x, k * 10, z),
				Color = hex("#FFE9B0"),
				Material = Enum.Material.Neon,
				Transparency = 0.55,
			})
		end
	end
	for z = -66, 60, 18 do
		tower(-80 - rng:NextInteger(0, 20), z)
		tower(80 + rng:NextInteger(0, 20), z)
	end
	for x = -90, 90, 20 do
		tower(x, 95 + rng:NextInteger(0, 15))
	end
	local road = group(lobby, "Folder", "Skyway")
	far(road, {
		Name = "Deck",
		Size = Vector3.new(260, 1.5, 10),
		Position = Vector3.new(0, 20, 72),
		Color = hex("#1B1530"),
	})
	far(road, {
		Name = "RailN",
		Size = Vector3.new(260, 0.4, 0.4),
		Position = Vector3.new(0, 21.2, 67),
		Color = CYAN,
		Material = Enum.Material.Neon,
	})
	far(road, {
		Name = "RailS",
		Size = Vector3.new(260, 0.4, 0.4),
		Position = Vector3.new(0, 21.2, 77),
		Color = PINK,
		Material = Enum.Material.Neon,
	})
	for x = -120, 120, 30 do
		far(road, {
			Name = "Pillar",
			Size = Vector3.new(2.5, 19.3, 2.5),
			Position = Vector3.new(x, 9.6, 72),
			Color = hex("#241D3A"),
		})
	end
end

return function(lobby: Model)
	lobby:ClearAllChildren()
	for _, step in { ground, exitAndStreet, gym, stage, boards, decor, skyline } do
		step(lobby)
		task.wait()
	end
	-- bord nord, doit valoir -78,5 (GetBoundingBox n'existe pas hors de Studio : nil sous Lune)
	local ok, cf, size = pcall(function()
		return lobby:GetBoundingBox()
	end)
	return if ok then cf.Position.Z - size.Z / 2 else nil
end
