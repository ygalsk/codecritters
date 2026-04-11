/// Meta upgrade definitions and helpers.
/// Upgrades are convenience/variety — no combat power creep.

pub const MAX_COSTS = 4;
pub const UPGRADE_COUNT = 3;

// Stat keys used with roster_db.incrementMetaStat / getMetaStat / updateMetaStatMax.
pub const STAT_TOTAL_RUNS = "total_runs";
pub const STAT_DEEPEST_FLOOR = "deepest_floor";
pub const STAT_CRITTERS_CAUGHT = "critters_caught";
pub const STAT_BOSSES_DEFEATED = "bosses_defeated";
pub const STAT_CURRENCY_EARNED = "currency_earned";
pub const STAT_SEEN_PREFIX = "stat:seen:";

pub const MetaUpgrade = struct {
    id: []const u8,
    name: []const u8,
    description: []const u8,
    max_level: u8,
    costs: [MAX_COSTS]u32,
};

pub const all_upgrades = [UPGRADE_COUNT]MetaUpgrade{
    .{
        .id = "extra_pack_slots",
        .name = "Extra Pack Slots",
        .description = "Bring more items into dungeon runs",
        .max_level = 4,
        .costs = .{ 150, 300, 500, 750 },
    },
    .{
        .id = "starting_currency",
        .name = "Starting Funds",
        .description = "Start each run with bonus currency",
        .max_level = 3,
        .costs = .{ 200, 400, 700, 0 },
    },
    .{
        .id = "species_codex",
        .name = "Species Codex",
        .description = "Unlock species discovery tracker in hub",
        .max_level = 1,
        .costs = .{ 300, 0, 0, 0 },
    },
};

/// Returns the cost for the next level, or null if already maxed.
pub fn costForNextLevel(upgrade: *const MetaUpgrade, current_level: u8) ?u32 {
    if (current_level >= upgrade.max_level) return null;
    return upgrade.costs[current_level];
}

/// Effective pack slots: base 6 + upgrade level.
pub fn getEffectivePackSlots(level: u8) u8 {
    return 6 + level;
}

/// Starting currency for a run based on upgrade level.
pub fn getStartingCurrency(level: u8) u32 {
    return switch (level) {
        0 => 0,
        1 => 50,
        2 => 100,
        3 => 200,
        else => 200,
    };
}

/// Whether the species codex is unlocked.
pub fn hasCodex(level: u8) bool {
    return level >= 1;
}

// --- Tests ---

const std = @import("std");

test "costForNextLevel" {
    const pack = &all_upgrades[0]; // extra_pack_slots, max 4
    try std.testing.expectEqual(@as(?u32, 150), costForNextLevel(pack, 0));
    try std.testing.expectEqual(@as(?u32, 300), costForNextLevel(pack, 1));
    try std.testing.expectEqual(@as(?u32, 500), costForNextLevel(pack, 2));
    try std.testing.expectEqual(@as(?u32, 750), costForNextLevel(pack, 3));
    try std.testing.expectEqual(@as(?u32, null), costForNextLevel(pack, 4));

    const codex = &all_upgrades[2]; // species_codex, max 1
    try std.testing.expectEqual(@as(?u32, 300), costForNextLevel(codex, 0));
    try std.testing.expectEqual(@as(?u32, null), costForNextLevel(codex, 1));
}

test "getEffectivePackSlots" {
    try std.testing.expectEqual(@as(u8, 6), getEffectivePackSlots(0));
    try std.testing.expectEqual(@as(u8, 8), getEffectivePackSlots(2));
    try std.testing.expectEqual(@as(u8, 10), getEffectivePackSlots(4));
}

test "getStartingCurrency" {
    try std.testing.expectEqual(@as(u32, 0), getStartingCurrency(0));
    try std.testing.expectEqual(@as(u32, 50), getStartingCurrency(1));
    try std.testing.expectEqual(@as(u32, 100), getStartingCurrency(2));
    try std.testing.expectEqual(@as(u32, 200), getStartingCurrency(3));
}
