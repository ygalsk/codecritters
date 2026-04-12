const std = @import("std");
const zqlite = @import("zqlite");
const db_mod = @import("db.zig");
const currency_store = @import("currency_store.zig");

const Db = db_mod.Db;

fn metaKey(buf: []u8, prefix: []const u8, id: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(buf, "{s}{s}", .{ prefix, id }) catch null;
}

// --- Meta Upgrades ---

pub fn getMetaUpgradeLevel(database: *Db, upgrade_id: []const u8) u8 {
    var key_buf: [64]u8 = undefined;
    const key = metaKey(&key_buf, "upgrade:", upgrade_id) orelse return 0;
    const maybe_row = database.conn.row(
        "SELECT value FROM meta WHERE key = ?1",
        .{key},
    ) catch return 0;
    if (maybe_row) |row| {
        defer row.deinit();
        return std.fmt.parseInt(u8, row.text(0), 10) catch 0;
    }
    return 0;
}

/// Purchase a meta upgrade: spend currency and set incremented level.
/// Not transactional — safe only in single-threaded use.
pub fn purchaseMetaUpgrade(database: *Db, upgrade_id: []const u8, cost: u32) bool {
    if (!currency_store.spendCurrency(database, cost)) return false;
    var key_buf: [64]u8 = undefined;
    const key = metaKey(&key_buf, "upgrade:", upgrade_id) orelse return false;
    var val_buf: [16]u8 = undefined;
    const new_level_str = std.fmt.bufPrint(&val_buf, "{d}", .{getMetaUpgradeLevel(database, upgrade_id) + 1}) catch return false;
    database.conn.exec(
        \\INSERT INTO meta (key, value) VALUES (?1, ?2)
        \\ON CONFLICT(key) DO UPDATE SET value = ?2
    , .{ key, new_level_str }) catch return false;
    return true;
}

// --- Meta Stats ---

pub fn getMetaStat(database: *Db, stat_key: []const u8) u64 {
    var key_buf: [64]u8 = undefined;
    const key = metaKey(&key_buf, "stat:", stat_key) orelse return 0;
    const maybe_row = database.conn.row(
        "SELECT value FROM meta WHERE key = ?1",
        .{key},
    ) catch return 0;
    if (maybe_row) |row| {
        defer row.deinit();
        return std.fmt.parseInt(u64, row.text(0), 10) catch 0;
    }
    return 0;
}

pub fn incrementMetaStat(database: *Db, stat_key: []const u8, amount: u64) !void {
    var key_buf: [64]u8 = undefined;
    const key = metaKey(&key_buf, "stat:", stat_key) orelse return;
    var val_buf: [24]u8 = undefined;
    const amount_str = std.fmt.bufPrint(&val_buf, "{d}", .{amount}) catch return;
    try database.conn.exec(
        \\INSERT INTO meta (key, value) VALUES (?1, ?2)
        \\ON CONFLICT(key) DO UPDATE SET value = CAST(CAST(value AS INTEGER) + CAST(?2 AS INTEGER) AS TEXT)
    , .{ key, amount_str });
}

pub fn updateMetaStatMax(database: *Db, stat_key: []const u8, value: u64) !void {
    var key_buf: [64]u8 = undefined;
    const key = metaKey(&key_buf, "stat:", stat_key) orelse return;
    var val_buf: [24]u8 = undefined;
    const val_str = std.fmt.bufPrint(&val_buf, "{d}", .{value}) catch return;
    try database.conn.exec(
        \\INSERT INTO meta (key, value) VALUES (?1, ?2)
        \\ON CONFLICT(key) DO UPDATE SET value = CASE
        \\  WHEN CAST(value AS INTEGER) < CAST(?2 AS INTEGER) THEN ?2
        \\  ELSE value
        \\END
    , .{ key, val_str });
}

pub fn isSpeciesDiscovered(database: *Db, species_id: []const u8) bool {
    var key_buf: [80]u8 = undefined;
    const key = metaKey(&key_buf, "stat:seen:", species_id) orelse return false;
    const maybe_row = database.conn.row(
        "SELECT 1 FROM meta WHERE key = ?1",
        .{key},
    ) catch return false;
    if (maybe_row) |row| {
        row.deinit();
        return true;
    }
    return false;
}

