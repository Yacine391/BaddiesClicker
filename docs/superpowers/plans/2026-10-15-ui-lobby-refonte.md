# Refonte visuelle HUD, fenêtres et lobby — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer le style V3 du client par le style « mix A » (cyan) validé sur prototypes — HUD, fenêtres, annonces, lobby et ambiance — sans changer le comportement P0.

**Architecture:** Les décisions d'affichage restent dans des modules purs testés avec Lune (`Logic/*`). Le style passe par de nouveaux jetons de thème et de nouvelles briques Fusion, puis les contrôleurs existants sont réécrits avec ces briques. Les icônes et le logo sont des SVG maison convertis en PNG par un petit script Node et uploadés par l'utilisateur. Le lobby est reconstruit dans Studio via le MCP et réexporté en `.rbxm`.

**Tech Stack:** Luau `--!strict`, Fusion 0.3 (copié), Rojo 7.7.1, Lune 0.10.4, Selene, StyLua, Node 24 + `@resvg/resvg-js`, MCP Roblox Studio.

**Spec:** `docs/superpowers/specs/2026-10-15-ui-lobby-refonte-design.md`, avec `docs/CONTRACT.md` (v3). Prototypes de référence : `.superpowers/brainstorm/1574-1792075760/content/hud-mix.html` (variante A), `windows-mixA.html`, `lobby-plan-v2.html`, `lobby-3d-hud-v2.html`.

## Global Constraints

- Branche `b/ui-refonte` ; push et PR seulement après accord explicite de l'utilisateur.
- Fichiers modifiables : `src/client/` sauf `Controllers/StateController.luau`, `Controllers/CelebrationController.luau`, `Controllers/DoorController.luau`, `Dev/*`, `*Bootstrap.client.luau` du codeur A (`CombatBootstrap`, `DevToolsBootstrap`) ; `assets/` ; `tests/client/` ; `docs/`. Exception à signaler dans la PR : `.gitignore` (ligne `assets/ui/export/node_modules/`).
- Couleurs (`Theme.Colors`) : `Panel` `#100E1E` (transparence 0,14), `PanelLine` `#A08CFF` (transparence 0,72), `Accent` `#3EE6C8`, `AccentDeep` `#13A6B5`, `Accent2` `#FF5FD2`, `Ink` `#0D0B16`, `Text` `#FFFFFF`, `TextDim` `#CFCAE6`, `Book` `#3EE6C8`, `Crew` `#B48CF0`, `Style` `#FF5FD2`, `Settings` `#CFCAE6`, `Close` `#E0233F`, `Principal` `#33B84A`. Raretés : `Catalog.rarities[*].color`, jamais en dur.
- Police : `Font.fromName("RobotoCondensed", weight)` avec `Enum.FontWeight.Bold`, `ExtraBold`, `Heavy`. Aucun emoji, aucune police LuckiestGuy ou FredokaOne.
- Panneau : `UICorner` 10 px, `UIStroke` 2 px. Croix : carré 42 px base, `Close`, coins 10 px, « X » en `Heavy`. Cibles tactiles ≥ 48 px réels (`TouchSize`).
- Base d'échelle 1280 × 720 ; mode compact quand l'échelle est **strictement inférieure à 0,6**.
- Comportement P0 inchangé : chiffres venant du snapshot uniquement, aucun `Train` fenêtre ouverte, maintien du clic, `PrimaryAction`, tutoriel.
- StyLua seulement sur les fichiers du codeur B (`core.autocrlf` réécrit sinon ceux du codeur A).
- Avant chaque commit : `lune run tests/run`, `lune run tests/client/run`, `selene src` sans erreur.
- Messages de commit conventionnels terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Écran très petit ou très large** (échelle 0,35 ; 21:9 ; téléphone portrait) : rien ne se chevauche, mode compact actif sous 0,6, croix et menu ≥ 48 px. → vérification Play à deux tailles (Tâche 5) + tests `LayoutMode` (Tâche 1).
2. **Snapshot sans `style`, sans `clearedLevels` ou sans `collection`** : les fenêtres et la carte de progression s'adaptent (onglet absent, carte masquée) sans erreur. → tests `HudModel.progress` et `StyleModel.tabs` (Tâche 1).
3. **Icône ou logo sans ID uploadé** (cas de départ) : repli lisible, jamais d'image cassée ni d'emoji. → vérification Play (Tâche 3).
4. **Événements `Result` en rafale** (10 tickets en 1 s) : les toasts s'empilent sans se superposer et disparaissent. → vérification Play (Tâche 5).
5. **« Effets réduits »** : coupe le bloom de l'ambiance en plus des auras. → vérification Play (Tâche 10).

