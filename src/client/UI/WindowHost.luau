--!strict
--[[
	WindowHost : monte une fenêtre quand UiState.openWindow vaut `name`, la détruit sinon.
	La fenêtre vit dans un scope intérieur (connexions, springs) nettoyé à la fermeture.
	Elle est placée dans HUD.Root pour profiter du même UIScale que le HUD.
]]

local Window = require(script.Parent.Components.Window)
local WindowModel = require(script.Parent.Parent.Logic.WindowModel)

local WindowHost = {}

export type Spec = {
	name: string,
	title: string,
	icon: string, -- clé de Theme.Icons
	-- onglets, ou fonction(snapshot) évaluée à l'ouverture (compteurs à jour)
	tabs: any?,
	activeTab: any?, -- état de string
	onTab: ((id: string) -> ())?,
	layout: ("list" | "free")?,
	-- Construit le contenu ; peut renvoyer des états Fusion d'instances (rebuild réactif)
	content: (inner: any) -> { any },
}

-- Onglets calculés depuis le snapshot : reconstruits seulement quand libellés ou compteurs changent
local function liveTabs(inner: any, deps: any, build: (any) -> any): any
	local signature = inner:Computed(function(use)
		return WindowModel.tabsSignature(build(use(deps.Store.snapshot)))
	end)
	return inner:Computed(function(use)
		use(signature)
		return build(deps.peek(deps.Store.snapshot))
	end)
end

function WindowHost.mount(scope: any, deps: any, parent: Instance, spec: Spec)
	local mounted = scope:Computed(function(use, inner)
		if use(deps.UiState.openWindow) ~= spec.name then
			return nil
		end
		return Window(inner, {
			Title = spec.title,
			Icon = spec.icon,
			Tabs = if type(spec.tabs) == "function" then liveTabs(inner, deps, spec.tabs) else spec.tabs,
			ActiveTab = spec.activeTab,
			OnTab = spec.onTab,
			Layout = spec.layout,
			Content = spec.content(inner),
			OnClose = function()
				deps.UiState.openWindow:set(nil)
			end,
		})
	end)
	scope:New("Folder")({
		Name = "Window_" .. spec.name,
		Parent = parent,
		[scope.Children] = mounted,
	})
end

-- Recalcule `build` seulement quand `key(snapshot)` change (pas à chaque tick de puissance)
function WindowHost.rows(inner: any, deps: any, key: (any) -> string, build: (any, any) -> { Instance })
	local signature = inner:Computed(function(use)
		return key(use(deps.Store.snapshot))
	end)
	return inner:Computed(function(use, rowsScope)
		use(signature)
		return build(rowsScope, deps.peek(deps.Store.snapshot))
	end)
end

return WindowHost
