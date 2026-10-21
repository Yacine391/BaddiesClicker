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
- [x] Valider en Studio (15/10) : 6 succès sur 10 accordés au profil de test, cosmétiques et titre portés ou retirés depuis le panneau
- [x] 5 badges créés le 15/10 (gratuits) et leurs IDs dans `BadgesConfig.luau`
- [ ] 5 badges restants (Première renaissance, Book Baddies V1, Book Crew V1, Mythic découverte, Collection V1 complète) : gratuits après 2 h (heure de Paris)

Sans source pour l'instant (à annoncer : missions ou événement) : montre, lunettes, aura Neon, trail d'étoiles.

**Côté codeur B** : écran Style (cosmétiques et titres, prévisualisation), titre au-dessus des avatars depuis
`BC_Title` (distance limitée, couleur lisible, option pour masquer ceux des autres), accessoires depuis
`BC_Style`, liste des succès depuis `snapshot.style`.

**Tester dans Studio** : au lancement, ton profil de test remplit déjà plusieurs conditions (Malik, renaissance,
parcours…) : les bannières « SUCCÈS » arrivent dans les 2 s. Carte GARDE-ROBE du panneau F4 : cliquer un
cosmétique ou un titre le porte (✓), recliquer le retire. Stop puis Play : tout est conservé.

## Statistiques de jeu (§29, §36) — branche `a/v1-metrics`

Envoyées par le **serveur** à AnalyticsService (jamais par le client), sans donnée personnelle.
À lire dans le Creator Hub → l'expérience → **Analytics** (onglets Onboarding, Progression, Economy, Custom).
Dans Studio, rien n'est envoyé : chaque événement s'écrit dans la sortie (`[Metrics] …`) pour vérifier.

| Onglet | Événement | Ce qu'il mesure |
|---|---|---|
| Onboarding | 1 Profil chargé → 2 Premier entraînement → 3 Malik obtenu → 4 Premier combat → 5 Premier boss vaincu → 6 Deuxième quartier → 7 Parcours terminé → 8 Première renaissance | où les nouveaux joueurs décrochent (une fois par joueur) |
| Progression | « Parcours », niveaux 1 à 10 : début, échec (mort), réussite | morts par niveau, niveaux trop durs |
| Economy | `TicketBaddie`, `TicketCrew` : gagnés (Entrainement, PremierPassage, Renaissance), dépensés (Relance, Coffre) | rythme des tickets |
| Custom | `TempsPremierCombat`, `TempsPremierBoss`, `DureeParcours` (secondes de jeu) | temps jusqu'aux premiers moments forts |
| Custom | `PuissanceALaMort` (niveau, tranche de puissance), `RepriseApresMort` (secondes avant de retenter) | difficulté, abandon après une mort |
| Custom | `RelancesJusquaDecouverte` (baddie, garantie ou table), `NouveauCompagnon`, `DropBoss`, `DecisionDrop` (accepter / refuser) | collection et décisions |
| Custom | `BaddieEffaceeAuRebirth` (baddie, rareté) | compréhension de la conservation |
| Custom | `RencontreInvalidee` (niveau, « deplacement ») | combats annulés par le contrôle des déplacements (§25) |

- [x] `Rules/Metrics` (étapes uniques, temps de jeu cumulé, relances jusqu'à découverte, tranches de puissance) ; profil `analytics` + garde-fous ; 5 tests Lune (105 au total)
- [x] `MetricsService` branché sur l'entraînement, le combat, les relances, les drops, les coffres et la renaissance
- [x] Valider en Studio (15/10) : `[Metrics] TicketBaddie -1 (Relance) → 18`, `RelancesJusquaDecouverte = 1 · iris · table` après une relance écrite en 666 ms
- [ ] Après publication : vérifier les premiers chiffres dans le Creator Hub (délai de quelques heures côté Roblox)

## Équilibrage (§29, §39) — branche `a/v1-balance-anticheat`

Détails, chiffres avant/après et décisions ouvertes : [`BALANCE.md`](BALANCE.md) ; rapport complet du simulateur : [`BALANCE-SIM.md`](BALANCE-SIM.md).

- [x] `tools/simulate.luau` (Lune) : parties complètes jouées avec les règles du serveur ; 4 joueurs modélisés (occasionnel, pressé, investi, farmeur) ; moments clés, morts par niveau, sources de puissance et de tickets, rendement d'une vague rejouée
- [x] Constat : les valeurs de test du dossier ne demandaient aucun entraînement (parcours en 2 min 30, Book en 10 min, aucune mort) et le boss 10 tuait d'un seul coup
- [x] Balance v4-p1 : PV des niveaux 2 à 10 (premier parcours ≈ 29 min pour un joueur occasionnel), récompenses 1 × / 5 × niveau (rejouer = s'entraîner), coups ennemis plafonnés sous 100
- [x] Puissance conseillée (§09) : `Combat.recommendedPower` et `nextLevel` dans le snapshot ; garde-fous d'équilibrage dans les tests
- [ ] Codeur B : afficher `nextLevel.recommendedPower` près de la porte ou dans le HUD
- [ ] Après publication : comparer les statistiques réelles aux médianes du simulateur, ajuster les profils puis la Balance

## Anti-triche des déplacements (§25) — branche `a/v1-balance-anticheat`

- [x] `Rules/Movement` (pur) : chaque position du personnage pendant un combat est comparée à la précédente ; vitesse permise = WalkSpeed **serveur** × 1,25 + 4 studs/s, réserve de 2 s pour la latence, marge de 8 studs ; la hauteur ne compte pas (zones de danger en 2D)
- [x] Anomalie isolée (pic de latence, chute, à-coup physique) : une ligne de journal, rien d'autre ; 3 anomalies en 20 s : rencontre invalidée, gains de la vague retirés, nouvelle vague possible après 5 s ; jamais de mort ni de bannissement
- [x] Branché dans `CombatService` (tick 10/s et chaque attaque), statistique `RencontreInvalidee`, `Result` `combatInvalid`, `end` avec `reason = "invalid"`
- [x] 10 tests Lune (marche normale, latence, téléportations, vitesse ×2 et ×1,2, WalkSpeed serveur, NaN, déplacement voulu par le jeu)
- [x] Outil Studio : bouton TÉLÉPORT (F4, en combat) — 1 clic = 1 anomalie sans effet, 3 clics en 20 s = combat annulé
- [ ] Valider en Studio (voir ci-dessous) puis surveiller `[Movement]` et `RencontreInvalidee` après publication
- [ ] Codeur B : toast neutre sur `combatInvalid` ; toute vitesse de marche réglée côté serveur

Test Studio : Play, entrer dans l'arène 1, F4 → TÉLÉPORT une fois (sortie : `[Movement] … anomalie 1/3 … (sans effet)`,
le combat continue), puis deux fois de plus en moins de 20 s (`rencontre invalidée`, panneau F4 : « Combat du niveau 1
invalidé »). Marcher et sauter normalement dans l'arène ne doit jamais rien écrire.
