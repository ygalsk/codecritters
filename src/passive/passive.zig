const std = @import("std");
const critter_mod = @import("critter");
const leveling = @import("leveling");
const game_data_mod = @import("game_data");

pub const ItemFind = struct {
    item_id: []const u8,
};

pub const MAX_PASSIVE_ITEMS = 4;

pub const ReconcileResult = struct {
    xp_awarded: u32,
    level_up: ?leveling.LevelUpResult,
    items_found: [MAX_PASSIVE_ITEMS]?ItemFind,
    item_count: u8,
    events_processed: u32,
};

// Tuning constants
pub const XP_PER_EVENT: u32 = 5;
pub const EVENTS_PER_ITEM_ROLL: u32 = 20;
pub const ITEM_FIND_CHANCE_PCT: u32 = 30;
pub const PASSIVE_LOOT_TABLE = [_][]const u8{ "small_patch", "print_statement", "hotfix" };

/// Process a batch of coding events and award XP + items to a critter.
/// The caller is responsible for persisting the critter, items, and marking events processed.
pub fn reconcile(
    event_count: u32,
    critter: *critter_mod.Critter,
    game_data: *const game_data_mod.GameData,
    seed: u64,
) ReconcileResult {
    var result = ReconcileResult{
        .xp_awarded = 0,
        .level_up = null,
        .items_found = .{ null, null, null, null },
        .item_count = 0,
        .events_processed = event_count,
    };

    if (event_count == 0) return result;

    const xp: u32 = event_count * XP_PER_EVENT;
    if (critter.level < 100) {
        result.xp_awarded = xp;
        result.level_up = leveling.awardXp(critter, xp, game_data);
    }

    // Roll for item finds
    var rng = std.Random.DefaultPrng.init(seed);
    var random = rng.random();
    const rolls = event_count / EVENTS_PER_ITEM_ROLL;

    var roll_i: u32 = 0;
    while (roll_i < rolls and result.item_count < MAX_PASSIVE_ITEMS) : (roll_i += 1) {
        const chance = random.intRangeAtMost(u32, 1, 100);
        if (chance <= ITEM_FIND_CHANCE_PCT) {
            const item_idx = random.intRangeLessThan(usize, 0, PASSIVE_LOOT_TABLE.len);
            result.items_found[result.item_count] = .{
                .item_id = PASSIVE_LOOT_TABLE[item_idx],
            };
            result.item_count += 1;
        }
    }

    return result;
}

// --- Tests ---

const testing = std.testing;

test "reconcile with zero events" {
    const gd = try game_data_mod.GameData.load(testing.allocator);
    defer @constCast(&gd).deinit();

    const sp = gd.findSpecies("println") orelse return error.MissingSpecies;
    var critter = critter_mod.Critter.createFromSpecies(sp, 5);

    const result = reconcile(0, &critter, &gd, 42);

    try testing.expectEqual(@as(u32, 0), result.xp_awarded);
    try testing.expectEqual(@as(u32, 0), result.events_processed);
    try testing.expectEqual(@as(u8, 0), result.item_count);
}

test "reconcile awards correct XP" {
    const gd = try game_data_mod.GameData.load(testing.allocator);
    defer @constCast(&gd).deinit();

    const sp = gd.findSpecies("println") orelse return error.MissingSpecies;
    var critter = critter_mod.Critter.createFromSpecies(sp, 1);
    const old_xp = critter.xp;

    const result = reconcile(3, &critter, &gd, 42);

    try testing.expectEqual(@as(u32, 15), result.xp_awarded); // 3 * 5
    try testing.expectEqual(@as(u32, 3), result.events_processed);
    try testing.expect(critter.xp > old_xp);
}

test "reconcile triggers level-up" {
    const gd = try game_data_mod.GameData.load(testing.allocator);
    defer @constCast(&gd).deinit();

    const sp = gd.findSpecies("println") orelse return error.MissingSpecies;
    var critter = critter_mod.Critter.createFromSpecies(sp, 1);
    // Need 40 XP for level 2, that's 8 events
    const result = reconcile(8, &critter, &gd, 42);

    try testing.expect(result.level_up != null);
    try testing.expect(result.level_up.?.levels_gained >= 1);
    try testing.expectEqual(@as(u8, 2), critter.level);
}

test "reconcile max-level critter gets no XP but processes events" {
    const gd = try game_data_mod.GameData.load(testing.allocator);
    defer @constCast(&gd).deinit();

    const sp = gd.findSpecies("println") orelse return error.MissingSpecies;
    var critter = critter_mod.Critter.createFromSpecies(sp, 100);

    const result = reconcile(1, &critter, &gd, 42);

    try testing.expectEqual(@as(u32, 0), result.xp_awarded);
    try testing.expectEqual(@as(u32, 1), result.events_processed);
}

test "reconcile item find with enough events" {
    const gd = try game_data_mod.GameData.load(testing.allocator);
    defer @constCast(&gd).deinit();

    const sp = gd.findSpecies("println") orelse return error.MissingSpecies;

    // 100 events = 5 rolls, high chance of at least one item
    var found_items = false;
    var seed: u64 = 0;
    while (seed < 20) : (seed += 1) {
        var test_critter = critter_mod.Critter.createFromSpecies(sp, 5);
        const result = reconcile(100, &test_critter, &gd, seed);
        if (result.item_count > 0) {
            found_items = true;
            const item = result.items_found[0].?;
            var valid = false;
            for (PASSIVE_LOOT_TABLE) |loot_id| {
                if (std.mem.eql(u8, item.item_id, loot_id)) {
                    valid = true;
                    break;
                }
            }
            try testing.expect(valid);
            break;
        }
    }
    try testing.expect(found_items);
}

test "reconcile few events produces no items" {
    const gd = try game_data_mod.GameData.load(testing.allocator);
    defer @constCast(&gd).deinit();

    const sp = gd.findSpecies("println") orelse return error.MissingSpecies;
    var critter = critter_mod.Critter.createFromSpecies(sp, 5);

    // 10 events < 20, no item roll
    const result = reconcile(10, &critter, &gd, 42);
    try testing.expectEqual(@as(u8, 0), result.item_count);
    try testing.expect(critter.xp > 0);
}
