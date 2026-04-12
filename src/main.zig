const std = @import("std");
const vaxis = @import("vaxis");

const game_data_mod = @import("game_data");
const species_mod = @import("species");
const items_mod = @import("items");
const critter_mod = @import("critter");
const battle = @import("battle");
const dungeon_mod = @import("dungeon");
const leveling = @import("leveling");
const db = @import("db/db.zig");
const roster_db = @import("db/roster.zig");
const battle_screen_mod = @import("ui/battle_screen.zig");
const BattleScreen = battle_screen_mod.BattleScreen;
const InventorySlot = battle_screen_mod.InventorySlot;
const dungeon_screen_mod = @import("ui/dungeon_screen.zig");
const DungeonScreen = dungeon_screen_mod.DungeonScreen;
const shop_screen_mod = @import("ui/shop_screen.zig");
const ShopScreen = shop_screen_mod.ShopScreen;
const hub_screen_mod = @import("ui/hub_screen.zig");
const HubScreen = hub_screen_mod.HubScreen;
const party_select_mod = @import("ui/party_select_screen.zig");
const PartySelectScreen = party_select_mod.PartySelectScreen;
const roster_screen_mod = @import("ui/roster_screen.zig");
const RosterScreen = roster_screen_mod.RosterScreen;
const inventory_screen_mod = @import("ui/inventory_screen.zig");
const InventoryScreen = inventory_screen_mod.InventoryScreen;
const sprite_mod = @import("ui/sprite.zig");
const SpriteMap = sprite_mod.SpriteMap;
const ui = @import("ui/ui_common.zig");
const theme = @import("ui/theme.zig");
const widgets = @import("ui/widgets.zig");
const passive = @import("passive");
const passive_store = @import("db/passive_store.zig");
const run_store = @import("db/run_store.zig");
const recap_screen_mod = @import("ui/recap_screen.zig");
const RecapScreen = recap_screen_mod.RecapScreen;
const title_screen_mod = @import("ui/title_screen.zig");
const TitleScreen = title_screen_mod.TitleScreen;
const run_over_screen_mod = @import("ui/run_over_screen.zig");
const RunOverScreen = run_over_screen_mod.RunOverScreen;
const meta_shop_screen_mod = @import("ui/meta_shop_screen.zig");
const MetaShopScreen = meta_shop_screen_mod.MetaShopScreen;
const codex_screen_mod = @import("ui/codex_screen.zig");
const CodexScreen = codex_screen_mod.CodexScreen;
const meta_upgrades = @import("ui/meta_upgrades.zig");
const sound = @import("ui/sound.zig");
const tileset_mod = @import("ui/tileset.zig");
const biome_bg_mod = @import("ui/biome_background.zig");
const effect_sprites_mod = @import("ui/effect_sprites.zig");
const transition_mod = @import("ui/transition.zig");
const screen_mod = @import("ui/screen.zig");
const Screen = screen_mod.Screen;
const game_bridge = @import("game_bridge.zig");
const cli = @import("cli.zig");

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    focus_in,
    focus_out,
};

pub const panic = vaxis.Panic.call;


var sprite_path_buf: [64]u8 = undefined;

