--!strict
--[[
	RateLimiter : seau à jetons, un par joueur et par action (§25).
	Pur (l'heure est passée en argument) donc testable avec Lune.
	Un refus est silencieux : jamais de bannissement sur un simple pic de latence.
]]

export type Bucket = { rate: number, burst: number, tokens: number, last: number? }

local RateLimiter = {}

function RateLimiter.new(ratePerSecond: number, burst: number): Bucket
	return { rate = ratePerSecond, burst = burst, tokens = burst, last = nil }
end

function RateLimiter.allow(bucket: Bucket, now: number): boolean
	local last = bucket.last
	if last ~= nil then
		bucket.tokens = math.min(bucket.burst, bucket.tokens + (now - last) * bucket.rate)
	end
	bucket.last = now
	if bucket.tokens >= 1 then
		bucket.tokens -= 1
		return true
	end
	return false
end

return RateLimiter
