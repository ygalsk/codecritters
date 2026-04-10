const std = @import("std");
const critter_mod = @import("critter");
const species_mod = @import("species");
const game_data_mod = @import("game_data");

pub const LevelUpResult = struct {
    levels_gained: u8,
    new_level: u8,
    old_level: u8,
    evolved: bool,
    new_species_id: ?[]const u8,
};

/// XP required to reach the given level (cumulative threshold).
/// Formula: level^2 * 10. Level 1 = 10, Level 2 = 40, Level 10 = 1000.
pub fn xpForLevel(level: u8) u32 {
    const l: u32 = @intCast(level);
    return l * l * 10;
}

/// Calculate XP awarded for a battle. Surviving party members each get this amount.
pub fn battleXpAward(enemy_level: u8, is_boss: bool) u32 {
    const base: u32 = 10 + @as(u32, enemy_level) * 3;
    return if (is_boss) base * 2 else base;
}

/// Award XP to a critter and process any level-ups and evolution.
/// Returns what happened (levels gained, evolution).
pub fn awardXp(
    critter: *critter_mod.Critter,
    amount: u32,
    game_data: *const game_data_mod.GameData,
) LevelUpResult {
    const old_level = critter.level;
    critter.xp += amount;

    var levels_gained: u8 = 0;
    var evolved = false;
    var new_species_id: ?[]const u8 = null;

    // Level up while XP exceeds threshold for next level (cap at 100)
    while (critter.level < 100 and critter.xp >= xpForLevel(critter.level + 1)) {
        critter.level += 1;
        levels_gained += 1;

        // Recompute stats from current species
        const sp = game_data.findSpecies(critter.species_id) orelse continue;
        critter.recomputeStats(sp);

        // Check evolution
        if (checkEvolution(critter, sp, game_data)) |evo_sp| {
            critter.species_id = evo_sp.id;
            critter.recomputeStats(evo_sp);
            // Update moves to evolved species' moves
            critter.move_slot_1 = evo_sp.signature_move;
            if (evo_sp.secondary_move) |sec| {
                if (critter.move_slot_2 == null) {
                    critter.move_slot_2 = sec;
                }
            }
            evolved = true;
            new_species_id = evo_sp.id;
        }
    }

    return .{
        .levels_gained = levels_gained,
        .new_level = critter.level,
        .old_level = old_level,
        .evolved = evolved,
        .new_species_id = new_species_id,
    };
}

/// Check if a critter should evolve. Returns the new species if evolution triggers.
fn checkEvolution(
    critter: *const critter_mod.Critter,
    current_species: *const species_mod.Species,
    game_data: *const game_data_mod.GameData,
) ?*const species_mod.Species {
    const evo_level = current_species.evolution_level orelse return null;
    const evo_id = current_species.evolves_to orelse return null;
    if (critter.level < evo_level) return null;
    // Guard: only evolve if we're still the pre-evolution species
    if (!std.mem.eql(u8, critter.species_id, current_species.id)) return null;
    return game_data.findSpecies(evo_id);
}

// --- Tests ---

const testing = std.testing;

test "xpForLevel is monotonically increasing" {
    var prev: u32 = 0;
    var level: u8 = 1;
    while (level <= 100) : (level += 1) {
        const xp = xpForLevel(level);
        try testing.expect(xp > prev);
        prev = xp;
    }
}

test "xpForLevel known values" {
    try testing.expectEqual(@as(u32, 10), xpForLevel(1));
    try testing.expectEqual(@as(u32, 40), xpForLevel(2));
    try testing.expectEqual(@as(u32, 250), xpForLevel(5));
    try testing.expectEqual(@as(u32, 1000), xpForLevel(10));
    try testing.expectEqual(@as(u32, 4000), xpForLevel(20));
}

test "battleXpAward normal and boss" {
    try testing.expectEqual(@as(u32, 40), battleXpAward(10, false));
    try testing.expectEqual(@as(u32, 80), battleXpAward(10, true));
    try testing.expectEqual(@as(u32, 13), battleXpAward(1, false));
}

