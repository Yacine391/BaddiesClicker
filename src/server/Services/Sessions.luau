--[[
	Sessions : état serveur NON sauvegardé de chaque joueur (§24 « session serveur uniquement »).
	Créée quand le profil est chargé, détruite au départ. En P1 elle portera aussi
	les HP, la rencontre en cours, la cible, etc.
]]

local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)

export type Session = {
	inCombat: boolean,
	buckets: { [string]: RateLimiter.Bucket },
	lastPassiveAt: number,
	hp: number, -- PV de combat (jamais sauvegardés)
	encounter: any?, -- rencontre en cours (Rules/Encounter)
	outsideSince: number?, -- depuis quand le joueur est hors de son arène
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
