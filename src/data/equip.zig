const critter_mod = @import("critter");
const items_mod = @import("items");

pub const EquipResult = enum {
    success,
    not_a_disc,
    no_move_id,
};

/// Equip a move disc to a critter's slot 3 (loadout slot).
/// Replaces any existing slot 3 move. Caller handles inventory decrement.
pub fn equipMoveDisc(critter: *critter_mod.Critter, item: *const items_mod.Item) EquipResult {
    if (item.kind != .move_disc) return .not_a_disc;
    const move_id = item.move_id orelse return .no_move_id;
    critter.move_slot_3 = move_id;
    return .success;
}

// --- Tests ---

const std = @import("std");
const testing = std.testing;

fn makeTestCritter() critter_mod.Critter {
    return .{
        .id = 1,
        .species_id = "println",
        .nickname = null,
        .level = 10,
        .xp = 0,
        .current_hp = 54,
        .max_hp = 54,
        .logic = 66,
        .resolve = 48,
        .speed = 60,
        .move_slot_1 = "log_dump",
        .move_slot_2 = null,
        .move_slot_3 = null,
        .scars = &.{},
        .cooldown_runs = 0,
    };
}

test "equip move disc sets slot 3" {
    var critter = makeTestCritter();
    const disc = items_mod.Item{
        .id = "disc_buffer_overflow",
        .name = "Buffer Overflow Disc",
        .kind = .move_disc,
        .move_id = "buffer_overflow",
    };
    const result = equipMoveDisc(&critter, &disc);
    try testing.expectEqual(EquipResult.success, result);
    try testing.expect(std.mem.eql(u8, "buffer_overflow", critter.move_slot_3.?));
}

test "equip over existing slot 3 replaces" {
    var critter = makeTestCritter();
    critter.move_slot_3 = "old_move";
    const disc = items_mod.Item{
        .id = "disc_mutex_lock",
        .name = "Mutex Lock Disc",
        .kind = .move_disc,
        .move_id = "mutex_lock",
    };
    const result = equipMoveDisc(&critter, &disc);
    try testing.expectEqual(EquipResult.success, result);
    try testing.expect(std.mem.eql(u8, "mutex_lock", critter.move_slot_3.?));
}

test "equip non-disc item returns not_a_disc" {
    var critter = makeTestCritter();
    const heal = items_mod.Item{
        .id = "small_patch",
        .name = "Small Patch",
        .kind = .healing,
        .heal_amount = 30,
    };
    const result = equipMoveDisc(&critter, &heal);
    try testing.expectEqual(EquipResult.not_a_disc, result);
    try testing.expectEqual(@as(?[]const u8, null), critter.move_slot_3);
}

test "equip disc without move_id returns no_move_id" {
    var critter = makeTestCritter();
    const bad_disc = items_mod.Item{
        .id = "bad_disc",
        .name = "Bad Disc",
        .kind = .move_disc,
        .move_id = null,
    };
    const result = equipMoveDisc(&critter, &bad_disc);
    try testing.expectEqual(EquipResult.no_move_id, result);
}
