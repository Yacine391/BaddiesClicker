# Baddie Clicker — Lot P0, Codeur B : design

**Date :** 14 octobre 2026 — **révision 2** (alignée sur le serveur du Codeur A, commit `b21b327`)
**Statut :** révisé, en attente de relecture
**Références :** `docs/Baddie_Clicker_Dossier_Unifie.pdf` (rubriques entre parenthèses), `docs/CONTRACT.md` (contrat v1),
`docs/proposals/2026-10-14-contract-v2-collection.md` (extension proposée)

## 0. Ce qui change depuis la révision 1

Le Codeur A (Yacine) a livré le vrai serveur P0 : profils ProfileStore, entraînement, Malik, tickets, contrat v1,
`StateController` côté client et un HUD de test. En conséquence :
- **plus de mock serveur** : le client se branche sur le serveur réel via `StateController` ;
- le client suit le **contrat v1** (`docs/CONTRACT.md`) et ses règles d'équipe (README) ;
- Book, Style et exposition demandent une **extension du contrat (v2)**, proposée au Codeur A ;
- Malik n'est **pas équipé au départ** : il arrive au 10ᵉ entraînement (tutoriel du Codeur A) ;
- Fusion est **copié dans `src/client/Packages/`** (comme ProfileStore côté serveur) au lieu de Wally ;
- placeholders et lobby sont construits dans Studio puis **exportés en `.rbxm` dans `assets/`**.

## 1. Objectif

Livrer la partie client du lot P0 (rubrique 02) : une scène cohérente et testable où le joueur s'entraîne dans un lobby
compact, voit Maya et ses trois looks, est rejoint puis suivi par Malik DJ qui produit de la puissance, et consulte un Book
qui distingue clairement **principale** et **exposition**.

### Critères d'acceptation (rubrique 02)
Le bêta-testeur, sans explication : reconnaît les trois looks de Maya ; distingue sa principale de son exposition ; constate
la production automatique de Malik ; trouve la sortie du lobby. La scène reste fluide en émulation téléphone puis sur
téléphone réel, et permet une capture verticale de 15 s.

### Périmètre
| Inclus (Codeur B) | Exclu |
|---|---|
| HUD final (style V3), fenêtres Book, Style, Crew, Réglages | Tout `src/server/` et `src/shared/` (Codeur A) |
| Suiveurs (principale + crew) depuis `State` et attributs `BC_*` | Combat, arène, mort (P1) |
| Placeholders R15 de Maya (3 looks) et Malik, exportés dans `assets/visuals/` | Modèles Blender finaux (remplacent les placeholders) |
| Greybox du lobby exportée dans `assets/world/` | Relances, drops, rebirth, classement fonctionnel |
| Podium et auras | Badges Roblox (P0 = succès internes, rubrique 19) |
| Proposition de contrat v2 (exposition, looks) | Implémentation serveur du v2 (Codeur A) |
| Tests Lune des modules purs client, vérification Play via MCP, checklist bêta | Montage vidéo (marketing) |

## 2. Règles de collaboration (README du Codeur A)

- Le Codeur B modifie `src/client/` (sauf `Controllers/StateController`), `assets/`, la carte.
- `docs/CONTRACT.md`, `src/shared/`, `default.project.json`, `rokit.toml`, `tests/run.luau` : **PR relue par les deux**.
- Une branche par sujet (`b/...`), PR vers `main`. Avant chaque commit : `lune run tests/run`, `stylua src tests`, `selene src`.
- `Flags.DEV_HUD` passe à `false` dans la PR qui branche le vrai HUD (seule exception à `shared/` côté B, prévue par le README).

## 3. Architecture client

