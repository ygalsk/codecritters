const std = @import("std");
const types = @import("types.zig");
const loader = @import("loader.zig");

pub const StatusEffect = enum {
    none,
    blocked,
    deprecated,
    segfaulted,
    linted,
    tilted,
    in_the_zone,
    spaghettified,
    enlightened,
    hallucinating,
};

pub const Move = struct {
    id: []const u8,
    name: []const u8,
    move_type: types.CritterType,
    power: u16,
    accuracy: u8,
    status_effect: StatusEffect = .none,
    status_chance: u8 = 0,
};

pub fn load(allocator: std.mem.Allocator, path: []const u8) !std.json.Parsed([]Move) {
    return loader.loadJsonFile(Move, allocator, path);
}

pub fn findById(items: []const Move, id: []const u8) ?*const Move {
    for (items) |*m| {
        if (std.mem.eql(u8, m.id, id)) return m;
    }
    return null;
}

test "load moves from JSON" {
    const allocator = std.testing.allocator;
    const parsed = try load(allocator, "data/moves.json");
    defer parsed.deinit();

    try std.testing.expect(parsed.value.len > 0);

    // Check a known move
    const log_dump = findById(parsed.value, "log_dump");
    try std.testing.expect(log_dump != null);
    try std.testing.expectEqual(types.CritterType.debug, log_dump.?.move_type);
    try std.testing.expectEqual(@as(u16, 40), log_dump.?.power);
    try std.testing.expectEqual(@as(u8, 100), log_dump.?.accuracy);
}

test "move with status effect" {
    const allocator = std.testing.allocator;
    const parsed = try load(allocator, "data/moves.json");
    defer parsed.deinit();

    const stack_trace = findById(parsed.value, "stack_trace");
    try std.testing.expect(stack_trace != null);
    try std.testing.expectEqual(StatusEffect.linted, stack_trace.?.status_effect);
    try std.testing.expect(stack_trace.?.status_chance > 0);
}
