# Équilibrage (dossier §29, §39) — codeur A

Les chiffres de `Shared/Balance` sont réglés avec un **simulateur** qui rejoue des parties complètes avec les
vraies règles du serveur (`Rules/Training`, `Crew`, `Combat`, `Encounter`, `Slots`, `Formulas`) : seul le
joueur est modélisé (vitesse de clic, réflexes, moment où il part au combat, ce qu'il fait de ses tickets).

```bash
lune run tools/simulate                           # rapport dans la console (≈ 1 min 30)
lune run tools/simulate --out docs/BALANCE-SIM.md # régénérer le rapport complet versionné
lune run tools/simulate --runs 30 --variant current
```

Rapport complet (tableaux par niveau, par joueur, avant/après) : [`BALANCE-SIM.md`](BALANCE-SIM.md).

## Joueurs modélisés

| Joueur | Entraînement | Attaque | Esquive | Part au combat quand… |
|---|---|---|---|---|
| Occasionnel | 3/s (maintien) | 4 clics/s | voit 85 % des zones, réagit en 0,25–0,6 s | la rencontre tient en ~60 coups |
| Pressé | 3/s | 4/s | idem | ~150 coups (rencontres longues, plus risquées) |
| Investi | 6/s | 7/s | 95 %, 0,2–0,4 s | ~80 coups |
| Farmeur | ne s'entraîne pas : rejoue le dernier niveau terminé | 4/s | 85 % | ~60 coups |

Tous : relancent le slot temporaire tant que leur principale est faible (garde à partir d'Iris ×1,8, ou
×2,5 pour l'investi), dépensent tout avant un rebirth qui efface, ouvrent les coffres, montent et équipent
les meilleurs compagnons, acceptent un drop meilleur ou nouveau. Ce sont des **hypothèses** : à comparer
aux statistiques réelles après publication (Creator Hub → Analytics, voir `V1-CODEUR-A.md`).

## Constat sur les valeurs de test du dossier (v4-p0)

1. **Le parcours ne demandait aucun entraînement.** Les récompenses de combat (2 × et 10 × niveau)
   suffisaient à passer au niveau suivant : 91 % de la puissance du premier parcours venait des combats,
   1 % de l'entraînement. Le cœur du jeu (« S'ENTRAÎNER ») ne servait qu'au tutoriel.
2. **Tout se consommait en une heure.** Parcours complet en 2 min 30, Baddies Book complet en 10 min,
   6 renaissances en 19 min (joueur occasionnel).
3. **Les ennemis n'avaient pas le temps d'attaquer** : 0 zone de danger par partie, aucune mort. L'esquive,
   la mort et la reprise (§10, §29 « morts par niveau ») n'existaient pas.
4. **Le boss du niveau 10 tuait d'un seul coup** (20 + 8 × 10 = 100 = PV du joueur), contraire à
   « une attaque ratée doit être compréhensible » (§08).
5. Avec des PV plus élevés mais les récompenses du dossier, **rejouer une vague devenait 30 % plus rapide
   que s'entraîner** (premier parcours en 18 min pour le farmeur contre 26 min pour l'occasionnel).

## Changements appliqués (Balance v4-p1)

Tous dans la liste des paramètres ouverts du dossier (§39 : PV, dégâts ennemis, récompenses de puissance).

| Paramètre | Avant | Après | Pourquoi |
|---|---|---|---|
| PV des niveaux 2 à 10 | 90 → 4 000 (sbire), 450 → 25 000 (boss) | 6 200 → 94 000, 32 000 → 570 000 | ≈ ce qu'un joueur occasionnel atteint en s'entraînant pour un premier parcours de ~27 min ; le niveau 1 garde 3 × 50 et 250 (§09) |
| Récompense sbire / boss | 2 × / 10 × niveau | 1 × / 5 × niveau | rejouer une vague rapporte autant que s'entraîner, pas plus (§12 « à équilibrer contre l'entraînement ») |
| Coup de sbire | 10 + 5 × niveau | 10 + 4 × niveau (50 au niveau 10) | deux erreurs avant la troisième fatale |
| Coup de boss | 20 + 8 × niveau | 20 + 6 × niveau (80 au niveau 10) | jamais mort d'un seul coup à PV pleins |
| Puissance conseillée | — | `nextLevel.recommendedPower` dans le snapshot | §09 : le saut de PV après le tutoriel doit être annoncé au joueur |

