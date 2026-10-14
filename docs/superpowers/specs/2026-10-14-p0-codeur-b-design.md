# Baddie Clicker — Lot P0, Codeur B : design

**Date :** 14 octobre 2026
**Statut :** validé section par section en brainstorming, en attente de relecture
**Référence :** `docs/Baddie_Clicker_Dossier_Unifie.pdf` (rubriques citées entre parenthèses)

## 1. Objectif

Livrer la partie client du lot P0 (rubrique 02) : une scène cohérente et testable où le joueur s'entraîne
dans un lobby compact, voit Maya et ses trois looks, est suivi par Malik DJ qui produit de la puissance,
et consulte un Book qui distingue clairement **principale** et **exposition**.

### Critères d'acceptation (rubrique 02)
Le bêta-testeur, sans explication :
1. reconnaît les trois looks de Maya ;
2. distingue sa principale de son exposition ;
3. constate la production automatique de Malik ;
4. trouve la sortie du lobby.

La scène reste fluide en émulation téléphone puis sur téléphone réel, et permet une capture verticale de 15 s.

### Périmètre
| Inclus | Exclu (autre lot ou autre rôle) |
|---|---|
| Greybox du lobby, podium Maya, zone d'entraînement, sortie | Combat, arène, sbires, boss, mort (P1) |
| Placeholders R15 de Maya (3 looks) et Malik | Modèles Blender finaux (remplacent les placeholders plus tard) |
| Suiveurs (principale + Malik) et auras | Relances, drops, rebirth, classement fonctionnel |
| HUD d'entraînement, fenêtres Book, Style, Crew, Réglages | Sauvegarde DataStore réelle (Codeur A) |
| Mock serveur derrière le vrai contrat réseau | Monétisation, badges Roblox (rubrique 19 : P0 = succès internes seulement) |
| Tests Lune des modules purs, vérification Play via MCP, checklist bêta | Montage de la vidéo (marketing) |

### Rôles
- **Codeur B (ce document)** : tout ce qui précède.
- **Codeur A** : remplacera `MockProfile` par le vrai service de profils (verrou de session, DataStore,
  rubriques 24 à 27) **sans modifier le client ni le contrat**.

## 2. Décisions retenues

| Sujet | Décision |
|---|---|
| Flux de travail | Code Luau en fichiers via Rojo 7.7.1 (port 34872) + Git ; place `BaddieClicker` dans Studio |
| Serveur | Mock côté serveur derrière les vrais remotes `Intent` / `State` / `Result` |
| Interface | Fusion 0.3 (Wally), style « simulateur Roblox » V3 validé sur maquette |
| Modèles | Placeholders R15 nommés selon la convention du dossier, remplaçables sans changer le code |
| Carte | Construite dans Studio et sauvegardée dans la place (Rojo ne gère pas `Workspace`) |
| Tests | Modules purs testés avec Lune hors Studio, en TDD |

## 3. Architecture

```
default.project.json   ReplicatedStorage.Shared / ServerScriptService.Server / StarterPlayerScripts.Client
wally.toml             Fusion 0.3 → ReplicatedStorage.Packages (mapping à ajouter au projet Rojo)
src/shared/
  Types.luau             types ClientProfile, Intent, Result
  Catalog.luau           catalogue public P0 : maya (B01), malik (C02)
  TestCatalog.luau       TEST_B99, chargé uniquement si RunService:IsStudio()
  Rules/Formulas.luau    gainManuel, gainPassif, dégâts                    [pur]
  Rules/Collection.luau  possession, exposition, looks débloqués, maîtrise [pur]
  Rules/Validators.luau  validation des intentions                         [pur]
  Rules/StateReducer.luau ordre des révisions, détection de trou           [pur]
  Net/Contract.luau      noms des remotes, types et limites
  UI/Theme.luau          couleurs, polices, tailles, table Icons
src/server/
  init.server.luau       crée les remotes, Init(deps) puis Start() de chaque service
  Services/MockProfile.luau  profil en mémoire par joueur
  Services/Training.luau     gain manuel et production passive
  Services/Crew.luau         compagnons équipés et taux
  Services/Appearance.luau   attributs visuels publics sur Player
  Net/IntentRouter.luau      validation, cadence, séquence, routage, Result
src/client/
  init.client.luau
  StateStore.luau        valeurs Fusion alimentées par State (via StateReducer)
  Controllers/  Input, HUD, Followers, Podium, Book, Style, Crew, Settings, FX
  UI/Components/  MenuTile, BigStat, ActionButton, FloatingNumber, Window, ListRow, Chip
tests/                   specs Lune des modules [pur] ; `lune run tests`
```