---

## File Structure

```
src/client/Logic/LayoutMode.luau     [pur] échelle → "full" | "compact"
src/client/Logic/HudModel.luau        [pur] + progress, toastFor, bouton Accent/Accent2
src/client/Logic/StyleModel.luau      [pur] onglets LOOKS / AURA / TITRE
src/client/UI/Theme.luau              jetons mix A, Icons (IDs), Logo, Glow
src/client/UI/Text.luau               texte sans ombre ; contour fin optionnel
src/client/UI/Components/Icon.luau        image teintée ou repli en forme simple
src/client/UI/Components/Panel.luau       panneau + halo
src/client/UI/Components/CounterPill.luau
src/client/UI/Components/MenuItem.luau    ligne large ou tuile compacte
src/client/UI/Components/CharacterCard.luau
src/client/UI/Components/ProgressCard.luau
src/client/UI/Components/PrimaryButton.luau   (remplace ActionButton)
src/client/UI/Components/{Toast,Window,ListRow,Chip}.luau  restylés
src/client/UI/Components/{MenuTile,BigStat,ActionButton}.luau  supprimés
src/client/Controllers/{HUD,Book,Style,Crew,Settings}.luau     réécrits
src/client/Controllers/Ambience.luau      ambiance coucher de soleil
assets/ui/icons/*.svg, assets/ui/logo.svg, assets/ui/glow.svg
assets/ui/export/{package.json,export.mjs}   SVG → PNG (assets/ui/png/)
assets/world/Lobby.rbxm                     reconstruit
```

---

### Task 1: Modèles purs (LayoutMode, HudModel, StyleModel)

**Files:**
- Create: `src/client/Logic/LayoutMode.luau`, `src/client/Logic/StyleModel.luau`
- Modify: `src/client/Logic/HudModel.luau`
- Test: `tests/client/run.luau` (groupes « LayoutMode », « HudModel v2 », « StyleModel »)

**Interfaces:**
- Produces:
  - `LayoutMode.mode(scale: number): "full" | "compact"` — `"compact"` si `scale < 0.6` ; `"full"` si `scale` est NaN ou ≤ 0.
  - `HudModel.build(...)` : `button.colorKey` devient `"Accent"` (repos) ou `"Accent2"` (combat) ; nouveau champ `progress: { visible: boolean, kind: "tutorial" | "run", title: string, value: number, max: number }` :
    tutoriel → `{ kind = "tutorial", title = "MALIK ARRIVE", value = progress, max = needed }` tant que `crewUnlocked == false` ; sinon, si `clearedLevels` est un tableau → `{ kind = "run", title = "PARCOURS", value = #clearedLevels, max = 10 }` ; sinon `visible = false`. Le champ `tutorial` existant reste pour compatibilité.
  - `HudModel.toastFor(event: {[string]: any}, catalog: any): string?` — `crewJoined` + `isNew == false` → `"+1 copie : " .. Catalog.crew[id].name` ; `crewJoined` + `isNew == true` → `nil` ; `ticket` → `"+" .. amount .. " ticket " .. (crew ? "compagnon" : "baddie")` ; tout autre `kind` → `nil`.
  - `StyleModel.tabs(snapshot: any, catalog: any, wardrobe: any): { { id: "looks" | "aura" | "title", label: string } }` — `LOOKS` si la principale existe dans le Catalog ; `AURA` si `snapshot.style.items` contient au moins un item d'emplacement `"aura"` ; `TITRE` si `snapshot.style.titles` n'est pas vide.
  - `StyleModel.auraRows(snapshot, wardrobe)` et `StyleModel.titleRows(snapshot, wardrobe)` → `{ { id: string, name: string, equipped: boolean } }` dans l'ordre `wardrobe.itemOrder` / `wardrobe.titleOrder` ; `equipped` = `style.equipped.aura == id` / `style.title == id`.

