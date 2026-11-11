--!strict
--[[
	UiState : état purement local de l'interface (fenêtre ouverte, réglages, impulsions d'animation).
	Les réglages sont sauvegardés par le serveur (`snapshot.settings`, intention SetSetting) : Controllers/Settings
	les relit au premier snapshot et envoie chaque changement.
]]

local UiState = {}

UiState.openWindow = nil :: any -- Value<string?> : nil | "Bonus" | "Book" | "Slots" | "Style" | "Crew" | "Settings"
UiState.settings = nil :: any -- { reducedEffects, showOthersFollowers, holdToTrain, sound, music } : Value<boolean>
UiState.trainPulse = nil :: any -- Value<number>, +1 à chaque clic local accepté par Input

function UiState.init(scope: any)
	UiState.openWindow = scope:Value(nil)
	UiState.settings = {
		reducedEffects = scope:Value(false),
		showOthersFollowers = scope:Value(true),
		holdToTrain = scope:Value(false),
		sound = scope:Value(true),
		music = scope:Value(true),
	}
	UiState.trainPulse = scope:Value(0)
end

return UiState
