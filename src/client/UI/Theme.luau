--!strict
--[[
	Theme : identité visuelle « mix A » (dominante cyan), validée sur prototypes
	(spec docs/superpowers/specs/2026-10-15-ui-lobby-refonte-design.md §3).

	Images : les PNG de assets/ui/png sont uploadés dans Roblox par l'utilisateur ; leurs IDs vont
	dans `Icons`, `Logo` et `Glow`. Tant qu'un ID est vide, les composants affichent un repli simple.

	TRANSITION : les clés de l'ancien style V3 (Nuit, Action, Fermer, Display, Body, bevel, Icons en
	PascalCase…) restent le temps que tous les composants soient refaits ; elles sont retirées à la fin
	de la refonte.
]]

local Theme = {}

local hex = Color3.fromHex

Theme.Colors = table.freeze({
	-- mix A
	Panel = hex("#100E1E"),
	PanelLine = hex("#A08CFF"),
	Accent = hex("#3EE6C8"),
	AccentLight = hex("#5FF3DA"),
	AccentDeep = hex("#13A6B5"),
	Accent2 = hex("#FF5FD2"),
	Accent2Light = hex("#FF9BE3"),
	Ink = hex("#0D0B16"),
	Text = hex("#FFFFFF"),
	TextDim = hex("#CFCAE6"),
	Book = hex("#3EE6C8"),
	Crew = hex("#B48CF0"),
	Style = hex("#FF5FD2"),
	Settings = hex("#CFCAE6"),
	Close = hex("#E0233F"),
	Principal = hex("#33B84A"),
	-- ancien style V3 (transition)
	Nuit = hex("#242036"),
	Violet = hex("#7642A3"),
	Cyan = hex("#13A6B5"),
	Or = hex("#D7A746"),
	Creme = hex("#F4EEE7"),
	Contour = hex("#1B1530"),
	Action = hex("#33B84A"),
	Fermer = hex("#E0233F"),
	Gris = hex("#8A84A3"),
	Orange = hex("#E06A1F"),
	Blanc = Color3.new(1, 1, 1),
})

Theme.Transparency = table.freeze({ Panel = 0.14, PanelLine = 0.72, Dim = 0.38 })
Theme.Radius = table.freeze({ Panel = 10, Button = 12 })

local function condensed(weight: Enum.FontWeight): Font
	return Font.fromName("RobotoCondensed", weight)
end

Theme.Fonts = table.freeze({
	Bold = condensed(Enum.FontWeight.Bold),
	ExtraBold = condensed(Enum.FontWeight.ExtraBold),
	Heavy = condensed(Enum.FontWeight.Heavy),
	-- ancien style V3 (transition)
	Display = condensed(Enum.FontWeight.Heavy),
	Body = condensed(Enum.FontWeight.Bold),
})

Theme.Stroke = table.freeze({ Text = 2, Frame = 2 })
Theme.BaseResolution = Vector2.new(1280, 720)
Theme.MinTouch = 48

-- IDs des images uploadées (assets/ui/README.md). "" = pas encore uploadée → repli.
Theme.Logo = ""
Theme.Glow = ""
Theme.GlowSlice = Rect.new(48, 48, 80, 80)

Theme.Icons = table.freeze({
	book = "",
	crew = "",
	style = "",
	settings = "",
	chevron = "",
	bolt = "",
	arm = "",
	ticket = "",
	door = "",
	lock = "",
	eye = "",
	crown = "",
	-- ancien style V3 (transition) : plus d'emoji, le repli est une initiale
	Power = { image = "", fallback = "P" },
	DJ = { image = "", fallback = "DJ" },
	Ticket = { image = "", fallback = "T" },
	Book = { image = "", fallback = "B" },
	Crew = { image = "", fallback = "C" },
	Style = { image = "", fallback = "S" },
	Settings = { image = "", fallback = "R" },
	Unknown = { image = "", fallback = "?" },
} :: any)

-- Éclaircit (k > 0) ou assombrit (k < 0) une couleur
function Theme.shade(color: Color3, k: number): Color3
	if k >= 0 then
		return color:Lerp(Color3.new(1, 1, 1), k)
	end
	return color:Lerp(Color3.new(0, 0, 0), -k)
end

-- Ancien style V3 (transition) : bloc « en relief »
function Theme.bevel(scope: any, color: any, radius: number?): { Instance }
	return {
		scope:New("UICorner")({ CornerRadius = UDim.new(0, radius or Theme.Radius.Panel) }),
		scope:New("UIStroke")({
			Color = Theme.Colors.Ink,
			Thickness = Theme.Stroke.Frame,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		}),
		scope:New("UIGradient")({
			Rotation = 90,
			Color = scope:Computed(function(use)
				local c: Color3 = use(color)
				return ColorSequence.new({
					ColorSequenceKeypoint.new(0, Theme.shade(c, 0.3)),
					ColorSequenceKeypoint.new(1, Theme.shade(c, -0.2)),
				})
			end),
		}),
	}
end

return Theme
