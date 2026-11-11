--[[
	PurchaseService : achats en Robux (produits développeur). Seul script à définir ProcessReceipt.

	Règle (§26, §27 appliquées aux achats) : un reçu Roblox n'est déclaré « accordé » qu'une fois le lot
	crédité ET écrit dans le profil avec l'identifiant du reçu. Tant que l'écriture n'est pas confirmée,
	on répond NotProcessedYet : Roblox représentera le reçu, et l'identifiant gardé au profil empêche
	tout double crédit. Produit inconnu ou profil absent : jamais d'accord, rien n'est donné.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ProductsConfig = require(script.Parent.Parent.Config.ProductsConfig)
local Rewards = require(script.Parent.Parent.Rules.Rewards)

local PurchaseService = {}

local ctx
local deps
local byProductId: { [number]: ProductsConfig.Product } = {}

function PurchaseService.init(context, dependencies)
	ctx = context
	deps = dependencies
	for _, product in ProductsConfig do
		if product.id > 0 then
			byProductId[product.id] = product
		end
	end
end

local function processReceipt(info: { [string]: any }): Enum.ProductPurchaseDecision
	local product = byProductId[info.ProductId]
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if product == nil or player == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = deps.Profiles.get(player)
	if data == nil then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	local applied = Rewards.applyPurchase(data, purchaseId, product.bundle, ctx)
	if applied then
		deps.State.markDirty(player)
		deps.State.notify(player, { kind = "purchase", product = product.label })
		print(`[Purchase] {player.UserId} {product.label} ({purchaseId}) crédité`)
	end
	local saved = deps.Profiles.saveAndWait(player, function(savedData)
		return Rewards.hasPurchase(savedData, purchaseId)
	end, ctx.Balance.purchases.saveTimeoutSeconds)
	if not saved then
		warn(
			`[Purchase] {player.UserId} {purchaseId} : écriture non confirmée, reçu représenté plus tard`
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PurchaseService.start()
	MarketplaceService.ProcessReceipt = function(info)
		local ok, decision = pcall(processReceipt, info)
		if not ok then
			warn(`[Purchase] erreur : {decision}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return decision
	end
end

return PurchaseService
