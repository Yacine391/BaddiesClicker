# Contrat réseau client ↔ serveur (v3, lots P0 + P1 + P2 — snapshot `v = 2`)

Ce fichier est la frontière entre le **codeur A** (serveur) et le **codeur B** (HUD, suiveurs, carte).
Tout changement passe par une PR relue par les deux.

Règle d'or (§25) : **le client envoie des intentions, jamais de montants.** Le serveur recalcule tout
depuis le profil et `Balance`. Une intention invalide, trop rapide ou faite au mauvais moment est
ignorée sans erreur.

## Remotes

Déclarés dans `default.project.json`, ils existent avant tout script : `ReplicatedStorage/Remotes/…`

| Remote | Sens | Appel |
|---|---|---|
| `Intent` | client → serveur | `FireServer(action: string, payload: table?)` |
| `State` | serveur → client | snapshot complet (ci-dessous) |
| `Result` | serveur → client | événement ponctuel `{ kind = ..., ... }` |
| `Combat` | serveur → client | flux de la rencontre en cours `{ t = ..., ... }` (ci-dessous) |

Côté client, **ne pas brancher les remotes à la main** : passer par
`Controllers/StateController` (`onState`, `onResult`, `onCombat`, `send`).

**Vocabulaire :** le **Baddies Book** est la collection des baddies découvertes (§15). Une baddie
peut être découverte (dans le Baddies Book), possédée (dans un slot) ou exposée (visuel seulement).
« Badge Roblox » désigne un succès de plateforme, jamais une baddie.

## Intentions acceptées

| Action | Payload | Limite serveur | Conditions |
|---|---|---|---|
| `Hello` | aucun | 2/s | renvoie le snapshot ; à envoyer au démarrage (fait par StateController) |
| `Train` | aucun | 8/s (rafale 8) | profil chargé, hors combat |
| `Attack` | `{ encounterId: string, targetId: string? }` | 8/s (rafale 8) | rencontre en cours ; cible à portée (25 studs + marge) ; sans `targetId` valide, le serveur prend l'ennemi le plus proche |
| `StartWave` | `{ levelId: number }` | 1/s | rejouer un niveau **terminé**, en étant dans son arène, hors combat |
| `Roll` ⏳ | `{ requestId, slotId, slotRevision }` | 4/s + 2 s entre deux relances | hors combat ; `slotRevision` = révision du slot affichée à la confirmation ; slot non verrouillé ; 1 ticket baddie |
| `AcceptDrop` ⏳ | `{ requestId, baddieId, slotRevision, pendingRevision }` | 4/s | hors combat ; au moins 1 drop de cette baddie ; `slotRevision` = révision du **temporaire** affiché |
| `RefuseDrop` ⏳ | `{ requestId, baddieId, pendingRevision }` | 4/s | à tout moment ; retire **une** unité |
| `Rebirth` ⏳ | `{ requestId, expectedRunId }` | 1/s | hors combat ; niveau 10 terminé dans le parcours `run.id = expectedRunId` |
| `OpenChest` ⏳ | `{ requestId }` | 4/s + 2 s entre deux coffres | hors combat ; 1 ticket compagnon |
| `SetActive` | `{ slotId }` | 4/s | hors combat ; slot rempli. Change seulement la principale, **aucun déplacement** de baddie |
| `SetRollLock` | `{ slotId, locked: boolean }` | 4/s | verrou de relance (le temporaire est quand même vidé au rebirth) |
| `SetDisplay` | `{ ids: { string } }` | 4/s | hors combat ; ≤ 3 IDs connus, **découverts**, sans doublon ; remplace toute la liste |
| `SetLook` | `{ baddieId, look: number }` | 4/s | hors combat ; baddie découverte ; `look` ∈ `collection.looks[id].unlocked` |
| `UpgradeCrew` | `{ crewId }` | 4/s | compagnon possédé, pas au niveau 10 ; dépense `niveau + 1` copies (`crewOwned[i].upgradeCost`) |
| `EquipCrew` | `{ ids: { string } }` | 4/s | ≤ 2 compagnons **possédés**, sans doublon ; remplace la liste (vide = aucun) |
| `SetStyle` | `{ slot, id? }` | 4/s | hors combat ; `slot` ∈ `Wardrobe.slots` ou `"title"` ; `id` débloqué et du bon emplacement ; `id` absent = retirer |
| `DevSetMastery` 🧪 | `{ baddieId, xp }` | 4/s | **Studio uniquement** : fixe l'XP de maîtrise (tester les looks) |
| `DevGrant` 🧪 | `{ what = "tickets" \| "crewTickets" \| "drop" \| "finishRun", baddieId? }` | 4/s | **Studio uniquement** : +10 tickets baddie, +5 tickets compagnon, un drop en attente, ou les 10 niveaux terminés |

