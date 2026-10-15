--!strict
--[[
	Formation : qui suit l'avatar, à quelle place, et comment les suiveurs rattrapent leur cible.
	Pur : positions en tables {x, y, z} (pas de Vector3), aucun require. Testé par tests/client/run.luau.
	Dossier §28 : principale + 3 exposées + 2 compagnons au maximum, affichage fusionné si la
	principale est aussi exposée.
]]

export type Member = { id: string, kind: "baddie" | "crew" }
export type Point = { x: number, y: number, z: number }

local MAX_DISPLAY = 3
local MAX_CREW = 2
local FIRST_ROW_Z = 4 -- studs derrière l'avatar
local ROW_STEP_Z = 3
local SIDE_X = 3
local SNAP_DISTANCE = 40

local Formation = {}

function Formation.members(principalId: string?, display: { string }, crew: { string }): { Member }
	local members: { Member } = {}
	if principalId ~= nil then
		table.insert(members, { id = principalId, kind = "baddie" })
	end
	local shown = 0
	for _, id in display do
		if id ~= principalId and shown < MAX_DISPLAY then
			table.insert(members, { id = id, kind = "baddie" })
			shown += 1
		end
	end
	for index, id in crew do
		if index > MAX_CREW then
			break
		end
		table.insert(members, { id = id, kind = "crew" })
	end
	return members
end

-- Rang 1 : juste derrière. Ensuite gauche/droite, une rangée de plus tous les deux suiveurs.
function Formation.offset(index: number): { x: number, z: number }
	if index <= 1 then
		return { x = 0, z = FIRST_ROW_Z }
	end
	local row = math.floor(index / 2)
	local side = if index % 2 == 0 then -1 else 1
	return { x = side * SIDE_X, z = FIRST_ROW_Z + row * ROW_STEP_Z }
end

function Formation.step(pos: Point, target: Point, dt: number): Point
	local dx, dy, dz = target.x - pos.x, target.y - pos.y, target.z - pos.z
	if math.sqrt(dx * dx + dy * dy + dz * dz) > SNAP_DISTANCE then
		return { x = target.x, y = target.y, z = target.z }
	end
	local alpha = 1 - 0.001 ^ dt
	return { x = pos.x + dx * alpha, y = pos.y + dy * alpha, z = pos.z + dz * alpha }
end

return Formation
