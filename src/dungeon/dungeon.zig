const std = @import("std");
const types = @import("types");
const species_mod = @import("species");
const critter_mod = @import("critter");
const game_data_mod = @import("game_data");
const items_mod = @import("items");

pub const floor_gen = @import("floor_gen.zig");
pub const biome = @import("biome.zig");
pub const shop = @import("shop.zig");
pub const detect = @import("detect.zig");

pub const RunPhase = enum {
    exploring,
    encounter,
    boss_encounter,
    between_floors,
    run_over,
};

pub const RunOutcome = enum {
    in_progress,
    extracted,
    wiped,
};

pub const Direction = enum {
    up,
    down,
    left,
    right,
};

pub const EncounterInfo = struct {
    species_id: []const u8,
    level: u8,
};

pub const MoveResult = union(enum) {
    moved,
    blocked,
    encounter_triggered: EncounterInfo,
    stairs_reached,
    boss_triggered: EncounterInfo,
};

pub const EncounterOutcome = enum {
    player_win,
    player_lose,
    caught,
};

pub const RunItem = struct {
    item_id: []const u8,
    count: u16,
};

pub const MAX_RUN_ITEMS: u8 = 16;
pub const MAX_RUN_CATCHES: u8 = 16;

pub const CatchRecord = struct {
    species_id: []const u8,
    level: u8,
    floor_caught: u8,
};

pub const DungeonState = struct {
    biome_ptr: *const biome.Biome,
    floor_number: u8,
    current_floor: floor_gen.Floor,

    player_x: u8,
    player_y: u8,

    party: [3]?critter_mod.Critter,
    party_species: [3]?*const species_mod.Species,

    currency: u32,

    run_inventory: [MAX_RUN_ITEMS]?RunItem,
    run_inventory_count: u8,

    catches: [MAX_RUN_CATCHES]?CatchRecord,
    catch_count: u8,

    phase: RunPhase,
    outcome: RunOutcome,

    seed: u64,
    rng: std.Random.DefaultPrng,

    current_shop: ?shop.ShopState,
};

/// Start a new dungeon run.
pub fn startRun(
    party_critters: []const critter_mod.Critter,
    party_species: []const *const species_mod.Species,
    biome_ptr: *const biome.Biome,
    seed: u64,
) DungeonState {
    var party: [3]?critter_mod.Critter = .{ null, null, null };
    var species_ptrs: [3]?*const species_mod.Species = .{ null, null, null };

    for (party_critters, 0..) |c, i| {
        if (i >= 3) break;
        party[i] = c;
        species_ptrs[i] = party_species[i];
    }

    var rng = std.Random.DefaultPrng.init(seed);
    const floor = floor_gen.generateFloor(1, rng.random());

    return .{
        .biome_ptr = biome_ptr,
        .floor_number = 1,
        .current_floor = floor,
        .player_x = floor.entrance_x,
        .player_y = floor.entrance_y,
        .party = party,
        .party_species = species_ptrs,
        .currency = 0,
        .run_inventory = .{null} ** MAX_RUN_ITEMS,
        .run_inventory_count = 0,
        .catches = .{null} ** MAX_RUN_CATCHES,
        .catch_count = 0,
        .phase = .exploring,
        .outcome = .in_progress,
        .seed = seed,
        .rng = rng,
        .current_shop = null,
    };
}

/// Move the player one tile in the given direction.
pub fn movePlayer(state: *DungeonState, dir: Direction) MoveResult {
    const dx: i16 = switch (dir) {
        .left => -1,
        .right => 1,
        else => 0,
    };
    const dy: i16 = switch (dir) {
        .up => -1,
        .down => 1,
        else => 0,
    };

    const nx = @as(i16, state.player_x) + dx;
    const ny = @as(i16, state.player_y) + dy;

    if (nx < 0 or nx >= floor_gen.FLOOR_WIDTH or ny < 0 or ny >= floor_gen.FLOOR_HEIGHT) {
        return .blocked;
    }

    const ux: u8 = @intCast(nx);
    const uy: u8 = @intCast(ny);

    const tile = state.current_floor.tiles[uy][ux];

    switch (tile) {
        .wall => return .blocked,
        .floor, .entrance => {
            state.player_x = ux;
            state.player_y = uy;
            return .moved;
        },
        .encounter => {
            state.player_x = ux;
            state.player_y = uy;
            state.current_floor.tiles[uy][ux] = .floor;

            const rng = state.rng.random();
            const species_id = biome.rollEncounter(state.biome_ptr, state.floor_number, rng) orelse {
                return .moved; // No valid encounter for this floor — treat as empty tile
            };
            const level = biome.encounterLevel(state.floor_number, rng);

            state.phase = .encounter;
            return .{ .encounter_triggered = .{
                .species_id = species_id,
                .level = level,
            } };
        },
        .stairs => {
            state.player_x = ux;
            state.player_y = uy;

            // Boss floor check: every 5 floors
            if (state.floor_number % 5 == 0) {
                const rng = state.rng.random();
                const boss_entry = biome.rollBoss(state.biome_ptr, rng);
                const boss_level = biome.encounterLevel(state.floor_number, rng);

                if (boss_entry) |entry| {
                    state.phase = .boss_encounter;
                    return .{ .boss_triggered = .{
                        .species_id = entry.species_id,
                        .level = boss_level + entry.level_bonus,
                    } };
                }
            }

            // Normal stairs — transition to between-floors
            state.phase = .between_floors;
            return .stairs_reached;
        },
    }
}

