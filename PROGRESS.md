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

## Phase 15 — Dungeon Quick Menu + In-Dungeon Item Use [DONE]
- **Quick menu**: Press `m` during dungeon exploration to open overlay with Items / Party / Close options. Uses `widgets.renderMenu` + `input.applyCursor` for consistent UX.
- **In-dungeon item use**: "Items" transitions to existing `InventoryScreen` populated from `run_inventory`. Item effects (healing/revive) applied directly to `dungeon_state.party` — no DB persistence during runs. Run inventory decremented on use.
- **In-dungeon party view**: "Party" transitions to existing `RosterScreen` showing dungeon party (read-only, disc equipping disabled via empty inventory).
- **Screen reuse pattern**: `from_dungeon` flag in main.zig routes inventory/roster return transitions back to dungeon instead of hub. `compactDungeonParty` helper converts sparse `party[3]?Critter` to compact arrays for screen init, with sparse index mapping for copy-back.
- **dungeon_screen.zig**: Added `MenuMode` enum (exploring/quick_menu), `pending_inventory`/`pending_roster` transition flags. Hint text shows `[m] Menu`.
- **main.zig**: Handles dungeon→inventory/roster transitions (run_inventory→InventoryEntry conversion, party compaction). Inventory return applies HP changes via index mapping and decrements run_inventory. Roster return is a simple transition back.
- 234 tests passing (no new tests — feature is UI-only screen wiring)

## Phase 16 — Bug Fixes: Battle Priority + Speed Death Logic [DONE]
- **Fainted critter guard**: Added HP checks in `processTurn` (`src/battle/battle.zig:335,350`) so the second actor in turn order cannot act if KO'd by the first. Previously, when the wild critter was faster and killed the player's active critter (but other party members survived), `state.outcome` stayed null and the fainted critter still resolved its attack.
- **Item/catch/swap priority**: Items, catch attempts, and swaps now have priority over attacks — they always resolve before the wild's attack move, regardless of speed. Speed-based ordering only applies to attack-vs-attack turns.
- 2 new tests: fainted critter doesn't act after KO; item use has priority even when player is slower
- 236 tests passing

## Phase 17 — Roster Swap, Party Reorder, Inventory Detail [DONE]
- **Roster swap** (`src/ui/roster_screen.zig`): Press S to enter swap mode, select two critters to exchange positions. Persisted via `sort_order` column in critters table.
- **Party reorder** (`src/ui/party_select_screen.zig`): Press S during party selection to swap selected slot positions, reordering the run party.
- **Inventory detail panel** (`src/ui/inventory_screen.zig`): Two-panel layout — item list on left, detail pane on right showing rarity-colored indicators, item descriptions, effect details, move disc stats (type/power/accuracy), buy/sell prices.
- **Rarity enum** moved from `species.zig` to `types.zig` for shared use by both species and items.
- **DB migration** (`src/db/db.zig`): Schema v2 adds `sort_order` column to critters table.
- **Files changed**: `data/items.json`, `src/data/items.zig`, `src/data/species.zig`, `src/data/types.zig`, `src/db/db.zig`, `src/db/roster.zig`, `src/main.zig`, `src/ui/colors.zig`, `src/ui/inventory_screen.zig`, `src/ui/party_select_screen.zig`, `src/ui/roster_screen.zig`, `src/ui/theme.zig`

