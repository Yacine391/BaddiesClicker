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
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"LeftHand",
	"RightUpperArm",
	"RightLowerArm",
	"RightHand",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"LeftFoot",
	"RightUpperLeg",
	"RightLowerLeg",
	"RightFoot",
}

-- Articulations R15 : nom du Motor6D, partie parente, partie enfant (même table que Humanoid:BuildRigFromAttachments).
-- L'importeur crée les *RigAttachment mais pas toujours les Motor6D (le Humanoid les construit au lancement) :
-- comme le contrat retire le Humanoid, on les construit ici.
local JOINTS = {
	{ "Root", "HumanoidRootPart", "LowerTorso" },
	{ "Waist", "LowerTorso", "UpperTorso" },
	{ "Neck", "UpperTorso", "Head" },
	{ "LeftShoulder", "UpperTorso", "LeftUpperArm" },
	{ "LeftElbow", "LeftUpperArm", "LeftLowerArm" },
	{ "LeftWrist", "LeftLowerArm", "LeftHand" },
	{ "RightShoulder", "UpperTorso", "RightUpperArm" },
	{ "RightElbow", "RightUpperArm", "RightLowerArm" },
	{ "RightWrist", "RightLowerArm", "RightHand" },
	{ "LeftHip", "LowerTorso", "LeftUpperLeg" },
	{ "LeftKnee", "LeftUpperLeg", "LeftLowerLeg" },
	{ "LeftAnkle", "LeftLowerLeg", "LeftFoot" },
	{ "RightHip", "LowerTorso", "RightUpperLeg" },
	{ "RightKnee", "RightUpperLeg", "RightLowerLeg" },
	{ "RightAnkle", "RightLowerLeg", "RightFoot" },
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
	assert(
		src and src:IsA("Model"),
		`{SOURCE:format(i)} introuvable dans Workspace : importer le FBX d'abord`
	)
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

	-- l'unité du FBX dépend des réglages de l'importeur : on ramène la hauteur à 5,5 studs
	local _, imported = src:GetBoundingBox()
	if math.abs(imported.Y - 5.5) > 0.05 then
		src:ScaleTo(src:GetScale() * 5.5 / imported.Y)
		print(`[Contrat] {name} : hauteur importée {math.floor(imported.Y * 100) / 100} → 5,5 studs`)
	end

	local hrp = src:FindFirstChild("HumanoidRootPart") :: BasePart
	assert(hrp, `{name} : pas de HumanoidRootPart (importer avec le type de rig R15)`)

	-- Motor6D depuis les attachements « <Joint>RigAttachment » (sans rien déplacer)
	for _, j in JOINTS do
		local jointName, p0, p1 = j[1], src:FindFirstChild(j[2]), src:FindFirstChild(j[3])
		if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
			local existing = motorInto(p1)
			if not (existing and existing.Part0 == p0) then
				if existing then
					existing:Destroy()
				end
				local a0 = p0:FindFirstChild(jointName .. "RigAttachment")
				local a1 = p1:FindFirstChild(jointName .. "RigAttachment")
				local motor = Instance.new("Motor6D")
				motor.Name = jointName
				motor.Part0, motor.Part1 = p0, p1
				if a1 and a1:IsA("Attachment") then
					motor.C1 = a1.CFrame
					motor.C0 = if a0 and a0:IsA("Attachment")
						then a0.CFrame
						else p0.CFrame:ToObjectSpace(a1.WorldCFrame)
				else
					motor.C0 = p0.CFrame:ToObjectSpace(p1.CFrame)
				end
				motor.Parent = p1
			end
		end
	end

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
	print(
		`[Contrat] {name} OK : hauteur {math.floor(size.Y * 100) / 100} studs, HRP à {lift} studs des pieds`
	)
end
