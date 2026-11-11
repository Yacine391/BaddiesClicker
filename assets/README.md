# Assets

Registre obligatoire (dossier §20) : une ligne par asset publié ou importé dans le jeu.

| assetId | Nom | Version | Auteur | Licence | Propriétaire | État |
|---|---|---|---|---|---|---|
| — | Maya (3 looks) | — | — | — | — | à produire |
| — | Malik (DJ) | — | — | — | — | à produire |
| — | Personnages en pièces Roblox, rig commun : 9 baddies × 3 looks, 6 compagnons, 3 sbires, TEST_B99 (`visuals/Characters.rbxm`, généré par `visuals/CharactersBuilder.luau`) | 0.2 | équipe (généré) | interne (formes Roblox, aucun mesh importé) | équipe | à valider en Play ; remplaçable par Blender en gardant noms et attaches |
| — | Cherry « Cherry Summer » (`B09_Cherry`), d'après la planche de référence fournie le 11/11 | 0.2 | équipe (généré) | interne ; planche de référence : à inscrire ici avec son auteur et sa licence | équipe | à valider en Play |
| — | Lobby (`world/Lobby.rbxm`), avec la roue du jour (`Lobby.Wheel`) | 0.3 | Codeur B | interne | équipe | blocs et néons, habillage Blender plus tard |

Rappels : noms, logos et bijoux originaux ; pas de marque, de célébrité ni de voix réelle sans droits (§20).
Les références artistiques sont des directions, pas des autorisations de reproduction.

## Personnages : régénérer et prévisualiser

```bash
lune run assets/visuals/export-characters                       # écrit visuals/Characters.rbxm
lune run assets/visuals/export-characters -- --json /tmp/bc     # + un JSON par modèle pour l'aperçu
cd assets/visuals/preview && npm install
node render.mjs /tmp/bc/B09_Cherry_Look01.json ../previews/B09_Cherry_Look01.png "BADDIE — CHERRY SUMMER"
node render.mjs --lineup ../previews/Cast_Look01.png /tmp/bc/B0*_Look01.json /tmp/bc/C0*.json
```

Les planches de `visuals/previews/` sont des aperçus (three.js), pas le rendu Roblox : la référence reste Studio.