```
src/client/
  Bootstrap.client.luau        (existant) → démarre aussi l'App si DEV_HUD = false
  Controllers/StateController   (Codeur A, inchangé) onState / onResult / send
  Packages/Fusion/              Fusion 0.3.0 copié (licence dans licenses/Fusion-LICENSE.txt)
  App.luau                      crée le scope Fusion, démarre les contrôleurs dans l'ordre
  Store.luau                    valeurs Fusion dérivées du snapshot (power, crew, tutorial, collection…)
  UiState.luau                  fenêtre ouverte, réglages locaux, impulsions d'animation
  Logic/                        [pur] HudModel, Formation, LookRotation
  UI/Theme.luau, UI/Text.luau, UI/Components/*
  Controllers/  Input, HUD, Book, Style, Crew, Settings, Followers, Podium, FX
tests/client/run.luau          tests Lune des modules [pur] de src/client/Logic (nouveau runner, ne modifie pas tests/run.luau)
assets/visuals/Characters.rbxm  placeholders (B01_Maya/Look01-03, C02_Malik/Base)
assets/world/Lobby.rbxm         greybox du lobby
```

Règles : les modules **[pur]** n'utilisent aucune API Roblox ni `require` (dépendances en paramètres) ; ils prennent le
snapshot et `Catalog`/`Balance` en argument. Le client ne décide d'aucun gain et ne branche jamais les remotes à la main.

**Seule modification partagée nécessaire** (une PR, déjà suggérée par le README du Codeur A) : dans `default.project.json`,
mapper `assets/visuals/Characters.rbxm` → `ReplicatedStorage.Visuals.Characters` et `assets/world/Lobby.rbxm` →
`Workspace.Lobby`.

## 4. Contrat utilisé

### v1 (existant, `docs/CONTRACT.md`)
- Intentions : `Hello` (envoyée par `StateController.start`), `Train` (aucun payload, 8/s côté serveur ; maintien client 3/s
  = `Balance.training.holdActionsPerSecond`). Une intention refusée est **ignorée sans réponse**.
- Snapshot : `mode`, `power`, `gainPerTrain`, `passivePerSecond`, `trainingBonus`, `rebirths`, `tickets`, `active {slotId,
  baddieId, multiplier, masteryLevel, damagePerClick}`, `crew {id, level, copies, perSecond}[]`, `stats`, `tutorial
  {crewUnlocked, progress, needed}`. Envoi groupé toutes les 0,1 s au plus ; les RemoteEvents étant ordonnés, le dernier
  snapshot reçu fait foi.
- `Result` : `crewJoined {crewId, isNew, equipped}`, `ticket {ticket, amount}`, `passiveTick {amount}`.
- Attributs : `BC_Ready`, `BC_ActiveBaddie`, `BC_EquippedCrew`.
- Noms, raretés, couleurs, looks : `Shared/Catalog` (`looks` = noms « Street Start », « Street Match », « Street Signature ») ;
  nombres : `Shared/Format.number`.

### v2 (proposé au Codeur A — détail dans le document de proposition)
- Snapshot : `collection = { discovered = {string}, display = {string}, looks = { [baddieId] = { unlocked = {number},
  selected = number } } }` (index de look 1..3).
- Intentions : `SetDisplay { ids }` (≤ 3, découvertes, sans doublon) ; `SetLook { baddieId, look }` (look débloqué).
- Attributs : `BC_ActiveLook` (index), `BC_Display` (IDs séparés par des virgules).
- Seuils de looks dans `Balance` : look 1 à maîtrise 0, look 2 à maîtrise 1, look 3 à maîtrise 5 (rubrique 03).
- En Studio uniquement : intention `DevSetMastery { baddieId, xp }` et identité de test `test_b99` découverte, pour tester
  l'exposition sans assets absents (rubriques 02, 13, 30).

**Tant que le v2 n'est pas fusionné**, le client lit `snapshot.collection` s'il existe ; sinon Book et Style affichent
Maya seule, sans actions d'exposition ni de choix de look (aucun faux bouton).

## 5. Lobby et personnages

