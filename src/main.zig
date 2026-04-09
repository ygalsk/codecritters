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

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    focus_in,
    focus_out,
};

pub const panic = vaxis.Panic.call;

const ActiveScreen = enum {
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
    const sprite_ids = [_][]const u8{ "println", "tracer", "glitch", "goto", "monad", "copilot", "segfault", "mutex", "lgtm", "singleton" };
    var sprite_storage: [sprite_ids.len]sprite_mod.SpriteSheet = undefined;
    var sprite_count: usize = 0;
    for (sprite_ids) |id| {
        const path = spritePath(id) orelse continue;
        sprite_storage[sprite_count] = sprite_mod.SpriteSheet.loadFromFile(alloc, path) catch continue;
        sprite_map.put(id, &sprite_storage[sprite_count]);
        sprite_count += 1;
    }
    defer for (sprite_storage[0..sprite_count]) |*s| s.deinit();

    // Screen state
    var active_screen: ActiveScreen = .hub;
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
    var run_over_dirty = true;

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
    }

    var quit = false;
    while (!quit) {
        while (loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| {
                    if (key.matches('q', .{}) or key.matches('c', .{ .ctrl = true })) {
                        if (active_screen == .hub) {
                            quit = true;
                            break;
                        } else if (key.matches('c', .{ .ctrl = true })) {
                            quit = true;
                            break;
                        }
                    }
                    switch (active_screen) {
                        .hub => hub_screen.handleInput(key),
                        .party_select => party_select_screen.handleInput(key),
                        .roster_view => roster_screen.handleInput(key),
                        .inventory => inv_screen.handleInput(key),
                        .dungeon => dg_screen.handleInput(key),
                        .battle => battle_screen.handleInput(key),
                        .shop => shop_screen.handleInput(key),
                        .run_over => {
                            // Any key returns to hub
                            active_screen = .hub;
                            hub_screen = HubScreen.init(rosterCount(&database), roster_db.getCurrency(&database));
                        },
                    }
                },
                .winsize => |ws| {
                    try vx.resize(alloc, writer, ws);
                    markAllDirty(active_screen, &hub_screen, &party_select_screen, &roster_screen, &inv_screen, &dg_screen, &battle_screen, &shop_screen, &run_over_dirty);
                },
                else => {},
            }
        }
        if (quit) break;

        // Check screen transitions
        switch (active_screen) {
            .hub => {
                if (hub_screen.done) {
                    hub_screen.done = false;
                    switch (hub_screen.selection orelse .quit) {
                        .new_run => {
                            reloadRoster(alloc, &database, &gd, &roster_buf, &roster_species_buf);
                            party_select_screen = PartySelectScreen.init(roster_buf, roster_species_buf[0..roster_buf.len]);
                            active_screen = .party_select;
                        },
                        .view_roster => {
                            reloadRoster(alloc, &database, &gd, &roster_buf, &roster_species_buf);
                            if (inventory_buf.len > 0) {
                                roster_db.freeInventory(alloc, inventory_buf);
                                inventory_buf = &.{};
                            }
                            inventory_buf = roster_db.loadInventory(&database, alloc) catch &.{};
                            var inv_entries: [roster_screen_mod.MAX_DISCS]RosterScreen.InventoryEntry = undefined;
                            const inv_len = @min(inventory_buf.len, roster_screen_mod.MAX_DISCS);
                            for (0..inv_len) |i| {
                                inv_entries[i] = .{
                                    .item_id = inventory_buf[i].item_id,
                                    .quantity = inventory_buf[i].quantity,
                                };
                            }
                            roster_screen = RosterScreen.init(roster_buf, roster_species_buf[0..roster_buf.len], inv_entries[0..inv_len], &gd);
                            active_screen = .roster_view;
                        },
                        .view_inventory => {
                            if (inventory_buf.len > 0) {
                                roster_db.freeInventory(alloc, inventory_buf);
                                inventory_buf = &.{};
                            }
                            inventory_buf = roster_db.loadInventory(&database, alloc) catch &.{};
                            const inv_len = @min(inventory_buf.len, inv_screen_entries.len);
                            for (0..inv_len) |i| {
                                inv_screen_entries[i] = .{
                                    .item_id = inventory_buf[i].item_id,
                                    .quantity = inventory_buf[i].quantity,
                                };
                            }
                            inv_screen = InventoryScreen.init(inv_screen_entries[0..inv_len], &gd, roster_db.getCurrency(&database));
                            active_screen = .inventory;
                        },
                        .quit => {
                            quit = true;
                        },
                    }
                    hub_screen.selection = null;
                }
            },
            .party_select => {
                if (party_select_screen.done) {
                    if (party_select_screen.confirmed) {
                        // Build party from selected roster indices
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
                            // Decrement cooldowns for all roster critters
                            decrementCooldowns(roster_buf, &database);

                            const seed: u64 = @intCast(std.time.milliTimestamp());
                            dungeon_state = dungeon_mod.startRun(
                                party_critters[0..party_count],
                                party_species[0..party_count],
                                biome_ptr,
                                seed,
                            );
                            dg_screen = DungeonScreen.init(&dungeon_state, &gd);
                            active_screen = .dungeon;
                        } else {
                            // No valid party, go back to hub
                            active_screen = .hub;
                            hub_screen = HubScreen.init(rosterCount(&database), roster_db.getCurrency(&database));
                        }
                    } else {
                        // Cancelled
                        active_screen = .hub;
                        hub_screen = HubScreen.init(rosterCount(&database), roster_db.getCurrency(&database));
                    }
                }
            },
            .roster_view => {
                // Handle pending equip events (persist to DB)
                if (roster_screen.pending_equip) |equip| {
                    if (equip.critter_idx < roster_buf.len) {
                        const critter = &roster_buf[equip.critter_idx];
                        // Save updated critter to DB
                        _ = roster_db.saveCritter(&database, critter) catch {};
                        // Consume disc from inventory
                        roster_db.removeInventoryItem(&database, equip.item_id, 1) catch {};
                    }
                    roster_screen.pending_equip = null;
                }
                if (roster_screen.done) {
                    active_screen = .hub;
                    hub_screen = HubScreen.init(rosterCount(&database), roster_db.getCurrency(&database));
                }
            },
            .inventory => {
                if (inv_screen.done) {
                    active_screen = .hub;
                    hub_screen = HubScreen.init(rosterCount(&database), roster_db.getCurrency(&database));
                }
            },
            .dungeon => {
                if (dg_screen.pending_battle) |info| {
                    dg_screen.pending_battle = null;
                    last_was_boss = dg_screen.pending_is_boss;
                    if (startBattle(&dungeon_state, info, &gd, &inv_bridge, &inv_bridge_count, &inv_pre_counts, &battle_state, &battle_screen, &sprite_map, use_kitty)) {
                        active_screen = .battle;
                    }
                } else if (dg_screen.pending_shop) {
                    dg_screen.pending_shop = false;
                    dungeon_mod.generateBetweenFloorShop(&dungeon_state, &gd);
                    shop_screen = ShopScreen.init(&dungeon_state, &gd);
                    active_screen = .shop;
                }
            },
            .battle => {
                if (battle_screen.done) {
                    const enc_result = finishBattle(&dungeon_state, &battle_state, &inv_bridge, inv_bridge_count, &inv_pre_counts);

                    // Show drop notification
                    if (enc_result.dropped_item_id) |item_id| {
                        if (gd.findItem(item_id)) |item| {
                            var drop_buf: [64]u8 = undefined;
                            const drop_msg = std.fmt.bufPrint(&drop_buf, "Found a {s}!", .{item.name}) catch "Found an item!";
                            dg_screen.log.push(drop_msg);
                        }
                    }

                    // Award XP on win/catch
                    const b_outcome = battle_state.outcome orelse .player_lose;
                    if (b_outcome == .player_win or b_outcome == .caught) {
                        awardPartyXp(&dungeon_state, &gd, battle_state.wild.critter.level, last_was_boss);
                    }

                    if (dungeon_state.phase == .run_over) {
                        // Persist catches and inventory on extraction
                        if (dungeon_state.outcome == .extracted) {
                            persistCatches(&dungeon_state, &gd, &database);
                            persistRunInventory(&dungeon_state, &database);
                        }
                        // Apply cooldowns on wipe
                        if (dungeon_state.outcome == .wiped) {
                            for (&dungeon_state.party) |*maybe_critter| {
                                if (maybe_critter.*) |*c| {
                                    c.cooldown_runs = 2;
                                }
                            }
                        }
                        // Persist scars earned during the run
                        persistPendingScars(&dungeon_state, &database, &run_party_ids);
                        // Save party state back to DB
                        savePartyState(&dungeon_state, &database, &run_party_ids);
                        active_screen = .run_over;
                        run_over_dirty = true;
                    } else if (dungeon_state.phase == .between_floors) {
                        dungeon_mod.generateBetweenFloorShop(&dungeon_state, &gd);
                        shop_screen = ShopScreen.init(&dungeon_state, &gd);
                        active_screen = .shop;
                    } else {
                        active_screen = .dungeon;
                        dg_screen.dirty = true;
                    }
                }
            },
            .shop => {
                if (shop_screen.done) {
                    if (shop_screen.extracted) {
                        dungeon_mod.extract(&dungeon_state);
                        persistCatches(&dungeon_state, &gd, &database);
                        persistRunInventory(&dungeon_state, &database);
                        persistPendingScars(&dungeon_state, &database, &run_party_ids);
                        savePartyState(&dungeon_state, &database, &run_party_ids);
                        active_screen = .run_over;
                        run_over_dirty = true;
                    } else {
                        dungeon_mod.advanceFloor(&dungeon_state);
                        dg_screen.resetVisited();
                        var buf: [64]u8 = undefined;
                        const msg = std.fmt.bufPrint(&buf, "Entered Floor {d}", .{dungeon_state.floor_number}) catch "Next floor!";
                        dg_screen.log.push(msg);
                        dg_screen.dirty = true;
                        active_screen = .dungeon;
                    }
                }
            },
            .run_over => {},
        }

        if (active_screen == .battle) {
            battle_screen.updateAnimation();
        }

        // Render
        const dirty = switch (active_screen) {
            .hub => hub_screen.dirty,
            .party_select => party_select_screen.dirty,
            .roster_view => roster_screen.dirty,
            .inventory => inv_screen.dirty,
            .dungeon => dg_screen.dirty,
            .battle => battle_screen.dirty,
            .shop => shop_screen.dirty,
            .run_over => run_over_dirty,
        };

        if (dirty) {
            switch (active_screen) {
                .hub => hub_screen.dirty = false,
                .party_select => party_select_screen.dirty = false,
                .roster_view => roster_screen.dirty = false,
                .inventory => inv_screen.dirty = false,
                .dungeon => dg_screen.dirty = false,
                .battle => battle_screen.dirty = false,
                .shop => shop_screen.dirty = false,
                .run_over => run_over_dirty = false,
            }
            const win = vx.window();
            switch (active_screen) {
                .hub => hub_screen.render(win),
                .party_select => party_select_screen.render(win),
                .roster_view => roster_screen.render(win),
                .inventory => inv_screen.render(win),
                .dungeon => dg_screen.render(win),
                .battle => battle_screen.render(win),
                .shop => shop_screen.render(win),
                .run_over => renderRunOver(win, &dungeon_state),
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

fn rosterCount(database: *db.Db) u16 {
    return roster_db.countCritters(database);
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
                party_critters[party_count] = c;
                party_species[party_count] = sp;
                party_count += 1;
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

fn awardPartyXp(
    dungeon_state: *dungeon_mod.DungeonState,
    gd: *const game_data_mod.GameData,
    enemy_level: u8,
    is_boss: bool,
) void {
    const xp_amount = leveling.battleXpAward(enemy_level, is_boss);

    for (&dungeon_state.party, 0..) |*maybe_critter, i| {
        if (maybe_critter.*) |*critter| {
            if (critter.current_hp == 0) continue;
            const result = leveling.awardXp(critter, xp_amount, gd);

            if (result.evolved) {
                if (result.new_species_id) |new_id| {
                    dungeon_state.party_species[i] = gd.findSpecies(new_id);
                }
            }
        }
    }
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
        _ = roster_db.saveCritter(database, &new_critter) catch {};
    }
}

fn decrementCooldowns(roster: []critter_mod.Critter, database: *db.Db) void {
    for (roster) |*critter| {
        if (critter.cooldown_runs > 0) {
            critter.cooldown_runs -= 1;
            // Heal to full when cooldown expires
            if (critter.cooldown_runs == 0) {
                critter.current_hp = critter.effectiveStat(.hp);
            }
            _ = roster_db.saveCritter(database, critter) catch {};
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
            roster_db.addScar(database, @intCast(critter_id), scar.stat, -1) catch {};
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
                _ = roster_db.saveCritter(database, &save_critter) catch {};
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
            roster_db.addInventoryItem(database, item.item_id, @intCast(item.count)) catch {};
        }
    }
    if (dungeon_state.currency > 0) {
        roster_db.addCurrency(database, dungeon_state.currency) catch {};
    }
}

fn markAllDirty(
    active_screen: ActiveScreen,
    hub_screen: *HubScreen,
    party_select_screen: *PartySelectScreen,
    roster_screen: *RosterScreen,
    inv_scr: *InventoryScreen,
    dg_screen: *DungeonScreen,
    battle_screen: *BattleScreen,
    shop_screen: *ShopScreen,
    run_over_dirty: *bool,
) void {
    switch (active_screen) {
        .hub => hub_screen.dirty = true,
        .party_select => party_select_screen.dirty = true,
        .roster_view => roster_screen.dirty = true,
        .inventory => inv_scr.dirty = true,
        .dungeon => dg_screen.dirty = true,
        .battle => battle_screen.dirty = true,
        .shop => shop_screen.dirty = true,
        .run_over => run_over_dirty.* = true,
    }
}

fn renderRunOver(win: vaxis.Window, dungeon_state: *const dungeon_mod.DungeonState) void {
    win.clear();

    const white_bold: ui.Style = .{ .fg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true };
    const gold: ui.Style = .{ .fg = .{ .rgb = .{ 255, 200, 40 } }, .bold = true };
    const gray: ui.Style = .{ .fg = .{ .rgb = .{ 180, 180, 180 } } };

    const title = switch (dungeon_state.outcome) {
        .extracted => "Run Complete - Extracted!",
        .wiped => "Run Over - Wiped!",
        .in_progress => "Run Over",
    };

    const title_color: ui.Style = if (dungeon_state.outcome == .extracted)
        .{ .fg = .{ .rgb = .{ 80, 255, 120 } }, .bold = true }
    else
        .{ .fg = .{ .rgb = .{ 255, 60, 60 } }, .bold = true };

    _ = ui.writeText(win, 2, 1, title, title_color);

    _ = ui.writeFmt(win, 2, 3, white_bold, "Floors cleared: {d}", .{dungeon_state.floor_number});
    _ = ui.writeFmt(win, 2, 4, gold, "Currency earned: ${d}", .{dungeon_state.currency});
    _ = ui.writeFmt(win, 2, 5, gray, "Critters caught: {d}", .{dungeon_state.catch_count});

    var row: u16 = 7;

    if (dungeon_state.catch_count > 0) {
        _ = ui.writeText(win, 2, row, "Catches:", gray);
        row += 1;
        for (dungeon_state.catches[0..dungeon_state.catch_count]) |maybe_catch| {
            const catch_rec = maybe_catch orelse continue;
            if (row >= win.height) break;
            _ = ui.writeFmt(win, 4, row, gray, "{s} Lv{d} (floor {d})", .{ catch_rec.species_id, catch_rec.level, catch_rec.floor_caught });
            row += 1;
        }
        row += 1;
    }

    // Show scars earned
    const scar_style: ui.Style = .{ .fg = .{ .rgb = .{ 200, 100, 100 } } };
    if (dungeon_state.pending_scar_count > 0) {
        _ = ui.writeText(win, 2, row, "Scars:", scar_style);
        row += 1;
        for (dungeon_state.pending_scars[0..dungeon_state.pending_scar_count]) |scar| {
            if (row >= win.height) break;
            if (dungeon_state.party[scar.party_index]) |c| {
                _ = ui.writeFmt(win, 4, row, scar_style, "{s}: -1 {s}", .{ c.species_id, scar.stat.displayName() });
            } else {
                _ = ui.writeFmt(win, 4, row, scar_style, "Party #{d}: -1 {s}", .{ scar.party_index + 1, scar.stat.displayName() });
            }
            row += 1;
        }
        row += 1;
    }

    // Show cooldown on wipe
    if (dungeon_state.outcome == .wiped) {
        _ = ui.writeText(win, 2, row, "Your critters need 2 runs to recover.", .{ .fg = .{ .rgb = .{ 255, 100, 100 } }, .bold = true });
    }

    const hint_row = if (win.height > 4) win.height - 2 else win.height;
    if (hint_row < win.height) {
        _ = ui.writeText(win, 2, hint_row, "[Press any key to continue]", ui.dim_style);
    }
}
