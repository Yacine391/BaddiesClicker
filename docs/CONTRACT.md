# Contrat réseau client ↔ serveur (v1, lot P0)

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

Côté client, **ne pas brancher les remotes à la main** : passer par
`Controllers/StateController` (`onState`, `onResult`, `send`).

## Intentions acceptées

| Action | Payload | Limite serveur | Conditions |
|---|---|---|---|
| `Hello` | aucun | 2/s | renvoie le snapshot ; à envoyer au démarrage (fait par StateController) |
| `Train` | aucun | 8/s (rafale 8) | profil chargé, hors combat |

Le client peut afficher `Balance.training.holdActionsPerSecond` (3/s) pour le maintien accessible.
À venir en P1/P2 : `Attack`, `StartWave`, `Roll`, `AcceptDrop`, `RefuseDrop`, `SetActive`, `Rebirth` (§25).

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

Prévus (P1/P2), déjà gérés par `CelebrationController` : `levelCleared` {`level`}, `masteryUp`
{`baddieId`, `level`}, `crewLevelUp` {`crewId`, `level`}, `rebirth` {`count`}, `discovery` {`baddieId`}.

## Effets RGB (`Controllers/CelebrationController`)

Bannière arc-en-ciel, gerbe de particules RGB autour du personnage, onde au sol et flash d'écran
quand le joueur franchit un cap : nouveau compagnon, ticket, palier de puissance (10, 25, 50, 100,
250…), puis niveaux, maîtrise, renaissance. Si `settings.reducedEffects` est vrai, seule la bannière
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