⏳ = **décision durable** (ci-dessous) : réponse `Result { kind = "mutation" }` après l'écriture.
Les autres intentions invalides sont ignorées sans réponse : le client se fie au snapshot suivant.
🧪 = déclarée seulement dans Studio (`RunService:IsStudio()`), absente en production.

Le client peut afficher `Balance.training.holdActionsPerSecond` (3/s) pour le maintien accessible.
En combat, le bouton principal envoie `Attack` ; au repos, `Train`. Jamais les deux (§07).
Le premier passage d'un niveau démarre tout seul quand le joueur entre dans son arène.

## Décisions durables (P2 : relance, drop, renaissance, coffre — §25 à §27)

1. Le client génère un `requestId` (chaîne de 1 à 64 caractères, ex. `HttpService:GenerateGUID(false)`)
   **par décision**, et le **réutilise** s'il doit renvoyer la même décision (pas de réponse, `saving`,
   `error` ou `confirmed = false`). Jamais un nouveau `requestId` pour une décision déjà envoyée.
2. Le serveur traite une décision à la fois par joueur, tire le hasard **une seule fois**, enregistre un
   reçu dans le profil puis attend l'écriture DataStore. Un renvoi du même `requestId` rend **le même
   résultat** (`replay = true`), sans nouvel effet.
3. Pendant l'écriture, `snapshot.saving = true` et les snapshots suivants sont retenus : afficher la
   révélation (roulette, bannière) **à la réception de la réponse**, jamais avant.

Réponse `Result` :

```lua
{
	kind = "mutation",
	action = "Roll",              -- "Roll" | "AcceptDrop" | "RefuseDrop" | "Rebirth" | "OpenChest"
	requestId = "…",              -- celui de la demande
	ok = true,
	reason = nil,                 -- si ok = false (voir ci-dessous)
	confirmed = true,             -- false : appliquée mais écriture non confirmée → renvoyer le même requestId
	replay = nil,                 -- true : renvoi d'une décision déjà traitée
	result = {                    -- selon l'action :
		-- Roll       : slotId, baddieId, previousId?, guaranteed, isNew, slotRevision, rollNumber
		-- AcceptDrop : slotId, baddieId, previousId?, isNew, slotRevision, remaining, isActive
		-- RefuseDrop : baddieId, remaining
		-- Rebirth    : count, runId, promotedSlotId?, newSlotId?, clearedSlotId?, lostBaddieId?,
		--              activeSlotId, fallback? ("conserved" | "maya"), baddieTickets, crewTickets
		-- OpenChest  : crewId, isNew, equipped, level, copies, guaranteed, openNumber
	},
}
```

Raisons de refus : `busy` (une décision est déjà en cours), `saving` (l'écriture précédente est encore
incertaine), `cooldown` (2 s entre deux relances ou deux coffres), `in_combat`, `stale` (révision ou parcours périmé :
resynchroniser et redemander confirmation), `locked`, `no_ticket` (ticket baddie, ou compagnon pour
`OpenChest`), `no_drop`, `no_temporary`,
`not_finished` (niveau 10 non terminé), `unknown_slot`, `invalid`, `duplicate`, `error`,
`maintenance` (décision coupée temporairement par l'équipe, voir `snapshot.maintenance` ; rien n'est modifié).
Après une renaissance confirmée, le serveur renvoie le joueur au lobby (1,5 s).

## Snapshot `State` (v = 2)

Envoyé au chargement, sur `Hello`, puis à chaque changement (regroupé, au plus toutes les 0,1 s).

