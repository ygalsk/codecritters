const std = @import("std");
const types = @import("types");
const loader = @import("loader");

pub const EncounterEntry = struct {
    species_id: []const u8,
    weight: u16,
    min_floor: u8,
    max_floor: u8,
};

pub const BossEntry = struct {
    species_id: []const u8,
    level_bonus: u8,
};

pub const ShopBiasEntry = struct {
    item_id: []const u8,
    weight: u16,
};

pub const Biome = struct {
    id: []const u8,
    name: []const u8,
    dominant_types: [2]types.CritterType,
    encounter_table: []const EncounterEntry,
    boss_pool: []const BossEntry,
    shop_bias: []const ShopBiasEntry,
    drop_table: []const ShopBiasEntry = &.{},
};

pub fn load(allocator: std.mem.Allocator, path: []const u8) !std.json.Parsed([]Biome) {
    return loader.loadJsonFile(Biome, allocator, path);
}

pub fn findById(biomes: []const Biome, id: []const u8) ?*const Biome {
    for (biomes) |*b| {
        if (std.mem.eql(u8, b.id, id)) return b;
    }
    return null;
}

/// Select a random encounter species for the given floor, using weighted random
/// from the biome's encounter table. Returns null if no entries match the floor.
pub fn rollEncounter(biome: *const Biome, floor_number: u8, rng: std.Random) ?[]const u8 {
    var total_weight: u32 = 0;
    for (biome.encounter_table) |entry| {
        if (floor_number >= entry.min_floor and floor_number <= entry.max_floor) {
            total_weight += entry.weight;
        }
    }
    if (total_weight == 0) return null;

    var roll = rng.intRangeLessThan(u32, 0, total_weight);
    for (biome.encounter_table) |entry| {
        if (floor_number >= entry.min_floor and floor_number <= entry.max_floor) {
            if (roll < entry.weight) return entry.species_id;
            roll -= entry.weight;
        }
    }

    return null;
}

/// Pick a random boss from the biome's boss pool.
pub fn rollBoss(biome: *const Biome, rng: std.Random) ?*const BossEntry {
    if (biome.boss_pool.len == 0) return null;
    const idx = rng.intRangeLessThan(usize, 0, biome.boss_pool.len);
    return &biome.boss_pool[idx];
}

/// Calculate encounter level based on floor depth.
/// Formula: 3 + floor*2 +/- 1, capped at 50.
pub fn encounterLevel(floor_number: u8, rng: std.Random) u8 {
    const base: i16 = 3 + @as(i16, floor_number) * 2;
    const variance: i16 = @as(i16, rng.intRangeAtMost(u8, 0, 2)) - 1; // -1, 0, or +1
    const level = @max(1, @min(50, base + variance));
    return @intCast(level);
}

/// Roll for an item drop after a battle. Boss kills are guaranteed drops.
/// Base drop chance: 40% + 3% per floor, capped at 70%.
pub fn rollDrop(b: *const Biome, floor_number: u8, is_boss: bool, rng: std.Random) ?[]const u8 {
    if (b.drop_table.len == 0) return null;

    // Check if drop occurs
    if (!is_boss) {
        const chance: u32 = @min(70, 40 + @as(u32, floor_number) * 3);
        if (rng.intRangeLessThan(u32, 0, 100) >= chance) return null;
    }

    // Weighted random selection from drop_table
    var total_weight: u32 = 0;
    for (b.drop_table) |entry| {
        total_weight += entry.weight;
    }
    if (total_weight == 0) return null;

    var roll = rng.intRangeLessThan(u32, 0, total_weight);
    for (b.drop_table) |entry| {
        if (roll < entry.weight) return entry.item_id;
        roll -= entry.weight;
    }

    return null;
}

// --- Tests ---

test "load biomes from JSON" {
    const allocator = std.testing.allocator;
    const parsed = try load(allocator, "data/biomes.json");
    defer parsed.deinit();

    try std.testing.expect(parsed.value.len >= 1);
    const generic = findById(parsed.value, "generic_dungeon");
    try std.testing.expect(generic != null);
    try std.testing.expectEqual(@as(usize, 5), generic.?.encounter_table.len);
    try std.testing.expectEqual(@as(usize, 1), generic.?.boss_pool.len);
    try std.testing.expectEqual(@as(usize, 7), generic.?.shop_bias.len);
}

test "rollEncounter respects floor range" {
    const allocator = std.testing.allocator;
    const parsed = try load(allocator, "data/biomes.json");
    defer parsed.deinit();

    const biome = &parsed.value[0];

    // On floor 1, tracer (min_floor=3) should never appear
    var prng = std.Random.DefaultPrng.init(0);
    var i: u16 = 0;
    while (i < 200) : (i += 1) {
        const result = rollEncounter(biome, 1, prng.random());
        try std.testing.expect(result != null);
        try std.testing.expect(!std.mem.eql(u8, result.?, "tracer"));
    }
}

test "rollEncounter returns tracer on floor 3+" {
    const allocator = std.testing.allocator;
    const parsed = try load(allocator, "data/biomes.json");
    defer parsed.deinit();

    const biome = &parsed.value[0];

    // On floor 5, tracer should eventually appear (weight=5 out of 100)
    var prng = std.Random.DefaultPrng.init(42);
    var found_tracer = false;
    var i: u16 = 0;
    while (i < 500) : (i += 1) {
        const result = rollEncounter(biome, 5, prng.random());
        if (result != null and std.mem.eql(u8, result.?, "tracer")) {
            found_tracer = true;
            break;
        }
    }
    try std.testing.expect(found_tracer);
}

test "encounterLevel scales with floor" {
    var prng = std.Random.DefaultPrng.init(0);
    const lv1 = encounterLevel(1, prng.random());
    const lv10 = encounterLevel(10, prng.random());

    // Floor 1 base = 5, floor 10 base = 23
    try std.testing.expect(lv1 >= 4 and lv1 <= 6);
    try std.testing.expect(lv10 >= 22 and lv10 <= 24);
}

test "encounterLevel capped at 50" {
    var prng = std.Random.DefaultPrng.init(0);
    const lv = encounterLevel(30, prng.random());
    try std.testing.expect(lv <= 50);
}

test "rollDrop returns items from drop_table" {
    const allocator = std.testing.allocator;
    const parsed = try load(allocator, "data/biomes.json");
    defer parsed.deinit();

    const b = &parsed.value[0];
    try std.testing.expect(b.drop_table.len >= 5);

    // Boss drop is guaranteed
    var prng = std.Random.DefaultPrng.init(42);
    const boss_drop = rollDrop(b, 5, true, prng.random());
    try std.testing.expect(boss_drop != null);

    // Normal drops should occur sometimes over many trials
    var drop_count: u32 = 0;
    var i: u32 = 0;
    while (i < 200) : (i += 1) {
        if (rollDrop(b, 3, false, prng.random()) != null) drop_count += 1;
    }
    try std.testing.expect(drop_count > 0);
    try std.testing.expect(drop_count < 200); // Not always
}

test "rollBoss returns valid entry" {
    const allocator = std.testing.allocator;
    const parsed = try load(allocator, "data/biomes.json");
    defer parsed.deinit();

    const biome = &parsed.value[0];
    var prng = std.Random.DefaultPrng.init(0);
    const boss = rollBoss(biome, prng.random());
    try std.testing.expect(boss != null);
    try std.testing.expect(std.mem.eql(u8, boss.?.species_id, "tracer"));
    try std.testing.expectEqual(@as(u8, 5), boss.?.level_bonus);
}
