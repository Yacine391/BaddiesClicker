--[[
	SettingsService : réglages du joueur gardés au profil (§22 « choix sauvegardés »). Règles : Rules/Settings.
	SetSetting { key, value: boolean } : choix immédiat, autorisé à tout moment (même en combat), ignoré
	s'il est invalide. Écrit avec l'autosave : un réglage n'est jamais une décision durable.
]]

local SettingsRules = require(script.Parent.Parent.Rules.Settings)

local SettingsService = {}

local ctx
local deps

function SettingsService.init(context, dependencies)
	ctx = context
	deps = dependencies
end

function SettingsService.onSetSetting(player: Player, payload: { [any]: any }?)
	local data = deps.Profiles.get(player)
	if payload == nil or data == nil then
		return
	end
	if SettingsRules.set(data, payload.key, payload.value, ctx) then
		deps.State.markDirty(player)
	end
end

return SettingsService
