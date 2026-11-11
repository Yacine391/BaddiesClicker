--!strict
--[[
	SoundModel : quel son jouer pour quel moment (module pur, testé par tests/client/run.luau).
	Les identifiants des sons sont dans Controllers/Sound ; ici, seulement les clés.
	Règle : un son par moment, jamais deux pour le même événement, rien pour les ticks passifs.
]]

local SoundModel = {}

-- Son d'un événement Result (StateController.onResult), ou nil
function SoundModel.forResult(event: { [string]: any }): string?
	local kind = event.kind
	if kind == "ticket" or kind == "masteryUp" or kind == "crewLevelUp" or kind == "playtimeReady" then
		return "ping"
	elseif kind == "levelCleared" then
		return "win"
	elseif kind == "death" then
		return "lose"
	elseif kind == "discovery" or kind == "achievement" or kind == "rebirth" then
		return "fanfare"
	elseif kind == "crewJoined" then
		return if event.isNew == false then "ping" else "fanfare"
	elseif kind == "dailyReward" or kind == "playtimeReward" or kind == "purchase" then
		return "coin"
	elseif kind == "combatLeft" or kind == "combatInvalid" then
		return "deny"
	elseif kind == "mutation" then
		if event.ok == false then
			return "deny"
		elseif event.action == "Roll" or event.action == "OpenChest" then
			return "roll"
		end
	end
	return nil
end

-- Son d'un message du flux Combat, ou nil
function SoundModel.forCombat(message: { [string]: any }): string?
	local t = message.t
	if t == "hit" then
		return if message.killed then "kill" else "hit"
	elseif t == "impact" then
		return if message.hit then "hurt" else nil
	elseif t == "telegraph" then
		return "warn"
	end
	return nil
end

-- Musique à jouer : "combat" en rencontre, "lobby" sinon ; nil si la musique est coupée ou l'état inconnu
function SoundModel.music(snapshot: any, musicOn: boolean): string?
	if not musicOn or type(snapshot) ~= "table" then
		return nil
	end
	return if snapshot.mode == "combat" then "combat" else "lobby"
end

-- Intervalle minimal entre deux déclenchements du même son (secondes) : pas de mitraillage au clic
SoundModel.MIN_INTERVAL =
	table.freeze({ tap = 0.07, hit = 0.06, ping = 0.15, warn = 0.2 } :: { [string]: number })

function SoundModel.allowed(key: string, now: number, lastPlayedAt: number?): boolean
	local gap = SoundModel.MIN_INTERVAL[key]
	return gap == nil or lastPlayedAt == nil or now - lastPlayedAt >= gap
end

return SoundModel
