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
- [ ] Maya, 3 looks (Blender, rig R15 commun, régénérée en A-pose sur `b/maya`) → valider avant tout autre personnage *(placeholders R15 en place : `assets/visuals/`)*
- [ ] Malik : modèle, casque, aura, idle + animation de mixage *(placeholder + aura + idle en place)*
- [x] Lobby compact : spawn, sortie visible dans l'axe, podium, entraînement, classement en direct et vitrine Style *(`assets/world/LobbyBuilder.luau` → `Lobby.rbxm`)*
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
- [x] Codeur B : barrière de rue retirée, vraies arènes `Levels/LevelN/Arena` + `Door` (`assets/world/LevelsBuilder.luau` → `Levels.rbxm`), rendu du combat via `onCombat` (`Controllers/Combat`)

Détails : `docs/P1-COMBAT.md`.

## P2 : slots, drops, rebirth, reprises (codeur A) — fusionné le 15/10 (PR #3)

- [x] File unique de mutations durables (sauvegarde prioritaire avant confirmation, reçu de mutation)
- [x] `Roll`, `AcceptDrop`, `RefuseDrop`, `SetActive`, `Rebirth` + garanties 50 (baddies) / 20 (compagnons)
- [x] Promotion du temporaire aux rebirths 1/3/6, aucun transfert entre slots
- [x] Tests §30 : aucun cas connu de perte ou de duplication, arrêt serveur pendant une récupération
- [x] Baddies Book, exposition et looks (proposition « collection » du codeur B), compagnons : coffres, niveaux, équipe
- [x] Garde-fous du profil au chargement, interrupteurs de maintenance, outil de restauration (`docs/OPERATIONS.md`)
- [x] Validé en Studio (15/10). Détails : `docs/P2-SLOTS.md`
- [x] Codeur B : écrans Slots, Drops, Renaissance (fenêtre SLOTS), Crew (coffres, niveaux, équipe) ; panneau F4 réduit aux outils Studio

## V1 puis bêta

- [x] Dix rencontres configurées, cinq quartiers ; équilibrage v4-p1 au simulateur (`docs/BALANCE.md`), à confirmer en bêta
- [x] Anti-triche des déplacements en combat (§25) : rencontre invalidée après 3 anomalies, sans bannissement
- [x] Classement du lobby, garde-robe, titres et 10 succès, statistiques serveur (PR #4 à #6, `docs/V1-CODEUR-A.md`)
- [x] Flags serveur de maintenance (§36) ; outil de restauration écrit
- [x] Restauration répétée avec succès sur un compte de test (21/10, store Studio ; voir `OPERATIONS.md` §3)
- [x] Badges Roblox : les 10 créés et renseignés dans `Config/BadgesConfig` (16/10) ; attribués après publication
- [x] Codeur B : tableau du lobby (`Controllers/Leaderboard`), écran Style, titres au-dessus des avatars (`Controllers/Titles`), vraies arènes et rendu du combat
- [ ] Catalogue validé (modèles et looks des 8 baddies et 6 compagnons)
- [x] PR #8 à #11 fusionnées (21/10) ; retours du test Studio d'Alejandro corrigés (relance de combat après une mort, accents, bannière, toasts, petit écran)
- [x] Matrice de tests §30 (`docs/TEST-MATRIX.md`) et fiche du bêta-testeur (`docs/beta-checklist-p0.md`)
- [ ] Studio : annulation à 3 téléportations (F4 → TÉLÉPORT ×3), maintenance `Roll`, 2 joueurs, émulateur téléphone, équipe pleine
- [ ] Mobile réel, présentation (vidéo 15 s après Maya et Malik)
