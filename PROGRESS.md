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

## Phase 6 — Dungeon Screen [DONE]
- Full dungeon exploration TUI wired to battle engine — first playable game loop
- **dungeon_screen.zig**: DungeonScreen renders 24×18 tile map centered in terminal. Tiles: wall `█` (dark gray), floor `·` (dim), encounter `!` (yellow), stairs `>` (green), entrance `<` (blue), player `@` (bold white). Manhattan-distance fog of war (radius 5): visible=full color, explored=dimmed ~40%, unseen=black. HUD shows floor number, currency, party HP summary. Message log and controls hint below map
- **shop_screen.zig**: ShopScreen for between-floors phase. Shows shop items with prices/quantities, party status with HP, currency. Cursor selection + Enter to buy, `c` to continue to next floor, `e` to extract and end run. Buy results shown as messages
- **main.zig rewrite**: `ActiveScreen` enum (dungeon/battle/shop/run_over) replaces hardcoded battle. Screen transition logic:
  - Dungeon→Battle: encounter/boss triggers build inventory bridge (RunItem→InventorySlot via GameData lookup), create BattleCritter party from dungeon state, init BattleState
  - Battle→Dungeon: extract updated Critter values from BattleCritter, sync consumed inventory counts, call resolveEncounter with decomposed params. Boss win→shop, wipe→run_over
  - Dungeon→Shop: stairs reached, generateBetweenFloorShop, init ShopScreen
  - Shop→Dungeon: advanceFloor, resetVisited (clears fog for new floor)
  - Shop→RunOver: extract, show summary
- **Inventory bridge**: stack-allocated InventorySlot array built before battle by resolving RunItem.item_id→*const Item. Pre-battle counts saved. Post-battle: diff counts, subtract consumed from run_inventory
- **Run over screen**: renderRunOver shows outcome (extracted/wiped), floors cleared, currency, catches list. Any key exits
- **Fog of war**: visited[][] bool array per floor, updateVisited marks tiles within Manhattan distance 5 of player. resetVisited on floor advance
- 190 tests still passing (no new UI tests — screens need live terminal)

## Phase 7 — Party & Roster Management [DONE]
- Metagame layer: XP/leveling, evolution, move disc equipping, hub menu, party selection, roster viewer
- **leveling.zig**: XP/leveling as pure functions. `xpForLevel(level) = level² × 10` (quadratic curve). `battleXpAward(enemy_level, is_boss)` = `10 + level × 3` (doubled for bosses). `awardXp(critter, amount, game_data) → LevelUpResult` — loops level-ups, recomputes stats, checks evolution per level. Evolution: when `critter.level >= species.evolution_level`, updates species_id, recomputes stats from new species, sets signature/secondary moves
- **equip.zig**: `equipMoveDisc(critter, item) → EquipResult` — validates item is move_disc kind, sets slot 3
- **critter.zig changes**: `calcStat` made `pub`, added `recomputeStats(self, species)` — recalculates all stats proportionally (preserves damage taken)
- **roster.zig addition**: `removeInventoryItem(db, item_id, quantity)` for consuming move discs
- **hub_screen.zig**: Main menu screen — New Run / View Roster / Quit. Centered layout, shows roster count. Game starts here instead of going straight to dungeon
- **party_select_screen.zig**: Load roster from DB, pick 1-3 critters. Toggle selection with Enter, confirm with C, escape to go back. Shows name/level/type/HP per critter. Cooldown critters visible but unselectable. Scrollable list
- **roster_screen.zig**: Detail view for one critter at a time, Left/Right to cycle. Shows: name, level, type badge, XP progress, stats with scar adjustments in red, all 3 move slots with type/power/accuracy, cooldown timer, scar count. Sub-mode: press D to equip move disc from inventory overlay (Up/Down pick, Enter equip, Esc cancel). Pending equip events persisted to DB by main.zig
- **main.zig rewrite**: `ActiveScreen` expanded to 7 states (hub/party_select/roster_view/dungeon/battle/shop/run_over). Game flow: hub → party_select → dungeon → battle ↔ shop → run_over → hub. Post-battle XP: surviving party members awarded XP, level-ups/evolutions applied, species pointers updated, critters saved to DB. Catches persisted on extraction (new Critter created from species+level, saved to roster). Starter seeding: empty roster gets Println Lv5 + Goto Lv5. Run over returns to hub (not quit)
- **dungeon_screen.zig**: Added `pending_is_boss` flag for boss XP calculation
- **build.zig**: `leveling_mod` and `equip_mod` registered as named modules with appropriate imports. Test entries added for both
- Design decisions: XP curve level²×10, XP award 10+level×3, evolution immediate on level-up, move disc always slot 3 (replaces existing), starter critters Lv5
- 203 tests (13 new: 9 leveling/evolution, 4 equip)

