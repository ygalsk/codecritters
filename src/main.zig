const std = @import("std");
const vaxis = @import("vaxis");

const game_data_mod = @import("game_data");
const species_mod = @import("species");
const items_mod = @import("items");
const critter_mod = @import("critter");
const battle = @import("battle");
const dungeon_mod = @import("dungeon");
const db = @import("db/db.zig");
const battle_screen_mod = @import("ui/battle_screen.zig");
const BattleScreen = battle_screen_mod.BattleScreen;
const InventorySlot = battle_screen_mod.InventorySlot;
const dungeon_screen_mod = @import("ui/dungeon_screen.zig");
const DungeonScreen = dungeon_screen_mod.DungeonScreen;
const shop_screen_mod = @import("ui/shop_screen.zig");
const ShopScreen = shop_screen_mod.ShopScreen;
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

    // Load biomes
    var biomes = dungeon_mod.biome.load(alloc, "data/biomes.json") catch |err| {
        std.debug.print("Failed to load biomes: {}\n", .{err});
        return err;
    };
    defer biomes.deinit();

    const biome_ptr = dungeon_mod.biome.findById(biomes.value, "generic_dungeon") orelse {
        std.debug.print("Missing generic_dungeon biome\n", .{});
        return error.MissingBiome;
    };

    // Load sprite sheets for known critters
    var sprite_map = SpriteMap{};
    const sprite_ids = [_][]const u8{ "println", "tracer", "glitch", "goto", "monad" };
    var sprite_storage: [sprite_ids.len]sprite_mod.SpriteSheet = undefined;
    var sprite_count: usize = 0;
    for (sprite_ids) |id| {
        const path = spritePath(id) orelse continue;
        sprite_storage[sprite_count] = sprite_mod.SpriteSheet.loadFromFile(alloc, path) catch continue;
        sprite_map.put(id, &sprite_storage[sprite_count]);
        sprite_count += 1;
    }
    defer for (sprite_storage[0..sprite_count]) |*s| s.deinit();

    // Setup starter party
    const player_sp = gd.findSpecies("println") orelse return error.MissingSpecies;
    const partner_sp = gd.findSpecies("goto") orelse return error.MissingSpecies;

    const player_critter = critter_mod.Critter.createFromSpecies(player_sp, 10);
    const partner_critter = critter_mod.Critter.createFromSpecies(partner_sp, 10);

    const party_critters = [_]critter_mod.Critter{ player_critter, partner_critter };
    const party_species = [_]*const species_mod.Species{ player_sp, partner_sp };

    const seed: u64 = @intCast(std.time.milliTimestamp());
    var dungeon_state = dungeon_mod.startRun(&party_critters, &party_species, biome_ptr, seed);

    // Screen state
    var active_screen: ActiveScreen = .dungeon;
    var dg_screen = DungeonScreen.init(&dungeon_state, &gd);
    var battle_state: battle.BattleState = undefined;
    var battle_screen: BattleScreen = undefined;
    var shop_screen: ShopScreen = undefined;
    var use_kitty = false;
    var run_over_dirty = true;

    // Inventory bridge storage
    var inv_bridge: [dungeon_mod.MAX_RUN_ITEMS]InventorySlot = undefined;
    var inv_bridge_count: usize = 0;
    var inv_pre_counts: [dungeon_mod.MAX_RUN_ITEMS]u8 = undefined;

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
                        quit = true;
                        break;
                    }
                    switch (active_screen) {
                        .dungeon => dg_screen.handleInput(key),
                        .battle => battle_screen.handleInput(key),
                        .shop => shop_screen.handleInput(key),
                        .run_over => {
                            quit = true;
                            break;
                        },
                    }
                },
                .winsize => |ws| {
                    try vx.resize(alloc, writer, ws);
                    switch (active_screen) {
                        .dungeon => dg_screen.dirty = true,
                        .battle => battle_screen.dirty = true,
                        .shop => shop_screen.dirty = true,
                        .run_over => run_over_dirty = true,
                    }
                },
                else => {},
            }
        }
        if (quit) break;

        // Check screen transitions
        switch (active_screen) {
            .dungeon => {
                if (dg_screen.pending_battle) |info| {
                    dg_screen.pending_battle = null;
                    if (startBattle(&dungeon_state, info, &gd, &inv_bridge, &inv_bridge_count, &inv_pre_counts, &battle_state, &battle_screen, &sprite_map, use_kitty, seed)) {
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
                    finishBattle(&dungeon_state, &battle_state, &inv_bridge, inv_bridge_count, &inv_pre_counts);

                    if (dungeon_state.phase == .run_over) {
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
            .dungeon => dg_screen.dirty,
            .battle => battle_screen.dirty,
            .shop => shop_screen.dirty,
            .run_over => run_over_dirty,
        };

        if (dirty) {
            switch (active_screen) {
                .dungeon => dg_screen.dirty = false,
                .battle => battle_screen.dirty = false,
                .shop => shop_screen.dirty = false,
                .run_over => run_over_dirty = false,
            }
            const win = vx.window();
            switch (active_screen) {
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
    seed: u64,
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

    battle_state.* = battle.initBattle(
        party_critters[0..party_count],
        party_species[0..party_count],
        wild_critter,
        wild_sp,
        seed +% @as(u64, @intCast(std.time.milliTimestamp())),
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
) void {
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

    dungeon_mod.resolveEncounter(dungeon_state, d_outcome, updated_party, caught_species_id, caught_level);

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

    if (dungeon_state.catch_count > 0) {
        var row: u16 = 7;
        _ = ui.writeText(win, 2, row, "Catches:", gray);
        row += 1;
        for (dungeon_state.catches[0..dungeon_state.catch_count]) |maybe_catch| {
            const catch_rec = maybe_catch orelse continue;
            if (row >= win.height) break;
            _ = ui.writeFmt(win, 4, row, gray, "{s} Lv{d} (floor {d})", .{ catch_rec.species_id, catch_rec.level, catch_rec.floor_caught });
            row += 1;
        }
    }

    const hint_row = if (win.height > 4) win.height - 2 else win.height;
    if (hint_row < win.height) {
        _ = ui.writeText(win, 2, hint_row, "[Press any key to exit]", ui.dim_style);
    }
}
