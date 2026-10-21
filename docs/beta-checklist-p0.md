# Checklist bêta — P0, P1 et V1 (dossier §02, §30)

À remplir par le bêta-testeur **sans explication préalable** des menus. Une fiche par session.

| Champ | Valeur |
|---|---|
| Version (commit / branche) | |
| Appareil (PC, téléphone, modèle) | |
| Orientation (paysage / portrait) | |
| Date | |

## 1. Critères d'acceptation P0

| # | Question (oui / non) | Étapes | Attendu | Obtenu | Capture |
|---|---|---|---|---|---|
| 1 | Reconnais-tu **les trois looks de Maya** ? | Va sur La Scène (à droite du spawn, podium doré), regarde 20 s ; puis ouvre STYLE | Trois tenues différentes de la même Maya, nom du look affiché ; STYLE montre les 3 looks (porté, débloqué ou « MAÎTRISE n ») | | |
| 2 | Sais-tu dire **qui est ta principale** et **qui est seulement exposée** ? | Ouvre BOOK, clique sur une carte | Carte et fiche de Maya : puce verte « PRINCIPALE · S1 » ; une baddie exposée porte la puce cyan « EXPOSÉE » ; EXPOSER / RETIRER ne change pas les dégâts de la principale | | |
| 3 | Vois-tu **Malik produire de la puissance tout seul** ? | Clique ENTRAÎNER 10 fois (carte en bas à gauche : « MALIK ARRIVE n/10 »), puis attends sans cliquer | Bannière « NOUVEAU CREW ! », carte MALIK à droite (+0,6/s), Malik te suit, la puissance monte seule ; la carte du bas passe à « PARCOURS 0/10 » | | |
| 4 | Trouves-tu **la sortie du lobby** ? | Depuis le spawn, sans aide | Arche violette « VERS LE NIVEAU 1 » droit devant, rue ouverte jusqu'au niveau 1, sans saut | | |

## 2. Contrôles complémentaires

| # | Contrôle | Attendu | Obtenu |
|---|---|---|---|
| 5 | Ouvre une fenêtre (BOOK) et clique sur ENTRAÎNER à travers | La puissance ne monte que par la production de Malik | |
| 6 | Réglages → Maintien du clic : OUI, puis garde ENTRAÎNER appuyé 2 s | Environ 6 à 7 entraînements, pas plus | |
| 7 | Réglages → Effets réduits : OUI | Auras de Maya, Malik et du podium nettement atténuées ; les néons du lobby ne « bavent » plus (bloom coupé) | |
| 8 | Fermer une fenêtre | La croix rouge carrée ferme ; un clic à côté de la fenêtre ne fait rien ; Échap ouvre le menu Roblox (normal) | |
| 8b | Annonces | Gagner un ticket (250 entraînements) ou une copie de compagnon : petit message en haut (« +1 ticket baddie », « +5 tickets baddie ») ; jamais plus de 4 messages à la fois, le bouton ENTRAÎNER reste visible | |
| 9 | **À deux joueurs** (Studio : Test → Clients and Servers, 2 joueurs) | Chacun voit l'équipe de l'autre ; quand un joueur part, ses suiveurs disparaissent | |
| 10 | Réglages → Suiveurs des autres : NON | Les équipes des autres joueurs disparaissent, la sienne reste | |
| 11 | Téléphone (ou émulation Studio, paysage) | Rien de coupé, boutons faciles à toucher, bouton ENTRAÎNER visible | |
| 12 | Fluidité sur le téléphone de référence | Pas de saccade visible en marchant avec Maya et Malik | |

## 3. Combat et progression (P1, V1)

| # | Contrôle | Attendu | Obtenu |
|---|---|---|---|
| 13 | Entrer dans l'arène 1 | Les sbires arrivent ; barre du haut « NIVEAU 1 · SBIRES », tes PV dessous ; le bouton devient ATTAQUER (touche F sur PC) | |
| 14 | Cercle rouge au sol | Il se remplit puis frappe ; en sortir à temps évite le coup ; touché : écran rouge et « −X PV » | |
| 15 | Battre le boss | Message « Niveau 1 terminé… », la porte du fond s'ouvre ; « puissance conseillée » pour le niveau 2 | |
| 16 | Mourir (rester dans les cercles) | « K.O. », retour au lobby ; la puissance reste ; les portes sont refermées ; **aucun combat ne recommence tout seul** | |
| 17 | Revenir dans une arène déjà gagnée | Bouton REJOUER LE NIVEAU N | |
| 18 | Menu SLOTS → onglet SLOTS | RELANCER demande une confirmation ; résultat « SLOT : X → Y » ; VERROUILLER empêche la relance | |
| 19 | Drop de boss (rare, 10 %) | Badge sur SLOTS ; onglet DROPS : ACCEPTER remplace le slot temporaire, REFUSER le supprime | |
| 20 | Fin du niveau 10 → onglet RENAISSANCE | Texte de ce qui est gardé / perdu ; après confirmation : retour au lobby, puissance 1 | |
| 21 | Menu CREW | OUVRIR un coffre, AMÉLIORER avec les copies, ÉQUIPER deux compagnons au maximum | |
| 22 | BOOK, exposition pleine | Une 4e baddie affiche « EXPOSITION PLEINE 3/3 » (il faut en retirer une) | |
| 23 | Écran CLASSEMENT du lobby (à 2 joueurs) | Les deux noms, ta ligne surlignée, alterne BADDIES / CREW | |
| 24 | Titre (après le boss 1 : STYLE → titre) | Le titre s'affiche au-dessus de ta tête, aussi chez l'autre joueur | |
| 25 | Annonces de succès | Accents corrects (« PREMIÈRE RENAISSANCE ») et texte entièrement visible à l'écran | |

## 4. Compréhension (questions ouvertes, à poser après la session)

- Qu'est-ce qui fait monter ta puissance ?
- À quoi sert la principale ? Et l'exposition ?
- Qu'as-tu cherché sans le trouver ?
- Que se passe-t-il quand tu meurs ? Qu'est-ce que tu gardes ?
- À quoi sert un slot « conservé » ?

## 5. Notes

Les personnages sont des **placeholders** (rigs simples, sans visage ; tous les boss utilisent Maya) : juger la
lisibilité et la silhouette, pas la finition. Matrice complète des tests et de ce qui est automatisé :
[`TEST-MATRIX.md`](TEST-MATRIX.md).
