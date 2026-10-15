--[[
	Panneau des slots de TEST (codeur A, Studio uniquement) : en haut à droite, touche F4 pour le replier.
	Il existe pour tester le lot P2 côté serveur avant les écrans Slots / Drops / Rebirth du codeur B.

	- Slots : contenu, temporaire ou conservé, principale, verrou ; RELANCER (deux clics : confirmer le
	  remplacement), PRINCIPALE, VERROU.
	- Drops en attente : ACCEPTER 1 (remplace le temporaire) et REFUSER 1, avec confirmation.
	- Renaissance : quand le niveau 10 est terminé, avec le texte de ce qui sera gardé ou effacé.
	- Outils Studio : +10 tickets, drop de Vega, finir le parcours, maîtrise 5 pour la principale.
	- Réponses des décisions durables (Result kind = "mutation") ; RÉESSAYER renvoie le MÊME requestId.
]]

local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Catalog = require(Shared:WaitForChild("Catalog"))
local TestCatalog = require(Shared:WaitForChild("TestCatalog"))
local Net = require(Shared:WaitForChild("Net"))

local NUIT = Color3.fromHex("#242036")
local NUIT_CLAIR = Color3.fromHex("#3A3550")
local OR = Color3.fromHex("#D7A746")
local CREME = Color3.fromHex("#F4EEE7")
local CYAN = Color3.fromHex("#13A6B5")
local ROUGE = Color3.fromRGB(205, 45, 70)
local VERT = Color3.fromRGB(60, 160, 90)

local CONFIRM_SECONDS = 4

local REASONS = {
	busy = "une décision est déjà en cours",
	saving = "la sauvegarde précédente est incertaine : réessaie",
	cooldown = "attends 2 s entre deux relances",
	in_combat = "impossible en combat",
	stale = "l'état a changé : vérifie et recommence",
	locked = "slot verrouillé",
	no_ticket = "pas de ticket baddie",
	no_drop = "plus de drop de cette baddie",
	not_finished = "termine le niveau 10 d'abord",
	no_temporary = "aucun slot temporaire",
	duplicate = "requestId déjà utilisé pour une autre action",
	error = "erreur serveur : réessaie",
	invalid = "demande invalide",
}

local DevSlotsPanel = {}

local function nameOf(id: string?): string
	if id == nil then
		return "vide"
	end
	local def = Catalog.baddies[id] or TestCatalog.baddies[id]
	return if def then def.name else id
end

local function multiplierOf(id: string?): string
	local def = if id then Catalog.baddies[id] else nil
	return if def then `×{def.multiplier}` else ""
end

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent ~= nil then
		instance.Parent = parent
	end
	return instance
end

local function rounded(instance: Instance, radius: number)
	make("UICorner", { CornerRadius = UDim.new(0, radius) }, instance)
end

local function list(parent: Instance, padding: number, horizontal: boolean?)
	make("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, padding),
		FillDirection = if horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical,
		Wraps = horizontal == true, -- les boutons passent à la ligne au lieu de déborder
	}, parent)
end

local function text(parent: Instance, value: string, size: number, color: Color3, order: number): TextLabel
	return make("TextLabel", {
		LayoutOrder = order,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Enum.Font.GothamBold,
		TextSize = size,
		TextColor3 = color,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = value,
	}, parent)
end