pub fn markSpeciesDiscovered(database: *Db, species_id: []const u8) void {
    var key_buf: [80]u8 = undefined;
    const key = metaKey(&key_buf, "stat:seen:", species_id) orelse return;
    setMetaFlag(database, key) catch {};
}

/// Set a meta key to "1" (used for species discovery tracking).
pub fn setMetaFlag(database: *Db, key: []const u8) !void {
    try database.conn.exec(
        \\INSERT INTO meta (key, value) VALUES (?1, '1')
        \\ON CONFLICT(key) DO NOTHING
    , .{key});
}

/// Count meta keys matching a prefix (e.g. "stat:seen:" for species discovered).
pub fn countMetaKeysWithPrefix(database: *Db, prefix: []const u8) u64 {
    var pattern_buf: [80]u8 = undefined;
    const pattern = std.fmt.bufPrint(&pattern_buf, "{s}%", .{prefix}) catch return 0;
    const maybe_row = database.conn.row(
        "SELECT COUNT(*) FROM meta WHERE key LIKE ?1",
        .{pattern},
    ) catch return 0;
    if (maybe_row) |row| {
        defer row.deinit();
        return @intCast(row.int(0));
    }
    return 0;
}

// --- Tests ---

test "meta upgrade purchase" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    try currency_store.addCurrency(&db, 1000);

    // Default level is 0
    try std.testing.expectEqual(@as(u8, 0), getMetaUpgradeLevel(&db, "extra_pack_slots"));

    // Purchase upgrade
    try std.testing.expect(purchaseMetaUpgrade(&db, "extra_pack_slots", 150));
    try std.testing.expectEqual(@as(u8, 1), getMetaUpgradeLevel(&db, "extra_pack_slots"));
    try std.testing.expectEqual(@as(u32, 850), currency_store.getCurrency(&db));

    // Purchase again
    try std.testing.expect(purchaseMetaUpgrade(&db, "extra_pack_slots", 300));
    try std.testing.expectEqual(@as(u8, 2), getMetaUpgradeLevel(&db, "extra_pack_slots"));
    try std.testing.expectEqual(@as(u32, 550), currency_store.getCurrency(&db));

    // Insufficient funds
    try std.testing.expect(!purchaseMetaUpgrade(&db, "extra_pack_slots", 600));
    try std.testing.expectEqual(@as(u8, 2), getMetaUpgradeLevel(&db, "extra_pack_slots"));
    try std.testing.expectEqual(@as(u32, 550), currency_store.getCurrency(&db));
}

test "meta stat tracking" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    // Default is 0
    try std.testing.expectEqual(@as(u64, 0), getMetaStat(&db, "total_runs"));

    // Increment
    try incrementMetaStat(&db, "total_runs", 1);
    try std.testing.expectEqual(@as(u64, 1), getMetaStat(&db, "total_runs"));

    try incrementMetaStat(&db, "total_runs", 1);
    try std.testing.expectEqual(@as(u64, 2), getMetaStat(&db, "total_runs"));

    // Max-update
    try updateMetaStatMax(&db, "deepest_floor", 5);
    try std.testing.expectEqual(@as(u64, 5), getMetaStat(&db, "deepest_floor"));

    // Update with lower value — no change
    try updateMetaStatMax(&db, "deepest_floor", 3);
    try std.testing.expectEqual(@as(u64, 5), getMetaStat(&db, "deepest_floor"));

    // Update with higher value
    try updateMetaStatMax(&db, "deepest_floor", 10);
    try std.testing.expectEqual(@as(u64, 10), getMetaStat(&db, "deepest_floor"));
}

test "species discovery tracking" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    // No species seen yet
    try std.testing.expectEqual(@as(u64, 0), countMetaKeysWithPrefix(&db, "stat:seen:"));

    // Discover some species
    try setMetaFlag(&db, "stat:seen:println");
    try setMetaFlag(&db, "stat:seen:glitch");
    try std.testing.expectEqual(@as(u64, 2), countMetaKeysWithPrefix(&db, "stat:seen:"));

    // Duplicate discovery — no change
    try setMetaFlag(&db, "stat:seen:println");
    try std.testing.expectEqual(@as(u64, 2), countMetaKeysWithPrefix(&db, "stat:seen:"));
}
