# Dungeon System

## Overview

Free-movement top-down dungeon (Zelda/Undertale feel). Your active [[critters|critter]] walks the rooms.
640x320px viewport (40x20 tiles at 16x16px) + 40px HUD strip.

## Floor Layout

4-6 rooms per floor connected by corridors:
- Start room (safe, no enemies)
- 2-3 enemy rooms
- Optional chest room (50% chance per floor)
- Boss room (stairs appear only after boss is defeated)

Boss floors (5, 10, 15) add a locked shop room accessible after the boss.

## Player Movement

- Smooth pixel-level movement, ~96px/sec
- AABB collision against wall tiles
- Active critter sprite walks. Party order determines who you see in the dungeon.

## Enemy Behavior

- **Patrol state**: simple route within home room (back-forth or random walk)
- **Detection**: player within 3 tiles (~48px) switches enemy to chase
- **Chase state**: locks onto player, moves toward them
- **Contact**: ~8px radius. Touch triggers [[battle-system|battle]].

This creates the sneak opportunity: hug walls, pass through detection edges, observe patrol routes from doorways before committing.

## Fog of War

- Per-room: entering permanently reveals all tiles in that room
- Adjacent rooms visible as dim silhouette through open doorways
- Unexplored rooms completely dark
- Minimap (64x48px overlay, top-right): explored rooms shown as rectangles

## Chest Room Rewards

- 60% — item (healing, [[items#Catch Tools|catch tool]], [[battle-system#Move Discs|move disc]], or [[items#Hold Items|hold item]])
- 30% — currency bonus (50-150g)
- 10% — lone wild critter (peaceful, approach to interact/catch)

## HUD Strip

```
[Println ****-] [Goto ****-] [Glitch ****-]  Floor 5/15  340g
```

HP bars color-code: green (>50%) -> yellow (25-50%) -> red (<25%).

## Optional Room Clearing

Rooms do not need to be cleared to progress. Stairs are blocked only by the boss room.

Strategies emerge:
- **Aggressive** — clear all for XP
- **Cautious** — sneak to boss
- **Greedy** — clear chest rooms only