```lua
{
	v = 2,
	mode = "rest",                -- "rest" | "combat" (le bouton change de libellé et de couleur)
	power = 12.4,                 -- puissance actuelle (peut être décimale)
	gainPerTrain = 1,             -- gain d'une action d'entraînement
	passivePerSecond = 0.6,       -- production totale du crew, bonus de rebirth inclus
	trainingBonus = 1,            -- ×bonus de rebirth
	rebirths = 0,
	tickets = { baddie = 10, crew = 0 },
	active = {                    -- la principale (une seule baddie compte)
		slotId = "s1",
		baddieId = "maya",
		multiplier = 1,
		masteryLevel = 0,
		damagePerClick = 12.4,
		look = 1,                 -- look porté par la principale (1 à 3)
	},
	crew = {                      -- compagnons équipés, dans l'ordre (2 max)
		{ id = "malik", level = 1, copies = 0, perSecond = 0.6 },
	},
	crewOwned = {                 -- toute la collection possédée, ordre du catalogue (P2)
		{ id = "malik", level = 2, copies = 1, upgradeCost = 3, canUpgrade = false,
		  equipped = true, perSecond = 0.66 },   -- upgradeCost nil au niveau 10
	},
	crewChest = {
		opened = 7,               -- coffres ouverts (compteur global, séparé des relances)
		guaranteeEvery = 20,
		untilGuarantee = 13,      -- 1 = le prochain coffre donne un compagnon manquant
		missing = { "kenji", "amine" },
		complete = false,
	},
	stats = { trainActions = 14, crewPowerEarned = 2.4 },
	settings = { reducedEffects = false }, -- effets réduits (§21)
	combat = {                    -- { active = false, hp, maxHP } hors combat
		active = true,
		encounterId = "123-4",
		levelId = 1,
		phase = "wave",           -- "wave" | "boss" | "finalizing"
		hp = 85, maxHP = 100,     -- PV de combat (jamais sauvegardés)
		minionsKilled = 1, minionsTotal = 3,
		boss = "jade",
	},
	clearedLevels = { 1, 2 },     -- portes ouvertes pour CE joueur (refermées à la mort)
	run = { id = 1, attempt = 1 },
	pendingDrops = { jade = 1 },  -- drops de boss en attente de décision (accepter / refuser 1)
	pendingRevision = 3,          -- à renvoyer avec AcceptDrop / RefuseDrop
	slots = {                     -- ordonnés ; un seul temporaire ; baddieId nil = slot vide
		{ id = "s1", order = 1, conserved = true, temporary = false, baddieId = "nova",
		  revision = 4, rollLocked = true, active = true },
		{ id = "s2", order = 2, conserved = false, temporary = true, baddieId = "lina",
		  revision = 2, rollLocked = false, active = false },
	},
	rolls = {
		baddie = 12,              -- relances effectuées (compteur global, garde la garantie)
		guaranteeEvery = 50,
		untilGuarantee = 38,      -- 1 = la prochaine relance est une ouverture garantie
		bookComplete = false,     -- Book complet : la table standard s'applique toujours
		missing = { "zuri", "vega" }, -- ouverture garantie : chance égale pour chacune
	},
	collection = {                -- Baddies Book (proposition contrat v2 du codeur B)
		discovered = { "maya", "nova" },  -- ordre du catalogue ; identités de test en dernier (Studio)
		display = { "nova" },             -- exposition, 3 max (apparence uniquement)
		looks = { maya = { unlocked = { 1, 2 }, selected = 2 }, nova = { unlocked = { 1 }, selected = 1 } },
		bookCount = 2, bookTotal = 8,     -- identités publiques seulement
	},
	saving = false,               -- true pendant l'écriture d'une décision durable
	maintenance = { },            -- décisions coupées ("Roll", "AcceptDrop", "RefuseDrop", "Rebirth", "OpenChest") : griser
	seq = 42,                     -- numéro croissant de ce snapshot : ignorer un snapshot plus ancien que le dernier reçu
	style = {                     -- garde-robe, titres et succès (§19) ; noms et emplacements : Shared/Wardrobe
		items = { "frame_simple", "headset_player" },   -- cosmétiques débloqués (ordre de Wardrobe.itemOrder)
		titles = { "boss_manager" },                    -- titres débloqués
		equipped = { frame = "frame_simple" },          -- emplacement -> cosmétique porté
		title = "boss_manager",                         -- titre affiché au-dessus de l'avatar, ou nil
		achievements = { "first_training", "first_crew", "first_boss" },
		achievementTotal = 10,
	},
	ranking = {                   -- classement du lobby : joueurs PRÉSENTS, calculé par le serveur (§15)
		lot = "V1", total = 8, crewTotal = 6, -- afficher « 7/8 » et le lot classé
		baddies = {               -- trié ; rang partagé en cas d'égalité (1, 1, 3)
			{ userId = 123, name = "Alex", score = 7, rank = 1 },  -- name = DisplayName
			{ userId = 456, name = "Mia", score = 7, rank = 1 },
			{ userId = 789, name = "Zoé", score = 5, rank = 3 },
		},
		crew = { { userId = 123, name = "Alex", score = 4, rank = 1 } }, -- onglet séparé
	},
	rebirth = {
		count = 1,                -- renaissances déjà faites
		available = false,        -- niveau 10 terminé dans ce parcours
		promotesNext = false,     -- la prochaine promeut le temporaire (paliers 1, 3, 6)
		temporarySlotId = "s2",
		baddieTickets = 5, crewTickets = 1, -- récompenses de la prochaine
	},
	tutorial = { crewUnlocked = true, progress = 10, needed = 10 },
}
```