## Phase 18 — Game Event Loop Engine [DONE]
- **ScreenResult tagged union** (`src/ui/screen_result.zig`): Unified transition type replacing per-screen flags (done, selection, pending_*, extracted, etc.). Every screen's `handleInput` now returns `?ScreenResult` instead of `void`. Variants: `goto_hub`, `goto_party_select`, `goto_roster(ScreenContext)`, `goto_inventory(ScreenContext)`, `goto_dungeon`, `goto_battle(BattleRequest)`, `goto_shop`, `goto_run_over`, `start_extraction`, `persist_swap`, `persist_equip`, `persist_item_use(ItemUseRequest)`, `quit`.
- **ScreenContext enum** (`from_hub`/`from_dungeon`): Replaces the old `from_dungeon: bool` flag in main.zig. Context carried in the result itself, not ambient mutable state.
- **Unified InventoryEntry** (`src/ui/ui_common.zig`): Three duplicate `InventoryEntry` types (RosterScreen, InventoryScreen, ad-hoc in main.zig) consolidated into one shared type.
- **RunOverScreen** (`src/ui/run_over_screen.zig`): Promoted from inline `renderRunOver` function + `run_over_dirty` bool to proper screen struct with `handleInput`/`render`/`dirty`.
- **Dead field cleanup**: Removed ~12 dead state fields across 8 screens (`done`, `selection`, `confirmed`, `pending_swap`, `pending_equip`, `use_result`, `pending_battle`, `pending_is_boss`, `pending_shop`, `pending_inventory`, `pending_roster`, `extracted`) plus dead type definitions (`HubChoice`, `DiscEquipEvent`, `SwapEvent`, `ItemUseResult`).
- **333-line transition switch eliminated**: The old `if (transition_pending == null) switch (active_screen)` block (checking per-screen flags) is gone. All transition logic now co-located with input handling in the input dispatch switch.
- **from_dungeon flag removed**: Was a form of temporal coupling. Context now flows through ScreenResult.
- Design grounded in: Ousterhout (deep modules — uniform interface), Raymond (nothing left to take away — unified types), Gabriel (Worse is Better — simple tagged union, no vtables)
- 236 tests passing, no new tests (architecture refactor, not new behavior)

## Phase 19 — Revive Cooldown Fix + Item Packing [DONE]
- **Critter.applyRevive()** (`src/data/critter.zig`): Consolidated revive logic into single method. Restores HP to percent of max AND resets `cooldown_runs` to 0. Previously revive code was duplicated in `inventory_screen.zig` and `battle.zig` — both restored HP but neither cleared cooldown, leaving revived critters unavailable.
- **Item packing on party select** (`src/ui/party_select_screen.zig`): Tab-based UI — press `I` or `Tab` to switch between party selection and item packing. Items tab shows persistent inventory with toggle markers `[*]/[ ]`. Up to 6 distinct item stacks can be packed (full quantity each). Packed items summary shown at bottom.
- **Dungeon run seeding** (`src/dungeon/dungeon.zig`): `startRun()` now accepts `initial_items: []const RunItem` parameter. Packed items populate `run_inventory` at run start. Items are removed from persistent DB on run confirmation — lost on wipe (roguelike risk), returned on successful extraction (existing behavior).
- **main.zig integration**: Loads persistent inventory before party select. On dungeon confirm, extracts packed items, removes from DB via `roster_db.removeInventoryItem()`, resolves item_id through `game_data.findItem()` for stable string pointers. Extracted `reloadInventory()` helper to deduplicate 3 identical free-load-copy blocks.
- **Simplify pass**: Fixed scroll not persisting between frames (`scroll_offset`/`item_scroll` written back to struct), fixed stale doc comment on `isAvailable()`, fixed latent u16 overflow in `applyRevive()` (intermediate widened to u32).
- 236 tests passing

## Phase 20 — CLI Enhancements: JSON + Statusline Sprite [DONE]
- **Enriched `status` command** (`src/main.zig`): Full JSON output with detailed favorite critter (stats with base/effective values, equipped moves resolved to name/type/power/accuracy, scars list, XP + XP to next level, cooldown status), roster summary (count, on_cooldown), persistent currency, active run state (biome, floor, currency) or null, pending events count. Uses `ArrayList(u8)` writer for dynamic-length output.
- **New `roster` subcommand** (`src/main.zig`): Dumps entire roster as JSON array, each critter with same detail level as `status` favorite. Uses shared `writeCritterJson` helper.
- **`statusline` sprite rendering** (`src/main.zig`, `src/ui/sprite.zig`): `statusline` now loads the favorite critter's PNG sprite and renders it to stdout using ANSI 24-bit color escape codes via new `SpriteSheet.renderToAnsi()` method. Info text (name, level, HP) positioned to the right of the sprite on the middle row. Falls back to plain text if sprite not found.
- **`renderToAnsi`** (`src/ui/sprite.zig`): New public method on `SpriteSheet` — same half-block technique as the TUI renderer but outputs `\x1b[38;2;R;G;Bm` / `\x1b[48;2;R;G;Bm` ANSI escapes instead of vaxis cells. Returns allocator-owned string. Transparent pixels rendered as spaces.
- **Files changed**: `src/main.zig`, `src/ui/sprite.zig`, `AGENT_INSTRUCTIONS.md`, `PROGRESS.md`
- 236 tests passing (no new tests — CLI output is integration-level)

