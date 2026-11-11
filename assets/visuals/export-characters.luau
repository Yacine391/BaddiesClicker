--[[
	Génère assets/visuals/Characters.rbxm à partir de CharactersBuilder.luau, sans Studio.
	Depuis la racine du repo :  lune run assets/visuals/export-characters

	Options :
	  --json <dossier>   écrit aussi un fichier JSON par modèle (pièces en repère monde) pour l'outil
	                     d'aperçu (assets/visuals/preview/render.mjs) ;
	  --only <Dossier>   ne construit que ce personnage (ex. B09_Cherry), sans écrire le .rbxm.

	Rojo synchronise le .rbxm dans ReplicatedStorage.Visuals.Characters (default.project.json).
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local HERE = "assets/visuals/"
local Catalog = require("../../src/shared/Catalog")

local env = setmetatable({
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	Enum = roblox.Enum,
}, { __index = _G })

local function load(name: string): any
	return luau.load(fs.readFile(HERE .. name .. ".luau"), { debugName = name, environment = env })()
end

local jsonDir: string? = nil
local only: string? = nil
do
	local args = process.args
	local i = 1
	while i <= #args do
		if args[i] == "--json" then
			jsonDir = args[i + 1]
			i += 1
		elseif args[i] == "--only" then
			only = args[i + 1]
			i += 1
		end
		i += 1
	end
end

local Kit = load("CharacterKit")
local Parts = load("CharacterParts")(Kit)
local Styles = load("CharacterStyles")(Kit, Parts)
local build = load("CharactersBuilder")(Kit, Parts, Styles)

local characters = roblox.Instance.new("Folder")
characters.Name = "Characters"
local counts = build(characters, only)

-- Vérifications du contrat (Followers, Podium, Combat, Portrait)
local BONES = {
	"HumanoidRootPart",
	"LowerTorso",
	"UpperTorso",
	"Head",
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
local MAX_PARTS = 260 -- budget par suiveur (§20 : vérifier les performances plutôt que multiplier les détails)

local function checkModel(model: any, path: string)
	assert(model.ClassName == "Model", `{path} n'est pas un Model`)
	assert(model.PrimaryPart ~= nil and model.PrimaryPart.Name == "HumanoidRootPart", `{path} : PrimaryPart`)
	assert(model.PrimaryPart.Anchored, `{path} : HumanoidRootPart doit être ancrée`)
	assert(model:FindFirstChildOfClass("AnimationController") ~= nil, `{path} : AnimationController manquant`)
	assert(model:FindFirstChild("AuraAttachment", true) ~= nil, `{path} : AuraAttachment manquant`)
	assert(model:FindFirstChild("NameTagAttachment", true) ~= nil, `{path} : NameTagAttachment manquant`)
	for _, name in BONES do
		assert(model:FindFirstChild(name) ~= nil, `{path} : os {name} manquant`)
	end
	local parts, lowest = 0, math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			parts += 1
			assert(not d.CanCollide, `{path}.{d.Name} : collision interdite`)
			if d.Name ~= "HumanoidRootPart" then
				assert(not d.Anchored, `{path}.{d.Name} : seule la racine est ancrée`)
			end
			if d.Transparency < 1 then
				lowest = math.min(lowest, d.CFrame.Position.Y - math.max(d.Size.X, d.Size.Y, d.Size.Z) / 2)
			end
		end
	end
	assert(parts <= MAX_PARTS, `{path} : {parts} pièces, budget {MAX_PARTS}`)
	assert(lowest > -0.6, `{path} : pièce sous le sol ({lowest})`)
end

local function dumpModel(model: any): { any }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			local shape = "box"
			if d.ClassName == "WedgePart" then
				shape = "wedge"
			elseif d:FindFirstChildOfClass("SpecialMesh") then
				shape = "ell"
			elseif d.Shape == roblox.Enum.PartType.Ball then
				shape = "ball"
			elseif d.Shape == roblox.Enum.PartType.Cylinder then
				shape = "cyl"
			end
			table.insert(list, {
				name = d.Name,
				shape = shape,
				size = { d.Size.X, d.Size.Y, d.Size.Z },
				cf = { d.CFrame:GetComponents() },
				color = "#" .. d.Color:ToHex(),
				transparency = d.Transparency,
				neon = d.Material == roblox.Enum.Material.Neon,
				metal = d.Material == roblox.Enum.Material.Metal,
			})
		end
	end
	return list
end

local total, models = 0, 0
for _, folder in characters:GetChildren() do
	for _, model in folder:GetChildren() do
		local path = `{folder.Name}.{model.Name}`
		checkModel(model, path)
		models += 1
		total += counts[path] or 0
		if jsonDir then
			fs.writeFile(`{jsonDir}/{folder.Name}_{model.Name}.json`, serde.encode("json", dumpModel(model)))
		end
	end
end

-- Chaque identité du catalogue public doit avoir ses modèles (aucun contenu annoncé sans visuel, §30)
if only == nil then
	for _, id in Catalog.baddieOrder do
		local def = Catalog.baddies[id]
		local folder = characters:FindFirstChild(`{def.code}_{def.name}`)
		assert(folder ~= nil, `baddie sans modèle : {def.code}_{def.name}`)
		for look = 1, 3 do
			assert(
				folder:FindFirstChild(string.format("Look%02d", look)),
				`{folder.Name} : Look{look} manquant`
			)
		end
	end
	for _, id in Catalog.crewOrder do
		local def = Catalog.crew[id]
		local folder = characters:FindFirstChild(`{def.code}_{def.name}`)
		assert(
			folder ~= nil and folder:FindFirstChild("Base"),
			`compagnon sans modèle : {def.code}_{def.name}`
		)
	end
	fs.writeFile(HERE .. "Characters.rbxm", roblox.serializeModel({ characters }))
	print(`Characters.rbxm écrit : {models} modèles, {total} pièces visibles`)
else
	print(`{only} : {models} modèles, {total} pièces visibles (aucun .rbxm écrit)`)
end
for path, count in counts do
	print(`  {path} : {count}`)
end
