# Refonte simulateur — Lot 1 (style, HUD du lobby, Book) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Donner au HUD du lobby et à la fenêtre Book le style « simulateur vif » (tuiles illustrées, contours épais, couleurs par fonction) sans toucher au serveur ni au contrat.

**Architecture:** On garde contrôleurs, `StateController`, `WindowHost` et modèles purs. Les nouvelles règles d'affichage (pastilles, minuteur cadeau, libellé « ??? », tickets compagnon) vont dans des modules purs de `src/client/Logic` testés par `tests/client/run.luau`. `Theme` et les composants Fusion sont refaits ; `HUD.luau` et `Book.luau` sont réorganisés autour d'eux.

**Tech Stack:** Luau, Fusion 0.3, Rojo 7.7.1, Lune (tests), StyLua, Selene, Roblox Studio MCP (Play, captures), Node (`assets/ui/export/export.mjs`).

**Spec:** `docs/superpowers/specs/2026-11-11-ui-lobby-simulateur-design.md` (§1 à §5 et §8 pour ce lot)

## Global Constraints

- Branche `b/ui-simulateur` ; ne jamais pousser `main` ; push et PR seulement avec l'accord de l'utilisateur.
- Aucun fichier modifié hors `src/client/`, `assets/ui/`, `tests/client/`, `docs/` (pas de serveur, `src/shared/`, contrat).
- Aucun encart payant ; aucune donnée fictive : chaque chiffre vient du snapshot via un modèle pur.
- Police : `Font.fromEnum(Enum.Font.FredokaOne)` ; contour `Ink` 3 px (titres, chiffres, tuiles), 2 px (listes).
- Couleurs : valeurs exactes de la spec §3.1 (`Ink #1A1030`, `Panel #2B1F4A`, `PanelInner #3A2C62`, dégradés Book/Style/Crew/Slots/Bonus/Settings/Action/Attack, `Close #F2384A`, `Badge #FF2E4D`).
- Cibles tactiles ≥ 48 px réels (`Metrics.touch`) ; bas droit et haut gauche de l'écran libres sur mobile.
- Animations interruptibles ; `UiState.settings.reducedEffects` ⇒ fondus seuls, pas d'échelle ni de « +N ».
- Pas d'emoji ; icône manquante ⇒ repli sur l'ancienne icône de trait.
- Avant chaque commit : `lune run tests/run`, `lune run tests/client/run`, `stylua src tests`, `selene src`.
- Play uniquement dans la place locale (placeId 0), jamais dans le jeu publié de Yacine.

## Review Focus

- Snapshot absent ou incomplet (`ready = false`, `rewards` nil) : HUD sans erreur, compteurs « — », aucune pastille, minuteur vide.
- Pastille numérique > 9 : affichée « 9+ », jamais un texte qui déborde de la pastille.
- Tous les paliers de temps de jeu reçus : la tuile cadeau n'affiche pas « 00:00 » en boucle mais un texte vide.
- Clics rapides sur une tuile pendant l'ouverture d'une fenêtre : une seule fenêtre, aucun tween empilé.
- Mobile 375 × 812 : la grille de tuiles ne recouvre ni les compteurs ni le bouton ENTRAÎNER.

---

### Task 1: Modèles purs d'affichage

**Files:**
- Create: `src/client/Logic/BadgeModel.luau`
- Modify: `src/client/Logic/HudModel.luau` (type `HudView` + `build`), `src/client/Logic/RewardsModel.luau`, `src/client/Logic/BookModel.luau`
- Test: `tests/client/run.luau` (nouvelle section `print("Refonte simulateur")` juste avant `print("Sons, accessoires et succès")`)

