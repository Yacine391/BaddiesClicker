--!strict
--[[
	PrimaryAction : ce que le bouton principal envoie selon le snapshot (§07, docs/CONTRACT.md).
	Hors combat : « Train ». En combat : « Attack » { encounterId } (sans targetId, le serveur
	prend l'ennemi le plus proche). Jamais les deux pour une même entrée.
	Pur, testé par tests/client/run.luau.
]]

export type Intent = { action: "Train" | "Attack", payload: { [string]: any }? }

local PrimaryAction = {}

function PrimaryAction.intent(snapshot: { [string]: any }?): Intent?
	if snapshot == nil then
		return nil
	end
	local combat = snapshot.combat
	if type(combat) == "table" and combat.active == true then
		if type(combat.encounterId) ~= "string" then
			return nil -- rencontre incomplète : on n'envoie rien plutôt qu'un Train refusé
		end
		return { action = "Attack", payload = { encounterId = combat.encounterId } }
	end
	return { action = "Train", payload = nil }
end

return PrimaryAction