fn spritePath(id: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(&sprite_path_buf, "assets/sprites/{s}.png", .{id}) catch null;
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // CLI subcommand dispatch — runs before any TUI setup
    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    _ = args.next(); // skip argv[0]
    if (args.next()) |subcmd| {
        if (std.mem.eql(u8, subcmd, "log-event")) {
            const event_type = args.next() orelse {
                cli.printUsage();
                return;
            };
            return cli.handleLogEvent(event_type);
        } else if (std.mem.eql(u8, subcmd, "set-favorite")) {
            const id_str = args.next() orelse {
                cli.printUsage();
                return;
            };
            return cli.handleSetFavorite(alloc, id_str);
        } else if (std.mem.eql(u8, subcmd, "status")) {
            return cli.handleStatus(alloc);
        } else if (std.mem.eql(u8, subcmd, "roster")) {
            return cli.handleRoster(alloc);
        } else if (std.mem.eql(u8, subcmd, "statusline")) {
            return cli.handleStatusline(alloc);
        } else {
            cli.printUsage();
            return;
        }
    }

    // --- TUI mode ---

    var gd = game_data_mod.GameData.load(alloc) catch |err| {
        std.debug.print("Failed to load game data: {}\n", .{err});
        return err;
    };
    defer gd.deinit();

    var database = db.Db.open("codecritter.db") catch |err| {
        std.debug.print("Failed to open database: {}\n", .{err});
        return err;
    };
    defer database.close();
    try database.initSchema();

    try game_bridge.seedStartersIfEmpty(&database, &gd);

    // Load biomes
    var biomes = dungeon_mod.biome.load(alloc, "data/biomes.json") catch |err| {
        std.debug.print("Failed to load biomes: {}\n", .{err});
        return err;
    };
    defer biomes.deinit();

    // Detect biome from working directory language
    const detected_id = dungeon_mod.detect.detectBiome();
    const biome_ptr = dungeon_mod.biome.findById(biomes.value, detected_id) orelse
        dungeon_mod.biome.findById(biomes.value, "generic_dungeon") orelse {
        std.debug.print("Missing generic_dungeon biome\n", .{});
        return error.MissingBiome;
    };

    // Load sprite sheets for known critters
    var sprite_map = SpriteMap{};
    const sprite_ids = [_][]const u8{ "println", "tracer", "profiler", "glitch", "gremlin", "pandemonium", "goto", "spaghetto", "dependency", "monad", "copilot", "segfault", "mutex", "lgtm", "singleton", "printf", "fprintf", "logstash", "stack_overflow", "kernel_panic_critter", "god_object", "monolith", "semaphore", "deadlock", "functor", "burrito", "nitpick", "bikeshed", "autopilot", "hallucination", "breakpoint", "watchpoint", "heisenbug", "fuzzer", "chaos_monkey", "bobby_tables", "queue", "priority_queue", "cron", "hashmap", "b_tree", "rubber_duck", "todo", "fixme", "four_oh_four", "readme", "no_tests", "yolo", "makefile", "jenkins", "cobol", "valgrind", "race_condition", "load_balancer", "turing_machine", "regex", "prompt_engineer", "mainframe", "root", "zero_day", "linus" };
    var sprite_storage: [sprite_ids.len]sprite_mod.SpriteSheet = undefined;
    var sprite_count: usize = 0;
    for (sprite_ids) |id| {
        const path = spritePath(id) orelse continue;
        sprite_storage[sprite_count] = sprite_mod.SpriteSheet.loadFromFile(alloc, path) catch continue;
        sprite_map.put(id, &sprite_storage[sprite_count]);
        sprite_count += 1;
    }
    defer for (sprite_storage[0..sprite_count]) |*s| s.deinit();

    // Load title sprite
    var title_sprite_storage: sprite_mod.SpriteSheet = undefined;
    var has_title_sprite = false;
    if (sprite_mod.SpriteSheet.loadFromFile(alloc, "assets/sprites/title.png")) |ts| {
        title_sprite_storage = ts;
        has_title_sprite = true;
    } else |_| {}
    defer if (has_title_sprite) title_sprite_storage.deinit();

    // Passive reconciliation — process events before showing UI
    const title_sprite_ptr: ?*const sprite_mod.SpriteSheet = if (has_title_sprite) &title_sprite_storage else null;
    const critter_sprite_ptr: ?*const sprite_mod.SpriteSheet = sprite_map.get("println");
    // Use half-block rendering for title/roster sprites (crisp pixel art, no Kitty blur)
    var screen: Screen = .{ .title = TitleScreen.init(title_sprite_ptr, critter_sprite_ptr, false) };
    if (runReconciliation(alloc, &database, &gd)) |r| {
        screen = .{ .recap = r };
    }

    // Game state (persists across screen transitions)
    var inv_screen_entries: [32]inventory_screen_mod.InventoryEntry = undefined;
    var dungeon_state: dungeon_mod.DungeonState = undefined;
    var battle_state: battle.BattleState = undefined;
    var use_kitty = false;
    // Dungeon screen is suspended while player is in battle/shop/roster/inventory mid-run
    var suspended_dungeon: ?DungeonScreen = null;

    // Tileset + biome background for dungeon rendering (Phase 25a)
    var tileset_storage: tileset_mod.Tileset = tileset_mod.Tileset{};
    var tileset_ptr: ?*const tileset_mod.Tileset = null;
    var biome_bg: biome_bg_mod.BiomeBackground = .{};

    // Effect sprites for battle animations (Phase 25b)
    var effect_sprite_map: effect_sprites_mod.EffectSpriteMap = .{};
    effect_sprite_map.load(alloc);

    // Roster/inventory storage for screens (loaded from DB before party_select/roster_view)
    var roster_buf: []critter_mod.Critter = &.{};
    defer if (roster_buf.len > 0) roster_db.freeRoster(alloc, roster_buf);
    var roster_species_buf: [party_select_mod.MAX_ROSTER]?*const species_mod.Species = undefined;
    var inventory_buf: []roster_db.InventoryEntry = &.{};
    defer if (inventory_buf.len > 0) roster_db.freeInventory(alloc, inventory_buf);

    // Party critter IDs (DB IDs) for the current run — used to save XP back
    var run_party_ids: [3]u64 = .{ 0, 0, 0 };

    // Inventory bridge storage
    var inv_bridge: [dungeon_mod.MAX_RUN_ITEMS]InventorySlot = undefined;
    var inv_bridge_count: usize = 0;
    var inv_pre_counts: [dungeon_mod.MAX_RUN_ITEMS]u8 = undefined;

    // Boss flag for XP calculation (set when battle starts)
    var last_was_boss: bool = false;

    var dg_inv_entries: [dungeon_mod.MAX_RUN_ITEMS]inventory_screen_mod.InventoryEntry = undefined;
    var dg_party_buf: [3]critter_mod.Critter = undefined;
    var dg_party_species_buf: [3]?*const species_mod.Species = undefined;
    var dg_party_map: [3]u8 = undefined; // compact index → sparse party index

    // TUI setup
    var tty_buf: [4096]u8 = undefined;
    var tty = try vaxis.Tty.init(&tty_buf);
    defer tty.deinit();

    const writer = tty.writer();

    var vx = try vaxis.init(alloc, .{});
    defer vx.deinit(alloc, writer);

    var loop: vaxis.Loop(Event) = .{ .vaxis = &vx, .tty = &tty };
    try loop.init();
    try loop.start();
    defer loop.stop();

    try vx.enterAltScreen(writer);
    try vx.queryTerminal(writer, 1 * std.time.ns_per_s);

    use_kitty = vx.caps.kitty_graphics;

    if (use_kitty) {
        for (sprite_map.entries[0..sprite_map.count]) |entry| {
            const path = spritePath(entry.species_id) orelse continue;
            @constCast(entry.sheet).loadKittyImage(&vx, alloc, writer, path) catch {};
        }
        if (has_title_sprite) {
            title_sprite_storage.loadKittyImage(&vx, alloc, writer, "assets/sprites/title.png") catch {};
        }
        effect_sprite_map.loadKittyImages(&vx, alloc, writer);
    }

    // Load tileset for the detected biome
    {
        var tile_path_buf: [128]u8 = undefined;
        const tile_path = std.fmt.bufPrint(&tile_path_buf, "assets/tiles/{s}.png", .{biome_ptr.id}) catch null;
        if (tile_path) |path| {
            if (tileset_mod.Tileset.loadFromFile(alloc, path)) |ts| {
                tileset_storage = ts;
                tileset_ptr = &tileset_storage;
                if (use_kitty) {
                    tileset_storage.loadKittyImage(&vx, alloc, writer, path) catch {};
                }
            } else |_| {}
        }
    }
    defer tileset_storage.deinit(alloc);
    defer if (use_kitty) tileset_storage.freeKittyImage(&vx, writer);
    defer effect_sprite_map.deinit(alloc, &vx, writer);

    // Transition state for screen-change visual effect
    var transition_start_ms: i64 = 0;
    var transition_to: ?Screen = null;
    const transition_duration_ms: i64 = transition_mod.DURATION_MS;
    var transition_kind: transition_mod.TransitionKind = .fade_to_black;

    var quit = false;
    while (!quit) {
        while (loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| {
                    if (key.matches('q', .{}) or key.matches('c', .{ .ctrl = true })) {
                        const t = screen.tag();
                        if (t == .hub or t == .title) {
                            quit = true;
                            break;
                        } else if (key.matches('c', .{ .ctrl = true })) {
                            quit = true;
                            break;
                        }
                    }
                    if (screen.handleInput(key)) |result| {
                        switch (result) {
                            .goto_hub => {
                                transition_to = .{ .hub = makeHubScreen(&database, &sprite_map, use_kitty) };
                                transition_kind = transition_mod.pickTransition(screen.tag(), .hub);
                                transition_start_ms = std.time.milliTimestamp();
                            },
                            .goto_party_select => {
                                reloadRoster(alloc, &database, &gd, &roster_buf, &roster_species_buf);
                                if (game_bridge.allUnavailable(roster_buf)) {
                                    game_bridge.decrementCooldowns(roster_buf, &database);
                                }
                                const pack_inv_len = reloadInventory(alloc, &database, &inventory_buf, &inv_screen_entries);
                                const pack_limit = meta_upgrades.getEffectivePackSlots(
                                    roster_db.getMetaUpgradeLevel(&database, "extra_pack_slots"),
                                );
                                transition_to = .{ .party_select = PartySelectScreen.initWithPackLimit(
                                    roster_buf,
                                    roster_species_buf[0..roster_buf.len],
                                    inv_screen_entries[0..pack_inv_len],
                                    &gd,
                                    pack_limit,
                                ) };
                                transition_kind = transition_mod.pickTransition(screen.tag(), .party_select);
                                transition_start_ms = std.time.milliTimestamp();
                            },
                            .goto_roster => |ctx| {
                                switch (ctx) {
                                    .from_hub => {
                                        reloadRoster(alloc, &database, &gd, &roster_buf, &roster_species_buf);
                                        var inv_entries: [roster_screen_mod.MAX_DISCS]RosterScreen.InventoryEntry = undefined;
                                        const inv_len = reloadInventory(alloc, &database, &inventory_buf, &inv_entries);
                                        transition_to = .{ .roster_view = RosterScreen.init(roster_buf, roster_species_buf[0..roster_buf.len], inv_entries[0..inv_len], &gd, &sprite_map, false, .from_hub) };
                                    },
                                    .from_dungeon => {
                                        if (screen.tag() == .dungeon) suspended_dungeon = screen.dungeon;
                                        const dg_party_count = game_bridge.compactDungeonParty(&dungeon_state, &dg_party_buf, &dg_party_species_buf, &dg_party_map);
                                        const empty_inv: []const RosterScreen.InventoryEntry = &.{};
                                        transition_to = .{ .roster_view = RosterScreen.init(
                                            dg_party_buf[0..dg_party_count],
                                            dg_party_species_buf[0..dg_party_count],
                                            empty_inv,
                                            &gd,
                                            &sprite_map,
                                            use_kitty,
                                            .from_dungeon,
                                        ) };
                                    },
                                }
                                transition_kind = transition_mod.pickTransition(screen.tag(), .roster_view);
                                transition_start_ms = std.time.milliTimestamp();
                            },
                            .goto_inventory => |ctx| {
                                switch (ctx) {
                                    .from_hub => {
                                        reloadRoster(alloc, &database, &gd, &roster_buf, &roster_species_buf);
                                        const inv_len = reloadInventory(alloc, &database, &inventory_buf, &inv_screen_entries);
                                        transition_to = .{ .inventory = InventoryScreen.init(inv_screen_entries[0..inv_len], &gd, roster_db.getCurrency(&database), roster_buf, roster_species_buf[0..roster_buf.len], .from_hub) };
                                    },
                                    .from_dungeon => {
                                        if (screen.tag() == .dungeon) suspended_dungeon = screen.dungeon;
                                        var dg_inv_count: usize = 0;
                                        for (dungeon_state.run_inventory[0..dungeon_state.run_inventory_count]) |maybe_item| {
                                            const run_item = maybe_item orelse continue;
                                            if (run_item.count == 0) continue;
                                            dg_inv_entries[dg_inv_count] = .{
                                                .item_id = run_item.item_id,
                                                .quantity = @intCast(run_item.count),
                                            };
                                            dg_inv_count += 1;
                                        }
                                        const dg_party_count = game_bridge.compactDungeonParty(&dungeon_state, &dg_party_buf, &dg_party_species_buf, &dg_party_map);
                                        transition_to = .{ .inventory = InventoryScreen.init(
                                            dg_inv_entries[0..dg_inv_count],
                                            &gd,
                                            dungeon_state.currency,
                                            dg_party_buf[0..dg_party_count],
                                            dg_party_species_buf[0..dg_party_count],
                                            .from_dungeon,
                                        ) };
                                    },
                                }
                                transition_kind = transition_mod.pickTransition(screen.tag(), .inventory);
                                transition_start_ms = std.time.milliTimestamp();
                            },
                            .goto_dungeon => {
                                switch (screen.tag()) {
                                    .party_select => {
                                        // Start a new dungeon run
                                        var party_critters: [3]critter_mod.Critter = undefined;
                                        var party_species: [3]*const species_mod.Species = undefined;
                                        var party_count: usize = 0;
                                        run_party_ids = .{ 0, 0, 0 };

                                        for (screen.party_select.selected) |maybe_idx| {
                                            if (maybe_idx) |idx| {
                                                if (idx < roster_buf.len) {
                                                    party_critters[party_count] = roster_buf[idx];
                                                    run_party_ids[party_count] = roster_buf[idx].id;
                                                    if (roster_species_buf[idx]) |sp| {
                                                        party_species[party_count] = sp;
                                                    } else continue;
                                                    party_count += 1;
                                                }
                                            }
                                        }

                                        if (party_count > 0) {
                                            game_bridge.decrementCooldowns(roster_buf, &database);

                                            var initial_items: [party_select_mod.MAX_PACK_SLOTS]dungeon_mod.RunItem = undefined;
                                            var initial_item_count: u8 = 0;
                                            for (screen.party_select.packed_items) |maybe| {
                                                if (maybe) |pack_entry| {
                                                    if (gd.findItem(pack_entry.item_id)) |gd_item| {
                                                        roster_db.removeInventoryItem(&database, pack_entry.item_id, pack_entry.quantity) catch {};
                                                        initial_items[initial_item_count] = .{
                                                            .item_id = gd_item.id,
                                                            .count = @intCast(pack_entry.quantity),
                                                        };
                                                        initial_item_count += 1;
                                                    }
                                                }
                                            }

                                            const seed: u64 = @intCast(std.time.milliTimestamp());
                                            const term_win = vx.window();
                                            const dg_w: u8 = @intCast(@min(dungeon_mod.floor_gen.MAX_WIDTH, @max(30, term_win.width -| 2)));
                                            const dg_h: u8 = @intCast(@min(dungeon_mod.floor_gen.MAX_HEIGHT, @max(12, term_win.height -| 7)));
                                            const start_currency = meta_upgrades.getStartingCurrency(
                                                roster_db.getMetaUpgradeLevel(&database, "starting_currency"),
                                            );
                                            dungeon_state = dungeon_mod.startRunSized(
                                                party_critters[0..party_count],
                                                party_species[0..party_count],
                                                biome_ptr,
                                                seed,
                                                initial_items[0..initial_item_count],
                                                dg_w,
                                                dg_h,
                                                start_currency,
                                            );
                                            roster_db.incrementMetaStat(&database, meta_upgrades.STAT_TOTAL_RUNS, 1) catch {};

                                            biome_bg = biome_bg_mod.BiomeBackground.load(&vx, alloc, writer, biome_ptr.id);

                                            transition_to = .{ .dungeon = DungeonScreen.init(&dungeon_state, &gd, tileset_ptr, &biome_bg, use_kitty) };
                                            transition_kind = transition_mod.pickTransition(screen.tag(), .dungeon);
                                            transition_start_ms = std.time.milliTimestamp();
                                        } else {
                                            transition_to = .{ .hub = makeHubScreen(&database, &sprite_map, use_kitty) };
                                            transition_kind = transition_mod.pickTransition(screen.tag(), .hub);
                                            transition_start_ms = std.time.milliTimestamp();
                                        }
                                    },
                                    .battle => {
                                        // Finish battle and determine next screen
                                        const enc_result = game_bridge.finishBattle(&dungeon_state, &battle_state, &inv_bridge, inv_bridge_count, &inv_pre_counts);
                                        var dg = &(suspended_dungeon orelse unreachable);

                                        if (enc_result.dropped_item_id) |item_id| {
                                            if (gd.findItem(item_id)) |item| {
                                                var drop_buf: [64]u8 = undefined;
                                                const drop_msg = std.fmt.bufPrint(&drop_buf, "Found a {s}!", .{item.name}) catch "Found an item!";
                                                dg.log.push(drop_msg);
                                            }
                                        }

                                        const b_outcome = battle_state.outcome orelse .player_lose;
                                        if (b_outcome == .player_win or b_outcome == .caught) {
                                            const xp_amount = game_bridge.awardBattleXp(&dungeon_state, &gd, battle_state.player_active, battle_state.wild.critter.level, last_was_boss);
                                            var xp_buf: [64]u8 = undefined;
                                            const xp_msg = std.fmt.bufPrint(&xp_buf, "+{d} XP", .{xp_amount}) catch "+XP";
                                            dg.log.push(xp_msg);

                                            if (last_was_boss) {
                                                roster_db.incrementMetaStat(&database, meta_upgrades.STAT_BOSSES_DEFEATED, 1) catch {};
                                            }
                                        }
                                        roster_db.markSpeciesDiscovered(&database, battle_state.wild.species.id);
                                        if (b_outcome == .caught) {
                                            roster_db.incrementMetaStat(&database, meta_upgrades.STAT_CRITTERS_CAUGHT, 1) catch {};
                                        }

                                        if (dungeon_state.phase == .run_over) {
                                            if (dungeon_state.outcome == .extracted) {
                                                game_bridge.handleExtraction(&dungeon_state, &gd, &database);
                                            }
                                            if (dungeon_state.outcome == .wiped) {
                                                for (&dungeon_state.party) |*maybe_critter| {
                                                    if (maybe_critter.*) |*c| {
                                                        c.cooldown_runs = 2;
                                                    }
                                                }
                                            }
                                            game_bridge.persistPendingScars(&dungeon_state, &database, &run_party_ids);
                                            game_bridge.savePartyState(&dungeon_state, &database, &run_party_ids);
                                            biome_bg.free(&vx, writer);
                                            suspended_dungeon = null;
                                            transition_to = .{ .run_over = RunOverScreen.init(&dungeon_state, &gd) };
                                            transition_kind = transition_mod.pickTransition(screen.tag(), .run_over);
                                            transition_start_ms = std.time.milliTimestamp();
                                        } else if (dungeon_state.phase == .between_floors) {
                                            dungeon_mod.generateBetweenFloorShop(&dungeon_state, &gd);
                                            // Keep suspended_dungeon — shop will also need it
                                            transition_to = .{ .shop = ShopScreen.init(&dungeon_state, &gd) };
                                            transition_kind = transition_mod.pickTransition(screen.tag(), .shop);
                                            transition_start_ms = std.time.milliTimestamp();
                                        } else {
                                            dg.dirty = true;
                                            screen = .{ .dungeon = dg.* };
                                            suspended_dungeon = null;
                                        }
                                    },
                                    .shop => {
                                        // Advance to next floor (no transition animation)
                                        dungeon_mod.advanceFloor(&dungeon_state);
                                        roster_db.updateMetaStatMax(&database, meta_upgrades.STAT_DEEPEST_FLOOR, dungeon_state.floor_number) catch {};
                                        var dg = &(suspended_dungeon orelse unreachable);
                                        dg.resetVisited();
                                        var buf: [64]u8 = undefined;
                                        const msg = std.fmt.bufPrint(&buf, "Entered Floor {d}", .{dungeon_state.floor_number}) catch "Next floor!";
                                        dg.log.push(msg);
                                        dg.dirty = true;
                                        screen = .{ .dungeon = dg.* };
                                        suspended_dungeon = null;
                                    },
                                    else => {
                                        // Resume dungeon from roster/inventory
                                        if (suspended_dungeon) |*dg| {
                                            dg.dirty = true;
                                            screen = .{ .dungeon = dg.* };
                                            suspended_dungeon = null;
                                        }
                                    },
                                }
                            },
                            .goto_battle => |req| {
                                last_was_boss = req.is_boss;
                                const info = dungeon_mod.EncounterInfo{ .species_id = req.species_id, .level = req.level };
                                if (game_bridge.startBattle(&dungeon_state, info, &gd, &inv_bridge, &inv_bridge_count, &inv_pre_counts, &battle_state)) {
                                    suspended_dungeon = screen.dungeon;
                                    transition_to = .{ .battle = BattleScreen.init(&battle_state, &gd, inv_bridge[0..inv_bridge_count], &sprite_map, &effect_sprite_map, use_kitty) };
                                    transition_kind = transition_mod.pickTransition(screen.tag(), .battle);
                                    transition_start_ms = std.time.milliTimestamp();
                                    sound.beep();
                                }
                            },
                            .goto_shop => {
                                suspended_dungeon = screen.dungeon;
                                dungeon_mod.generateBetweenFloorShop(&dungeon_state, &gd);
                                transition_to = .{ .shop = ShopScreen.init(&dungeon_state, &gd) };
                                transition_kind = transition_mod.pickTransition(screen.tag(), .shop);
                                transition_start_ms = std.time.milliTimestamp();
                            },
                            .goto_run_over => {
                                transition_to = .{ .run_over = RunOverScreen.init(&dungeon_state, &gd) };
                                transition_kind = transition_mod.pickTransition(screen.tag(), .run_over);
                                transition_start_ms = std.time.milliTimestamp();
                            },
                            .goto_meta_shop => {
                                var levels: [meta_upgrades.UPGRADE_COUNT]u8 = undefined;
                                for (meta_upgrades.all_upgrades, 0..) |upgrade, i| {
                                    levels[i] = roster_db.getMetaUpgradeLevel(&database, upgrade.id);
                                }
                                transition_to = .{ .meta_shop = MetaShopScreen.init(roster_db.getCurrency(&database), levels) };
                                transition_kind = transition_mod.pickTransition(screen.tag(), .meta_shop);
                                transition_start_ms = std.time.milliTimestamp();
                            },
                            .goto_codex => {
                                transition_to = .{ .codex = CodexScreen.init(&gd, &database) };
                                transition_kind = transition_mod.pickTransition(screen.tag(), .codex);
                                transition_start_ms = std.time.milliTimestamp();
                            },
                            .persist_swap => |swap| {
                                roster_db.swapCritterOrder(&database, @intCast(swap.id_a), @intCast(swap.id_b)) catch |err| {
                                    std.log.err("swap: swapCritterOrder failed: {}", .{err});
                                };
                            },
                            .persist_equip => |equip| {
                                if (equip.critter_idx < roster_buf.len) {
                                    const critter = &roster_buf[equip.critter_idx];
                                    roster_db.updateCritterMove3(&database, @intCast(critter.id), equip.move_id) catch |err| {
                                        std.log.err("equip: updateCritterMove3 failed: {}", .{err});
                                    };
                                    roster_db.removeInventoryItem(&database, equip.item_id, 1) catch |err| {
                                        std.log.err("equip: removeInventoryItem failed: {}", .{err});
                                    };
                                }
                                const saved_cursor = screen.roster_view.cursor;
                                const saved_ctx = screen.roster_view.screen_context;
                                reloadRoster(alloc, &database, &gd, &roster_buf, &roster_species_buf);
                                var inv_entries: [roster_screen_mod.MAX_DISCS]RosterScreen.InventoryEntry = undefined;
                                const inv_len = reloadInventory(alloc, &database, &inventory_buf, &inv_entries);
                                screen = .{ .roster_view = RosterScreen.init(roster_buf, roster_species_buf[0..roster_buf.len], inv_entries[0..inv_len], &gd, &sprite_map, false, saved_ctx) };
                                screen.roster_view.cursor = @min(saved_cursor, @as(u8, @intCast(@max(roster_buf.len, 1) - 1)));
                            },
                            .persist_item_use => |use| {
                                switch (use.context) {
                                    .from_dungeon => {
                                        if (use.target_idx < 3) {
                                            const sparse_idx = dg_party_map[use.target_idx];
                                            dungeon_state.party[sparse_idx] = dg_party_buf[use.target_idx];
                                        }
                                        for (dungeon_state.run_inventory[0..dungeon_state.run_inventory_count]) |*maybe_item| {
                                            if (maybe_item.*) |*run_item| {
                                                if (std.mem.eql(u8, run_item.item_id, use.item_id)) {
                                                    run_item.count -|= 1;
                                                    break;
                                                }
                                            }
                                        }
                                    },
                                    .from_hub => {
                                        if (use.target_idx < roster_buf.len) {
                                            _ = roster_db.saveCritter(&database, &roster_buf[use.target_idx]) catch |err| {
                                                std.log.err("inventory use: saveCritter failed: {}", .{err});
                                            };
                                        }
                                        roster_db.removeInventoryItem(&database, use.item_id, 1) catch |err| {
                                            std.log.err("inventory use: removeInventoryItem failed: {}", .{err});
                                        };
                                    },
                                }
                            },
                            .persist_meta_purchase => |req| {
                                const upgrade = &meta_upgrades.all_upgrades[req.upgrade_index];
                                const level = screen.meta_shop.upgrade_levels[req.upgrade_index];
                                const cost = meta_upgrades.costForNextLevel(upgrade, level) orelse 0;
                                if (cost > 0 and roster_db.purchaseMetaUpgrade(&database, upgrade.id, cost)) {
                                    screen.meta_shop.applyPurchase(req.upgrade_index, cost);
                                } else {
                                    screen.meta_shop.applyPurchaseFailed();
                                }
                            },
                            .start_extraction => {
                                dungeon_mod.extract(&dungeon_state);
                                game_bridge.handleExtraction(&dungeon_state, &gd, &database);
                                game_bridge.persistPendingScars(&dungeon_state, &database, &run_party_ids);
                                game_bridge.savePartyState(&dungeon_state, &database, &run_party_ids);
                                transition_to = .{ .run_over = RunOverScreen.init(&dungeon_state, &gd) };
                                transition_kind = transition_mod.pickTransition(screen.tag(), .run_over);
                                transition_start_ms = std.time.milliTimestamp();
                            },
                            .quit => {
                                quit = true;
                            },
                        }
                    }
                },
                .winsize => |ws| {
                    try vx.resize(alloc, writer, ws);
                    screen.dirtyPtr().* = true;
                },
                else => {},
            }
        }
        if (quit) break;

        // Handle transition overlay
        if (transition_to) |*pending| {
            const elapsed = std.time.milliTimestamp() - transition_start_ms;
            if (elapsed >= transition_duration_ms) {
                screen = pending.*;
                transition_to = null;
            } else {
                const progress = @as(f32, @floatFromInt(elapsed)) / @as(f32, @floatFromInt(transition_duration_ms));
                const win = vx.window();

                if (progress >= 0.5) {
                    pending.render(win);
                } else {
                    win.clear();
                }

                switch (transition_kind) {
                    .fade_to_black => transition_mod.renderFadeToBlack(win, progress),
                    .wipe_left => transition_mod.renderWipeLeft(win, progress),
                    .dissolve => transition_mod.renderDissolve(win, progress),
                }

                try vx.render(writer);
                try writer.flush();
                std.Thread.sleep(16 * std.time.ns_per_ms);
                continue;
            }
        }

        // Per-frame animation updates
        screen.updateAnimation();

        // Dirty-check and render
        const screen_dirty = screen.dirtyPtr();
        if (screen.alwaysDirty()) screen_dirty.* = true;

        if (screen_dirty.*) {
            screen_dirty.* = false;
            const win = vx.window();
            screen.render(win);
            try vx.render(writer);
            try writer.flush();
        }

        std.Thread.sleep(16 * std.time.ns_per_ms);
    }
}

