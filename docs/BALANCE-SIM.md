# Rapport du simulateur d'équilibrage (`lune run tools/simulate`)

Généré par `tools/simulate.luau` : 100 parties par joueur et par réglage, graine 20261015. Les règles sont celles du serveur ; seul le joueur est modélisé.

## Avant : valeurs de test du dossier (v4-p0)

| Niveau | Sbires × PV | PV boss | Coup sbire / boss | Coups pour mourir | Puissance pour ~60 coups | Récompense de la vague | Rejouer avec la puissance du niveau suivant |
|---|---|---|---|---|---|---|---|
| 1 | 3 × 50 | 250 | 15 / 28 | 7 / 4 | 7 | 16 | 1,1/s |
| 2 | 3 × 90 | 450 | 20 / 36 | 5 / 3 | 13 | 32 | 2,4/s |
| 3 | 4 × 150 | 800 | 25 / 44 | 4 / 3 | 25 | 54 | 3,6/s |
| 4 | 4 × 250 | 1400 | 30 / 52 | 4 / 2 | 42 | 72 | 4,8/s |
| 5 | 4 × 400 | 2500 | 35 / 60 | 3 / 2 | 70 | 90 | 5,7/s |
| 6 | 4 × 650 | 4000 | 40 / 68 | 3 / 2 | 112 | 108 | 7,2/s |
| 7 | 5 × 1000 | 6500 | 45 / 76 | 3 / 2 | 200 | 140 | 8,6/s |
| 8 | 5 × 1600 | 10000 | 50 / 84 | 2 / 2 | 320 | 160 | 10,0/s |
| 9 | 5 × 2500 | 16000 | 55 / 92 | 2 / 2 | 500 | 180 | 11,2/s |
| 10 | 5 × 4000 | 25000 | 60 / 100 | 2 / 1 | 800 | 200 | — |

Entraînement : 3,0 puissance/s au maintien (×1,1 par renaissance). Rendement d'une vague rejouée : 4 clics/s et 6 s d'apparitions, avec la puissance qui suffit au niveau suivant.

### Joueur « Occasionnel » (100 parties de 10 h 00 maximum)

Entraînement 3/s, attaque 4/s, voit 85 % des zones (réaction 0,25–0,60 s), part au combat vers 60 coups, garde une principale à partir de ×1,8.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 13 s | 7 s | 25 s | 100 % |
| Premier combat | 29 s | 23 s | 41 s | 100 % |
| Premier boss vaincu (niveau 1) | 32 s | 26 s | 44 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 55 s | 48 s | 1 min 07 | 100 % |
| Niveau 5 terminé | 1 min 19 | 1 min 13 | 1 min 33 | 100 % |
| Premier parcours terminé (niveau 10) | 2 min 28 | 2 min 19 | 2 min 43 | 100 % |
| Première renaissance | 2 min 36 | 2 min 28 | 2 min 51 | 100 % |
| 3e renaissance | 9 min 26 | 8 min 57 | 9 min 38 | 100 % |
| 6e renaissance (4 slots) | 18 min 33 | 18 min 22 | 18 min 45 | 100 % |
| Premier drop de boss | 1 min 35 | 38 s | 7 min 06 | 100 % |
| 4 baddies au Baddies Book | 2 min 31 | 9 s | 2 min 48 | 100 % |
| Baddies Book complet (9) | 12 min 17 | 9 min 21 | 18 min 56 | 100 % |
| Vega (Mythic) découverte | 9 min 30 | 2 min 42 | 18 min 43 | 100 % |
| Les 6 compagnons | 1 h 00 | 27 min 36 | 1 h 07 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 2 min 28 · parcours 2 : 3 min 17 · parcours 3 : 2 min 48 · parcours 4 : 2 min 49 · parcours 5 : 2 min 49 · parcours 6 : 2 min 48.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 18,9 | 0,00 | 0,00 | 3 s | 44 |
| 2 | 17,9 | 0,00 | 0,00 | 3 s | 82 |
| 3 | 17,9 | 0,00 | 0,00 | 4 s | 144 |
| 4 | 17,9 | 0,00 | 0,00 | 4 s | 223 |
| 5 | 17,9 | 0,00 | 0,00 | 4 s | 320 |
| 6 | 17,9 | 0,00 | 0,00 | 4 s | 435 |
| 7 | 17,9 | 0,00 | 0,00 | 5 s | 583 |
| 8 | 17,9 | 0,00 | 0,00 | 5 s | 752 |
| 9 | 17,9 | 0,00 | 0,00 | 6 s | 940 |
| 10 | 17,9 | 0,00 | 0,00 | 6 s | 1149 |