## Phase 21 — Three-Stage Evolution Lines (All 7 Types) [DONE]
- **+15 species** (`data/species.json`): Second 3-stage chain per type (common→common→uncommon): Printf→Fprintf→Logstash (debug), Segfault→Stack Overflow→Kernel Panic (chaos), Singleton→God Object→Monolith (patience), Mutex→Semaphore→Deadlock (legacy), Monad→Functor→Burrito (wisdom), LGTM→Nitpick→Bikeshed (snark), Copilot→Autopilot→Hallucination (vibe). Total species: 15→30.
- **+16 moves** (`data/moves.json`): Type-themed moves for new chains. Total moves: 16→32.
- **+20 sprites** (`tools/gen_sprites.py`, `assets/sprites/`): All new species + refreshed existing sprites. Total sprites: 10→30.
- **2 new status effects** (`src/battle/status.zig`): Enlightened (wisdom, -resolve) and Hallucinating (vibe, -accuracy).
- **Biome encounter updates** (`data/biomes.json`): All three dungeon biomes updated with new species across floor gates.
- **Files changed**: `data/species.json`, `data/moves.json`, `data/biomes.json`, `src/battle/status.zig`, `src/data/leveling.zig`, `src/data/moves.zig`, `src/dungeon/biome.zig`, `src/ui/sprite.zig`, `src/ui/text.zig`, `tools/gen_sprites.py`, `assets/sprites/*.png`

## Phase 22 — Four New Biomes + Detection [DONE]
- **Expanded `detect.zig`** (`src/dungeon/detect.zig`): Added scoring for Rust (.rs, Cargo.toml/Cargo.lock), Go (.go, go.mod/go.sum), C (.c/.h, Makefile/CMakeLists.txt/meson.build), and Shell (.sh/.bash/.zsh). Winner selection uses array of (score, biome_id) tuples — highest score wins, tie-break order: python > node > rust > go > c > shell. Removed early-exit optimization (single-dir iteration fast enough).
- **4 new biomes** (`data/biomes.json`): Rustacean Depths (debug/patience, orange/copper theme), Gopher Tunnels (patience/wisdom, cyan/teal theme), C Catacombs (legacy/chaos, dark gray/red theme), Shell Scripts (snark/chaos, terminal green theme). Each with full encounter table (~14 species, floor-gated), 4-boss pool, shop bias, and drop table.
- **6 new detection tests**: Each new biome detection, tie-break priority, and score-beats-tiebreak.
- **Files changed**: `src/dungeon/detect.zig`, `data/biomes.json`, `PROGRESS.md`