**Interfaces:**
- Produces:
  - `BadgeModel.pip(text: string?): string` — `""` si nil/vide ; un nombre ≥ 10 ⇒ `"9+"` ; un nombre ⇒ lui-même ; tout autre texte (ex. `"NEW"`) ⇒ `"!"`.
  - `HudView.crewTicketText: string` — `format(tickets.crew)`, `"—"` si snapshot non prêt.
  - `RewardsModel.giftText(snapshot: any, balance: any, extraSeconds: number): string` — `"PRÊT"` si un palier est `ready` ; sinon `RewardsModel.clock(needed − (seconds + extraSeconds))` du premier palier `locked` (borné à 0) ; `""` si tous reçus ou rewards absents.
  - `BookModel.cardLabel(card: Card): string` — `card.name` si découverte, sinon `"???"`.

- [ ] **Step 1: Écrire les tests**

```lua
test("pip : vide, nombre, 9+, texte", function()
	eq(BadgeModel.pip(nil), "")
	eq(BadgeModel.pip(""), "")
	eq(BadgeModel.pip("3"), "3")
	eq(BadgeModel.pip("12"), "9+")
	eq(BadgeModel.pip("NEW"), "!")
end)
test("crewTicketText : tickets compagnon du snapshot", function()
	eq(build(with({ tickets = { baddie = 10, crew = 4 } })).crewTicketText, "4")
	eq(build(nil).crewTicketText, "—")
end)
test("giftText : prêt, compte à rebours, terminé, absent", function()
	-- s'appuie sur rewardsSnapshot / Balance déjà utilisés par la section « Récompenses »
	-- palier 1 = 5 min ; 200 s jouées + 40 s écoulées côté client ⇒ 60 s restantes
	eq(RewardsModel.giftText(rewardsSnapshot({ playtime = { seconds = 200, milestones = {} } }), Balance, 40), RewardsModel.clock(60))
	eq(RewardsModel.giftText(rewardsSnapshot({ playtime = { seconds = 300, milestones = { { ready = true } } } }), Balance, 0), "PRÊT")
	-- tous reçus
	local all = {}
	for i in Balance.playtime.milestones do all[i] = { claimed = true } end
	eq(RewardsModel.giftText(rewardsSnapshot({ playtime = { seconds = 99999, milestones = all } }), Balance, 0), "")
	eq(RewardsModel.giftText({}, Balance, 0), "")
end)
test("cardLabel : ??? tant que non découverte", function()
	local cards = BookModel.cards(bookSnapshot(), Catalog, Format)
	for _, c in cards do
		eq(BookModel.cardLabel(c), if c.discovered then c.name else "???", c.id)
	end
end)
```
Adapter les noms d'aides (`rewardsSnapshot`, `bookSnapshot`, `Balance`, `Catalog`, `Format`) à ceux réellement définis dans le fichier ; si `rewardsSnapshot` n'accepte pas `playtime`, construire le snapshot à la main avec `rewards.playtime`.

- [ ] **Step 2: Lancer** `lune run tests/client/run` — Expected: FAIL (`BadgeModel` introuvable / `giftText` nil).
- [ ] **Step 3: Implémenter** les 4 fonctions ci-dessus (lecture de `rewards.playtime` identique à `RewardsModel.playtime`).
- [ ] **Step 4: Lancer** `lune run tests/client/run` — Expected: `0 échec(s)`.
- [ ] **Step 5: Commit** `feat(client): modèles purs de la refonte simulateur (pastilles, cadeau, ???, tickets compagnon)`

### Task 2: Thème et icônes simulateur

**Files:**
- Modify: `src/client/UI/Theme.luau`, `src/client/UI/Text.luau`, `src/client/UI/Components/Icon.luau`
- Create: `assets/ui/icons-sim/*.svg` (14 icônes de la spec §3.4), `assets/ui/icons-sim/png/` (export), mise à jour `assets/ui/README.md` et `assets/ui/export/export.mjs` (dossier source paramétrable)

