# Maya dans Blender — design

**Date :** 2026-10-18 · **Codeur :** B · **Lot :** P0 · **Branche :** `b/maya`
**Référence visuelle :** concept « MAYA · STREET START » fourni par l'utilisateur (face, dos, portrait, palette).

## 1. But et critère de réussite

Remplacer les placeholders `B01_Maya/Look01..03` par une vraie Maya, modélisée **par scripts Python dans Blender**
(MCP Blender), riggée en **R15** et animée par les animations standard de Roblox. Gratuit, sans générateur externe.

Réussite (acceptation P0, §02) : le bêta-testeur **reconnaît les 3 looks de Maya sans explication** (podium, suiveur,
boss) ; les animations idle/marche la déforment proprement ; ≤ 10 000 triangles par look.

Hors périmètre : Malik et les autres baddies (même chaîne réutilisée ensuite), animations sur mesure, visage peint.

## 2. Contrat à respecter (inchangé, déjà consommé par le code)

`ReplicatedStorage.Visuals.Characters.B01_Maya.Look01..Look03`, chaque modèle :
- `HumanoidRootPart` (Part 2×2×1, PrimaryPart) + les 15 MeshParts R15 (`Head`, `UpperTorso`, `LowerTorso`,
  `Left/RightUpperArm`, `Left/RightLowerArm`, `Left/RightHand`, `Left/RightUpperLeg`, `Left/RightLowerLeg`,
  `Left/RightFoot`) reliées par les Motor6D R15 standard ;
- `AnimationController` + `Animator`, **aucun `Humanoid`** ;
- `AuraAttachment` dans `UpperTorso` (0, 0, 0), `NameTagAttachment` dans `Head` (0, ≈1,4, 0) ;
- hauteur totale ≈ 5,5 studs (comme le placeholder), pieds au niveau du bas de la boîte.

Consommateurs : `Podium` (rotation des looks), `Followers` (idle `507766666`, marche `507777826`), `Combat` (boss).
Aucun changement de code client n'est prévu.

## 3. Style et construction

Silhouette du concept : adulte stylisée, tête et chevelure volumineuses, veste oversize, cargo large, baskets épaisses.
Rendu « low-poly lissé » à formes propres (pas le niveau de détail du concept). Pas de sexualisation, aucune marque.

Scripts dans `assets/visuals/blender/` (relançables, une scène reconstruite de zéro à chaque exécution) :

| Script | Rôle |
|---|---|
| `maya_body.py` | corps, mains, visage en relief (yeux, sourcils, bouche), cheveux en grappes de boucles fusionnées |
| `maya_outfit.py` | t-shirt, veste (empiècements, passepoils), cargo à poches, baskets, bracelet ; accessoires des looks 2–3 |
| `palette.py` | texture-palette 256 px (cases de couleur) ; chaque matériau pointe vers sa case ; une palette par look |
| `r15_armature.py` | squelette aux noms et à la hiérarchie R15 ; tête et cheveux liés à 100 % à `Head`, le reste en poids automatiques corrigés aux épaules et hanches |
| `export_fbx.py` | un FBX par look (`B01_Maya_Look01..03.fbx`), échelle Roblox, ≤ 10 000 triangles |
| `render_views.py` | rendus face / profil / dos (PNG) pour la validation |

Une seule texture par look (la palette) : léger, net dans Roblox, et changer de look = surtout changer de palette.

## 4. Les trois looks (même corps, même visage)

| Look | Déblocage | Haut | Bas | Baskets | Ajout |
|---|---|---|---|---|---|
| 1 · Street Start | maîtrise 0 | veste denim #3B5B8C, empiècements crème #F4EEE7, passepoils orange #F2A65A, t-shirt crème | cargo crème | crème / marine / orange | bracelet orange |
| 2 · Street Match | maîtrise 1 | veste crème, empiècements orange, t-shirt crème | cargo denim | orange / crème | bandeau orange, bracelet assorti |
| 3 · Street Signature | maîtrise 5 | veste nuit #242036, passepoils or #D7A746, t-shirt orange | cargo nuit | nuit / or | chaîne dorée, créoles géométriques dorées |

Lecture de loin : 1 = foncé en haut / clair en bas ; 2 = l'inverse ; 3 = sombre et doré.

## 5. Répartition du travail

- **Claude (MCP Blender + MCP Studio)** : scripts, rendus, export FBX ; après l'import, mise au contrat dans Studio
  (noms, `AnimationController`/`Animator`, attachments, suppression du `Humanoid`), vérification en Play.
- **Utilisateur** : valider les rendus à chaque étape ; dans Studio, **Importer 3D** les 3 FBX (type de rig R15) — l'outil
  d'import ne se pilote pas par MCP ; puis clic droit sur `Characters` → **Enregistrer dans un fichier** →
  `assets/visuals/Characters.rbxm`.

## 6. Validation

1. Après le corps, après la tenue, après le rig : rendus face / profil / dos montrés à côté du concept ; l'utilisateur
   valide le look 1 avant les looks 2 et 3.
2. Pose de test dans Blender : bras levés, jambe pliée — pas de déchirure aux épaules, coudes, hanches, genoux.
3. Studio, Play : podium (3 looks qui tournent, étiquettes justes), suiveur (idle et marche animés), boss du niveau 1.
4. Compte de triangles ≤ 10 000 par look (script `export_fbx.py` refuse au-delà).
5. Contrat vérifié par un script Luau exécuté dans Studio (MCP) : noms des 15 parties, Motor6D, attachments,
   pas de `Humanoid`, hauteur 5,5 ± 0,3 studs. (Lune 0.10.4 ne lit pas `Characters.rbxm` — bug `Tags SharedString`.)

## 7. Git

Versionnés : scripts `assets/visuals/blender/*.py`, rendus de validation (`assets/visuals/renders/maya/*.png`, petits),
`Characters.rbxm` final. Non versionnés (`.gitignore`) : `.blend` de travail et FBX intermédiaires (régénérables).
Les MeshParts importées référencent des assets uploadés au nom de l'utilisateur (comme les images UI).

## 8. Risques

- Rendu jugé trop simple face au concept : on itère sur les rendus avant le rig ; le style « formes propres » est assumé.
- Poids automatiques ratés sur des pièces disjointes (boucles, poches) : liaison rigide de ces pièces à l'os le plus proche.
- Import Studio qui renomme ou fusionne des pièces : l'étape de mise au contrat (§5) corrige les noms ; le script de
  vérification (§6.5) bloque si le contrat n'est pas tenu.
