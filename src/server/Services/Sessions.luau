--[[
	Sessions : état serveur NON sauvegardé de chaque joueur (§24 « session serveur uniquement »).
	Créée quand le profil est chargé, détruite au départ. Elle porte les PV et la rencontre
	en cours (P1), et la file des décisions durables (P2).
]]

local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

export type Session = {
	inCombat: boolean,
	buckets: { [string]: RateLimiter.Bucket },
	lastPassiveAt: number,
	hp: number, -- PV de combat (jamais sauvegardés)
	encounter: any?, -- rencontre en cours (Rules/Encounter)
	outsideSince: number?, -- depuis quand le joueur est hors de son arène
	mutating: boolean, -- une décision durable est en cours d'écriture (MutationService)
	unconfirmed: any?, -- décision appliquée dont l'écriture n'est pas encore confirmée
	lastRollAt: number?, -- dernière relance acceptée (2 s minimum entre deux)
	lastChestAt: number?, -- dernier coffre de compagnon ouvert (même délai)
	badgeBusy: boolean, -- attribution de badges Roblox en cours
	nextBadgeAt: number?, -- prochain essai après un échec de BadgeService
	startedAt: number, -- début de la session (temps de jeu pour les statistiques)
	lastDeathAt: number?, -- dernière mort (statistique « reprise après une mort »)
}

local Sessions = {}

local byPlayer: { [Player]: Session } = {}

function Sessions.create(player: Player): Session
	local session: Session = {
		inCombat = false,
		buckets = {},
		lastPassiveAt = os.clock(),
		hp = 0,
		encounter = nil,
		outsideSince = nil,
		mutating = false,
		unconfirmed = nil,
		lastRollAt = nil,
		lastChestAt = nil,
		badgeBusy = false,
		nextBadgeAt = nil,
		startedAt = os.clock(),
		lastDeathAt = nil,
	}
	byPlayer[player] = session
	return session
end

function Sessions.get(player: Player): Session?
	return byPlayer[player]
end

function Sessions.remove(player: Player)
	byPlayer[player] = nil
end

function Sessions.all(): { [Player]: Session }
	return byPlayer
end

function Sessions.bucket(session: Session, action: string, rate: number, burst: number): RateLimiter.Bucket
	local bucket = session.buckets[action]
	if bucket == nil then
		bucket = RateLimiter.new(rate, burst)
		session.buckets[action] = bucket
	end
	return bucket
end

return Sessions