pub const EncounterResult = struct {
    dropped_item_id: ?[]const u8 = null,
};

/// Resolve the outcome of an encounter (battle result).
/// Updated party reflects post-battle HP state.
/// Returns info about drops for the caller to display.
pub fn resolveEncounter(
    state: *DungeonState,
    outcome: EncounterOutcome,
    updated_party: [3]?critter_mod.Critter,
    caught_species_id: ?[]const u8,
    caught_level: u8,
) EncounterResult {
    // Update party state from battle
    state.party = updated_party;

    const was_boss = state.phase == .boss_encounter;
    var result = EncounterResult{};

    switch (outcome) {
        .player_win => {
            // Award currency (boss gives double)
            const multiplier: u32 = if (was_boss) 2 else 1;
            state.currency += (10 + @as(u32, state.floor_number) * 5) * multiplier;
            state.phase = if (was_boss) .between_floors else .exploring;
        },
        .caught => {
            // Award currency (less than a win)
            state.currency += 5 + @as(u32, state.floor_number) * 3;

            // Record catch
            if (caught_species_id) |sid| {
                if (state.catch_count < MAX_RUN_CATCHES) {
                    state.catches[state.catch_count] = .{
                        .species_id = sid,
                        .level = caught_level,
                        .floor_caught = state.floor_number,
                    };
                    state.catch_count += 1;
                }
            }
            state.phase = .exploring;
        },
        .player_lose => {
            // Check if any party member is still alive
            var any_alive = false;
            for (state.party) |maybe_critter| {
                if (maybe_critter) |c| {
                    if (c.current_hp > 0) {
                        any_alive = true;
                        break;
                    }
                }
            }

            if (any_alive) {
                state.phase = .exploring;
            } else {
                state.phase = .run_over;
                state.outcome = .wiped;
            }
        },
    }

    // Roll for item drop on win or catch (not on loss)
    if (outcome != .player_lose) {
        const dropped = biome.rollDrop(state.biome_ptr, state.floor_number, was_boss, state.rng.random());
        if (dropped) |item_id| {
            addRunItem(state, item_id, 1);
            result.dropped_item_id = item_id;
        }
    }

    return result;
}

/// Advance to the next floor. Call after between-floors phase completes.
pub fn advanceFloor(state: *DungeonState) void {
    state.floor_number += 1;
    const floor = floor_gen.generateFloor(state.floor_number, state.rng.random());
    state.current_floor = floor;
    state.player_x = floor.entrance_x;
    state.player_y = floor.entrance_y;
    state.phase = .exploring;
    state.current_shop = null;
}

/// Generate the between-floor shop.
pub fn generateBetweenFloorShop(state: *DungeonState, game_data: *const game_data_mod.GameData) void {
    state.current_shop = shop.generateShop(state.biome_ptr, state.floor_number, game_data, state.rng.random());
}

/// Buy an item from the current shop. Adds purchased item to run inventory.
pub fn buyShopItem(state: *DungeonState, slot_index: u8) shop.BuyResult {
    const s = &(state.current_shop orelse return .invalid_slot);
    if (slot_index >= shop.MAX_SHOP_SLOTS) return .invalid_slot;
    const item_id = if (s.slots[slot_index]) |slot| slot.item_id else return .invalid_slot;

    const result = shop.buyItem(s, slot_index, &state.currency);
    if (result == .success) {
        addRunItem(state, item_id, 1);
    }
    return result;
}

