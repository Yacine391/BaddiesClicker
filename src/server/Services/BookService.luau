--[[
	BookService : Baddies Book, exposition et looks (lot P2, proposition contrat v2 du codeur B).
	Règles dans Rules/Collection. Choix immédiats, hors combat ; une intention invalide est ignorée.

	- SetDisplay { ids }          : 3 identités découvertes maximum, sans doublon (apparence uniquement)
	- SetLook { baddieId, look }  : look débloqué par la maîtrise
]]

local CollectionRules = require(script.Parent.Parent.Rules.Collection)

local BookService = {}

local ctx
local deps

function BookService.init(context, dependencies)
	ctx = context
	deps = dependencies
end

local function ready(player: Player): any?
	local data = deps.Profiles.get(player)
	local session = deps.Sessions.get(player)
	if data == nil or session == nil or session.inCombat or session.encounter ~= nil then
		return nil
	end
	return data
end

function BookService.onSetDisplay(player: Player, payload: { [any]: any }?)
	local data = ready(player)
	if payload == nil or data == nil then
		return
	end
	if CollectionRules.setDisplay(data, payload.ids, ctx) == nil then
		deps.State.refreshAttributes(player, data)
		deps.State.markDirty(player)
	end
end

function BookService.onSetLook(player: Player, payload: { [any]: any }?)
	local data = ready(player)
	if payload == nil or data == nil then
		return
	end
	if CollectionRules.setLook(data, payload.baddieId, payload.look, ctx) == nil then
		deps.State.refreshAttributes(player, data)
		deps.State.markDirty(player)
	end
end

return BookService
