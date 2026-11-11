--!strict
--[[
	HudLayout : positions du HUD calculées depuis les tailles réelles (spec simulateur §4.1–4.2).
	Pur. Toutes les valeurs sont en pixels du canevas (référence 1280 × 720 mise à l'échelle) ;
	`canvasHeight` est la hauteur du canevas une fois les zones sûres de Roblox retirées.
	Sur téléphone, les tuiles grossissent (≥ 48 px réels) : la grille remonte pour ne jamais couvrir les compteurs.
]]

local HudLayout = {}

HudLayout.GRID_GAP = 8 -- entre tuiles du menu (lignes et colonnes)

local COUNTERS_HEIGHT = 4 * 34 + 3 * 2 -- 4 compteurs de 34, 2 entre eux
local MARGIN = 14
local LABEL_OVERFLOW = 6 -- libellé des tuiles qui dépasse sous la dernière ligne
local GAP = 8

export type Layout = {
	menuTop: number,
	countersTop: number,
	ticketBarOffset: number, -- Y depuis le bas (négatif) du bas de la barre de ticket
	cardsTop: number,
}

function HudLayout.compute(
	canvasHeight: number,
	tileSide: number,
	buttonHeight: number,
	giftSide: number
): Layout
	local countersTop = canvasHeight - MARGIN - COUNTERS_HEIGHT
	local gridHeight = 3 * tileSide + 2 * HudLayout.GRID_GAP
	local centered = canvasHeight / 2 - MARGIN - gridHeight / 2
	local highest = countersTop - GAP - LABEL_OVERFLOW - gridHeight
	return {
		menuTop = math.floor(math.min(centered, highest)),
		countersTop = countersTop,
		ticketBarOffset = -(18 + buttonHeight + 8),
		cardsTop = MARGIN + giftSide + 24,
	}
end

return HudLayout