- [ ] **Step 1: Tests** (le runner charge déjà `Catalog` et `Format` ; ajouter `Wardrobe = require("../../src/shared/Wardrobe")`)
```luau
test("LayoutMode : seuil 0,6", function() eq(LayoutMode.mode(0.59), "compact") eq(LayoutMode.mode(0.6), "full") end)
test("LayoutMode : échelle invalide", function() eq(LayoutMode.mode(0 / 0), "full") eq(LayoutMode.mode(0), "full") end)
test("HudModel : bouton repos Accent", function() eq(build(baseSnapshot()).button.colorKey, "Accent") end)
test("HudModel : bouton combat Accent2", function() eq(build(with({ mode = "combat" })).button.colorKey, "Accent2") end)
test("HudModel : progression tutoriel", function() local p = build(with({ tutorial = { crewUnlocked = false, progress = 7, needed = 10 } })).progress eq(p.visible, true) eq(p.title, "MALIK ARRIVE") eq(p.value, 7) eq(p.max, 10) end)
test("HudModel : progression parcours", function() local p = build(with({ clearedLevels = { 1, 2, 3 } })).progress eq(p.kind, "run") eq(p.title, "PARCOURS") eq(p.value, 3) eq(p.max, 10) end)
test("HudModel : progression absente", function() eq(build(baseSnapshot()).progress.visible, false) end)
test("HudModel : toast copie", function() eq(HudModel.toastFor({ kind = "crewJoined", crewId = "malik", isNew = false }, Catalog), "+1 copie : Malik") end)
test("HudModel : pas de toast nouveau compagnon", function() eq(HudModel.toastFor({ kind = "crewJoined", crewId = "malik", isNew = true }, Catalog), nil) end)
test("HudModel : toast ticket", function() eq(HudModel.toastFor({ kind = "ticket", ticket = "crew", amount = 1 }, Catalog), "+1 ticket compagnon") eq(HudModel.toastFor({ kind = "ticket", ticket = "baddie", amount = 2 }, Catalog), "+2 ticket baddie") end)
test("HudModel : toast inconnu", function() eq(HudModel.toastFor({ kind = "passiveTick", amount = 0.6 }, Catalog), nil) end)
test("StyleModel : sans style", function() local t = StyleModel.tabs(baseSnapshot(), Catalog, Wardrobe) eq(#t, 1) eq(t[1].id, "looks") end)
test("StyleModel : aura et titre", function() local s = with({ style = { items = { "aura_spark" }, titles = { "boss_manager" }, equipped = { aura = "aura_spark" }, title = nil } }) local t = StyleModel.tabs(s, Catalog, Wardrobe) eq(#t, 3) eq(StyleModel.auraRows(s, Wardrobe)[1].equipped, true) eq(StyleModel.titleRows(s, Wardrobe)[1].name, "Gérant de Baddies") eq(StyleModel.titleRows(s, Wardrobe)[1].equipped, false) end)
```
Mettre à jour les tests existants « bouton repos » (`"Action"` → `"Accent"`) et « bouton combat » (`"Fermer"` → `"Accent2"`).
- [ ] **Step 2:** `lune run tests/client/run` → échecs attendus (modules ou champs absents).
- [ ] **Step 3:** Implémenter `LayoutMode`, `StyleModel`, et les ajouts de `HudModel` (purs, sans `require`).
- [ ] **Step 4:** `lune run tests/client/run` → 0 échec ; `lune run tests/run` → 0 échec.
- [ ] **Step 5:** Commit `feat(client): layout mode, progress, toast and style view models`.

### Task 2: Icônes, logo et halo (SVG → PNG)

