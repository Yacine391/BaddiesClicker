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
	}),
}

function Net.remote(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end

return Net