- Temps de jeu : entraînement 0 %, combat 19 %, trajets 52 %, menus 29 %.
- Puissance gagnée pendant le premier parcours : entraînement 1 %, compagnons (passif) 7 %, combats 91 % ; sur toute la partie : 0 %, 44 %, 55 %.
- Tickets baddie : départ 4 %, entraînement 0 %, premiers passages 64 %, renaissances 32 %.
- Entraînement d'affilée sans décision : médiane 5 s, plus long par partie 5 s (médiane), 5 s (10 % des parties).
- Zones de danger : 0 par partie, 0 % touchent ; drops reçus 18,0, acceptés 13,1 par partie.
- Relances quand le Book est complet : médiane 63, 90 % des parties sous 100 ; garanties utilisées 1,3 par partie.

### Joueur « Pressé » (100 parties de 10 h 00 maximum)

Entraînement 3/s, attaque 4/s, voit 85 % des zones (réaction 0,25–0,60 s), part au combat vers 150 coups, garde une principale à partir de ×1,8.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 13 s | 7 s | 25 s | 93 % |
| Premier combat | 29 s | 23 s | 41 s | 100 % |
| Premier boss vaincu (niveau 1) | 32 s | 26 s | 44 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 56 s | 49 s | 1 min 07 | 100 % |
| Niveau 5 terminé | 1 min 20 | 1 min 13 | 1 min 33 | 100 % |
| Premier parcours terminé (niveau 10) | 2 min 28 | 2 min 19 | 2 min 43 | 100 % |
| Première renaissance | 2 min 36 | 2 min 30 | 2 min 51 | 100 % |
| 3e renaissance | 9 min 26 | 8 min 57 | 9 min 38 | 100 % |
| 6e renaissance (4 slots) | 18 min 34 | 18 min 23 | 18 min 44 | 100 % |
| Premier drop de boss | 1 min 36 | 38 s | 7 min 38 | 100 % |
| 4 baddies au Baddies Book | 2 min 33 | 9 s | 2 min 48 | 100 % |
| Baddies Book complet (9) | 12 min 17 | 9 min 21 | 18 min 56 | 100 % |
| Vega (Mythic) découverte | 9 min 29 | 2 min 42 | 18 min 45 | 100 % |
| Les 6 compagnons | 1 h 00 | 27 min 56 | 1 h 12 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 2 min 28 · parcours 2 : 3 min 19 · parcours 3 : 2 min 47 · parcours 4 : 2 min 49 · parcours 5 : 2 min 49 · parcours 6 : 2 min 48.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 19,4 | 0,00 | 0,00 | 3 s | 44 |
| 2 | 18,4 | 0,00 | 0,00 | 3 s | 82 |
| 3 | 18,4 | 0,00 | 0,00 | 4 s | 144 |
| 4 | 18,4 | 0,00 | 0,00 | 4 s | 223 |
| 5 | 18,4 | 0,00 | 0,00 | 4 s | 320 |
| 6 | 18,4 | 0,00 | 0,00 | 4 s | 435 |
| 7 | 18,4 | 0,00 | 0,00 | 5 s | 583 |
| 8 | 18,4 | 0,00 | 0,00 | 5 s | 752 |
| 9 | 18,4 | 0,00 | 0,00 | 6 s | 940 |
| 10 | 18,4 | 0,00 | 0,00 | 6 s | 1149 |

