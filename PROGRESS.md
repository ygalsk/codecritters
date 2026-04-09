# Codecritter — Progress

## Phase 0 — Project Skeleton [DONE]
- Zig 0.15.2 + libvaxis 0.5.1 (git, commit 3d37f04)
- `build.zig` uses `b.dependency("vaxis", ...)` + `b.createModule` with `.imports` pattern
- `src/main.zig`: alt screen, event loop, renders centered text, exits on q/Ctrl-C
- vaxis API: `Tty.init(&buf)`, `tty.writer()` returns `*std.Io.Writer`, `vx.deinit(alloc, writer)`, `vx.resize(alloc, writer, ws)`
- vaxis `Window.printSegment(.{.text, .style}, .{.col_offset, .row_offset})` for text rendering
- vaxis `Event` is a user-defined `union(enum)` — loop dispatches matching fields
- `pub const panic = vaxis.Panic.call;` for terminal restore on crash

## Phase 1 — Data Layer [DONE]
- Core data structs: CritterType (7 types), Species, Move, Item, Critter instance
- Type effectiveness chart as comptime 7x7 array matching design doc
- JSON data loading via `std.json.parseFromSlice` with `.allocate = .alloc_always`
- Test data: 5 species (Println, Tracer, Glitch, Goto, Monad), 12 moves, 8 items
- SQLite persistence via zqlite.zig (karlseguin/zqlite.zig, bundles SQLite C)
- Schema: critters, scars, inventory, settings, meta tables
- Full save/load round-trip for critters with scars, roster, inventory
- 45 unit tests passing across data and db modules
- GCC 15 `.sframe` linker workaround: `link_gc_sections = true`
- Zig 0.15.2 ArrayList API: unmanaged (allocator per-call), not managed
- Cross-directory imports handled via named module imports in build.zig

## Phase 2 — Battle Engine (No UI) [DONE]
- Battle engine as pure functions in `src/battle/` — no rendering, no side effects beyond state mutation
- **damage.zig**: `calculateDamage` (power × type_effectiveness × logic/resolve × variance[0.85–1.0], min 1), `rollAccuracy`, `effectiveStat` (clamped to min 1)
- **status.zig**: `StatusState` struct (one status at a time, new replaces old), `applyStatus` with durations (blocked=1, deprecated=3, segfaulted=3, linted=2, tilted=3, in_the_zone=3, spaghettified=2), `processStatusTick` (blocked skips turn, deprecated decays stats -3/turn, segfaulted 25% chance 10% max HP self-damage, tilted -20 accuracy, in_the_zone +30 power/-30 resolve), `isMoveBlockedByLint`, `rollStatusInflict`
- **catch.zig**: `attemptCatch` formula: base_rate + type_bonus - hp_penalty - rarity_penalty, min 5% floor. Type bonuses: breakpoint +15 vs debug, linter +15 vs chaos / -10 vs wisdom, formal_proof -30 vs chaos. HP penalty: (current_hp × 50) / max_hp. Rarity penalty: common=0, uncommon=10, rare=20, epic=35, legendary=50
- **ai.zig**: `chooseWildMoveSlot` — random non-null move slot selection
- **battle.zig**: `BattleState`, `BattleCritter` (wraps critter copy + species ptr + status), `BattleAction` (attack/swap/use_item/catch_attempt), `TurnResult` with event system (16 event types, max 16 per turn), `processTurn` flow: status ticks → turn order by speed (ties broken by RNG) → resolve both sides → check fainting
- **build.zig**: Named data modules (types, moves, species, items, critter, game_data, loader) with full dependency wiring so battle/ imports data types without `../` paths while preserving type identity
- 81 new tests (126 total), all passing
- Design decisions made: variance range 0.85–1.0, deprecated decays -3 per tick, segfaulted 25%/10% max HP, minimum 5% catch chance floor, status durations as listed above

## Phase 3 — Battle Screen [DONE]
- Full battle TUI in `src/ui/` — thin rendering layer over Phase 2 engine
- **battle_screen.zig**: 7-state menu system (main_menu, select_attack, select_swap, select_item, select_catch_tool, animating, battle_over), arrow key navigation, Enter/Space confirm, Escape backs out
- **colors.zig**: CritterType → RGB color mapping, HP bar color thresholds (green >50%, yellow 25-50%, red <25%)
- **text.zig**: BattleEvent → human-readable message formatting, status name display
- Layout: wild critter top-right, player bottom-left, each with 10×4 colored rectangle sprite, name/level/type badge, HP bar, status indicator. Separator, 4-line rolling message log, menu area below
- Turn events step through one-by-one on keypress (Pokemon-style drama)
- Forced swap when active critter faints with alive party members remaining
- Inventory system: `InventorySlot` struct with item pointer + count, submenus filter by item kind
- Test battle on startup: Println Lv10 + Goto Lv10 vs wild Glitch Lv8, 3× Print Statement + 2× Hotfix
- **build.zig**: battle engine exposed as named module (`battle_mod`), exe imports all data/battle modules for shared type identity. UI files use relative imports between themselves + named imports for data/battle/vaxis
- **Vaxis gotcha**: `printSegment` stores borrowed references to text — stack-local `bufPrint` buffers become dangling after helper functions return. Fixed with `writeText`/`writeFmt` helpers that write character-by-character using a comptime ASCII grapheme lookup table (static memory, no dangling pointers)
- 126 tests still passing (no new UI tests — battle_screen needs a live terminal)

