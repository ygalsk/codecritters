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

### Phases 0–13.5 — Core Systems + Starter Chains + Title + Graphics Engine [DONE]
All game systems built through Phase 12. Phase 13 added title screen and transitions. Phase 13.5 refactored UI into reusable layers. 15 species, 16 moves. See PROGRESS.md for details.

### Phase 14 — Bug Fixes: Death Logic + Cooldown Blocking + XP + Hub Item Use [DONE]
Fixed death logic (fainted critters no longer excluded from battle party), cooldown deadlock (cooldowns decrement before party select), XP persistence (silent catch {} replaced with error logging, index mapping fixed). Hub inventory now interactive — healing/revive items usable on roster critters.

### Phase 15 — Dungeon Quick Menu + In-Dungeon Item Use [DONE]
Press `m` in dungeon for quick menu: swap active roster order, open inventory to use items, view party. Wire healing/consumable item effects through dungeon context (hub inventory already interactive from Phase 14).

### Phase 16 — Bug Fixes: Battle Priority + Speed Death Logic [DONE]
Fixed two battle bugs: (1) items, catches, and swaps now have priority over attacks — they always resolve first regardless of speed; (2) fainted critters no longer act — HP guard added before the second actor's action in both turn-order branches.

### Phase 17 — Roster Swap + Item Screen Improvements
Roster and party select screens gain position-swap controls. Item/inventory screen shows full descriptions, effect values, and item sprites. Items display rarity indicators.

### Phase 18 — Game Event Loop Engine (Research Phase)
Research and design a reusable game event loop engine. The UI rendering layer (theme/layout/widgets/anim/input) exists but there's no centralized game event loop. Needs discussion on scope and architecture before implementation.

### Phase 19 — CLI Enhancements: JSON + Statusline Sprite
Enrich `status` CLI with full JSON output for chat personality (individual critter details, equipped moves, run state). Add `statusline --sprite` flag returning rendered sprite with info for Claude statusline.

### Phase 20 — Three-Stage Evolution Lines (All 7 Types)
Complete every type's 3-stage common→common→uncommon line (Printf→Fprintf→Logstash, Segfault→Stack Overflow→Kernel Panic, etc.). +15 species, +14 moves, +15 sprites. Update all biome encounter tables.

### Phase 21 — Four New Biomes + Detection
Rustacean Depths (.rs), Gopher Tunnels (.go), C Catacombs (.c/.h), Shell Scripts (.sh). Complete detect.zig with language scoring. Each biome needs encounter table, boss pool, shop/drop bias, theme colors.

### Phase 22 — Two-Stage Lines + Standalone Rares
Each type gets its uncommon→rare 2-stage line + standalone rare (Breakpoint→Watchpoint, Heisenbug, etc.). +21 species, +10 moves, +21 sprites.

### Phase 23 — Epics + Legendaries + Sound Cues
7 epics (stats reflect drawbacks, no special engine hooks yet) + 3 legendaries (not in encounter tables). Sound system emitting BEL on key events. +10 species, +8 moves, +10 sprites. Full 61-critter roster complete.

### Phase 24 — Dungeon Graphics + Biome Tilesets + Attack Animations + Visual Overhaul
Sprite-based dungeon rendering with biome-specific tilesets for each dungeon type. Battle attack animations per move type. Visual pass on all screens: title, hub, roster, shop, recap. Target 80×24 minimum.

### Phase 25 — Sprite Audit + Final Visual Polish
Verify all 61 sprites exist. Hub shows favorite critter. Roster shows sprite previews. Battle handles long names. All screens clean at 80×24.

### Phase 26 — README + Build Streamlining
Enhance README with actual screenshots, GIFs, and visual appeal. Streamline build and install process (single-command setup, clearer install instructions).

### Phase 27 — Balance Pass + Final Polish
Stat totals by rarity tier, move power/accuracy curves, XP curve verification, catch rate review, biome encounter balance, shop pricing, edge case testing. Content-complete.

---

## Principles

- **Playable early, polished late.** Phase 3 should produce something a human can interact with. Every phase after that should keep the game playable.
- **Data-driven.** Critter stats, moves, items, type chart, biome encounter tables — all in JSON, not hardcoded. Tuning should never require recompilation.
- **Game logic separate from rendering.** Battle engine and dungeon engine must work and be testable without any UI. Screens are thin layers over game logic.
- **Don't over-engineer.** No ECS, no entity framework, no custom allocator pools unless a profiler says you need them. Structs, arrays, and functions.
- **One thing at a time.** Each phase has a clear deliverable. Don't leak scope between phases.
