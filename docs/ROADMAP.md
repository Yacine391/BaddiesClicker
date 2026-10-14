# Feuille de route (dossier v4 §31)

Règle : après chaque lot, une version jouable va au bêta-testeur. Les idées nouvelles vont dans le
backlog ; pendant P0/P1, seules les corrections de la boucle entrent.

## P0 : identité (en cours)

**Codeur A**
- [x] Repo, Rojo, Rokit, lint, format, tests
- [x] Profil minimal (ProfileStore : verrou de session, autosave 60 s, store Studio séparé, refus d'un schéma plus récent)
- [x] Puissance et entraînement serveur (limite 8/s, maintien 3/s côté client)
- [x] Malik DJ : débloqué au 10e entraînement, production passive serveur 0,6/s, gain réel affiché
- [x] Tickets : +1 baddie / 250 actions, +1 compagnon / 500 actions
- [x] Contrat réseau `docs/CONTRACT.md`
- [ ] Vérifier en Studio : Play solo, puis 2 joueurs (Test → Clients and Servers)
- [ ] Vérifier la sauvegarde réelle (place publié + accès API Studio) : quitter / revenir, puissance et Malik conservés

**Codeur B**
- [ ] Maya, 3 looks (Blender, rig R15 commun) → valider avant tout autre personnage *(placeholders R15 en place : `assets/visuals/`)*
- [ ] Malik : modèle, casque, aura, idle + animation de mixage *(placeholder + aura + idle en place)*
- [x] Lobby compact : spawn, sortie visible dans l'axe, podium, entraînement, emplacements « prototype » *(greybox `assets/world/Lobby.rbxm`)*
- [x] HUD final branché sur `StateController`, puis `Flags.DEV_HUD = false`
- [x] Suiveurs (principale + crew) depuis les attributs `BC_*`

**Acceptation P0 (§02)** : le bêta-testeur reconnaît les 3 looks de Maya, constate la production du DJ,
trouve la sortie du lobby ; fluide sur le téléphone de référence ; vidéo réelle de 15 s.

## P1 : un boss jouable (codeur A : combat, mort, victoire)

- [ ] `Sessions` : HP joueur, rencontre en cours, cible, cadence
- [ ] Ennemis logiques côté serveur : approche → télégraphie (~1 s) → impact → récupération
- [ ] Intentions `StartWave(levelId)` et `Attack(encounterId, targetId, sequence)` : portée 25 studs, une application de dégâts par action
- [ ] Victoire boss : mur individuel ouvert, récompense de puissance, **un seul** tirage à 10 % → `pendingDrops`
- [ ] Mort : retour lobby, portes refermées, puissance et possessions conservées
- [ ] Arbitrage « dernier coup contre mort » dans la boucle serveur
- [ ] Tests §30 : clic hors combat / en combat, boss vaincu sans drop, deux requêtes de victoire, 20 échecs boss, mort au niveau 8

## P2 : slots, drops, rebirth, reprises (codeur A)

- [ ] File unique de mutations durables (sauvegarde prioritaire avant confirmation, reçu de mutation)
- [ ] `Roll`, `AcceptDrop`, `RefuseDrop`, `SetActive`, `Rebirth` + garanties 50 (baddies) / 20 (compagnons)
- [ ] Promotion du temporaire aux rebirths 1/3/6, aucun transfert entre slots
- [ ] Tests §30 : aucun cas connu de perte ou de duplication, arrêt serveur pendant une récupération

## V1 puis bêta

- [ ] Dix rencontres configurées, cinq quartiers, catalogue validé
- [ ] Sécurité, stockage, restauration testée, flags serveur de maintenance (§36)
- [ ] Mobile, présentation, matrice de tests complète