- Temps de jeu : entraînement 0 %, combat 19 %, trajets 52 %, menus 29 %.
- Puissance gagnée pendant le premier parcours : entraînement 1 %, compagnons (passif) 7 %, combats 92 % ; sur toute la partie : 0 %, 45 %, 55 %.
- Tickets baddie : départ 4 %, entraînement 0 %, premiers passages 64 %, renaissances 32 %.
- Entraînement d'affilée sans décision : médiane 5 s, plus long par partie 5 s (médiane), 5 s (10 % des parties).
- Zones de danger : 1 par partie, 0 % touchent ; drops reçus 18,5, acceptés 13,4 par partie.
- Relances quand le Book est complet : médiane 63, 90 % des parties sous 100 ; garanties utilisées 1,3 par partie.

### Joueur « Investi » (100 parties de 10 h 00 maximum)

Entraînement 6/s, attaque 7/s, voit 95 % des zones (réaction 0,20–0,40 s), part au combat vers 80 coups, garde une principale à partir de ×2,5.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 25 s | 7 s | 27 s | 100 % |
| Premier combat | 40 s | 22 s | 42 s | 100 % |
| Premier boss vaincu (niveau 1) | 42 s | 25 s | 45 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 59 s | 42 s | 1 min 08 | 100 % |
| Niveau 5 terminé | 1 min 18 | 1 min 01 | 1 min 35 | 100 % |
| Premier parcours terminé (niveau 10) | 2 min 10 | 1 min 53 | 2 min 42 | 100 % |
| Première renaissance | 2 min 16 | 2 min 01 | 2 min 50 | 100 % |
| 3e renaissance | 7 min 41 | 7 min 22 | 7 min 49 | 100 % |
| 6e renaissance (4 slots) | 15 min 07 | 14 min 59 | 15 min 16 | 100 % |
| Premier drop de boss | 1 min 20 | 41 s | 4 min 55 | 100 % |
| 4 baddies au Baddies Book | 18 s | 5 s | 2 min 07 | 100 % |
| Baddies Book complet (9) | 9 min 27 | 7 min 34 | 15 min 24 | 100 % |
| Vega (Mythic) découverte | 7 min 42 | 2 min 21 | 15 min 17 | 100 % |
| Les 6 compagnons | 47 min 20 | 22 min 39 | 50 min 13 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 2 min 10 · parcours 2 : 2 min 34 · parcours 3 : 2 min 18 · parcours 4 : 2 min 19 · parcours 5 : 2 min 19 · parcours 6 : 2 min 18.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 18,0 | 0,00 | 0,00 | 3 s | 58 |
| 2 | 17,0 | 0,00 | 0,00 | 3 s | 95 |
| 3 | 17,0 | 0,00 | 0,00 | 3 s | 156 |
| 4 | 17,0 | 0,00 | 0,00 | 3 s | 234 |
| 5 | 17,0 | 0,00 | 0,00 | 4 s | 330 |
| 6 | 17,0 | 0,00 | 0,00 | 4 s | 443 |
| 7 | 17,0 | 0,00 | 0,00 | 4 s | 589 |
| 8 | 17,0 | 0,00 | 0,00 | 4 s | 756 |
| 9 | 17,0 | 0,00 | 0,00 | 5 s | 943 |
| 10 | 17,0 | 0,00 | 0,00 | 5 s | 1150 |

