--[[
	Génère assets/world/Lobby.rbxm à partir de LobbyBuilder.luau, sans Studio.
	Depuis la racine du repo :  lune run assets/world/export-lobby

	Rojo synchronise ensuite le .rbxm dans Workspace.Lobby. Pour changer le lobby : modifier
	LobbyBuilder.luau, relancer cette commande, vérifier en Play.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local HERE = "assets/world/"

-- Random de Roblox n'existe pas sous Lune : petit générateur déterministe (même graine, même ville)
local Random = {}
Random.__index = Random
function Random.new(seed: number)
	return setmetatable({ state = seed % 2147483647 }, Random)
end
function Random:NextInteger(min: number, max: number): number
	self.state = (self.state * 48271) % 2147483647
	return min + self.state % (max - min + 1)
end

local env = setmetatable({
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	Font = roblox.Font,
	Enum = roblox.Enum,
	Random = Random,
	task = { wait = function() end },
}, { __index = _G })

local source = fs.readFile(HERE .. "LobbyBuilder.luau")
local build = luau.load(source, { debugName = "LobbyBuilder", environment = env })()

local lobby = roblox.Instance.new("Model")
lobby.Name = "Lobby"
build(lobby)

local parts, north = 0, math.huge
local banned = 0
for _, d in lobby:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
		-- bord nord approché par les pièces non tournées (décor tourné : bancs, feuilles, loin de la rue)
		north = math.min(north, d.CFrame.Position.Z - d.Size.Z / 2)
	end
	if d.ClassName == "ClickDetector" or d.ClassName == "ProximityPrompt" or d.Name == "Barrier" then
		banned += 1
	end
end
assert(lobby:FindFirstChild("Spawn") and lobby.Spawn.ClassName == "SpawnLocation", "Lobby.Spawn manquant")
assert(lobby:FindFirstChild("Podium") and lobby.Podium:FindFirstChild("Stand"), "Lobby.Podium.Stand manquant")
assert(banned == 0, "ClickDetector, ProximityPrompt ou Barrier interdits dans le lobby")
assert(math.abs(north + 78.5) < 0.01, `bord nord attendu -78,5, obtenu {north}`)

fs.writeFile(HERE .. "Lobby.rbxm", roblox.serializeModel({ lobby }))
print(`Lobby.rbxm écrit : {parts} pièces, bord nord {north}`)
