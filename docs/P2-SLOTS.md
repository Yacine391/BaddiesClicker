# Lot P2 : slots, relances, drops, renaissance et compagnons (codeur A)

Branche `a/p2-slots`, construite sur `a/p1-combat` (PR #2). Fiche séparée de `ROADMAP.md` pour ne pas
créer de conflit avec la PR #1 du codeur B ; à reporter dans la feuille de route après fusion.
Contrat réseau : `docs/CONTRACT.md` (v3, snapshot `v = 2`).

## Fait (testé hors Studio : 90 tests Lune, dont 50 pour le P2)

- [x] `Rules/Slots` : slots à identité fixe (aucun transfert), un seul temporaire, slot vide = `""`
- [x] Relance : 1 ticket, remplace le contenu du slot choisi (conservé ou non), `slotRevision` +1, découverte au Baddies Book
- [x] Garantie : toutes les 50 relances, une identité **manquante** tirée uniformément si le Book public est incomplet (lot V1 complet en 350 relances au plus) ; compteur global conservé après mort et rebirth
- [x] Verrou manuel de relance par slot ; confirmation par révision du slot (`stale` si le contenu a changé)
- [x] Drops en attente : accepter 1 (remplace **le temporaire uniquement**, découvre), refuser 1 (rien d'autre)
- [x] Principale : seulement un slot rempli, hors combat ; seule `activeSlotId` change
- [x] Renaissance : niveau 10 terminé ; paliers 1/3/6 → le temporaire devient conservé avec son contenu et un nouveau temporaire s'ouvre ; sinon le temporaire est vidé (verrou compris) ; +5 tickets baddie, +1 ticket compagnon, puissance 1, nouveau parcours ; drops, Book, maîtrise et compagnons conservés ; principale perdue → conservé rempli au plus fort multiplicateur, sinon Maya dans le temporaire (secours) ; retour au lobby
- [x] `Rules/Collection` (proposition contrat v2 du codeur B) : Baddies Book, exposition 3 places sans effet sur les dégâts, looks débloqués par la maîtrise (0/1/5), look choisi avec repli
- [x] `Rules/Receipts` + `MutationService` : une décision durable à la fois, tirage unique, reçu durable, réponse **après** l'écriture DataStore (`Profiles.saveAndWait`), renvoi idempotent du même `requestId`, écriture incertaine résolue avant la suivante
- [x] Snapshot `v = 2` : `slots`, `rolls`, `collection`, `saving`, `rebirth`, `pendingRevision`, `active.look` ; attributs `BC_ActiveLook`, `BC_Display`, `BC_BookCount`
- [x] Studio : `TestCatalog` (`test_b99` hors Book public), `DevSetMastery`, `DevGrant`, panneau `Dev/DevSlotsPanel` (F4)
- [x] Coffres de compagnons (`OpenChest`, décision durable) : 1 ticket compagnon, table du catalogue, toutes les 20 ouvertures un compagnon **manquant** (uniforme) ; compteur global séparé des relances
- [x] Niveaux des compagnons (`UpgradeCrew`) : L → L+1 coûte L+1 copies, niveau 10 max, copies gardées au maximum ; écriture prioritaire
- [x] Équipe (`EquipCrew`) : 2 compagnons possédés maximum, sans doublon ; snapshot `crewOwned` et `crewChest`

### Robustesse (§24, §27, §30, §36)

- [x] `Rules/ProfileGuard` au chargement : migrations explicites (refus d'un schéma plus récent ou d'une migration manquante), nombres finis et bornés, un seul temporaire, principale valide, possédée = découverte, exposition et équipe nettoyées ; identités inconnues archivées, jamais supprimées ; fixture de profil P0/P1
- [x] Protocole des décisions durables testable (`Receipts.run`) : tests de panne avec un faux DataStore (arrêt serveur avant et après l'écriture, même `requestId` répété, écriture incertaine qui bloque la suivante)
- [x] Interrupteurs de maintenance (`MaintenanceService`, DataStore `BC_Ops_v1` + attribut Studio) ; `snapshot.maintenance` et `snapshot.seq`
- [x] Journal des décisions (durée d'écriture, échecs), outil de restauration `Admin/ProfileAdmin`, procédure `docs/OPERATIONS.md`
- [x] Cas restants §30/§37 : drop non accepté, mort + reconnexion + rebirth avec drop, relance d'un conservé, rebirth 1 avec Nova, deux slots Nova, Vega maîtrise 10 = 6 dégâts

## Choix proposés (à valider)

- Principale perdue au rebirth : le slot conservé rempli **au plus fort multiplicateur** (le dossier dit « un slot rempli conservé »).
- 2 s minimum entre deux relances (§25, « proposition ») : refus `cooldown`.
- Un seul reçu durable (la dernière décision) ; les renvois plus anciens sont bloqués par les révisions.
- Les snapshots sont retenus pendant l'écriture d'une décision (≤ 12 s) : les gains continuent, l'affichage suit après.
- Look par défaut : 1 ; si le look choisi n'est plus débloqué, le plus haut débloqué.

## Reste

- [x] Valider en Studio : slots, relances, drops, renaissance (15/10)
- [x] Valider en Studio : coffres, niveaux et équipe des compagnons (15/10)
- [ ] Valider en Studio : maintenance (étape 9 ci-dessous)
- [ ] Répéter une restauration sur un compte de test (`docs/OPERATIONS.md` §3)
- [ ] Après fusion des PR #1 et #2 : déclarer le remote `Combat` dans `default.project.json`, reporter P1 et P2 dans `ROADMAP.md`

## Côté codeur B (P2)

- [ ] Écran Slots : numéro, temporaire/conservé, personnage, verrou ; « Relancer ce slot » avec confirmation (surtout Gold ou mieux), « Sélectionner comme principale »
- [ ] Écran Drops : « Vega remplacera Lina dans le slot temporaire s2 », boutons **Accepter 1** / **Refuser 1**
- [ ] Écran Rebirth : aperçu (slot promu ou effacé, tickets, bonus) et confirmation avec `run.id`
- [ ] Générer un `requestId` par décision et le réutiliser en cas de renvoi ; afficher la révélation à la réponse `mutation`
- [ ] Book et Style : brancher `collection` (déjà prévu dans la PR #1)
- [ ] Crew : afficher `crewOwned` (niveau, copies, coût), boutons Ouvrir un coffre / Améliorer / Équiper ; `crewChest` pour la garantie
- [ ] Supprimer `DevToolsBootstrap.client.luau` et `Dev/DevSlotsPanel.luau` quand ces écrans sont prêts

## Tester dans Studio

1. `rojo serve`, Rojo → Connect, F5. Panneau « SLOTS · P2 » en haut à droite (F4 pour le replier).
2. **Relance** : RELANCER sur s1, puis CONFIRMER → la réponse arrive après la sauvegarde (« sauvegardé ✓ »).
   Maya reste dans le Baddies Book même si elle est remplacée.
3. **Verrou** : VERROU sur s1 → le bouton RELANCER disparaît ; DÉVERROUILLER pour revenir.
4. **Garantie** : +10 TICKETS plusieurs fois, puis relance jusqu'à « garantie dans 1 » → la suivante donne une identité manquante.
5. **Drops** : DROP VEGA, puis ACCEPTER 1 (remplace le temporaire) ou REFUSER 1.
6. **Renaissance** : FINIR LE PARCOURS (ou battre Vega au niveau 10), puis RENAÎTRE : s1 devient conservé, s2 s'ouvre,
   puissance 1, +5 tickets, retour au lobby. Deuxième renaissance : s2 est vidé. Troisième : s2 est promu.
7. **Sauvegarde** : Stop puis Play (avec « Studio Access to API Services ») → slots, Book, tickets et drops sont conservés.
8. **Compagnons** : +5 TICKETS CREW, puis OUVRIR UN COFFRE plusieurs fois (2 s entre deux) : nouveau compagnon
   (équipé s'il reste une place) ou +1 copie. AMÉLIORER apparaît quand les copies suffisent (2 pour le niveau 2) ;
   la production par seconde monte de 10 %. ÉQUIPER / RETIRER change les 2 compagnons actifs.
9. **Maintenance** : onglet **Serveur**, barre de commande : `game.ServerScriptService:SetAttribute("BC_Maintenance", "Roll")`.
   Le panneau affiche « MAINTENANCE : Roll » et une relance répond « coupé pour maintenance » sans dépenser de ticket.
   Remettre `""` pour rouvrir.
