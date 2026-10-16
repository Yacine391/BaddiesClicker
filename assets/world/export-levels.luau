--[[
	Génère assets/world/Levels.rbxm à partir de LevelsBuilder.luau, sans Studio.
	Depuis la racine du repo :  lune run assets/world/export-levels

	Rojo synchronise ensuite le .rbxm dans Workspace.Levels (default.project.json). Pour changer les
	arènes : modifier LevelsBuilder.luau (ou Balance.levels), relancer cette commande, vérifier en Play.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local HERE = "assets/world/"
local Balance = require("../../src/shared/Balance")

local env = setmetatable({
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Font = roblox.Font,
	Enum = roblox.Enum,
}, { __index = _G })

local source = fs.readFile(HERE .. "LevelsBuilder.luau")
local build = luau.load(source, { debugName = "LevelsBuilder", environment = env })()

local levels = roblox.Instance.new("Folder")
levels.Name = "Levels"
build(levels, Balance.levels)

-- Vérifications du contrat (WorldService, DoorController, Controllers/Combat)
local parts, south = 0, -math.huge
for _, d in levels:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		south = math.max(south, d.CFrame.Position.Z + d.Size.Z / 2)
	end
	assert(
		d.ClassName ~= "ClickDetector" and d.ClassName ~= "ProximityPrompt",
		"ClickDetector ou ProximityPrompt interdits dans les arènes"
	)
end
for levelId = 1, #Balance.levels do
	local folder = levels:FindFirstChild(`Level{levelId}`)
	assert(folder ~= nil, `Level{levelId} manquant`)
	local arena = folder:FindFirstChild("Arena")
	assert(arena ~= nil and arena:IsA("BasePart"), `Level{levelId}.Arena manquant`)
	assert(
		arena.Transparency == 1 and arena.CanCollide == false,
		`Level{levelId}.Arena doit être invisible et sans collision`
	)
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = arena.CFrame:GetComponents()
	assert(
		r00 == 1
			and r11 == 1
			and r22 == 1
			and r01 == 0
			and r02 == 0
			and r10 == 0
			and r12 == 0
			and r20 == 0
			and r21 == 0,
		`Level{levelId}.Arena doit être alignée sur les axes`
	)
	local door = folder:FindFirstChild("Door")
	assert(
		door ~= nil and door:IsA("BasePart") and door.CanCollide,
		`Level{levelId}.Door manquante ou sans collision`
	)
end
-- Le décor peut dépasser un peu au-dessus de l'entrée, jamais dans la rue du lobby (bout à Z = -78,5)
assert(south <= -78.5 + 0.6, `les arènes empiètent sur le lobby : bord sud {south}`)

fs.writeFile(HERE .. "Levels.rbxm", roblox.serializeModel({ levels }))
print(`Levels.rbxm écrit : {#Balance.levels} arènes, {parts} pièces, bord sud {south}`)
