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

### Phases 0–29 [DONE]

| Phase | Summary |
|-------|---------|
| 0–13.5 | Core systems, starter chains, title screen, graphics engine, UI layers |
| 14 | Bug fixes: death logic, cooldown blocking, XP, hub item use |
| 15 | Dungeon quick menu, in-dungeon item use |
| 16 | Bug fixes: battle priority, speed death logic |
| 17 | Roster swap, item screen improvements |
| 18 | Game event loop engine (ScreenResult unification) |
| 19 | Revive cooldown fix, item packing for dungeon runs |
| 20 | CLI enhancements: JSON status, roster export, statusline sprite |
| 21 | Three-stage evolution lines for all 7 types (+15 species, +14 moves) |
| 22 | Four new biomes + language detection (Rust, Go, C, Shell) |
| 23 | Two-stage lines + standalone rares (+21 species, +10 moves) |
| 24 | Epics + legendaries + BEL sound cues (full 61-critter roster) |
| 24.5 | Bug fix: item equip SQL error (multi-statement split) |
| 25 | Kitty-first graphics overhaul (backgrounds, animations, transitions) |
| 26 | Sprite audit + final visual polish (80×24 clean) |
| 27 | Meta shop, species codex, lifetime stats HUD |
| 28 | README, install script, release CI, MIT license |
| 29 | Balance pass + XP grant items + animated HP bars — content-complete |

See PROGRESS.md for full details on each phase.

### Phase 30 — Roster List View + Query Optimization
Replace one-at-a-time roster browsing with scrollable list view (Name, Lv, Type, HP columns). Select a row to drill into existing detail view. Fix loadRoster N+1 query problem — collapse 1+2N queries into 2 bulk SELECTs (all critters + all scars), join in code. List/detail toggle via `view_mode` state on roster screen.

### Phase 31 — Compiler Flags (Run Modifiers)
Toggleable "compiler flags" that modify dungeon runs — harder for better loot. Inspired by Halo skulls, themed as real compiler/toolchain flags. Simple on/off toggles, multipliers stack multiplicatively on currency/XP/drop rarity.

Initial flags (~8): `-O0` (enemy +25% HP), `-Wall` (+1 encounter/floor), `-Werror` (status +1 turn), `-fno-exceptions` (no healing drops), `--pedantic` (boss +1 move), `-march=native` (enemy +20% speed), `--release-fast` (30s floor timer), `-fsanitize` (1HP/floor drain).

Data-driven via `compiler_flags.json`. Flag toggle UI on party select screen, displayed as `zig build -Wall -Werror` command line. Unlock progression: start with 3 flags, complete runs with N active to unlock N+1. Persist active flags per run in DB.

### Phase 32 — Floppy Disc Move Sprites
Replace text-based move disc rendering with floppy disc pixel sprites via kitty graphics protocol. Base disc sprite tinted per move type. Render in roster equip overlay and battle move selection. Unicode text fallback for non-kitty terminals unchanged.

---

## Principles

- **Playable early, polished late.** Phase 3 should produce something a human can interact with. Every phase after that should keep the game playable.
- **Data-driven.** Critter stats, moves, items, type chart, biome encounter tables — all in JSON, not hardcoded. Tuning should never require recompilation.
- **Game logic separate from rendering.** Battle engine and dungeon engine must work and be testable without any UI. Screens are thin layers over game logic.
- **Don't over-engineer.** No ECS, no entity framework, no custom allocator pools unless a profiler says you need them. Structs, arrays, and functions.
- **One thing at a time.** Each phase has a clear deliverable. Don't leak scope between phases.
