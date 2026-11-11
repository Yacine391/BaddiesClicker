# Refonte simulateur — Lot 2 (écrans restants) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Passer tous les écrans restants (Style, Crew, Équipe, Bonus, Réglages, Décisions, combat, toasts, cartes de droite) au style simulateur du lot 1, et corriger les mineurs notés à la relecture du lot 1.

**Architecture:** Les écrans du lot 2 reposent sur les jetons « mix A » de `Theme` et sur six composants partagés (`ListRow`, `Panel`, `Chip`, `CharacterCard`, `ProgressCard`, `Toast`). On recale ces jetons sur la palette simulateur et on restyle ces composants : chaque fenêtre hérite du style sans réécriture. Les ajustements propres à une fenêtre viennent ensuite.

**Tech Stack:** Luau, Fusion 0.3, Rojo, Lune, StyLua, Selene, Roblox Studio MCP.

**Spec:** `docs/superpowers/specs/2026-11-11-ui-lobby-simulateur-design.md` (§3, §5.2, §5.3) ; lot 1 : `docs/superpowers/plans/2026-11-11-ui-simulateur-lot1.md`.

## Global Constraints
- Mêmes contraintes que le lot 1 (client seul, aucune donnée fictive, aucun encart payant, cibles ≥ 48 px réels, effets réduits respectés).
- Choix utilisateur du 11/11 : HUD compact (tuiles 64), cases au rebord fin avec liseré, icônes vectorielles ombrées **sans Blender**, rien qui dépasse des cases.
- `stylua` seulement sur les fichiers modifiés (autocrlf).

## Review Focus
- Fenêtre ouverte avec un snapshot sans `rewards`, `crew` ou `collection` : aucune erreur, lignes vides ou texte neutre.
- Interrupteur des Réglages cliqué vite plusieurs fois : l'état affiché suit le serveur.
- Toast pendant une fenêtre ouverte : lisible et au-dessus du voile.
- Combat : tuiles du menu, ProgressCard et bouton ATTAQUER rouge sans chevauchement avec la bannière de combat.
- Texte long (nom de look, description de succès) : tronqué ou réduit, jamais hors de la ligne.

---

### Task 1: Jetons et composants partagés
**Files:** `UI/Theme.luau`, `UI/Components/{Panel,ListRow,Chip,CharacterCard,ProgressCard,Toast}.luau`
- Theme :
  - `Accent` devient vert action (`#5BE36A`, clair `#8CF07F`, foncé `#22A93A`).
  - `PanelLine` passe à `Ink`, avec `Transparency.PanelLine` à 0 et `Transparency.Panel` à 0.
  - `Radius` : Panel 8, Button 6.
  - Couleurs de menu mix A alignées sur `Gradients.*.top`.
- **Panel** : fond plein `Panel`, contour `Ink` de 3, sans halo (`Glow` ne fait que colorer le contour).
- **ListRow** :
  - fond `PanelInner`, contour `Ink` de 2 avec liseré clair ;
  - titre FredokaOne contouré ;
  - bouton d'action = `Tile` au dégradé `Action`, libellé blanc contouré ;
  - interrupteur au vert action.
- **Chip** : coins 4, FredokaOne 12.
- **CharacterCard** : fond `PanelInner`, cadre de rareté de 3 px, nom contouré.
- **ProgressCard** : style panneau simulateur, masquée en mode compact (mineur 1 du lot 1).
- **Toast** : panneau simulateur, texte contouré.
- **Vérification** : tests Lune verts, selene ; en Play, captures des fenêtres Style, Crew, Équipe, Bonus et Réglages.

### Task 2: Mineurs du lot 1
- `BadgeModel.crewJoinedIsNew(event): boolean` (test : `isNew = false` ⇒ false, `isNew = true` ⇒ true, champ absent ⇒ true pour rester compatible). Le HUD n'allume la pastille Crew que si elle renvoie vrai.
- `MenuItem` : relâchement suivi par `UserInputService.InputEnded` (échelle remise à 1 même si le doigt sort de la case) ; pas de grossissement au survol sur écran tactile sans souris.
- Onglets latéraux : largeur `max(170, texte + 32)`.
- Tuile cadeau toujours visible (raccourci BONUS) ; seul le minuteur est masqué quand il est vide.
- **Vérification** : tests Lune ; Play.

### Task 3: Ajustements par écran et combat
- Style, Crew, Slots, Bonus, Decisions, Combat : remplacer les couleurs codées en dur qui tranchent avec le nouveau style, après lecture des captures de la tâche 1.
- Combat : vérifier la place des éléments ; ATTAQUER rouge.
- **Vérification** : captures Play de chaque écran.
