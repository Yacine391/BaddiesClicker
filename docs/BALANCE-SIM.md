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
| Deuxième quartier (niveau 3 terminé) | 57 s | 48 s | 1 min 10 | 100 % |
| Niveau 5 terminé | 1 min 21 | 1 min 13 | 1 min 34 | 100 % |
| Premier parcours terminé (niveau 10) | 2 min 29 | 2 min 19 | 2 min 43 | 100 % |
| Première renaissance | 2 min 37 | 2 min 30 | 2 min 53 | 100 % |
| 3e renaissance | 9 min 29 | 8 min 57 | 9 min 40 | 100 % |
| 6e renaissance (4 slots) | 18 min 34 | 18 min 23 | 18 min 46 | 100 % |
| Premier drop de boss | 1 min 35 | 38 s | 7 min 21 | 100 % |
| 4 baddies au Baddies Book | 2 min 33 | 9 s | 2 min 48 | 100 % |
| Baddies Book complet (8) | 9 min 32 | 6 min 25 | 18 min 41 | 100 % |
| Vega (Mythic) découverte | 9 min 27 | 2 min 51 | 15 min 33 | 100 % |
| Les 6 compagnons | 1 h 00 | 27 min 36 | 1 h 13 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 2 min 29 · parcours 2 : 3 min 32 · parcours 3 : 2 min 48 · parcours 4 : 2 min 49 · parcours 5 : 2 min 49 · parcours 6 : 2 min 48.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 18,7 | 0,00 | 0,00 | 3 s | 44 |
| 2 | 17,7 | 0,00 | 0,00 | 3 s | 82 |
| 3 | 17,7 | 0,00 | 0,00 | 4 s | 144 |
| 4 | 17,7 | 0,00 | 0,00 | 4 s | 223 |
| 5 | 17,7 | 0,00 | 0,00 | 4 s | 320 |
| 6 | 17,7 | 0,00 | 0,00 | 4 s | 435 |
| 7 | 17,7 | 0,00 | 0,00 | 5 s | 583 |
| 8 | 17,7 | 0,00 | 0,00 | 5 s | 752 |
| 9 | 17,7 | 0,00 | 0,00 | 6 s | 940 |
| 10 | 17,7 | 0,00 | 0,00 | 6 s | 1149 |

- Temps de jeu : entraînement 0 %, combat 19 %, trajets 52 %, menus 29 %.
- Puissance gagnée pendant le premier parcours : entraînement 1 %, compagnons (passif) 8 %, combats 91 % ; sur toute la partie : 0 %, 45 %, 55 %.
- Tickets baddie : départ 4 %, entraînement 0 %, premiers passages 64 %, renaissances 32 %.
- Entraînement d'affilée sans décision : médiane 5 s, plus long par partie 5 s (médiane), 5 s (10 % des parties).
- Zones de danger : 0 par partie, 0 % touchent ; drops reçus 18,0, acceptés 13,3 par partie.
- Relances quand le Book est complet : médiane 50, 90 % des parties sous 100 ; garanties utilisées 0,8 par partie.

### Joueur « Pressé » (100 parties de 10 h 00 maximum)

