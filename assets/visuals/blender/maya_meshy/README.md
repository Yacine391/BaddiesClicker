# Maya (modèle Meshy en pose A) — chaîne de fabrication

1. **Vues** : 3 images en pose A (face, dos, profil) générées par Higgsfield (`gpt_image_2_5`) à partir du concept
   → `assets/visuals/source/maya_apose_*.png`.
2. **3D** : Higgsfield `multi_image_to_3d` (Meshy), `pose_mode = a-pose`, texturé, ~8 000 triangles
   → `assets/visuals/source/maya_meshy_apose.glb` (30 crédits).
3. **Blender** (`pip install bpy==5.2.2`, Python 3.13), dans l'ordre, avec un dossier de travail `OUT` :
   - `step1_import.py <glb> OUT` : fusion, hauteur 5,5 studs, pieds en z = 0, face vers -Y, rendus.
   - `step2_rig.py OUT` : articulations, bras ramenés à 15° (les animations Roblox partent des bras le long du corps),
     coutures soudées, poids automatiques (chaleur), tête rigide, squelette R15 vertical (`../r15_armature.py`).
   - `step2b_export_faces.py OUT`, puis `regions.py` et `recolor.py` : zones de la texture (veste, t-shirt, cargo, baskets, mains) et textures des
     looks 2 et 3 (recoloration qui garde plis et ombres). Ils lisent `OUT/faces.npy` et `OUT/base_2048.png`
     (exportés depuis `maya_step2.blend` ; dossier choisi par la variable `MAYA_OUT`).
   - `step3_build.py <1|2|3> OUT` : texture 1024 du look, accessoires (look 2 : bandeau ; look 3 : chaîne et
     créoles), découpe en 15 parties R15, export `B01_Maya_LookNN.fbx` (non versionné), rendus.
4. **Studio** : Importer 3D les 3 FBX (rig R15), puis `assets/visuals/studio/apply_contract.luau` dans la barre de
   commande, puis enregistrer `Characters` dans `assets/visuals/Characters.rbxm`.

Rendus de contrôle : `assets/visuals/renders/maya/meshy_look0*.png`, `meshy_pose_test.png` (bras levés, genou plié).