## Phase 23 — Two-Stage Lines + Standalone Rares [DONE]
- **+21 species** (`data/species.json`): 7 uncommon→rare two-stage evolution lines (Breakpoint→Watchpoint, Fuzzer→Chaos Monkey, Queue→Priority Queue, Hashmap→B-Tree, TODO→FIXME, README→No Tests, Makefile→Jenkins) + 7 standalone rares (Heisenbug, Bobby Tables, Cron, Rubber Duck, 404, YOLO, COBOL). All evolve at level 32. Stat totals: uncommon bases ~285-290, rare evolutions ~340-365, standalone rares ~355-360.
- **+10 moves** (`data/moves.json`): Breakpoint Set, Memory Watch, Observer Effect (debug); Fuzz Input, Process Kill, SQL Injection (chaos); Priority Boost, Cron Job (patience); Rebalance, Explain Yourself (wisdom). SNARK/VIBE/LEGACY reuse existing moves.
- **Biome encounter updates** (`data/biomes.json`): All 7 biomes updated with new species in encounter tables (uncommons at weight 3, floor 7+; rares at weight 1-2, floor 10+) and boss pools (+2 rare bosses per biome).
- **+21 sprites** (`tools/gen_sprites.py`, `assets/sprites/`): All new species have 32x16 2-frame sprite sheets using type color schemes.
- **Totals**: 51 species, 42 moves, 52 sprites (including title.png), 7 biomes.
- **Files changed**: `data/species.json`, `data/moves.json`, `data/biomes.json`, `tools/gen_sprites.py`, `assets/sprites/*.png`, `PROGRESS.md`, `AGENT_INSTRUCTIONS.md`

## Phase 24 — Epics + Legendaries + Sound Cues [DONE]
- **+7 epic species** (`data/species.json`): One per type with stats reflecting drawbacks (no engine hooks yet). Valgrind (debug, SPD=15), Race Condition (chaos, fragile glass cannon), Load Balancer (patience, LGC=30), Turing Machine (wisdom, slow), Regex (snark, power=120/acc=50 signature), Prompt Engineer (vibe, LGC=5), Mainframe (legacy, HP=200/SPD=5). BST ~390, extreme stat distributions.
- **+3 legendary species**: Root (legacy, BST=450, signature=Sudo), Zero Day (chaos, BST=450, SPD=160), Linus (wisdom, BST=440, signature=Revert). Not in encounter tables — milestone-locked (acquisition TBD).
- **+8 moves** (`data/moves.json`): Memory Scan (debug 95/90), Data Race (chaos 100/65), Regex Match (snark 120/50, highest power in game), Prompt (vibe 0/100, always applies in_the_zone), Core Dump (legacy 110/70), Sudo (legacy 90/90), Zero Day Exploit (chaos 100/85), Revert (wisdom 75/95). Load Balancer and Turing Machine reuse existing moves as signatures.
- **Biome encounter updates** (`data/biomes.json`): 7 epics added to 1-2 biomes each at weight=1, min_floor=12 (deeper than rares). Legendaries excluded from all tables.
- **+10 sprites** (`tools/gen_sprites.py`, `assets/sprites/`): All 10 new species have 32x16 2-frame sprite sheets.
- **BEL sound system** (`src/ui/sound.zig`): New module with `beep()` writing `\x07` to stdout. Emits on: battle start, critter fainted, successful catch, super-effective hit, level up, evolution.
- **Sprite capacity** (`src/ui/sprite.zig`): MAX_SPRITES bumped from 64 to 72.
- **Totals**: 61 species (full roster complete), 50 moves, 62 sprites (including title.png), 7 biomes.
- **Files changed**: `data/species.json`, `data/moves.json`, `data/biomes.json`, `tools/gen_sprites.py`, `assets/sprites/*.png`, `src/ui/sound.zig`, `src/ui/battle_screen.zig`, `src/ui/sprite.zig`, `src/main.zig`, `PROGRESS.md`, `AGENT_INSTRUCTIONS.md`

## Phase 24.5 — Bug Fix: Item Equip SQL Error [DONE]
- **zqlite MultipleStatements fix** (`src/db/roster.zig`): Split two-statement SQL in `removeInventoryItem` (UPDATE + DELETE) into separate `exec()` calls — zqlite rejects multi-statement strings.
- **Simplified equip persistence**: Replaced full `saveCritter` with targeted `updateCritterMove3` for disc equipping, removing unnecessary allocator plumbing from `RosterScreen`.
- **UI sync**: Roster/inventory reloaded after equip to keep screens in sync with DB.

