# Images de l'interface (refonte mix A)

Sources SVG maison : `icons/*.svg`, `logo.svg`, `glow.svg`. PNG générés dans `png/` par :

```bash
cd assets/ui/export
npm install
node export.mjs
```

Polices utilisées par le logo (rendu seulement, pas dans le jeu) : `export/fonts/` —
Roboto Condensed Black Italic (SIL Open Font License 1.1, Google), Permanent Marker (Apache License 2.0, Font Diner).

## Upload dans Roblox

1. Creator Hub → **Creations → Development Items → Decals/Images**, **au nom du groupe du jeu** (pas d'un compte perso).
2. Uploader chaque fichier de `png/`.
3. Reporter l'ID (`rbxassetid://…`) ci-dessous, puis dans `src/client/UI/Theme.luau` (`Theme.Icons`, `Theme.Logo`, `Theme.Glow`).

Icônes de trait (blanches) : teintées en jeu par `ImageColor3`. `arm` et `ticket` sont en couleur.
`glow.png` : halo en 9-slice (`SliceCenter` 48, 48, 80, 80).

| Fichier | Usage | assetId |
|---|---|---|
| `png/book.png` | menu Book | `rbxassetid://94716205629835` |
| `png/crew.png` | menu Crew, tutoriel | `rbxassetid://113913955556099` |
| `png/style.png` | menu Style | `rbxassetid://71735145745689` |
| `png/settings.png` | menu Réglages | `rbxassetid://115418148096622` |
| `png/chevron.png` | flèche du menu | `rbxassetid://71242548714789` |
| `png/bolt.png` | bouton principal, production | `rbxassetid://107048971234661` |
| `png/arm.png` | compteur de puissance | `rbxassetid://139685984254923` |
| `png/ticket.png` | compteur de tickets | `rbxassetid://73411537747382` |
| `png/door.png` | carte « Parcours » | `rbxassetid://109053980589787` |
| `png/lock.png` | look verrouillé | `rbxassetid://124733419973837` |
| `png/eye.png` | exposer | `rbxassetid://138818406947967` |
| `png/crown.png` | réservé (classement, titres) | `rbxassetid://76335979670718` |
| `png/logo.png` | logo du HUD | `rbxassetid://104433435199565` |
| `png/glow.png` | halo des panneaux | `rbxassetid://105925253038271` |

## Icônes simulateur (refonte du 11/11)

Sources générées par `export/icons_sim.py` dans `icons-sim/*.svg`, PNG par `node export.mjs icons-sim` (`icons-sim/png/`).
Pleines et en couleur : jamais teintées en jeu. Uploadées au nom de l'utilisateur.

| Fichier | ID |
|---|---|
| `icons-sim/png/book.png` | `rbxassetid://88512135926373` |
| `icons-sim/png/style.png` | `rbxassetid://70535176425536` |
| `icons-sim/png/crew.png` | `rbxassetid://118890991313443` |
| `icons-sim/png/slots.png` | `rbxassetid://98333344524522` |
| `icons-sim/png/bonus.png` | `rbxassetid://113075847922595` |
| `icons-sim/png/settings.png` | `rbxassetid://123042582402960` |
| `icons-sim/png/power.png` | `rbxassetid://104575341948505` |
| `icons-sim/png/ticket.png` | `rbxassetid://110263683634513` |
| `icons-sim/png/companionTicket.png` | `rbxassetid://104613250518186` |
| `icons-sim/png/coin.png` | `rbxassetid://81074390464856` |
| `icons-sim/png/gift.png` | `rbxassetid://83421099312203` |
| `icons-sim/png/lock.png` | `rbxassetid://104027571520849` |
| `icons-sim/png/door.png` | `rbxassetid://72003425824728` |
| `icons-sim/png/crown.png` | `rbxassetid://82780129259484` |

## Icônes 3D (rendus Blender, 11/11)

Scène et modèles : `blender/icon_kit.py` + `blender/icons.py` (une fonction `build_<nom>` par icône), rendus 512 × 512 transparents dans `icons-3d/`.
Remplacent les icônes simulateur plates, sauf `lock` et `door` (toujours `icons-sim`).

| Fichier | ID |
|---|---|
| `icons-3d/book.png` | `rbxassetid://125173625918836` |
| `icons-3d/style.png` | `rbxassetid://101028663402756` |
| `icons-3d/crew.png` | `rbxassetid://98520148403150` |
| `icons-3d/slots.png` | `rbxassetid://70628433746190` |
| `icons-3d/bonus.png` | `rbxassetid://118887008661733` |
| `icons-3d/settings.png` | `rbxassetid://120022267838035` |
| `icons-3d/gift.png` | `rbxassetid://111345075798964` |
| `icons-3d/power.png` | `rbxassetid://128247149260944` |
| `icons-3d/ticket.png` | `rbxassetid://72915798347235` |
| `icons-3d/companionTicket.png` | `rbxassetid://137714168881506` |
| `icons-3d/coin.png` | `rbxassetid://139690753999507` |
| `icons-3d/crown.png` | `rbxassetid://73066508179627` |
