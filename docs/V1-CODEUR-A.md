# V1 : lots du codeur A après le P2

Branches `a/v1-…`, empilées sur `a/p2-slots` (PR #3). Fiche séparée de `ROADMAP.md` pour ne pas créer de
conflit avec le codeur B ; à reporter dans la feuille de route après fusion.

## Classement du lobby (§15) — branche `a/v1-ranking`

- [x] `Rules/Ranking` : joueurs présents triés par score, rang partagé en cas d'égalité (1, 1, 3), ordre alphabétique à égalité
- [x] Score Baddies = identités du lot public découvertes (doublons, looks, boss rencontrés, drops non acceptés et identités de test exclus) ; onglet Crew séparé = compagnons possédés
- [x] `RankingService` : rafraîchissement groupé toutes les 2 s, état renvoyé aux joueurs seulement si le classement change ; calculé par le serveur, aucun score venant du client
- [x] Snapshot `ranking` (lot, total, `baddies`, `crew`) ; attributs `BC_BookCount`, `BC_CrewCount`
- [x] Panneau de test (F4) : carte CLASSEMENT ; 3 tests Lune (93 au total)
- [x] Valider en Studio à 2 joueurs (15/10) : Player1 2/8 devant Player2 1/8, onglet Crew séparé ; vérifie aussi le test « 2 joueurs » du P0

**Côté codeur B** : tableau du lobby (3D ou HUD) depuis `snapshot.ranking`, « Alex - 7/8 », onglets Baddies / Crew.
Le classement mondial reste hors V1.

**Tester dans Studio** : onglet **Test → Clients and Servers**, 2 joueurs, Démarrer. Dans un des deux clients,
relancer (F4) jusqu'à une nouvelle baddie : en 2 s, la carte CLASSEMENT change dans les deux fenêtres.
Égalité : les deux joueurs affichent le rang 1.

## Garde-robe, titres et succès (§19) — branche `a/v1-wardrobe`

- [x] `Shared/Wardrobe` : 8 emplacements (cou, poignet, visage, tête, aura, trail, pose, cadre), 12 cosmétiques, 3 titres, 10 succès et leurs récompenses ; listes du lot V1 **figées**
- [x] `Rules/Achievements` : conditions serveur, récompenses données une seule fois, « Collection V1 complète » conservée si une V2 ajoute des personnages ; un drop non accepté ne compte pas
- [x] `WardrobeService` : vérification groupée toutes les 2 s, écriture prioritaire, Result `achievement` ; badges Roblox via `Config/BadgesConfig` (IDs à renseigner), réessayés sans redonner les récompenses, jamais dans Studio
- [x] `SetStyle { slot, id? }` hors combat ; snapshot `style` ; attributs `BC_Title`, `BC_Style` ; garde-fous du profil (sélection non débloquée retirée)
- [x] `CelebrationController` : bannière RGB « SUCCÈS : … » ; panneau de test : carte GARDE-ROBE
- [x] 7 tests Lune (100 au total)
- [ ] Valider en Studio (ci-dessous)
- [ ] Créer les 10 badges dans le Creator Dashboard et coller leurs IDs dans `src/server/Config/BadgesConfig.luau`

Sans source pour l'instant (à annoncer : missions ou événement) : montre, lunettes, aura Neon, trail d'étoiles.

**Côté codeur B** : écran Style (cosmétiques et titres, prévisualisation), titre au-dessus des avatars depuis
`BC_Title` (distance limitée, couleur lisible, option pour masquer ceux des autres), accessoires depuis
`BC_Style`, liste des succès depuis `snapshot.style`.

**Tester dans Studio** : au lancement, ton profil de test remplit déjà plusieurs conditions (Malik, renaissance,
parcours…) : les bannières « SUCCÈS » arrivent dans les 2 s. Carte GARDE-ROBE du panneau F4 : cliquer un
cosmétique ou un titre le porte (✓), recliquer le retire. Stop puis Play : tout est conservé.
