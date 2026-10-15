# Baddie Clicker — Refonte visuelle : HUD, fenêtres et lobby (style « mix A »)

**Date :** 15 octobre 2026
**Statut :** validé par prototypes, en attente de relecture
**Rôle :** codeur B (client, carte, intégration)
**Références :** `docs/Baddie_Clicker_Dossier_Unifie.pdf` (§05, §20, §21, §22, §28), `docs/CONTRACT.md` (v3)

## 1. Pourquoi

Le HUD V3 du lot P0 « fait jeu Roblox de base » : éléments trop gros, emojis, bulles. L'utilisateur veut un rendu
**pro et très propre qui reste typiquement Roblox**, au niveau des jeux qui percent en 2025-2026.

Étude faite sur des images de gameplay réelles de Grow a Garden, Steal a Brainrot, Steal an Egg et Pet Simulator 99 :
leurs HUD sont compacts (petits boutons, gros chiffres en bas à gauche, carte de quête en haut, beaucoup d'espace
libre), avec des icônes dessinées et des panneaux sombres nets.

Direction retenue après trois tours de prototypes : **« mix A, dominante cyan »**, qui croise une référence fournie
par l'utilisateur (logo graffiti, compteurs en pastilles, menu large à chevrons, cartes de personnages, gros bouton
central) et l'habillage « Night club » (bleu nuit, néon par catégorie). Prototypes de référence, dans
`.superpowers/brainstorm/1574-1792075760/content/` (non versionnés) : `hud-mix.html` (variante A),
`windows-mixA.html`, `lobby-plan-v2.html`, `lobby-3d-hud-v2.html` (rendu Blender + HUD).

## 2. Périmètre

| Inclus | Exclu (specs suivantes) |
|---|---|
| Système visuel : couleurs, typo, panneaux, boutons, icônes, logo | HUD de combat (ennemis, cercles de danger, PV), remplacement de `Dev/DevCombat*` |
| HUD du lobby refait (mix A), mode compact pour téléphone | Écrans Slots, Relances, Drops, Renaissance, coffres Crew, Classement, Titres |
| Fenêtres Book, Style, Crew, Réglages refaites sur le nouveau gabarit | Kit de décor modélisé dans Blender (façades, palmiers, scène) |
| Annonces : toasts « +1 ticket » et « +1 copie », retrait du toast « nouveau compagnon » (accord avec le codeur A) | Modèles finaux de Maya et Malik |
| Lobby reconstruit selon le nouveau plan, en blocs Roblox + néons, ambiance coucher de soleil | `Workspace.Levels` (arènes, portes) |
| Retrait de la barrière « Niveau 1 : bientôt » (ajustement 2 du codeur A) | |

Les écrans futurs réutiliseront les composants de cette spec : aucun nouveau style n'est à inventer pour eux.

## 3. Système visuel

### 3.1 Couleurs (`Theme.Colors`)
| Jeton | Valeur | Usage |
|---|---|---|
| `Panel` | `#100E1E`, transparence 0,14 | fond des panneaux |
| `PanelLine` | `#A08CFF`, transparence 0,72 | bordure de 2 px des panneaux |
| `Accent` | `#3EE6C8` (cyan menthe) | bouton principal, néon actif, barres de progression, chiffres de production |
| `AccentDeep` | `#13A6B5` | bas du dégradé du bouton principal |
| `Accent2` | `#FF5FD2` (rose) | badge NEW, début des dégradés de progression |
| `Ink` | `#0D0B16` | texte sur fond clair, contours |
| `Text` / `TextDim` | `#FFFFFF` / `#CFCAE6` | textes |
| `Book` / `Crew` / `Style` / `Settings` | `#3EE6C8` / `#B48CF0` / `#FF5FD2` / `#CFCAE6` | couleur d'icône et de néon par menu |
| `Close` | `#E0233F` | croix de fermeture |
| `Principal` | `#33B84A` | puce « PRINCIPALE » |
| Raretés | `Catalog.rarities[*].color` | puces de rareté (pas de couleur en dur) |

