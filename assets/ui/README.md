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
