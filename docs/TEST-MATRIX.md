# Matrice de tests (dossier §30)

Chaque test du dossier, avec ce qui le couvre aujourd'hui :

- **Auto** : test Lune, à lancer à chaque PR avec `lune run tests/run` (serveur) et `lune run tests/client/run` (client).
- **Studio** : à vérifier à la main dans Studio, avec les outils F4 (Studio uniquement).
- **Bêta** : à faire par le bêta-testeur, avec la fiche [`beta-checklist-p0.md`](beta-checklist-p0.md).

| # | Test (§30) | Attendu | Couverture | Comment vérifier |
|---|---|---|---|---|
| 1 | Clic hors combat puis en combat | Entraîne puis attaque, jamais les deux | Auto + Studio | `Logic/PrimaryAction` (client), `Training.canTrain` (serveur) ; en Play : ENTRAÎNER au lobby, ATTAQUER dans l'arène |
| 2 | Boss vaincu sans drop | Mur ouvert, progression possible | Auto + Studio | test « boss vaincu sans drop » ; en Play : la porte s'ouvre |
| 3 | Deux requêtes de victoire | Une récompense, un tirage au maximum | Auto | test « deux requêtes de victoire » |
| 4 | 20 échecs boss | Toujours 10 % au suivant, aucune garantie | Auto | test « 20 victoires sans drop » |
| 5 | Relance 50 / coffre compagnon 20 | Identité manquante si la collection est incomplète | Auto + Studio | tests garantie 50 / coffre 20 ; F4 +10 TICKETS, onglet SLOTS : « garantie dans N » |
| 6 | Drop non accepté | Aucun multiplicateur, ni exposition, ni Book | Auto | tests drops en attente (Book, classement, dégâts) |
| 7 | Mort, reconnexion, rebirth avec drop | Drop toujours en attente | Auto + Studio | tests de survie des drops ; F4 DROP VEGA, mourir, quitter / revenir : badge SLOTS = 1 |
| 8 | Accepter une unité d'une pile | Temporaire remplacé, quantité −1 | Auto + Studio | test « accepter une unité » ; DROP VEGA ×2 puis ACCEPTER 1 |
| 9 | Accepter dans un conservé | Impossible | Auto | `Slots.checkAcceptDrop` (le client ne propose que le temporaire) |
| 10 | Mort au niveau 8 | Puissance gardée, toutes les portes fermées | Auto + Studio | test « mort au niveau 8 » ; en Play : retour lobby, PARCOURS 0/10 |
| 11 | Rebirth 3 avec Vega dans s2 | s2 promu avec Vega, aucune migration entre slots | Auto | tests de renaissance (paliers 1/3/6) |
| 12 | Rebirth avec la principale temporaire effacée | Repli sur un slot conservé rempli, sinon Maya | Auto | tests de repli de la renaissance |
| 13 | Relance d'un conservé | Ancienne baddie remplacée, Book intact | Auto + Studio | test relance d'un conservé ; SLOTS → RELANCER sur S1 conservé |
| 14 | Baddie exposée mais non possédée | Aucun effet sur les dégâts | Auto | `Combat.attackDamage` ne lit que la principale |
| 15 | Tableau avec égalités et doublons | Rang partagé, doublons non comptés | Auto + Studio | `Rules/Ranking` (1, 1, 3) ; à 2 joueurs, écran CLASSEMENT du lobby |
| 16 | Arrêt serveur pendant une récupération | Pas de double consommation ni de double personnage | Auto | tests reçus durables, renvoi du même `requestId` |
| R1 | Même `requestId` de relance répété | Même résultat, un seul ticket consommé | Auto | tests Receipts ; côté client, `Controllers/Decisions` réutilise le `requestId` |
| R2 | Résultat Mythic fourni par le client | Ignoré, tirage serveur | Auto | les intentions n'acceptent aucun résultat (CONTRACT) |
| R3 | Rebirth 1 avec Nova en s1 | Nova reste en s1 conservé, s2 temporaire ouvert | Auto + Studio | test palier 1 ; F4 FINIR LE PARCOURS puis RENAISSANCE |
| R4 | Rebirth 2 avec Vega en s2 | Vega effacée du slot, gardée au Book | Auto | test renaissance sans promotion |
| R5 | Deux slots avec Nova | Une seule principale, pas de cumul | Auto | dégâts = principale seule |
| R6 | Doublon de compagnon | Copies correctes, pas deux fois le même équipé | Auto + Studio | tests Crew ; CREW → OUVRIR, AMÉLIORER, ÉQUIPER (3e compagnon : « équipe pleine ») |
| R7 | Deux serveurs, même profil | Une seule session écrit | Studio publié | verrou ProfileStore : rejoindre sur deux appareils, le premier est expulsé |
| R8 | Mission puis reconnexion | Récompense une seule fois | — | pas de missions en V1 |
| R9 | Migration / restauration | Slots, découvertes, cosmétiques préservés | Auto + Studio | tests ProfileGuard (profil P0) ; exercice de restauration (OPERATIONS §3) |

## Compléments du §30

| Contrôle | Couverture | Comment vérifier |
|---|---|---|
| Déplacements impossibles (§25) | Auto + Studio | 10 tests `Rules/Movement` ; F4 → TÉLÉPORT ×3 en combat : « Combat annulé » ; ×1 : seulement une ligne `[Movement]` |
| Maintenance (§36) | Studio | attribut `ServerScriptService.BC_Maintenance` = `Roll` : RELANCER grisé, refus « maintenance » |
| Tactile, petit écran | Bêta | émulateur Studio puis vrai téléphone : boutons ≥ 48 px réels, en-tête des fenêtres non débordé sous l'échelle 0,77 |
| Latence | Studio | Paramètres Studio → réseau, latence simulée 250 ms : pas de combat annulé en marchant |
| Deux puis huit clients | Studio | Test → Clients and Servers : classement, titres, ennemis de l'un invisibles chez l'autre |
| Effets réduits | Bêta | Réglages : auras atténuées, bloom coupé |
| Modèles sans texture chargée | Bêta | réseau lent : silhouettes et plaques de PV restent lisibles |
| Erreur DataStore | Auto + Studio | tests Receipts (`saving`, `error`) ; place sans accès API : décisions refusées proprement |
| 30 minutes de mémoire | Bêta | Developer Console → Memory : pas de croissance continue après 30 min de combats |

## Critères de sortie de bêta (§30)

- [ ] Aucun bug ouvert de perte ou de duplication.
- [ ] Parcours complet et renaissance sans outil admin.
- [ ] Tous les contenus annoncés obtenables.
- [ ] Compris par de nouveaux joueurs sans coaching.
- [ ] Budgets appareils atteints (30 images/s sur le téléphone de référence).
- [ ] Restauration répétée avec succès.
