--!strict
--[[
	Theme : identité visuelle « mix A » (dominante cyan), validée sur prototypes
	(spec docs/superpowers/specs/2026-10-15-ui-lobby-refonte-design.md §3).

	Images : les PNG de assets/ui/png sont uploadés dans Roblox par l'utilisateur ; leurs IDs vont
	dans `Icons`, `Logo` et `Glow`. Tant qu'un ID est vide, les composants affichent un repli simple.
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
	Danger = hex("#FF3B5C"), -- zones de danger, PV bas, coup reçu (combat)
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
})

Theme.Stroke = table.freeze({ Text = 2, Frame = 2 })
Theme.BaseResolution = Vector2.new(1280, 720)
Theme.MinTouch = 48

-- IDs des images uploadées (assets/ui/README.md). "" = pas encore uploadée → repli.
Theme.Logo = "rbxassetid://104433435199565"
Theme.Glow = "rbxassetid://105925253038271" -- halo porté par Components/Halo, derrière les panneaux
Theme.GlowSlice = Rect.new(48, 48, 80, 80)

Theme.Icons = table.freeze({
	book = "rbxassetid://94716205629835",
	crew = "rbxassetid://113913955556099",
	style = "rbxassetid://71735145745689",
	settings = "rbxassetid://115418148096622",
	chevron = "rbxassetid://71242548714789",
	bolt = "rbxassetid://107048971234661",
	arm = "rbxassetid://139685984254923",
	ticket = "rbxassetid://73411537747382",
	door = "rbxassetid://109053980589787",
	lock = "rbxassetid://124733419973837",
	eye = "rbxassetid://138818406947967",
	crown = "rbxassetid://76335979670718",
})

return Theme
