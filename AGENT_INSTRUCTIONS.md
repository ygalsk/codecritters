# Codecritter — Agent Instructions

You are implementing Codecritter, a Pokemon-style roguelike TUI game written in Zig with libvaxis. Before writing any code, read CODECRITTER_DESIGN.md thoroughly — it is the source of truth for all game design decisions.

## How To Work

**Do not start implementing features randomly.** Every phase begins with a planning step where you produce a concrete plan document, get approval, and only then begin writing code.

### Phase Workflow

For each phase:

1. **Read** CODECRITTER_DESIGN.md and any existing code
2. **Plan** — produce a short PLAN_PHASE_N.md covering:
   - What exactly gets built this phase
   - What data structures are needed
   - What external dependencies are required
   - What the acceptance criteria are (how do we know it's done)
   - What is explicitly out of scope for this phase
3. **Get approval** before writing code
4. **Implement** in small, testable increments
5. **Verify** against the acceptance criteria
6. **Update** any docs or plans if design decisions were made during implementation

### Decision Making

- If you encounter a design question not covered by the design doc, **ask** — don't assume
- If something in the design doc turns out to be impractical during implementation, **flag it** with a proposed alternative rather than silently changing the design
- Tuning values (stat numbers, XP curves, catch rates, timings) are yours to set as reasonable defaults — these are explicitly deferred in the design doc and can be adjusted through playtesting later
- Prefer simple working implementations over clever incomplete ones

---

## Roadmap

### Phase 0 — Project Skeleton
Zig project setup, build.zig, libvaxis dependency, a window that opens and closes cleanly. Prove the toolchain works. Nothing else.

### Phase 1 — Data Layer
Define the core data structures: Species, Critter (instance), Move, Item, type chart. Load species/moves/items from JSON data files. Write the data files for a small test subset (3-5 critters, a handful of moves). SQLite schema for persistent game state (roster, inventory, settings). Save and load a roster.

### Phase 2 — Battle Engine (No UI)
Turn-based battle logic as pure functions with no rendering. Damage calculation, type effectiveness, status effects, speed-based turn order, fainting, swapping. Write tests against known scenarios. This must be solid before any UI work begins.

### Phase 3 — Battle Screen
Render a battle using libvaxis. Two sprite placeholders (colored rectangles are fine), HP bars, action menu (Attack, Catch, Swap, Item). Wire up the battle engine from Phase 2. A human should be able to play through a full battle using keyboard input.

### Phase 4 — Sprites
Sprite loading and rendering system. Half-block renderer using truecolor. Kitty graphics protocol renderer with capability detection and automatic fallback. Load PNG sprite sheets, support multi-frame idle animation. Replace the Phase 3 placeholders with real sprites for the test critters.

### Phase 5 — Dungeon Engine (No UI)
Procedural floor generation. Grid representation, tile types (floor, wall, encounter, shop, stairs). Player movement logic. Encounter triggering. Floor-to-floor transitions. Boss floor logic. All testable without rendering.

### Phase 6 — Dungeon Screen
Render the dungeon map using libvaxis. Player movement with keyboard. Fog of war or visible radius. Transition into battle screen on encounter. Between-floor shop screen. Wire up to the battle engine.

### Phase 7 — Party & Roster Management
Party selection screen (pick 3 from roster). Roster viewer showing all owned critters, stats, scars, cooldown status. Leveling, XP gain from battles, evolution triggers. Move Disc equipping.

### Phase 8 — Catch System & Inventory
Catch tool usage during battle (replaces Attack option). Catch rate formula. Inventory screen. Item drops from battles. Shop purchasing with currency.

### Phase 9 — Biome System
Working directory language detection. Biome-specific encounter tables, shop bias, floor aesthetics. Generic fallback biome. At least 2 real biomes implemented (e.g., Python + JS).

### Phase 10 — Death, Scarring & Persistence
Faint → cooldown timer + stat scarring. Persistent roster across runs. Run extraction vs wipe. Full save/load cycle through a complete run.

### Phase 11 — Passive Layer & MCP
Event logging for Claude Code tool-use hooks. Backlog reconciliation on game launch. Passive XP and item finding. MCP server on Unix socket exposing party state as JSON-RPC. Statusline-friendly output.

### Phase 12 — Polish & Content
Full critter roster (all 61). All moves defined. All biomes. Title screen, screen transitions, sound cues (if terminal supports BEL or similar). Balance pass on stats, catch rates, XP curves.

---

## Principles

- **Playable early, polished late.** Phase 3 should produce something a human can interact with. Every phase after that should keep the game playable.
- **Data-driven.** Critter stats, moves, items, type chart, biome encounter tables — all in JSON, not hardcoded. Tuning should never require recompilation.
- **Game logic separate from rendering.** Battle engine and dungeon engine must work and be testable without any UI. Screens are thin layers over game logic.
- **Don't over-engineer.** No ECS, no entity framework, no custom allocator pools unless a profiler says you need them. Structs, arrays, and functions.
- **One thing at a time.** Each phase has a clear deliverable. Don't leak scope between phases.