## Phase 4 — Sprites [DONE]
- **sprite.zig**: SpriteSheet struct — loads PNG sprite sheets via zigimg (vaxis transitive dep), stores RGBA pixels, renders with two backends
- **Half-block renderer**: baseline for any truecolor terminal. Uses ▄/▀ with fg/bg color pairs — 2 vertical pixels per cell. 16×16 sprite = 16 cols × 8 rows. Handles transparency (alpha threshold 128)
- **Kitty graphics renderer**: uses vaxis `Image.draw` API with `clip_region` for frame selection. Auto-detected via `vx.caps.kitty_graphics` after `queryTerminal`. Falls back to half-block automatically
- **PNG sprite sheets**: 32×16 (2 frames side-by-side), generated by `tools/gen_sprites.py`. Frame 2 is 1px bounce up (idle animation). 5 critters: Println (terminal icon), Tracer (magnifying glass), Glitch (lightning zigzag), Goto (circular arrow), Monad (nested brackets)
- **SpriteMap**: simple ID→SpriteSheet lookup, passed to BattleScreen. Falls back to colored rectangle if no sprite found for a species
- **Animation**: frame cycling based on elapsed time (500ms interval). Main loop uses poll+drain architecture (`tryEvent` non-blocking) with 16ms sleep (~60fps) so animation runs smoothly without input
- **Layout updated**: sprite area now 16 cols × 8 rows (was 10×4), layout zones adjusted for larger sprites
- **zigimg access**: `vaxis.zigimg` — transitive dependency re-exported by vaxis. `Image.fromFilePath` + format-agnostic `iterator()` (Colorf32 → u8 RGBA conversion)
- **loadKittyImage**: separate method — loads kitty image after terminal capability detection, only if kitty_graphics supported
- 129 tests (3 new: pixel indexing, PNG loading round-trip, display size calculation)

## Phase 5 — Dungeon Engine (No UI) [DONE]
- Dungeon engine as pure game logic in `src/dungeon/` — no rendering, fully testable
- **floor_gen.zig**: 24x18 grid, `Tile` enum (wall/floor/encounter/stairs/entrance), `generateFloor(floor_number, rng)` — room-and-corridor algorithm placing 3-5 non-overlapping rooms connected by L-shaped corridors, encounter tiles scaled by depth (3 + floor/2, max 8), deterministic with seed. BFS `isReachable` for connectivity verification
- **biome.zig**: `Biome` struct with encounter table (weighted species + floor range), boss pool, shop bias. `rollEncounter` (weighted random with floor filtering), `rollBoss`, `encounterLevel` (3 + floor×2 ±1, capped at 50). JSON loading from `data/biomes.json`. One `generic_dungeon` biome using all 5 test species
- **shop.zig**: `ShopState` (up to 6 slots), `generateShop` (weighted random from biome shop_bias, prices scale +10%/floor), `buyItem` with currency deduction and stock tracking
- **dungeon.zig**: `DungeonState` (biome, floor, player position, party, currency, run inventory, catches, phase, outcome, RNG), `RunPhase` enum (exploring/encounter/boss_encounter/between_floors/run_over), `RunOutcome` (in_progress/extracted/wiped)
- **Key functions**: `startRun` (copies party, generates floor 1), `movePlayer` (returns MoveResult union: moved/blocked/encounter_triggered/stairs_reached/boss_triggered), `resolveEncounter` (decomposed params — no battle module import), `advanceFloor`, `extract`, `generateBetweenFloorShop`, `buyShopItem`, `addRunItem`, `alivePartyCount`
- **Battle integration**: dungeon engine does NOT import battle module. Caller bridges: movePlayer returns encounter info, caller runs battle, passes results back via resolveEncounter with decomposed params (outcome enum + updated party + optional catch info)
- **Boss floors**: every 5 floors (5, 10, 15...), boss from biome pool with level bonus. Boss win transitions to between_floors (double currency reward)
- **Encounter tiles**: consumed on step (become floor). Encounters roll species from biome table respecting floor range. Currency awarded: win = 10 + floor×5, catch = 5 + floor×3
- **DB schema additions**: `runs` (biome_id, floor_number, currency, outcome, seed, timestamps), `run_party` (slot, critter_id, current_hp), `run_inventory` (item_id, quantity), `run_catches` (species_id, level, floor_caught)
- **run_store.zig**: `saveRun`, `updateRun`, `endRun`, `saveRunPartySlot`, `saveRunCatch`, `saveRunInventoryItem`, `loadRun`, `loadRunParty`, `loadRunCatches`, `findActiveRun`, with full free functions
- **build.zig**: `dungeon_mod` with named data imports (types, species, items, critter, game_data). floor_gen.zig tested standalone (no deps). Biome/shop/dungeon tested with data imports. run_store.zig tested with zqlite+critter
- Design decisions: 24×18 grid, room+corridor generation, encounter density 3+floor/2, level formula 3+floor×2±1, currency 10+floor×5 per win, 1 biome (generic_dungeon) for Phase 5
- 190 tests (61 new: 6 floor_gen, 6 biome, 5 shop, 12 dungeon including full-run simulation, 7 run_store, plus 25 from dungeon.zig test helpers used across tests)
