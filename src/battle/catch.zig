const std = @import("std");
const types = @import("types");
const items = @import("items");
const species = @import("species");

pub const CatchResult = struct {
    success: bool,
    catch_chance: u8,
};

/// Calculate type bonus/penalty for a catch tool against a critter type.
fn typeBonus(tier: items.CatchTier, critter_type: types.CritterType) i16 {
    return switch (tier) {
        .breakpoint => if (critter_type == .debug) @as(i16, 15) else 0,
        .linter => switch (critter_type) {
            .chaos => 15,
            .wisdom => -10,
            else => 0,
        },
        .formal_proof => if (critter_type == .chaos) @as(i16, -30) else 0,
        .print_statement, .try_catch => 0,
    };
}

/// Rarity penalty applied to catch chance.
fn rarityPenalty(rarity: species.Rarity) i16 {
    return switch (rarity) {
        .common => 0,
        .uncommon => 10,
        .rare => 20,
        .epic => 35,
        .legendary => 50,
    };
}

/// Attempt to catch a wild critter. Returns whether it succeeded and the computed chance.
pub fn attemptCatch(
    tool: *const items.Item,
    critter_type: types.CritterType,
    current_hp: u16,
    max_hp: u16,
    rarity: species.Rarity,
    rng: std.Random,
) CatchResult {
    const base: i16 = @intCast(tool.base_catch_rate orelse 0);
    const tier = tool.catch_tier orelse return .{ .success = false, .catch_chance = 0 };

    const bonus = typeBonus(tier, critter_type);

    // HP penalty: higher HP = harder to catch. At full HP = -50, at 1 HP ≈ 0
    const hp_penalty: i16 = if (max_hp > 0)
        @intCast((@as(u32, current_hp) * 50) / @as(u32, max_hp))
    else
        0;

    const rarity_pen = rarityPenalty(rarity);

    const raw_chance = base + bonus - hp_penalty - rarity_pen;
    const clamped = std.math.clamp(raw_chance, 5, 100); // minimum 5% chance
    const chance: u8 = @intCast(clamped);

    const roll = rng.intRangeAtMost(u8, 1, 100);
    return .{
        .success = roll <= chance,
        .catch_chance = chance,
    };
}

// --- Tests ---

fn makeCatchTool(tier: items.CatchTier, rate: u8) items.Item {
    return .{
        .id = "test_tool",
        .name = "Test",
        .kind = .catch_tool,
        .catch_tier = tier,
        .base_catch_rate = rate,
    };
}

test "attemptCatch: low HP is easier than full HP" {
    const tool = makeCatchTool(.breakpoint, 40);
    var prng1 = std.Random.DefaultPrng.init(0);
    var prng2 = std.Random.DefaultPrng.init(0);

    const full_hp = attemptCatch(&tool, .chaos, 100, 100, .common, prng1.random());
    const low_hp = attemptCatch(&tool, .chaos, 1, 100, .common, prng2.random());

    try std.testing.expect(low_hp.catch_chance > full_hp.catch_chance);
}

test "attemptCatch: rarity makes it harder" {
    const tool = makeCatchTool(.try_catch, 60);
    var prng1 = std.Random.DefaultPrng.init(0);
    var prng2 = std.Random.DefaultPrng.init(0);
    const common = attemptCatch(&tool, .debug, 10, 100, .common, prng1.random());
    const legendary = attemptCatch(&tool, .debug, 10, 100, .legendary, prng2.random());

    try std.testing.expect(common.catch_chance > legendary.catch_chance);
}

test "attemptCatch: breakpoint gets bonus vs debug" {
    const tool = makeCatchTool(.breakpoint, 40);
    var prng1 = std.Random.DefaultPrng.init(0);
    var prng2 = std.Random.DefaultPrng.init(0);
    const vs_debug = attemptCatch(&tool, .debug, 10, 100, .common, prng1.random());
    const vs_chaos = attemptCatch(&tool, .chaos, 10, 100, .common, prng2.random());

    try std.testing.expect(vs_debug.catch_chance > vs_chaos.catch_chance);
}

test "attemptCatch: linter bonus vs chaos, penalty vs wisdom" {
    const tool = makeCatchTool(.linter, 50);
    var prng1 = std.Random.DefaultPrng.init(0);
    var prng2 = std.Random.DefaultPrng.init(0);
    var prng3 = std.Random.DefaultPrng.init(0);
    const vs_chaos = attemptCatch(&tool, .chaos, 10, 100, .common, prng1.random());
    const vs_wisdom = attemptCatch(&tool, .wisdom, 10, 100, .common, prng2.random());
    const vs_debug = attemptCatch(&tool, .debug, 10, 100, .common, prng3.random());

    try std.testing.expect(vs_chaos.catch_chance > vs_debug.catch_chance);
    try std.testing.expect(vs_debug.catch_chance > vs_wisdom.catch_chance);
}

test "attemptCatch: formal_proof penalized vs chaos" {
    const tool = makeCatchTool(.formal_proof, 90);
    var prng1 = std.Random.DefaultPrng.init(0);
    var prng2 = std.Random.DefaultPrng.init(0);
    const vs_chaos = attemptCatch(&tool, .chaos, 10, 100, .common, prng1.random());
    const vs_debug = attemptCatch(&tool, .debug, 10, 100, .common, prng2.random());

    try std.testing.expect(vs_debug.catch_chance > vs_chaos.catch_chance);
}

test "attemptCatch: minimum 5% chance" {
    const tool = makeCatchTool(.print_statement, 20);
    var prng = std.Random.DefaultPrng.init(0);
    const result = attemptCatch(&tool, .debug, 100, 100, .legendary, prng.random());
    try std.testing.expectEqual(@as(u8, 5), result.catch_chance);
}

test "attemptCatch: higher tier tools are better" {
    const print_stmt = makeCatchTool(.print_statement, 20);
    const breakpoint_tool = makeCatchTool(.breakpoint, 40);
    const try_catch_tool = makeCatchTool(.try_catch, 60);

    var prng1 = std.Random.DefaultPrng.init(0);
    var prng2 = std.Random.DefaultPrng.init(0);
    var prng3 = std.Random.DefaultPrng.init(0);
    const r1 = attemptCatch(&print_stmt, .patience, 30, 100, .common, prng1.random());
    const r2 = attemptCatch(&breakpoint_tool, .patience, 30, 100, .common, prng2.random());
    const r3 = attemptCatch(&try_catch_tool, .patience, 30, 100, .common, prng3.random());

    try std.testing.expect(r3.catch_chance > r2.catch_chance);
    try std.testing.expect(r2.catch_chance > r1.catch_chance);
}