Entraînement 3/s, attaque 4/s, voit 85 % des zones (réaction 0,25–0,60 s), part au combat vers 150 coups, garde une principale à partir de ×1,8.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 13 s | 7 s | 28 s | 96 % |
| Premier combat | 29 s | 23 s | 41 s | 100 % |
| Premier boss vaincu (niveau 1) | 32 s | 26 s | 44 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 57 s | 49 s | 1 min 10 | 100 % |
| Niveau 5 terminé | 1 min 21 | 1 min 13 | 1 min 34 | 100 % |
| Premier parcours terminé (niveau 10) | 2 min 30 | 2 min 21 | 2 min 43 | 100 % |
| Première renaissance | 2 min 38 | 2 min 30 | 2 min 53 | 100 % |
| 3e renaissance | 9 min 29 | 8 min 57 | 9 min 40 | 100 % |
| 6e renaissance (4 slots) | 18 min 34 | 18 min 24 | 18 min 46 | 100 % |
| Premier drop de boss | 1 min 36 | 38 s | 7 min 23 | 100 % |
| 4 baddies au Baddies Book | 2 min 33 | 9 s | 2 min 48 | 100 % |
| Baddies Book complet (8) | 9 min 32 | 6 min 25 | 18 min 41 | 100 % |
| Vega (Mythic) découverte | 9 min 27 | 2 min 51 | 15 min 33 | 100 % |
| Les 6 compagnons | 1 h 00 | 27 min 39 | 1 h 13 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 2 min 30 · parcours 2 : 3 min 32 · parcours 3 : 2 min 48 · parcours 4 : 2 min 49 · parcours 5 : 2 min 49 · parcours 6 : 2 min 48.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 19,2 | 0,00 | 0,00 | 3 s | 44 |
| 2 | 18,2 | 0,00 | 0,00 | 3 s | 82 |
| 3 | 18,2 | 0,00 | 0,00 | 4 s | 144 |
| 4 | 18,2 | 0,00 | 0,00 | 4 s | 223 |
| 5 | 18,2 | 0,00 | 0,00 | 4 s | 320 |
| 6 | 18,2 | 0,00 | 0,00 | 4 s | 435 |
| 7 | 18,2 | 0,00 | 0,00 | 5 s | 583 |
| 8 | 18,2 | 0,00 | 0,00 | 5 s | 752 |
| 9 | 18,2 | 0,00 | 0,00 | 6 s | 940 |
| 10 | 18,2 | 0,00 | 0,00 | 6 s | 1149 |

- Temps de jeu : entraînement 0 %, combat 19 %, trajets 52 %, menus 29 %.
- Puissance gagnée pendant le premier parcours : entraînement 1 %, compagnons (passif) 7 %, combats 92 % ; sur toute la partie : 0 %, 45 %, 55 %.
- Tickets baddie : départ 4 %, entraînement 0 %, premiers passages 64 %, renaissances 32 %.
- Entraînement d'affilée sans décision : médiane 5 s, plus long par partie 5 s (médiane), 5 s (10 % des parties).
- Zones de danger : 0 par partie, 0 % touchent ; drops reçus 18,4, acceptés 13,6 par partie.
- Relances quand le Book est complet : médiane 50, 90 % des parties sous 100 ; garanties utilisées 0,8 par partie.

### Joueur « Investi » (100 parties de 10 h 00 maximum)

Entraînement 6/s, attaque 7/s, voit 95 % des zones (réaction 0,20–0,40 s), part au combat vers 80 coups, garde une principale à partir de ×2,5.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 25 s | 7 s | 27 s | 100 % |
| Premier combat | 40 s | 22 s | 42 s | 100 % |
| Premier boss vaincu (niveau 1) | 42 s | 25 s | 45 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 1 min | 42 s | 1 min 08 | 100 % |
| Niveau 5 terminé | 1 min 19 | 1 min 01 | 1 min 35 | 100 % |
| Premier parcours terminé (niveau 10) | 2 min 13 | 1 min 55 | 2 min 43 | 100 % |
| Première renaissance | 2 min 19 | 2 min 01 | 2 min 51 | 100 % |
| 3e renaissance | 7 min 43 | 7 min 28 | 7 min 51 | 100 % |
| 6e renaissance (4 slots) | 15 min 09 | 15 min | 15 min 20 | 100 % |
| Premier drop de boss | 1 min 17 | 41 s | 4 min 50 | 100 % |
| 4 baddies au Baddies Book | 18 s | 8 s | 2 min 07 | 100 % |
| Baddies Book complet (8) | 7 min 43 | 4 min 59 | 15 min 15 | 100 % |
| Vega (Mythic) découverte | 7 min 41 | 2 min 14 | 12 min 39 | 100 % |
| Les 6 compagnons | 49 min 06 | 22 min 42 | 49 min 57 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 2 min 13 · parcours 2 : 2 min 40 · parcours 3 : 2 min 18 · parcours 4 : 2 min 19 · parcours 5 : 2 min 19 · parcours 6 : 2 min 18.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 18,0 | 0,00 | 0,00 | 3 s | 58 |
| 2 | 17,0 | 0,00 | 0,00 | 3 s | 96 |
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
- Zones de danger : 0 par partie, 0 % touchent ; drops reçus 17,6, acceptés 13,1 par partie.
- Relances quand le Book est complet : médiane 50, 90 % des parties sous 100 ; garanties utilisées 0,9 par partie.

### Joueur « Farmeur » (100 parties de 10 h 00 maximum)

