--[[
	Mise au contrat des personnages importés (à coller dans la barre de commande de Studio, HORS Play).

	Avant : Fichier → Importer 3D les FBX `B01_Maya_Look01..03.fbx` (type de rig R15). L'importeur crée dans
	Workspace un modèle par fichier, avec Humanoid, HumanoidRootPart et 15 MeshParts reliées par des Motor6D.

	Ce script, pour chaque look :
	- supprime le Humanoid, ajoute AnimationController + Animator ;
	- HumanoidRootPart 2×2×1, invisible, sans collision, PrimaryPart, à la même hauteur au-dessus des pieds que
	  l'ancien placeholder (le Motor6D Root est recalculé pour ne rien déplacer) ;
	- AuraAttachment dans UpperTorso en (0, 0, 0), NameTagAttachment dans Head (position de l'ancien placeholder) ;
	- vérifie le contrat (15 parties, Motor6D, hauteur 5,5 ± 0,3) puis remplace LookNN dans
	  ReplicatedStorage.Visuals.Characters.<dossier>.

	Ensuite : clic droit sur ReplicatedStorage.Visuals.Characters → Enregistrer dans un fichier →
	assets/visuals/Characters.rbxm.
]]

local FOLDER = "B01_Maya" -- dossier du personnage dans Visuals.Characters
local SOURCE = "B01_Maya_Look%02d" -- nom des modèles importés dans Workspace
local LOOKS = 3

local PARTS = {
	"Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local dir = game:GetService("ReplicatedStorage").Visuals.Characters[FOLDER]

local function bottomOf(model: Model): number
	local box, size = model:GetBoundingBox()
	return box.Position.Y - size.Y / 2
end

local function motorInto(part: BasePart): Motor6D?
	for _, m in part:GetChildren() do
		if m:IsA("Motor6D") and m.Part1 == part then
			return m
		end
	end
	return nil
end

for i = 1, LOOKS do
	local name = ("Look%02d"):format(i)
	local src = workspace:FindFirstChild(SOURCE:format(i))
	assert(src and src:IsA("Model"), `{SOURCE:format(i)} introuvable dans Workspace : importer le FBX d'abord`)
	local old = dir:FindFirstChild(name)

	local humanoid = src:FindFirstChildWhichIsA("Humanoid", true)
	if humanoid then
		humanoid:Destroy()
	end
	if not src:FindFirstChildOfClass("AnimationController") then
		local controller = Instance.new("AnimationController")
		Instance.new("Animator").Parent = controller
		controller.Parent = src
	end

	local hrp = src:FindFirstChild("HumanoidRootPart") :: BasePart
	assert(hrp, `{name} : pas de HumanoidRootPart (importer avec le type de rig R15)`)
	local lower = src:FindFirstChild("LowerTorso") :: BasePart
	local root = motorInto(lower)
	assert(root and root.Part0 == hrp, `{name} : LowerTorso n'est pas relié au HumanoidRootPart`)

	-- même hauteur du HRP au-dessus des pieds que l'ancien placeholder (3 studs par défaut, comme un R15)
	local lift = 3
	local oldHrp = old and old:FindFirstChild("HumanoidRootPart") :: BasePart?
	if old and oldHrp then
		lift = oldHrp.Position.Y - bottomOf(old)
	end
	local lowerCFrame = lower.CFrame
	local target = CFrame.new(hrp.Position.X, bottomOf(src) + lift, hrp.Position.Z) * hrp.CFrame.Rotation
	hrp.CFrame = target
	root.C0 = hrp.CFrame:Inverse() * lowerCFrame * root.C1
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.Transparency = 1
	hrp.CanCollide = false
	hrp.CanQuery = false
	hrp.CanTouch = false
	if oldHrp then
		hrp.Anchored = oldHrp.Anchored
	end
	src.PrimaryPart = hrp

	local upper = src:FindFirstChild("UpperTorso") :: BasePart
	local head = src:FindFirstChild("Head") :: BasePart
	local aura = upper:FindFirstChild("AuraAttachment") or Instance.new("Attachment")
	aura.Name = "AuraAttachment"
	aura.Position = Vector3.zero
	aura.Parent = upper
	local tag = head:FindFirstChild("NameTagAttachment") or Instance.new("Attachment")
	tag.Name = "NameTagAttachment"
	local oldTag = old and old:FindFirstChild("Head") and old.Head:FindFirstChild("NameTagAttachment")
	tag.Position = if oldTag then oldTag.Position else Vector3.new(0, 1.4, 0)
	tag.Parent = head

	-- contrôle du contrat
	local problems = {}
	for _, partName in PARTS do
		local part = src:FindFirstChild(partName)
		if not (part and part:IsA("BasePart")) then
			table.insert(problems, `partie {partName} absente`)
		elseif not motorInto(part) then
			table.insert(problems, `{partName} sans Motor6D`)
		end
	end
	local _, size = src:GetBoundingBox()
	if math.abs(size.Y - 5.5) > 0.3 then
		table.insert(problems, `hauteur {math.floor(size.Y * 100) / 100} studs (attendu 5,5 ± 0,3)`)
	end
	if #problems > 0 then
		warn(`[Contrat] {name} : {table.concat(problems, " ; ")}`)
		continue
	end

	src.Name = name
	if old then
		src:PivotTo(old:GetPivot())
		old:Destroy()
	end
	src.Parent = dir
	print(`[Contrat] {name} OK : hauteur {math.floor(size.Y * 100) / 100} studs, HRP à {lift} studs des pieds`)
end
