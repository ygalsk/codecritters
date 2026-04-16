# Progression

## Run Structure

| | |
|---|---|
| Floors per run | 15 |
| Boss floors | 5, 10, 15 |
| Shop | After each boss (floor 5, 10, 15) — full party heal + buy items |
| HP recovery | Shop only. No auto-heal between fights. |
| Run win condition | Defeat floor 15 boss |
| Floor 16+ | Optional depth mode — no win state, deepest floor = score |
| Enemy level | `3 + floor x 2 +/- 1` (cap 50) |
| No escape | Once [[battle-system|encounter]] triggers, fight to completion |

## Scars

When a [[critters|critter]] faints, it receives a permanent **-1 to a random stat**. Displayed in red on codex and roster. A critter with 3 scars has a story.

## Cooldowns

After fainting, unavailable for **1 full run**. Forces roster rotation. Builds bench depth requirement.

Both mechanics together: losing your best critter costs you a scar (permanent) and a run (temporary). The calculation: push deeper and risk it, or extract and protect.

## Economy

Per-battle: `10 + floor x 5`. Boss: `x2`.
Shop prices scale with floor: `base_price x (1 + (floor-1) x 0.1)`.

Before first shop (floors 1-5): expect ~400-500 gold. Enough for 2-3 items.

[[items#Hold Items|Hold items]] and [[battle-system#Move Discs|Move Discs]] are never sold in shops (drops only). Shops sell: [[items#Catch Tools|catch tools]], healing, XP items.

## Meta Progression

No meta shop. No power upgrades. All unlocks are skill-gated variety expansions.

| Gate | Unlock |
|---|---|
| Clear floor 5 | Biome selection before each run |
| Clear floor 10 | Hard Mode run flag (+5 enemy levels) |
| Clear floor 15 | Floor 16+ depth mode |
| Catch all 7 type representatives | 4th party slot |
| Fill codex | Secret 4th starter: Heisenbug |
| + [[critters#Legendary Critters|Legendary]] unlock conditions | |

The 4th party slot is the only power unlock. By the time you earn it, you've demonstrated mastery.

## Achievements ("Commits")

Git commit format. Displayed in the [[presentation#Hub|Records tab]].

```
feat: add critter              First catch
fix: handle edge case          Win at <10% HP
hotfix: prod is down           Win after first critter faints
release: v1.0                  Clear floor 15
feat!: breaking change         First wipe
docs: add comments             Fill the codex
ci: pipeline passes            Clear floor 15 with no faints
revert: this was a mistake     Catch a Legendary
perf: reduce allocations       Win without taking any damage
test: add coverage             Use all 3 catch tool types in one run
chore: clean up globals        Catch full 3-stage evolution line
refactor: extract method       Evolve a critter for the first time
merge conflict resolved        2 scarred critters in same active party
```

Some commits unlock meta content. All are visible in Records tab.
