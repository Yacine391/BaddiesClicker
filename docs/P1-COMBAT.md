# Lot P1 : un boss jouable (codeur A)

Branche `a/p1-combat`. Fiche séparée de `ROADMAP.md` pour ne pas créer de conflit avec la PR #1
du codeur B ; à reporter dans la feuille de route après fusion des deux branches.

## Fait (testé hors Studio : 40 tests Lune)

- [x] `Sessions` : PV de combat, rencontre en cours, sortie d'arène
- [x] Ennemis logiques côté serveur : approche → télégraphie (1 à 1,3 s) → impact → récupération
- [x] Sbire : frappe lente sur la position du joueur ; boss : frappe en cercle autour de lui
- [x] 1 ou 2 sbires simultanés, puis le boss ; ennemis individuels (personne ne vole ton boss)
- [x] Intentions `Attack(encounterId, targetId?)` (portée 25 studs, une application de dégâts) et `StartWave(levelId)` (rejouer)
- [x] Entrée dans l'arène = début de la vague ; accès vérifié par le serveur (porte N-1 ouverte + position)
- [x] Victoire boss : porte individuelle ouverte, +10 × niveau, +1 ticket au premier passage, **un seul** tirage à 10 % → drops en attente, sauvegarde prioritaire
- [x] Mort : retour lobby, portes refermées, puissance et possessions conservées ; dernier coup contre mort arbitré par le serveur
- [x] Tests §30 : boss vaincu sans drop, deux requêtes de victoire, 20 échecs boss, mort au niveau 8, esquive
- [x] Carte grise de test (10 arènes + portes, Studio), rendu et panneau de combat de test

## Reste

- [x] Valider en Studio : parcours complet des 10 niveaux (vagues, boss, portes), « rejouer » (15/10)
- [x] Valider en Studio : mort (retour lobby, portes refermées) et drop à 10 % (drops en attente) (15/10)
- [ ] Régler les chiffres (PV, dégâts, cadence) après les premiers combats réels
- [x] Après fusion de la PR #1 : remote `Combat` déclaré dans `default.project.json`, cases reportées dans `ROADMAP.md` (15/10)

## Côté codeur B (P1)

- [x] `Input` : envoyer `Attack { encounterId }` quand `snapshot.combat.active` (au lieu de `Train`) — PR #1, `Logic/PrimaryAction`
- [x] Retirer la barrière « lot P1 » de la rue (refonte UI) ; arènes réelles aux noms du contrat : `assets/world/LevelsBuilder.luau`, `lune run assets/world/export-levels` → `Levels.rbxm` (Workspace.Levels)
- [x] Rendu du combat (ennemis, cercles de danger, PV) via `StateController.onCombat` : `Controllers/Combat` + `Logic/CombatModel` (7 tests) ; `DoorController` démarré par l'App ; `CombatBootstrap` et `Dev/DevCombat*` supprimés

## Tester dans Studio

1. `rojo serve`, Baseplate, Rojo → Connect, F5.
2. Marche vers le nord jusqu'à l'arène « NIVEAU 1 · Street Block » : le combat démarre seul.
3. Panneau de droite : ATTAQUER (ou F). Sors des cercles rouges avant qu'ils soient pleins.
4. Bats Jade : effets RGB, la porte violette s'ouvre (pour toi seul). 10 % de chance de drop.
5. Mort : reste dans les cercles → retour au lobby, portes refermées, puissance conservée.
6. Dans une arène terminée : bouton REJOUER LE NIVEAU.
