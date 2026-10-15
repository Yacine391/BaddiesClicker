--[[
	WorldService : lit les arènes de Workspace.Levels (contrat dans World/DevWorld.luau).
	Dans Studio uniquement, construit la carte grise de test si Workspace.Levels n'existe pas.
	La position du joueur est vérifiée ici : traverser un mur côté client ne donne
	ni combat ni gain dans une arène non accessible (§08).
]]

local RunService = game:GetService("RunService")

local DevWorld = require(script.Parent.Parent.World.DevWorld)

export type Arena = {
	levelId: number,
	bounds: { minX: number, maxX: number, minZ: number, maxZ: number },
	floorY: number,
	height: number,
}

local WorldService = {}

local arenas: { [number]: Arena } = {}

function WorldService.init(ctx)
	local levels = workspace:FindFirstChild("Levels")
	if levels == nil and RunService:IsStudio() then
		levels = DevWorld.build(ctx)
		print("[BaddieClicker] carte grise de test construite (Studio uniquement)")
	end
	if levels == nil then
		warn("[BaddieClicker] Workspace.Levels introuvable : aucun combat possible")
		return
	end
	for levelId = 1, #ctx.Balance.levels do
		local folder = levels:FindFirstChild(`Level{levelId}`)
		local zone = if folder then folder:FindFirstChild("Arena") else nil
		if zone ~= nil and zone:IsA("BasePart") then
			local p, s = zone.Position, zone.Size
			arenas[levelId] = {
				levelId = levelId,
				bounds = {
					minX = p.X - s.X / 2,
					maxX = p.X + s.X / 2,
					minZ = p.Z - s.Z / 2,
					maxZ = p.Z + s.Z / 2,
				},
				floorY = p.Y - s.Y / 2,
				height = s.Y,
			}
		end
	end
end

function WorldService.arena(levelId: number): Arena?
	return arenas[levelId]
end

function WorldService.isInside(arena: Arena, position: Vector3): boolean
	local b = arena.bounds
	return position.X >= b.minX
		and position.X <= b.maxX
		and position.Z >= b.minZ
		and position.Z <= b.maxZ
		and position.Y >= arena.floorY - 6
		and position.Y <= arena.floorY + arena.height + 6
end

function WorldService.levelAt(position: Vector3): number?
	for levelId, arena in arenas do
		if WorldService.isInside(arena, position) then
			return levelId
		end
	end
	return nil
end

return WorldService
