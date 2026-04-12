const std = @import("std");
const zqlite = @import("zqlite");
const db_mod = @import("db.zig");

const Db = db_mod.Db;

pub fn getCurrency(database: *Db) u32 {
    const maybe_row = database.conn.row(
        "SELECT value FROM meta WHERE key = 'currency'",
        .{},
    ) catch return 0;
    if (maybe_row) |row| {
        defer row.deinit();
        const val = std.fmt.parseInt(u32, row.text(0), 10) catch return 0;
        return val;
    }
    return 0;
}

pub fn addCurrency(database: *Db, amount: u32) !void {
    var buf: [16]u8 = undefined;
    const amount_str = std.fmt.bufPrint(&buf, "{d}", .{amount}) catch return;
    try database.conn.exec(
        \\INSERT INTO meta (key, value) VALUES ('currency', ?1)
        \\ON CONFLICT(key) DO UPDATE SET value = CAST(CAST(value AS INTEGER) + CAST(?1 AS INTEGER) AS TEXT)
    , .{amount_str});
}

/// Atomically check currency >= amount and deduct. Returns true if successful.
pub fn spendCurrency(database: *Db, amount: u32) bool {
    var buf: [16]u8 = undefined;
    const amount_str = std.fmt.bufPrint(&buf, "{d}", .{amount}) catch return false;
    database.conn.exec(
        \\UPDATE meta SET value = CAST(CAST(value AS INTEGER) - CAST(?1 AS INTEGER) AS TEXT)
        \\WHERE key = 'currency' AND CAST(value AS INTEGER) >= CAST(?1 AS INTEGER)
    , .{amount_str}) catch return false;
    return database.conn.changes() > 0;
}

// --- Tests ---

test "currency get and add" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    // Default is 0
    try std.testing.expectEqual(@as(u32, 0), getCurrency(&db));

    // Add currency
    try addCurrency(&db, 100);
    try std.testing.expectEqual(@as(u32, 100), getCurrency(&db));

    // Add more (stacks)
    try addCurrency(&db, 50);
    try std.testing.expectEqual(@as(u32, 150), getCurrency(&db));
}

test "spend currency" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    try addCurrency(&db, 200);

    // Spend within budget
    try std.testing.expect(spendCurrency(&db, 150));
    try std.testing.expectEqual(@as(u32, 50), getCurrency(&db));

    // Spend more than available — fails, balance unchanged
    try std.testing.expect(!spendCurrency(&db, 100));
    try std.testing.expectEqual(@as(u32, 50), getCurrency(&db));

    // Spend exact remaining
    try std.testing.expect(spendCurrency(&db, 50));
    try std.testing.expectEqual(@as(u32, 0), getCurrency(&db));
}
