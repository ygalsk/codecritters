const std = @import("std");
const types = @import("types");
const moves = @import("moves");

pub const StatusState = struct {
    effect: moves.StatusEffect = .none,
    turns_remaining: u8 = 0,
    logic_mod: i16 = 0,
    resolve_mod: i16 = 0,
    speed_mod: i16 = 0,
    accuracy_mod: i8 = 0,
    power_mod: i8 = 0,

    pub fn clear(self: *StatusState) void {
        self.* = .{};
    }
};

/// Default duration for each status effect.
fn statusDuration(effect: moves.StatusEffect) u8 {
    return switch (effect) {
        .none => 0,
        .blocked => 1,
        .deprecated => 3,
        .segfaulted => 3,
        .linted => 2,
        .tilted => 3,
        .in_the_zone => 3,
        .spaghettified => 2,
    };
}

/// Apply a status effect. Replaces any existing status and resets modifiers.
pub fn applyStatus(status: *StatusState, effect: moves.StatusEffect) void {
    status.* = .{
        .effect = effect,
        .turns_remaining = statusDuration(effect),
    };
    switch (effect) {
        .in_the_zone => {
            status.power_mod = 30;
            status.resolve_mod = -30;
        },
        .tilted => {
            status.accuracy_mod = -20;
        },
        else => {},
    }
}

pub const StatusTickResult = struct {
    skip_turn: bool = false,
    self_damage: u16 = 0,
    effect_expired: bool = false,
};

/// Process start-of-turn status effects. Call before the critter acts.
/// Returns what happened (skip turn, self-damage, etc).
/// Decrements turns_remaining and clears status on expiry.
pub fn processStatusTick(status: *StatusState, max_hp: u16, rng: std.Random) StatusTickResult {
    if (status.effect == .none) return .{};

    var result = StatusTickResult{};

    switch (status.effect) {
        .blocked => {
            result.skip_turn = true;
        },
        .deprecated => {
            // Stats decay: -3 to logic, resolve, speed each tick
            status.logic_mod -= 3;
            status.resolve_mod -= 3;
            status.speed_mod -= 3;
        },
        .segfaulted => {
            // 25% chance to deal 10% max HP as self-damage
            if (rng.intRangeAtMost(u8, 1, 100) <= 25) {
                result.self_damage = @max(1, max_hp / 10);
            }
        },
        .tilted, .in_the_zone, .linted, .spaghettified => {
            // These are passive — effects applied via modifiers or move restrictions
        },
        .none => unreachable,
    }

    // Decrement duration
    status.turns_remaining -= 1;
    if (status.turns_remaining == 0) {
        result.effect_expired = true;
        status.clear();
    }

    return result;
}

/// Check if a move is blocked by linted status (only same-type moves allowed).
pub fn isMoveBlockedByLint(
    critter_type: types.CritterType,
    move_type: types.CritterType,
    effect: moves.StatusEffect,
) bool {
    if (effect != .linted) return false;
    return critter_type != move_type;
}

/// Roll whether a status effect is inflicted based on the move's status_chance.
pub fn rollStatusInflict(move: *const moves.Move, rng: std.Random) bool {
    if (move.status_effect == .none) return false;
    if (move.status_chance == 0) return false;
    if (move.status_chance >= 100) return true;
    return rng.intRangeAtMost(u8, 1, 100) <= move.status_chance;
}

// --- Tests ---

test "applyStatus: sets effect and duration" {
    var status = StatusState{};
    applyStatus(&status, .blocked);
    try std.testing.expectEqual(moves.StatusEffect.blocked, status.effect);
    try std.testing.expectEqual(@as(u8, 1), status.turns_remaining);
}

test "applyStatus: replaces existing status" {
    var status = StatusState{};
    applyStatus(&status, .tilted);
    try std.testing.expectEqual(@as(i8, -20), status.accuracy_mod);

    applyStatus(&status, .blocked);
    try std.testing.expectEqual(moves.StatusEffect.blocked, status.effect);
    try std.testing.expectEqual(@as(i8, 0), status.accuracy_mod); // cleared
}

