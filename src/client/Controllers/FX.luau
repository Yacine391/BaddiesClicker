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

local PRESETS: { [string]: (Attachment) -> ParticleEmitter } = {
	-- Maya : halo orange discret
	maya = function(attachment)
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromHex("#F2A65A"), Color3.fromHex("#E06A1F"))
		e.LightEmission = 0.8
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(0.6, 1.2)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Rate = 8
		e.Parent = attachment
		return e
	end,
	-- Malik : barres d'égaliseur cyan qui montent
	malik = function(attachment)
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(Color3.fromHex("#13A6B5"), Color3.fromHex("#5FE2FF"))
		e.LightEmission = 1
		e.Size =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.05) })
		e.Squash = NumberSequence.new(1.5)
		e.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.6, 0.9)
		e.Speed = NumberRange.new(2, 3)
		e.EmissionDirection = Enum.NormalId.Top
		e.SpreadAngle = Vector2.new(25, 25)
		e.Rate = 10
		e.Parent = attachment
		return e
	end,
}

local function apply(aura: Aura)
	aura.emitter.Rate = aura.baseRate * (if reduced then REDUCED_FACTOR else 1)
end

-- Ajoute l'aura de `id` sur le modèle (AuraAttachment) ; sans effet si l'identité n'a pas de preset
function FX.attach(model: Instance, id: string)
	local preset = PRESETS[id]
	local attachment = model:FindFirstChild("AuraAttachment", true)
	if preset == nil or attachment == nil or not attachment:IsA("Attachment") then
		return
	end
	local emitter = preset(attachment)
	local aura = { emitter = emitter, baseRate = emitter.Rate }
	apply(aura)
	table.insert(auras, aura)
	emitter.Destroying:Connect(function()
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
