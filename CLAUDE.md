# Codecritter — Claude Code Context

## What This Is
Pokemon-style roguelike TUI game in Zig + libvaxis. See CODECRITTER_DESIGN.md for full design, STARTINGPOINT.md for phase roadmap.

## Build & Run
```
zig build        # compile
zig build run    # launch game
zig build test   # run unit tests (45 tests)
```
Zig 0.15.2. libvaxis 0.5.1, zqlite 0.0.1 fetched via build.zig.zon.

## Project Structure
```
build.zig              # build config, wires vaxis + zqlite dependencies
build.zig.zon          # package manifest
src/
  main.zig             # entry point, loads data + DB, TUI event loop
  data/
    types.zig          # CritterType enum, type effectiveness chart (comptime 7x7)
    species.zig        # Species struct, JSON loading, findById
    moves.zig          # Move struct, StatusEffect enum, JSON loading
    items.zig          # Item struct, ItemKind, CatchTier, JSON loading
    critter.zig        # Critter instance struct, createFromSpecies factory
    loader.zig         # Generic JSON file loading helper
    game_data.zig      # GameData: loads all JSON, provides lookup functions
  db/
    db.zig             # Db wrapper: open/close, schema init (zqlite)
    roster.zig         # Save/load critters, scars, inventory
data/
  species.json         # 5 test species
  moves.json           # 12 test moves
  items.json           # 8 test items
CODECRITTER_DESIGN.md  # game design doc (source of truth)
STARTINGPOINT.md       # phase roadmap & workflow
PROGRESS.md            # what was built each phase
```

## Design Philosophy

Follow the principles of **A Philosophy of Software Design** (John Ousterhout):
- Design modules that are **deep** — simple interfaces hiding significant complexity
- Fight **complexity** at every step: obscurity, dependencies, cognitive load
- Write **obvious code** — a reader should immediately understand what it does and why
- Define errors **out of existence** where possible rather than propagating them
- Invest in good abstractions now to reduce future complexity; tactical programming creates debt

For the open-source and development process, follow **The Cathedral and the Bazaar** (Eric Raymond):
- **Release early, release often** — get working software in front of users fast
- **Treat users as co-developers** — every player/contributor is a potential bug-finder
- **Given enough eyeballs, all bugs are shallow** — design for transparency and debuggability
- **Plan to throw one away; you will anyhow** — don't over-invest in first implementations
- **Good programmers know what to write; great ones know what to rewrite (and reuse)**

## Conventions
- Follow STARTINGPOINT.md phase workflow: plan -> approve -> implement -> verify
- Data-driven: critter stats, moves, items in JSON, not hardcoded
- Game logic separate from rendering — engines must work without UI
- No over-engineering: structs, arrays, functions. No ECS/entity frameworks.
- Tuning values (stats, XP curves, catch rates) are reasonable defaults, adjustable later

## Zig 0.15.2 Notes
- `std.ArrayList(T)` is unmanaged — pass allocator per-call (`.append(alloc, item)`, `.deinit(alloc)`)
- JSON parsing: `std.json.parseFromSlice` with `.allocate = .alloc_always` when source buffer is freed
- Cross-directory imports: use named module imports in build.zig, not `../` paths
- GCC 15 `.sframe` linker fix: `compile.link_gc_sections = true` on targets linking libc

## vaxis API Notes
- `Tty.init(&buf)` takes a write buffer, `tty.writer()` returns `*std.Io.Writer`
- `vaxis.init(alloc, .{})` / `vx.deinit(alloc, writer)`
- Event loop: define `Event = union(enum)` with fields like `key_press: vaxis.Key`, `winsize: vaxis.Winsize`
- `vaxis.Loop(Event)` — `.init()`, `.start()`, `.nextEvent()`, `.stop()`
- Rendering: `vx.window()` -> `win.clear()` -> `win.printSegment(...)` -> `vx.render(writer)` -> `writer.flush()`
- `key.matches('q', .{})` / `key.matches('c', .{ .ctrl = true })` for input
- `pub const panic = vaxis.Panic.call;` restores terminal on crash

## zqlite API Notes
- `zqlite.open(path, zqlite.OpenFlags.Create)` returns `Conn`
- `conn.execNoArgs("SQL")` for DDL, `conn.exec("SQL", .{params})` for parameterized
- `conn.row("SQL", .{params})` returns `?Row`, `conn.rows(...)` returns `Rows`
- Row: `.int(col)`, `.text(col)`, `.nullableText(col)`, `.nullableInt(col)`
- `conn.lastInsertedRowId()` after INSERT