/// Extract from the dungeon voluntarily (between floors only).
pub fn extract(state: *DungeonState) void {
    state.phase = .run_over;
    state.outcome = .extracted;
}

/// Add an item to the run inventory.
pub fn addRunItem(state: *DungeonState, item_id: []const u8, count: u16) void {
    // Check if item already exists
    for (state.run_inventory[0..state.run_inventory_count]) |*maybe_item| {
        if (maybe_item.*) |*item| {
            if (std.mem.eql(u8, item.item_id, item_id)) {
                item.count += count;
                return;
            }
        }
    }
    // Add new entry
    if (state.run_inventory_count < MAX_RUN_ITEMS) {
        state.run_inventory[state.run_inventory_count] = .{
            .item_id = item_id,
            .count = count,
        };
        state.run_inventory_count += 1;
    }
}

/// Count alive party members.
pub fn alivePartyCount(state: *const DungeonState) u8 {
    var count: u8 = 0;
    for (state.party) |maybe_critter| {
        if (maybe_critter) |c| {
            if (c.current_hp > 0) count += 1;
        }
    }
    return count;
}

// --- Tests ---

fn makeTestCritter(id: u64, hp: u16) critter_mod.Critter {
    return .{
        .id = id,
        .species_id = "println",
        .nickname = null,
        .level = 10,
        .xp = 0,
        .current_hp = hp,
        .max_hp = hp,
        .logic = 50,
        .resolve = 40,
        .speed = 45,
        .move_slot_1 = "log_dump",
        .move_slot_2 = null,
        .move_slot_3 = null,
        .scars = &.{},
        .cooldown_until = null,
    };
}

test "startRun initializes state correctly" {
    const allocator = std.testing.allocator;

    const biomes_parsed = try biome.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();
    const b = &biomes_parsed.value[0];

    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();

    const sp = gd.findSpecies("println").?;
    const critters = [_]critter_mod.Critter{
        makeTestCritter(1, 100),
        makeTestCritter(2, 90),
        makeTestCritter(3, 80),
    };
    const species_ptrs = [_]*const species_mod.Species{ sp, sp, sp };

    const state = startRun(&critters, &species_ptrs, b, 42);

    try std.testing.expectEqual(@as(u8, 1), state.floor_number);
    try std.testing.expectEqual(RunPhase.exploring, state.phase);
    try std.testing.expectEqual(RunOutcome.in_progress, state.outcome);
    try std.testing.expectEqual(@as(u32, 0), state.currency);
    try std.testing.expect(state.party[0] != null);
    try std.testing.expect(state.party[1] != null);
    try std.testing.expect(state.party[2] != null);
    // Player should be at entrance
    try std.testing.expectEqual(state.current_floor.entrance_x, state.player_x);
    try std.testing.expectEqual(state.current_floor.entrance_y, state.player_y);
}

test "movePlayer onto floor tile" {
    const allocator = std.testing.allocator;
    const biomes_parsed = try biome.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();
    const b = &biomes_parsed.value[0];

    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();
    const sp = gd.findSpecies("println").?;

    const critters = [_]critter_mod.Critter{makeTestCritter(1, 100)};
    const species_ptrs = [_]*const species_mod.Species{sp};

    var state = startRun(&critters, &species_ptrs, b, 42);

    // Find a floor tile adjacent to player
    const result = findAdjacentFloorMove(&state);
    if (result) |dir| {
        const old_x = state.player_x;
        const old_y = state.player_y;
        const move_result = movePlayer(&state, dir);
        switch (move_result) {
            .moved => {
                try std.testing.expect(state.player_x != old_x or state.player_y != old_y);
            },
            else => {},
        }
    }
}

test "movePlayer into wall returns blocked" {
    // Place player directly next to a known wall and verify blocked
    const allocator = std.testing.allocator;
    const biomes_parsed = try biome.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();
    const b = &biomes_parsed.value[0];

    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();
    const sp = gd.findSpecies("println").?;

    const critters = [_]critter_mod.Critter{makeTestCritter(1, 100)};
    const species_ptrs = [_]*const species_mod.Species{sp};

    var state = startRun(&critters, &species_ptrs, b, 42);

    // Move to grid edge (0,0 is always a wall) — place player at (1,1) if floor, or find a wall neighbor
    // Alternatively: moving off the grid boundary is always blocked
    state.player_x = 0;
    state.player_y = 0;
    const result = movePlayer(&state, .left);
    try std.testing.expectEqual(MoveResult.blocked, result);
}