### Lobby (greybox, rubrique 05) — `assets/world/Lobby.rbxm`
- Place d'environ 90 × 70 studs, sol continu, aucun saut imposé ; spawn au sud ; **sortie au nord visible dès le spawn**.
- La sortie mène à un court segment de rue fermé par une barrière « Niveau 1 : bientôt » (arène en P1).
- Zone d'entraînement à l'ouest ; podium de Maya décalé à l'est (`Podium.Stand`).
- Book/Classement et Relances/Style : **panneaux « Prototype » non interactifs**.
- Construit dans Studio via le MCP, puis exporté (clic droit → Enregistrer dans un fichier) vers `assets/world/Lobby.rbxm`.

### Placeholders — `assets/visuals/Characters.rbxm`
| Modèle | Description |
|---|---|
| `B01_Maya/Look01` | R15, palette `Catalog.baddies.maya.palette` (denim, crème, orange doux) |
| `B01_Maya/Look02` | + bracelet et baskets assortis |
| `B01_Maya/Look03` | + accent orange et bijoux géométriques |
| `C02_Malik/Base` | R15 plus large, palette `Catalog.crew.malik.palette`, casque simple |
| `TEST/TEST_B99` | Silhouette grise (affichée seulement en Studio, si le v2 l'expose) |

Chaque modèle : `AnimationController` + `Animator`, `AuraAttachment`, `NameTagAttachment`, aucun `Humanoid`. Un modèle
Blender remplace un placeholder en gardant le même nom et les mêmes attachments.

### Podium
Rendu local : Maya change de look toutes les ~6 s avec un demi-tour ; étiquette « Look N · <nom du Catalog> ».

### Suiveurs (rubrique 28)
- Rendu **client uniquement** : joueur local depuis le snapshot (principale, crew, exposition v2) ; autres joueurs depuis
  `BC_ActiveBaddie`, `BC_EquippedCrew` (et `BC_ActiveLook`, `BC_Display` en v2), uniquement si `BC_Ready`.
- Formation stable derrière l'avatar, positions interpolées, sans collision ; recalage au-delà d'une distance seuil ;
  idle et marche ; suiveurs des autres joueurs simplifiés puis masqués avec la distance ; 20 rigs animés maximum.
- Malik apparaît à la réception de `crewJoined` (petite entrée en scène) ; `passiveTick` affiche « +0,6 » au-dessus de lui.
- Nettoyage complet au départ d'un joueur ou au changement d'équipe.

### Auras
Maya : halo orange discret ; Malik : barres d'égaliseur cyan. « Effets réduits » atténue les auras locales et des autres.

## 6. HUD et fenêtres (style V3 validé sur maquette)

### Thème
Polices `LuckiestGuy` (chiffres, titres) et `FredokaOne` (libellés) ; texte blanc, `UIStroke` sombre 3–4 px, ombre portée ;
boutons en relief (`UIGradient`, liseré blanc, contour sombre, bande basse foncée) ; palette du dossier + vert d'action et
rouge de fermeture.

### Composants Fusion (un fichier chacun, `UI/Components/`)
| Composant | Rôle |
|---|---|
| `MenuTile` | Tuile carrée, icône qui dépasse, libellé dessous, badge « NEW! » |
| `BigStat` | Icône + chiffre géant sans panneau, « pop » quand la valeur change |
| `ActionButton` | Gros bouton qui s'écrase au clic puis rebondit |
| `FloatingNumber` | « +1 » / « +0,6 » qui s'envole |
| `Window` | Bord lumineux, titre en pilule, croix rouge, fond à motif, bloque les clics vers le jeu |
| `ListRow` | Ligne colorée : portrait, nom, chips, bouton |
| `Chip` | Étiquette de statut |
| `Toast` | Message court (nouveau compagnon, ticket) |

### Écrans
| Écran | Contenu |
|---|---|
| HUD | Principale en haut au centre (nom, rareté, ×multiplicateur, slot) ; tuiles Book, Crew, Style, Réglages à gauche ; en bas à gauche puissance (`Format.number`), production du crew (« +0,6/s Malik ») et tickets ; tant que `tutorial.crewUnlocked` est faux, une jauge « Malik arrive : progress/needed » ; bouton ENTRAÎNER en bas à droite, libellé et couleur liés à `mode` |
| Book | Onglets Baddies (`#discovered` / 8 du lot public) et Crew ; fiche Maya « PRINCIPALE · SLOT 1 » ; en v2, fiche exposée avec « Apparence uniquement · aucun multiplicateur » et Exposer/Retirer ; « ??? » pour les identités non découvertes |
| Style | Les trois looks de Maya ; en v2, sélection des débloqués ; verrouillés grisés avec « Maîtrise 1 » / « Maîtrise 5 » |
| Crew | Compagnons du snapshot : nom, rôle, `perSecond`, niveau, copies |
| Réglages | Effets réduits, suiveurs des autres joueurs, maintien du clic (3/s) — locaux en P0 (`settings.reducedEffects` existe dans le profil : persistance à ajouter au contrat plus tard) |

### Comportement
- Retour visuel immédiat au clic ; le chiffre de puissance ne change qu'à réception du snapshot.
- Une seule fenêtre ouverte ; croix ou Échap ; aucune intention `Train` tant qu'une fenêtre est ouverte (rubrique 21).
- `UIScale` sur 1280 × 720 ; `ScreenInsets` pour les encoches ; cibles ≥ 48 px ; libellés en plus des couleurs.
- Icônes : emoji/formes simples tant que les rendus Blender (PNG transparents, référencés dans `Theme.Icons`) n'existent pas.

## 7. Gestion des erreurs

| Situation | Comportement |
|---|---|
| Aucun snapshot reçu | « Chargement… », bouton désactivé ; jamais de profil inventé |
| Intention ignorée par le serveur (cadence, combat) | Aucun changement de chiffre ; l'animation locale du clic reste purement visuelle |
| `snapshot.collection` absent (v1) | Book/Style en lecture seule, sans actions |
| Modèle visuel absent | Silhouette grise de secours + avertissement console |
| ID inconnu du `Catalog` dans un attribut | Ignoré (aucun suiveur), avertissement console |
| Départ d'un joueur | Nettoyage via un `scope` Fusion et des connexions par joueur |

## 8. Tests

1. **Lune** — `lune run tests/client/run` (modules `src/client/Logic`) :
   - `HudModel` : textes du HUD depuis un snapshot (puissance via `Format.number`, « +0,6/s Malik », jauge du tutoriel
     « 7/10 », pastille principale « MAYA ×1 · Slot 1 ») ; snapshot sans crew → pas de ligne de production ; compteur Book
     ignorant `test_b99`.
   - `Formation` : positions des suiveurs (1, 2, 3 suiveurs), fusion principale/exposition, recalage au-delà du seuil.
   - `LookRotation` : ordre et période du podium.
2. **Play dans Studio via le MCP** : HUD présent ; clic → puissance +1 ; au 10ᵉ clic, toast Malik puis production
   ≈ 0,6/s ; suiveurs présents ; fenêtre ouverte → aucun `Train` ; deux joueurs : suiveurs de l'autre visibles et nettoyés.
3. **Checklist bêta-testeur** reprenant les critères d'acceptation, d'abord en émulation téléphone.

## 9. Définition de « terminé »
- `lune run tests/run` et `lune run tests/client/run` passent ; `selene src` sans erreur ; `stylua` appliqué.
- Vérification Play validée ; checklist bêta remise.
- PR client (HUD, fenêtres, suiveurs, `DEV_HUD = false`), PR assets (mapping Rojo) et proposition v2 ouvertes et relues.
- L'exposition est démontrable dès que le Codeur A a fusionné le v2.

## 10. Points ouverts
- **Groupe Roblox** propriétaire du jeu et accès des deux codeurs (nécessaire pour tester la sauvegarde réelle).
- **Animations** des placeholders (animations Roblox par défaut) à confirmer en Play.
- **Blender** : remplacer la 5.4 Alpha par une version stable avant l'export de Maya.