**Interfaces:**
- Produces:
  - `Theme.Colors` : jetons §3.1 ; chaque couleur de menu existe en paire `Theme.Gradients.<Nom> = { top: Color3, bottom: Color3 }` pour `Book, Style, Crew, Slots, Bonus, Settings, Action, Attack`.
  - `Theme.Fonts.Main = Font.fromEnum(Enum.Font.FredokaOne)` ; `Theme.Fonts.Bold/ExtraBold/Heavy` pointent aussi sur FredokaOne (compatibilité des écrans du lot 2).
  - `Theme.Stroke = { Text = 3, List = 2, Frame = 3 }`.
  - `Theme.Icons` : clés de §3.4 ; valeur `""` tant que non uploadée. `Theme.LegacyIcons` = table actuelle (repli).
  - `Text.label` : `Stroke = true` ⇒ `UIStroke` `Ink` épaisseur `Theme.Stroke.Text` ; nouvelle prop `StrokeThickness: number?`.
  - `Icon` : `Name` clé de `Theme.Icons` ; si `""`, utilise `Theme.LegacyIcons[Name]` teintée, sinon forme de repli existante.
- Étapes :
- [ ] **Step 1:** Dessiner les 14 SVG (pleins, contour `#1A1030` 10 px sur 256, ombre interne, couleurs du menu correspondant ; `coin` or, `power` éclair jaune, `ticket` rose, `companionTicket` violet, `gift` orange, `lock` gris, `door` cyan, `crown` or).
- [ ] **Step 2:** `node assets/ui/export/export.mjs icons-sim` — Expected: 14 PNG 256 × 256 dans `assets/ui/icons-sim/png/`. Les montrer à l'utilisateur (SendUserFile) avant upload.
- [ ] **Step 3:** Modifier Theme, Text, Icon ; `selene src`, `stylua src tests` — Expected: propres ; `lune run tests/client/run` vert.
- [ ] **Step 4:** Upload au nom de l'utilisateur (MCP `upload_image`, lots de 2–3), IDs dans `Theme.Icons` et `assets/ui/README.md`. Si l'upload échoue : laisser `""` (repli) et le noter.
- [ ] **Step 5: Commit** `feat(client): thème simulateur (FredokaOne, dégradés par menu, icônes pleines)`

### Task 3: Tuile, compteur et bouton principal

**Files:**
- Modify: `src/client/UI/Components/MenuItem.luau` (devient la tuile), `CounterPill.luau`, `PrimaryButton.luau`
- Create: `src/client/UI/Components/Tile.luau` (forme commune), `src/client/UI/Motion.luau`

