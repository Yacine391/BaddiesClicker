--[[
	CharacterKit : fabrique de personnages en pièces Roblox (aucun mesh importé), sur un rig commun.
	Ce n'est PAS un script du jeu : `lune run assets/visuals/export-characters` l'exécute et écrit
	assets/visuals/Characters.rbxm, que Rojo synchronise dans ReplicatedStorage.Visuals.Characters.

	Rig (dossier §03 « un corps et un squelette de référence », §20 « rig commun, vêtements modulaires ») :
	- os invisibles aux noms R15 (HumanoidRootPart, LowerTorso, UpperTorso, Head, bras, jambes) reliés par
	  des Motor6D sans rotation : les animations R15 de Roblox (idle, marche) s'appliquent telles quelles ;
	- chaque pièce visible est soudée (Weld) à son os : une pièce = une forme simple (bloc, boule, cylindre,
	  ellipsoïde par SpecialMesh) en SmoothPlastic, sans collision ni requête ;
	- HumanoidRootPart ancrée à 3 studs au-dessus des pieds (comme un avatar R15) : pivot du modèle ;
	- AnimationController + Animator, AuraAttachment (torse) et NameTagAttachment (au-dessus de la tête).
	Repère : pieds à Y = 0, le personnage regarde vers -Z, sa droite est +X.

	Un modèle Blender peut remplacer un personnage en gardant le même nom de dossier et les mêmes attaches.
]]

local hex = Color3.fromHex
local V = Vector3.new
local rad = math.rad

local Kit = {}

export type Rig = {
	model: Model,
	bones: { [string]: Part },
	S: any, -- squelette (points d'articulation en repère modèle, avant mise à l'échelle)
	k: number, -- échelle uniforme autour des pieds
	count: number,
	skin: Color3,
}

--------------------------------------------------------------------------------------------------
-- Géométrie
--------------------------------------------------------------------------------------------------

-- CFrame au milieu de p0→p1, axe Y local le long du segment, axe Z local au plus près de l'avant/arrière
local function segmentCFrame(p0: Vector3, p1: Vector3): (CFrame, number)
	local d = p1 - p0
	local length = d.Magnitude
	local y = d / length
	local hint = if math.abs(y.Z) > 0.95 then V(0, 1, 0) else V(0, 0, 1)
	local x = y:Cross(hint).Unit
	local z = x:Cross(y).Unit
	local mid = (p0 + p1) / 2
	return CFrame.new(mid.X, mid.Y, mid.Z, x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z), length
end
Kit.segmentCFrame = segmentCFrame

-- Cylindre Roblox : axe le long de X local. `upright` le redresse le long de Y local.
local UPRIGHT = CFrame.Angles(0, 0, rad(90))
Kit.UPRIGHT = UPRIGHT

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end
Kit.at = at

--------------------------------------------------------------------------------------------------
-- Rig
--------------------------------------------------------------------------------------------------

-- Squelette de référence (personnage de 5,3 studs, §03). `b` ajuste la carrure.
function Kit.skeleton(b: any): any
	local S = {
		ankleY = 0.48,
		kneeY = 1.56,
		hipY = 2.62,
		pelvisY = 2.78,
		waistY = 3.08,
		chestY = 3.55,
		shoulderY = 3.98,
		neckY = 4.14,
		headY = 4.72,
		headR = 0.5, -- rayon du cylindre de tête
		headCylBottom = 4.42,
		headCylTop = 5.0,
		headBottomH = 0.28, -- demi-hauteur de la calotte du menton
		headTopH = 0.31, -- demi-hauteur de la calotte du crâne
		-- masque du visage : ellipsoïde (demi-axes a, b, c) centré en (0, y, z)
		face = { y = 4.64, z = -0.2, a = 0.515, b = 0.55, c = 0.335 },
		shoulderX = b.shoulderX or 0.47,
		hipX = b.hipX or 0.29,
		kneeX = b.kneeX or 0.33,
		ankleX = b.ankleX or 0.4,
		armSpread = b.armSpread or 10, -- degrés d'écart des bras au repos (pose en A légère)
		upperArm = 0.57,
		lowerArm = 0.58,
		hand = 0.2,
	}
	local a = rad(S.armSpread)
	local dir = V(math.sin(a), -math.cos(a), 0) -- vers le bas et l'extérieur, côté droit
	S.shoulder = V(S.shoulderX, S.shoulderY, 0)
	S.elbow = S.shoulder + dir * S.upperArm
	S.wrist = S.elbow + dir * S.lowerArm
	S.handCenter = S.wrist + dir * S.hand
	S.armDir = dir
	S.hip = V(S.hipX, S.hipY, 0)
	S.knee = V(S.kneeX, S.kneeY, 0)
	S.ankle = V(S.ankleX, S.ankleY, 0)
	return S
