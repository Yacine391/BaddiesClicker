# Baddie Clicker — Refonte « simulateur vif » : HUD, menus et lobby de nuit

**Date :** 11 novembre 2026
**Statut :** design validé à l'oral, spec en attente de relecture
**Rôle :** codeur B (client, carte, intégration)
**Branche :** `b/ui-simulateur`, tirée de `claude/keen-carson-ptlo48` (pièces, roue, connexion, temps de jeu, Cherry)
**Remplace :** la direction visuelle « mix A » de `2026-10-15-ui-lobby-refonte-design.md` (§3 à §7). Les règles
fonctionnelles de cette spec (cibles tactiles, zones sûres, mode compact, aucune donnée inventée) restent valables.

## 1. Pourquoi

L'utilisateur a fourni 5 captures de simulateurs Roblox à succès (HUD à tuiles illustrées, compteurs empilés, Index
en grille de silhouettes « ??? », magasin à bandeau coloré) et a décidé le 11/11 : **on fait comme les exemples**.
La règle précédente « éviter les gros boutons colorés et les contours épais » est **annulée**.

Garde-fous :
- On reprend les **codes du genre** (disposition, tuiles, contours, couleurs franches), jamais le look d'un jeu
  précis : icônes, logo, palette et décor sont dessinés pour Baddie Clicker.
