--!strict
--[[
	Statistiques de jeu : partie pure (testée dans tests/run.luau). Dossier §29 (indicateurs), §36, [R7].
	MetricsService envoie les événements à AnalyticsService ; ce module décide QUOI envoyer et QUAND.

	- Étapes d'accueil (funnel « onboarding ») : chacune une seule fois par joueur, mémorisée dans le profil.
	- Temps de jeu cumulé (secondes en session, pas l'horloge du téléphone) : temps jusqu'au premier combat,
	  au premier boss, durée d'un parcours.
	- Relances jusqu'à une découverte : compteur remis à zéro à chaque nouvelle identité.
	- Aucune donnée personnelle : l'identifiant Roblox suffit à AnalyticsService.
]]

export type Step = { step: number, name: string }

local Metrics = {}

-- Étapes de l'accueil, dans l'ordre naturel du jeu
Metrics.ONBOARDING = table.freeze({
	joined = { step = 1, name = "Profil chargé" },
	firstTrain = { step = 2, name = "Premier entraînement" },
	firstCrew = { step = 3, name = "Malik obtenu" },
	firstCombat = { step = 4, name = "Premier combat" },
	firstBoss = { step = 5, name = "Premier boss vaincu" },
	secondDistrict = { step = 6, name = "Deuxième quartier" },
	runComplete = { step = 7, name = "Parcours terminé" },
	firstRebirth = { step = 8, name = "Première renaissance" },
} :: { [string]: Step })

-- true la première fois seulement (clé mémorisée dans le profil)
function Metrics.once(data: any, key: string): boolean
	local seen = data.analytics.once
	if seen[key] == true then
		return false
	end
	seen[key] = true
	return true
end

-- Temps de jeu total en secondes : sessions précédentes + session en cours
function Metrics.playSeconds(data: any, sessionSeconds: number): number
	return math.floor(data.analytics.playSeconds + math.max(0, sessionSeconds))
end

-- Fin de session : ajoute la durée au cumul du profil
function Metrics.closeSession(data: any, sessionSeconds: number)
	data.analytics.playSeconds += math.max(0, sessionSeconds)
end

-- Une relance de plus ; renvoie le nombre de relances qu'il a fallu si elle découvre une identité
function Metrics.onRoll(data: any, isNew: boolean): number?
	data.analytics.rollsSinceDiscovery += 1
	if not isNew then
		return nil
	end
	local count = data.analytics.rollsSinceDiscovery
	data.analytics.rollsSinceDiscovery = 0
	return count
end

-- Début d'un parcours (profil neuf ou renaissance), en temps de jeu
function Metrics.startRun(data: any, playSeconds: number)
	data.analytics.runStartedAt = playSeconds
end

function Metrics.runSeconds(data: any, playSeconds: number): number
	return math.max(0, playSeconds - data.analytics.runStartedAt)
end

-- Paquets de puissance (évite des valeurs uniques innombrables dans les champs du tableau de bord)
function Metrics.powerBucket(power: number): string
	if power < 10 then
		return "<10"
	end
	local magnitude = 10 ^ math.floor(math.log10(power))
	local lead = math.floor(power / magnitude)
	local low = if lead >= 5 then 5 * magnitude elseif lead >= 2 then 2 * magnitude else magnitude
	return `{math.floor(low)}+`
end

return Metrics
