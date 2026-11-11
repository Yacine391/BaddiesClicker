--!strict
--[[
	Theme : identité « simulateur vif » (spec docs/superpowers/specs/2026-11-11-ui-lobby-simulateur-design.md §3) :
	une couleur par fonction (même couleur dans le HUD et le lobby), FredokaOne, contours Ink épais.
	Les jetons « mix A » restent pour les écrans pas encore refaits (lot 2).

	Images : les PNG de assets/ui/png sont uploadés dans Roblox par l'utilisateur ; leurs IDs vont
	dans `Icons`, `Logo` et `Glow`. Tant qu'un ID est vide, les composants affichent un repli simple.
]]

local Theme = {}

local hex = Color3.fromHex

Theme.Colors = table.freeze({
	-- simulateur
	Ink = hex("#1A1030"),
	Panel = hex("#2B1F4A"),
	PanelInner = hex("#3A2C62"),
	Badge = hex("#FF2E4D"),
	Close = hex("#F2384A"),
	-- anciens noms « mix A », recalés sur la palette simulateur (lot 2) : contours Ink, actions en vert
	PanelLine = hex("#1A1030"),
	Accent = hex("#5BE36A"),
	AccentLight = hex("#8CF07F"),
	AccentDeep = hex("#22A93A"),
	Accent2 = hex("#FF5FD2"),
	Accent2Light = hex("#FF9BE3"),
	Text = hex("#FFFFFF"),
	TextDim = hex("#CFCAE6"),
	Book = hex("#2FA8FF"),
	Crew = hex("#A57CFF"),
	Style = hex("#FF6FC8"),
	Settings = hex("#8C95B8"),
	Slots = hex("#FFC93C"),
	Principal = hex("#33B84A"),
	Danger = hex("#FF3B5C"), -- zones de danger, PV bas, coup reçu (combat)
})

-- Dégradés verticaux (haut → bas) des tuiles, bandeaux et boutons, par fonction
local function grad(top: string, bottom: string)
	return table.freeze({ top = hex(top), bottom = hex(bottom) })
end
Theme.Gradients = table.freeze({
	Book = grad("#2FA8FF", "#1B6FE0"),
	Style = grad("#FF6FC8", "#E0369E"),
	Crew = grad("#A57CFF", "#6E44D9"),
	Slots = grad("#FFC93C", "#E39A12"),
	Bonus = grad("#FF9A3C", "#F2552C"),
	Settings = grad("#8C95B8", "#5A6386"),
	Action = grad("#5BE36A", "#22A93A"),
	Attack = grad("#FF5A5A", "#D42A3A"),
})

Theme.Transparency = table.freeze({ Panel = 0, PanelLine = 0, Dim = 0.38 })
Theme.Radius = table.freeze({ Panel = 8, Button = 6 })

-- Une seule police (FredokaOne) ; les anciens noms de graisse pointent dessus pour les écrans du lot 2
local main = Font.fromEnum(Enum.Font.FredokaOne)
Theme.Fonts = table.freeze({
	Main = main,
	Bold = main,
	ExtraBold = main,
	Heavy = main,
})

-- Contours Ink : 3 px titres, chiffres et tuiles ; 2 px listes
Theme.Stroke = table.freeze({ Text = 3, List = 2, Frame = 3 })
Theme.BaseResolution = Vector2.new(1280, 720)
Theme.MinTouch = 48

-- IDs des images uploadées (assets/ui/README.md). "" = pas encore uploadée → repli.
Theme.Logo = "rbxassetid://104433435199565"
Theme.Glow = "rbxassetid://105925253038271" -- halo porté par Components/Halo, derrière les panneaux
Theme.GlowSlice = Rect.new(48, 48, 80, 80)

-- Icônes vectorielles ombrées en couleur (assets/ui/icons-sim, export/icons_sim.py), jamais teintées. "" = pas encore uploadée → LegacyIcons.
Theme.Icons = table.freeze({
	book = "rbxassetid://115287645348474",
	style = "rbxassetid://97789432741218",
	crew = "rbxassetid://123418976146795",
	slots = "rbxassetid://98396816807789",
	bonus = "rbxassetid://97930375524846",
	settings = "rbxassetid://124354903973041",
	power = "rbxassetid://85705886922860",
	ticket = "rbxassetid://89116907720761",
	companionTicket = "rbxassetid://93541429184199",
	coin = "rbxassetid://75842863094002",
	gift = "rbxassetid://117002826576254",
	lock = "rbxassetid://81383788793970",
	door = "rbxassetid://70666264534865",
	crown = "rbxassetid://136212647644515",
})

-- Icônes de trait blanches « mix A » (assets/ui/png), teintées par ImageColor3 : repli et anciens noms
Theme.LegacyIcons = table.freeze({
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
