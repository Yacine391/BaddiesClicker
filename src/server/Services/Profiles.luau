--[[
	Profiles : chargement et sauvegarde des profils avec ProfileStore (§27).
	ProfileStore gère le verrou de session, l'autosave et la sauvegarde à la fermeture.

	- Chargement impossible → on expulse ; jamais de profil neuf de remplacement.
	- Studio → DataStore de test séparé (BC_Profiles_STUDIO_v1).
	- Sans « Studio Access to API Services », ProfileStore passe tout seul en mode
	  mock : le jeu tourne, mais rien n'est sauvegardé entre deux Play.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)
local ProfileTemplate = require(script.Parent.Parent.Rules.ProfileTemplate)

local Profiles = {}

local ctx
local store
local active: { [Player]: any } = {}
local loadedListeners: { (Player, any) -> () } = {}
local releasingListeners: { (Player) -> () } = {}

function Profiles.init(context)
	ctx = context
	local save = ctx.Balance.save

	ProfileStore.SetConstant("AUTO_SAVE_PERIOD", save.autosaveSeconds)
	local storeName = if RunService:IsStudio() then save.studioStoreName else save.storeName
	store = ProfileStore.New(storeName, ProfileTemplate.new(ctx))

	ProfileStore.OnError:Connect(function(message, name, key)
		warn(`[Profiles] erreur DataStore ({name} / {key}) : {message}`)
	end)
	ProfileStore.OnCriticalToggle:Connect(function(isCritical)
		warn(`[Profiles] état critique DataStore : {isCritical}`)
	end)
end

-- fn(player, data) est appelée quand le profil d'un joueur est prêt
function Profiles.onLoaded(fn: (Player, any) -> ())
	table.insert(loadedListeners, fn)
end

-- fn(player) est appelée juste avant la fermeture de la session d'un joueur
function Profiles.onReleasing(fn: (Player) -> ())
	table.insert(releasingListeners, fn)
end

-- Données du profil actif, ou nil si le profil n'est pas (ou plus) chargé
function Profiles.get(player: Player): any?
	local profile = active[player]
	if profile ~= nil and profile:IsActive() then
		return profile.Data
	end
	return nil
end

local function loadPlayer(player: Player)
	local profile = store:StartSessionAsync(`Player_{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		if player.Parent == Players then
			player:Kick(
				"Ton profil n'a pas pu être chargé. Réessaie dans un instant : rien n'a été modifié."
			)
		end
		return
	end

	-- Un serveur plus ancien ne doit jamais réécrire un profil d'un schéma plus récent (§36).
	if (profile.Data.schemaVersion or 0) > ctx.Balance.save.schemaVersion then
		profile:EndSession()
		player:Kick("Ce serveur est plus ancien que ton profil. Rejoins un autre serveur.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		active[player] = nil
		player:Kick("Ta session s'est terminée (ouverte sur un autre serveur ?). Reconnecte-toi.")
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return
	end

	active[player] = profile
	for _, fn in loadedListeners do
		task.spawn(fn, player, profile.Data)
	end
end

local function releasePlayer(player: Player)
	for _, fn in releasingListeners do
		fn(player)
	end
	local profile = active[player]
	if profile ~= nil then
		profile:EndSession()
	end
end

function Profiles.start()
	Players.PlayerAdded:Connect(loadPlayer)
	Players.PlayerRemoving:Connect(releasePlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(loadPlayer, player)
	end
end

return Profiles