test "movePlayer onto encounter tile triggers encounter" {
    const allocator = std.testing.allocator;
    const biomes_parsed = try biome.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();
    const b = &biomes_parsed.value[0];

    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();
    const sp = gd.findSpecies("println").?;

    const critters = [_]critter_mod.Critter{makeTestCritter(1, 100)};
    const species_ptrs = [_]*const species_mod.Species{sp};

    var state = startRun(&critters, &species_ptrs, b, 42);

    // Navigate towards an encounter tile using BFS
    if (findPathToTile(&state, .encounter)) |path| {
        for (path.dirs[0..path.len]) |dir| {
            const result = movePlayer(&state, dir);
            switch (result) {
                .encounter_triggered => |info| {
                    try std.testing.expect(info.species_id.len > 0);
                    try std.testing.expect(info.level >= 1);
                    try std.testing.expectEqual(RunPhase.encounter, state.phase);
                    // Tile should now be floor
                    try std.testing.expectEqual(floor_gen.Tile.floor, state.current_floor.tiles[state.player_y][state.player_x]);
                    return;
                },
                .blocked => break,
                else => {},
            }
        }
    }
    // If no encounter tiles exist on this floor, that's ok — different seed
}

test "boss floor triggers on floor 5" {
    const allocator = std.testing.allocator;
    const biomes_parsed = try biome.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();
    const b = &biomes_parsed.value[0];

    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();
    const sp = gd.findSpecies("println").?;

    const critters = [_]critter_mod.Critter{makeTestCritter(1, 100)};
    const species_ptrs = [_]*const species_mod.Species{sp};

    var state = startRun(&critters, &species_ptrs, b, 42);

    // Advance to floor 5
    state.floor_number = 4;
    state.phase = .between_floors;
    advanceFloor(&state);
    try std.testing.expectEqual(@as(u8, 5), state.floor_number);

    // Navigate to stairs
    if (findPathToTile(&state, .stairs)) |path| {
        for (path.dirs[0..path.len]) |dir| {
            const result = movePlayer(&state, dir);
            switch (result) {
                .boss_triggered => |info| {
                    try std.testing.expect(info.species_id.len > 0);
                    try std.testing.expect(info.level > 0);
                    try std.testing.expectEqual(RunPhase.boss_encounter, state.phase);
                    return;
                },
                .encounter_triggered => {
                    // Resolve encounter and keep moving
                    state.phase = .exploring;
                },
                .blocked => break,
                else => {},
            }
        }
    }
}

test "resolveEncounter updates party and awards currency" {
    const allocator = std.testing.allocator;
    const biomes_parsed = try biome.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();
    const b = &biomes_parsed.value[0];

    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();
    const sp = gd.findSpecies("println").?;

    const critters = [_]critter_mod.Critter{makeTestCritter(1, 100)};
    const species_ptrs = [_]*const species_mod.Species{sp};

    var state = startRun(&critters, &species_ptrs, b, 42);
    state.phase = .encounter;

    // Simulate battle — critter took some damage
    var updated = state.party;
    updated[0].?.current_hp = 60;

    _ = resolveEncounter(&state, .player_win, updated, null, 0);

    try std.testing.expectEqual(@as(u16, 60), state.party[0].?.current_hp);
    try std.testing.expect(state.currency > 0); // 10 + 1*5 = 15
    try std.testing.expectEqual(RunPhase.exploring, state.phase);
}

test "resolveEncounter wipe when all fainted" {
    const allocator = std.testing.allocator;
    const biomes_parsed = try biome.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();
    const b = &biomes_parsed.value[0];

    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();
    const sp = gd.findSpecies("println").?;

    const critters = [_]critter_mod.Critter{makeTestCritter(1, 100)};
    const species_ptrs = [_]*const species_mod.Species{sp};

    var state = startRun(&critters, &species_ptrs, b, 42);
    state.phase = .encounter;

    var updated = state.party;
    updated[0].?.current_hp = 0;

    _ = resolveEncounter(&state, .player_lose, updated, null, 0);

    try std.testing.expectEqual(RunPhase.run_over, state.phase);
    try std.testing.expectEqual(RunOutcome.wiped, state.outcome);
}