fn lookupFavoriteSprite(database: *db.Db, sprite_map: *const SpriteMap) ?*const sprite_mod.SpriteSheet {
    const critter_id = passive_store.getFavoriteCritterId(database) orelse return null;
    const row = database.conn.row(
        "SELECT species_id FROM critters WHERE id = ?1",
        .{critter_id},
    ) catch return null;
    if (row) |r| {
        defer r.deinit();
        const species_id = r.text(0);
        return sprite_map.get(species_id);
    }
    return null;
}

fn makeHubScreen(database: *db.Db, sprite_map: *const SpriteMap, use_kitty: bool) HubScreen {
    const has_codex = meta_upgrades.hasCodex(roster_db.getMetaUpgradeLevel(database, "species_codex"));
    const stats = HubScreen.HubStats{
        .total_runs = roster_db.getMetaStat(database, meta_upgrades.STAT_TOTAL_RUNS),
        .deepest_floor = roster_db.getMetaStat(database, meta_upgrades.STAT_DEEPEST_FLOOR),
        .critters_caught = roster_db.getMetaStat(database, meta_upgrades.STAT_CRITTERS_CAUGHT),
        .species_discovered = roster_db.countMetaKeysWithPrefix(database, meta_upgrades.STAT_SEEN_PREFIX),
        .bosses_defeated = roster_db.getMetaStat(database, meta_upgrades.STAT_BOSSES_DEFEATED),
    };
    return HubScreen.initFull(
        game_bridge.rosterCount(database),
        roster_db.getCurrency(database),
        lookupFavoriteSprite(database, sprite_map),
        use_kitty,
        has_codex,
        stats,
    );
}

