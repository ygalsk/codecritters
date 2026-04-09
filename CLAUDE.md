# Codecritter

Pokemon-style roguelike TUI game. Zig 0.15.2 + libvaxis + zqlite.

## Build
```
zig build          # compile
zig build run      # launch game
zig build test     # 129 unit tests
```

## Structure
```
src/data/       # Species, Move, Item, Critter structs + JSON loading + type chart
src/battle/     # Battle engine: damage, status, catch, AI, turn processing (no UI)
src/ui/         # Battle screen TUI, sprite rendering (half-block + kitty), colors, text
src/db/         # SQLite persistence (roster, inventory, scars)
src/main.zig    # TUI entry point
data/*.json     # Species, moves, items definitions
assets/sprites/ # 32x16 PNG sprite sheets (2 frames per critter)
```

## Key Docs
- `CODECRITTER_DESIGN.md` — source of truth for game design
- `AGENT_INSTRUCTIONS.md` — phase workflow and roadmap
- `PROGRESS.md` — what was built each phase, API details, design decisions

## Conventions
- Phase workflow: plan → approve → implement → verify → update docs
- Data-driven: stats/moves/items in JSON, not hardcoded
- Game logic separate from rendering — engines work without UI
- No over-engineering: structs, arrays, functions. No ECS.

## Zig Gotchas
- `std.ArrayList(T)` is unmanaged — pass allocator per-call
- JSON: `std.json.parseFromSlice` with `.allocate = .alloc_always`
- Cross-directory imports: named modules in build.zig, not `../` paths
- GCC 15 `.sframe` fix: `link_gc_sections = true` on targets linking libc
- `std.Random.DefaultPrng` — `.random()` needs `*self` (mutable), not const
- zigimg access: `vaxis.zigimg` (re-exported transitive dep). `Image.deinit(alloc)` needs allocator arg
- vaxis `Window.child(.{.x_off, .y_off, .width, .height})` — width/height are `?u16`, not structs
