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
| `png/book.png` | menu Book | |
| `png/crew.png` | menu Crew, tutoriel | |
| `png/style.png` | menu Style | |
| `png/settings.png` | menu Réglages | |
| `png/chevron.png` | flèche du menu | |
| `png/bolt.png` | bouton principal, production | |
| `png/arm.png` | compteur de puissance | |
| `png/ticket.png` | compteur de tickets | |
| `png/door.png` | carte « Parcours » | |
| `png/lock.png` | look verrouillé | |
| `png/eye.png` | exposer | |
| `png/crown.png` | réservé (classement, titres) | |
| `png/logo.png` | logo du HUD | |
| `png/glow.png` | halo des panneaux | |