### 3.2 Typographie
- Interface : `Font.fromName("RobotoCondensed")` en `Bold` (libellés), `ExtraBold` (titres de ligne), `Heavy`/`Black`
  (chiffres et titres de fenêtre), en capitales pour les titres.
- Logo : image (voir 3.5), jamais une police.
- Pas de contour épais sur le texte : la lisibilité vient du fond sombre des panneaux. Seuls les gros chiffres
  posés hors panneau (« +1 », « +0,6 ») ont un `UIStroke` fin (2 px, `Ink`).

### 3.3 Formes et effets (faisables dans Roblox)
- Panneau : `Frame` `Panel` + `UICorner` 10 px + `UIStroke` 2 px `PanelLine`.
- Panneau actif ou mis en avant : `UIStroke` de la couleur de catégorie + **halo** (ImageLabel 9-slice d'une lueur
  douce, derrière le panneau, teintée par `ImageColor3`). Roblox n'a pas d'ombre portée native : le halo est une image.
- Bouton principal : contour 3 px en dégradé `Accent2 → Accent` (UIGradient sur UIStroke), remplissage dégradé vertical
  `#5FF3DA → Accent`, reflet haut (Frame blanche 45 % de transparence), enfoncement au clic (spring, déjà en place).
- Croix : carré 42 px `Close`, coins 10 px, « X » en `RobotoCondensed Black`.
- Pas d'emoji nulle part.

### 3.4 Icônes
- Jeu d'icônes maison en SVG (style trait 2,4 px pour les menus, style plein dégradé pour puissance et tickets), versionné
  dans `assets/ui/icons/*.svg` : `book`, `crew`, `style`, `settings`, `chevron`, `bolt`, `arm`, `ticket`, `door`, `lock`,
  `eye`, `crown`.
- Export en PNG 256 × 256 (`assets/ui/icons/png/`), puis **upload par l'utilisateur** dans Roblox (Asset Manager, au nom
  du groupe du jeu). Les IDs vont dans `Theme.Icons`.
- Icônes de trait : PNG blanc, teinté en jeu par `ImageColor3` (une seule image par icône). Icônes pleines : PNG en
  couleur.
- Tant qu'un ID manque : repli sur une forme simple dessinée en `Frame` (jamais d'emoji).

### 3.5 Logo
- « BADDIE » en capitales italiques très grasses, blanc à contour sombre, et « Clicker » en script graffiti cyan lumineux,
  incliné de −6° : exporté en PNG transparent 1024 px (`assets/ui/logo.png`), uploadé comme les icônes.
- Affiché en haut à gauche du HUD, sous les boutons Roblox. Hauteur 120 px à l'échelle de référence.

## 4. HUD du lobby

