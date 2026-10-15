--!strict
--[[
	Reçus des mutations durables (module pur, testé dans tests/run.luau). Dossier §25, §26, §27.

	`requestId` est une clé de reprise, pas une permission : le client en génère un par décision
	(relance, drop accepté/refusé, renaissance) et le RÉUTILISE s'il doit renvoyer la même décision
	après une erreur ambiguë. Le serveur garde le reçu de la mutation la plus récente dans le profil
	(sauvegardé avec elle) : un renvoi du même requestId rend le même résultat, sans nouvel effet
	ni nouveau tirage. Seules les mutations réussies laissent un reçu.

	Les renvois plus anciens sont bloqués par les révisions (slotRevision, pendingRevision, run.id).
]]

export type Receipt = { requestId: string, action: string, result: { [string]: any }, revision: number }

local Receipts = {}

Receipts.MAX_LENGTH = 64

function Receipts.isValidRequestId(requestId: any): boolean
	return type(requestId) == "string" and #requestId >= 1 and #requestId <= Receipts.MAX_LENGTH
end

-- Reçu enregistré pour ce requestId, ou nil
function Receipts.find(data: any, requestId: string): Receipt?
	local receipt = data.lastMutation
	if type(receipt) == "table" and receipt.requestId == requestId then
		return receipt :: Receipt
	end
	return nil
end

-- Après une mutation réussie : révision globale +1 et reçu durable (écrit avec la mutation)
function Receipts.record(data: any, requestId: string, action: string, result: { [string]: any }): Receipt
	data.revision += 1
	local receipt: Receipt =
		{ requestId = requestId, action = action, result = result, revision = data.revision }
	data.lastMutation = receipt
	return receipt
end

-- La copie sauvegardée contient-elle ce reçu ? (prédicat pour Profiles.saveAndWait)
function Receipts.isSaved(savedData: any, requestId: string): boolean
	return type(savedData) == "table"
		and type(savedData.lastMutation) == "table"
		and savedData.lastMutation.requestId == requestId
end

return Receipts