fn reloadInventory(
    alloc: std.mem.Allocator,
    database: *db.Db,
    inventory_buf: *[]roster_db.InventoryEntry,
    dest: []inventory_screen_mod.InventoryEntry,
) usize {
    if (inventory_buf.len > 0) {
        roster_db.freeInventory(alloc, inventory_buf.*);
        inventory_buf.* = &.{};
    }
    inventory_buf.* = roster_db.loadInventory(database, alloc) catch &.{};
    const len = @min(inventory_buf.len, dest.len);
    for (0..len) |i| {
        dest[i] = .{
            .item_id = inventory_buf.*[i].item_id,
            .quantity = inventory_buf.*[i].quantity,
        };
    }
    return len;
}

fn reloadRoster(
    alloc: std.mem.Allocator,
    database: *db.Db,
    gd: *const game_data_mod.GameData,
    roster_buf: *[]critter_mod.Critter,
    species_buf: *[party_select_mod.MAX_ROSTER]?*const species_mod.Species,
) void {
    if (roster_buf.len > 0) {
        roster_db.freeRoster(alloc, roster_buf.*);
    }
    roster_buf.* = roster_db.loadRoster(database, alloc) catch &.{};
    for (roster_buf.*, 0..) |critter, i| {
        if (i >= party_select_mod.MAX_ROSTER) break;
        species_buf[i] = gd.findSpecies(critter.species_id);
    }
}

