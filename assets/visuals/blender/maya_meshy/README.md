# Maya (modèle Meshy en pose A) — chaîne de fabrication

Version 2 (22/10) : style de la planche choisie par Yacine (cheveux longs ondulés, maquillage glam, mains façon
Roblox), crop top à col montant, proportions naturelles, baskets sans logo (pas de sexualisation, aucune marque).

1. **Vues** : 3 images en pose A (face, dos, profil) générées par Higgsfield (`gpt_image_2_5`) à partir de la planche
   → `assets/visuals/source/maya_apose_*.png`.
2. **3D** : Higgsfield `multi_image_to_3d` (Meshy), `pose_mode = a-pose`, texturé, ~8 300 triangles
   → `assets/visuals/source/maya_meshy_apose.glb` (30 crédits).
3. **Blender** (`pip install bpy==5.2.2`, Python 3.13), dans l'ordre, avec un dossier de travail `OUT` :
   - `step1_import.py <glb> OUT` : fusion, hauteur 5,5 studs, pieds en z = 0, face vers -Y, rendus.
   - `hairprobe.py OUT` : sommets des cheveux (texture très sombre) → `OUT/hair.npy`.
   - `step2_rig.py OUT` : cheveux rapprochés du dos, coutures soudées, bras ramenés à 18° (les animations Roblox
     partent des bras le long du corps), poids automatiques (chaleur), cheveux et tête rigides sur `Head`,
     squelette R15 vertical (`../r15_armature.py`), rendus dont une pose de test.
   - `step2b_export_faces.py OUT` : texture de base et faces (position, UV, cheveux) pour l'étape suivante.
   - `regions.py OUT` : zones de la texture pixel par pixel (veste, col, manches, t-shirt, ventre, cargo gauche et
     droite, baskets, mains).
   - `recolor.py OUT` : crop top (ventre en peau + nombril) sur les 3 looks ; look 2 (veste crème, épaules orange,
     manches denim, cargo deux tons) et look 3 (nuit et or, crop top orange).
   - `step3_build.py <1|2|3> OUT` : texture 1024 du look, accessoires (look 2 : bandeau orange, créoles losanges et
     fine chaîne dorées ; look 3 : grosse chaîne et créoles dorées), découpe en 15 parties R15,
     export `B01_Maya_LookNN.fbx` (non versionné), rendus.
4. **Studio** : Importer 3D les 3 FBX (rig R15), puis `assets/visuals/studio/apply_contract.luau` dans la barre de
   commande, puis enregistrer `Characters` dans `assets/visuals/Characters.rbxm`.

Rendus de contrôle : `assets/visuals/renders/maya/meshy_look0*.png`, `meshy_pose_test.png` (bras levés, genou plié).
