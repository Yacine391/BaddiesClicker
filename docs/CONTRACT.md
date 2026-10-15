# Contrat réseau client ↔ serveur (v2, lots P0 + P1)

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

Le client peut afficher `Balance.training.holdActionsPerSecond` (3/s) pour le maintien accessible.
En combat, le bouton principal envoie `Attack` ; au repos, `Train`. Jamais les deux (§07).
Le premier passage d'un niveau démarre tout seul quand le joueur entre dans son arène.
À venir en P2 : `Roll`, `AcceptDrop`, `RefuseDrop`, `SetActive`, `Rebirth` (§25).

## Snapshot `State` (v = 1)

Envoyé au chargement, sur `Hello`, puis à chaque changement (regroupé, au plus toutes les 0,1 s).

```lua
{
	v = 1,
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
	},
	crew = {                      -- compagnons équipés, dans l'ordre (2 max)
		{ id = "malik", level = 1, copies = 0, perSecond = 0.6 },
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
	pendingDrops = { jade = 1 },  -- drops de boss en attente de décision (P2 : accepter / refuser)
	tutorial = { crewUnlocked = true, progress = 10, needed = 10 },
}
```

Noms, raretés, couleurs et looks : lire `Shared/Catalog` avec l'ID (`Catalog.baddies.maya`,
`Catalog.crew.malik`). Nombres à afficher : `Shared/Format.number(n)` (format français).

## Événements `Result`

| `kind` | Champs | Usage suggéré |
|---|---|---|
| `crewJoined` | `crewId`, `isNew`, `equipped` | annonce du nouveau compagnon (tutoriel : Malik) |
| `ticket` | `ticket` = `"baddie"`/`"crew"`, `amount` | toast +1 ticket |
| `passiveTick` | `amount` (puissance réellement gagnée) | petit « +0,6 » au-dessus du compagnon, chaque seconde |

| `levelCleared` | `level`, `boss`, `drop` (baddieId ou nil), `firstClear`, `baddieTickets`, `power` | boss vaincu : la porte s'ouvre ; texte « 10 % à chaque victoire, aucun drop garanti » |
| `masteryUp` | `baddieId`, `level` | la principale monte en maîtrise |
| `death` | — | « Retour au lobby. Ta puissance et tes baddies restent ; les portes se referment. » |
| `combatLeft` | — | sorti de l'arène plus de 3 s : combat abandonné, aucune récompense |

Prévus (P2), déjà gérés par `CelebrationController` : `crewLevelUp` {`crewId`, `level`}, `rebirth` {`count`},
`discovery` {`baddieId`}.

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

Rendu de test actuel (Studio uniquement) : `Dev/DevCombatView` (blocs, cercles rouges, barres de PV) et
`Dev/DevCombatPanel` (bouton ATTAQUER, touche F, « rejouer »), lancés par `CombatBootstrap.client.luau`.
À remplacer par le HUD de combat du codeur B, qui démarre alors `DoorController` depuis son App.

## Monde : arènes et portes (§05, §09)

Le serveur lit `Workspace.Levels` ; sans carte et dans Studio uniquement, il construit une carte grise
de test, placée juste au nord de `Workspace.Lobby` s'il existe.
La vraie carte du codeur B doit garder ces noms :

| Instance | Rôle |
|---|---|
| `Workspace.Levels.LevelN.Arena` | zone de combat du niveau N : Part **invisible, sans collision, alignée sur les axes** ; entrée au sud (+Z), ennemis au nord (-Z) |
| `Workspace.Levels.LevelN.Door` | porte vers le niveau N+1 ; `Controllers/DoorController` l'ouvre **localement** pour le joueur qui a vaincu le boss N |

Ouvrir une porte n'est qu'une présentation : le serveur vérifie lui-même que le joueur a le droit
d'être dans une arène. Traverser un mur côté client ne donne ni combat ni gain.

## Effets RGB (`Controllers/CelebrationController`)

Bannière arc-en-ciel, gerbe de particules RGB autour du personnage, onde au sol et flash d'écran
quand le joueur franchit un cap : nouveau compagnon, ticket, palier de puissance (10, 25, 50, 100,
250…), niveau terminé, drop de boss, maîtrise, puis renaissance (P2). Si `settings.reducedEffects` est vrai, seule la bannière
reste. Le HUD final peut réutiliser `rainbowGradient(guiObjectOuStroke)` et `play({ title, subtitle?, big })`.

## Attributs du Player (visibles par tous les clients)

Pour afficher les suiveurs de **tous** les joueurs, pas seulement les siens :

| Attribut | Type | Exemple |
|---|---|---|
| `BC_Ready` | boolean | `true` quand le profil est chargé |
| `BC_ActiveBaddie` | string | `"maya"` |
| `BC_EquippedCrew` | string, IDs séparés par des virgules | `"malik"` ou `"malik,enzo"` |

Les suiveurs sont **purement visuels et locaux** (§28) : aucune physique serveur, aucune collision,
arrêter une animation ne change rien aux gains.