- Temps de jeu : entraînement 0 %, combat 22 %, trajets 49 %, menus 29 %.
- Puissance gagnée pendant le premier parcours : entraînement 3 %, compagnons (passif) 6 %, combats 91 % ; sur toute la partie : 0 %, 39 %, 61 %.
- Tickets baddie : départ 4 %, entraînement 0 %, premiers passages 64 %, renaissances 32 %.
- Entraînement d'affilée sans décision : médiane 5 s, plus long par partie 5 s (médiane), 5 s (10 % des parties).
- Zones de danger : 0 par partie, 0 % touchent ; drops reçus 17,5, acceptés 13,0 par partie.
- Relances quand le Book est complet : médiane 55, 90 % des parties sous 100 ; garanties utilisées 1,3 par partie.

### Joueur « Farmeur » (100 parties de 10 h 00 maximum)

Entraînement 3/s, attaque 4/s, voit 85 % des zones (réaction 0,25–0,60 s), part au combat vers 60 coups, garde une principale à partir de ×1,8.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 13 s | 7 s | 25 s | 100 % |
| Premier combat | 29 s | 23 s | 41 s | 100 % |
| Premier boss vaincu (niveau 1) | 32 s | 26 s | 44 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 55 s | 48 s | 1 min 07 | 100 % |
| Niveau 5 terminé | 1 min 19 | 1 min 13 | 1 min 33 | 100 % |
| Premier parcours terminé (niveau 10) | 2 min 28 | 2 min 19 | 2 min 43 | 100 % |
| Première renaissance | 2 min 36 | 2 min 28 | 2 min 51 | 100 % |
| 3e renaissance | 9 min 26 | 8 min 57 | 9 min 38 | 100 % |
| 6e renaissance (4 slots) | 18 min 33 | 18 min 22 | 18 min 45 | 100 % |
| Premier drop de boss | 1 min 35 | 38 s | 7 min 06 | 100 % |
| 4 baddies au Baddies Book | 2 min 31 | 9 s | 2 min 48 | 100 % |
| Baddies Book complet (9) | 12 min 17 | 9 min 21 | 18 min 56 | 100 % |
| Vega (Mythic) découverte | 9 min 30 | 2 min 42 | 18 min 43 | 100 % |
| Les 6 compagnons | 1 h 00 | 27 min 36 | 1 h 07 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 2 min 28 · parcours 2 : 3 min 17 · parcours 3 : 2 min 48 · parcours 4 : 2 min 49 · parcours 5 : 2 min 49 · parcours 6 : 2 min 48.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 18,9 | 0,00 | 0,00 | 3 s | 44 |
| 2 | 17,9 | 0,00 | 0,00 | 3 s | 82 |
| 3 | 17,9 | 0,00 | 0,00 | 4 s | 144 |
| 4 | 17,9 | 0,00 | 0,00 | 4 s | 223 |
| 5 | 17,9 | 0,00 | 0,00 | 4 s | 320 |
| 6 | 17,9 | 0,00 | 0,00 | 4 s | 435 |
| 7 | 17,9 | 0,00 | 0,00 | 5 s | 583 |
| 8 | 17,9 | 0,00 | 0,00 | 5 s | 752 |
| 9 | 17,9 | 0,00 | 0,00 | 6 s | 940 |
| 10 | 17,9 | 0,00 | 0,00 | 6 s | 1149 |

- Temps de jeu : entraînement 0 %, combat 19 %, trajets 52 %, menus 29 %.
- Puissance gagnée pendant le premier parcours : entraînement 1 %, compagnons (passif) 7 %, combats 91 % ; sur toute la partie : 0 %, 44 %, 55 %.
- Tickets baddie : départ 4 %, entraînement 0 %, premiers passages 64 %, renaissances 32 %.
- Entraînement d'affilée sans décision : médiane 5 s, plus long par partie 5 s (médiane), 5 s (10 % des parties).
- Zones de danger : 0 par partie, 0 % touchent ; drops reçus 18,0, acceptés 13,1 par partie.
- Relances quand le Book est complet : médiane 63, 90 % des parties sous 100 ; garanties utilisées 1,3 par partie.
- Vagues rejouées au lieu de s'entraîner : 0 par partie.

## Après : Balance actuelle (v4-p2)

