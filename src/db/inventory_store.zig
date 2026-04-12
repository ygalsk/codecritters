const std = @import("std");
const zqlite = @import("zqlite");
const db_mod = @import("db.zig");

const Db = db_mod.Db;

pub const InventoryEntry = struct {
    item_id: []const u8,
    quantity: i64,
};

pub fn addInventoryItem(db: *Db, item_id: []const u8, quantity: i64) !void {
    try db.conn.exec(
        \\INSERT INTO inventory (item_id, quantity) VALUES (?1, ?2)
        \\ON CONFLICT(item_id) DO UPDATE SET quantity = quantity + ?2
    , .{ item_id, quantity });
}

pub fn removeInventoryItem(database: *Db, item_id: []const u8, quantity: i64) !void {
    try database.conn.exec(
        \\UPDATE inventory SET quantity = quantity - ?2 WHERE item_id = ?1
    , .{ item_id, quantity });
    try database.conn.exec(
        \\DELETE FROM inventory WHERE item_id = ?1 AND quantity <= 0
    , .{item_id});
}

pub fn loadInventory(db: *Db, allocator: std.mem.Allocator) ![]InventoryEntry {
    var entries: std.ArrayList(InventoryEntry) = .{};
    errdefer {
        for (entries.items) |e| allocator.free(e.item_id);
        entries.deinit(allocator);
    }

    var rows = try db.conn.rows("SELECT item_id, quantity FROM inventory", .{});
    defer rows.deinit();

    while (rows.next()) |row| {
        try entries.append(allocator, .{
            .item_id = try allocator.dupe(u8, row.text(0)),
            .quantity = row.int(1),
        });
    }
    if (rows.err) |err| return err;

    return entries.toOwnedSlice(allocator);
}

pub fn freeInventory(allocator: std.mem.Allocator, inv: []InventoryEntry) void {
    for (inv) |e| allocator.free(e.item_id);
    allocator.free(inv);
}

// --- Tests ---

test "inventory add and load" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    const allocator = std.testing.allocator;

    try addInventoryItem(&db, "small_patch", 3);
    try addInventoryItem(&db, "print_statement", 5);

    const inv = try loadInventory(&db, allocator);
    defer freeInventory(allocator, inv);

    try std.testing.expectEqual(@as(usize, 2), inv.len);
}
