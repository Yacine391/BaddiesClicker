# Proposition : contrat réseau v2 — collection, exposition et looks (lot P0)

> **Statut : implémenté dans le contrat v3, PR #3** (`docs/CONTRACT.md`). Ce document reste comme trace de la proposition.

**De :** Codeur B — **Pour :** Codeur A (relecture et implémentation serveur)
**Base :** `docs/CONTRACT.md` v1 — **Dossier :** rubriques 02, 03, 11, 13, 15, 19, 25, 30

## Pourquoi

L'acceptation du lot P0 (§02) demande que le bêta-testeur **distingue sa principale de son exposition** et reconnaisse
les **trois looks de Maya**. Le v1 n'expose ni découvertes, ni exposition, ni looks : le client ne peut donc ni afficher
le Book complet, ni proposer « Exposer », ni choisir un look. Tout ce qui suit reste additif : rien du v1 ne change.

## 1. Snapshot `State` : `v = 2`, nouveau champ `collection`

```lua
collection = {
	discovered = { "maya" },                 -- discoveredBaddies, ordre de Catalog.baddieOrder
	display = { },                           -- displayBaddies, 3 IDs maximum
	looks = {
		maya = { unlocked = { 1 }, selected = 1 },   -- index dans Catalog.baddies.maya.looks
	},
},
```
- `unlocked` est **dérivé** de la maîtrise (`Formulas.masteryLevel`) et de `Balance.looks.unlockAtMastery`, jamais stocké.
- `selected` est stocké dans le profil (voir §4) ; s'il n'est plus débloqué, le serveur renvoie le plus haut débloqué.

## 2. Nouvelles intentions

| Action | Payload | Limite | Conditions serveur |
|---|---|---|---|
| `SetDisplay` | `{ ids = { string } }` | 4/s | hors combat ; ≤ `Balance.collection.maxDisplay` (3) ; chaque ID est une chaîne connue de `Catalog` et **découverte** ; sans doublon. Remplace la liste entière. |
| `SetLook` | `{ baddieId = string, look = number }` | 4/s | hors combat ; baddie découverte ; `look` entier ∈ `unlocked`. |

Comme en v1, une intention invalide est ignorée sans réponse ; le client se fie au snapshot suivant.
L'exposition **n'entre dans aucune formule** (§15) : `active.multiplier` et `damagePerClick` restent calculés depuis la
principale seule.

## 3. Attributs publics

| Attribut | Type | Exemple |
|---|---|---|
| `BC_ActiveLook` | number | `1` (look de la principale) |
| `BC_Display` | string, IDs séparés par des virgules | `"maya"` |

## 4. Profil et `Balance`

- Profil : ajouter `selectedLooks = {}` (baddieId → index). Ajout compatible : ProfileStore le réconcilie, pas de migration
  de vrais joueurs (aucun n'existe, §24).
- `Balance.looks = { unlockAtMastery = { 0, 1, 5 } }` (§03 : look 2 à maîtrise 1, look 3 à maîtrise 5).
- `Balance.collection = { maxDisplay = 3 }`.

## 5. Outils de test réservés à Studio (§02, §13, §30)

Pour démontrer l'exposition sans produire d'autres personnages :
- `Shared/TestCatalog` : identité `test_b99` (silhouette grise, ×1, 1 look). Chargée **uniquement si
  `RunService:IsStudio()`**, jamais comptée dans le lot public ni dans le classement.
- En Studio, le profil reçoit `test_b99` dans `discoveredBaddies` (store Studio séparé, déjà en place).
- Intention `DevSetMastery { baddieId, xp }` : acceptée **uniquement en Studio**, pour tester le déblocage des looks avant le
  combat (P1). Ignorée en production.

## 6. Tests suggérés (`tests/run.luau`)

- `SetDisplay` : 4 IDs → refusé ; doublon → refusé ; ID non découvert → refusé ; liste valide → acceptée.
- Exposer une identité ×4 ne change ni `active.multiplier` ni `damagePerClick`.
- `unlocked` : XP 0 → `{1}` ; XP 10 → `{1, 2}` ; XP 250 → `{1, 2, 3}`.
- `SetLook` sur un look verrouillé → refusé ; `selected` retombe au plus haut débloqué si la maîtrise baisse (garde-fou).
- `test_b99` absent du catalogue hors Studio.

## 7. Côté client (Codeur B)

Le client lit `snapshot.collection` s'il existe. Tant que le v2 n'est pas fusionné, Book et Style sont en lecture seule
(Maya uniquement, aucune action affichée).
