# Baddie Clicker — contexte projet

Jeu Roblox (Luau). La **source de vérité** est le dossier de production unifié V3+V4 :
- `docs/Baddie_Clicker_Dossier_Unifie.pdf` (46 p.)
- `docs/Baddie_Clicker_Dossier_Unifie.txt` (texte extrait, à grep par numéro de rubrique « NN. Titre »)

Règle de lecture : **la V4 prime**. La rubrique 38 liste les règles V3 remplacées — ne jamais les réintroduire
(pas de Glow, pas de `runEarnedGlow`, pas d'achat de maîtrise, pas de Rare → c'est Silver, compagnon tutoriel = Malik, pas Enzo).
Les chiffres sont des propositions réglables ; les **règles structurelles** (slots sans transfert, boss 10 % sans garantie,
exposition sans puissance) ne changent pas sans décision écrite.

## Équipe et périmètre
- 2 codeurs (A : serveur/profils/combat/slots/drops/sauvegarde ; B : HUD, scène Maya/Malik, carte, anims, intégration Blender), 1 marketing, 1 bêta-testeur.
- **Lot P0 (maintenant)** : Maya 3 looks, Malik DJ, un morceau de lobby compact, auras Maya/Malik, 1 capture verticale.
- **Lot P1** : arène grise, un sbire, Maya en boss de test, une porte, la mort. IDs de test isolés, jamais dans le catalogue public.
- Ne pas produire les 8 baddies en parallèle. Pas de faux boutons dans le lobby.
- Hors V1 : monétisation, échanges, logement, chat perso, IA en direct, offline, classement mondial, votes.

## Boucle et combat
- Hors combat le clic **entraîne** (+puissance) ; en combat il **attaque**. Jamais les deux pour une même entrée.
- Combat **personnel** : chaque joueur a ses ennemis/HP/portes ; les autres ne peuvent ni voler ni subir.
- Joueur 100 HP, portée 25 studs, télégraphie ~1 s puis impact ; tout calculé serveur, le cercle au sol est un rendu client.
- 10 niveaux / 5 quartiers (Street Block, Shopping Avenue, Festival Park, Skyline Rooftop, World Stage). Victoire boss ⇒ mur ouvert pour ce joueur.
- Mort : retour lobby, puissance/slots/Book/drops gardés, **toutes les portes se referment**.
- Rebirth : après niveau 10, volontaire ; puissance → 1 ; paliers 1/3/6 promeuvent le temporaire en conservé.

## Formules (rubrique 12)
```
bonusEntrainement = 1 + 0.10 × min(rebirths, 20)
gainManuel        = 1 × bonusEntrainement
gainPassif/s      = Σ compagnons actifs × bonusEntrainement
dégâts/clic       = puissance × multiplicateurPrincipale × (1 + 0.05 × maîtrisePrincipale)
```
Maîtrise 0–10 : +1 XP/sbire, +5 XP/boss (si principale), seuil niveau L = 10 × L². Récompense puissance : sbire 2×niveau, boss 10×niveau.
Tickets : 10 baddie à la création ; 1 baddie / 250 entraînements ; 1 compagnon / 500 ; +1 baddie au 1er passage d'un niveau par run ;
rebirth +5 baddie +1 compagnon.