Entraînement 3/s, attaque 4/s, voit 85 % des zones (réaction 0,25–0,60 s), part au combat vers 60 coups, garde une principale à partir de ×1,8.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 13 s | 7 s | 25 s | 100 % |
| Premier combat | 29 s | 23 s | 41 s | 100 % |
| Premier boss vaincu (niveau 1) | 32 s | 26 s | 44 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 57 s | 48 s | 1 min 10 | 100 % |
| Niveau 5 terminé | 1 min 21 | 1 min 13 | 1 min 34 | 100 % |
| Premier parcours terminé (niveau 10) | 2 min 29 | 2 min 19 | 2 min 43 | 100 % |
| Première renaissance | 2 min 37 | 2 min 30 | 2 min 53 | 100 % |
| 3e renaissance | 9 min 29 | 8 min 57 | 9 min 40 | 100 % |
| 6e renaissance (4 slots) | 18 min 34 | 18 min 23 | 18 min 46 | 100 % |
| Premier drop de boss | 1 min 35 | 38 s | 7 min 21 | 100 % |
| 4 baddies au Baddies Book | 2 min 33 | 9 s | 2 min 48 | 100 % |
| Baddies Book complet (8) | 9 min 32 | 6 min 25 | 18 min 41 | 100 % |
| Vega (Mythic) découverte | 9 min 27 | 2 min 51 | 15 min 33 | 100 % |
| Les 6 compagnons | 1 h 00 | 27 min 36 | 1 h 13 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 2 min 29 · parcours 2 : 3 min 32 · parcours 3 : 2 min 48 · parcours 4 : 2 min 49 · parcours 5 : 2 min 49 · parcours 6 : 2 min 48.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 18,7 | 0,00 | 0,00 | 3 s | 44 |
| 2 | 17,7 | 0,00 | 0,00 | 3 s | 82 |
| 3 | 17,7 | 0,00 | 0,00 | 4 s | 144 |
| 4 | 17,7 | 0,00 | 0,00 | 4 s | 223 |
| 5 | 17,7 | 0,00 | 0,00 | 4 s | 320 |
| 6 | 17,7 | 0,00 | 0,00 | 4 s | 435 |
| 7 | 17,7 | 0,00 | 0,00 | 5 s | 583 |
| 8 | 17,7 | 0,00 | 0,00 | 5 s | 752 |
| 9 | 17,7 | 0,00 | 0,00 | 6 s | 940 |
| 10 | 17,7 | 0,00 | 0,00 | 6 s | 1149 |

- Temps de jeu : entraînement 0 %, combat 19 %, trajets 52 %, menus 29 %.
- Puissance gagnée pendant le premier parcours : entraînement 1 %, compagnons (passif) 8 %, combats 91 % ; sur toute la partie : 0 %, 45 %, 55 %.
- Tickets baddie : départ 4 %, entraînement 0 %, premiers passages 64 %, renaissances 32 %.
- Entraînement d'affilée sans décision : médiane 5 s, plus long par partie 5 s (médiane), 5 s (10 % des parties).
- Zones de danger : 0 par partie, 0 % touchent ; drops reçus 18,0, acceptés 13,3 par partie.
- Relances quand le Book est complet : médiane 50, 90 % des parties sous 100 ; garanties utilisées 0,8 par partie.
- Vagues rejouées au lieu de s'entraîner : 0 par partie.