**Interfaces:**
- Consumes: Task 1 `BadgeModel.pip` ; Task 2 `Theme.Gradients`, `Theme.Stroke`, `Icon`.
- Produces:
  - `Tile(scope, { Gradient: { top, bottom }, Size: any, Children: { any }, Pressed: any? }) -> Frame` — coins 12, dégradé vertical, `UIStroke` 3 `Ink`, ombre Frame `Ink` décalée de 4 px, reflet blanc 75 % sur le tiers haut.
  - `Motion.hover(scope, target: GuiObject, reduced: any)` (échelle 1,04, 0,08 s Quad Out), `Motion.press(...)` (0,92 puis ressort), `Motion.open(scope, target, reduced)` (0,9 → 1 + fondu, 0,15 s Back Out), `Motion.close(target, reduced, done: () -> ())` (0,08 s Quad In). Un seul tween actif par cible (le nouveau annule l'ancien). `reduced` vrai ⇒ fondu seul.
  - `MenuItem` : props existantes conservées ; `Color` remplacé par `Gradient` ; rendu tuile 96 × 96 (compact : 72), icône 56 au centre, libellé `FredokaOne` 18 contour 3 débordant en bas, pastille `Badge` 26 px en haut à droite avec `BadgeModel.pip(badge)`, masquée si `""`. `Active` = cadre blanc 4 px.
  - `CounterPill` : icône 40 + chiffre `FredokaOne` 34 contour 3, sans fond de pastille ; pop 1,12 → 1 en 0,15 s sur `Pulse` (désactivé si réduit).
  - `PrimaryButton` : garde `ColorKey` `"Accent" | "Accent2"` (valeurs de `HudModel`, tests existants) et les traduit : `"Accent"` ⇒ `Theme.Gradients.Action`, `"Accent2"` ⇒ `Theme.Gradients.Attack` ; tuile 260 × 84, libellé 34.
- [ ] **Step 1:** Implémenter ; `selene src`, `stylua src tests`, tests Lune — Expected: propres / verts.
- [ ] **Step 2:** Vérif Studio (Play) : capture de la colonne de tuiles ; survol, pression, pastille « ! » visible via `DevGrant drop`.
- [ ] **Step 3: Commit** `feat(client): tuiles, compteurs et bouton au style simulateur`

### Task 4: Disposition du HUD du lobby

**Files:**
- Modify: `src/client/Controllers/HUD.luau`, `src/client/Logic/LayoutMode.luau` si un seuil change (tests existants à garder verts)

**Interfaces:**
- Consumes: Tasks 1–3 ; `HudModel.build` (`powerText`, `ticketText`, `crewTicketText`, `productionText`, `progress`, `button`, `cards`) ; `RewardsModel.coinsText`, `RewardsModel.giftText`, `RewardsModel.badge`.
- Disposition (base 1280 × 720) :
  - Colonne gauche centrée verticalement, marge 16 : grille 2 × 3 — Book, Style, Crew, Slots (« ÉQUIPE »), Bonus, Settings (« RÉGLAGES »), dans cet ordre.
  - Pastilles : Book = `bookBadge` existant ; Slots = `slotsBadge` ; Bonus = `bonusBadge` ; Crew = nouveau `crewBadge` (Value `"NEW"` sur l'événement `crewJoined`, remis à `""` à l'ouverture de Crew, même logique que `bookBadge`).
  - Bas gauche : `CounterPill` empilés puissance, tickets baddie, tickets compagnon, pièces.
  - Bas centre : `PrimaryButton` ; les « +N » de `FloatingNumber` sont coupés si `reducedEffects` ; au-dessus, barre `view.progress` (`title`, `value/max`, remplissage 0,25 s) et `productionText`. **Ruling de plan** : la spec cite « Prochain ticket N/250 », mais le snapshot ne porte aucun compteur d'entraînements ; on affiche la progression existante (`view.progress`) — coût si faux : ajouter un champ côté serveur (codeur A) puis changer une ligne.
  - Haut centre : bannière une ligne = `view.progress.title` si visible, sinon masquée (sous l'échelle 0,6 : masquée).
  - Haut droite (sous les boutons Roblox, y ≥ 60) : tuile `Bonus` 72 px icône `gift` + `giftText` ; `extraSeconds` = secondes depuis le dernier snapshot (une seule boucle `task.delay` de 1 s, coupée au cleanup) ; clic ⇒ `openWindow = "Bonus"`.
  - Droite : cartes existantes restylées (`PanelInner`, cadre rareté 3 px).
  - Retirer le logo du HUD (le menu Roblox occupe le haut gauche) si le chevauchement est constaté en Play ; sinon le garder au-dessus de la grille.
- [ ] **Step 1:** Implémenter ; tests Lune, `selene`, `stylua` — Expected: verts/propres.
- [ ] **Step 2:** Play ordinateur : capture plein écran ; snapshot non prêt (démarrage) sans erreur dans la console.
- [ ] **Step 3:** Play mobile (émulation 375 × 812 dans Studio) : capture ; vérifier Review Focus ligne 5.
- [ ] **Step 4: Commit** `feat(client): HUD du lobby au style simulateur`

### Task 5: Fenêtre au gabarit simulateur

**Files:**
- Modify: `src/client/UI/Components/Window.luau`, `src/client/UI/WindowHost.luau`

**Interfaces:**
- Consumes: Task 2 `Theme.Gradients`, Task 3 `Motion.open/close`.
- Produces:
  - `Window` props ajoutées : `Gradient: { top: Color3, bottom: Color3 }?` (défaut `Theme.Gradients.Book`), `TabsPlacement: ("header" | "side")?` (défaut `"header"`), `Reduced: any?`.
  - Rendu : fond `Panel`, coins 14, contour 4 `Ink`, bandeau 64 au dégradé du menu avec icône 44 + titre `FredokaOne` 32 contour 3, croix carrée 52 `Close` contour 3, coins 10. `"side"` : onglets en colonne de boutons 150 × 56 à droite de la fenêtre (actif = dégradé du menu, inactif = `PanelInner`). Les onglets restent un état Fusion (comportement `liveTabs` conservé).
  - Ouverture `Motion.open`, fermeture : la croix et Échap appellent `OnClose` immédiatement (pas d'attente du tween, pour rester interruptible).
  - `WindowHost.Spec` : champs `gradient` et `tabsPlacement` passés à `Window`.
- [ ] **Step 1:** Implémenter ; tests Lune (`WindowModel` vert), `selene`, `stylua`.
- [ ] **Step 2:** Play : ouvrir/fermer chaque fenêtre existante 10 fois de suite, clics rapides sur la tuile pendant l'ouverture — Expected: une seule fenêtre, aucune erreur console (Review Focus ligne 4).
- [ ] **Step 3: Commit** `feat(client): gabarit de fenêtre simulateur (bandeau coloré, onglets latéraux)`

### Task 6: Book en grille « ??? »

**Files:**
- Modify: `src/client/Controllers/Book.luau`

**Interfaces:**
- Consumes: `BookModel.cards`, `BookModel.cardLabel`, `BookModel.counts`, `BookModel.detail` ; Task 5 `Window` (`gradient = Theme.Gradients.Book`, `tabsPlacement = "side"`, fenêtre 860 × 520).
- Rendu :
  - Onglets latéraux « BADDIES », « COMPAGNONS » (compteurs existants).
  - Grille 4 colonnes défilante (`UIGridLayout`, cellules 150 × 190) : découverte = `Portrait` + cadre rareté 3 px + `cardLabel` ; non découverte = `Portrait` `Locked = true` teinté `Ink` + « ??? » ; puce `chip` existante (EXPOSÉE / PRINCIPALE) en haut.
  - Bas : barre « N/M découvertes » (`BookModel.counts`) remplie au dégradé Book.
  - Clic sur une carte découverte ⇒ fiche `detail` dans le même gabarit (comportement actuel conservé) ; carte non découverte ⇒ aucune action.
- [ ] **Step 1:** Implémenter ; tests Lune (section BookModel verte), `selene`, `stylua`.
- [ ] **Step 2:** Play : Book ouvert sur un profil neuf (Maya seule découverte) puis après `DevGrant tickets` + relances — captures ordinateur et mobile ; aucun texte coupé.
- [ ] **Step 3: Commit** `feat(client): Book en grille de silhouettes au style simulateur`

### Task 7: Vérification d'ensemble et livraison

- [ ] **Step 1:** `lune run tests/run`, `lune run tests/client/run`, `stylua --check src tests`, `selene src` — Expected: tout vert.
- [ ] **Step 2:** Play : vue du spawn avec HUD, Book ouvert, Bonus ouvert, effets réduits activés (aucune échelle), combat lancé (fenêtres fermées, bouton ATTAQUER rouge). Captures dans `docs/captures/ui-simulateur/`.
- [ ] **Step 3:** Rapport à l'utilisateur : ce qui est vérifié, ce qui ne l'est pas (appareil mobile réel, performances), icônes non uploadées le cas échéant. Push et PR seulement s'il le demande.
