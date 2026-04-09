# Codecritter — Claude Code Context

## What This Is
Pokemon-style roguelike TUI game in Zig + libvaxis. See CODECRITTER_DESIGN.md for full design, STARTINGPOINT.md for phase roadmap.

## Build & Run
```
zig build        # compile
zig build run    # launch game
```
Zig 0.15.2. libvaxis 0.5.1 fetched via build.zig.zon.

## Project Structure
```
build.zig          # build config, wires vaxis dependency
build.zig.zon      # package manifest
src/main.zig       # entry point, TUI event loop
CODECRITTER_DESIGN.md  # game design doc (source of truth)
STARTINGPOINT.md       # phase roadmap & workflow
PROGRESS.md            # what was built each phase
```

## Conventions
- Follow STARTINGPOINT.md phase workflow: plan -> approve -> implement -> verify
- Data-driven: critter stats, moves, items, type chart in JSON, not hardcoded
- Game logic separate from rendering — engines must work without UI
- No over-engineering: structs, arrays, functions. No ECS/entity frameworks.
- Tuning values (stats, XP curves, catch rates) are reasonable defaults, adjustable later

## vaxis API Notes
- `Tty.init(&buf)` takes a write buffer, `tty.writer()` returns `*std.Io.Writer`
- `vaxis.init(alloc, .{})` / `vx.deinit(alloc, writer)`
- Event loop: define `Event = union(enum)` with fields like `key_press: vaxis.Key`, `winsize: vaxis.Winsize`
- `vaxis.Loop(Event)` — `.init()`, `.start()`, `.nextEvent()`, `.stop()`
- Rendering: `vx.window()` -> `win.clear()` -> `win.printSegment(...)` -> `vx.render(writer)` -> `writer.flush()`
- `key.matches('q', .{})` / `key.matches('c', .{ .ctrl = true })` for input
- `pub const panic = vaxis.Panic.call;` restores terminal on crash
