--!strict
--[[
	Ambience : coucher de soleil appliqué côté client au démarrage (spec refonte §7.3).
	Rien n'est modifié côté serveur ni dans la place : les changements de Lighting faits par un
	LocalScript restent locaux. « Effets réduits » coupe le bloom.

	Une seule Atmosphere est prise en compte par Roblox : on règle celle de la place si elle existe.
	Le bloom de la place est coupé localement pour ne pas s'additionner à BC_Bloom.
]]

local Lighting = game:GetService("Lighting")

local Ambience = {}

local function ensure<T>(className: string, name: string): T
	local existing = Lighting:FindFirstChild(name)
	if existing then
		return existing :: any
	end
	local created = Instance.new(className :: any)
	created.Name = name
	created.Parent = Lighting
	return created :: any
end

function Ambience.start(scope: any, deps: any)
	-- valeurs réglées en Play : 18,2 / 2 rendaient les personnages presque noirs
	Lighting.ClockTime = 17.7
	Lighting.Brightness = 2.4
	Lighting.OutdoorAmbient = Color3.fromHex("#9A7AA8")
	Lighting.Ambient = Color3.fromHex("#5A4870")

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or ensure("Atmosphere", "BC_Atmosphere")
	atmosphere.Color = Color3.fromHex("#E89A9A")
	atmosphere.Decay = Color3.fromHex("#6A3A7A")
	atmosphere.Density = 0.3
	atmosphere.Haze = 1.2

	for _, effect in Lighting:GetChildren() do
		if effect:IsA("BloomEffect") and effect.Name ~= "BC_Bloom" then
			effect.Enabled = false
		end
	end
	local bloom: BloomEffect = ensure("BloomEffect", "BC_Bloom")
	bloom.Intensity = 0.8
	bloom.Size = 28
	bloom.Threshold = 0.95

	local grade: ColorCorrectionEffect = ensure("ColorCorrectionEffect", "BC_ColorCorrection")
	grade.Saturation = 0.12
	grade.Contrast = 0.08

	local reduced = deps.UiState.settings.reducedEffects
	local function apply()
		bloom.Enabled = not deps.peek(reduced)
	end
	apply()
	scope:Observer(reduced):onChange(apply)
end

return Ambience