**Files:**
- Create: `assets/ui/icons/{book,crew,style,settings,chevron,bolt,arm,ticket,door,lock,eye,crown}.svg`, `assets/ui/logo.svg`, `assets/ui/glow.svg`, `assets/ui/export/package.json`, `assets/ui/export/export.mjs`, `assets/ui/png/*.png`, `assets/ui/README.md`
- Modify: `.gitignore` (+ `assets/ui/export/node_modules/`)

**Interfaces:**
- Produces: un PNG par SVG dans `assets/ui/png/` (icônes 256 × 256, logo 1024 px de large, `glow.png` 128 × 128) ; `assets/ui/README.md` liste chaque fichier avec une colonne « assetId » à remplir par l'utilisateur.

- [ ] **Step 1:** Dessiner les SVG en reprenant les symboles des prototypes `hud-mix.html` (`m-book`, `m-crew`, `m-style`, `m-set`, `m-door`, `m-bolt`, `m-arm`, `m-ticket`) et `windows-mixA.html` (`w-lock`, `w-eye`), plus `chevron` et `crown`. Icônes de trait : trait **blanc** 2,4 (teintées en jeu). `arm` et `ticket` : couleurs pleines comme dans le prototype. Logo : « BADDIE » italique noir 900 blanc à contour `#0D0B16`, « Clicker » script cyan `#3EE6C8` avec lueur, rotation −6°, texte converti en tracés (pas de dépendance de police). `glow.svg` : carré 128 avec dégradé radial blanc → transparent (pour un 9-slice `SliceCenter` 48–80).
- [ ] **Step 2:** `assets/ui/export/package.json` avec la dépendance `@resvg/resvg-js` (version épinglée) ; `export.mjs` convertit chaque SVG de `assets/ui/` et `assets/ui/icons/` vers `assets/ui/png/` à la taille ci-dessus.
- [ ] **Step 3:** `cd assets/ui/export && npm install && node export.mjs` → 15 PNG présents. Les afficher (outil de lecture d'image) pour contrôler fond transparent et rendu.
- [ ] **Step 4:** Rédiger `assets/ui/README.md` (procédure d'upload dans le Creator Hub au nom du groupe, tableau fichier → assetId vide).
- [ ] **Step 5:** Commit `feat(assets): UI icon set, logo and glow sources with PNG export`.

### Task 3: Thème et briques de base

**Files:**
- Modify: `src/client/UI/Theme.luau`, `src/client/UI/Text.luau`
- Create: `src/client/UI/Components/Icon.luau`, `src/client/UI/Components/Panel.luau`

**Interfaces:**
- Produces:
  - `Theme.Colors` (Global Constraints) ; `Theme.Transparency = { Panel = 0.14, PanelLine = 0.72, Dim = 0.38 }` ; `Theme.Fonts = { Bold, ExtraBold, Heavy }` (RobotoCondensed) ; `Theme.Radius = { Panel = 10, Button = 12 }` ; `Theme.Icons: { [string]: string }` (clés = noms des SVG de la Tâche 2, valeurs `""` jusqu'à l'upload) ; `Theme.Logo: string` ; `Theme.Glow: string` ; `Theme.MinTouch = 48` ; `Theme.BaseResolution`.
  - `Text.label(scope, { Text, Size, Position?, AnchorPoint?, Weight?: "Bold" | "ExtraBold" | "Heavy", Color?, XAlignment?, Stroke?: boolean, ZIndex? }): TextLabel` — un seul `TextLabel` (`TextScaled`), sans ombre ; `Stroke = true` ajoute un `UIStroke` 2 px `Ink`.
  - `Icon(scope, { Name: string, Size: UDim2, Position?, Color?: any }): GuiObject` — `ImageLabel` avec `Theme.Icons[Name]` et `ImageColor3 = Color` ; si l'ID est `""` : `Frame` carré arrondi (6 px), `UIStroke` 2 px `Color`, initiale du nom en `Heavy`.
  - `Panel(scope, { Size, Position?, AnchorPoint?, Glow?: Color3 | state, Line?: Color3 | state, Children?, Name? }): Frame` — fond `Panel`, coins, contour `Line` (défaut `PanelLine`) ; si `Glow` : `ImageLabel` `Theme.Glow` 9-slice derrière (agrandi de 24 px, teinté, transparence 0,4) ; sans ID de halo, `UIStroke` plus épais (3 px) à la place.
- [ ] **Step 1:** Implémenter.
- [ ] **Step 2: Vérification Play** (MCP, `Client`) : écran de démonstration temporaire avec un `Panel` avec et sans halo, `Icon` avec ID vide (repli) et `Text.label` aux trois graisses ; `screen_capture` ; aucun emoji ; détruire l'écran de démonstration.
- [ ] **Step 3:** Commit `feat(ui): mix A theme tokens, text, icon and panel primitives`.

### Task 4: Composants du HUD

**Files:**
- Create: `src/client/UI/Components/{CounterPill,MenuItem,CharacterCard,ProgressCard,PrimaryButton}.luau`
- Modify: `src/client/UI/Components/Toast.luau`
- Delete: `src/client/UI/Components/{MenuTile,BigStat,ActionButton}.luau` (leurs usages disparaissent à la Tâche 5 ; supprimer dans la même PR, commit de la Tâche 5)

**Interfaces:**
- Consumes: `Panel`, `Icon`, `Text.label`, `Theme`.
- Produces (tailles en px de référence) :
  - `CounterPill(scope, { Icon: string, Text: state<string>, Glow: boolean, Pulse?: state<number> })` — hauteur 46, largeur auto (`AutomaticSize.X`), icône 32, texte `ExtraBold` 25 ; « pop » (spring 1 → 1,12) quand `Pulse` change.
  - `MenuItem(scope, { Icon, Label, Color: Color3, Mode: state<"full" | "compact">, Active: state<boolean>, Badge?: state<string>, OnClick })` — full : 236 × 54, icône 30 teintée `Color`, libellé `ExtraBold` 20, chevron ; actif : contour `Color`, barre gauche 4 px, halo. Compact : tuile carrée 54 (hauteur compensée par `TouchSize`), icône 28, libellé 11 sous l'icône.
  - `CharacterCard(scope, { Rarity: { label, color }, Name, Line1, Line2, Accent: Color3, Mode: state })` — 150 × 158 en full (zone portrait 96 + texte), bandeau 150 × 46 en compact (nom + `Line1`).
  - `ProgressCard(scope, { Model: state<progress> })` — 290 × 62, icône `door` (parcours) ou `crew` (tutoriel), titre `ExtraBold` 15 + « » », valeur « n / max », barre dégradée `Accent2 → Accent` ; invisible si `visible == false`.
  - `PrimaryButton(scope, { Label: state<string>, ColorKey: state<"Accent" | "Accent2">, Enabled: state<boolean>, OnActivated, OnPress, OnRelease })` — 300 × 76, contour 3 px dégradé, remplissage dégradé (Accent : `#5FF3DA → Accent` ; Accent2 : `#FF9BE3 → Accent2`), icône `bolt` 40, libellé `Heavy` 38 `Ink` ; mêmes événements que l'ancien `ActionButton` (appui par `InputBegan`, relâchement via `UserInputService.InputEnded`).
  - `Toast.show(parent, text, icon?)` — `Panel` contour `Accent`, icône, texte `ExtraBold` ; les toasts simultanés s'empilent (décalage de 58 px par toast visible) au lieu de se superposer.
- [ ] **Step 1:** Implémenter.
- [ ] **Step 2: Vérification Play** : écran de démonstration avec un exemplaire de chaque composant (MenuItem en full et en compact, PrimaryButton dans les deux couleurs, 3 toasts lancés en 0,2 s) ; `screen_capture` comparé à `hud-mix.html` ; détruire la démonstration.
- [ ] **Step 3:** Commit `feat(ui): mix A HUD components`.

### Task 5: HUD réécrit

**Files:**
- Modify: `src/client/Controllers/HUD.luau`, `src/client/App.luau` (si l'ordre des contrôleurs change)
- Delete: `src/client/UI/Components/{MenuTile,BigStat,ActionButton}.luau`

**Interfaces:**
- Consumes: Tâches 1, 3, 4 ; `Store`, `UiState`, `Input`, `StateController.onResult`, `Catalog`, `Format`.
- Produces: `ScreenGui` `HUD` (mêmes réglages d'échelle qu'aujourd'hui, `deps.HudRoot` conservé, `deps.LayoutMode: state<"full" | "compact">` ajouté pour les fenêtres) avec la disposition de la spec §4 : logo (`ImageLabel` `Theme.Logo`, 300 × 120 en haut à gauche sous les boutons Roblox ; repli : `Text.label` « BADDIE CLICKER » `Heavy`), compteurs puissance (`arm`, halo, `Pulse = trainPulse`) et tickets (`ticket`), menu Book/Crew/Style/Réglages (couleurs `Book`/`Crew`/`Style`/`Settings`, `Active` = `UiState.openWindow` ou dernière fenêtre ouverte, badge `NEW` rose sur Book quand une découverte n'a pas été ouverte depuis l'arrivée de `Result.discovery`), cartes principale + compagnons du snapshot, `ProgressCard`, `PrimaryButton`, étiquette « +1 puissance » montante. Toasts : `HudModel.toastFor` (plus de toast pour un nouveau compagnon).
- [ ] **Step 1:** Implémenter, supprimer les trois anciens composants.
- [ ] **Step 2: Vérification Play** (fenêtre Studio large) : `screen_capture` comparée à `hud-mix.html` (A) ; 10 entraînements → bannière RGB du codeur A seule (aucun toast), carte de progression qui passe au mode parcours ; puissance qui pop.
- [ ] **Step 3: Review Focus 1** : fenêtre Studio réduite (échelle < 0,6) → mode compact, croix, tuiles et bouton ≥ 48 px (`AbsoluteSize`), aucun chevauchement visible ; `screen_capture`.
- [ ] **Step 4: Review Focus 4** : dans le contexte MCP `Client`, `require` du module `Toast` et 6 appels `Toast.show(PlayerGui.HUD.Root, "+1 ticket baddie", "ticket")` espacés de 0,15 s → empilés, tous lisibles, disparus après 3 s (le module est une copie, mais il écrit dans le même `PlayerGui`).
- [ ] **Step 5:** Commit `feat(client): mix A HUD with compact mode and new toasts`.

### Task 6: Gabarit de fenêtre, lignes, Crew et Réglages

**Files:**
- Modify: `src/client/UI/Components/{Window,ListRow,Chip}.luau`, `src/client/UI/WindowHost.luau` (si besoin), `src/client/Controllers/{Crew,Settings}.luau`

**Interfaces:**
- Produces:
  - `Window(scope, { Title, Icon, Tabs?: { { id, label, count? } }, ActiveTab?: state<string>, OnTab?, Content, OnClose, Size? })` — 820 × 500, contour `Accent` + halo, en-tête 62 (icône teintée `Accent`, titre `Heavy` 28, onglets en pastilles 34 de haut — actif : contour `Accent`, fond `Accent` à 88 % de transparence, compteur en `Accent`), croix carrée (Global Constraints), fond de jeu assombri (`Ink`, transparence `Theme.Transparency.Dim`) qui bloque les clics.
  - `ListRow` : fond `Panel` à contour `PanelLine` (plus de dégradé coloré), portrait carré arrondi 54, nom `ExtraBold` 20, puces `Chip` (fond couleur, texte `Ink` `ExtraBold` 11), bouton d'action en mini `PrimaryButton` (130 × 44, `Accent`) ; `Dimmed` = transparence 0,45.
  - Crew : une ligne par compagnon (rareté, nom · rôle, `+x / s` en `Accent`, `Niv. n`, `Copies : n`, puce `ÉQUIPÉ` si équipé). Réglages : lignes à interrupteur (pastille `Accent` OUI / grise NON).
- [ ] **Step 1:** Implémenter.
- [ ] **Step 2: Vérification Play** : ouvrir Crew et Réglages → `screen_capture` ; croix et clic hors fenêtre bloqué ; interrupteurs fonctionnels.
- [ ] **Step 3:** Commit `feat(ui): mix A window template, rows, crew and settings`.

### Task 7: Book

**Files:**
- Modify: `src/client/Controllers/Book.luau`

**Interfaces:**
- Consumes: `Window`, `Panel`, `Icon`, `Chip`, `PrimaryButton`, `HudModel.build(...).bookCount`, snapshot `collection` (v3), `Catalog`.
- Produces: onglets `BADDIES n/8` et `CREW n/m` ; grille 4 colonnes de cartes 150 px (rareté, silhouette colorée selon la palette du Catalog ou noire si non découverte, nom ou « ??? », puce : `PRINCIPALE · Sn` `Principal`, `EXPOSÉE` `Accent`, chance `rollChance %` pour « ??? ») ; sélection par clic (contour `Accent` + halo) ; fiche 250 px : portrait, nom `Heavy` 26, puces, `Multiplicateur ×m`, `Maîtrise Niv. n`, barre, `Looks k/3`, boutons `VOIR LES LOOKS` (ouvre Style) et `EXPOSER`/`RETIRER` (`SetDisplay`, seulement si `collection` existe et < 3 exposées ou déjà exposée) ; barre `COLLECTION n / 8`. Onglet CREW : liste des compagnons possédés (lignes de la Tâche 6). Ouvrir le Book efface le badge `NEW`.
- [ ] **Step 1:** Implémenter.
- [ ] **Step 2: Vérification Play** : capture comparée à `windows-mixA.html` (Book) ; avec un snapshot v3 réel (profil Studio de Yacine : `test_b99` découverte) → exposer puis retirer `TEST B99`, la puce change ; la puissance par clic ne change pas.
- [ ] **Step 3:** Commit `feat(client): mix A book with detail panel`.

### Task 8: Style

**Files:**
- Modify: `src/client/Controllers/Style.luau`

**Interfaces:**
- Consumes: `StyleModel.tabs/auraRows/titleRows`, `Wardrobe`, `Window` (onglets), `Panel`, `PrimaryButton`, snapshot `collection.looks`.
- Produces: onglets selon `StyleModel.tabs` ; LOOKS : aperçu 300 px à gauche (silhouette de la principale aux couleurs du look porté, socle néon `Accent`, nom + look en `Accent`), 3 lignes de looks (porté : puce `PORTÉ` ; débloqué : bouton `PORTER` → `SetLook { baddieId, look }` ; verrouillé : icône `lock` + `MAÎTRISE n`) ; AURA : lignes des auras débloquées, `PORTER`/`RETIRER` → `SetStyle { slot = "aura", id? }` ; TITRE : lignes des titres, `AFFICHER`/`RETIRER` → `SetStyle { slot = "title", id? }`. Actions désactivées en combat (`snapshot.mode == "combat"`).
- [ ] **Step 1:** Implémenter.
- [ ] **Step 2: Vérification Play** : capture comparée à `windows-mixA.html` (Style) ; avec le profil Studio, `DevSetMastery` de test → PORTER le look 2 ; si un titre est débloqué, l'afficher → `BC_Title` change.
- [ ] **Step 3:** Commit `feat(client): mix A style window with looks, aura and title tabs`.

### Task 9: Lobby reconstruit

**Files:**
- Modify: `assets/world/Lobby.rbxm` (export Studio)

**Interfaces:**
- Produces: `Workspace.Lobby` conforme à la spec §7.1 (repère nord = −Z), noms conservés : `Lobby.Spawn` (`SpawnLocation`), `Lobby.Podium.Stand`. Plus de `Street.Barrier` ; la rue s'ouvre vers le nord.

- [ ] **Step 1:** En Edit via le MCP, renommer l'ancien `Workspace.Lobby` en `Lobby_P0` (il est remplacé, pas supprimé tant que l'export n'est pas validé), puis construire le nouveau lobby par groupes (`task.wait()` entre chaque) : sol et allée, murs bas + liserés `Neon` cyan, couronne au sol, arche + `SurfaceGui` « VERS LE NIVEAU 1 », rue, Street Gym, La Scène (`Podium.Stand`, anneau, écran LED `SurfaceGui`, projecteurs, cabine DJ), écran Classement, vitrine Style, palmiers, bancs, lampadaires, demi-terrain, ville et voie surélevée sans collision. Matériaux et couleurs du concept Blender (`lobby_concept.blend`).
- [ ] **Step 2: Vérification Play** : `screen_capture` depuis le spawn comparée à `lobby-3d-hud-v2.html` ; marcher du spawn au bout de la rue sans saut ; `search_game_tree` : aucun `ClickDetector`/`ProximityPrompt` sous `Lobby`, pas de `Barrier` ; Maya apparaît sur `Podium.Stand`.
- [ ] **Step 3:** Demander à l'utilisateur d'exporter `Workspace.Lobby` vers `assets/world/Lobby.rbxm` (remplacement) ; vérifier la date du fichier ; resynchroniser Rojo ; supprimer `Lobby_P0` de la place.
- [ ] **Step 4:** Commit `feat(world): mix A lobby, barrier removed`.

### Task 10: Ambiance coucher de soleil

**Files:**
- Create: `src/client/Controllers/Ambience.luau`
- Modify: `src/client/App.luau` (ajout `"Ambience"` en tête des contrôleurs visuels)

**Interfaces:**
- Produces: au démarrage, côté client uniquement : `Lighting.ClockTime = 18.2`, `Lighting.Brightness = 2`, `Atmosphere` (`Color` `#C77DA0`, `Decay` `#5A3A7A`, `Density` 0,32, `Haze` 1,6), `BloomEffect` (`Intensity` 0,8, `Size` 28, `Threshold` 0,95), `ColorCorrectionEffect` (`Saturation` 0,12, `Contrast` 0,08) ; instances nommées `BC_*`, créées seulement si absentes ; `BloomEffect.Enabled = not reducedEffects` (observe `UiState.settings.reducedEffects`).
- [ ] **Step 1:** Implémenter.
- [ ] **Step 2: Vérification Play** : `screen_capture` depuis le spawn (néons qui brillent, ciel orangé) ; Réglages → effets réduits → bloom coupé (`Lighting.BC_Bloom.Enabled == false`).
- [ ] **Step 3:** Commit `feat(client): sunset ambience with bloom`.

### Task 11: Finitions, documentation et vérification

**Files:**
- Modify: `docs/proposals/2026-10-14-contract-v2-collection.md` (en tête : « Statut : implémenté dans le contrat v3, PR #3 »), `docs/beta-checklist-p0.md` (captures et comportements du nouveau style), `assets/ui/README.md` (IDs renseignés par l'utilisateur), `src/client/UI/Theme.luau` (IDs)

- [ ] **Step 1:** Demander à l'utilisateur d'uploader les 15 PNG (`assets/ui/png/`) dans Roblox au nom du groupe du jeu et de donner les IDs ; les reporter dans `Theme.Icons`, `Theme.Logo`, `Theme.Glow` et le README. Si l'utilisateur reporte l'upload, le noter dans la PR (les replis restent actifs).
- [ ] **Step 2:** Mettre à jour la proposition et la checklist.
- [ ] **Step 3:** `lune run tests/run` et `lune run tests/client/run` → 0 échec ; `selene src` → 0 erreur ; `stylua --check` sur les fichiers du codeur B.
- [ ] **Step 4:** Parcours Play complet : spawn → HUD → 10 entraînements → Book (exposer) → Style (look, titre) → Crew → Réglages (effets réduits) → sortie vers le niveau 1 ; `get_console_output` sans erreur ; captures pour la PR.
- [ ] **Step 5:** Commit `docs: redesign handoff (proposal status, checklist, asset IDs)` ; demander l'accord pour pousser `b/ui-refonte` et ouvrir la PR vers `main` (captures + liste des assets).