## Phase 8 — Catch System & Inventory [DONE]
- Completes item/catch loop: all 5 catch tiers, item drops, Try-Catch penalty, inventory persistence, hub inventory screen, heal target selection
- **items.json**: Added Linter (tier 4, 50% base, $500) and Formal Proof (tier 5, 70% base, $800) catch tools. Now 10 items total
- **biomes.json**: Added `drop_table` array per biome (7 items, weighted). Added Linter/Formal Proof to shop_bias
- **biome.zig**: `rollDrop(biome, floor, is_boss, rng)` — base 40% chance +3%/floor (cap 70%), boss guaranteed. Weighted random from drop_table
- **dungeon.zig**: `resolveEncounter` now returns `EncounterResult { dropped_item_id }`. Rolls drops on win/catch, adds to run_inventory
- **battle.zig**: Try-Catch failure mechanic — failed catch with `.try_catch` tier tool triggers free retaliatory wild attack. New `catch_retaliation` event with move name and damage. `resolveCatch` now takes `game_data` param
- **text.zig**: Added formatting for `catch_retaliation` event: "It broke free and attacked with [move]! [N] damage."
- **roster.zig**: `getCurrency(db)` / `addCurrency(db, amount)` using meta table key-value. Currency persists across runs
- **main.zig**: `persistRunInventory` saves run items + currency to DB on extraction (both battle and shop paths). Drop notification pushed to dungeon log ("Found a [item]!")
- **hub_screen.zig**: Added "Inventory" menu option (4 items: New Run/View Roster/Inventory/Quit). Currency displayed on hub: "Roster: N critters | $N"
- **inventory_screen.zig** (new): Hub inventory viewer grouped by category (Catch Tools, Healing Items, Move Discs). Shows quantity + extra info (catch rate %, heal amount). Currency display. Up/Down navigate, Esc back
- **battle_screen.zig**: Healing target selection — new `select_heal_target` menu state. Item → select healing item → select party member (all alive, including active). Shows HP bars per target. Esc restores item and returns to item list
- Design decisions: drop chance 40%+3%/floor (boss guaranteed), currency in meta table, no selling from hub (only in dungeon shops), wipe = lose all run items/currency
- 207 tests (4 new: currency round-trip, Try-Catch retaliation, rollDrop, drop_table load)

## Phase 10 — Death, Scarring & Persistence [DONE]
- Consequence system: scars, run-based cooldowns, revive item, effective stats
- **critter.zig**: `effectiveStat(stat)` returns base stat minus accumulated scar penalties (floored at 1). `baseStat(stat)` switch for field access by StatKind. `StatKind.displayName()` for UI. `cooldown_until: ?i64` replaced with `cooldown_runs: u8` (run-based, not time-based)
- **battle.zig**: All stat reads use `effectiveStat` — speed (turn order), logic/resolve (damage calc), max HP (healing cap, status ticks, catch rate). Revive handling in `resolveItem`: `.revive` kind restores fainted critter to `revive_percent`% of effective max HP. `revive_used: bool` on BattleState limits 1 revive per battle
- **items.zig**: Added `revive` to `ItemKind`, `revive_percent: ?u8` field. Git Revert item (50% revive, $300)
- **dungeon.zig**: `PendingScar` struct + `pending_scars[16]` on DungeonState. `resolveEncounter` compares pre/post battle HP — critters that went from alive to fainted get a random stat scar. Already-fainted critters don't double-scar
- **main.zig**: `persistPendingScars` writes scars to DB at run end (both extraction and wipe). On wipe: all party critters get `cooldown_runs = 2`. `decrementCooldowns` runs at each new run start — decrements all roster critters with cooldown, full HP heal when cooldown expires
- **battle_screen.zig**: Unified item/party filter helpers — `countItems(filter)`/`getNthItem(filter, n)` with `?ItemKind` (null = usable items). `countPartyByHp(want_fainted)`/`getPartyTarget(want_fainted, idx)`. Single `renderItemList` for both usable items and catch tools. Revive items show fainted targets, grayed out after use
- **party_select_screen.zig**: `isOnCooldown` checks `cooldown_runs > 0`. Shows run count: "[COOLDOWN 2 run(s)]"
- **roster_screen.zig**: Stats display uses `effectiveStat` (shows effective values, scar notes show penalty). Cooldown shows run count instead of minutes
- **Run over screen**: Shows scar summary (species + stat penalized) and cooldown warning on wipe
- Design decisions: scars per-faint (checked at battle end, revive avoids scar), cooldown = 2 runs (not time-based), 1 revive per battle, extraction keeps scars but no cooldown, wipe adds cooldown to all party members
- 222 tests (15 new: effective stat with scars, floor at 1, scar generation on faint, no double-scar)