Noms, raretés, couleurs et looks : lire `Shared/Catalog` avec l'ID (`Catalog.baddies.maya`,
`Catalog.crew.malik`). Nombres à afficher : `Shared/Format.number(n)` (format français).

## Événements `Result`

| `kind` | Champs | Usage suggéré |
|---|---|---|
| `crewJoined` | `crewId`, `isNew`, `equipped` | `isNew = true` : bannière RGB « NOUVEAU CREW » (CelebrationController) ; `isNew = false` : doublon d'un coffre, toast « +1 copie » (HUD) |
| `ticket` | `ticket` = `"baddie"`/`"crew"`, `amount` | toast +1 ticket (HUD seulement) |
| `passiveTick` | `amount` (puissance réellement gagnée) | petit « +0,6 » au-dessus du compagnon, chaque seconde |

| `levelCleared` | `level`, `boss`, `drop` (baddieId ou nil), `firstClear`, `baddieTickets`, `power` | boss vaincu : la porte s'ouvre ; texte « 10 % à chaque victoire, aucun drop garanti » |
| `masteryUp` | `baddieId`, `level` | la principale monte en maîtrise |
| `death` | — | « Retour au lobby. Ta puissance et tes baddies restent ; les portes se referment. » |
| `combatLeft` | — | sorti de l'arène plus de 3 s : combat abandonné, aucune récompense |
| `mutation` | voir « Décisions durables » | réponse à `Roll`, `AcceptDrop`, `RefuseDrop`, `Rebirth` |
| `discovery` | `baddieId` | nouvelle identité au Baddies Book (relance ou drop accepté), après l'écriture |
| `rebirth` | `count` | renaissance confirmée |
| `crewLevelUp` | `crewId`, `level` | compagnon amélioré (`UpgradeCrew`) |
| `achievement` | `id`, `items`, `titles` | succès obtenu et ce qu'il débloque (noms : `Shared/Wardrobe`) |

## Flux `Combat` (rencontre individuelle, §08)

Chaque joueur a ses propres ennemis : le serveur calcule positions, PV, zones de danger et impacts,
et n'envoie ce flux qu'au joueur concerné. Le client ne fait que l'afficher (modèles, animations,
cercles au sol). Positions en studs dans le plan XZ ; la hauteur vient de `floorY`.

| `t` | Champs | Rendu attendu |
|---|---|---|
| `start` | `encounterId`, `levelId`, `floorY`, `hp`, `maxHP`, `minionsTotal`, `boss` | début de la vague |
| `spawn` | `enemy = { id, kind ("minion" ou "boss"), baddieId?, hp, maxHP, x, z }` | faire apparaître l'ennemi |
| `pos` | `list = { { id, x, z }, ... }` (10 fois/s) | interpoler la position des ennemis |
| `telegraph` | `enemyId`, `x`, `z`, `radius`, `duration` | cercle de danger au sol qui se remplit pendant `duration` s |
| `impact` | `enemyId`, `x`, `z`, `radius`, `hit`, `damage`, `hp` | frappe ; `hp` = PV du joueur après coup |
| `hit` | `targetId`, `damage`, `hp`, `killed` | coup du joueur sur un ennemi |
| `end` | `encounterId`, `reason` ("victory", "death", "left") | tout nettoyer |

