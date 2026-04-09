const std = @import("std");
const species_mod = @import("species.zig");

pub const StatKind = enum {
    hp,
    logic,
    resolve,
    speed,
};

pub const Scar = struct {
    stat: StatKind,
    amount: i8,
};

pub const Critter = struct {
    id: u64,
    species_id: []const u8,
    nickname: ?[]const u8,
    level: u8,
    xp: u32,
    current_hp: u16,
    max_hp: u16,
    logic: u16,
    resolve: u16,
    speed: u16,
    move_slot_1: ?[]const u8,
    move_slot_2: ?[]const u8,
    move_slot_3: ?[]const u8,
    scars: []Scar,
    cooldown_until: ?i64,

    /// Calculate stats for a given species at a given level.
    /// Simple linear scaling: stat = base + (level * base / 50)
    pub fn calcStat(base: u16, level: u8) u16 {
        const lvl: u32 = @intCast(level);
        const b: u32 = @intCast(base);
        return @intCast(b + (lvl * b / 50));
    }

    /// Recompute all stats from species base stats at the critter's current level.
    /// Adjusts current_hp proportionally (preserving damage taken).
    pub fn recomputeStats(self: *Critter, sp: *const species_mod.Species) void {
        const old_max = self.max_hp;
        const new_max = calcStat(sp.base_stats.hp, self.level);
        self.max_hp = new_max;
        if (new_max > old_max) {
            self.current_hp +|= new_max - old_max;
        }
        if (self.current_hp > new_max) self.current_hp = new_max;
        self.logic = calcStat(sp.base_stats.logic, self.level);
        self.resolve = calcStat(sp.base_stats.resolve, self.level);
        self.speed = calcStat(sp.base_stats.speed, self.level);
    }

    /// Create a new critter instance from a species definition at a given level.
    pub fn createFromSpecies(sp: *const species_mod.Species, level: u8) Critter {
        const hp = calcStat(sp.base_stats.hp, level);
        return .{
            .id = 0,
            .species_id = sp.id,
            .nickname = null,
            .level = level,
            .xp = 0,
            .current_hp = hp,
            .max_hp = hp,
            .logic = calcStat(sp.base_stats.logic, level),
            .resolve = calcStat(sp.base_stats.resolve, level),
            .speed = calcStat(sp.base_stats.speed, level),
            .move_slot_1 = sp.signature_move,
            .move_slot_2 = sp.secondary_move,
            .move_slot_3 = null,
            .scars = &.{},
            .cooldown_until = null,
        };
    }
};

test "create critter from species" {
    const sp = species_mod.Species{
        .id = "println",
        .name = "Println",
        .critter_type = .debug,
        .rarity = .common,
        .base_stats = .{ .hp = 45, .logic = 55, .resolve = 40, .speed = 50 },
        .signature_move = "log_dump",
        .secondary_move = null,
        .evolves_to = "tracer",
        .evolution_level = 12,
    };

    const c = Critter.createFromSpecies(&sp, 10);
    try std.testing.expectEqual(@as(u8, 10), c.level);
    try std.testing.expect(std.mem.eql(u8, "println", c.species_id));
    try std.testing.expect(std.mem.eql(u8, "log_dump", c.move_slot_1.?));
    try std.testing.expectEqual(@as(?[]const u8, null), c.move_slot_2);
    // HP at level 10: 45 + (10 * 45 / 50) = 45 + 9 = 54
    try std.testing.expectEqual(@as(u16, 54), c.max_hp);
    try std.testing.expectEqual(c.max_hp, c.current_hp);
    // Logic at level 10: 55 + (10 * 55 / 50) = 55 + 11 = 66
    try std.testing.expectEqual(@as(u16, 66), c.logic);
}
