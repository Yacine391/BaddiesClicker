# V1 : lots du codeur A après le P2

Branches `a/v1-…`, empilées sur `a/p2-slots` (PR #3). Fiche séparée de `ROADMAP.md` pour ne pas créer de
conflit avec le codeur B ; à reporter dans la feuille de route après fusion.

## Classement du lobby (§15) — branche `a/v1-ranking`

- [x] `Rules/Ranking` : joueurs présents triés par score, rang partagé en cas d'égalité (1, 1, 3), ordre alphabétique à égalité
- [x] Score Baddies = identités du lot public découvertes (doublons, looks, boss rencontrés, drops non acceptés et identités de test exclus) ; onglet Crew séparé = compagnons possédés
- [x] `RankingService` : rafraîchissement groupé toutes les 2 s, état renvoyé aux joueurs seulement si le classement change ; calculé par le serveur, aucun score venant du client
- [x] Snapshot `ranking` (lot, total, `baddies`, `crew`) ; attributs `BC_BookCount`, `BC_CrewCount`
- [x] Panneau de test (F4) : carte CLASSEMENT ; 3 tests Lune (93 au total)
- [ ] Valider en Studio à 2 joueurs (ci-dessous)

**Côté codeur B** : tableau du lobby (3D ou HUD) depuis `snapshot.ranking`, « Alex - 7/8 », onglets Baddies / Crew.
Le classement mondial reste hors V1.

**Tester dans Studio** : onglet **Test → Clients and Servers**, 2 joueurs, Démarrer. Dans un des deux clients,
relancer (F4) jusqu'à une nouvelle baddie : en 2 s, la carte CLASSEMENT change dans les deux fenêtres.
Égalité : les deux joueurs affichent le rang 1.

## À venir

- [ ] Garde-robe, titres et succès (§19) : déblocages permanents, « Collection V1 complète » acquise même si une V2 ajoute des personnages