Rendu : `Controllers/Combat` (démarré par l'App, logique pure dans `Logic/CombatModel`) — ennemis,
plaques de PV, zones de danger, chiffres de dégâts, barre de vague / boss, PV du joueur, flash rouge,
bouton REJOUER (`StartWave`) dans l'arène d'un niveau terminé, « puissance conseillée » hors combat.
L'attaque passe par le bouton principal du HUD (ou la touche F). L'App démarre aussi `DoorController`.

## Monde : arènes et portes (§05, §09)

Le serveur lit `Workspace.Levels`, synchronisé par Rojo depuis `assets/world/Levels.rbxm` (généré par
`lune run assets/world/export-levels` à partir de `LevelsBuilder.luau`, qui vérifie aussi ce contrat).
Sans `Workspace.Levels` (place sans Rojo), Studio construit encore la carte grise de secours (`World/DevWorld`).
Les arènes doivent garder ces noms :

| Instance | Rôle |
|---|---|
| `Workspace.Levels.LevelN.Arena` | zone de combat du niveau N : Part **invisible, sans collision, alignée sur les axes** ; entrée au sud (+Z), ennemis au nord (-Z) |
| `Workspace.Levels.LevelN.Door` | porte vers le niveau N+1 ; `Controllers/DoorController` l'ouvre **localement** pour le joueur qui a vaincu le boss N |

Ouvrir une porte n'est qu'une présentation : le serveur vérifie lui-même que le joueur a le droit
d'être dans une arène. Traverser un mur côté client ne donne ni combat ni gain.

## Effets RGB (`Controllers/CelebrationController`)

Bannière arc-en-ciel, gerbe de particules RGB autour du personnage, onde au sol et flash d'écran
pour les **grands moments** : nouveau compagnon, palier de puissance (10, 25, 50, 100, 250…), niveau terminé,
drop de boss, maîtrise, nouvelle baddie, renaissance, succès. Les petites infos (`ticket`, et `crewJoined` avec
`isNew = false`, soit +1 copie) sont des toasts du HUD du codeur B : jamais de double annonce. Si `settings.reducedEffects` est vrai, seule la bannière
reste. Le HUD final peut réutiliser `rainbowGradient(guiObjectOuStroke)` et `play({ title, subtitle?, big })`.

## Attributs du Player (visibles par tous les clients)

Pour afficher les suiveurs de **tous** les joueurs, pas seulement les siens :

| Attribut | Type | Exemple |
|---|---|---|
| `BC_Ready` | boolean | `true` quand le profil est chargé |
| `BC_ActiveBaddie` | string | `"maya"` |
| `BC_EquippedCrew` | string, IDs séparés par des virgules | `"malik"` ou `"malik,enzo"` |
| `BC_ActiveLook` | number | `1` (look de la principale) |
| `BC_Display` | string, IDs séparés par des virgules | `"nova,jade"` (exposition) |
| `BC_BookCount` | number | `2` (identités publiques découvertes : score du classement) |
| `BC_CrewCount` | number | `4` (compagnons possédés : score de l'onglet Crew) |
| `BC_Title` | string | `"baddie_pro"` (titre affiché au-dessus de l'avatar, `""` si aucun) |
| `BC_Style` | string | `"neck=chain_gold,frame=frame_v1"` (cosmétiques portés, par emplacement) |

## Outils de test (Studio uniquement)

- `Shared/TestCatalog` : identité `test_b99` (silhouette grise, ×1, un look). Dans Studio, le serveur
  l'ajoute au catalogue (`TestCatalog.merge`) et au Baddies Book du profil Studio. Jamais tirée en
  relance, jamais « manquante », jamais comptée dans `bookCount`. Côté client, `Shared/Catalog` ne la
  contient pas : afficher l'ID tel quel si `Catalog.baddies[id]` est nil.
- `DevSetMastery`, `DevGrant` : voir les intentions.
- `Dev/DevSlotsPanel` (touche F4), lancé par `DevToolsBootstrap.client.luau` : slots, relances, drops,
  renaissance et outils, en attendant les écrans Slots / Drops / Rebirth du codeur B.

Les suiveurs sont **purement visuels et locaux** (§28) : aucune physique serveur, aucune collision,
arrêter une animation ne change rien aux gains.
