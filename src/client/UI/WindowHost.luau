--!strict
--[[
	WindowHost : monte une fenêtre quand UiState.openWindow vaut `name`, la détruit sinon.
	La fenêtre vit dans un scope intérieur (connexions, springs) nettoyé à la fermeture.
	Elle est placée dans HUD.Root pour profiter du même UIScale que le HUD.
]]

local Window = require(script.Parent.Components.Window)

local WindowHost = {}

export type Spec = {
	name: string,
	title: string,
	icon: string, -- clé de Theme.Icons
	tabs: { { id: string, label: string, count: string? } }?,
	activeTab: any?, -- état de string
	onTab: ((id: string) -> ())?,
	layout: ("list" | "free")?,
	-- Construit le contenu ; peut renvoyer des états Fusion d'instances (rebuild réactif)
	content: (inner: any) -> { any },
}

function WindowHost.mount(scope: any, deps: any, parent: Instance, spec: Spec)
	local mounted = scope:Computed(function(use, inner)
		if use(deps.UiState.openWindow) ~= spec.name then
			return nil
		end
		return Window(inner, {
			Title = spec.title,
			Icon = spec.icon,
			Tabs = spec.tabs,
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