end

-- Symétrie : point du côté `side` (1 = droite du personnage, -1 = gauche)
local function mirror(p: Vector3, side: number): Vector3
	return V(p.X * side, p.Y, p.Z)
end
Kit.mirror = mirror

local function bone(rig: Rig, name: string, position: Vector3, size: Vector3?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = (size or V(0.4, 0.4, 0.4)) * rig.k
	p.CFrame = CFrame.new(position * rig.k)
	p.Transparency = 1
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = rig.model
	rig.bones[name] = p
	return p
end

local function joint(rig: Rig, name: string, parent: string, child: string, position: Vector3)
	local p0, p1 = rig.bones[parent], rig.bones[child]
	local world = position * rig.k
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = p0
	m.Part1 = p1
	m.C0 = CFrame.new(world - p0.CFrame.Position)
	m.C1 = CFrame.new(world - p1.CFrame.Position)
	m.Parent = p1
end

function Kit.newRig(name: string, S: any, skin: Color3, scale: number?): Rig
	local model = Instance.new("Model")
	model.Name = name
	local rig: Rig = { model = model, bones = {}, S = S, k = scale or 1, count = 0, skin = skin }
	local k = rig.k

	-- Racine : 3 studs au-dessus des pieds quelle que soit l'échelle (les pieds restent au sol)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = V(2, 2, 1)
	root.CFrame = CFrame.new(0, 3, 0)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model
	rig.bones.HumanoidRootPart = root
	model.PrimaryPart = root

	bone(rig, "LowerTorso", V(0, S.pelvisY, 0))
	bone(rig, "UpperTorso", V(0, S.chestY, 0))
	bone(rig, "Head", V(0, S.headY, 0))
	for _, side in { 1, -1 } do
		local prefix = if side == 1 then "Right" else "Left"
		bone(rig, prefix .. "UpperArm", mirror((S.shoulder + S.elbow) / 2, side))
		bone(rig, prefix .. "LowerArm", mirror((S.elbow + S.wrist) / 2, side))
		bone(rig, prefix .. "Hand", mirror(S.handCenter, side))
		bone(rig, prefix .. "UpperLeg", mirror((S.hip + S.knee) / 2, side))
		bone(rig, prefix .. "LowerLeg", mirror((S.knee + S.ankle) / 2, side))
		bone(rig, prefix .. "Foot", mirror(V(S.ankleX, S.ankleY / 2, 0), side))
	end

	-- Articulation « Root » : exprimée depuis la racine non mise à l'échelle
	local rootJoint = Instance.new("Motor6D")
	rootJoint.Name = "Root"
	rootJoint.Part0 = root
	rootJoint.Part1 = rig.bones.LowerTorso
	rootJoint.C0 = CFrame.new(V(0, S.pelvisY * k, 0) - root.CFrame.Position)
	rootJoint.C1 = CFrame.new()
	rootJoint.Parent = rig.bones.LowerTorso

	joint(rig, "Waist", "LowerTorso", "UpperTorso", V(0, S.waistY, 0))
	joint(rig, "Neck", "UpperTorso", "Head", V(0, S.neckY, 0))
	for _, side in { 1, -1 } do
		local prefix = if side == 1 then "Right" else "Left"
		joint(rig, prefix .. "Shoulder", "UpperTorso", prefix .. "UpperArm", mirror(S.shoulder, side))
		joint(rig, prefix .. "Elbow", prefix .. "UpperArm", prefix .. "LowerArm", mirror(S.elbow, side))
		joint(rig, prefix .. "Wrist", prefix .. "LowerArm", prefix .. "Hand", mirror(S.wrist, side))
		joint(rig, prefix .. "Hip", "LowerTorso", prefix .. "UpperLeg", mirror(S.hip, side))
		joint(rig, prefix .. "Knee", prefix .. "UpperLeg", prefix .. "LowerLeg", mirror(S.knee, side))
		joint(rig, prefix .. "Ankle", prefix .. "LowerLeg", prefix .. "Foot", mirror(S.ankle, side))
	end

	local controller = Instance.new("AnimationController")
	controller.Name = "AnimationController"
	local animator = Instance.new("Animator")
	animator.Name = "Animator"
	animator.Parent = controller
	controller.Parent = model

	local aura = Instance.new("Attachment")
	aura.Name = "AuraAttachment"
	aura.CFrame = CFrame.new()
	aura.Parent = rig.bones.UpperTorso
	local tag = Instance.new("Attachment")
	tag.Name = "NameTagAttachment"
	tag.CFrame = CFrame.new(0, (5.9 - S.headY) * k, 0)
	tag.Parent = rig.bones.Head
	local feet = Instance.new("Attachment")
	feet.Name = "GroundAttachment" -- aux pieds : auras au sol (anneaux)
	feet.CFrame = CFrame.new(0, -3, 0)
	feet.Parent = root

	return rig
end

--------------------------------------------------------------------------------------------------
-- Pièces
--------------------------------------------------------------------------------------------------

export type Opts = {
	material: Enum.Material?,
	transparency: number?,
	reflectance: number?,
	shadow: boolean?,
}

-- Ajoute une pièce soudée à `boneName`. `shape` : "box" | "ball" | "cyl" | "ell" | "wedge".
-- `cf` et `size` en repère modèle (avant échelle). Cylindre : axe X local, taille (longueur, d, d).
function Kit.add(
	rig: Rig,
	boneName: string,
	name: string,
	shape: string,
	color: Color3,
	size: Vector3,
	cf: CFrame,
	opts: Opts?
): BasePart
	local parent = rig.bones[boneName]
	assert(parent ~= nil, `os inconnu : {boneName}`)
	local k = rig.k
	local p: BasePart
	if shape == "wedge" then
		p = Instance.new("WedgePart")
	else
		local part = Instance.new("Part")
		if shape == "ball" then
			part.Shape = Enum.PartType.Ball
		elseif shape == "cyl" then
			part.Shape = Enum.PartType.Cylinder
		end
		p = part
	end
	p.Name = name
	p.Size = size * k
	p.CFrame = (cf - cf.Position) + cf.Position * k
	p.Color = color
	p.Material = if opts and opts.material then opts.material else Enum.Material.SmoothPlastic
	p.Transparency = if opts and opts.transparency then opts.transparency else 0
	p.Reflectance = if opts and opts.reflectance then opts.reflectance else 0
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = opts ~= nil and opts.shadow == true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape == "ell" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	local weld = Instance.new("Weld")
	weld.Name = "BoneWeld"
	weld.Part0 = parent
	weld.Part1 = p
	weld.C0 = parent.CFrame:Inverse() * p.CFrame
	weld.C1 = CFrame.new()
	weld.Parent = p
	p.Parent = rig.model
	rig.count += 1
	return p
end

local add = Kit.add

-- Ellipsoïde étiré entre deux points (membre) : largeur X, profondeur Z, dépassement aux extrémités
function Kit.limb(
	rig: Rig,
	boneName: string,
	name: string,
	color: Color3,
	p0: Vector3,
	p1: Vector3,
	width: number,
	depth: number,
	overshoot: number?,
	opts: Opts?
): BasePart
	local cf, length = segmentCFrame(p0, p1)
	return add(rig, boneName, name, "ell", color, V(width, length + (overshoot or 0.2), depth), cf, opts)
end

-- Cylindre entre deux points
function Kit.tube(
	rig: Rig,
	boneName: string,
	name: string,
	color: Color3,
	p0: Vector3,
	p1: Vector3,
	diameter: number,
	opts: Opts?
): BasePart
	local cf, length = segmentCFrame(p0, p1)
	return add(rig, boneName, name, "cyl", color, V(length, diameter, diameter), cf * UPRIGHT, opts)
end

-- Barre fine (boîte) entre deux points : bijoux, lacets, tiges
function Kit.bar(
	rig: Rig,
	boneName: string,
	name: string,
	color: Color3,
	p0: Vector3,
	p1: Vector3,
	width: number,
	depth: number?,
	opts: Opts?
): BasePart
	local cf, length = segmentCFrame(p0, p1)
	return add(rig, boneName, name, "box", color, V(width, length, depth or width), cf, opts)
end

-- Chaîne d'ellipsoïdes le long d'une courbe (mèches, queue de cheval). widths : largeur par point.
function Kit.strand(
	rig: Rig,
	boneName: string,
	name: string,
	color: Color3,
	points: { Vector3 },
	widths: { number },
	flatten: number?,
	opts: Opts?
)
	for i = 1, #points - 1 do
		local w = (widths[i] + widths[i + 1]) / 2
		-- dépassement ≈ longueur du segment : les ellipsoïdes se fondent au lieu de former des perles
		local overshoot = (points[i + 1] - points[i]).Magnitude * 0.95
		Kit.limb(
			rig,
			boneName,
			name,
			color,
			points[i],
			points[i + 1],
			w,
			w * (flatten or 0.8),
			overshoot,
			opts
		)
	end
end

-- Anneau (créole, bracelet large) en `n` barres dans le plan local XY de `cf`
function Kit.ring(
	rig: Rig,
	boneName: string,
	name: string,
	color: Color3,
	cf: CFrame,
	radius: number,
	thickness: number,
	n: number,
	opts: Opts?
)
	for i = 0, n - 1 do
		local a0 = (i / n) * math.pi * 2
		local a1 = ((i + 1) / n) * math.pi * 2
		local p0 = cf:PointToWorldSpace(V(math.cos(a0) * radius, math.sin(a0) * radius, 0))
		local p1 = cf:PointToWorldSpace(V(math.cos(a1) * radius, math.sin(a1) * radius, 0))
		local segment, length = segmentCFrame(p0, p1)
		add(
			rig,
			boneName,
			name,
			"box",
			color,
			V(thickness, length + thickness * 0.6, thickness),
			segment,
			opts
		)
	end
end

--------------------------------------------------------------------------------------------------
-- Tête : surface du visage
--------------------------------------------------------------------------------------------------

-- CFrame posé sur le visage au point (x, y), -Z local vers l'extérieur ; `lift` décolle la pièce.
-- Le visage est un ellipsoïde large et peu bombé (S.face, posé par Parts.body) devant le cylindre de
-- tête : les traits restent lisibles de face et de trois quarts sans s'enrouler sur les côtés.
function Kit.onFace(S: any, x: number, y: number, lift: number?): CFrame
	local f = S.face
	local cx = math.clamp(x, -f.a * 0.92, f.a * 0.92)
	local ny = math.clamp((y - f.y) / f.b, -0.92, 0.92)
	local nx = cx / f.a
	local inside = math.max(0.02, 1 - nx * nx - ny * ny)
	local z = f.z - f.c * math.sqrt(inside)
	local normal = V(cx / (f.a * f.a), (y - f.y) / (f.b * f.b), (z - f.z) / (f.c * f.c)).Unit
	local p = V(cx, y, z) + normal * (lift or 0)
	return CFrame.lookAt(p, p + normal)
end

-- Pastille plate sur le visage (yeux, sourcils, lèvres) : ellipsoïde (w, h, t), inclinaison en degrés
function Kit.facePatch(
	rig: Rig,
	name: string,
	color: Color3,
	x: number,
	y: number,
	w: number,
	h: number,
	t: number,
	roll: number?,
	opts: Opts?
): BasePart
	local cf = Kit.onFace(rig.S, x, y, 0) * CFrame.Angles(0, 0, rad(roll or 0))
	return add(rig, "Head", name, "ell", color, V(w, h, t), cf, opts)
end

Kit.hex = hex
Kit.V = V

return Kit
