# Critters

## Stats (4)

- **HP** — hit points. Reaches zero = fainted. [[progression#Scars|Scar]] applied. 1-run [[progression#Cooldowns|cooldown]] begins.
- **Logic** — attack power. How hard moves hit.
- **Resolve** — defense. Damage reduction.
- **Speed** — turn order. Higher Speed acts first. Ties broken randomly.

### Stat Growth

`stat_at_level = base_stat x (1 + level / 50)`

Level 5 = +10% over base. Level 25 = +50%. Level 50 = +100% (doubled).

## Critter Loadout (4 slots)

```
[Signature move] [Secondary move] [Move Disc] [Hold Item]
```

- **Signature move** — always own [[types|type]], learned at base form. Cannot be changed.
- **Secondary move** — own or related type, learned at evolution or mid-level. Cannot be changed.
- **Move Disc** — equippable off-type coverage move. Swappable at [[presentation#Hub|hub]] between runs.
- **Hold item** — equippable passive/active modifier. Persists across runs. See [[items#Hold Items]].

## Evolution

**Trigger**: level threshold (varies by species).
- 3-stage lines: evolve at levels 12 and 28
- 2-stage lines: evolve at levels 13-15 (first form) and 28-32 (final)

Evolution is a [[presentation#Full-Screen Moments|full-screen interruption]]: flash, sprite transition, stat comparison screen. Permanent and visible in the roster.

## Starter Selection

First time launching the game, a "Choose your partner" screen appears before the hub:

```
+-- CHOOSE YOUR PARTNER -------------------+
|                                           |
|   [Println]      [Goto]      [Glitch]    |
|    DEBUG         LEGACY       CHAOS       |
|                                           |
|   Deployer      Monolith     Hotfix       |
|  Methodical.   Indestructible.  Fast.     |
|  Lints foes.   Outlasts all.  Volatile.   |
|                                           |
|          <> to browse, Enter to choose    |
+-------------------------------------------+
```

The other two starters are catchable later in [[dungeon|dungeon runs]].

**Starter triangle:** Glitch (CHAOS) > Goto (LEGACY) > Println (DEBUG) > Glitch

## Legendary Critters

Three legendaries, each with deep achievement gates:

| Legendary | Type | Unlock Condition |
|---|---|---|
| **Root** | LEGACY | Catch all 7 LEGACY species -> appears as floor 13+ rare encounter |
| **Zero Day** | CHAOS | Clear floor 15 with zero catches -> appears on floor 15 of next run |
| **Linus** | WISDOM | Fill the complete codex (all 61 species) -> appears on floor 15 |

Each legendary's unlock reflects its character. Linus reveals itself only to those who know everything. Zero Day respects efficient violence.

## Species Count

61 total: 7 types x 7 critters + 3 starters + 3 legendaries.
See `sprites_progress.md` for the full species list and sprite status.
