# Maya dans Blender — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal :** remplacer `B01_Maya/Look01..03` par une Maya modélisée par scripts dans Blender, riggée R15, exportée vers Studio.

**Architecture :** des scripts Python relançables (`assets/visuals/blender/`) reconstruisent la scène de zéro via le MCP
Blender ; une texture-palette par look ; un squelette R15 skinné ; un FBX par look importé dans Studio par l'utilisateur,
puis mis au contrat par un script Luau exécuté via le MCP Studio.

**Tech Stack :** Blender 5.2.2 LTS (bpy), FBX, Roblox Studio (Importer 3D, MCP), Luau.

**Spec :** `docs/superpowers/specs/2026-10-18-maya-blender-design.md`

## Global Constraints

- Unité : 1 unité Blender = 1 stud ; hauteur totale 5,5 ± 0,3 ; pieds à Z = 0 ; Maya face à −Y.
- ≤ 10 000 triangles par look (tous objets exportés confondus) ; une texture-palette de 256 px par look.
- Palette exacte : denim #3B5B8C, crème #F4EEE7, orange #F2A65A, nuit #242036, or #D7A746 ; peau, cheveux, yeux libres.
- Parties R15 exactes : `Head`, `UpperTorso`, `LowerTorso`, `LeftUpperArm`, `LeftLowerArm`, `LeftHand`, `RightUpperArm`,
  `RightLowerArm`, `RightHand`, `LeftUpperLeg`, `LeftLowerLeg`, `LeftFoot`, `RightUpperLeg`, `RightLowerLeg`, `RightFoot`.
- Squelette : `Root` → `HumanoidRootNode` → `LowerTorso` → (`UpperTorso` → `Head`, bras) et (jambes) ; un os par partie,
  même nom que la partie.
- Contrat Studio : `HumanoidRootPart` (PrimaryPart, 2×2×1), `AnimationController` + `Animator`, pas de `Humanoid`,
  `AuraAttachment` dans `UpperTorso` (0,0,0), `NameTagAttachment` dans `Head` (0, ≈1,4, 0).
- Aucune marque, pas de sexualisation, adulte stylisée. Messages et commentaires en français.
- Chaque script reconstruit sa partie de zéro (idempotent) ; aucun script ne sauvegarde par-dessus un `.blend` existant sans le nommer.

## Review Focus

1. Épaules et hanches pendant la marche : pas de déchirure ni d'écrasement (pose de test, Task 4).
2. Boucles de cheveux et poches disjointes : liées rigidement à un seul os, jamais à moitié (check Task 4).
3. Import Studio qui renomme les pièces (suffixes, fusion) : `conform.luau` les renomme ou échoue clairement (Task 6).
4. Looks 2 et 3 lisibles de loin : rendus des 3 looks côte à côte à petite taille (Task 5).
5. Échelle FBX → Studio fausse (×100 ou ×0,01) : `check-characters.luau` refuse une hauteur hors 5,5 ± 0,3 (Task 6).

---

## Fichiers

| Fichier | Rôle |
|---|---|
| `assets/visuals/blender/bc_common.py` | `reset_scene()`, `material(name, hex)`, `add_obj(...)`, `join(objs, name)`, `tri_count(objs)` |
| `assets/visuals/blender/palette.py` | `PALETTES = { "Look01": {...}, "Look02": {...}, "Look03": {...} }`, `apply_palette(look)` |
| `assets/visuals/blender/maya_body.py` | `build_body() -> list[Object]` : corps, mains, tête, visage, cheveux |
| `assets/visuals/blender/maya_outfit.py` | `build_outfit(look) -> list[Object]` : vêtements, baskets, accessoires du look |
| `assets/visuals/blender/r15_armature.py` | `build_armature() -> Object`, `skin(objs, arm)`, `split_parts(objs, arm) -> dict[str, Object]`, `test_pose(arm)` |
| `assets/visuals/blender/export_fbx.py` | `export_look(look, out_dir)` |
| `assets/visuals/blender/render_views.py` | `render_views(tag, out_dir)` : face, profil, dos (PNG 768 px) |
| `assets/visuals/blender/checks.py` | vérifications appelées en fin de tâche (assertions, messages en français) |
| `assets/visuals/studio/conform.luau` | met les 3 modèles importés au contrat |
| `assets/visuals/studio/check-characters.luau` | vérifie le contrat (exécuté via MCP Studio) |
| `assets/visuals/renders/maya/*.png` | rendus de validation |

Les scripts sont exécutés via `execute_blender_code` : `exec(open(path).read())` après ajout du dossier au `sys.path`.