## Phase 25 — Kitty-First Graphics Overhaul [DONE]
- **FX engine** (`src/ui/fx.zig`): Brogue-style dancing colors (3× sine with per-cell phase offsets), smooth light attenuation (inverse-square falloff), pulsing/breathing color effects, color tinting/blending. All pure functions, no state.
- **Tileset system** (`src/ui/tileset.zig`): Sprite-sheet sub-rectangle renderer with `TileIndex` enum (wall/floor/encounter/stairs/entrance). Loads tileset PNGs, renders individual tiles at brightness levels. Kitty graphics protocol support via image placement IDs.
- **Biome backgrounds** (`src/ui/biome_background.zig`): Per-biome background images loaded via Kitty graphics protocol, rendered as z-indexed underlays beneath dungeon maps.
- **Battle animation sequencer** (`src/ui/battle_anim.zig`): Multi-step animation pipeline: slide → effect → flash → shake. `BattleAnimSequencer` drives timed sequences from battle events, with skip support (Space/Enter). Per-step timing: slide 8 ticks, effect 12 ticks, flash 6 ticks, shake 8 ticks.
- **Effect sprites** (`src/ui/effect_sprites.zig`): Per-type animated effect sprites (7 types) for battle attack animations. Loaded from `assets/effects/` PNGs, rendered at target position during effect phase.
- **Screen transitions** (`src/ui/transition.zig`): Fade-to-black, wipe-left, and dissolve transitions between screens. `pickTransition` selects style based on source→destination pair. Replaces old instant cut-to-black.
- **Dynamic floor sizing** (`src/dungeon/floor_gen.zig`): `generateFloorSized` accepts width/height parameters, scaling room count, room sizes, and encounter density with floor area. `Floor` struct carries `width`/`height` fields. Max buffer 200×60, default 80×35. Dungeon fills terminal (minus HUD).
- **Enhanced dungeon rendering** (`src/ui/dungeon_screen.zig`): Position-based tile character variation (3 wall glyphs: █▓▒, 3 floor glyphs: ·∘⋅), dancing colors on all visible tiles, smooth lighting attenuation from player position, visibility radius increased to 8. Kitty path: tileset tiles with brightness. Unicode fallback: textured walls + varied floors.
- **Hub screen polish** (`src/ui/hub_screen.zig`): Per-character dancing color title, breathing subtitle, favorite critter sprite with animation, box-drawing border.
- **Title screen polish** (`src/ui/title_screen.zig`): Breathing subtitle, floating critter sprite (y-oscillation), pulsing hint text.
- **Shop screen polish** (`src/ui/shop_screen.zig`): Box-drawing border, thin separator, rarity-colored item names.
- **Recap/RunOver borders** (`src/ui/recap_screen.zig`, `src/ui/run_over_screen.zig`): Colored box borders (green for recap, green/red for extraction/wipe).
- **Battle screen enhancements** (`src/ui/battle_screen.zig`): Sprite position animation (slide offsets), flash overlay, shake effect, effect sprite rendering during attacks. `move_type` added to `DamageDealtEvent` for type-specific effects.
- **Easing functions** (`src/ui/anim.zig`): `easeOutQuad`, `easeInOutCubic`, `lerp`, `lerpI16` for animation curves.
- **Shared widgets** (`src/ui/widgets.zig`): `renderColorBorder` and `renderThinSeparator` extracted from 4+2 duplicate implementations across screens.
- **+21 placeholder assets**: 7 biome backgrounds (`assets/backgrounds/`), 7 biome tilesets (`assets/tiles/`), 7 type effect sprites (`assets/effects/`).
- **Files changed**: `src/ui/fx.zig`, `src/ui/tileset.zig`, `src/ui/biome_background.zig`, `src/ui/battle_anim.zig`, `src/ui/effect_sprites.zig`, `src/ui/transition.zig`, `src/ui/kitty_manager.zig`, `src/ui/widgets.zig`, `src/ui/anim.zig`, `src/ui/battle_screen.zig`, `src/ui/dungeon_screen.zig`, `src/ui/hub_screen.zig`, `src/ui/title_screen.zig`, `src/ui/shop_screen.zig`, `src/ui/recap_screen.zig`, `src/ui/run_over_screen.zig`, `src/dungeon/dungeon.zig`, `src/dungeon/floor_gen.zig`, `src/battle/battle.zig`, `src/main.zig`, `build.zig`, `tools/gen_placeholders.py`, `assets/backgrounds/`, `assets/effects/`, `assets/tiles/`, `AGENT_INSTRUCTIONS.md`

