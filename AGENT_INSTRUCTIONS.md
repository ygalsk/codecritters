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

### Phase 18 — Game Event Loop Engine [DONE]
Unified screen signaling via ScreenResult tagged union. All 10 screens' handleInput returns ?ScreenResult. 333-line transition switch eliminated. from_dungeon flag replaced by ScreenContext carried in results. InventoryEntry types unified. RunOverScreen promoted to proper screen struct. RunContext struct defined for future use.

### Phase 19 — Revive Cooldown Fix + Item Packing [DONE]
Consolidated revive logic into `Critter.applyRevive()` — fixes cooldown not resetting on revive, eliminates duplication between inventory_screen and battle engine. Added item packing to party select screen: press `I`/`Tab` to switch to items tab, toggle items from persistent inventory to bring into dungeon runs (up to 6 slots). Packed items removed from DB at run start, seeded into dungeon `run_inventory`.

### Phase 20 — CLI Enhancements: JSON + Statusline Sprite [DONE]
Enriched `status` CLI with full JSON (detailed favorite critter stats/moves/scars, roster summary, currency, active run state). New `roster` subcommand dumps full roster as JSON array. `statusline` now renders ANSI half-block sprite alongside critter info.

### Phase 21 — Three-Stage Evolution Lines (All 7 Types)
Complete every type's 3-stage common→common→uncommon line (Printf→Fprintf→Logstash, Segfault→Stack Overflow→Kernel Panic, etc.). +15 species, +14 moves, +15 sprites. Update all biome encounter tables.

### Phase 22 — Four New Biomes + Detection [DONE]
Rustacean Depths (.rs), Gopher Tunnels (.go), C Catacombs (.c/.h), Shell Scripts (.sh). Completed detect.zig with 6-language scoring (manifests +10, extensions +1 capped at 20, highest-score-wins with tie-breaking). Each biome has encounter table, boss pool, shop/drop bias, theme colors. 6 new detection tests.

### Phase 23 — Two-Stage Lines + Standalone Rares [DONE]
Each type gets its uncommon→rare 2-stage line + standalone rare (Breakpoint→Watchpoint, Heisenbug, etc.). +21 species, +10 moves, +21 sprites.

### Phase 24 — Epics + Legendaries + Sound Cues [DONE]
7 epics (stats reflect drawbacks, no special engine hooks yet) + 3 legendaries (not in encounter tables). Sound system emitting BEL on key events. +10 species, +8 moves, +10 sprites. Full 61-critter roster complete.

### Phase 24.5 — Bug Fix: Item Equip SQL Error
Fix `removeInventoryItem` in `src/db/roster.zig` — split two-statement SQL (UPDATE + DELETE) into separate `exec()` calls to fix `error.MultipleStatements` from zqlite. Also address the subsequent crash-on-quit triggered by the unhandled error state.

### Phase 25 — Kitty-First Graphics Overhaul [DONE]
Kitty graphics protocol rendering engine: biome backgrounds (z-indexed), tileset system (sprite-sheet sub-rectangles), dynamic floor sizing (fills terminal). Battle animation sequencer (slide → effect → flash → shake) with per-type effect sprites. Screen transitions (fade/wipe/dissolve). Visual pass: dancing colors (Brogue-style sine-wave RGB), smooth lighting attenuation, enhanced Unicode fallback (textured walls, varied floors). Hub/title/shop/recap/run_over polished with box-drawing borders, breathing colors, animated sprites. +8 new UI modules, 21 placeholder assets.

### Phase 26 — Sprite Audit + Final Visual Polish
Verify all 61 sprites exist. Hub shows favorite critter. Roster shows sprite previews. Battle handles long names. All screens clean at 80×24.

### Phase 27 — Meta Shop + Meta Progression HUD [DONE]
Meta shop accessible from hub with 3 convenience upgrades (Extra Pack Slots, Starting Funds, Species Codex). Lifetime stats HUD on hub screen (runs, deepest floor, catches, species discovered, bosses). Species Codex screen (scrollable list with discovered/undiscovered). Stat tracking hooks on run start, floor advance, battles, catches, and extraction. DB layer for meta upgrades and stats via existing meta key-value table. +3 new UI modules (meta_shop_screen, codex_screen, meta_upgrades), 5 new DB test cases.

### Phase 28 — README + Build + Data Streamlining
Enhance README with actual screenshots, GIFs, and visual appeal. Streamline build and install process (single-command setup, clearer install instructions). Evaluate JSON data architecture — consider splitting monolithic species/moves/items JSON into per-entity files for easier editing and reduced load overhead.

### Phase 29 — Balance Pass + Final Polish
Stat totals by rarity tier, move power/accuracy curves, XP curve verification, catch rate review, biome encounter balance, shop pricing, edge case testing. Add level-up consumable item (XP grant item kind + data + inventory use logic). Content-complete.

---

## Principles

- **Playable early, polished late.** Phase 3 should produce something a human can interact with. Every phase after that should keep the game playable.
- **Data-driven.** Critter stats, moves, items, type chart, biome encounter tables — all in JSON, not hardcoded. Tuning should never require recompilation.
- **Game logic separate from rendering.** Battle engine and dungeon engine must work and be testable without any UI. Screens are thin layers over game logic.
- **Don't over-engineer.** No ECS, no entity framework, no custom allocator pools unless a profiler says you need them. Structs, arrays, and functions.
- **One thing at a time.** Each phase has a clear deliverable. Don't leak scope between phases.
