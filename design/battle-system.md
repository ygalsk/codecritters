# Battle System

## Encounter Types

### Standard Wild (1v1)
One wild [[critters|critter]]. Your active critter fights it. Bench exists for swaps only.

### Trainer Boss Teams (all bosses)
Boss has a party of 2-3 critters sent sequentially. After each falls, the next enters. Your critter's HP and [[types#Status Effects|status]] carry over between sub-fights. Boss header shows: `[BOSS] Profiler — Party: ***`

### Boss + Minion
Some bosses arrive with a support critter simultaneously active. The minion acts every turn (heals boss, removes your status, debuffs you). Bench assist model activates:
- **Non-Reviewer bench**: item / swap / weakest move
- **Reviewer bench**: all above + their [[archetypes#Reviewer Support Specials|Support Special]]

### Swarm (floor 11+ only)
3 consecutive 1v1 fights. No HP recovery between. Room is visually distinct (3 enemies visible). Entering is a choice.

## Turn Structure

1. Player selects action (Attack / Catch / Swap / Item / Bench if in boss+minion)
2. Enemy AI selects action
3. Resolve in Speed order
4. Apply damage, status, effects
5. Check for faints
6. Tick status durations
7. Check battle end conditions

## Battle Actions

- **Attack** — choose from 3 moves; show type/power/effectiveness on hover
- **Catch** — choose [[items#Catch Tools|catch tool]]; show success % preview
- **Swap** — costs your turn; swap active critter with bench
- **Item** — use healing/buff item; choose target
- **Bench** (boss+minion only) — Reviewer Support Special or basic bench action

## Battle AI

Wild critters: prefer super-effective moves -> else highest power -> 20% random move selection.

## No Escape

Once an encounter triggers, the fight runs to completion. No flee option.

## Damage Formula

```
damage = move_power x type_effectiveness x (attacker_logic / defender_resolve) x rand(0.85, 1.0)
```

Minimum damage: 1. All values use level-adjusted [[critters#Stats|stats]].

**[[types|Type]] effectiveness:** 1.5x (strong), 1.0x (neutral), 0.5x (weak).

**Speed** determines turn order within a round. Both combatants select actions, then resolve in Speed order. Fastest goes first. A [[archetypes|Hotfix]] archetype almost always acts first.

## Move System

### Move Properties
- Name, [[types|type]], power (0-120), accuracy (50-100%), [[types#Status Effects|status effect]] (optional), status chance (%)

### Move Power Distribution
- Low (30-50): reliable, always-hits utility moves
- Mid (55-80): standard damage, common
- High (85-120): high risk/reward with reduced accuracy

### Move Discs (21 total)

Off-type coverage in the [[critters#Critter Loadout|loadout]] slot. Found in [[dungeon|dungeons]] and shops.

| Tier | Power | Accuracy | Rarity |
|---|---|---|---|
| Disc I | 50 | 95% | Common |
| Disc II | 70 | 85% | Uncommon |
| Disc III | 90 | 75% | Rare |

One disc per type x 3 tiers = 21 discs. A CHAOS Disc III on a PATIENCE critter covers matchups it would otherwise lose.