test "awardXp single level up" {
    const gd = try game_data_mod.GameData.load(testing.allocator);
    defer @constCast(&gd).deinit();

    const sp = gd.findSpecies("println") orelse return error.MissingSpecies;
    var critter = critter_mod.Critter.createFromSpecies(sp, 1);
    // Need 40 XP for level 2
    const result = awardXp(&critter, 40, &gd);
    try testing.expectEqual(@as(u8, 1), result.levels_gained);
    try testing.expectEqual(@as(u8, 2), result.new_level);
    try testing.expectEqual(@as(u8, 1), result.old_level);
    try testing.expect(!result.evolved);
    // Stats should be recomputed for level 2
    try testing.expectEqual(critter_mod.Critter.calcStat(sp.base_stats.hp, 2), critter.max_hp);
}

test "awardXp multi level up" {
    const gd = try game_data_mod.GameData.load(testing.allocator);
    defer @constCast(&gd).deinit();

    const sp = gd.findSpecies("println") orelse return error.MissingSpecies;
    var critter = critter_mod.Critter.createFromSpecies(sp, 1);
    // Give enough XP to reach level 5 (need 250 cumulative)
    const result = awardXp(&critter, 250, &gd);
    try testing.expect(result.levels_gained >= 4);
    try testing.expectEqual(@as(u8, 5), result.new_level);
}

test "awardXp triggers evolution at threshold" {
    const gd = try game_data_mod.GameData.load(testing.allocator);
    defer @constCast(&gd).deinit();

    const sp = gd.findSpecies("println") orelse return error.MissingSpecies;
    // Println evolves to Tracer at level 12
    var critter = critter_mod.Critter.createFromSpecies(sp, 11);
    critter.xp = xpForLevel(11); // Already at level 11
    // Need xpForLevel(12) = 1440 total, give enough to cross
    const result = awardXp(&critter, xpForLevel(12) - critter.xp, &gd);
    try testing.expect(result.evolved);
    try testing.expect(result.levels_gained >= 1);
    try testing.expect(std.mem.eql(u8, "tracer", critter.species_id));
    // Stats should use Tracer's base stats
    const tracer_sp = gd.findSpecies("tracer") orelse return error.MissingSpecies;
    try testing.expectEqual(critter_mod.Critter.calcStat(tracer_sp.base_stats.logic, critter.level), critter.logic);
}

test "awardXp evolution triggers when target species exists" {
    const gd = try game_data_mod.GameData.load(testing.allocator);
    defer @constCast(&gd).deinit();

    // Monad evolves_to "functor" at level 15
    const sp = gd.findSpecies("monad") orelse return error.MissingSpecies;
    var critter = critter_mod.Critter.createFromSpecies(sp, 14);
    critter.xp = xpForLevel(14);
    const result = awardXp(&critter, xpForLevel(15) - critter.xp, &gd);
    try testing.expect(result.levels_gained >= 1);
    try testing.expect(result.evolved);
    // Species should now be functor
    try testing.expect(std.mem.eql(u8, "functor", critter.species_id));
}

test "awardXp does not exceed level 100" {
    const gd = try game_data_mod.GameData.load(testing.allocator);
    defer @constCast(&gd).deinit();

    const sp = gd.findSpecies("println") orelse return error.MissingSpecies;
    var critter = critter_mod.Critter.createFromSpecies(sp, 99);
    critter.xp = xpForLevel(99);
    const result = awardXp(&critter, 999999, &gd);
    try testing.expect(critter.level <= 100);
    _ = result;
}

test "recomputeStats preserves damage" {
    const sp = species_mod.Species{
        .id = "test",
        .name = "Test",
        .critter_type = .debug,
        .rarity = .common,
        .base_stats = .{ .hp = 50, .logic = 50, .resolve = 50, .speed = 50 },
        .signature_move = "log_dump",
    };
    var critter = critter_mod.Critter.createFromSpecies(&sp, 5);
    // Take 10 damage
    critter.current_hp -= 10;
    const hp_before = critter.current_hp;
    critter.level = 6;
    critter.recomputeStats(&sp);
    // HP should have increased by the max_hp delta, preserving damage taken
    try testing.expect(critter.current_hp > hp_before);
    try testing.expect(critter.current_hp < critter.max_hp);
}