| Niveau | Sbires × PV | PV boss | Coup sbire / boss | Coups pour mourir | Puissance pour ~60 coups | Récompense de la vague | Rejouer avec la puissance du niveau suivant |
|---|---|---|---|---|---|---|---|
| 1 | 3 × 50 | 250 | 14 / 26 | 8 / 4 | 7 | 8 | 1,1/s |
| 2 | 3 × 6200 | 32000 | 18 / 32 | 6 / 4 | 886 | 16 | 1,3/s |
| 3 | 4 × 14000 | 71000 | 22 / 38 | 5 / 3 | 2219 | 27 | 1,8/s |
| 4 | 4 × 23000 | 119000 | 26 / 44 | 4 / 3 | 3719 | 36 | 2,4/s |
| 5 | 4 × 34000 | 209000 | 30 / 50 | 4 / 2 | 5806 | 45 | 2,4/s |
| 6 | 4 × 45000 | 230000 | 34 / 56 | 3 / 2 | 7188 | 54 | 3,1/s |
| 7 | 5 × 56000 | 285000 | 38 / 62 | 3 / 2 | 9500 | 70 | 3,8/s |
| 8 | 5 × 69000 | 348000 | 42 / 68 | 3 / 2 | 11600 | 80 | 4,0/s |
| 9 | 5 × 81000 | 412000 | 46 / 74 | 3 / 2 | 13734 | 90 | 5,1/s |
| 10 | 5 × 94000 | 570000 | 50 / 80 | 2 / 2 | 18800 | 100 | — |

Entraînement : 3,0 puissance/s au maintien (×1,1 par renaissance). Rendement d'une vague rejouée : 4 clics/s et 6 s d'apparitions, avec la puissance qui suffit au niveau suivant.

### Joueur « Occasionnel » (100 parties de 10 h 00 maximum)

Entraînement 3/s, attaque 4/s, voit 85 % des zones (réaction 0,25–0,60 s), part au combat vers 60 coups, garde une principale à partir de ×1,8.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 13 s | 7 s | 25 s | 100 % |
| Premier combat | 29 s | 23 s | 41 s | 100 % |
| Premier boss vaincu (niveau 1) | 32 s | 26 s | 44 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 5 min 33 | 4 min 40 | 6 min 27 | 100 % |
| Niveau 5 terminé | 11 min 53 | 9 min 20 | 14 min 21 | 100 % |
| Premier parcours terminé (niveau 10) | 28 min 17 | 22 min 11 | 33 min 53 | 100 % |
| Première renaissance | 28 min 25 | 22 min 21 | 34 min 01 | 100 % |
| 3e renaissance | 58 min 52 | 51 min 39 | 1 h 12 | 100 % |
| 6e renaissance (4 slots) | 1 h 31 | 1 h 20 | 1 h 47 | 100 % |
| Premier drop de boss | 17 min 55 | 2 min 07 | 43 min 50 | 100 % |
| 4 baddies au Baddies Book | 23 min 28 | 9 s | 33 min 27 | 100 % |
| Baddies Book complet (9) | 53 min 57 | 37 min 24 | 1 h 18 | 100 % |
| Vega (Mythic) découverte | 47 min 25 | 29 min 06 | 1 h 12 | 100 % |
| Les 6 compagnons | 1 h 04 | 30 min 47 | 1 h 11 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 28 min 17 · parcours 2 : 15 min 17 · parcours 3 : 14 min 13 · parcours 4 : 11 min 05 · parcours 5 : 9 min 39 · parcours 6 : 9 min 01.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 6,6 | 0,00 | 0,00 | 3 s | 36 |
| 2 | 6,5 | 0,00 | 0,00 | 14 s | 443 |
| 3 | 6,5 | 0,00 | 0,00 | 15 s | 1043 |
| 4 | 6,5 | 0,01 | 0,00 | 15 s | 1683 |
| 5 | 6,5 | 0,07 | 0,00 | 15 s | 2610 |
| 6 | 6,5 | 0,05 | 0,00 | 15 s | 3090 |
| 7 | 6,4 | 0,08 | 0,00 | 15 s | 4039 |
| 8 | 6,3 | 0,13 | 0,00 | 15 s | 4917 |
| 9 | 6,2 | 0,11 | 0,00 | 15 s | 5814 |
| 10 | 6,1 | 0,00 | 0,00 | 14 s | 7912 |

