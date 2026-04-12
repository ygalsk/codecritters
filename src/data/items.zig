const std = @import("std");
const types = @import("types.zig");
const loader = @import("loader.zig");

pub const ItemKind = enum {
    catch_tool,
    healing,
    revive,
    move_disc,
    xp_grant,
};

pub const CatchTier = enum {
    print_statement,
    breakpoint,
    try_catch,
    linter,
    formal_proof,
};

pub const Item = struct {
    id: []const u8,
    name: []const u8,
    description: []const u8 = "",
    kind: ItemKind,
    rarity: types.Rarity = .common,
    catch_tier: ?CatchTier = null,
    base_catch_rate: ?u8 = null,
    heal_amount: ?u16 = null,
    revive_percent: ?u8 = null,
    move_id: ?[]const u8 = null,
    xp_amount: ?u32 = null,
    buy_price: u16 = 0,
    sell_price: u16 = 0,
};

pub fn load(allocator: std.mem.Allocator, path: []const u8) !std.json.Parsed([]Item) {
    return loader.loadJsonFile(Item, allocator, path);
}

pub fn findById(items: []const Item, id: []const u8) ?*const Item {
    for (items) |*item| {
        if (std.mem.eql(u8, item.id, id)) return item;
    }
    return null;
}

test "load items from JSON" {
    const allocator = std.testing.allocator;
    const parsed = try load(allocator, "data/items.json");
    defer parsed.deinit();

    try std.testing.expect(parsed.value.len > 0);

    // Check a catch tool
    const ps = findById(parsed.value, "print_statement");
    try std.testing.expect(ps != null);
    try std.testing.expectEqual(ItemKind.catch_tool, ps.?.kind);
    try std.testing.expectEqual(CatchTier.print_statement, ps.?.catch_tier.?);
    try std.testing.expectEqual(@as(u8, 20), ps.?.base_catch_rate.?);
    try std.testing.expectEqual(types.Rarity.common, ps.?.rarity);
    try std.testing.expect(ps.?.description.len > 0);

    // Check a healing item
    const hotfix = findById(parsed.value, "hotfix");
    try std.testing.expect(hotfix != null);
    try std.testing.expectEqual(ItemKind.healing, hotfix.?.kind);
    try std.testing.expectEqual(@as(u16, 80), hotfix.?.heal_amount.?);

    // Check a move disc
    const disc = findById(parsed.value, "disc_buffer_overflow");
    try std.testing.expect(disc != null);
    try std.testing.expectEqual(ItemKind.move_disc, disc.?.kind);
    try std.testing.expect(std.mem.eql(u8, "buffer_overflow", disc.?.move_id.?));

    // Check an XP grant item
    const review = findById(parsed.value, "code_review");
    try std.testing.expect(review != null);
    try std.testing.expectEqual(ItemKind.xp_grant, review.?.kind);
    try std.testing.expectEqual(@as(u32, 150), review.?.xp_amount.?);
    try std.testing.expectEqual(types.Rarity.uncommon, review.?.rarity);
}
