--!strict
--[[
	Sound : effets sonores et musique (§22 « Paramètres : son », §36 « assets et sons autorisés »).
	Rendu local. Quoi jouer et quand : Logic/SoundModel (pur, testé). Réglages SONS et MUSIQUE sauvegardés.

	IDENTIFIANTS : par défaut, les effets pointent vers des sons livrés avec le client Roblox
	(`rbxasset://sounds/…`), utilisables sans droits ni upload. À VÉRIFIER dans Studio (un fichier absent
	donne seulement un avertissement dans la sortie), puis à remplacer par les sons choisis par l'équipe.
	La musique n'a pas de valeur par défaut : renseigner `MUSIC` avec des pistes dont l'équipe a les droits
	(""  = pas de musique, rien n'est joué).
]]

local SoundService = game:GetService("SoundService")

local Client = script.Parent.Parent
local SoundModel = require(Client.Logic.SoundModel)

local Sound = {}

type Spec = { id: string, volume: number, speed: number? }

local EFFECTS: { [string]: Spec } = {
	tap = { id = "rbxasset://sounds/clickfast.wav", volume = 0.22 }, -- entraînement
	hit = { id = "rbxasset://sounds/swordslash.wav", volume = 0.3 }, -- coup porté
	kill = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.4 }, -- ennemi vaincu
	hurt = { id = "rbxasset://sounds/hit.wav", volume = 0.5 }, -- coup reçu
	warn = { id = "rbxasset://sounds/switch.wav", volume = 0.25, speed = 0.8 }, -- zone de danger annoncée
	ping = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.35 }, -- petite annonce
	coin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.4, speed = 1.35 }, -- récompense
	roll = { id = "rbxasset://sounds/unsheath.wav", volume = 0.35 }, -- relance, coffre
	win = { id = "rbxasset://sounds/victory.wav", volume = 0.5 }, -- boss vaincu
	fanfare = { id = "rbxasset://sounds/victory.wav", volume = 0.5, speed = 1.2 }, -- découverte, succès
	lose = { id = "rbxasset://sounds/uuhhh.mp3", volume = 0.45 }, -- K.O.
	deny = { id = "rbxasset://sounds/switch.wav", volume = 0.3, speed = 0.6 }, -- refus
	open = { id = "rbxasset://sounds/switch.wav", volume = 0.25, speed = 1.2 }, -- fenêtre
	spin = { id = "rbxasset://sounds/clickfast.wav", volume = 0.3, speed = 1.4 }, -- cran de la roue
}

-- Musique : pistes à fournir (droits vérifiés), en boucle. "" = silence.
local MUSIC: { [string]: Spec } = {
	lobby = { id = "", volume = 0.25 },
	combat = { id = "", volume = 0.3 },
}

local sounds: { [string]: Sound } = {}
local lastPlayedAt: { [string]: number } = {}
local musicTrack: Sound? = nil
local musicKey: string? = nil
local soundOn = true

local function make(name: string, spec: Spec, looped: boolean): Sound
	local s = Instance.new("Sound")
	s.Name = "BC_" .. name
	s.SoundId = spec.id
	s.Volume = spec.volume
	s.PlaybackSpeed = spec.speed or 1
	s.Looped = looped
	s.Parent = SoundService
	return s
end

-- Joue l'effet `key` (clé de EFFECTS) si les sons sont actifs et s'il n'a pas été joué à l'instant
function Sound.play(key: string?)
	if key == nil or not soundOn then
		return
	end
	local sound = sounds[key]
	local now = os.clock()
	if sound == nil or not SoundModel.allowed(key, now, lastPlayedAt[key]) then
		return
	end
	lastPlayedAt[key] = now
	SoundService:PlayLocalSound(sound)
end

local function setMusic(key: string?)
	if key == musicKey then
		return
	end
	musicKey = key
	if musicTrack ~= nil then
		musicTrack:Stop()
		musicTrack:Destroy()
		musicTrack = nil
	end
	local spec = if key then MUSIC[key] else nil
	if spec ~= nil and spec.id ~= "" then
		local track = make("Music_" .. tostring(key), spec, true)
		track:Play()
		musicTrack = track
	end
end

function Sound.start(scope: any, deps: any)
	for key, spec in EFFECTS do
		sounds[key] = make(key, spec, false)
		table.insert(scope, sounds[key])
	end

	local settings = deps.UiState.settings
	soundOn = deps.peek(settings.sound)
	scope:Observer(settings.sound):onChange(function()
		soundOn = deps.peek(settings.sound)
	end)

	local function refreshMusic()
		setMusic(SoundModel.music(deps.peek(deps.Store.snapshot), deps.peek(settings.music)))
	end
	refreshMusic()
	scope:Observer(settings.music):onChange(refreshMusic)
	scope:Observer(deps.Store.snapshot):onChange(refreshMusic)

	scope:Observer(deps.UiState.trainPulse):onChange(function()
		Sound.play("tap")
	end)
	scope:Observer(deps.UiState.openWindow):onChange(function()
		Sound.play("open")
	end)
	deps.StateController.onResult(function(event)
		Sound.play(SoundModel.forResult(event))
	end)
	deps.StateController.onCombat(function(message)
		Sound.play(SoundModel.forCombat(message))
	end)

	table.insert(scope, function()
		setMusic(nil)
	end)
end

return Sound