- **Aucun encart payant** (x2, packs, œufs, passe de saison, minuteur d'offre). Seule exception : le tour de roue
  payant déjà décidé (`Config/ProductsConfig`), affiché uniquement dans la fenêtre Bonus.
- Aucune donnée fictive : tout chiffre affiché vient du snapshot (`HudModel`, `BookModel`, `RewardsModel`…).

## 2. Périmètre et lots

| Lot | Contenu | Validation |
|---|---|---|
| 1 | Système visuel (§3), composants refaits, HUD du lobby (§4), fenêtre Book (§5.1) | Captures Play ordinateur + mobile |
| 2 | Style, Crew, Équipe (Slots), Bonus, Réglages (+ effets réduits), Décisions (drops), HUD de combat, toasts | Captures Play de chaque écran |
| 3 | Lobby de nuit (§6) : blockout `LobbyBuilder`, vérifié en jeu, puis 3 assets Blender, export `Lobby.rbxm` | Captures spawn, allée, chaque zone |
| 4 | Baddies qui dansent sur la piste du lobby (§7) | Après validation des modèles finaux |

Exclu : serveur, `src/shared/`, contrat réseau, sauvegarde, économie, règles de combat, `Workspace.Levels`.

## 3. Système visuel (`UI/Theme`)

### 3.1 Couleurs
| Jeton | Valeur | Usage |
|---|---|---|
| `Ink` | `#1A1030` | contours de tuiles, contours de texte, ombres dessinées |
| `Panel` | `#2B1F4A` | fond des fenêtres |
| `PanelInner` | `#3A2C62` | fond des cartes et listes |
| `Text` | `#FFFFFF` | textes |
| `Book` | `#2FA8FF` → `#1B6FE0` | tuile + bandeau Book (dégradé haut → bas) |
| `Style` | `#FF6FC8` → `#E0369E` | Style |
| `Crew` | `#A57CFF` → `#6E44D9` | Crew |
| `Slots` | `#FFC93C` → `#E39A12` | Équipe |
| `Bonus` | `#FF9A3C` → `#F2552C` | Bonus (roue, connexion, temps de jeu) |
| `Settings` | `#8C95B8` → `#5A6386` | Réglages |
| `Action` | `#5BE36A` → `#22A93A` | bouton ENTRAÎNER |
| `Attack` | `#FF5A5A` → `#D42A3A` | bouton ATTAQUER (combat) |
| `Close` | `#F2384A` | croix |
| `Badge` | `#FF2E4D` | pastille « ! » |
| Raretés | `Catalog.rarities[*].color` | cadres de cartes (pas de couleur en dur) |

Une couleur par fonction, la même dans le HUD et dans le lobby (§6.3).

### 3.2 Typographie
- `Font.fromEnum(Enum.Font.FredokaOne)` partout (titres, libellés, chiffres).
- Contour `UIStroke` `Ink` : 3 px sur titres, chiffres et libellés de tuiles ; 2 px sur les textes de liste.
- Capitales pour titres de fenêtre et libellés de tuile.

### 3.3 Formes
- **Tuile** : carré, coins 12 px, dégradé vertical de sa couleur, `UIStroke` 3 px `Ink`, « ombre » = Frame `Ink`
  décalée de 4 px vers le bas derrière la tuile, reflet haut (bande blanche à 75 % de transparence sur le tiers haut),
  icône illustrée au centre, libellé en bas qui déborde légèrement du bord.
- **Fenêtre** : fond `Panel`, coins 14 px, contour 4 px `Ink`, **bandeau titre** de la couleur du menu (hauteur 64)
  avec icône + titre à gauche, croix carrée `Close` 52 px à droite collée au bandeau.
- **Carte** (Book, Style, Équipe) : fond `PanelInner`, cadre 3 px de la couleur de rareté, portrait, nom en bas.
- **Pastille « ! »** : rond `Badge` 26 px, contour `Ink`, en haut à droite de la tuile.
- Pas d'emoji. Le halo `Theme.Glow` n'est plus utilisé par défaut.

### 3.4 Icônes
Nouvelles icônes **pleines et colorées** (style illustré du genre, dessin propre à Baddie Clicker), SVG versionnés dans
`assets/ui/icons-sim/*.svg`, PNG 256 × 256 dans `assets/ui/icons-sim/png/`, uploadés au nom de l'utilisateur ; IDs
dans `Theme.Icons`. Liste : `book`, `style`, `crew`, `slots`, `bonus`, `settings`, `power`, `ticket`,
`companionTicket`, `coin`, `gift`, `lock`, `door`, `crown`. Tant qu'un ID manque : repli sur l'ancienne icône de
trait teintée (jamais d'emoji, jamais de trou).

## 4. HUD du lobby (`Controllers/HUD`)

### 4.1 Ordinateur (base 1280 × 720, `UIScale` existant)
- **Colonne gauche** (centrée verticalement, marge 16) : grille 2 × 3 de tuiles 96 × 96 — Book, Style, Crew,
  Équipe, Bonus, Réglages. Pastille « ! » seulement sur une donnée réelle :
  Book = nouvelle découverte non vue ; Équipe = `pendingDrops` non vide ; Bonus = tour gratuit dispo, récompense de
  connexion ou palier de temps de jeu à réclamer ; Crew = compagnon nouveau non vu. Les règles de pastille sont des
  fonctions pures dans `Logic/BadgeModel` (testées).
- **Bas gauche** : compteurs empilés (puissance, tickets baddie, tickets compagnon, pièces), icône 40 px + chiffre
  `FredokaOne` 34, contour 3 px. Le chiffre qui change fait un « pop » (échelle 1,12 → 1, 0,15 s).
- **Bas centre** : bouton ENTRAÎNER (`Action`) 260 × 84 ; au-dessus, barre « Prochain ticket N/250 » et
  « +X/s » du passif. En combat : ATTAQUER (`Attack`), même place (dossier : un clic entraîne OU attaque, jamais les deux).
- **Haut centre** : bannière d'objectif (niveau courant / prochain quartier), une ligne.
- **Haut droite** (sous la zone Roblox) : tuile cadeau avec minuteur du prochain palier de temps de jeu, ouvre Bonus.
- **Droite** : cartes de la principale et des compagnons actifs (`CharacterCard` restylée).
- Centre de l'écran libre.

### 4.2 Mobile (mode compact existant, `LayoutMode`)
- Tuiles 72 px réels minimum (≥ 48 garanti par `Metrics.touch`), grille 2 × 3 conservée.
- Bas droit vide (saut, pavé tactile), haut gauche vide (menu Roblox).
- Cartes réduites au bandeau, bannière d'objectif masquée sous 0,6.
- Aucun survol requis : tout état est visible sans survol.

## 5. Menus

### 5.1 Book (écran représentatif)
- Fenêtre 860 × 520, bandeau `Book`, titre « BOOK ».
- Onglets à droite (colonne de boutons larges) : « Baddies », « Compagnons ».
- Grille de cartes 4 colonnes défilante : découverte = portrait + cadre rareté + nom ; non découverte = silhouette
  noire (portrait en `ImageColor3` `Ink`) + « ??? » ; exposée = puce « EXPOSÉE ».
- Barre de progression en bas : « N/M découvertes » (données `BookModel`).
- Fiche personnage au clic (look, rareté, multiplicateur) dans le même gabarit.

### 5.2 Autres écrans (lot 2)
Même gabarit (bandeau coloré, croix, cartes) pour Style, Crew, Équipe, Bonus, Réglages, Décisions. États lisibles :
sélectionné (cadre blanc 4 px + coche), verrouillé (cadenas + désaturé), indisponible (55 % de transparence,
libellé de raison), actif/principale (puce `Action` « PRINCIPALE »).
HUD de combat : PV joueur et ennemis, bouton ATTAQUER, sans tuiles de menu (les fenêtres se ferment déjà en combat).

### 5.3 Animations
| Interaction | Effet | Durée / courbe |
|---|---|---|
| Survol (souris) | échelle 1,04 | 0,08 s Quad Out |
| Pression | échelle 0,92 puis ressort | spring existant |
| Ouverture fenêtre | échelle 0,9 → 1 + fondu | 0,15 s Back Out |
| Fermeture | échelle → 0,95 + fondu | 0,08 s Quad In |
| Jauge | remplissage | 0,25 s Quad Out |
| Gain | « +N » près du bouton (pool existant `FloatingNumber`, plafonné) | 0,6 s |
| Déblocage | carte qui grossit au centre, se range seule | 1,2 s, non bloquant |

Toutes les animations sont interruptibles (un tween remplace le précédent), aucun empilement au clic rapide.
« Effets réduits » (Réglages) : pas d'échelle ni de rebond, fondus seuls, pas de « +N ».

## 6. Lobby de nuit (`assets/world/LobbyBuilder.luau`)

### 6.1 Contraintes conservées
- Sol 90 × 70 centré sur l'origine ; spawn (0, 0,6, 25) face au nord ; arche à Z = −35,5 ; rue jusqu'à Z = −78,5,
  rien au-delà.
- Noms utilisés par le code inchangés : `Lobby.Spawn`, `Lobby.Podium.Stand` (28, 2, −4), `Lobby.Wheel.Rotor`
  (PrimaryPart `Disc`, axe X), tableaux Classement et Style lus par `Leaderboard` / `Style`.
- Aucun ClickDetector, ProximityPrompt ni barrière ; éléments statiques ancrés ; décor lointain sans collision.
- Source de vérité : `LobbyBuilder` → export `Lobby.rbxm` (jamais de retouche à la main dans Studio).

### 6.2 Ambiance (`Controllers/Ambience`)
- Nuit : `ClockTime` 0, ciel bleu nuit / violet, lune visible, étoiles.
- Lisibilité de simulateur : `Ambient` et `OutdoorAmbient` clairs (bleu-violet), les couleurs des zones restent
  franches sans éclairage.
- Ombres : lune seulement. Lumières : guirlandes et néons en `Neon` sans `PointLight`, sauf 4 `SurfaceLight`
  maximum (porte, scène).
- Effets réduits : bloom coupé (comportement actuel conservé).

### 6.3 Composition
| Zone | Couleur (§3.1) | Place |
|---|---|---|
| Porte NIVEAU 1 | cyan lumineux | bout de l'allée (nord) — **point focal**, plus haute que tout |
| Salle d'entraînement | `Bonus` orange | ouest |
| La Scène (Maya, Malik) + piste de danse | `Style`/`Crew` violet-rose | est |
| Roue du jour | `Slots` jaune | à droite du spawn |
| Classement | `Book` bleu | nord-ouest |
| Vitrine Style | `Style` rose | nord-est |

- Allée neutre (pierre claire, liseré lumineux) du spawn jusqu'à la porte, dégagée.
- **Piste de danse** réservée devant la scène (≈ 16 × 12, dalles lumineuses), vide au lot 3, occupée au lot 4.
- Volumes francs aux bords épais, estrades d'une marche au plus, murets colorés, herbe et arbres stylisés en
  périphérie, guirlandes au-dessus des zones.
- 4 titres flottants maximum (BillboardGui `FredokaOne`, contour 3 px) : « ENTRAÎNE-TOI », « LA SCÈNE »,
  « ROUE DU JOUR », « NIVEAU 1 ».
- La roue et le podium existants sont **rhabillés sur place**, jamais retirés.

### 6.4 Blender (après validation du blockout)
3 assets : arche NIVEAU 1, auvent de la scène, jeu de 3 arbres. Échelle avatar R15, UV propres, transformations
appliquées, pivot au sol, collisions simples (Box/Hull). Sources dans `assets/world/blender/` (`.blend` et textures
versionnés ; `.blend` ignorés par Git aujourd'hui → on ajoute une exception pour ce dossier). **Limite** : l'import du
mesh dans Studio est fait par l'utilisateur (Importateur 3D) ; tant qu'il manque, le blockout en Parts reste en place.

## 7. Lot 4 : baddies qui dansent (après)
Sur la piste de danse, 5 à 8 baddies du catalogue (`ReplicatedStorage.Visuals.Characters`, contrat R15) jouent des
animations de danse en boucle, côté client, via un seul contrôleur (pas de script par personnage). Prérequis : modèles
finaux validés (Maya d'abord) et IDs de danse choisis par l'utilisateur. Spec dédiée le moment venu.

## 8. Tests et validation
- `lune run tests/run` : nouveaux tests purs pour `BadgeModel` (pastilles) et la grille Book (découvert / « ??? » /
  exposé) ; tests existants verts.
- `stylua src tests`, `selene src` propres.
- En Play (place locale uniquement, jamais le jeu publié) : vue du spawn, allée, chaque zone ; HUD ordinateur et mobile
  (émulation 375 × 812) ; ouverture/fermeture répétée de chaque fenêtre ; clics rapides pendant une animation ;
  effets réduits ; pas de texte coupé ni de chevauchement. Captures jointes à la PR.
- On n'affirme rien de non vérifié : ce qui n'a pas pu être testé est listé dans la PR.
