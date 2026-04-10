const std = @import("std");
const types = @import("types.zig");
const loader = @import("loader.zig");

pub const Rarity = types.Rarity;

pub const BaseStats = struct {
    hp: u16,
    logic: u16,
    resolve: u16,
    speed: u16,
};

pub const Species = struct {
    id: []const u8,
    name: []const u8,
    critter_type: types.CritterType,
    rarity: Rarity,
    base_stats: BaseStats,
    signature_move: []const u8,
    secondary_move: ?[]const u8 = null,
    evolves_to: ?[]const u8 = null,
    evolution_level: ?u8 = null,
};

pub fn load(allocator: std.mem.Allocator, path: []const u8) !std.json.Parsed([]Species) {
    return loader.loadJsonFile(Species, allocator, path);
}

pub fn findById(items: []const Species, id: []const u8) ?*const Species {
    for (items) |*s| {
        if (std.mem.eql(u8, s.id, id)) return s;
    }
    return null;
}

test "load species from JSON" {
    const allocator = std.testing.allocator;
    const parsed = try load(allocator, "data/species.json");
    defer parsed.deinit();

    try std.testing.expect(parsed.value.len >= 5);

    const println = findById(parsed.value, "println");
    try std.testing.expect(println != null);
    try std.testing.expectEqual(types.CritterType.debug, println.?.critter_type);
    try std.testing.expectEqual(Rarity.common, println.?.rarity);
    try std.testing.expectEqual(@as(u16, 45), println.?.base_stats.hp);
    try std.testing.expect(std.mem.eql(u8, "tracer", println.?.evolves_to.?));
    try std.testing.expectEqual(@as(u8, 12), println.?.evolution_level.?);
}

test "species without evolution" {
    const allocator = std.testing.allocator;
    const parsed = try load(allocator, "data/species.json");
    defer parsed.deinit();

    // Monad should have evolution in our test data
    const monad = findById(parsed.value, "monad");
    try std.testing.expect(monad != null);
    try std.testing.expectEqual(types.CritterType.wisdom, monad.?.critter_type);
}