- Temps de jeu : entraînement 65 %, combat 15 %, trajets 11 %, menus 9 %.
- Puissance gagnée pendant le premier parcours : entraînement 54 %, compagnons (passif) 39 %, combats 7 % ; sur toute la partie : 36 %, 55 %, 10 %.
- Tickets baddie : départ 7 %, entraînement 30 %, premiers passages 42 %, renaissances 21 %.
- Entraînement d'affilée sans décision : médiane 34 s, plus long par partie 2 min 50 (médiane), 2 min 50 (10 % des parties).
- Zones de danger : 205 par partie, 5 % touchent ; drops reçus 6,5, acceptés 3,4 par partie.
- Relances quand le Book est complet : médiane 64, 90 % des parties sous 100 ; garanties utilisées 1,3 par partie.
- Puissance à la mort : médiane 3243 (45 morts sur 100 parties).

### Joueur « Pressé » (100 parties de 10 h 00 maximum)

Entraînement 3/s, attaque 4/s, voit 85 % des zones (réaction 0,25–0,60 s), part au combat vers 150 coups, garde une principale à partir de ×1,8.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 16 s | 7 s | 34 s | 100 % |
| Premier combat | 29 s | 23 s | 41 s | 100 % |
| Premier boss vaincu (niveau 1) | 32 s | 26 s | 44 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 3 min 36 | 3 min 01 | 3 min 59 | 100 % |
| Niveau 5 terminé | 7 min 45 | 6 min 33 | 10 min 27 | 100 % |
| Premier parcours terminé (niveau 10) | 18 min 58 | 14 min 17 | 26 min 20 | 100 % |
| Première renaissance | 19 min 06 | 14 min 25 | 26 min 28 | 100 % |
| 3e renaissance | 44 min 44 | 37 min 39 | 56 min 06 | 100 % |
| 6e renaissance (4 slots) | 1 h 13 | 1 h 02 | 1 h 25 | 100 % |
| Premier drop de boss | 8 min 44 | 1 min 04 | 21 min 39 | 100 % |
| 4 baddies au Baddies Book | 16 min 14 | 9 s | 24 min 29 | 100 % |
| Baddies Book complet (9) | 49 min 27 | 35 min 12 | 1 h 17 | 100 % |
| Vega (Mythic) découverte | 38 min 53 | 19 min 30 | 1 h 11 | 100 % |
| Les 6 compagnons | 2 h 14 | 1 h 17 | 2 h 46 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 18 min 58 · parcours 2 : 13 min 25 · parcours 3 : 10 min 40 · parcours 4 : 9 min 28 · parcours 5 : 8 min 32 · parcours 6 : 7 min 43.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 29,4 | 0,00 | 0,00 | 3 s | 36 |
| 2 | 28,4 | 0,02 | 0,00 | 32 s | 203 |
| 3 | 28,4 | 0,16 | 0,00 | 36 s | 454 |
| 4 | 28,2 | 0,32 | 0,00 | 36 s | 743 |
| 5 | 27,9 | 1,21 | 0,00 | 37 s | 1314 |
| 6 | 26,7 | 1,11 | 0,00 | 36 s | 1526 |
| 7 | 25,6 | 2,74 | 0,00 | 31 s | 2067 |
| 8 | 22,9 | 2,80 | 0,00 | 32 s | 2524 |
| 9 | 20,1 | 2,11 | 0,00 | 28 s | 2972 |
| 10 | 17,9 | 3,31 | 0,00 | 28 s | 3911 |