Référence : `hud-mix.html`, variante A. Base 1280 × 720, mis à l'échelle comme aujourd'hui (`UIScale` sur
l'`AbsoluteSize` du `ScreenGui`, `ScreenInsets`).

| Zone | Contenu |
|---|---|
| Haut gauche | Logo (3.5) |
| Haut droite | Deux pastilles : **puissance** (icône bras, `Format.number`, contour `Accent` + halo, « pop » à l'entraînement) et **tickets baddie** (icône ticket). Aucun bouton « + » : pas de monétisation en V1 |
| Gauche | Menu vertical de 4 lignes 236 × 54 : icône de trait teintée, libellé, chevron. Ligne survolée ou dernière ouverte : bordure et barre gauche de sa couleur + halo. Badge « NEW » rose si une découverte n'a pas été vue (Book) |
| Droite | Cartes 150 px : **principale** (rareté, nom, « ×m dégâts », « Principale · Slot n », bordure de la couleur du look) puis jusqu'à 2 **compagnons** (rareté, nom, « +x / s », « rôle · Niv. n ») |
| Bas gauche | Carte de progression 290 × 62 : tutoriel « MALIK ARRIVE n/10 » tant que `tutorial.crewUnlocked` est faux ; ensuite « PARCOURS n/10 » avec n = `#snapshot.clearedLevels` (icône porte, barre n/10) ; masquée si le snapshot n'a pas `clearedLevels` |
| Bas centre | Bouton principal 300 × 76 « ENTRAÎNER » (icône éclair) ; en combat « ATTAQUER » (même gabarit, remplissage rose) via `PrimaryAction`. Étiquette « +1 puissance » qui monte au-dessus à chaque entraînement |

**Mode compact** (téléphone) : quand l'échelle est inférieure à 0,6, le menu passe en tuiles carrées d'icônes (grille
2 × 2, libellé sous l'icône) et les cartes de droite se réduisent à leur bandeau (nom + taux). Toutes les cibles restent
≥ 48 px réels (`TouchSize`). La règle de bascule vit dans un module pur testé.

Le comportement P0 est conservé tel quel : chiffres venant du snapshot, aucun `Train` fenêtre ouverte, maintien du clic,
`PrimaryAction`, tutoriel, `HudModel`.

## 5. Fenêtres

Gabarit commun (`Window`) : panneau 820 × 500, bordure `Accent` 2 px + halo, en-tête de 62 px (icône de trait, titre
en capitales `Black` 28 px, onglets en pastilles, croix carrée à droite), corps, fond du jeu assombri à 62 %.
Le fond bloque toujours les clics vers le jeu.

| Fenêtre | Contenu (référence `windows-mixA.html`) |
|---|---|
| **Book** | Onglets BADDIES n/8 et CREW n/6. Gauche : grille 4 colonnes de cartes 150 px (rareté, silhouette ou portrait, nom, puce de statut : `PRINCIPALE · S1` verte, `EXPOSÉE` cyan, ou chance « 25 % » pour une identité non découverte « ??? »). Droite : fiche 250 px de la carte sélectionnée (grand portrait, nom, puces, multiplicateur, maîtrise avec barre, looks n/3, boutons « VOIR LES LOOKS » et « EXPOSER/RETIRER »). Bas : barre de collection |
| **Style** | Onglets LOOKS, AURA, TITRE (AURA et TITRE affichent ce que le contrat v3 fournit ; sinon onglet absent). Gauche : aperçu grand format de la principale sur un socle néon. Droite : 3 lignes de looks (porté : puce cyan ; débloqué : bouton « PORTER » ; verrouillé : cadenas + « MAÎTRISE n ») |
| **Crew** | Liste des compagnons possédés en lignes : portrait, nom, rôle, « +x / s », niveau, copies ; équipés marqués |
| **Réglages** | Lignes à interrupteur (effets réduits, suiveurs des autres, maintien du clic) |

Les portraits restent des silhouettes colorées tant que les rendus Blender des personnages n'existent pas.

## 6. Annonces (accord avec le codeur A, `docs/CONTRACT.md` « Effets RGB »)

- `crewJoined` avec `isNew = true` : **plus de toast** côté HUD (bannière RGB du `CelebrationController`).
- `crewJoined` avec `isNew = false` : toast « +1 copie : {Nom} ».
- `ticket` : toast « +{n} ticket baddie / compagnon ».
- Nouveau style de toast : panneau `Panel` + bordure `Accent`, icône, texte `ExtraBold`, glisse depuis le haut.

## 7. Lobby

### 7.1 Plan (référence `lobby-plan-v2.html`)
Place d'environ 90 × 70 studs, sol continu, aucun saut imposé. Repère Roblox : nord = −Z.

| Zone | Position | Contenu |
|---|---|---|
| Spawn | sud, dans l'axe | `SpawnLocation` face au nord |
| Allée + couronne | centre | allée plus claire, couronne graffiti en néon cyan au sol |
| Sortie | nord, axe | arche violette, enseigne « VERS LE NIVEAU 1 », rue vers `Workspace.Levels.Level1` (**barrière retirée**) |
| Street Gym | ouest | barres, disques, bancs, mannequins, cadre néon violet, enseigne |
| La Scène | est | `Podium.Stand` doré avec anneau néon cyan, écran LED du look porté, projecteurs, cabine DJ |
| Classement | nord-ouest | écran LED (prototype tant que le classement n'est pas branché à l'écran) |
| Vitrine Style | nord-est | vitrine néon rose avec mannequins (prototype jusqu'à son écran) |
| Décor | bords | palmiers, bancs, lampadaires néon, demi-terrain de basket, murs bas tagués à liseré cyan, ville et voie surélevée au loin |

Les noms utilisés par le code restent : `Workspace.Lobby`, `Lobby.Podium.Stand`, `Lobby.Spawn`.

### 7.2 Construction
- Construit dans Studio via le MCP, en blocs Roblox et pièces `Neon`, puis exporté vers `assets/world/Lobby.rbxm`
  (remplace la greybox P0, même mapping Rojo).
- Enseignes et écrans : `SurfaceGui` (police `RobotoCondensed`), sans `ClickDetector` ni `ProximityPrompt`.
- La ville et la voie surélevée sont du décor lointain, sans collision.
- Le concept Blender (`lobby_concept.blend`, rendu `lobby-3d-hud-v2.html`) sert de référence de cadrage et de couleurs ;
  il n'est pas importé tel quel.

### 7.3 Ambiance (`Controllers/Ambience.luau`, côté client)
Coucher de soleil appliqué localement au démarrage : `Lighting.ClockTime` ≈ 18,2, `Atmosphere` violet-orangé,
`Sky` sans nuages lourds, `BloomEffect` doux (pour faire briller les néons), `ColorCorrectionEffect` légèrement saturé.
« Effets réduits » coupe le bloom. Rien n'est modifié côté serveur ni dans un fichier partagé.

## 8. Contraintes de collaboration
- Fichiers touchés : uniquement `src/client/` (hors `StateController`, `CelebrationController`, `DoorController`,
  `Dev/*`), `assets/`, `tests/client/`, `docs/`.
- `CONTRACT.md` n'est pas modifié. `docs/proposals/2026-10-14-contract-v2-collection.md` est marqué « implémenté dans v3 ».

## 9. Tests et vérification
- **Lune** (`lune run tests/client/run`) : règle du mode compact (échelle → mode), textes de la carte de progression et
  des toasts (`HudModel` étendu), libellé et couleur du bouton selon `PrimaryAction`.
- **Play dans Studio via le MCP** : captures du HUD, du Book, du Style et du lobby depuis le spawn, comparées aux
  prototypes ; parcours P0 inchangé (entraînement, Malik, fenêtres, maintien, effets réduits) ; échelle 0,42 →
  mode compact et cibles ≥ 48 px.
- **Non-régression** : `lune run tests/run`, `lune run tests/client/run`, `selene src` sans erreur.

## 10. Définition de « terminé »
- HUD, fenêtres et lobby correspondent aux prototypes validés (captures jointes à la PR).
- Plus aucun emoji ni élément du style V3 dans le client.
- Tous les tests passent ; parcours P0 vérifié en jeu ; mode compact vérifié.
- PR `b/ui-refonte` ouverte vers `main`, avec la liste des assets à uploader et leurs IDs renseignés.

## 11. Points ouverts
- **Upload des images** (icônes, logo, halo) : fait par l'utilisateur dans Roblox, au nom du groupe du jeu.
  Tant qu'un ID manque, les replis en formes simples s'affichent.
- **Export des SVG en PNG** : outil à confirmer pendant le plan (script local ou rendu via Blender).