## Slots, drops, Book
- Slots à identité fixe, **aucun transfert inter-slot**. `activeSlotId` choisit la principale (seule source de multiplicateur).
- « Conservé » survit au rebirth mais **une relance le remplace quand même**. 1 seul temporaire, 3 conservés max.
- Relance : 1 ticket, hors combat, résultat enregistré avant animation. Garantie : toutes les 50 relances baddie (20 coffres compagnon), identité manquante tirée uniformément.
- Boss : **10 % fixe**, sans pity. Drop ⇒ `pendingDrops` (inutilisable, n'expire jamais, survit mort/rebirth). Accepter 1 ⇒ remplace **uniquement le temporaire**. Interdit dans un conservé.
- Book = découvertes permanentes. Exposition (3 places) = **apparence uniquement, aucune puissance**. Classement lobby = nb d'identités découvertes.

## Catalogue V1
Baddies : Maya Common ×1 (32 %), Lina Common ×1,2 (25 %), Jade Silver ×1,5 (17 %), Iris Silver ×1,8 (12 %),
Sienna Gold ×2,2 (7 %), Nova Gold ×2,5 (5 %), Zuri Legendary ×3,2 (1,5 %), Vega Mythic ×4 (0,5 %).
Compagnons (pas d'attaque en V1, 2 actifs max) : Enzo 0,4/s, Malik 0,6/s, Rafael 0,8/s, Dario 1,2/s, Kenji 1,6/s, Amine 2,0/s.
Niveau compagnon : L→L+1 coûte L+1 copies, max 10, taux = base × (1 + 0.10 × (L-1)).

## Architecture et sécurité (rubriques 23–27)
- Arbo réelle (voir README) : `src/shared/` (Balance, Catalog, Formulas, Net, Format, Flags), `src/server/` (Bootstrap,
  Services/, Rules/, Util/, Packages/ProfileStore), `src/client/` (Bootstrap, Controllers/, Dev/DevHUD), remotes déclarés
  dans `default.project.json`. Chiffres ajustables uniquement dans `Shared/Balance`.
- Modules `Init(deps)` puis `Start()`. Formules, tirages et transitions de slots dans des **modules purs testables**.
- **Autorité serveur** : le client n'envoie que des intentions (Train, Attack, StartWave, Roll, AcceptDrop, RefuseDrop, SetActive, Rebirth…). Jamais de dégâts, taux ou victoire fournis par le client.
- `requestId` = clé d'idempotence ; tirage unique **hors** callback `UpdateAsync` ; reçu durable de mutation.
- Verrou de session (bail + génération) ; mutations durables sérialisées ; autosave ~60 s décalé ; jamais d'écriture par clic.
- Profil introuvable ⇒ **jamais** de profil vide de remplacement. DataStore de test séparé de la prod.
- Schéma de profil : rubrique 24 (`schemaVersion = 4`).
- Équilibrage dans un fichier de config séparé, versionné.

## Quand utiliser quel skill / outil
Seulement quand la situation correspond — pas de skill pour une petite modif évidente.

| Moment | Skill / outil | Pourquoi ici |
|---|---|---|
| Avant de concevoir un système (profil, combat, slots…) | `superpowers:brainstorming` → `superpowers:writing-plans` | Beaucoup de paramètres du dossier sont des propositions : trancher avant de coder |
| Écrire un module serveur pur (formules, tirages, transitions de slots) | `superpowers:test-driven-development` | Rubriques 30 et 37 : modules purs testés |
| Plan écrit avec tâches indépendantes | `superpowers:subagent-driven-development` | Un agent par module, relecture entre chaque |
| Choix d'architecture durable (verrou de session, ProfileStore vs maison…) | `engineering:architecture` | Décision écrite, comme l'exige la rubrique 36 |
| Remotes, mutations de profil, sauvegarde | `security-review` puis `code-review` | Perte/duplication = risque critique n°1 |
| Bug ou comportement inattendu | `superpowers:systematic-debugging` | Courses mort/dernier coup, erreurs DataStore |
| Avant de dire « ça marche » | `superpowers:verification-before-completion` | Toujours vérifier en Play dans Studio |
| Traduire la matrice de la rubrique 30 | `engineering:testing-strategy` | Plan de tests pour le bêta-testeur |
| Maquette / hiérarchie du HUD | `ui-ux-pro-max` | Cibles 48 px, contraste, mobile |
| Scripts TikTok, calendrier | `marketing:content-creation`, `marketing:campaign-plan` | Rubriques 33–35 |
| Codebase devenue grosse | `graphify` | Cartographier les dépendances |
| Modèles, rig, rendus face/profil/dos | MCP `Blender` | Une seule instance : jamais deux agents en parallèle dessus |
| Greybox, scripts, Play, console | MCP `Roblox_Studio` | Idem, travail séquentiel |

Agents : oui pour modules indépendants, recherche doc Roblox, relecture indépendante, ou pistes Codeur A / Codeur B
en worktrees séparés. Non pour Blender/Studio (instance unique) ni pour paralléliser les personnages avant validation de Maya.

## Repo, rôles et toolchain
- Repo partagé avec **Yacine (Codeur A)**. L'utilisateur est **Codeur B** : `src/client/` (sauf `Controllers/StateController`),
  `assets/`, la carte, l'intégration Blender. Codeur A : `src/server/`, `src/shared/` (sauf `Flags`), `tests/`.
- **Contrat réseau = `docs/CONTRACT.md`** ; toute modification (et de `src/shared/`, `default.project.json`, `rokit.toml`) passe
  par une PR relue par les deux. Une branche par sujet (`b/...`), PR vers `main`. Ne jamais pousser sur `main` directement.
- Côté client, ne jamais brancher les remotes à la main : passer par `StateController` (`onState`, `onResult`, `send`).
- Outils (Rokit, `rokit install`) : Rojo 7.7.1, Selene, StyLua, Lune. Avant chaque commit :
  `lune run tests/run`, `stylua src tests`, `selene src`.
- `rojo serve` (port par défaut 34872) ; place locale `BaddieClicker.rbxl` ignorée par Git. Carte : export `.rbxm` dans
  `assets/world/` (proposition de Yacine). Le HUD de test se coupe avec `Flags.DEV_HUD = false` quand le vrai HUD est branché.

## Art
Adultes 3D stylisés, streetwear français / scène musicale, sans sexualisation. Palette : Nuit #242036, Violet #7642A3, Cyan #13A6B5, Or #D7A746, Crème #F4EEE7.
Pas de marques/célébrités réelles (ex. 92i). Nommage : `B06_Nova_Look02`, `C02_Malik_Base`, `Aura_Nova_Gold`, `Anim_C02_Signature`.
Valider Maya (rig R16, export tôt vers Studio) avant tout autre personnage.
