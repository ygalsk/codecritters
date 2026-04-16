# CodeCritters

Pokemon-style roguelike for the terminal. Every critter is a programming concept.

Built on [Vexel](https://github.com/dkremer/vexel), a terminal graphics engine using the Kitty graphics protocol.

## Running

```bash
# Install Vexel, then:
vexel run .
# or from the Vexel repo:
zig build run -- /path/to/codecritters-game/
```

## Design

The `design/` folder is the living design bible (open it as an Obsidian vault for graph view):

- [Vision](design/vision.md) — what this game is
- [Core Loop](design/core-loop.md) — the session flow
- [Types](design/types.md) — 7 types, matchups, status effects
- [Archetypes](design/archetypes.md) — 7 combat roles
- [Battle System](design/battle-system.md) — encounters, turns, damage, moves
- [Dungeon](design/dungeon.md) — exploration, enemies, fog of war
- [Items](design/items.md) — hold items, catch tools
- [Critters](design/critters.md) — stats, evolution, starters, legendaries
- [Progression](design/progression.md) — scars, economy, meta unlocks, achievements
- [Presentation](design/presentation.md) — hub UI, UX principles
- [Art Direction](design/art-direction.md) — sprites, animation, music
- [Emotional Arc](design/emotional-arc.md) — how a run feels
- [Scope](design/scope.md) — v1 boundary

The original brain dump lives in [DESIGN.md](DESIGN.md).