Inchangé (règles confirmées ou hors sujet) : drop de boss 10 % sans garantie, garanties toutes les 50
relances et 20 coffres, tickets (10 au départ, 1 toutes les 250 actions, +1 au premier passage, +5 au rebirth),
gain d'entraînement (+1 × bonus de rebirth), taux des compagnons, maîtrise, slots et conservation.

## Résultat (médianes, 100 parties par joueur)

| Moment | Occasionnel avant | Occasionnel après | Investi après | Farmeur après |
|---|---|---|---|---|
| Premier boss (niveau 1) | 32 s | 32 s | 42 s | 32 s |
| Deuxième quartier (niveau 3) | 57 s | 5 min 30 | 2 min 39 | 7 min 38 |
| Niveau 5 | 1 min 21 | 11 min 53 | 5 min 28 | 15 min 32 |
| Premier parcours (niveau 10) | 2 min 29 | 28 min 45 | 12 min 29 | 30 min 21 |
| Parcours suivants (2 → 6) | ~2 min 50 | 16 → 10 min | 9 → 6 min | 20 → 11 min |
| Baddies Book complet | 9 min 32 | 48 min | 22 min | 1 h 05 |
| Les 6 compagnons | 1 h 00 | 1 h 06 | 40 min | 3 h 35 |
| 6e renaissance (4 slots) | 18 min 34 | 1 h 35 | 49 min | 1 h 49 |

Premier parcours de l'occasionnel : entraînement 54 % de la puissance, compagnons 39 %, combats 7 % ;
65 % du temps à s'entraîner, au plus 2 min 50 d'entraînement d'affilée sans décision. Morts : 0,5 par
partie (occasionnel), aucune (investi), 13,6 (pressé, surtout niveaux 7 à 10 : se précipiter fait gagner
du temps mais coûte des allers-retours). Le farmeur va aussi vite que l'occasionnel, gagne bien plus de
drops (73 contre 6) mais aucun ticket d'entraînement, donc ses compagnons arrivent bien plus tard :
deux façons de jouer viables, aucune dominante.

## Points à surveiller (décisions ouvertes)

- **Production passive** : 39 % de la puissance du premier parcours, 55 % sur l'ensemble (les compagnons
  produisent aussi en combat et en trajet). §29 demande de revoir les taux si l'attente passive domine.
  Leviers sans toucher au dossier confirmé : un ticket compagnon toutes les 750 actions au lieu de 500,
  ou des taux de base plus bas. À trancher avec les premières statistiques réelles.
- **Saut après le tutoriel** : le niveau 2 demande ~900 de puissance avec Maya (contre 7 au niveau 1).
  Le HUD du codeur B doit afficher `nextLevel.recommendedPower` (« Puissance conseillée : 886 »).
- **Contenu V1 court pour un joueur investi** (Book en 22 min, crew en 40 min) : normal pour 8 baddies et
  6 compagnons ; les lots du catalogue futur rallongeront.
- **Hypothèses joueur** : le moment où un vrai joueur part au combat change tout (pressé contre occasionnel).
  Après publication, comparer `TempsPremierBoss`, `DureeParcours`, `PuissanceALaMort` et la progression par
  niveau aux médianes ci-dessus, puis corriger les profils du simulateur avant de retoucher la Balance.

## Régler ensuite

1. Modifier `Shared/Balance` (jamais une règle confirmée).
2. `lune run tools/simulate --runs 50 --variant current` pour un premier regard, puis le rapport complet.
3. `lune run tests/run` : les garde-fous d'équilibrage (aucun coup mortel d'un coup, PV croissants) doivent passer.
4. Régénérer `docs/BALANCE-SIM.md` et noter le changement ici.