### Task 1 : socle (commun, palette, vérifications)

- [ ] Écrire `checks.check_palette()` : 3 looks, mêmes clés de matériau, valeurs hex exactes de la spec §4
  (ex. `PALETTES["Look01"]["jacket"] == "#3B5B8C"`, `PALETTES["Look03"]["piping"] == "#D7A746"`).
- [ ] L'exécuter dans Blender → échec (`palette.py` absent).
- [ ] Écrire `bc_common.py`, `palette.py` (matériaux : skin, hair, eye, brow, lip, tshirt, jacket, panel, piping,
  pants, shoe_main, shoe_sole, shoe_accent, bracelet, headband, gold) ; `.gitignore` : `assets/visuals/**/*.blend`,
  `assets/visuals/**/*.fbx`.
- [ ] `check_palette()` → OK. Commit `feat(visuals): Blender scaffolding and Maya palettes`.

### Task 2 : corps, visage, cheveux

- [ ] `checks.check_body(objs)` : hauteur 5,5 ± 0,3 (sans les baskets : ≥ 5,0), pieds à Z = 0 ± 0,05, symétrie X ± 0,05,
  ≤ 5 000 triangles.
- [ ] Construire `maya_body.py` (proportions du concept : tête ≈ 1/4,5 de la hauteur, chevelure ≈ 1,6 × la largeur de
  la tête), lancer `check_body` → OK.
- [ ] `render_views("body")` ; montrer les rendus à côté du concept ; **attendre la validation de l'utilisateur**.
- [ ] Commit `feat(visuals): Maya body, face and hair`.

### Task 3 : tenue du look 1

- [ ] `checks.check_outfit(objs)` : total ≤ 10 000 triangles, aucun objet sous Z = 0, chaque matériau de la palette du
  look présent.
- [ ] Construire `maya_outfit.py` (look 1) → `check_outfit` OK → `render_views("look01")` ; **validation utilisateur**.
- [ ] Commit `feat(visuals): Maya Street Start outfit`.

### Task 4 : rig R15

- [ ] `checks.check_rig(arm, parts)` : 17 os aux noms exacts (Root, HumanoidRootNode + 15) ; 15 objets-parties aux noms
  exacts ; chaque sommet a un poids total 1 ± 0,01 ; sommets de `Head` à 100 % sur l'os `Head`.
- [ ] `r15_armature.py` : os placés aux articulations du corps (Task 2) ; poids automatiques puis pièces disjointes
  (boucles, poches, bijoux) liées à 100 % à l'os le plus proche ; découpe en 15 parties par os dominant.
- [ ] `check_rig` OK ; `test_pose` (bras levés 80°, genou plié 60°) → `render_views("pose")` sans déchirure visible.
- [ ] Commit `feat(visuals): Maya R15 rig`.

### Task 5 : looks 2 et 3, export

- [ ] `checks.check_export(path)` : le FBX existe, ≤ 10 000 triangles relus après réimport, 15 parties + armature.
- [ ] `build_outfit("Look02")` (bandeau, bracelet) et `("Look03")` (chaîne, créoles) ; `apply_palette` ;
  `export_fbx.py` → `B01_Maya_Look01..03.fbx` dans `assets/visuals/export/` (ignoré par Git).
- [ ] `render_views` des 3 looks + une planche côte à côte en petit ; **validation utilisateur**.
- [ ] Commit `feat(visuals): Maya Street Match and Street Signature, FBX export`.

### Task 6 : intégration Studio

- [ ] Écrire `check-characters.luau` (contrat global ; hauteur 5,5 ± 0,3) ; l'exécuter sur les placeholders → OK
  (le contrat actuel passe), puis sur un modèle volontairement cassé → échec lisible.
- [ ] **Utilisateur** : Importer 3D les 3 FBX (type de rig R15, unité Stud) dans `ReplicatedStorage.Visuals.Characters`.
- [ ] `conform.luau` : noms `B01_Maya/Look0N`, `HumanoidRootPart` PrimaryPart, `AnimationController` + `Animator`,
  attachments, suppression du `Humanoid` ; anciens placeholders retirés. `check-characters.luau` → OK.
- [ ] Play : podium (3 looks), suiveur (idle et marche), boss du niveau 1 ; console sans erreur.
- [ ] **Utilisateur** : clic droit `Characters` → Enregistrer dans un fichier → `assets/visuals/Characters.rbxm`.
- [ ] Commit `feat(visuals): Maya replaces the placeholders` ; demander l'accord pour pousser et ouvrir la PR.
