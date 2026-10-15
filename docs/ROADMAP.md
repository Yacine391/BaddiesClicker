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
- [x] Effets RGB de célébration (paliers de puissance, nouveau compagnon, tickets ; prêts pour niveaux, maîtrise, renaissance)
- [x] Vérifier en Studio : Play solo (14/10, Malik et production OK)
- [ ] Vérifier en Studio : 2 joueurs (Test → Clients and Servers)
- [x] Vérifier la sauvegarde réelle (place publié + accès API Studio) : puissance et Malik conservés après Stop / Play

**Codeur B**
- [ ] Maya, 3 looks (Blender, rig R15 commun) → valider avant tout autre personnage *(placeholders R15 en place : `assets/visuals/`)*
- [ ] Malik : modèle, casque, aura, idle + animation de mixage *(placeholder + aura + idle en place)*
- [x] Lobby compact : spawn, sortie visible dans l'axe, podium, entraînement, emplacements « prototype » *(greybox `assets/world/Lobby.rbxm`)*
- [x] HUD final branché sur `StateController`, puis `Flags.DEV_HUD = false`
- [x] Suiveurs (principale + crew) depuis les attributs `BC_*`

**Acceptation P0 (§02)** : le bêta-testeur reconnaît les 3 looks de Maya, constate la production du DJ,
trouve la sortie du lobby ; fluide sur le téléphone de référence ; vidéo réelle de 15 s.

## P1 : un boss jouable (codeur A : combat, mort, victoire)

- [x] `Sessions` : HP joueur, rencontre en cours, cible, cadence
- [x] Ennemis logiques côté serveur : approche → télégraphie (~1 s) → impact → récupération
- [x] Intentions `StartWave(levelId)` et `Attack(encounterId, targetId?)` : portée 25 studs, une application de dégâts par action (la cadence 8/s remplace le numéro de séquence)
- [x] Victoire boss : mur individuel ouvert, récompense de puissance, **un seul** tirage à 10 % → `pendingDrops`
- [x] Mort : retour lobby, portes refermées, puissance et possessions conservées
- [x] Arbitrage « dernier coup contre mort » dans la boucle serveur
- [x] Tests §30 : clic hors combat / en combat, boss vaincu sans drop, deux requêtes de victoire, 20 échecs boss, mort au niveau 8
- [x] Validé en Studio (15/10) : 10 niveaux, rejouer, mort, drop ; bouton principal Attack/Train (codeur B, PR #1)
- [ ] Codeur B : barrière de rue retirée, vraies arènes `Levels/LevelN/Arena` + `Door`, rendu du combat via `onCombat` (ajustements 2 et 3)

Détails : `docs/P1-COMBAT.md`.

## P2 : slots, drops, rebirth, reprises (codeur A)

- [ ] File unique de mutations durables (sauvegarde prioritaire avant confirmation, reçu de mutation)
- [ ] `Roll`, `AcceptDrop`, `RefuseDrop`, `SetActive`, `Rebirth` + garanties 50 (baddies) / 20 (compagnons)
- [ ] Promotion du temporaire aux rebirths 1/3/6, aucun transfert entre slots
- [ ] Tests §30 : aucun cas connu de perte ou de duplication, arrêt serveur pendant une récupération

## V1 puis bêta

- [ ] Dix rencontres configurées, cinq quartiers, catalogue validé
- [ ] Sécurité, stockage, restauration testée, flags serveur de maintenance (§36)
- [ ] Mobile, présentation, matrice de tests complète
