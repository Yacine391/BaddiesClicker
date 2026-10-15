--[[
	WardrobeService : succès, garde-robe, titres et badges Roblox (dossier §19). Règles dans Rules/Achievements.

	- Vérification groupée (Balance.achievements.checkSeconds) : dès qu'une condition est remplie, le succès
	  est accordé une fois, ses récompenses écrites en priorité (saveNow) et annoncées (Result « achievement »).
	- Badges Roblox : attribués côté serveur avec les IDs de Config/BadgesConfig ; un échec est réessayé
	  plus tard (badgeRetrySeconds) sans jamais redonner les récompenses internes. Rien dans Studio.
	- SetStyle { slot, id? } : porter un cosmétique débloqué (ou un titre), hors combat ; id absent = retirer.
]]

local BadgeService = game:GetService("BadgeService")
local RunService = game:GetService("RunService")

local AchievementRules = require(script.Parent.Parent.Rules.Achievements)
local BadgesConfig = require(script.Parent.Parent.Config.BadgesConfig)

local WardrobeService = {}

local ctx
local deps

function WardrobeService.init(context, dependencies)
	ctx = context
	deps = dependencies
end

-- Intention « SetStyle »
function WardrobeService.onSetStyle(player: Player, payload: { [any]: any }?)
	local data = deps.Profiles.get(player)
	local session = deps.Sessions.get(player)
	if payload == nil or data == nil or session == nil or session.inCombat or session.encounter ~= nil then
		return
	end
	if AchievementRules.setStyle(data, payload.slot, payload.id, ctx) == nil then
		deps.State.refreshAttributes(player, data)
		deps.State.markDirty(player)
	end
end

local function awardBadges(player: Player, data, session)
	if RunService:IsStudio() or session.badgeBusy then
		return
	end
	if session.nextBadgeAt ~= nil and os.clock() < session.nextBadgeAt then
		return
	end
	local pending = {}
	for id in data.pendingBadges do
		local badgeId = BadgesConfig[id]
		if type(badgeId) == "number" and badgeId > 0 then
			table.insert(pending, { id = id, badgeId = badgeId })
		end
	end
	if #pending == 0 then
		return
	end

	session.badgeBusy = true
	task.spawn(function()
		local failed = false
		for _, entry in pending do
			local ok, awarded = pcall(function()
				return BadgeService:AwardBadgeAsync(player.UserId, entry.badgeId)
			end)
			if not (ok and awarded) then
				-- déjà possédé, ou réponse perdue : la vérité est chez Roblox
				ok, awarded = pcall(function()
					return BadgeService:UserHasBadgeAsync(player.UserId, entry.badgeId)
				end)
			end
			local current = deps.Profiles.get(player)
			if ok and awarded and current ~= nil then
				current.pendingBadges[entry.id] = nil
			else
				failed = true
				warn(
					`[WardrobeService] badge {entry.id} non attribué à {player.UserId} : réessai plus tard`
				)
			end
		end
		session.badgeBusy = false
		if failed then
			session.nextBadgeAt = os.clock() + ctx.Balance.achievements.badgeRetrySeconds
		end
	end)
end

local function tick()
	for player, session in deps.Sessions.all() do
		local data = deps.Profiles.get(player)
		if data ~= nil and not session.mutating then
			local earned = AchievementRules.check(data, ctx)
			if #earned > 0 then
				deps.Profiles.saveNow(player) -- récompenses uniques : écriture prioritaire (§27)
				for _, entry in earned do
					deps.State.notify(player, {
						kind = "achievement",
						id = entry.id,
						items = entry.items,
						titles = entry.titles,
					})
				end
				deps.State.markDirty(player)
			end
			awardBadges(player, data, session)
		end
	end
end

function WardrobeService.start()
	task.spawn(function()
		while true do
			task.wait(ctx.Balance.achievements.checkSeconds)
			local ok, err = pcall(tick)
			if not ok then
				warn(`[WardrobeService] {err}`)
			end
		end
	end)
end

return WardrobeService