## Après : Balance actuelle (v4-p1)

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
| Deuxième quartier (niveau 3 terminé) | 5 min 30 | 4 min 42 | 6 min 27 | 100 % |
| Niveau 5 terminé | 11 min 53 | 9 min 31 | 14 min 21 | 100 % |
| Premier parcours terminé (niveau 10) | 28 min 45 | 22 min 13 | 34 min 16 | 100 % |
| Première renaissance | 28 min 53 | 22 min 22 | 34 min 24 | 100 % |
| 3e renaissance | 1 h 02 | 50 min 21 | 1 h 13 | 100 % |
| 6e renaissance (4 slots) | 1 h 35 | 1 h 20 | 1 h 51 | 100 % |
| Premier drop de boss | 16 min 47 | 38 s | 47 min 14 | 100 % |
| 4 baddies au Baddies Book | 23 min 03 | 9 s | 33 min 16 | 100 % |
| Baddies Book complet (8) | 47 min 44 | 33 min 17 | 1 h 11 | 100 % |
| Vega (Mythic) découverte | 44 min 48 | 27 min 49 | 1 h 01 | 100 % |
| Les 6 compagnons | 1 h 06 | 34 min 04 | 1 h 17 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 28 min 45 · parcours 2 : 15 min 36 · parcours 3 : 15 min 27 · parcours 4 : 11 min 33 · parcours 5 : 10 min 22 · parcours 6 : 9 min 33.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 6,7 | 0,00 | 0,00 | 3 s | 36 |
| 2 | 6,7 | 0,00 | 0,00 | 14 s | 445 |
| 3 | 6,7 | 0,00 | 0,00 | 15 s | 1043 |
| 4 | 6,7 | 0,02 | 0,00 | 15 s | 1695 |
| 5 | 6,7 | 0,10 | 0,00 | 15 s | 2612 |
| 6 | 6,6 | 0,06 | 0,00 | 15 s | 3090 |
| 7 | 6,5 | 0,13 | 0,00 | 15 s | 4039 |
| 8 | 6,4 | 0,11 | 0,00 | 15 s | 4917 |
| 9 | 6,3 | 0,12 | 0,00 | 15 s | 5810 |
| 10 | 6,1 | 0,00 | 0,00 | 14 s | 7909 |

- Temps de jeu : entraînement 65 %, combat 15 %, trajets 11 %, menus 9 %.
- Puissance gagnée pendant le premier parcours : entraînement 54 %, compagnons (passif) 39 %, combats 7 % ; sur toute la partie : 36 %, 55 %, 9 %.
- Tickets baddie : départ 7 %, entraînement 30 %, premiers passages 42 %, renaissances 21 %.
- Entraînement d'affilée sans décision : médiane 36 s, plus long par partie 2 min 50 (médiane), 2 min 50 (10 % des parties).
- Zones de danger : 209 par partie, 5 % touchent ; drops reçus 6,4, acceptés 3,5 par partie.
- Relances quand le Book est complet : médiane 50, 90 % des parties sous 100 ; garanties utilisées 1,0 par partie.
- Puissance à la mort : médiane 3031 (54 morts sur 100 parties).

### Joueur « Pressé » (100 parties de 10 h 00 maximum)

Entraînement 3/s, attaque 4/s, voit 85 % des zones (réaction 0,25–0,60 s), part au combat vers 150 coups, garde une principale à partir de ×1,8.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 16 s | 7 s | 34 s | 100 % |
| Premier combat | 29 s | 23 s | 41 s | 100 % |
| Premier boss vaincu (niveau 1) | 33 s | 26 s | 44 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 3 min 36 | 3 min 01 | 4 min 15 | 100 % |
| Niveau 5 terminé | 7 min 44 | 6 min 37 | 10 min 20 | 100 % |
| Premier parcours terminé (niveau 10) | 19 min 14 | 14 min 17 | 24 min 31 | 100 % |
| Première renaissance | 19 min 22 | 14 min 25 | 24 min 39 | 100 % |
| 3e renaissance | 45 min 17 | 37 min 54 | 54 min 27 | 100 % |
| 6e renaissance (4 slots) | 1 h 13 | 1 h 01 | 1 h 27 | 100 % |
| Premier drop de boss | 8 min 08 | 38 s | 20 min 28 | 100 % |
| 4 baddies au Baddies Book | 16 min 14 | 9 s | 23 min 54 | 100 % |
| Baddies Book complet (8) | 39 min 05 | 30 min 31 | 1 h 03 | 100 % |
| Vega (Mythic) découverte | 36 min 12 | 21 min 11 | 56 min 17 | 100 % |
| Les 6 compagnons | 2 h 11 | 1 h 09 | 2 h 40 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 19 min 14 · parcours 2 : 13 min 34 · parcours 3 : 10 min 50 · parcours 4 : 9 min 33 · parcours 5 : 8 min 25 · parcours 6 : 8 min 04.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 29,1 | 0,00 | 0,00 | 3 s | 36 |
| 2 | 28,2 | 0,02 | 0,00 | 32 s | 203 |
| 3 | 28,2 | 0,21 | 0,00 | 36 s | 454 |
| 4 | 28,0 | 0,35 | 0,00 | 36 s | 811 |
| 5 | 27,6 | 1,27 | 0,00 | 37 s | 1314 |
| 6 | 26,4 | 1,08 | 0,00 | 36 s | 1526 |
| 7 | 25,3 | 2,90 | 0,00 | 31 s | 2080 |
| 8 | 22,4 | 2,63 | 0,00 | 30 s | 2536 |
| 9 | 19,7 | 2,10 | 0,00 | 28 s | 3062 |
| 10 | 17,6 | 3,04 | 0,00 | 28 s | 4057 |