## Phase 27 — Meta Shop + Meta Progression HUD [DONE]
- **Meta upgrades** (`src/ui/meta_upgrades.zig`): 3 convenience upgrades — Extra Pack Slots (base 6 + level, max +4), Starting Funds (0/50/100/200 per run), Species Codex (unlock at Lv1). Stat key constants (`STAT_TOTAL_RUNS`, `STAT_DEEPEST_FLOOR`, etc.) for type-safe DB access.
- **Meta shop screen** (`src/ui/meta_shop_screen.zig`): Purchase upgrades with lifetime currency. Shows current level, cost for next, max indicator. Message log for feedback.
- **Species Codex screen** (`src/ui/codex_screen.zig`): Scrollable species list with discovered/undiscovered state. Checkmark + name/type/rarity for discovered, `???` for unknown. Discovery state cached in bool array at init (no per-frame DB queries).
- **Lifetime stats HUD** (`src/ui/hub_screen.zig`): Runs, deepest floor, catches, species discovered, bosses defeated — shown below menu on hub screen.
- **DB layer** (`src/db/roster.zig`): `spendCurrency`, `getMetaUpgradeLevel`, `purchaseMetaUpgrade`, `getMetaStat`, `incrementMetaStat`, `updateMetaStatMax`, `setMetaFlag`, `countMetaKeysWithPrefix`, `isSpeciesDiscovered`, `markSpeciesDiscovered`. Shared `metaKey` helper for prefixed key construction.
- **Stat tracking hooks** (`src/main.zig`): Run start, floor advance, battle outcomes (catches, boss defeats, species discovery), currency earned on extraction.
- **Dynamic hub menu** (`src/ui/hub_screen.zig`): Menu items built conditionally — Codex only appears when unlocked. `buildMenu()` returns items + action mapping.
- **Pack slot upgrade** (`src/ui/party_select_screen.zig`): `initWithPackLimit` accepts dynamic pack limit from meta upgrade level.
- **Battle name truncation** (`src/ui/battle_screen.zig`): `writeTextTruncated` helper in `ui_common.zig` for long critter names with `..` suffix.
- **Small-terminal guards** (`src/ui/recap_screen.zig`, `src/ui/run_over_screen.zig`, `src/ui/title_screen.zig`): `layout.tooSmall` checks on screens that were missing them.
- **Simplify pass**: Extracted `renderDancingTitle` widget (3 duplicates → 1), stat key constants (10 inline strings → constants), `metaKey` helper (5 duplicates → 1), moved species discovery SQL from UI to DB layer.
- **+5 DB tests**: `spendCurrency`, `purchaseMetaUpgrade`, `incrementMetaStat`/`updateMetaStatMax`, `setMetaFlag`/`countMetaKeysWithPrefix`.
- **Files changed**: `src/ui/meta_upgrades.zig`, `src/ui/meta_shop_screen.zig`, `src/ui/codex_screen.zig`, `src/ui/hub_screen.zig`, `src/ui/party_select_screen.zig`, `src/ui/battle_screen.zig`, `src/ui/ui_common.zig`, `src/ui/widgets.zig`, `src/ui/screen_result.zig`, `src/ui/recap_screen.zig`, `src/ui/run_over_screen.zig`, `src/ui/title_screen.zig`, `src/db/roster.zig`, `src/dungeon/dungeon.zig`, `src/main.zig`, `build.zig`, `build.zig.zon`, `AGENT_INSTRUCTIONS.md`