function DevSlotsPanel.start(state)
	local player = Players.LocalPlayer
	local snapshot: any = nil
	local confirmUntil: { [string]: number } = {}
	local lastMessage = "Prêt. Les décisions durables attendent la sauvegarde avant de répondre."
	local lastRequest: { action: string, payload: { [string]: any } }? = nil
	local canRetry = false
	local open = true

	local gui = make("ScreenGui", { Name = "DevSlotsPanel", ResetOnSpawn = false, DisplayOrder = 5 })
	local panel = make("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = NUIT,
		BackgroundTransparency = 0.08,
	}, gui)
	rounded(panel, 12)
	local pad = make("UIPadding", {}, panel)
	for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
		(pad :: any)[side] = UDim.new(0, 10)
	end
	list(panel, 6)
	local header = make("TextButton", {
		LayoutOrder = 1,
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Size = UDim2.new(1, 0, 0, 16),
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextColor3 = OR,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}, panel)
	local body = make("Frame", {
		LayoutOrder = 2,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	}, panel)
	list(body, 6)
	gui.Parent = player:WaitForChild("PlayerGui")

	local render: () -> ()

	local function send(action: string, payload: { [string]: any })
		lastRequest = { action = action, payload = payload }
		canRetry = false
		lastMessage = `{action} envoyé… (sauvegarde)`
		state.send(action, payload)
		render()
	end

	local function durable(action: string, payload: { [string]: any })
		payload.requestId = HttpService:GenerateGUID(false)
		send(action, payload)
	end

	-- Bouton à deux clics : le premier arme la confirmation (texte d'avertissement), le second agit
	local function button(
		parent: Instance,
		key: string,
		label: string,
		warning: string?,
		color: Color3,
		onClick: () -> ()
	)
		local armed = warning ~= nil and (confirmUntil[key] or 0) > os.clock()
		local b = make("TextButton", {
			Size = UDim2.new(0, 0, 0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = if armed then ROUGE else color,
			Font = Enum.Font.GothamBlack,
			TextSize = 12,
			TextColor3 = CREME,
			Text = `  {if armed then warning :: string else label}  `,
		}, parent)
		rounded(b, 8)
		b.Activated:Connect(function()
			if warning ~= nil and not armed then
				confirmUntil[key] = os.clock() + CONFIRM_SECONDS
				render()
				task.delay(CONFIRM_SECONDS, render)
				return
			end
			confirmUntil[key] = nil
			onClick()
		end)
		return b
	end

	local function card(order: number, title: string, color: Color3): Frame
		local c = make("Frame", {
			LayoutOrder = order,
			BackgroundColor3 = color,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, body)
		rounded(c, 8)
		local p = make("UIPadding", {}, c)
		for _, side in { "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" } do
			(p :: any)[side] = UDim.new(0, 6)
		end
		list(c, 4)
		text(c, title, 13, CREME, 1)
		local actions = make("Frame", {
			LayoutOrder = 2,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
		}, c)
		list(actions, 4, true)
		return actions
	end

	render = function()
		for _, child in body:GetChildren() do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		header.Text = if open
			then "SLOTS · P2 (test Studio) — F4 ou clic pour replier"
			else "SLOTS · P2 ▸ (F4)"
		body.Visible = open
		local s = snapshot
		if not open or s == nil or s.slots == nil then
			return
		end
		if s.mode == "combat" then
			text(body, "En combat : relances, drops et renaissance attendent la fin.", 12, CREME, 1)
			return
		end

		local rolls = s.rolls or {}
		local guarantee = if rolls.bookComplete
			then "Book complet : table standard"
			else `garantie dans {rolls.untilGuarantee} (1 chance sur {#(rolls.missing or {})})`
		text(
			body,
			`Tickets {s.tickets.baddie} · relances {rolls.baddie} · {guarantee}{if s.saving
				then " · SAUVEGARDE…"
				else ""}`,
			12,
			CREME,
			1
		)

		local order = 10
		local temporary = nil
		for _, slot in s.slots do
			order += 1
			if slot.temporary then
				temporary = slot
			end
			local tags = {}
			table.insert(tags, if slot.temporary then "TEMPORAIRE" else "CONSERVÉ")
			if slot.active then
				table.insert(tags, "★ PRINCIPALE")
			end
			if slot.rollLocked then
				table.insert(tags, "VERROUILLÉ")
			end
			local title =
				`{string.upper(slot.id)} · {nameOf(slot.baddieId)} {multiplierOf(slot.baddieId)} · {table.concat(
					tags,
					" · "
				)}`
			local actions = card(order, title, if slot.active then NUIT_CLAIR else Color3.fromHex("#2E2A42"))
			if not slot.rollLocked then
				local warning = if slot.baddieId
					then `CONFIRMER : {nameOf(slot.baddieId)} sera remplacée`
					else "CONFIRMER LA RELANCE"
				button(actions, `roll:{slot.id}`, "RELANCER (1 ticket)", warning, OR, function()
					durable(Net.Actions.Roll, { slotId = slot.id, slotRevision = slot.revision })
				end)
			end
			if slot.baddieId and not slot.active then
				button(actions, `active:{slot.id}`, "PRINCIPALE", nil, CYAN, function()
					send(Net.Actions.SetActive, { slotId = slot.id })
				end)
			end
			if slot.baddieId or slot.rollLocked then
				button(
					actions,
					`lock:{slot.id}`,
					if slot.rollLocked then "DÉVERROUILLER" else "VERROU",
					nil,
					NUIT,
					function()
						send(Net.Actions.SetRollLock, { slotId = slot.id, locked = not slot.rollLocked })
					end
				)
			end
		end

		order = 100
		for id, count in s.pendingDrops or {} do
			order += 1
			local target = if temporary
				then `{string.upper(temporary.id)} ({nameOf(temporary.baddieId)})`
				else "?"
			local actions = card(
				order,
				`DROP · {nameOf(id)} ×{count} → remplacera {target}`,
				Color3.fromHex("#4B1D7A")
			)
			button(
				actions,
				`accept:{id}`,
				"ACCEPTER 1",
				`CONFIRMER : {nameOf(id)} dans {target}`,
				VERT,
				function()
					durable(Net.Actions.AcceptDrop, {
						baddieId = id,
						slotRevision = if temporary then temporary.revision else -1,
						pendingRevision = s.pendingRevision,
					})
				end
			)
			button(actions, `refuse:{id}`, "REFUSER 1", "CONFIRMER : supprimer 1", ROUGE, function()
				durable(Net.Actions.RefuseDrop, { baddieId = id, pendingRevision = s.pendingRevision })
			end)
		end

		local rebirth = s.rebirth or {}
		if rebirth.available then
			local nextCount = (rebirth.count or 0) + 1
			local effect = if rebirth.promotesNext
				then `{string.upper(rebirth.temporarySlotId or "?")} devient conservé, un nouveau temporaire s'ouvre`
				else `{string.upper(rebirth.temporarySlotId or "?")} reste temporaire : son contenu sera effacé`
			local actions = card(
				200,
				`RENAISSANCE {nextCount} · {effect} · +{rebirth.baddieTickets} tickets`,
				NUIT_CLAIR
			)
			button(
				actions,
				"rebirth",
				`RENAÎTRE ({nextCount})`,
				"CONFIRMER : puissance → 1",
				OR,
				function()
					durable(Net.Actions.Rebirth, { expectedRunId = s.run.id })
				end
			)
		end

		local tools = card(300, "Outils Studio", Color3.fromHex("#2E2A42"))
		button(tools, "dev:tickets", "+10 TICKETS", nil, NUIT, function()
			send(Net.Actions.DevGrant, { what = "tickets" })
		end)
		button(tools, "dev:drop", "DROP VEGA", nil, NUIT, function()
			send(Net.Actions.DevGrant, { what = "drop", baddieId = "vega" })
		end)
		button(tools, "dev:run", "FINIR LE PARCOURS", nil, NUIT, function()
			send(Net.Actions.DevGrant, { what = "finishRun" })
		end)
		if s.active and s.active.baddieId then
			button(tools, "dev:mastery", "MAÎTRISE 5", nil, NUIT, function()
				send(Net.Actions.DevSetMastery, { baddieId = s.active.baddieId, xp = 250 })
			end)
		end

		local status = card(400, lastMessage, NUIT)
		if canRetry and lastRequest ~= nil then
			local request = lastRequest
			button(status, "retry", "RÉESSAYER (même requestId)", nil, OR, function()
				send(request.action, request.payload)
			end)
		end
	end

	local function signature(s: any): string
		if s == nil or s.slots == nil then
			return "none"
		end
		local parts = { s.mode, tostring(s.saving), tostring(s.tickets.baddie), tostring(s.pendingRevision) }
		for _, slot in s.slots do
			table.insert(parts, `{slot.id}:{slot.baddieId}:{slot.revision}:{slot.rollLocked}:{slot.active}`)
		end
		local rolls = s.rolls or {}
		table.insert(parts, `{rolls.baddie}:{s.run and s.run.id}:{s.rebirth and s.rebirth.available}`)
		table.insert(parts, tostring(s.active and s.active.baddieId))
		return table.concat(parts, "|")
	end

	local lastSignature = ""
	state.onState(function(s)
		snapshot = s
		local sig = signature(s)
		if sig ~= lastSignature then
			lastSignature = sig
			render()
		end
	end)

	state.onResult(function(event)
		if event.kind ~= "mutation" then
			return
		end
		local r = event.result or {}
		if not event.ok then
			lastMessage = `{event.action} refusé : {REASONS[event.reason] or event.reason}`
			canRetry = event.reason == "saving" or event.reason == "error"
		else
			local saved = if event.confirmed then "sauvegardé ✓" else "écriture NON confirmée"
			canRetry = not event.confirmed
			if event.action == "Roll" then
				local extra = if r.guaranteed then " (garantie)" else ""
				local new = if r.isNew then " · NOUVELLE au Baddies Book !" else ""
				lastMessage =
					`Relance {r.slotId} : {nameOf(r.previousId)} → {nameOf(r.baddieId)}{extra}{new} · {saved}`
			elseif event.action == "AcceptDrop" then
				lastMessage =
					`{nameOf(r.baddieId)} acceptée dans {r.slotId} (reste {r.remaining}) · {saved}`
			elseif event.action == "RefuseDrop" then
				lastMessage = `Drop de {nameOf(r.baddieId)} refusé (reste {r.remaining}) · {saved}`
			elseif event.action == "Rebirth" then
				local parts = { `Renaissance {r.count}` }
				if r.promotedSlotId then
					table.insert(parts, `{r.promotedSlotId} conservé, {r.newSlotId} ouvert`)
				end
				if r.lostBaddieId then
					table.insert(parts, `{nameOf(r.lostBaddieId)} effacée de {r.clearedSlotId}`)
				end
				if r.fallback then
					table.insert(parts, `principale → {r.activeSlotId} ({r.fallback})`)
				end
				lastMessage = `{table.concat(parts, " · ")} · {saved}`
			end
			if event.replay then
				lastMessage ..= " (renvoi du même reçu)"
			end
		end
		render()
	end)

	local function toggle()
		open = not open
		render()
	end
	header.Activated:Connect(toggle)
	ContextActionService:BindAction("BC_DevSlotsPanel", function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			toggle()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.F4)

	render()
end

return DevSlotsPanel