- Temps de jeu : entraînement 10 %, combat 50 %, trajets 30 %, menus 11 %.
- Puissance gagnée pendant le premier parcours : entraînement 36 %, compagnons (passif) 38 %, combats 26 % ; sur toute la partie : 6 %, 68 %, 26 %.
- Tickets baddie : départ 5 %, entraînement 4 %, premiers passages 61 %, renaissances 30 %.
- Entraînement d'affilée sans décision : médiane 24 s, plus long par partie 1 min 35 (médiane), 2 min 45 (10 % des parties).
- Zones de danger : 1105 par partie, 11 % touchent ; drops reçus 23,6, acceptés 14,9 par partie.
- Relances quand le Book est complet : médiane 50, 90 % des parties sous 100 ; garanties utilisées 0,9 par partie.
- Puissance à la mort : médiane 1641 (1360 morts sur 100 parties).

### Joueur « Investi » (100 parties de 10 h 00 maximum)

Entraînement 6/s, attaque 7/s, voit 95 % des zones (réaction 0,20–0,40 s), part au combat vers 80 coups, garde une principale à partir de ×2,5.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 25 s | 7 s | 27 s | 100 % |
| Premier combat | 40 s | 22 s | 42 s | 100 % |
| Premier boss vaincu (niveau 1) | 42 s | 25 s | 45 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 2 min 39 | 2 min 24 | 4 min 23 | 100 % |
| Niveau 5 terminé | 5 min 28 | 4 min 40 | 8 min 07 | 100 % |
| Premier parcours terminé (niveau 10) | 12 min 29 | 10 min 36 | 13 min 51 | 100 % |
| Première renaissance | 12 min 37 | 10 min 42 | 14 min | 100 % |
| 3e renaissance | 29 min 45 | 26 min 24 | 33 min 39 | 100 % |
| 6e renaissance (4 slots) | 48 min 49 | 43 min 51 | 56 min 15 | 100 % |
| Premier drop de boss | 7 min 35 | 42 s | 21 min | 100 % |
| 4 baddies au Baddies Book | 18 s | 8 s | 12 min 57 | 100 % |
| Baddies Book complet (8) | 22 min 23 | 17 min 35 | 38 min 31 | 100 % |
| Vega (Mythic) découverte | 20 min 44 | 12 min 10 | 36 min 42 | 100 % |
| Les 6 compagnons | 40 min 18 | 17 min 59 | 55 min 36 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 12 min 29 · parcours 2 : 8 min 41 · parcours 3 : 8 min · parcours 4 : 6 min 50 · parcours 5 : 6 min · parcours 6 : 5 min 37.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 6,8 | 0,00 | 0,00 | 3 s | 50 |
| 2 | 6,7 | 0,00 | 0,00 | 11 s | 307 |
| 3 | 6,7 | 0,00 | 0,00 | 12 s | 692 |
| 4 | 6,7 | 0,00 | 0,00 | 12 s | 1090 |
| 5 | 6,6 | 0,00 | 0,00 | 12 s | 1751 |
| 6 | 6,6 | 0,00 | 0,00 | 12 s | 2004 |
| 7 | 6,6 | 0,00 | 0,00 | 12 s | 2709 |
| 8 | 6,6 | 0,00 | 0,00 | 12 s | 3293 |
| 9 | 6,6 | 0,00 | 0,00 | 12 s | 3886 |
| 10 | 6,6 | 0,00 | 0,00 | 12 s | 5029 |

- Temps de jeu : entraînement 49 %, combat 22 %, trajets 15 %, menus 14 %.
- Puissance gagnée pendant le premier parcours : entraînement 65 %, compagnons (passif) 24 %, combats 11 % ; sur toute la partie : 43 %, 43 %, 14 %.
- Tickets baddie : départ 7 %, entraînement 25 %, premiers passages 45 %, renaissances 22 %.
- Entraînement d'affilée sans décision : médiane 16 s, plus long par partie 1 min 15 (médiane), 1 min 25 (10 % des parties).
- Zones de danger : 60 par partie, 5 % touchent ; drops reçus 6,9, acceptés 4,3 par partie.
- Relances quand le Book est complet : médiane 50, 90 % des parties sous 100 ; garanties utilisées 1,0 par partie.

