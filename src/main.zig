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
const recap_screen_mod = @import("ui/recap_screen.zig");
const RecapScreen = recap_screen_mod.RecapScreen;
const title_screen_mod = @import("ui/title_screen.zig");
const TitleScreen = title_screen_mod.TitleScreen;
const run_over_screen_mod = @import("ui/run_over_screen.zig");
const RunOverScreen = run_over_screen_mod.RunOverScreen;

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    focus_in,
    focus_out,
};

pub const panic = vaxis.Panic.call;

const ActiveScreen = enum {
    title,
    recap,
    hub,
    party_select,
    roster_view,
    inventory,
    dungeon,
    battle,
    shop,
    run_over,
};

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
                printUsage();
                return;
            };
            return handleLogEvent(event_type);
        } else if (std.mem.eql(u8, subcmd, "set-favorite")) {
            const id_str = args.next() orelse {
                printUsage();
                return;
            };
            return handleSetFavorite(alloc, id_str);
        } else if (std.mem.eql(u8, subcmd, "status")) {
            return handleStatus(alloc);
        } else if (std.mem.eql(u8, subcmd, "statusline")) {
            return handleStatusline(alloc);
        } else {
            printUsage();
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

    try seedStartersIfEmpty(&database, &gd);

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
    const sprite_ids = [_][]const u8{ "println", "tracer", "profiler", "glitch", "gremlin", "pandemonium", "goto", "spaghetto", "dependency", "monad", "copilot", "segfault", "mutex", "lgtm", "singleton" };
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
    var recap_screen: RecapScreen = undefined;
    const title_sprite_ptr: ?*const sprite_mod.SpriteSheet = if (has_title_sprite) &title_sprite_storage else null;
    const critter_sprite_ptr: ?*const sprite_mod.SpriteSheet = sprite_map.get("println");
    // Use half-block rendering for title/roster sprites (crisp pixel art, no Kitty blur)
    var title_screen = TitleScreen.init(title_sprite_ptr, critter_sprite_ptr, false);
    var active_screen: ActiveScreen = .title;
    const reconcile_result = runReconciliation(alloc, &database, &gd);
    if (reconcile_result) |r| {
        recap_screen = r;
        active_screen = .recap;
    }

    // Screen state
    var hub_screen: HubScreen = HubScreen.init(rosterCount(&database), roster_db.getCurrency(&database));
    var party_select_screen: PartySelectScreen = undefined;
    var roster_screen: RosterScreen = undefined;
    var inv_screen: InventoryScreen = undefined;
    var inv_screen_entries: [32]inventory_screen_mod.InventoryEntry = undefined;
    var dungeon_state: dungeon_mod.DungeonState = undefined;
    var dg_screen: DungeonScreen = undefined;
    var battle_state: battle.BattleState = undefined;
    var battle_screen: BattleScreen = undefined;
    var shop_screen: ShopScreen = undefined;
    var use_kitty = false;
    var run_over_screen: RunOverScreen = undefined;

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
    }

    // Transition state for screen-change visual effect
    var transition_start_ms: i64 = 0;
    var transition_pending: ?ActiveScreen = null;
    const transition_duration_ms: i64 = 150;

    var quit = false;
    while (!quit) {
        while (loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| {
                    if (key.matches('q', .{}) or key.matches('c', .{ .ctrl = true })) {
                        if (active_screen == .hub or active_screen == .title) {
                            quit = true;
                            break;
                        } else if (key.matches('c', .{ .ctrl = true })) {
                            quit = true;
                            break;
                        }
                    }
                    switch (active_screen) {
                        .title => {
                            if (title_screen.handleInput(key)) |result| {
                                switch (result) {
                                    .goto_hub => {
                                        hub_screen = HubScreen.init(rosterCount(&database), roster_db.getCurrency(&database));
                                        transition_pending = .hub;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    else => {},
                                }
                            }
                        },
                        .recap => {
                            if (recap_screen.handleInput(key)) |result| {
                                switch (result) {
                                    .goto_hub => {
                                        hub_screen = HubScreen.init(rosterCount(&database), roster_db.getCurrency(&database));
                                        transition_pending = .hub;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    else => {},
                                }
                            }
                        },
                        .hub => {
                            if (hub_screen.handleInput(key)) |result| {
                                switch (result) {
                                    .goto_party_select => {
                                        reloadRoster(alloc, &database, &gd, &roster_buf, &roster_species_buf);
                                        if (allUnavailable(roster_buf)) {
                                            decrementCooldowns(roster_buf, &database);
                                        }
                                        const pack_inv_len = reloadInventory(alloc, &database, &inventory_buf, &inv_screen_entries);
                                        party_select_screen = PartySelectScreen.init(
                                            roster_buf,
                                            roster_species_buf[0..roster_buf.len],
                                            inv_screen_entries[0..pack_inv_len],
                                            &gd,
                                        );
                                        transition_pending = .party_select;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    .goto_roster => {
                                        reloadRoster(alloc, &database, &gd, &roster_buf, &roster_species_buf);
                                        var inv_entries: [roster_screen_mod.MAX_DISCS]RosterScreen.InventoryEntry = undefined;
                                        const inv_len = reloadInventory(alloc, &database, &inventory_buf, &inv_entries);
                                        roster_screen = RosterScreen.init(roster_buf, roster_species_buf[0..roster_buf.len], inv_entries[0..inv_len], &gd, &sprite_map, false, .from_hub);
                                        transition_pending = .roster_view;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    .goto_inventory => {
                                        reloadRoster(alloc, &database, &gd, &roster_buf, &roster_species_buf);
                                        const inv_len = reloadInventory(alloc, &database, &inventory_buf, &inv_screen_entries);
                                        inv_screen = InventoryScreen.init(inv_screen_entries[0..inv_len], &gd, roster_db.getCurrency(&database), roster_buf, roster_species_buf[0..roster_buf.len], .from_hub);

                                        transition_pending = .inventory;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    .quit => {
                                        quit = true;
                                    },
                                    else => {},
                                }
                            }
                        },
                        .party_select => {
                            if (party_select_screen.handleInput(key)) |result| {
                                switch (result) {
                                    .goto_dungeon => {
                                        var party_critters: [3]critter_mod.Critter = undefined;
                                        var party_species: [3]*const species_mod.Species = undefined;
                                        var party_count: usize = 0;
                                        run_party_ids = .{ 0, 0, 0 };

                                        for (party_select_screen.selected) |maybe_idx| {
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
                                            decrementCooldowns(roster_buf, &database);

                                            // Extract packed items and remove from persistent inventory
                                            var initial_items: [party_select_mod.MAX_PACK_SLOTS]dungeon_mod.RunItem = undefined;
                                            var initial_item_count: u8 = 0;
                                            for (party_select_screen.packed_items) |maybe| {
                                                if (maybe) |pack_entry| {
                                                    // Use game-data pointer for stable item_id lifetime
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
                                            dungeon_state = dungeon_mod.startRun(
                                                party_critters[0..party_count],
                                                party_species[0..party_count],
                                                biome_ptr,
                                                seed,
                                                initial_items[0..initial_item_count],
                                            );
                                            dg_screen = DungeonScreen.init(&dungeon_state, &gd);
                                            transition_pending = .dungeon;
                                            transition_start_ms = std.time.milliTimestamp();
                                        } else {
                                            hub_screen = HubScreen.init(rosterCount(&database), roster_db.getCurrency(&database));
                                            transition_pending = .hub;
                                            transition_start_ms = std.time.milliTimestamp();
                                        }
                                    },
                                    .goto_hub => {
                                        hub_screen = HubScreen.init(rosterCount(&database), roster_db.getCurrency(&database));
                                        transition_pending = .hub;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    else => {},
                                }
                            }
                        },
                        .roster_view => {
                            if (roster_screen.handleInput(key)) |result| {
                                switch (result) {
                                    .persist_swap => |swap| {
                                        roster_db.swapCritterOrder(&database, @intCast(swap.id_a), @intCast(swap.id_b)) catch |err| {
                                            std.log.err("swap: swapCritterOrder failed: {}", .{err});
                                        };
                                    },
                                    .persist_equip => |equip| {
                                        if (equip.critter_idx < roster_buf.len) {
                                            const critter = &roster_buf[equip.critter_idx];
                                            _ = roster_db.saveCritter(&database, critter) catch |err| {
                                                std.log.err("equip: saveCritter failed: {}", .{err});
                                            };
                                            roster_db.removeInventoryItem(&database, equip.item_id, 1) catch |err| {
                                                std.log.err("equip: removeInventoryItem failed: {}", .{err});
                                            };
                                        }
                                    },
                                    .goto_hub => {
                                        hub_screen = HubScreen.init(rosterCount(&database), roster_db.getCurrency(&database));
                                        transition_pending = .hub;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    .goto_dungeon => {
                                        transition_pending = .dungeon;
                                        dg_screen.dirty = true;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    else => {},
                                }
                            }
                        },
                        .inventory => {
                            if (inv_screen.handleInput(key)) |result| {
                                switch (result) {
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
                                    .goto_hub => {
                                        hub_screen = HubScreen.init(rosterCount(&database), roster_db.getCurrency(&database));
                                        transition_pending = .hub;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    .goto_dungeon => {
                                        transition_pending = .dungeon;
                                        dg_screen.dirty = true;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    else => {},
                                }
                            }
                        },
                        .dungeon => {
                            if (dg_screen.handleInput(key)) |result| {
                                switch (result) {
                                    .goto_battle => |req| {
                                        last_was_boss = req.is_boss;
                                        const info = dungeon_mod.EncounterInfo{ .species_id = req.species_id, .level = req.level };
                                        if (startBattle(&dungeon_state, info, &gd, &inv_bridge, &inv_bridge_count, &inv_pre_counts, &battle_state, &battle_screen, &sprite_map, use_kitty)) {
                                            transition_pending = .battle;
                                            transition_start_ms = std.time.milliTimestamp();
                                        }
                                    },
                                    .goto_shop => {
                                        dungeon_mod.generateBetweenFloorShop(&dungeon_state, &gd);
                                        shop_screen = ShopScreen.init(&dungeon_state, &gd);
                                        transition_pending = .shop;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    .goto_inventory => {
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
                                        const dg_party_count = compactDungeonParty(&dungeon_state, &dg_party_buf, &dg_party_species_buf, &dg_party_map);
                                        inv_screen = InventoryScreen.init(
                                            dg_inv_entries[0..dg_inv_count],
                                            &gd,
                                            dungeon_state.currency,
                                            dg_party_buf[0..dg_party_count],
                                            dg_party_species_buf[0..dg_party_count],
                                            .from_dungeon,
                                        );
                                        transition_pending = .inventory;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    .goto_roster => {
                                        const dg_party_count = compactDungeonParty(&dungeon_state, &dg_party_buf, &dg_party_species_buf, &dg_party_map);
                                        const empty_inv: []const RosterScreen.InventoryEntry = &.{};
                                        roster_screen = RosterScreen.init(
                                            dg_party_buf[0..dg_party_count],
                                            dg_party_species_buf[0..dg_party_count],
                                            empty_inv,
                                            &gd,
                                            &sprite_map,
                                            use_kitty,
                                            .from_dungeon,
                                        );
                                        transition_pending = .roster_view;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    else => {},
                                }
                            }
                        },
                        .battle => {
                            if (battle_screen.handleInput(key)) |result| {
                                switch (result) {
                                    .goto_dungeon => {
                                        const enc_result = finishBattle(&dungeon_state, &battle_state, &inv_bridge, inv_bridge_count, &inv_pre_counts);

                                        if (enc_result.dropped_item_id) |item_id| {
                                            if (gd.findItem(item_id)) |item| {
                                                var drop_buf: [64]u8 = undefined;
                                                const drop_msg = std.fmt.bufPrint(&drop_buf, "Found a {s}!", .{item.name}) catch "Found an item!";
                                                dg_screen.log.push(drop_msg);
                                            }
                                        }

                                        const b_outcome = battle_state.outcome orelse .player_lose;
                                        if (b_outcome == .player_win or b_outcome == .caught) {
                                            const xp_amount = awardBattleXp(&dungeon_state, &gd, battle_state.player_active, battle_state.wild.critter.level, last_was_boss);
                                            var xp_buf: [64]u8 = undefined;
                                            const xp_msg = std.fmt.bufPrint(&xp_buf, "+{d} XP", .{xp_amount}) catch "+XP";
                                            dg_screen.log.push(xp_msg);
                                        }

                                        if (dungeon_state.phase == .run_over) {
                                            if (dungeon_state.outcome == .extracted) {
                                                handleExtraction(&dungeon_state, &gd, &database);
                                            }
                                            if (dungeon_state.outcome == .wiped) {
                                                for (&dungeon_state.party) |*maybe_critter| {
                                                    if (maybe_critter.*) |*c| {
                                                        c.cooldown_runs = 2;
                                                    }
                                                }
                                            }
                                            persistPendingScars(&dungeon_state, &database, &run_party_ids);
                                            savePartyState(&dungeon_state, &database, &run_party_ids);
                                            transition_pending = .run_over;
                                            transition_start_ms = std.time.milliTimestamp();
                                            run_over_screen = RunOverScreen.init(&dungeon_state, &gd);
                                        } else if (dungeon_state.phase == .between_floors) {
                                            dungeon_mod.generateBetweenFloorShop(&dungeon_state, &gd);
                                            shop_screen = ShopScreen.init(&dungeon_state, &gd);
                                            transition_pending = .shop;
                                            transition_start_ms = std.time.milliTimestamp();
                                        } else {
                                            active_screen = .dungeon;
                                            dg_screen.dirty = true;
                                        }
                                    },
                                    else => {},
                                }
                            }
                        },
                        .shop => {
                            if (shop_screen.handleInput(key)) |result| {
                                switch (result) {
                                    .start_extraction => {
                                        dungeon_mod.extract(&dungeon_state);
                                        handleExtraction(&dungeon_state, &gd, &database);
                                        persistPendingScars(&dungeon_state, &database, &run_party_ids);
                                        savePartyState(&dungeon_state, &database, &run_party_ids);
                                        run_over_screen = RunOverScreen.init(&dungeon_state, &gd);
                                        transition_pending = .run_over;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    .goto_dungeon => {
                                        dungeon_mod.advanceFloor(&dungeon_state);
                                        dg_screen.resetVisited();
                                        var buf: [64]u8 = undefined;
                                        const msg = std.fmt.bufPrint(&buf, "Entered Floor {d}", .{dungeon_state.floor_number}) catch "Next floor!";
                                        dg_screen.log.push(msg);
                                        dg_screen.dirty = true;
                                        active_screen = .dungeon;
                                    },
                                    else => {},
                                }
                            }
                        },
                        .run_over => {
                            if (run_over_screen.handleInput(key)) |result| {
                                switch (result) {
                                    .goto_hub => {
                                        hub_screen = HubScreen.init(rosterCount(&database), roster_db.getCurrency(&database));
                                        transition_pending = .hub;
                                        transition_start_ms = std.time.milliTimestamp();
                                    },
                                    else => {},
                                }
                            }
                        },
                    }
                },
                .winsize => |ws| {
                    try vx.resize(alloc, writer, ws);
                    markAllDirty(active_screen, &title_screen, &recap_screen, &hub_screen, &party_select_screen, &roster_screen, &inv_screen, &dg_screen, &battle_screen, &shop_screen, &run_over_screen);
                },
                else => {},
            }
        }
        if (quit) break;

        // Handle transition overlay (cut to black)
        if (transition_pending) |pending| {
            const elapsed = std.time.milliTimestamp() - transition_start_ms;
            if (elapsed >= transition_duration_ms) {
                active_screen = pending;
                transition_pending = null;
            } else {
                const win = vx.window();
                win.clear();
                try vx.render(writer);
                try writer.flush();
                const remaining = transition_duration_ms - elapsed;
                std.Thread.sleep(@intCast(remaining * std.time.ns_per_ms));
                continue;
            }
        }

        if (active_screen == .title) {
            title_screen.updateAnimation();
        } else if (active_screen == .roster_view) {
            roster_screen.updateAnimation();
        } else if (active_screen == .battle) {
            battle_screen.updateAnimation();
        }

        // Render
        const dirty = switch (active_screen) {
            .title => title_screen.dirty,
            .recap => recap_screen.dirty,
            .hub => hub_screen.dirty,
            .party_select => party_select_screen.dirty,
            .roster_view => roster_screen.dirty,
            .inventory => inv_screen.dirty,
            .dungeon => dg_screen.dirty,
            .battle => battle_screen.dirty,
            .shop => shop_screen.dirty,
            .run_over => run_over_screen.dirty,
        };

        if (dirty) {
            switch (active_screen) {
                .title => title_screen.dirty = false,
                .recap => recap_screen.dirty = false,
                .hub => hub_screen.dirty = false,
                .party_select => party_select_screen.dirty = false,
                .roster_view => roster_screen.dirty = false,
                .inventory => inv_screen.dirty = false,
                .dungeon => dg_screen.dirty = false,
                .battle => battle_screen.dirty = false,
                .shop => shop_screen.dirty = false,
                .run_over => run_over_screen.dirty = false,
            }
            const win = vx.window();
            switch (active_screen) {
                .title => title_screen.render(win),
                .recap => recap_screen.render(win),
                .hub => hub_screen.render(win),
                .party_select => party_select_screen.render(win),
                .roster_view => roster_screen.render(win),
                .inventory => inv_screen.render(win),
                .dungeon => dg_screen.render(win),
                .battle => battle_screen.render(win),
                .shop => shop_screen.render(win),
                .run_over => run_over_screen.render(win),
            }
            try vx.render(writer);
            try writer.flush();
        }

        std.Thread.sleep(16 * std.time.ns_per_ms);
    }
}

fn seedStartersIfEmpty(database: *db.Db, gd: *const game_data_mod.GameData) !void {
    const roster = try roster_db.loadRoster(database, std.heap.page_allocator);
    defer roster_db.freeRoster(std.heap.page_allocator, roster);
    if (roster.len > 0) return;

    // Create starter critters
    const println_sp = gd.findSpecies("println") orelse return;
    const goto_sp = gd.findSpecies("goto") orelse return;

    var println = critter_mod.Critter.createFromSpecies(println_sp, 5);
    var goto_c = critter_mod.Critter.createFromSpecies(goto_sp, 5);

    _ = try roster_db.saveCritter(database, &println);
    _ = try roster_db.saveCritter(database, &goto_c);
}

/// Copy non-null dungeon party members into compact buffers, returning count and sparse index mapping.
fn compactDungeonParty(
    state: *const dungeon_mod.DungeonState,
    buf: *[3]critter_mod.Critter,
    sp_buf: *[3]?*const species_mod.Species,
    map: *[3]u8,
) usize {
    var count: usize = 0;
    for (state.party, 0..) |maybe, i| {
        if (maybe) |c| {
            buf[count] = c;
            sp_buf[count] = state.party_species[i];
            map[count] = @intCast(i);
            count += 1;
        }
    }
    return count;
}

fn rosterCount(database: *db.Db) u16 {
    return roster_db.countCritters(database);
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

fn startBattle(
    dungeon_state: *dungeon_mod.DungeonState,
    info: dungeon_mod.EncounterInfo,
    gd: *const game_data_mod.GameData,
    inv_bridge: *[dungeon_mod.MAX_RUN_ITEMS]InventorySlot,
    inv_bridge_count: *usize,
    inv_pre_counts: *[dungeon_mod.MAX_RUN_ITEMS]u8,
    battle_state: *battle.BattleState,
    b_screen: *BattleScreen,
    sprite_map: *const SpriteMap,
    use_kitty: bool,
) bool {
    const wild_sp = gd.findSpecies(info.species_id) orelse return false;
    const wild_critter = critter_mod.Critter.createFromSpecies(wild_sp, info.level);

    var party_critters: [3]critter_mod.Critter = undefined;
    var party_species: [3]*const species_mod.Species = undefined;
    var party_count: usize = 0;
    for (dungeon_state.party, 0..) |maybe, i| {
        if (maybe) |c| {
            if (dungeon_state.party_species[i]) |sp| {
                party_critters[i] = c;
                party_species[i] = sp;
                party_count = i + 1;
            }
        }
    }
    if (party_count == 0) return false;

    inv_bridge_count.* = 0;
    for (dungeon_state.run_inventory[0..dungeon_state.run_inventory_count]) |maybe_item| {
        const item = maybe_item orelse continue;
        const game_item = gd.findItem(item.item_id) orelse continue;
        const count: u8 = @intCast(@min(item.count, 255));
        inv_bridge[inv_bridge_count.*] = .{ .item = game_item, .count = count };
        inv_pre_counts[inv_bridge_count.*] = count;
        inv_bridge_count.* += 1;
    }

    const seed: u64 = @intCast(std.time.milliTimestamp());
    battle_state.* = battle.initBattle(
        party_critters[0..party_count],
        party_species[0..party_count],
        wild_critter,
        wild_sp,
        seed,
    );
    b_screen.* = BattleScreen.init(battle_state, gd, inv_bridge[0..inv_bridge_count.*], sprite_map, use_kitty);
    return true;
}

fn finishBattle(
    dungeon_state: *dungeon_mod.DungeonState,
    battle_state: *const battle.BattleState,
    inv_bridge: *const [dungeon_mod.MAX_RUN_ITEMS]InventorySlot,
    inv_bridge_count: usize,
    inv_pre_counts: *const [dungeon_mod.MAX_RUN_ITEMS]u8,
) dungeon_mod.EncounterResult {
    const b_outcome = battle_state.outcome orelse .player_lose;
    const d_outcome: dungeon_mod.EncounterOutcome = switch (b_outcome) {
        .player_win => .player_win,
        .player_lose => .player_lose,
        .caught => .caught,
    };

    var updated_party: [3]?critter_mod.Critter = .{ null, null, null };
    for (battle_state.player_party, 0..) |maybe_bc, i| {
        if (maybe_bc) |bc| {
            updated_party[i] = bc.critter;
        }
    }

    var caught_species_id: ?[]const u8 = null;
    var caught_level: u8 = 0;
    if (b_outcome == .caught) {
        caught_species_id = battle_state.wild.species.id;
        caught_level = battle_state.wild.critter.level;
    }

    const enc_result = dungeon_mod.resolveEncounter(dungeon_state, d_outcome, updated_party, caught_species_id, caught_level);

    // Sync consumed inventory items back to dungeon
    var bridge_idx: usize = 0;
    for (dungeon_state.run_inventory[0..dungeon_state.run_inventory_count]) |*maybe_item| {
        if (maybe_item.*) |*item| {
            if (bridge_idx < inv_bridge_count) {
                const consumed = inv_pre_counts[bridge_idx] -| inv_bridge[bridge_idx].count;
                if (consumed > 0) {
                    item.count -|= consumed;
                }
                bridge_idx += 1;
            }
        }
    }

    return enc_result;
}

fn awardBattleXp(
    dungeon_state: *dungeon_mod.DungeonState,
    gd: *const game_data_mod.GameData,
    active_idx: u2,
    enemy_level: u8,
    is_boss: bool,
) u32 {
    const xp_amount = leveling.battleXpAward(enemy_level, is_boss);
    const i: usize = active_idx;

    if (dungeon_state.party[i]) |*critter| {
        if (critter.current_hp == 0) return xp_amount;
        const result = leveling.awardXp(critter, xp_amount, gd);

        if (result.evolved) {
            if (result.new_species_id) |new_id| {
                dungeon_state.party_species[i] = gd.findSpecies(new_id);
            }
        }
    }
    return xp_amount;
}

fn persistCatches(
    dungeon_state: *const dungeon_mod.DungeonState,
    gd: *const game_data_mod.GameData,
    database: *db.Db,
) void {
    for (dungeon_state.catches[0..dungeon_state.catch_count]) |maybe_catch| {
        const catch_rec = maybe_catch orelse continue;
        const sp = gd.findSpecies(catch_rec.species_id) orelse continue;
        var new_critter = critter_mod.Critter.createFromSpecies(sp, catch_rec.level);
        _ = roster_db.saveCritter(database, &new_critter) catch |err| {
            std.log.err("persistCatches: saveCritter failed: {}", .{err});
        };
    }
}

fn handleExtraction(
    dungeon_state: *dungeon_mod.DungeonState,
    gd: *const game_data_mod.GameData,
    database: *db.Db,
) void {
    persistCatches(dungeon_state, gd, database);
    persistRunInventory(dungeon_state, database);
    awardExtractionXp(dungeon_state, gd);
    healPartyOnExtraction(dungeon_state);
}

fn awardExtractionXp(
    dungeon_state: *dungeon_mod.DungeonState,
    gd: *const game_data_mod.GameData,
) void {
    const bonus = 5 + @as(u32, dungeon_state.floor_number) * 2;
    for (&dungeon_state.party, 0..) |*maybe_critter, i| {
        if (maybe_critter.*) |*critter| {
            if (critter.current_hp == 0) continue;
            const result = leveling.awardXp(critter, bonus, gd);
            if (result.evolved) {
                if (result.new_species_id) |new_id| {
                    dungeon_state.party_species[i] = gd.findSpecies(new_id);
                }
            }
        }
    }
}

fn healPartyOnExtraction(dungeon_state: *dungeon_mod.DungeonState) void {
    for (&dungeon_state.party) |*maybe_critter| {
        if (maybe_critter.*) |*c| {
            if (c.current_hp > 0) {
                c.current_hp = c.effectiveStat(.hp);
            } else {
                c.cooldown_runs = 1;
            }
        }
    }
}

fn allUnavailable(roster: []const critter_mod.Critter) bool {
    for (roster) |critter| {
        if (critter.isAvailable()) return false;
    }
    return true;
}

fn decrementCooldowns(roster: []critter_mod.Critter, database: *db.Db) void {
    for (roster) |*critter| {
        if (critter.cooldown_runs > 0) {
            critter.cooldown_runs -= 1;
            // Heal to full when cooldown expires
            if (critter.cooldown_runs == 0) {
                critter.current_hp = critter.effectiveStat(.hp);
            }
            _ = roster_db.saveCritter(database, critter) catch |err| {
                std.log.err("decrementCooldowns: saveCritter failed: {}", .{err});
            };
        }
    }
}

fn persistPendingScars(
    dungeon_state: *const dungeon_mod.DungeonState,
    database: *db.Db,
    run_party_ids: *const [3]u64,
) void {
    for (dungeon_state.pending_scars[0..dungeon_state.pending_scar_count]) |scar| {
        const critter_id = run_party_ids[scar.party_index];
        if (critter_id != 0) {
            roster_db.addScar(database, @intCast(critter_id), scar.stat, -1) catch |err| {
                std.log.err("persistPendingScars: addScar failed: {}", .{err});
            };
        }
    }
}

fn savePartyState(
    dungeon_state: *const dungeon_mod.DungeonState,
    database: *db.Db,
    run_party_ids: *const [3]u64,
) void {
    for (dungeon_state.party, 0..) |maybe_critter, i| {
        if (maybe_critter) |critter| {
            if (run_party_ids[i] != 0) {
                var save_critter = critter;
                save_critter.id = run_party_ids[i];
                _ = roster_db.saveCritter(database, &save_critter) catch |err| {
                    std.log.err("savePartyState: saveCritter failed: {}", .{err});
                };
            }
        }
    }
}

fn persistRunInventory(
    dungeon_state: *const dungeon_mod.DungeonState,
    database: *db.Db,
) void {
    for (dungeon_state.run_inventory[0..dungeon_state.run_inventory_count]) |maybe_item| {
        const item = maybe_item orelse continue;
        if (item.count > 0) {
            roster_db.addInventoryItem(database, item.item_id, @intCast(item.count)) catch |err| {
                std.log.err("persistRunInventory: addInventoryItem failed: {}", .{err});
            };
        }
    }
    if (dungeon_state.currency > 0) {
        roster_db.addCurrency(database, dungeon_state.currency) catch |err| {
            std.log.err("persistRunInventory: addCurrency failed: {}", .{err});
        };
    }
}

fn markAllDirty(
    active_screen: ActiveScreen,
    title_scr: *TitleScreen,
    recap_scr: *RecapScreen,
    hub_screen: *HubScreen,
    party_select_screen: *PartySelectScreen,
    roster_screen: *RosterScreen,
    inv_scr: *InventoryScreen,
    dg_screen: *DungeonScreen,
    battle_screen: *BattleScreen,
    shop_screen: *ShopScreen,
    run_over_scr: *RunOverScreen,
) void {
    switch (active_screen) {
        .title => title_scr.dirty = true,
        .recap => recap_scr.dirty = true,
        .hub => hub_screen.dirty = true,
        .party_select => party_select_screen.dirty = true,
        .roster_view => roster_screen.dirty = true,
        .inventory => inv_scr.dirty = true,
        .dungeon => dg_screen.dirty = true,
        .battle => battle_screen.dirty = true,
        .shop => shop_screen.dirty = true,
        .run_over => run_over_scr.dirty = true,
    }
}

// --- CLI subcommand handlers ---

fn writeOut(comptime fmt: []const u8, args: anytype) void {
    var buf: [2048]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, fmt, args) catch return;
    std.fs.File.stdout().writeAll(str) catch {};
}

fn openDb() ?db.Db {
    var database = db.Db.open("codecritter.db") catch |err| {
        std.debug.print("Failed to open database: {}\n", .{err});
        return null;
    };
    database.initSchema() catch {
        database.close();
        return null;
    };
    return database;
}

fn printUsage() void {
    std.fs.File.stdout().writeAll(
        \\Usage: codecritter [command]
        \\
        \\Commands:
        \\  (no args)              Launch the game
        \\  log-event <type>       Log a coding event (bash, edit, write, etc.)
        \\  set-favorite <id>      Set which critter earns passive XP
        \\  status                 Output party status as JSON
        \\  statusline             Output compact statusline string
        \\
    ) catch {};
}

fn handleLogEvent(event_type: []const u8) void {
    var database = openDb() orelse return;
    defer database.close();

    passive_store.logEvent(&database, event_type) catch |err| {
        std.debug.print("Failed to log event: {}\n", .{err});
    };
}

fn handleSetFavorite(alloc: std.mem.Allocator, id_str: []const u8) void {
    const critter_id = std.fmt.parseInt(i64, id_str, 10) catch {
        std.debug.print("Invalid critter ID: {s}\n", .{id_str});
        return;
    };

    var database = openDb() orelse return;
    defer database.close();

    if (roster_db.loadCritter(&database, alloc, critter_id) catch null) |critter| {
        var c = critter;
        roster_db.freeCritter(alloc, &c);
    } else {
        std.debug.print("No critter with ID {d}\n", .{critter_id});
        return;
    }

    passive_store.setFavoriteCritterId(&database, critter_id) catch |err| {
        std.debug.print("Failed to set favorite: {}\n", .{err});
        return;
    };

    writeOut("Favorite critter set to ID {d}\n", .{critter_id});
}

fn handleStatus(alloc: std.mem.Allocator) void {
    var database = openDb() orelse return;
    defer database.close();

    var gd = game_data_mod.GameData.load(alloc) catch |err| {
        std.debug.print("Failed to load game data: {}\n", .{err});
        return;
    };
    defer gd.deinit();

    const fav_id = passive_store.getFavoriteCritterId(&database) orelse getFirstCritterId(&database);
    const pending = passive_store.countUnprocessedEvents(&database);
    const roster_count = roster_db.countCritters(&database);

    const on_cooldown = countCooldowns(&database);

    if (fav_id) |id| {
        if (roster_db.loadCritter(&database, alloc, id) catch null) |critter| {
            var c = critter;
            defer roster_db.freeCritter(alloc, &c);
            const sp_name = if (gd.findSpecies(c.species_id)) |sp| sp.name else c.species_id;
            writeOut(
                \\{{"favorite":{{"id":{d},"name":"{s}","species":"{s}","level":{d},"xp":{d},"hp":"{d}/{d}"}},"roster":{{"count":{d},"on_cooldown":{d}}},"pending_events":{d}}}
                \\
            , .{ c.id, sp_name, c.species_id, c.level, c.xp, c.current_hp, c.max_hp, roster_count, on_cooldown, pending });
            return;
        }
    }

    writeOut(
        \\{{"favorite":null,"roster":{{"count":{d},"on_cooldown":{d}}},"pending_events":{d}}}
        \\
    , .{ roster_count, on_cooldown, pending });
}

fn handleStatusline(alloc: std.mem.Allocator) void {
    var database = openDb() orelse return;
    defer database.close();

    var gd = game_data_mod.GameData.load(alloc) catch return;
    defer gd.deinit();

    const fav_id = passive_store.getFavoriteCritterId(&database) orelse getFirstCritterId(&database);

    if (fav_id) |id| {
        if (roster_db.loadCritter(&database, alloc, id) catch null) |critter| {
            var c = critter;
            defer roster_db.freeCritter(alloc, &c);
            const sp_name = if (gd.findSpecies(c.species_id)) |sp| sp.name else c.species_id;
            writeOut("{s} Lv{d} \xe2\x99\xa5{d}/{d}\n", .{ sp_name, c.level, c.current_hp, c.max_hp });
            return;
        }
    }

    std.fs.File.stdout().writeAll("No critters yet\n") catch {};
}

fn countCooldowns(database: *db.Db) u16 {
    const maybe_row = database.conn.row("SELECT COUNT(*) FROM critters WHERE cooldown_runs > 0", .{}) catch return 0;
    if (maybe_row) |row| {
        defer row.deinit();
        return @intCast(@max(row.int(0), 0));
    }
    return 0;
}

fn getFirstCritterId(database: *db.Db) ?i64 {
    const maybe_row = database.conn.row("SELECT id FROM critters ORDER BY id LIMIT 1", .{}) catch return null;
    if (maybe_row) |row| {
        defer row.deinit();
        return row.int(0);
    }
    return null;
}

// --- Passive reconciliation ---

fn runReconciliation(alloc: std.mem.Allocator, database: *db.Db, gd: *game_data_mod.GameData) ?RecapScreen {
    const event_count = passive_store.countUnprocessedEvents(database);
    if (event_count == 0) return null;

    const stored_fav = passive_store.getFavoriteCritterId(database);
    const fav_id = stored_fav orelse getFirstCritterId(database) orelse return null;

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
