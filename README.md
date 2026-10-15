# Baddie Clicker

Jeu Roblox : on s'entraîne, on affronte sbires et baddies boss, on collectionne et on renaît.
La référence des règles est le **dossier de production v4** (14 octobre 2026).

## État actuel : P0, P1 et P2 validés ; V1 en cours (classement du lobby)

| Fait | Où |
|---|---|
| Profils sauvegardés avec ProfileStore : verrou de session, autosave 60 s, store Studio séparé | `src/server/Services/Profiles.luau` |
| Puissance et entraînement calculés par le serveur, limite 8 actions/s | `Rules/Training.luau`, `Services/TrainingService.luau` |
| Malik le DJ : débloqué après 10 entraînements, production passive serveur 0,6/s | `Rules/Crew.luau`, `Services/CrewService.luau` |
| Effets RGB quand on franchit un cap (paliers, compagnon, niveau, drop, maîtrise) | `Controllers/CelebrationController.luau` |
| Combat individuel : vague de sbires, boss, télégraphies, esquive, mort, portes, drop à 10 % | `Rules/Combat.luau`, `Rules/Encounter.luau`, `Services/CombatService.luau` |
| Carte grise de test (10 arènes + portes, Studio uniquement, placée après le lobby s'il existe) | `src/server/World/DevWorld.luau` |
| Contrat réseau Intent / State / Result / Combat pour le codeur B | `docs/CONTRACT.md` |
| Slots, relances (garantie toutes les 50), drops acceptés/refusés, renaissance et paliers 1/3/6 | `Rules/Slots.luau`, `Services/SlotService.luau` |
| Baddies Book, exposition 3 places, looks débloqués par la maîtrise | `Rules/Collection.luau`, `Services/BookService.luau` |
| Décisions durables : une à la fois, tirage unique, reçu, réponse après la sauvegarde | `Rules/Receipts.luau`, `Services/MutationService.luau` |
| Coffres de compagnons (garantie toutes les 20), niveaux par copies, équipe de 2 | `Rules/Crew.luau`, `Services/CrewService.luau` |
| Classement du lobby (Book public et crew, rangs partagés), rafraîchi par lots | `Rules/Ranking.luau`, `Services/RankingService.luau` |
| Garde-fous du profil au chargement (migrations, invariants), maintenance, restauration | `Rules/ProfileGuard.luau`, `Services/MaintenanceService.luau`, `Admin/`, `docs/OPERATIONS.md` |
| HUD, vue et panneaux de test (temporaires, Studio) | `src/client/Dev/`, `CombatBootstrap.client.luau`, `DevToolsBootstrap.client.luau` |
| 93 tests des règles, des pannes et des profils (cas §30 du dossier) | `tests/run.luau`, `tests/fixtures/` |

**Vocabulaire :** le **Baddies Book** est la collection des baddies découvertes.

Suite du travail : `docs/ROADMAP.md`.

## Installation sur Ubuntu (une seule fois)

**1. Outils (Rokit).** Rokit installe Rojo, Selene, StyLua et Lune aux versions fixées dans `rokit.toml`.

```bash
curl -sSf https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.sh | bash
# ferme et rouvre le terminal, puis à la racine du repo :
rokit install
```

**2. Plugin Rojo dans Roblox Studio (Vinegar).** `rojo plugin install` ne trouve pas le préfixe Wine de Vinegar, donc on le copie à la main :

```bash
curl -L -o /tmp/Rojo.rbxm https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/Rojo.rbxm
find ~/.var/app/org.vinegarhq.Vinegar ~/.local/share/vinegar -type d -path "*Roblox/Plugins" 2>/dev/null
cp /tmp/Rojo.rbxm "<dossier affiché par find>/"
```

Si `find` n'affiche rien : dans Studio, onglet **Plugins → Plugins Folder** ouvre le bon dossier. Relance Studio ensuite.
La version du plugin doit correspondre à celle de `rojo` dans `rokit.toml`.

**3. VS Code.** Ouvre le dossier et accepte les extensions recommandées (Luau Language Server, Rojo, StyLua, Selene).

## Lancer le jeu en local

```bash
rojo serve
```

Dans Studio : **New → Baseplate**, puis **Plugins → Rojo → Connect**, puis **Play**.

Ce que tu dois voir :
- le HUD DEV à gauche et le bouton **ENTRAÎNER** en bas ;
- chaque clic ajoute +1 puissance (le maintien envoie 3 actions/s) ;
- au 10e entraînement, un toast annonce Malik, puis la puissance monte seule de 0,6/s ;
- vers le nord, la carte grise de test : entre dans l'arène du niveau 1 et le combat commence.
  Un panneau de combat de test apparaît à droite : **ATTAQUER** (ou touche **F**). Sors des cercles
  rouges avant l'impact, bats Jade, la porte s'ouvre. Détails : `docs/P1-COMBAT.md`.
- en haut à droite, le panneau **SLOTS · P2** (touche **F4**) : relancer un slot, accepter ou refuser
  un drop, renaître, ouvrir un coffre de compagnon, améliorer ou équiper le crew, et des outils de test.
  Détails : `docs/P2-SLOTS.md`.

**Sauvegarde dans Studio :** tant que le place n'est pas publié avec **Game Settings → Security → Enable Studio Access to API Services**, ProfileStore tourne en mode mock et rien n'est gardé entre deux Play. C'est normal. Une fois l'accès activé, Studio écrit dans `BC_Profiles_STUDIO_v1`, jamais dans les profils des vrais joueurs.

**Test à plusieurs :** onglet **Test → Clients and Servers**, 2 joueurs.

## Avant chaque commit

```bash
lune run tests/run    # règles du jeu
stylua src tests      # formatage
selene src            # lint
```

## Organisation du code

```
src/shared/   → ReplicatedStorage.Shared   (lu par le serveur et le client)
  Balance       tous les chiffres ajustables (paramètres proposés du dossier)
  Catalog       baddies, compagnons, raretés ; IDs stables
  Formulas      calculs purs (§12)
  Net           noms des remotes et des intentions
  Format, Flags affichage des nombres, interrupteurs de dev
  TestCatalog   identités de test, chargées dans Studio uniquement
src/server/   → ServerScriptService.Server
  Bootstrap     ordre d'initialisation, intentions acceptées
  Services/     Profiles, Sessions, StateService, TrainingService, CrewService, CombatService,
                MutationService, SlotService, BookService, MaintenanceService, RankingService,
                DevService (Studio), IntentRouter
  Admin/        ProfileAdmin : versions et restauration de profils (responsables, docs/OPERATIONS.md)
  Rules/        règles pures, testées sans Studio
  Util/         RateLimiter
  Packages/     ProfileStore (Apache-2.0, voir licenses/)
src/client/   → StarterPlayer.StarterPlayerScripts.Client
  Controllers/StateController   seule porte réseau côté client
  Dev/DevHUD                    HUD de test, à retirer quand le vrai HUD arrive
ReplicatedStorage.Remotes       Intent, State, Result (déclarés dans default.project.json)
tests/run.luau                  tests des règles (Lune)
```

Principe : **le serveur décide, le client affiche.** Le client n'envoie jamais un montant, un dégât ou une victoire (§25).

## Travailler à deux

- **Codeur A** : `src/server/`, `src/shared/` (sauf `Flags`), `tests/`.
- **Codeur B** : `src/client/` (sauf `StateController`), `assets/`, la carte, l'intégration Blender.
- Le **contrat réseau** (`docs/CONTRACT.md`) se modifie en PR relue par les deux.
- Une branche par sujet (`a/combat`, `b/hud`…), PR vers `main`.
- **Carte, à décider avec B :** pour garder une seule source de vérité (§23), B exporte le lobby et les arènes en `.rbxm` dans `assets/world/` et on les ajoute au projet Rojo.