### Joueur « Farmeur » (100 parties de 10 h 00 maximum)

Entraînement 3/s, attaque 4/s, voit 85 % des zones (réaction 0,25–0,60 s), part au combat vers 60 coups, garde une principale à partir de ×1,8.

| Moment | Médiane | 10 % les plus rapides | 10 % les plus lents | Atteint |
|---|---|---|---|---|
| Malik obtenu (tutoriel) | 13 s | 7 s | 25 s | 100 % |
| Premier combat | 29 s | 23 s | 41 s | 100 % |
| Premier boss vaincu (niveau 1) | 32 s | 26 s | 44 s | 100 % |
| Deuxième quartier (niveau 3 terminé) | 7 min 38 | 6 min 49 | 9 min 03 | 100 % |
| Niveau 5 terminé | 15 min 32 | 13 min 25 | 17 min 51 | 100 % |
| Premier parcours terminé (niveau 10) | 30 min 21 | 26 min 21 | 35 min 59 | 100 % |
| Première renaissance | 30 min 32 | 26 min 29 | 36 min 10 | 100 % |
| 3e renaissance | 1 h 09 | 58 min 11 | 1 h 19 | 100 % |
| 6e renaissance (4 slots) | 1 h 49 | 1 h 30 | 2 h 06 | 100 % |
| Premier drop de boss | 1 min 14 | 38 s | 2 min 39 | 100 % |
| 4 baddies au Baddies Book | 26 min 59 | 9 s | 34 min 58 | 100 % |
| Baddies Book complet (8) | 1 h 05 | 36 min 55 | 1 h 19 | 100 % |
| Vega (Mythic) découverte | 1 h 02 | 30 min 29 | 1 h 18 | 100 % |
| Les 6 compagnons | 3 h 35 | 2 h 18 | 4 h 43 | 100 % |

Durée médiane d'un parcours complet (niveaux 1 à 10, morts comprises) — parcours 1 : 30 min 21 · parcours 2 : 19 min 43 · parcours 3 : 17 min 03 · parcours 4 : 13 min 54 · parcours 5 : 12 min 03 · parcours 6 : 11 min 25.

| Niveau | Tentatives / partie | Morts / partie | Abandons | Première victoire : durée | Puissance |
|---|---|---|---|---|---|
| 1 | 85,5 | 0,00 | 0,00 | 3 s | 36 |
| 2 | 89,1 | 0,00 | 0,00 | 14 s | 371 |
| 3 | 76,8 | 0,00 | 0,00 | 15 s | 833 |
| 4 | 96,1 | 0,02 | 0,00 | 15 s | 1348 |
| 5 | 52,9 | 0,55 | 0,00 | 15 s | 2052 |
| 6 | 86,7 | 0,21 | 0,00 | 15 s | 2450 |
| 7 | 65,5 | 0,69 | 0,00 | 15 s | 3374 |
| 8 | 62,5 | 0,61 | 0,00 | 15 s | 4390 |
| 9 | 108,3 | 0,67 | 0,00 | 15 s | 5227 |
| 10 | 18,9 | 0,00 | 0,00 | 14 s | 5852 |

- Temps de jeu : entraînement 0 %, combat 63 %, trajets 28 %, menus 9 %.
- Puissance gagnée pendant le premier parcours : entraînement 0 %, compagnons (passif) 18 %, combats 82 % ; sur toute la partie : 0 %, 57 %, 43 %.
- Tickets baddie : départ 4 %, entraînement 0 %, premiers passages 64 %, renaissances 32 %.
- Entraînement d'affilée sans décision : médiane 5 s, plus long par partie 5 s (médiane), 5 s (10 % des parties).
- Zones de danger : 1493 par partie, 6 % touchent ; drops reçus 73,3, acceptés 40,1 par partie.
- Relances quand le Book est complet : médiane 50, 90 % des parties sous 50 ; garanties utilisées 0,6 par partie.
- Vagues rejouées au lieu de s'entraîner : 532 par partie.
- Puissance à la mort : médiane 2536 (275 morts sur 100 parties).