Règles de structure :
- Chaque service expose `Init(deps)` puis `Start()` ; pas de dépendance circulaire (rubrique 23).
- Les modules marqués **[pur]** n'utilisent aucune API Roblox (`game`, `Instance`, `RunService`…) et ne
  font pas de `require` d'autres modules : leurs dépendances sont passées en paramètres. Ils sont ainsi
  chargeables à l'identique par Roblox et par Lune.
- Le client ne décide d'aucun gain : il affiche ce que le serveur publie (rubrique 25).

## 4. Contrat réseau

Trois `RemoteEvent` dans `ReplicatedStorage.Remotes` :

### `Intent` (client → serveur)
| `kind` | Champs | Validation serveur |
|---|---|---|
| `Train` | `sequence` | Profil prêt ; cadence ≤ 8/s (limite dédiée à l'entraînement) |
| `SetDisplay` | `sequence`, `ids: {string}` | ≤ 3, sans doublon, toutes découvertes, IDs connus |
| `SetLook` | `sequence`, `baddieId`, `lookId` | Baddie découverte, look débloqué |
| `Sync` | `sequence` | Renvoie un instantané complet |
| `DevSetMastery` | `sequence`, `baddieId`, `xp` | **Uniquement si `RunService:IsStudio()`** ; ignoré sinon |

`sequence` est un entier strictement croissant par client ; une séquence non croissante est rejetée.
Le client n'envoie jamais de puissance, de gain ou de résultat.

### `State` (serveur → propriétaire uniquement)
```luau
type ClientProfile = {
  revision: number,
  power: number,               -- décimales conservées, affichage arrondi
  rebirths: number,            -- 0 en P0
  gainPerTrain: number,        -- Formulas.manualGain(rebirths)
  passivePerSec: number,       -- Formulas.passiveGain(taux équipés, rebirths)
  activeSlotId: string,        -- "s1"
  slots: { [string]: { order: number, conserved: boolean, baddieId: string? } },
  discovered: { [string]: true },
  display: { string },         -- ≤ 3 IDs
  masteryXP: { [string]: number },
  unlockedLooks: { [string]: { string } },
  selectedLook: { [string]: string },
  equippedCrew: { string },    -- ≤ 2 identités distinctes
  crew: { [string]: { level: number, copies: number } },
}
```
Publication : à chaque changement, regroupée à **4 envois par seconde maximum** (la production passive
change en continu). `revision` augmente de 1 à chaque envoi.

### `Result` (serveur → client)
`{ sequence: number, ok: boolean, reason: string? }` pour chaque intention traitée.
Raisons P0 : `NotReady`, `RateLimited`, `BadSequence`, `Invalid`, `Locked`, `NotDiscovered`, `TooMany`.

### Données publiques (autres joueurs)
Attributs sur l'instance `Player`, posés par `Appearance` : `BC_ActiveBaddie`, `BC_ActiveLook`,
`BC_Display` (IDs séparés par des virgules), `BC_Crew`. Jamais de tickets, compteurs ni historique.

### Comportement du mock
- Profil initial en mémoire : `power = 1`, Maya dans `s1` (principale), Malik équipé niveau 1,
  `discovered = { maya }`, maîtrise 0, `Look01` débloqué et sélectionné.
- En Studio uniquement : `TEST_B99` ajouté aux découvertes, non possédé, pour tester l'exposition.
- `Train` : `power += gainPerTrain` (1 en P0).
- Production : `power += passivePerSec × dt` côté serveur (0,6/s avec Malik niveau 1, rubrique 04).
- Rien n'est sauvegardé ; un nouveau serveur repart du profil initial.

## 5. Lobby et personnages

### Lobby (greybox, rubrique 05)
- Place d'environ 90 × 70 studs dans `Workspace.Lobby`, sol continu, aucun saut imposé.
- Spawn au sud ; **sortie au nord, visible dès le spawn**, sur l'axe dégagé.
- La sortie mène à un court segment de rue fermé par une barrière « Niveau 1 : bientôt » (l'arène est en P1).
- Zone d'entraînement à l'ouest (décor et indication « Entraînement ») ; podium de Maya décalé à l'est.
- Emplacements Book/Classement et Relances/Style : **panneaux « Prototype » non interactifs**.
- Kit réutilisable : sols, murs, bancs, néons, signalétique, aux couleurs de la palette (rubrique 20).

### Placeholders (`ReplicatedStorage.Visuals.Characters`)
| Modèle | Description |
|---|---|
| `B01_Maya/Look01` | R15, palette denim/crème/orange, carré bouclé simplifié |
| `B01_Maya/Look02` | + bracelet et baskets assortis |
| `B01_Maya/Look03` | + accent orange et bijoux géométriques |
| `C02_Malik/Base` | R15 plus large, anthracite/cyan/argent, casque simple |
| `TEST/TEST_B99` | Silhouette grise neutre (Studio uniquement) |

Un modèle Blender remplace un placeholder en gardant **le même nom et les mêmes attachments**
(`AuraAttachment`, `NameTagAttachment`). Aucun code ne référence une pièce interne du modèle.

### Podium
Rendu local : Maya change de look toutes les ~6 s avec un petit demi-tour ; étiquette
« Look N · Street Start / Street Match / Street Signature ».

### Suiveurs (rubrique 28)
- Rendu **côté client uniquement**, à partir du `State` (joueur local) ou des attributs (autres joueurs).
- Formation stable derrière l'avatar, positions interpolées, `CanCollide = false`, pas de `Humanoid`
  complet (`AnimationController` + `Animator`), recalage discret au-delà d'une distance seuil.
- Idle et marche partagés ; affichage fusionné si la principale est aussi exposée.
- Suiveurs des autres joueurs simplifiés puis masqués avec la distance ; budget initial 20 rigs animés.
- Nettoyage complet (modèles, connexions, animations) au départ d'un joueur.

### Auras
Maya : halo orange discret ; Malik : barres d'égaliseur cyan. Le réglage « Effets réduits » atténue les
auras du joueur local et des autres joueurs.

## 6. HUD et fenêtres (style V3)

### Thème
- Polices : `LuckiestGuy` (chiffres, titres), `FredokaOne` (libellés).
- Texte : blanc, `UIStroke` sombre 3–4 px, ombre portée par copie décalée.
- Relief des boutons : `UIGradient` vertical, liseré blanc intérieur, contour sombre, bande basse foncée.
- Palette du dossier (Nuit, Violet, Cyan, Or, Crème) + vert pour l'action principale, rouge pour fermer.

### Composants Fusion
Un composant = un fichier dans `Client/UI/Components/`.

| Composant | Rôle |
|---|---|
| `MenuTile` | Tuile carrée, icône qui dépasse en haut, libellé dessous, badge « NEW! » facultatif |
| `BigStat` | Icône + chiffre géant sans panneau, « pop » (spring) quand la valeur change |
| `ActionButton` | Gros bouton vert qui s'écrase au clic puis rebondit (spring sur `UIScale`) |
| `FloatingNumber` | « +1 » qui s'envole et disparaît |
| `Window` | Bord lumineux à dégradé tournant, titre en pilule qui déborde, croix rouge, fond à motif |
| `ListRow` | Ligne colorée : portrait, nom, `Chip`s de statut, bouton d'action |
| `Chip` | Étiquette de statut (Common, Principale, Exposée…) |

### Écrans
| Écran | Contenu |
|---|---|
| HUD | Principale en haut au centre ; tuiles Book, Crew, Style, Réglages à gauche ; puissance, production de Malik et gain par entraînement en bas à gauche ; bouton ENTRAÎNER en bas à droite |
| Book | Onglets Baddies (lot public, ex. 1/8) et Crew ; fiche Maya (Principale · Slot 1 · ×1) ; fiche TEST_B99 (Exposée · « Apparence uniquement · aucun multiplicateur ») ; actions Exposer / Retirer |
| Style | Looks de Maya ; looks verrouillés avec leur condition (« Maîtrise 1 », « Maîtrise 5 ») |
| Crew | Malik : taux/s, niveau, copies |
| Réglages | Effets réduits, suiveurs des autres joueurs, maintien du clic (3 actions/s) — non persistés en P0 |

`TEST_B99` n'entre jamais dans le compteur du lot public.

### Comportement
- Retour visuel immédiat au clic (bouton qui s'écrase, « +1 » qui s'envole) ; le chiffre de puissance ne
  change qu'à réception du `State`.
- Une seule fenêtre ouverte ; fermeture par la croix ou Échap ; la fenêtre bloque les clics vers le jeu.
- `UIScale` sur une base 1280 × 720 ; `ScreenInsets` pour les encoches ; cibles tactiles ≥ 48 px ;
  libellés en plus des couleurs (rubrique 21).

### Icônes
Placeholders (emoji ou formes simples) dans des `ImageLabel`, référencés par nom dans `Theme.Icons`.
Ils seront remplacés par des rendus Blender en PNG transparent, sans changement de code. La texture à
motif des fenêtres suit le même principe.

## 7. Gestion des erreurs

| Situation | Comportement |
|---|---|
| Profil pas encore prêt | « Chargement… » ; actions désactivées jusqu'au premier `State` ; jamais de profil inventé |
| Intention refusée | `Result.ok = false` + `reason` ; message court au joueur ; aucun changement local |
| `State` plus ancien que le courant | Ignoré |
| Trou de révision | Intention `Sync`, puis remplacement par l'instantané complet |
| Entrée client invalide | Rejet serveur (types, bornes, listes, séquence, cadence) |
| Modèle visuel absent | Silhouette grise de secours + avertissement console |
| Départ d'un joueur | Nettoyage via un `scope` Fusion et des connexions par joueur |

## 8. Tests

1. **Lune (hors Studio, TDD)** — `lune run tests` :
   - `Formulas` (le multiplicateur est un paramètre, d'où des cas hors catalogue P0) :
     multiplicateur ×1, puissance 1, maîtrise 0 → 1 ; ×4 (Vega), puissance 1, maîtrise 10 → 6 ;
     facteur d'entraînement au rebirth 20 → 3 ; somme des taux de compagnons × facteur.
   - `Collection` : principale possédée ; exposition ≤ 3, découvertes, sans multiplicateur ; seuils de
     maîtrise `10 × L²` ; Look02 à maîtrise 1, Look03 à maîtrise 5.
   - `Validators` : chaque intention mal formée est rejetée avec la bonne raison.
   - `StateReducer` : révision ancienne ignorée ; trou détecté.
2. **Play dans Studio via le MCP** : HUD présent ; `Train` → puissance +1 ; production ≈ 0,6/s ;
   deux suiveurs présents ; Book : principale et exposition distinctes ; `DevSetMastery` débloque Look02.
3. **Checklist bêta-testeur** reprenant les critères d'acceptation, d'abord en émulation téléphone.

## 9. Définition de « terminé »
- Tous les tests Lune passent.
- La vérification Play passe.
- La checklist bêta est remise.
- `docs/contract.md` décrit le contrat pour le Codeur A (intentions, `ClientProfile`, raisons, attributs publics).

## 10. Points ouverts
- **Partage de la place entre les deux codeurs** : la carte vit dans le fichier `.rbxl` ; choisir entre
  Team Create et un `.rbxl` versionné avant que le Codeur A commence.
- **Animations** : IDs d'idle et de marche des placeholders (animations Roblox par défaut) à confirmer.
- **Version de Blender** : la 5.4 Alpha installée est à remplacer par une version stable avant l'export de Maya.
