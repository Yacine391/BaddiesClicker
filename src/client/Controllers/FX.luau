--!strict
--[[
	FX : auras des personnages (§19, §20). Chaque personnage a sa propre aura ;
	« Effets réduits » divise le débit des particules par 4, pour soi et pour les autres.
]]

local FX = {}

local REDUCED_FACTOR = 0.25

type Aura = { emitter: ParticleEmitter, baseRate: number }

local auras: { Aura } = {}
local reduced = false

--[[
	Une aura par identité (§17, §18, §20) : quatre systèmes paramétrés produisent toutes les auras.
	  halo   lueur douce autour du buste        sparks  étincelles vives
	  rise   traits qui montent (égaliseur)     drift   formes lentes qui tournent (pétales, prismes)
	  ground anneaux bas, au niveau du sol
	L'aura appartient au personnage : sa couleur n'est pas celle de sa rareté.
]]
type Preset = { kind: string, from: string, to: string, rate: number, size: number? }

local AURAS: { [string]: Preset } = {
	maya = { kind = "halo", from = "#F2A65A", to = "#E06A1F", rate = 8 },
	lina = { kind = "ground", from = "#8FA98B", to = "#B7F27A", rate = 7 },
	jade = { kind = "rise", from = "#13A6B5", to = "#5FE2FF", rate = 7, size = 0.1 },
	iris = { kind = "drift", from = "#B9A3D9", to = "#D6336C", rate = 5 },
	sienna = { kind = "sparks", from = "#B87333", to = "#FFB36B", rate = 9 },
	nova = { kind = "sparks", from = "#D7A746", to = "#FFFFF0", rate = 10 },
	zuri = { kind = "halo", from = "#7642A3", to = "#B48CF0", rate = 11, size = 0.5 },
	vega = { kind = "drift", from = "#30D5C8", to = "#7642A3", rate = 8, size = 0.4 },
	cherry = { kind = "sparks", from = "#FF3B5C", to = "#8A1C2B", rate = 9, size = 0.3 },
	enzo = { kind = "halo", from = "#F2684A", to = "#C94E34", rate = 6 },
	malik = { kind = "rise", from = "#13A6B5", to = "#5FE2FF", rate = 10 },
	rafael = { kind = "ground", from = "#2E9E5B", to = "#F4F1EA", rate = 7 },
	dario = { kind = "sparks", from = "#C9B38A", to = "#D7A746", rate = 6 },
	kenji = { kind = "rise", from = "#FF5FD2", to = "#B48CF0", rate = 11 },
	amine = { kind = "drift", from = "#FFD86B", to = "#30D5C8", rate = 8, size = 0.36 },
	-- auras de la garde-robe du joueur (§19 : troisième couche, Controllers/Wearables)
	aura_spark = { kind = "sparks", from = "#FFFFFF", to = "#3EE6C8", rate = 12, size = 0.26 },
	aura_neon = { kind = "rise", from = "#FF5FD2", to = "#3EE6C8", rate = 12, size = 0.18 },
}

local function fade(from: number, to: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, to) })
end

local function emitter(preset: Preset, attachment: Attachment): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromHex(preset.from), Color3.fromHex(preset.to))
	e.Rate = preset.rate
	local size = preset.size
	if preset.kind == "rise" then
		-- traits fins qui montent (égaliseur de Malik, lignes de Jade)
		e.LightEmission = 1
		e.Size = fade(size or 0.15, 0.05)
		e.Squash = NumberSequence.new(1.5)
		e.Transparency = fade(0.2, 1)
		e.Lifetime = NumberRange.new(0.6, 0.9)
		e.Speed = NumberRange.new(2, 3)
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(25, 25)
	elseif preset.kind == "sparks" then
		e.LightEmission = 1
		e.Size = fade(size or 0.22, 0)
		e.Transparency = fade(0, 1)
		e.Lifetime = NumberRange.new(0.5, 1)
		e.Speed = NumberRange.new(1.5, 3.5)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Drag = 2
	elseif preset.kind == "drift" then
		-- formes lentes qui tournent en tombant (pétales d'Iris, prismes de Vega)
		e.LightEmission = 0.5
		e.Size = fade(size or 0.3, 0.1)
		e.Squash = NumberSequence.new(-0.4)
		e.Transparency = fade(0.15, 1)
		e.Lifetime = NumberRange.new(1.6, 2.4)
		e.Speed = NumberRange.new(0.5, 1)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-90, 90)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -0.6, 0)
	elseif preset.kind == "ground" then
		-- anneaux bas : particules larges et plates qui s'étalent près du sol
		e.LightEmission = 0.7
		e.Size = fade(size or 0.5, 1.6)
		e.Squash = NumberSequence.new(-2.2)
		e.Transparency = fade(0.35, 1)
		e.Lifetime = NumberRange.new(0.9, 1.3)
		e.Speed = NumberRange.new(0.1, 0.3)
		e.SpreadAngle = Vector2.new(180, 180)
	else
		-- halo discret autour du buste
		e.LightEmission = 0.8
		e.Size = fade(size or 0.35, 0)
		e.Transparency = fade(0.3, 1)
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(0.6, 1.2)
		e.SpreadAngle = Vector2.new(180, 180)
	end
	e.Parent = attachment
	return e
end

local function apply(aura: Aura)
	aura.emitter.Rate = aura.baseRate * (if reduced then REDUCED_FACTOR else 1)
end

-- Ajoute l'aura de `id` sur le modèle ; sans effet si l'identité n'a pas d'aura ou si l'attache manque.
-- Les auras « ground » partent des pieds (GroundAttachment), les autres du buste (AuraAttachment).
function FX.attach(model: Instance, id: string)
	local preset = AURAS[id]
	if preset == nil then
		return
	end
	local attachment = if preset.kind == "ground" then model:FindFirstChild("GroundAttachment", true) else nil
	attachment = attachment or model:FindFirstChild("AuraAttachment", true)
	if attachment == nil or not attachment:IsA("Attachment") then
		return
	end
	local created = emitter(preset, attachment)
	local aura = { emitter = created, baseRate = created.Rate }
	apply(aura)
	table.insert(auras, aura)
	created.Destroying:Connect(function()
		local index = table.find(auras, aura)
		if index then
			table.remove(auras, index)
		end
	end)
end

function FX.start(scope: any, deps: any)
	local setting = deps.UiState.settings.reducedEffects
	reduced = deps.peek(setting)
	scope:Observer(setting):onChange(function()
		reduced = deps.peek(setting)
		for _, aura in auras do
			apply(aura)
		end
	end)
end

return FX
