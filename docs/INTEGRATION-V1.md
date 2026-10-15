# Branche de test commune `integration/v1` (ne pas fusionner)

Assemble **sans rien fusionner dans `main`** : la PR #1 du codeur B (`b/p0-client`) et les PR #2 à #6 du codeur A
(`a/p1-combat` → `a/p2-slots` → `a/v1-ranking` → `a/v1-wardrobe` → `a/v1-metrics`).
Sert à jouer au jeu complet, HUD du codeur B + règles serveur du codeur A, avant les vraies fusions.
On la jette (ou on la recrée) quand les PR sont fusionnées dans l'ordre.

## Ce qui a été fait pour assembler

- Seul conflit : `src/client/Bootstrap.client.luau`. Résolution : `CelebrationController` (effets RGB, codeur A)
  démarre avant `StateController` ; puis `DevHUD` si `Flags.DEV_HUD`, sinon l'`App` du codeur B (cas actuel).
- `default.project.json` : remote `Combat` déclaré (étape prévue après les fusions ; `CombatService` le crée
  encore lui-même s'il manque).
- Vérifié : 105 tests serveur + 37 tests client (Lune), stylua, rojo build.

## Jouer

```bash
git fetch && git switch integration/v1
rojo serve
```

Studio → Rojo → Connect → F5. On voit le **HUD du codeur B** (le HUD DEV du codeur A est masqué :
`Flags.DEV_HUD = false`), plus, dans Studio uniquement, le panneau de combat (droite, touche F) et le panneau
SLOTS · P2 (haut droite, F4).

## Limites connues (en attente des ajustements 2 et 3 du codeur B)

- ~~Ajustement 1~~ fait (PR #1 à jour, 15/10) : le bouton principal du HUD envoie `Attack { encounterId }` en combat
  et `Train` au repos (`Logic/PrimaryAction`, 37 tests client).
- La barrière de rue du lobby est ouverte par la carte grise de test dans Studio seulement. Ajustement 2 :
  la retirer de `Lobby.rbxm` et placer les vraies arènes `Levels/LevelN/Arena` + `Door`.
- Ennemis rendus par la vue de test du codeur A. Ajustement 3 : rendu via `StateController.onCombat`,
  `DoorController` démarré depuis l'App, suppression de `CombatBootstrap.client.luau` et `Dev/DevCombat*`.
- Écrans Slots, Drops, Renaissance, Crew (collection), Style, classement du lobby et titres : pas encore côté
  HUD ; tout est testable via le panneau F4.
- luau-lsp signale des avertissements de type dans des fichiers UI Fusion du codeur B (`UI/Components/*`,
  `Controllers/HUD`, `Followers`) : déjà présents sur `b/p0-client`, sans effet à l'exécution observé.
