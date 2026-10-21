--[[
	ProfileAdmin : consulter et restaurer un profil (§27, §36). Réservé aux responsables du jeu.
	Le jeu ne l'utilise JAMAIS : aucun remote n'y mène, et ServerScriptService n'est pas visible des clients.

	À lancer dans Studio, place publiée ouverte, « Studio Access to API Services » activé, pendant un Play,
	dans la barre de commande de l'onglet **Serveur** (procédure complète : docs/OPERATIONS.md) :

		local Admin = require(game.ServerScriptService.Server.Admin.ProfileAdmin)
		Admin.versions(123456789)                 -- 10 dernières versions du profil de production
		Admin.show(123456789, "VERSION")          -- résumé d'une version (sans argument : la plus récente)
		Admin.restore(123456789, "VERSION")       -- réécrit cette version comme profil courant

	Par défaut : store de PRODUCTION (BC_Profiles_v1). Dernier argument `true` : store Studio.
	`restore` termine la session du joueur s'il est en ligne (il sera reconnecté sur la version restaurée,
	qui repasse par les garde-fous au chargement). Chaque action est écrite dans la sortie, pour le journal.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local ProfileStore = require(script.Parent.Parent.Packages.ProfileStore)
local ProfileTemplate = require(script.Parent.Parent.Rules.ProfileTemplate)

local ProfileAdmin = {}

local stores: { [string]: any } = {}

local function storeFor(studio: boolean?): (any, string)
	local name = if studio then Balance.save.studioStoreName else Balance.save.storeName
	if stores[name] == nil then
		stores[name] = ProfileStore.New(name, ProfileTemplate.new({ Balance = Balance }))
	end
	return stores[name], name
end

local function keyOf(userId: number): string
	assert(type(userId) == "number" and userId > 0, "userId invalide")
	return `Player_{userId}`
end

local function date(millis: number?): string
	if millis == nil then
		return "?"
	end
	return DateTime.fromUnixTimestampMillis(millis):FormatUniversalTime("YYYY-MM-DD HH:mm:ss", "fr-fr")
		.. " UTC"
end

local function summary(data: any): string
	local slots = {}
	for id, slot in data.slots or {} do
		table.insert(
			slots,
			`{id}={if slot.baddieId == "" then "vide" else slot.baddieId}{if slot.conserved then "*" else ""}`
		)
	end
	table.sort(slots)
	local drops = {}
	for id, count in data.pendingDrops or {} do
		table.insert(drops, `{id}×{count}`)
	end
	local book = 0
	for _ in data.discoveredBaddies or {} do
		book += 1
	end
	local receipt = if type(data.lastMutation) == "table" and data.lastMutation.requestId
		then `{data.lastMutation.action} {data.lastMutation.requestId}`
		else "aucun"
	return `schéma {data.schemaVersion} · puissance {data.power} · rebirths {data.rebirths} · run {data.run and data.run.id}`
		.. ` · tickets {data.tickets and data.tickets.baddie}/{data.tickets and data.tickets.crew}`
		.. ` · slots [{table.concat(slots, ", ")}] (* = conservé) · principale {data.activeSlotId}`
		.. ` · drops [{table.concat(drops, ", ")}] · Book {book} · dernier reçu {receipt}`
end

-- Liste les versions les plus récentes (date, identifiant de version, résumé)
function ProfileAdmin.versions(userId: number, count: number?, studio: boolean?)
	local store, name = storeFor(studio)
	local query = store:VersionQuery(keyOf(userId), Enum.SortDirection.Descending)
	print(`[ProfileAdmin] {name} / {keyOf(userId)} : versions les plus récentes`)
	print(
		"  (une version de l'heure UTC en cours est écrasée par la sauvegarde suivante : restaurer une heure passée)"
	)
	for index = 1, count or 10 do
		local profile = query:NextAsync()
		if profile == nil then
			break
		end
		local info = profile.KeyInfo
		print(`  {index}. {date(info and info.UpdatedTime)} · version {info and info.Version}`)
		print(`     {summary(profile.Data)}`)
	end
end

-- Résumé d'une version précise (ou de la plus récente)
function ProfileAdmin.show(userId: number, version: string?, studio: boolean?)
	local store, name = storeFor(studio)
	local profile = store:GetAsync(keyOf(userId), version)
	if profile == nil then
		warn(
			`[ProfileAdmin] {name} / {keyOf(userId)} : aucune donnée pour la version {tostring(version)}`
				.. " (absente, ou écrasée dans la même heure UTC)"
		)
		return nil
	end
	print(
		`[ProfileAdmin] {name} / {keyOf(userId)} · version {version or "courante"} : {summary(profile.Data)}`
	)
	return profile.Data
end

-- Réécrit une ancienne version comme profil courant (la version actuelle reste dans l'historique DataStore)
function ProfileAdmin.restore(userId: number, version: string, studio: boolean?)
	assert(type(version) == "string" and #version > 0, "version obligatoire (voir Admin.versions)")
	local store, name = storeFor(studio)
	local profile = store:GetAsync(keyOf(userId), version)
	if profile == nil then
		warn(
			`[ProfileAdmin] restauration annulée : version {version} introuvable ou écrasée. Roblox ne garde que`
				.. " la 1re sauvegarde de chaque heure UTC (les suivantes de la même heure l'écrasent) :"
				.. " choisir une version d'une heure passée dans Admin.versions."
		)
		return false
	end
	print(
		`[ProfileAdmin] RESTAURATION {name} / {keyOf(userId)} ← version {version} : {summary(profile.Data)}`
	)
	profile:SetAsync()
	print("[ProfileAdmin] écrit. Vérifier avec Admin.show(userId) puis une connexion du joueur.")
	return true
end

return ProfileAdmin
