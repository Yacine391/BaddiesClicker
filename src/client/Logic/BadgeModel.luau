--!strict
--[[
	BadgeModel : texte de la pastille rouge des tuiles du HUD (spec simulateur §4.1).
	Pur. Entrée : le badge déjà calculé par le HUD ("" = rien, "3" = compte, "NEW" = nouveauté).
]]

local BadgeModel = {}

function BadgeModel.pip(text: string?): string
	if text == nil or text == "" then
		return ""
	end
	local n = tonumber(text)
	if n == nil then
		return "!"
	end
	return if n >= 10 then "9+" else tostring(n)
end

-- Événement « crewJoined » : la pastille Crew ne s'allume que pour un compagnon nouveau (pas une copie).
-- Champ `isNew` absent : on garde l'ancien comportement (pastille).
function BadgeModel.crewJoinedIsNew(event: { [string]: any }): boolean
	return event.isNew ~= false
end

return BadgeModel