- Temps de jeu : entraînement 9 %, combat 50 %, trajets 30 %, menus 11 %.
- Puissance gagnée pendant le premier parcours : entraînement 37 %, compagnons (passif) 37 %, combats 26 % ; sur toute la partie : 5 %, 68 %, 27 %.
- Tickets baddie : départ 5 %, entraînement 4 %, premiers passages 61 %, renaissances 30 %.
- Entraînement d'affilée sans décision : médiane 25 s, plus long par partie 1 min 30 (médiane), 2 min 45 (10 % des parties).
- Zones de danger : 1125 par partie, 11 % touchent ; drops reçus 24,2, acceptés 15,5 par partie.
- Relances quand le Book est complet : médiane 67, 90 % des parties sous 100 ; garanties utilisées 1,3 par partie.
- Puissance à la mort : médiane 1653 (1378 morts sur 100 parties).

### Joueur « Investi » (100 parties de 10 h 00 maximum)

Entraînement 6/s, attaque 7/s, voit 95 % des zones (réaction 0,20–0,40 s), part au combat vers 80 coups, garde une principale à partir de ×2,5.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 25 s | 7 s | 27 s | 100 % |
| Premier combat | 40 s | 22 s | 42 s | 100 % |
| Premier boss vaincu (niveau 1) | 42 s | 25 s | 45 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 2 min 37 | 2 min 11 | 4 min 23 | 100 % |
| Niveau 5 terminé | 5 min 23 | 4 min 28 | 8 min 08 | 100 % |
| Premier parcours terminé (niveau 10) | 12 min 19 | 10 min 03 | 13 min 51 | 100 % |
| Première renaissance | 12 min 27 | 10 min 09 | 14 min | 100 % |
| 3e renaissance | 29 min 24 | 25 min 20 | 32 min 55 | 100 % |
| 6e renaissance (4 slots) | 48 min 38 | 42 min 32 | 53 min 04 | 100 % |
| Premier drop de boss | 7 min 57 | 42 s | 23 min 30 | 100 % |
| 4 baddies au Baddies Book | 18 s | 5 s | 13 min 02 | 100 % |
| Baddies Book complet (9) | 25 min 21 | 18 min 36 | 39 min 37 | 100 % |
| Vega (Mythic) découverte | 20 min 41 | 11 min 19 | 39 min 20 | 100 % |
| Les 6 compagnons | 40 min 02 | 20 min 21 | 48 min 01 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 12 min 19 · parcours 2 : 8 min 21 · parcours 3 : 7 min 36 · parcours 4 : 6 min 46 · parcours 5 : 5 min 44 · parcours 6 : 5 min 36.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 6,5 | 0,00 | 0,00 | 3 s | 50 |
| 2 | 6,4 | 0,00 | 0,00 | 11 s | 307 |
| 3 | 6,4 | 0,00 | 0,00 | 12 s | 692 |
| 4 | 6,4 | 0,00 | 0,00 | 12 s | 1088 |
| 5 | 6,4 | 0,00 | 0,00 | 12 s | 1749 |
| 6 | 6,3 | 0,00 | 0,00 | 12 s | 1999 |
| 7 | 6,3 | 0,00 | 0,00 | 12 s | 2706 |
| 8 | 6,3 | 0,00 | 0,00 | 12 s | 3286 |
| 9 | 6,3 | 0,00 | 0,00 | 12 s | 3881 |
| 10 | 6,3 | 0,00 | 0,00 | 12 s | 5026 |

- Temps de jeu : entraînement 49 %, combat 22 %, trajets 15 %, menus 14 %.
- Puissance gagnée pendant le premier parcours : entraînement 65 %, compagnons (passif) 24 %, combats 11 % ; sur toute la partie : 43 %, 43 %, 14 %.
- Tickets baddie : départ 7 %, entraînement 25 %, premiers passages 45 %, renaissances 23 %.
- Entraînement d'affilée sans décision : médiane 16 s, plus long par partie 1 min 15 (médiane), 1 min 25 (10 % des parties).
- Zones de danger : 57 par partie, 5 % touchent ; drops reçus 6,2, acceptés 3,6 par partie.
- Relances quand le Book est complet : médiane 63, 90 % des parties sous 100 ; garanties utilisées 1,3 par partie.