test "applyStatus: in_the_zone sets power and resolve mods" {
    var status = StatusState{};
    applyStatus(&status, .in_the_zone);
    try std.testing.expectEqual(@as(i8, 30), status.power_mod);
    try std.testing.expectEqual(@as(i16, -30), status.resolve_mod);
}

test "applyStatus: tilted sets accuracy mod" {
    var status = StatusState{};
    applyStatus(&status, .tilted);
    try std.testing.expectEqual(@as(i8, -20), status.accuracy_mod);
}

test "processStatusTick: blocked skips turn then clears" {
    var status = StatusState{};
    applyStatus(&status, .blocked);
    var prng = std.Random.DefaultPrng.init(0);

    const result = processStatusTick(&status, 100, prng.random());
    try std.testing.expect(result.skip_turn);
    try std.testing.expect(result.effect_expired);
    try std.testing.expectEqual(moves.StatusEffect.none, status.effect);
}

test "processStatusTick: deprecated decays stats over 3 turns" {
    var status = StatusState{};
    applyStatus(&status, .deprecated);
    var prng = std.Random.DefaultPrng.init(0);

    // Turn 1
    _ = processStatusTick(&status, 100, prng.random());
    try std.testing.expectEqual(@as(i16, -3), status.logic_mod);
    try std.testing.expectEqual(@as(u8, 2), status.turns_remaining);

    // Turn 2
    _ = processStatusTick(&status, 100, prng.random());
    try std.testing.expectEqual(@as(i16, -6), status.logic_mod);

    // Turn 3 — expires
    const result = processStatusTick(&status, 100, prng.random());
    try std.testing.expect(result.effect_expired);
    try std.testing.expectEqual(moves.StatusEffect.none, status.effect);
    try std.testing.expectEqual(@as(i16, 0), status.logic_mod); // cleared
}

test "processStatusTick: segfaulted self-damage with seeded rng" {
    var status = StatusState{};
    applyStatus(&status, .segfaulted);

    // Run many ticks to see both outcomes
    var hit_count: u32 = 0;
    var prng = std.Random.DefaultPrng.init(42);
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        // Reset status each time since it expires after 3 ticks
        applyStatus(&status, .segfaulted);
        const result = processStatusTick(&status, 100, prng.random());
        if (result.self_damage > 0) {
            try std.testing.expectEqual(@as(u16, 10), result.self_damage); // 10% of 100
            hit_count += 1;
        }
    }
    // With 25% chance over 100 trials, should get some hits
    try std.testing.expect(hit_count > 5);
    try std.testing.expect(hit_count < 50);
}

test "isMoveBlockedByLint: blocks off-type moves" {
    // Debug critter using a chaos move while linted
    try std.testing.expect(isMoveBlockedByLint(.debug, .chaos, .linted));
}

test "isMoveBlockedByLint: allows same-type moves" {
    try std.testing.expect(!isMoveBlockedByLint(.debug, .debug, .linted));
}

test "isMoveBlockedByLint: no effect without linted status" {
    try std.testing.expect(!isMoveBlockedByLint(.debug, .chaos, .none));
    try std.testing.expect(!isMoveBlockedByLint(.debug, .chaos, .blocked));
}

test "rollStatusInflict: no status = never inflicts" {
    const move = moves.Move{
        .id = "t",
        .name = "T",
        .move_type = .debug,
        .power = 40,
        .accuracy = 100,
    };
    var prng = std.Random.DefaultPrng.init(0);
    try std.testing.expect(!rollStatusInflict(&move, prng.random()));
}

test "rollStatusInflict: 100% chance always inflicts" {
    const move = moves.Move{
        .id = "t",
        .name = "T",
        .move_type = .debug,
        .power = 40,
        .accuracy = 100,
        .status_effect = .blocked,
        .status_chance = 100,
    };
    var prng = std.Random.DefaultPrng.init(0);
    var i: u32 = 0;
    while (i < 50) : (i += 1) {
        try std.testing.expect(rollStatusInflict(&move, prng.random()));
    }
}
