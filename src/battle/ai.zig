const std = @import("std");

/// Choose a random non-null move slot index for a wild critter.
/// Returns a move slot index (0, 1, or 2).
pub fn chooseWildMoveSlot(
    slot_1: ?[]const u8,
    slot_2: ?[]const u8,
    slot_3: ?[]const u8,
    rng: std.Random,
) u2 {
    var available: [3]u2 = undefined;
    var count: u8 = 0;

    if (slot_1 != null) {
        available[count] = 0;
        count += 1;
    }
    if (slot_2 != null) {
        available[count] = 1;
        count += 1;
    }
    if (slot_3 != null) {
        available[count] = 2;
        count += 1;
    }

    if (count == 0) return 0; // fallback — shouldn't happen with valid data
    if (count == 1) return available[0];

    const idx = rng.intRangeAtMost(u8, 0, count - 1);
    return available[idx];
}

// --- Tests ---

test "chooseWildMoveSlot: single move always returns it" {
    var prng = std.Random.DefaultPrng.init(42);
    var i: u32 = 0;
    while (i < 50) : (i += 1) {
        const slot = chooseWildMoveSlot("move_a", null, null, prng.random());
        try std.testing.expectEqual(@as(u2, 0), slot);
    }
}

test "chooseWildMoveSlot: two moves returns valid slots" {
    var prng = std.Random.DefaultPrng.init(42);
    var saw_0 = false;
    var saw_1 = false;
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        const slot = chooseWildMoveSlot("move_a", "move_b", null, prng.random());
        try std.testing.expect(slot == 0 or slot == 1);
        if (slot == 0) saw_0 = true;
        if (slot == 1) saw_1 = true;
    }
    try std.testing.expect(saw_0);
    try std.testing.expect(saw_1);
}

test "chooseWildMoveSlot: three moves returns valid slots" {
    var prng = std.Random.DefaultPrng.init(42);
    var saw = [3]bool{ false, false, false };
    var i: u32 = 0;
    while (i < 200) : (i += 1) {
        const slot = chooseWildMoveSlot("a", "b", "c", prng.random());
        try std.testing.expect(slot <= 2);
        saw[slot] = true;
    }
    try std.testing.expect(saw[0]);
    try std.testing.expect(saw[1]);
    try std.testing.expect(saw[2]);
}

test "chooseWildMoveSlot: skips null middle slot" {
    var prng = std.Random.DefaultPrng.init(42);
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        const slot = chooseWildMoveSlot("a", null, "c", prng.random());
        try std.testing.expect(slot == 0 or slot == 2);
    }
}