### Joueur « Farmeur » (100 parties de 10 h 00 maximum)

Entraînement 3/s, attaque 4/s, voit 85 % des zones (réaction 0,25–0,60 s), part au combat vers 60 coups, garde une principale à partir de ×1,8.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 13 s | 7 s | 25 s | 100 % |
| Premier combat | 29 s | 23 s | 41 s | 100 % |
| Premier boss vaincu (niveau 1) | 32 s | 26 s | 44 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 7 min 38 | 6 min 48 | 9 min 01 | 100 % |
| Niveau 5 terminé | 15 min 32 | 13 min 24 | 17 min 50 | 100 % |
| Premier parcours terminé (niveau 10) | 30 min 12 | 26 min 20 | 35 min 55 | 100 % |
| Première renaissance | 30 min 20 | 26 min 28 | 36 min 03 | 100 % |
| 3e renaissance | 1 h 08 | 58 min 43 | 1 h 19 | 100 % |
| 6e renaissance (4 slots) | 1 h 47 | 1 h 32 | 2 h 01 | 100 % |
| Premier drop de boss | 1 min 14 | 38 s | 2 min 39 | 100 % |
| 4 baddies au Baddies Book | 27 min 05 | 9 s | 35 min 01 | 100 % |
| Baddies Book complet (9) | 1 h 13 | 54 min 26 | 1 h 51 | 100 % |
| Vega (Mythic) découverte | 1 h 07 | 30 min 29 | 1 h 28 | 100 % |
| Les 6 compagnons | 3 h 31 | 2 h 29 | 4 h 33 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 30 min 12 · parcours 2 : 19 min 19 · parcours 3 : 17 min · parcours 4 : 14 min 03 · parcours 5 : 12 min 03 · parcours 6 : 11 min 12.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 82,4 | 0,00 | 0,00 | 3 s | 36 |
| 2 | 85,7 | 0,00 | 0,00 | 14 s | 369 |
| 3 | 73,1 | 0,00 | 0,00 | 15 s | 832 |
| 4 | 92,3 | 0,00 | 0,00 | 15 s | 1348 |
| 5 | 50,4 | 0,56 | 0,00 | 15 s | 2051 |
| 6 | 82,5 | 0,18 | 0,00 | 15 s | 2446 |
| 7 | 62,6 | 0,68 | 0,00 | 15 s | 3335 |
| 8 | 59,6 | 0,57 | 0,00 | 15 s | 4394 |
| 9 | 103,8 | 0,63 | 0,00 | 15 s | 5228 |
| 10 | 18,6 | 0,00 | 0,00 | 14 s | 5817 |

- Temps de jeu : entraînement 0 %, combat 63 %, trajets 28 %, menus 9 %.
- Puissance gagnée pendant le premier parcours : entraînement 0 %, compagnons (passif) 18 %, combats 82 % ; sur toute la partie : 0 %, 56 %, 44 %.
- Tickets baddie : départ 4 %, entraînement 0 %, premiers passages 64 %, renaissances 32 %.
- Entraînement d'affilée sans décision : médiane 5 s, plus long par partie 5 s (médiane), 5 s (10 % des parties).
- Zones de danger : 1429 par partie, 6 % touchent ; drops reçus 69,7, acceptés 37,2 par partie.
- Relances quand le Book est complet : médiane 50, 90 % des parties sous 100 ; garanties utilisées 1,1 par partie.
- Vagues rejouées au lieu de s'entraîner : 505 par partie.
- Puissance à la mort : médiane 2548 (262 morts sur 100 parties).

