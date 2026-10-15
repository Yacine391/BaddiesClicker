--[[
	MaintenanceService : interrupteurs serveur pour couper TEMPORAIREMENT une décision durable si un bug
	critique apparaît (§36), sans republier le jeu. Une décision coupée est refusée avec la raison
	"maintenance" ; rien n'est supprimé (jamais de drop en attente effacé pour résoudre un incident).

	Décisions qu'on peut couper : Roll, AcceptDrop, RefuseDrop, Rebirth, OpenChest.
	Une décision est coupée si l'une de ces deux sources le dit :
	- DataStore « BC_Ops_v1 » (Studio : « BC_Ops_STUDIO_v1 »), clé « maintenance », valeur
	  { Roll = true, Rebirth = true, ... } : relue toutes les 60 s par chaque serveur. Se modifie depuis le
	  Creator Hub (Data Stores Manager) ou la barre de commande de Studio : voir docs/OPERATIONS.md.
	- Attribut `BC_Maintenance` de ServerScriptService, ex. "Roll,Rebirth" : effet immédiat sur CE serveur
	  (tests dans Studio, onglet Serveur de la barre de commande).
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local MaintenanceService = {}

MaintenanceService.ACTIONS = table.freeze({ "Roll", "AcceptDrop", "RefuseDrop", "Rebirth", "OpenChest" })
local KEY = "maintenance"
local ATTRIBUTE = "BC_Maintenance"

local ctx
local fromStore: { [string]: boolean } = {}
local warned = false

function MaintenanceService.init(context)
	ctx = context
end

local function attributeFlags(): { [string]: boolean }
	local flags = {}
	local value = ServerScriptService:GetAttribute(ATTRIBUTE)
	if type(value) == "string" then
		for name in string.gmatch(value, "[^,%s]+") do
			flags[name] = true
		end
	end
	return flags
end

function MaintenanceService.isDisabled(action: string): boolean
	return fromStore[action] == true or attributeFlags()[action] == true
end

-- Décisions actuellement coupées (pour le snapshot : le client grise les boutons)
function MaintenanceService.disabledList(): { string }
	local list = {}
	for _, action in MaintenanceService.ACTIONS do
		if MaintenanceService.isDisabled(action) then
			table.insert(list, action)
		end
	end
	return list
end

local function refresh(store: DataStore)
	local ok, value = pcall(function()
		return store:GetAsync(KEY)
	end)
	if not ok then
		if not warned then
			warned = true
			warn(
				`[Maintenance] lecture impossible (accès API ?) : interrupteurs DataStore ignorés. {value}`
			)
		end
		return
	end
	local flags = {}
	if type(value) == "table" then
		for _, action in MaintenanceService.ACTIONS do
			if value[action] == true then
				flags[action] = true
			end
		end
	end
	local before = table.concat(MaintenanceService.disabledList(), ",")
	fromStore = flags
	local after = table.concat(MaintenanceService.disabledList(), ",")
	if before ~= after then
		warn(`[Maintenance] décisions coupées : {if after == "" then "aucune" else after}`)
	end
end

function MaintenanceService.start()
	local save = ctx.Balance.save
	local name = if RunService:IsStudio() then save.studioOpsStoreName else save.opsStoreName
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(name)
	end)
	if not ok then
		warn(`[Maintenance] DataStore {name} indisponible : {store}`)
		return
	end
	task.spawn(function()
		while true do
			refresh(store)
			task.wait(save.maintenancePollSeconds)
		end
	end)
end

return MaintenanceService
