--[[
	PurchaseService : achats en Robux (produits développeur). Seul script à définir ProcessReceipt.

	Règle (§26, §27 appliquées aux achats) : un reçu Roblox n'est déclaré « accordé » qu'une fois le lot
	crédité ET écrit dans le profil avec l'identifiant du reçu. Tant que l'écriture n'est pas confirmée,
	on répond NotProcessedYet : Roblox représentera le reçu, et l'identifiant gardé au profil empêche
	tout double crédit. Produit inconnu ou profil absent : jamais d'accord, rien n'est donné.
	Le seul produit est un tirage payant : il n'est pas crédité là où Roblox les restreint (PolicyService).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ProductsConfig = require(script.Parent.Parent.Config.ProductsConfig)
local Rewards = require(script.Parent.Parent.Rules.Rewards)

local PurchaseService = {}

local ctx
local deps
local byProductId: { [number]: ProductsConfig.Product } = {}
local POLICY_WAIT_SECONDS = 10

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
	-- Tirage payant : jamais crédité à un joueur dont le pays restreint les objets aléatoires payants, même si
	-- son client a forcé l'achat (le bouton ne lui est pas proposé). Non accordé = remboursé par Roblox.
	-- Un reçu déjà crédité (écriture à confirmer) suit son cours ; au retour d'un joueur, on laisse le temps
	-- à la politique d'être lue avant de décider.
	if not Rewards.hasPurchase(data, purchaseId) then
		local session = deps.Sessions.get(player)
		local deadline = os.clock() + POLICY_WAIT_SECONDS
		while session ~= nil and not session.policyKnown and os.clock() < deadline do
			task.wait(0.25)
			session = deps.Sessions.get(player)
		end
		if session == nil or session.paidRandomAllowed ~= true then
			warn(
				`[Purchase] {info.PlayerId} {purchaseId} : tirage payant non autorisé pour ce joueur, non crédité`
			)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		data = deps.Profiles.get(player)
		if data == nil then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
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