// --- Passive reconciliation ---

fn runReconciliation(alloc: std.mem.Allocator, database: *db.Db, gd: *game_data_mod.GameData) ?RecapScreen {
    const event_count = passive_store.countUnprocessedEvents(database);
    if (event_count == 0) return null;

    const stored_fav = passive_store.getFavoriteCritterId(database);
    const fav_id = stored_fav orelse cli.getFirstCritterId(database) orelse return null;

    var critter = (roster_db.loadCritter(database, alloc, fav_id) catch return null) orelse return null;
    defer roster_db.freeCritter(alloc, &critter);

    const old_level = critter.level;
    const seed: u64 = @intCast(@max(std.time.milliTimestamp(), 0));
    const result = passive.reconcile(event_count, &critter, gd, seed);

    // Persist critter, items, mark events processed
    _ = roster_db.saveCritter(database, &critter) catch {};

    var i: u8 = 0;
    while (i < result.item_count) : (i += 1) {
        if (result.items_found[i]) |item| {
            roster_db.addInventoryItem(database, item.item_id, 1) catch {};
        }
    }

    if (stored_fav == null) {
        passive_store.setFavoriteCritterId(database, @intCast(fav_id)) catch {};
    }

    passive_store.markAllEventsProcessed(database) catch {};

    // Build recap data
    var data = RecapScreen{
        .dirty = true,
        .xp_awarded = result.xp_awarded,
        .events_processed = result.events_processed,
        .level_before = old_level,
        .level_after = critter.level,
        .evolved = if (result.level_up) |lu| lu.evolved else false,
        .items = undefined,
        .item_count = result.item_count,
        .critter_name = undefined,
        .critter_name_len = 0,
    };

    // Copy critter display name
    const sp_name = if (gd.findSpecies(critter.species_id)) |sp| sp.name else critter.species_id;
    const name_len: u8 = @intCast(@min(sp_name.len, 32));
    @memcpy(data.critter_name[0..name_len], sp_name[0..name_len]);
    data.critter_name_len = name_len;

    // Copy item names
    const empty_item = RecapScreen.ItemDisplay{ .name = undefined, .name_len = 0 };
    data.items = .{empty_item} ** 4;
    var j: u8 = 0;
    while (j < result.item_count) : (j += 1) {
        if (result.items_found[j]) |item| {
            const item_name = if (gd.findItem(item.item_id)) |it| it.name else item.item_id;
            const ilen: u8 = @intCast(@min(item_name.len, 32));
            @memcpy(data.items[j].name[0..ilen], item_name[0..ilen]);
            data.items[j].name_len = ilen;
        }
    }

    return data;
}