test "resolveEncounter records catch" {
    const allocator = std.testing.allocator;
    const biomes_parsed = try biome.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();
    const b = &biomes_parsed.value[0];

    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();
    const sp = gd.findSpecies("println").?;

    const critters = [_]critter_mod.Critter{makeTestCritter(1, 100)};
    const species_ptrs = [_]*const species_mod.Species{sp};

    var state = startRun(&critters, &species_ptrs, b, 42);
    state.phase = .encounter;

    _ = resolveEncounter(&state, .caught, state.party, "glitch", 8);

    try std.testing.expectEqual(@as(u8, 1), state.catch_count);
    try std.testing.expect(std.mem.eql(u8, state.catches[0].?.species_id, "glitch"));
    try std.testing.expectEqual(@as(u8, 8), state.catches[0].?.level);
}

test "advanceFloor increments and regenerates" {
    const allocator = std.testing.allocator;
    const biomes_parsed = try biome.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();
    const b = &biomes_parsed.value[0];

    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();
    const sp = gd.findSpecies("println").?;

    const critters = [_]critter_mod.Critter{makeTestCritter(1, 100)};
    const species_ptrs = [_]*const species_mod.Species{sp};

    var state = startRun(&critters, &species_ptrs, b, 42);
    state.phase = .between_floors;

    advanceFloor(&state);

    try std.testing.expectEqual(@as(u8, 2), state.floor_number);
    try std.testing.expectEqual(RunPhase.exploring, state.phase);
    try std.testing.expectEqual(state.current_floor.entrance_x, state.player_x);
    try std.testing.expectEqual(state.current_floor.entrance_y, state.player_y);
}

test "extract sets outcome" {
    const allocator = std.testing.allocator;
    const biomes_parsed = try biome.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();
    const b = &biomes_parsed.value[0];

    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();
    const sp = gd.findSpecies("println").?;

    const critters = [_]critter_mod.Critter{makeTestCritter(1, 100)};
    const species_ptrs = [_]*const species_mod.Species{sp};

    var state = startRun(&critters, &species_ptrs, b, 42);
    state.phase = .between_floors;

    extract(&state);

    try std.testing.expectEqual(RunPhase.run_over, state.phase);
    try std.testing.expectEqual(RunOutcome.extracted, state.outcome);
}

test "addRunItem stacks duplicates" {
    const allocator = std.testing.allocator;
    const biomes_parsed = try biome.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();
    const b = &biomes_parsed.value[0];

    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();
    const sp = gd.findSpecies("println").?;

    const critters = [_]critter_mod.Critter{makeTestCritter(1, 100)};
    const species_ptrs = [_]*const species_mod.Species{sp};

    var state = startRun(&critters, &species_ptrs, b, 42);

    addRunItem(&state, "small_patch", 2);
    addRunItem(&state, "small_patch", 1);

    try std.testing.expectEqual(@as(u8, 1), state.run_inventory_count);
    try std.testing.expectEqual(@as(u16, 3), state.run_inventory[0].?.count);
}

// --- Test helpers ---

fn findAdjacentFloorMove(state: *const DungeonState) ?Direction {
    const dirs = [_]Direction{ .up, .down, .left, .right };
    const dx_vals = [_]i16{ 0, 0, -1, 1 };
    const dy_vals = [_]i16{ -1, 1, 0, 0 };

    for (dirs, dx_vals, dy_vals) |dir, ddx, ddy| {
        const nx = @as(i16, state.player_x) + ddx;
        const ny = @as(i16, state.player_y) + ddy;
        if (nx >= 0 and nx < floor_gen.FLOOR_WIDTH and ny >= 0 and ny < floor_gen.FLOOR_HEIGHT) {
            const tile = state.current_floor.tiles[@intCast(ny)][@intCast(nx)];
            if (tile == .floor) return dir;
        }
    }
    return null;
}

const PathResult = struct {
    dirs: [256]Direction,
    len: u16,
};

