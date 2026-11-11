--!strict
--[[
	Réglages du joueur (module pur, testé). Dossier §21, §22 : « choix sauvegardés ».
	Uniquement des interrupteurs d'affichage et de confort : aucun réglage ne change un gain, une
	cadence serveur ni une règle. Le client les applique ; le serveur ne fait que les garder.
	Clés et valeurs par défaut : Shared/Balance.settings.
]]

local Settings = {}

-- SetSetting { key, value } ; true si le profil a changé
function Settings.set(data: any, key: any, value: any, ctx: any): boolean
	if type(key) ~= "string" or ctx.Balance.settings[key] == nil or type(value) ~= "boolean" then
		return false
	end
	if data.settings[key] == value then
		return false
	end
	data.settings[key] = value
	return true
end

-- Vue du client : toutes les clés connues, en booléens
function Settings.view(data: any, ctx: any): { [string]: boolean }
	local view = {}
	for key, default in ctx.Balance.settings do
		local stored = if type(data.settings) == "table" then data.settings[key] else nil
		view[key] = if type(stored) == "boolean" then stored else default
	end
	return view
end

return Settings