## Phase 11 — Passive Layer [DONE]
- Passive XP/item system rewarding real coding work via CLI subcommands (no MCP server — descoped in favor of CLI + hooks + Claude Code skill in separate repo)
- **db.zig**: Added `events` table (id, event_type, timestamp, processed). Added `PRAGMA busy_timeout=3000` for concurrent CLI+TUI access
- **passive_store.zig** (new): `logEvent`, `loadUnprocessedEvents`, `freeEvents`, `markEventsProcessed`, `countUnprocessedEvents`, `getFavoriteCritterId`, `setFavoriteCritterId` — follows roster.zig pattern, uses settings table for favorite
- **passive.zig** (new, `src/passive/`): Pure reconciliation engine. `reconcile(events, critter, game_data, seed) → ReconcileResult` — awards XP (5 per event via `leveling.awardXp`), rolls items (per 20 events, 30% chance from loot table: small_patch, print_statement, hotfix). No DB imports — caller handles persistence
- **CLI subcommands** in main.zig: arg parsing via `std.process.argsWithAllocator` before TUI setup
  - `codecritter log-event <type>` — logs event to DB (DB-only, fast, called by Claude Code hooks)
  - `codecritter set-favorite <id>` — sets which critter earns passive XP (validates critter exists)
  - `codecritter status` — outputs JSON: favorite critter info, roster summary, pending event count
  - `codecritter statusline` — outputs compact one-liner: `Println Lv12 ♥45/54`
  - No args — launches TUI as before
- **recap_screen.zig** (new): "While you were coding..." screen showing XP gained, level-ups, items found, event count. Any key dismisses to hub
- **main.zig integration**: `runReconciliation` at TUI startup loads unprocessed events, runs passive.reconcile, persists critter/items/events, auto-selects first roster critter as favorite if none set. `recap` added to `ActiveScreen` enum with full input/transition/render wiring
- **writeOut helper**: `bufPrint` + `std.fs.File.stdout().writeAll()` for CLI output (Zig 0.15 stdout API)
- Design decisions: MCP server descoped (CLI subcommands + external hooks/skills instead), favorite critter managed via CLI (not game UI), cooldown critters still earn passive XP, max-level critters get 0 XP but still roll items, XP_PER_EVENT=5, EVENTS_PER_ITEM_ROLL=20, ITEM_FIND_CHANCE_PCT=30
- 234 tests (12 new: 5 passive_store, 6 passive engine, 1 schema)

## Phase 12 — Complete Starter Evolution Chains [DONE]
- All 3 starter lines now complete (9 species total across 3 chains)
- **DEBUG chain**: Println → Tracer → Profiler (Uncommon, hp=75/logic=95/resolve=65/speed=85)
- **CHAOS chain**: Glitch → Gremlin (Common, hp=50/logic=80/resolve=45/speed=75) → Pandemonium (Uncommon, hp=60/logic=100/resolve=50/speed=110)
- **LEGACY chain**: Goto → Spaghetto (Common, hp=65/logic=55/resolve=70/speed=60) → Dependency (Uncommon, hp=100/logic=60/resolve=95/speed=65)
- **4 new moves**: null_deref (chaos 55/90, segfaulted 20%), heap_profile (debug 85/85, linted 25%), kernel_panic (chaos 90/75, segfaulted 25%), vendor_lock (legacy 80/85, deprecated 30%). Spaghetto reuses tech_debt as secondary
- **Stat design**: mid evos ~250 total, finals ~320 total. Type themes preserved (CHAOS: glass cannon high logic+speed, LEGACY: tank high hp+resolve)
- **Evolution levels**: Gremlin evolves at Lv30→Pandemonium, Spaghetto at Lv28→Dependency, Tracer at Lv28→Profiler (already set)
- **5 new sprites**: profiler (flame graph), gremlin (imp with horns), pandemonium (explosion fragments), spaghetto (tangled lines), dependency (inverted tree). Generated via updated gen_sprites.py
- **Biome encounters updated**: all 3 biomes (generic_dungeon, pythonic_caves, node_abyss) now include mid evos on floor 4-5+ and finals on floor 7-8+. Profiler added to generic_dungeon boss pool, Pandemonium to node_abyss boss pool
- **main.zig**: sprite_ids expanded from 10 to 15 entries
- Data totals: 15 species, 16 moves, 3 biomes
- 234 tests passing (2 updated: biome encounter count, evolution missing-target test now uses monad→functor)

## Phase 13 — Title Screen + Screen Transitions [DONE]
- See commit history for details

## Phase 13.5 — Graphics Engine Layer [DONE]
- See commit history for details

## Phase 14 — Bug Fixes: Death Logic + Cooldown Blocking + XP [DONE]
- **Death logic fix**: `startBattle()` no longer compact-packs party, preserving fainted critters at their original indices. `initBattle()` sets `player_active` to first alive critter. Battle screen forced-swap kicks in when active critter faints but others remain.
- **Cooldown blocking fix**: `decrementCooldowns()` moved to before `PartySelectScreen` creation (on entering "New Run"), preventing deadlock when all critters are on cooldown.
- **XP persistence fix**: All `catch {}` in persistence functions (`savePartyState`, `persistCatches`, `persistPendingScars`, `persistRunInventory`, `decrementCooldowns`, equip handler) replaced with `catch |err| { std.log.err(...) }` for visibility. Death logic index fix also resolves potential `run_party_ids` mapping drift.
- **Hub inventory item use**: `InventoryScreen` now interactive — press Enter on healing/revive items to select a target critter. Two-step flow: browse → select target → apply effect. Healing restricted to alive critters below max HP; revive restricted to fainted critters. Item consumption persisted to DB. Separate rendering for target selection mode.
- 3 new tests: initBattle with fainted party member, checkPlayerLoss with one alive, checkPlayerLoss with all fainted
