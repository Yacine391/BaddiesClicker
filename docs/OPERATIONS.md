# Exploitation : maintenance, journal et restauration (codeur A)

Dossier §27 et §36. Ces outils servent **en cas d'incident** sur le jeu publié. Ils ne suppriment jamais un
drop en attente, une découverte ou une baddie.

## 1. Couper une décision en urgence (interrupteurs de maintenance)

Si un bug critique touche les relances, les drops, la renaissance ou les coffres, on coupe la décision
concernée **sans republier**. Les joueurs reçoivent la raison `maintenance` (le HUD grise le bouton grâce à
`snapshot.maintenance`) ; rien n'est modifié dans les profils.

Décisions qu'on peut couper : `Roll`, `AcceptDrop`, `RefuseDrop`, `Rebirth`, `OpenChest`.

**Tous les serveurs** (pris en compte en 60 s au plus) : DataStore `BC_Ops_v1`, clé `maintenance`.
Dans Studio, place publiée ouverte, accès API activé, barre de commande :

```lua
-- couper les relances et la renaissance
game:GetService("DataStoreService"):GetDataStore("BC_Ops_v1"):SetAsync("maintenance", { Roll = true, Rebirth = true })
-- tout rouvrir
game:GetService("DataStoreService"):GetDataStore("BC_Ops_v1"):SetAsync("maintenance", {})
```

(La même clé peut aussi être modifiée depuis le Creator Hub, dans le gestionnaire de Data Stores de l'expérience,
s'il est disponible pour ton compte.) Les tests Studio utilisent `BC_Ops_STUDIO_v1`.

**Un seul serveur, effet immédiat** (tests dans Studio, pendant un Play, barre de commande de l'onglet **Serveur**) :

```lua
game.ServerScriptService:SetAttribute("BC_Maintenance", "Roll,AcceptDrop") -- couper
game.ServerScriptService:SetAttribute("BC_Maintenance", "")                -- rouvrir
```

Le panneau de test (F4) affiche alors « MAINTENANCE : Roll, AcceptDrop coupé(s) ».

## 2. Journal

Sortie serveur (Developer Console → Server, ou journaux de l'expérience) :

| Ligne | Sens |
|---|---|
| `[Mutation] <UserId> Roll <requestId> rév. 12 écrite en 180 ms` | décision durable écrite (durée de la sauvegarde) |
| `[Mutation] <UserId> … NON confirmée après 12000 ms` | écriture incertaine : la décision suivante attendra sa confirmation |
| `[Mutation] <UserId> … ERREUR : …` | exception serveur ; le client renverra le même `requestId` |
| `[Profiles] profil <UserId> corrigé (n) : …` | le chargement a réparé des valeurs impossibles (voir `Rules/ProfileGuard`) |
| `[Profiles] profil <UserId> refusé : …` | schéma plus récent ou migration manquante : joueur expulsé, profil intact |
| `[Maintenance] décisions coupées : …` | un interrupteur vient de changer |

Aucune donnée personnelle autre que l'identifiant Roblox n'est écrite.

## 3. Restaurer un profil

Chaque sauvegarde crée une version DataStore. `src/server/Admin/ProfileAdmin.luau` permet de les lire et
d'en remettre une en place. Le jeu ne l'appelle jamais.

1. Ouvrir la place **publiée** dans Studio, accès API activé, lancer **Play**, choisir l'onglet **Serveur**.
2. Dans la barre de commande :

```lua
local Admin = require(game.ServerScriptService.Server.Admin.ProfileAdmin)
Admin.versions(123456789)              -- 10 dernières versions : date, identifiant, résumé
Admin.show(123456789, "<version>")     -- détail d'une version
Admin.restore(123456789, "<version>")  -- la remet comme profil courant
Admin.show(123456789)                  -- vérifier
```

`123456789` = UserId du joueur. Ajouter `true` en dernier argument pour viser le store Studio
(`BC_Profiles_STUDIO_v1`) au lieu de la production. La restauration ferme la session du joueur s'il est
connecté ; au retour, son profil repasse par les garde-fous. La version remplacée reste dans l'historique.

**À répéter avant la bêta** sur un compte de test (§36 « restauration répétée avec succès ») :
noter la version, faire une relance, restaurer la version notée, vérifier que la relance a disparu.

## 4. Mise à jour du schéma de profil

`Balance.save.schemaVersion` = 4. Pour passer à 5 : écrire `ProfileGuard.migrations[4]`, une fixture
`tests/fixtures/profile_v4_*.luau` et son test, puis augmenter `schemaVersion`. Un serveur plus ancien refuse
un profil plus récent (le joueur est renvoyé vers un autre serveur) : jamais d'écriture d'un ancien schéma
sur des données récentes.