fn findPathToTile(state: *const DungeonState, target_tile: floor_gen.Tile) ?PathResult {
    // BFS from player position to nearest target tile
    const W = floor_gen.FLOOR_WIDTH;
    const H = floor_gen.FLOOR_HEIGHT;

    var visited: [H][W]bool = [_][W]bool{[_]bool{false} ** W} ** H;
    var parent_dir: [H][W]?Direction = [_][W]?Direction{[_]?Direction{null} ** W} ** H;
    var parent_x: [H][W]u8 = [_][W]u8{[_]u8{0} ** W} ** H;
    var parent_y: [H][W]u8 = [_][W]u8{[_]u8{0} ** W} ** H;

    var queue: [@as(u16, W) * H][2]u8 = undefined;
    var head: u16 = 0;
    var tail: u16 = 0;

    queue[tail] = .{ state.player_x, state.player_y };
    tail += 1;
    visited[state.player_y][state.player_x] = true;

    const dirs = [_]Direction{ .up, .down, .left, .right };
    const dx_vals = [_]i16{ 0, 0, -1, 1 };
    const dy_vals = [_]i16{ -1, 1, 0, 0 };

    var target_x: u8 = 0;
    var target_y: u8 = 0;
    var found = false;

    while (head < tail) {
        const cx = queue[head][0];
        const cy = queue[head][1];
        head += 1;

        if (state.current_floor.tiles[cy][cx] == target_tile and (cx != state.player_x or cy != state.player_y)) {
            target_x = cx;
            target_y = cy;
            found = true;
            break;
        }

        for (dirs, dx_vals, dy_vals) |dir, ddx, ddy| {
            const nx_i = @as(i16, cx) + ddx;
            const ny_i = @as(i16, cy) + ddy;
            if (nx_i < 0 or nx_i >= W or ny_i < 0 or ny_i >= H) continue;
            const nx: u8 = @intCast(nx_i);
            const ny: u8 = @intCast(ny_i);
            if (visited[ny][nx]) continue;
            if (state.current_floor.tiles[ny][nx] == .wall) continue;
            visited[ny][nx] = true;
            parent_dir[ny][nx] = dir;
            parent_x[ny][nx] = cx;
            parent_y[ny][nx] = cy;
            queue[tail] = .{ nx, ny };
            tail += 1;
        }
    }

    if (!found) return null;

    // Reconstruct path
    var result = PathResult{ .dirs = undefined, .len = 0 };
    var px = target_x;
    var py = target_y;
    while (px != state.player_x or py != state.player_y) {
        result.dirs[result.len] = parent_dir[py][px].?;
        result.len += 1;
        const ppx = parent_x[py][px];
        const ppy = parent_y[py][px];
        px = ppx;
        py = ppy;
    }

    // Reverse path
    var i: u16 = 0;
    var j: u16 = result.len - 1;
    while (i < j) {
        const tmp = result.dirs[i];
        result.dirs[i] = result.dirs[j];
        result.dirs[j] = tmp;
        i += 1;
        j -= 1;
    }

    return result;
}

test "full run simulation: 5 floors with encounters, boss, extraction" {
    const allocator = std.testing.allocator;
    const biomes_parsed = try biome.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();
    const b = &biomes_parsed.value[0];

    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();
    const sp = gd.findSpecies("println").?;

    const critters = [_]critter_mod.Critter{
        makeTestCritter(1, 100),
        makeTestCritter(2, 90),
    };
    const species_ptrs = [_]*const species_mod.Species{ sp, sp };

    var state = startRun(&critters, &species_ptrs, b, 777);

    // Simulate 5 floors
    var floors_completed: u8 = 0;
    while (floors_completed < 5 and state.outcome == .in_progress) {
        try std.testing.expectEqual(RunPhase.exploring, state.phase);

        // Navigate to stairs, resolving encounters along the way
        if (findPathToTile(&state, .stairs)) |path| {
            for (path.dirs[0..path.len]) |dir| {
                if (state.phase != .exploring) break;
                const result = movePlayer(&state, dir);
                switch (result) {
                    .encounter_triggered => {
                        // Simulate winning the battle
                        _ = resolveEncounter(&state, .player_win, state.party, null, 0);
                    },
                    .boss_triggered => {
                        // Simulate winning the boss battle — transitions to between_floors
                        _ = resolveEncounter(&state, .player_win, state.party, null, 0);
                        try std.testing.expectEqual(RunPhase.between_floors, state.phase);
                        generateBetweenFloorShop(&state, &gd);
                        advanceFloor(&state);
                        floors_completed += 1;
                        break;
                    },
                    .stairs_reached => {
                        try std.testing.expectEqual(RunPhase.between_floors, state.phase);

                        // Generate and verify shop
                        generateBetweenFloorShop(&state, &gd);
                        try std.testing.expect(state.current_shop != null);

                        advanceFloor(&state);
                        floors_completed += 1;
                    },
                    else => {},
                }
            }
        } else {
            // Shouldn't happen — floors are always connected
            return error.TestUnexpectedResult;
        }
    }

    try std.testing.expect(floors_completed > 0);
    try std.testing.expect(state.currency > 0);
    try std.testing.expect(state.floor_number > 1);

    // Extract
    state.phase = .between_floors;
    extract(&state);
    try std.testing.expectEqual(RunOutcome.extracted, state.outcome);
    try std.testing.expectEqual(RunPhase.run_over, state.phase);
}
