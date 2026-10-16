--!strict
--[[
	UiState : état purement local de l'interface (fenêtre ouverte, réglages, impulsions d'animation).
	Les réglages ne sont pas encore sauvegardés (P0) : le profil a `settings`, le contrat pas encore.
]]

local UiState = {}

UiState.openWindow = nil :: any -- Value<string?> : nil | "Book" | "Slots" | "Style" | "Crew" | "Settings"
UiState.settings = nil :: any -- { reducedEffects, showOthersFollowers, holdToTrain } : Value<boolean>
UiState.trainPulse = nil :: any -- Value<number>, +1 à chaque clic local accepté par Input

function UiState.init(scope: any)
	UiState.openWindow = scope:Value(nil)
	UiState.settings = {
		reducedEffects = scope:Value(false),
		showOthersFollowers = scope:Value(true),
		holdToTrain = scope:Value(false),
	}
	UiState.trainPulse = scope:Value(0)
end

return UiState
