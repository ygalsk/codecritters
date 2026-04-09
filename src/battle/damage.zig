const std = @import("std");
const types = @import("types");
const moves = @import("moves");

/// Get effective stat value after status modifiers, clamped to minimum 1.
pub fn effectiveStat(base: u16, modifier: i16) u16 {
    const result = @as(i32, @intCast(base)) + @as(i32, modifier);
    if (result < 1) return 1;
    return @intCast(result);
}

/// Check if a move hits based on accuracy + status modifier.
pub fn rollAccuracy(base_accuracy: u8, accuracy_mod: i8, rng: std.Random) bool {
    const effective: i16 = @as(i16, base_accuracy) + @as(i16, accuracy_mod);
    if (effective >= 100) return true;
    if (effective <= 0) return false;
    const threshold: u8 = @intCast(effective);
    return rng.intRangeAtMost(u8, 1, 100) <= threshold;
}

/// Calculate damage from an attack.
/// Formula: power * type_effectiveness * (logic / resolve) * power_mult * variance
/// Variance is 0.85–1.0. Minimum damage is 1.
pub fn calculateDamage(
    move: *const moves.Move,
    attacker_logic: u16,
    logic_mod: i16,
    defender_resolve: u16,
    resolve_mod: i16,
    defender_type: types.CritterType,
    power_mod: i8,
    rng: std.Random,
) u16 {
    const power: f32 = @floatFromInt(move.power);
    const effectiveness = types.getEffectiveness(move.move_type, defender_type).multiplier();

    const eff_logic: f32 = @floatFromInt(effectiveStat(attacker_logic, logic_mod));
    const eff_resolve: f32 = @floatFromInt(effectiveStat(defender_resolve, resolve_mod));

    const power_mult: f32 = 1.0 + @as(f32, @floatFromInt(power_mod)) / 100.0;

    // Variance: random float in [0.85, 1.0]
    const roll = rng.intRangeAtMost(u8, 0, 15);
    const variance: f32 = 0.85 + @as(f32, @floatFromInt(roll)) / 100.0;

    const raw = power * effectiveness * (eff_logic / eff_resolve) * power_mult * variance;
    if (raw < 1.0) return 1;
    return @intFromFloat(raw);
}

// --- Tests ---

test "effectiveStat: no modifier" {
    try std.testing.expectEqual(@as(u16, 50), effectiveStat(50, 0));
}

test "effectiveStat: positive modifier" {
    try std.testing.expectEqual(@as(u16, 60), effectiveStat(50, 10));
}

test "effectiveStat: negative modifier clamps to 1" {
    try std.testing.expectEqual(@as(u16, 1), effectiveStat(10, -20));
}

test "effectiveStat: exactly zero clamps to 1" {
    try std.testing.expectEqual(@as(u16, 1), effectiveStat(5, -5));
}

test "rollAccuracy: 100% always hits" {
    var prng = std.Random.DefaultPrng.init(42);
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        try std.testing.expect(rollAccuracy(100, 0, prng.random()));
    }
}

test "rollAccuracy: 0% never hits" {
    var prng = std.Random.DefaultPrng.init(42);
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        try std.testing.expect(!rollAccuracy(0, 0, prng.random()));
    }
}

test "rollAccuracy: negative modifier can reduce to zero" {
    var prng = std.Random.DefaultPrng.init(42);
    var i: u32 = 0;
    while (i < 100) : (i += 1) {
        try std.testing.expect(!rollAccuracy(20, -30, prng.random()));
    }
}

test "calculateDamage: neutral type, equal stats" {
    // debug vs debug = neutral (1.0x)
    const move = moves.Move{
        .id = "test_move",
        .name = "Test",
        .move_type = .debug,
        .power = 40,
        .accuracy = 100,
    };
    var prng = std.Random.DefaultPrng.init(0);
    const dmg = calculateDamage(&move, 50, 0, 50, 0, .debug, 0, prng.random());
    // power=40, effectiveness=1.0, logic/resolve=1.0, variance in [0.85,1.0]
    // Expected: 40 * 1.0 * 1.0 * [0.85-1.0] = 34-40
    try std.testing.expect(dmg >= 34);
    try std.testing.expect(dmg <= 40);
}

test "calculateDamage: strong type effectiveness" {
    // debug vs chaos = strong (1.5x)
    const move = moves.Move{
        .id = "test_move",
        .name = "Test",
        .move_type = .debug,
        .power = 40,
        .accuracy = 100,
    };
    var prng = std.Random.DefaultPrng.init(0);
    const dmg = calculateDamage(&move, 50, 0, 50, 0, .chaos, 0, prng.random());
    // 40 * 1.5 * 1.0 * [0.85-1.0] = 51-60
    try std.testing.expect(dmg >= 51);
    try std.testing.expect(dmg <= 60);
}

test "calculateDamage: weak type effectiveness" {
    // debug vs wisdom = weak (0.5x)
    const move = moves.Move{
        .id = "test_move",
        .name = "Test",
        .move_type = .debug,
        .power = 40,
        .accuracy = 100,
    };
    var prng = std.Random.DefaultPrng.init(0);
    const dmg = calculateDamage(&move, 50, 0, 50, 0, .wisdom, 0, prng.random());
    // 40 * 0.5 * 1.0 * [0.85-1.0] = 17-20
    try std.testing.expect(dmg >= 17);
    try std.testing.expect(dmg <= 20);
}

test "calculateDamage: minimum 1 damage" {
    // Very low power, weak effectiveness, low logic, high resolve
    const move = moves.Move{
        .id = "weak",
        .name = "Weak",
        .move_type = .debug,
        .power = 1,
        .accuracy = 100,
    };
    var prng = std.Random.DefaultPrng.init(0);
    const dmg = calculateDamage(&move, 1, 0, 100, 0, .wisdom, 0, prng.random());
    try std.testing.expectEqual(@as(u16, 1), dmg);
}

test "calculateDamage: logic modifier boosts damage" {
    const move = moves.Move{
        .id = "test",
        .name = "Test",
        .move_type = .debug,
        .power = 40,
        .accuracy = 100,
    };
    var prng1 = std.Random.DefaultPrng.init(999);
    const base_dmg = calculateDamage(&move, 50, 0, 50, 0, .debug, 0, prng1.random());
    var prng2 = std.Random.DefaultPrng.init(999);
    const boosted_dmg = calculateDamage(&move, 50, 20, 50, 0, .debug, 0, prng2.random());
    try std.testing.expect(boosted_dmg > base_dmg);
}

test "calculateDamage: power modifier boosts damage" {
    const move = moves.Move{
        .id = "test",
        .name = "Test",
        .move_type = .debug,
        .power = 40,
        .accuracy = 100,
    };
    var prng1 = std.Random.DefaultPrng.init(999);
    const base_dmg = calculateDamage(&move, 50, 0, 50, 0, .debug, 0, prng1.random());
    var prng2 = std.Random.DefaultPrng.init(999);
    const boosted_dmg = calculateDamage(&move, 50, 0, 50, 0, .debug, 30, prng2.random());
    try std.testing.expect(boosted_dmg > base_dmg);
}
