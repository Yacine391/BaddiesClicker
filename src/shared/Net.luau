--[[
	Net : noms des remotes et des intentions. Contrat complet : docs/CONTRACT.md.
	Les RemoteEvents sont déclarés de façon statique dans default.project.json
	(ReplicatedStorage/Remotes), donc ils existent avant tout script.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {
	INTENT = "Intent", -- client → serveur : FireServer(action, payload?)
	STATE = "State", -- serveur → client : snapshot complet de l'état du joueur
	RESULT = "Result", -- serveur → client : événement ponctuel { kind = ..., ... }
	COMBAT = "Combat", -- serveur → client : flux de la rencontre en cours { t = ..., ... }

	Actions = table.freeze({
		Hello = "Hello", -- « je suis prêt, envoie-moi mon état »
		Train = "Train", -- une action d'entraînement (hors combat)
		Attack = "Attack", -- une attaque { encounterId, targetId? } (en combat)
		StartWave = "StartWave", -- relancer un niveau depuis son arène { levelId }
		-- Lot P2 (décisions durables, réponse par Result { kind = "mutation" }) :
		Roll = "Roll", -- { requestId, slotId, slotRevision }
		AcceptDrop = "AcceptDrop", -- { requestId, baddieId, slotRevision, pendingRevision }
		RefuseDrop = "RefuseDrop", -- { requestId, baddieId, pendingRevision }
		Rebirth = "Rebirth", -- { requestId, expectedRunId }
		OpenChest = "OpenChest", -- { requestId } (coffre de compagnon, 1 ticket compagnon)
		-- Lot P2 (choix immédiats, sans écriture prioritaire) :
		SetActive = "SetActive", -- { slotId }
		SetRollLock = "SetRollLock", -- { slotId, locked }
		SetDisplay = "SetDisplay", -- { ids } (exposition, 3 max)
		SetLook = "SetLook", -- { baddieId, look }
		UpgradeCrew = "UpgradeCrew", -- { crewId } (dépense niveau + 1 copies)
		EquipCrew = "EquipCrew", -- { ids } (2 compagnons possédés maximum)
		SetStyle = "SetStyle", -- { slot, id? } (cosmétique ou titre débloqué ; id absent = retirer)
		DevSetMastery = "DevSetMastery", -- { baddieId, xp } (Studio uniquement)
		DevGrant = "DevGrant", -- { what = "tickets" | "crewTickets" | "drop" | "finishRun", baddieId? } (Studio)
	}),
}

function Net.remote(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
