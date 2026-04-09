const std = @import("std");
const zqlite = @import("zqlite");
const db_mod = @import("db.zig");

const Db = db_mod.Db;

pub const EventRecord = struct {
    id: i64,
    event_type: []const u8,
    timestamp: i64,
};

pub fn logEvent(db: *Db, event_type: []const u8) !void {
    try db.conn.exec(
        "INSERT INTO events (event_type) VALUES (?1)",
        .{event_type},
    );
}

pub fn countUnprocessedEvents(db: *Db) u32 {
    const maybe_row = db.conn.row(
        "SELECT COUNT(*) FROM events WHERE processed = 0",
        .{},
    ) catch return 0;
    if (maybe_row) |row| {
        defer row.deinit();
        return @intCast(@max(row.int(0), 0));
    }
    return 0;
}

pub fn loadUnprocessedEvents(db: *Db, allocator: std.mem.Allocator) ![]EventRecord {
    var events: std.ArrayList(EventRecord) = .{};
    errdefer {
        for (events.items) |e| allocator.free(e.event_type);
        events.deinit(allocator);
    }

    var rows = try db.conn.rows(
        "SELECT id, event_type, timestamp FROM events WHERE processed = 0 ORDER BY id",
        .{},
    );
    defer rows.deinit();

    while (rows.next()) |row| {
        try events.append(allocator, .{
            .id = row.int(0),
            .event_type = try allocator.dupe(u8, row.text(1)),
            .timestamp = row.int(2),
        });
    }
    if (rows.err) |err| return err;

    return events.toOwnedSlice(allocator);
}

pub fn freeEvents(allocator: std.mem.Allocator, events: []EventRecord) void {
    for (events) |e| allocator.free(e.event_type);
    allocator.free(events);
}

pub fn markEventsProcessed(db: *Db, up_to_id: i64) !void {
    try db.conn.exec(
        "UPDATE events SET processed = 1 WHERE id <= ?1 AND processed = 0",
        .{up_to_id},
    );
}

pub fn markAllEventsProcessed(db: *Db) !void {
    try db.conn.execNoArgs("UPDATE events SET processed = 1 WHERE processed = 0");
}

pub fn getFavoriteCritterId(db: *Db) ?i64 {
    const maybe_row = db.conn.row(
        "SELECT value FROM settings WHERE key = 'favorite_critter_id'",
        .{},
    ) catch return null;
    if (maybe_row) |row| {
        defer row.deinit();
        return std.fmt.parseInt(i64, row.text(0), 10) catch null;
    }
    return null;
}

pub fn setFavoriteCritterId(db: *Db, critter_id: i64) !void {
    var buf: [20]u8 = undefined;
    const id_str = std.fmt.bufPrint(&buf, "{d}", .{critter_id}) catch return;
    try db.conn.exec(
        "INSERT OR REPLACE INTO settings (key, value) VALUES ('favorite_critter_id', ?1)",
        .{id_str},
    );
}

// --- Tests ---

test "logEvent and countUnprocessed" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    try std.testing.expectEqual(@as(u32, 0), countUnprocessedEvents(&db));

    try logEvent(&db, "bash");
    try logEvent(&db, "edit");
    try logEvent(&db, "write");

    try std.testing.expectEqual(@as(u32, 3), countUnprocessedEvents(&db));
}

test "loadUnprocessedEvents returns correct records" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    const allocator = std.testing.allocator;

    try logEvent(&db, "bash");
    try logEvent(&db, "edit");

    const events = try loadUnprocessedEvents(&db, allocator);
    defer freeEvents(allocator, events);

    try std.testing.expectEqual(@as(usize, 2), events.len);
    try std.testing.expect(std.mem.eql(u8, "bash", events[0].event_type));
    try std.testing.expect(std.mem.eql(u8, "edit", events[1].event_type));
    try std.testing.expect(events[0].id < events[1].id);
}

test "markEventsProcessed" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    const allocator = std.testing.allocator;

    try logEvent(&db, "bash");
    try logEvent(&db, "edit");
    try logEvent(&db, "write");

    // Load to get IDs
    const events = try loadUnprocessedEvents(&db, allocator);
    defer freeEvents(allocator, events);

    // Mark first two as processed
    try markEventsProcessed(&db, events[1].id);

    try std.testing.expectEqual(@as(u32, 1), countUnprocessedEvents(&db));
}

test "favorite critter get/set round-trip" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    // Default is null
    try std.testing.expectEqual(@as(?i64, null), getFavoriteCritterId(&db));

    // Set and get
    try setFavoriteCritterId(&db, 42);
    try std.testing.expectEqual(@as(?i64, 42), getFavoriteCritterId(&db));

    // Update
    try setFavoriteCritterId(&db, 7);
    try std.testing.expectEqual(@as(?i64, 7), getFavoriteCritterId(&db));
}

test "loadUnprocessedEvents skips processed" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    const allocator = std.testing.allocator;

    try logEvent(&db, "bash");
    try logEvent(&db, "edit");

    // Load and mark all processed
    const events1 = try loadUnprocessedEvents(&db, allocator);
    try markEventsProcessed(&db, events1[events1.len - 1].id);
    freeEvents(allocator, events1);

    // Add one more
    try logEvent(&db, "write");

    const events2 = try loadUnprocessedEvents(&db, allocator);
    defer freeEvents(allocator, events2);

    try std.testing.expectEqual(@as(usize, 1), events2.len);
    try std.testing.expect(std.mem.eql(u8, "write", events2[0].event_type));
}
