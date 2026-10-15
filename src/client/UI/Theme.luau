--!strict
--[[
	Theme : identité visuelle du HUD, style « simulateur Roblox » V3 validé sur maquette.
	Palette du dossier (§20) + vert d'action et rouge de fermeture.
	Icônes : `image` = asset du rendu Blender quand il existe, sinon `fallback` (emoji).
]]

local Theme = {}

Theme.Colors = table.freeze({
	Nuit = Color3.fromHex("#242036"),
	Violet = Color3.fromHex("#7642A3"),
	Cyan = Color3.fromHex("#13A6B5"),
	Or = Color3.fromHex("#D7A746"),
	Creme = Color3.fromHex("#F4EEE7"),
	Contour = Color3.fromHex("#1B1530"),
	Action = Color3.fromHex("#33B84A"),
	Fermer = Color3.fromHex("#E0233F"),
	Gris = Color3.fromHex("#8A84A3"),
	Orange = Color3.fromHex("#E06A1F"),
	Blanc = Color3.new(1, 1, 1),
})

Theme.Fonts = table.freeze({
	Display = Font.fromName("LuckiestGuy"),
	Body = Font.fromName("FredokaOne"),
})

Theme.Stroke = table.freeze({ Text = 3, Frame = 4 })
Theme.BaseResolution = Vector2.new(1280, 720)
Theme.MinTouch = 48

Theme.Icons = table.freeze({
	Power = { image = "", fallback = "💪" },
	DJ = { image = "", fallback = "🎧" },
	Ticket = { image = "", fallback = "🎟️" },
	Book = { image = "", fallback = "📖" },
	Crew = { image = "", fallback = "🎧" },
	Style = { image = "", fallback = "👑" },
	Settings = { image = "", fallback = "⚙️" },
	Unknown = { image = "", fallback = "❔" },
})

-- Éclaircit (k > 0) ou assombrit (k < 0) une couleur, pour les dégradés en relief
function Theme.shade(color: Color3, k: number): Color3
	if k >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), k)
	end
	return color:Lerp(Color3.new(0, 0, 0), -k)
end

-- Enfants communs d'un bloc « en relief » : coins, contour sombre, dégradé vertical
-- `color` peut être une Color3 ou un état Fusion de Color3.
function Theme.bevel(scope: any, color: any, radius: number?): { Instance }
	return {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, radius or 14) }),
		scope:New("UIStroke")({
			Color = Theme.Colors.Contour,
			Thickness = Theme.Stroke.Frame,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		scope:New("UIGradient")({
			Rotation = 90,
			Color = scope:Computed(function(use)
				local c: Color3 = use(color)
				return ColorSequence.new({
					ColorSequenceKeypoint.new(0, Theme.shade(c, 0.45)),
					ColorSequenceKeypoint.new(0.5, c),
					ColorSequenceKeypoint.new(1, Theme.shade(c, -0.25)),
				})
			end),
		}),
	}
end

return Theme
