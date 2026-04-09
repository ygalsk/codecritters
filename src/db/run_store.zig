const std = @import("std");
const zqlite = @import("zqlite");
const db_mod = @import("db.zig");
const critter_mod = @import("critter");

const Db = db_mod.Db;

pub const RunRecord = struct {
    id: i64,
    biome_id: []const u8,
    floor_number: u8,
    currency: u32,
    outcome: []const u8,
    seed: u64,
};

pub const RunPartySlot = struct {
    critter_id: i64,
    current_hp: u16,
};

pub const RunCatch = struct {
    species_id: []const u8,
    level: u8,
    floor_caught: u8,
};

/// Save a new run. Returns the run ID.
pub fn saveRun(
    db: *Db,
    biome_id: []const u8,
    seed: u64,
    floor_number: u8,
    currency: u32,
) !i64 {
    try db.conn.exec(
        \\INSERT INTO runs (biome_id, seed, floor_number, currency)
        \\VALUES (?1, ?2, ?3, ?4)
    , .{
        biome_id,
        @as(i64, @bitCast(seed)),
        @as(i64, floor_number),
        @as(i64, currency),
    });
    return db.conn.lastInsertedRowId();
}

/// Update run progress (floor number, currency).
pub fn updateRun(db: *Db, run_id: i64, floor_number: u8, currency: u32) !void {
    try db.conn.exec(
        "UPDATE runs SET floor_number = ?1, currency = ?2 WHERE id = ?3",
        .{ @as(i64, floor_number), @as(i64, currency), run_id },
    );
}

/// Save a party slot for a run.
pub fn saveRunPartySlot(db: *Db, run_id: i64, slot: u8, critter_id: i64, current_hp: u16) !void {
    try db.conn.exec(
        \\INSERT OR REPLACE INTO run_party (run_id, slot, critter_id, current_hp)
        \\VALUES (?1, ?2, ?3, ?4)
    , .{
        run_id,
        @as(i64, slot),
        critter_id,
        @as(i64, current_hp),
    });
}

/// Record a catch during a run.
pub fn saveRunCatch(db: *Db, run_id: i64, species_id: []const u8, level: u8, floor_caught: u8) !void {
    try db.conn.exec(
        \\INSERT INTO run_catches (run_id, species_id, level, floor_caught)
        \\VALUES (?1, ?2, ?3, ?4)
    , .{
        run_id,
        species_id,
        @as(i64, level),
        @as(i64, floor_caught),
    });
}

/// Save a run inventory item.
pub fn saveRunInventoryItem(db: *Db, run_id: i64, item_id: []const u8, quantity: u16) !void {
    try db.conn.exec(
        \\INSERT OR REPLACE INTO run_inventory (run_id, item_id, quantity)
        \\VALUES (?1, ?2, ?3)
    , .{
        run_id,
        item_id,
        @as(i64, quantity),
    });
}

/// End a run with the given outcome.
pub fn endRun(db: *Db, run_id: i64, outcome: []const u8) !void {
    try db.conn.exec(
        "UPDATE runs SET outcome = ?1, ended_at = unixepoch() WHERE id = ?2",
        .{ outcome, run_id },
    );
}

/// Load a run record by ID.
pub fn loadRun(db: *Db, allocator: std.mem.Allocator, run_id: i64) !?RunRecord {
    const maybe_row = try db.conn.row(
        "SELECT id, biome_id, floor_number, currency, outcome, seed FROM runs WHERE id = ?1",
        .{run_id},
    );

    if (maybe_row) |row| {
        defer row.deinit();
        return .{
            .id = row.int(0),
            .biome_id = try allocator.dupe(u8, row.text(1)),
            .floor_number = @intCast(row.int(2)),
            .currency = @intCast(row.int(3)),
            .outcome = try allocator.dupe(u8, row.text(4)),
            .seed = @bitCast(row.int(5)),
        };
    }
    return null;
}

pub fn freeRunRecord(allocator: std.mem.Allocator, record: *RunRecord) void {
    allocator.free(record.biome_id);
    allocator.free(record.outcome);
}

/// Load party slots for a run.
pub fn loadRunParty(db: *Db, allocator: std.mem.Allocator, run_id: i64) ![]RunPartySlot {
    var slots: std.ArrayList(RunPartySlot) = .{};
    errdefer slots.deinit(allocator);

    var rows = try db.conn.rows(
        "SELECT critter_id, current_hp FROM run_party WHERE run_id = ?1 ORDER BY slot",
        .{run_id},
    );
    defer rows.deinit();

    while (rows.next()) |row| {
        try slots.append(allocator, .{
            .critter_id = row.int(0),
            .current_hp = @intCast(row.int(1)),
        });
    }
    if (rows.err) |err| return err;

    return slots.toOwnedSlice(allocator);
}

/// Load catches for a run.
pub fn loadRunCatches(db: *Db, allocator: std.mem.Allocator, run_id: i64) ![]RunCatch {
    var catches: std.ArrayList(RunCatch) = .{};
    errdefer {
        for (catches.items) |c| allocator.free(c.species_id);
        catches.deinit(allocator);
    }

    var rows = try db.conn.rows(
        "SELECT species_id, level, floor_caught FROM run_catches WHERE run_id = ?1",
        .{run_id},
    );
    defer rows.deinit();

    while (rows.next()) |row| {
        try catches.append(allocator, .{
            .species_id = try allocator.dupe(u8, row.text(0)),
            .level = @intCast(row.int(1)),
            .floor_caught = @intCast(row.int(2)),
        });
    }
    if (rows.err) |err| return err;

    return catches.toOwnedSlice(allocator);
}

pub fn freeRunCatches(allocator: std.mem.Allocator, catches: []RunCatch) void {
    for (catches) |c| allocator.free(c.species_id);
    allocator.free(catches);
}

/// Find an active (in-progress) run.
pub fn findActiveRun(db: *Db) !?i64 {
    const maybe_row = try db.conn.row(
        "SELECT id FROM runs WHERE outcome = 'in_progress' ORDER BY id DESC LIMIT 1",
        .{},
    );
    if (maybe_row) |row| {
        defer row.deinit();
        return row.int(0);
    }
    return null;
}

// --- Tests ---

test "save and load run round-trip" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    const allocator = std.testing.allocator;

    const run_id = try saveRun(&db, "generic_dungeon", 42, 1, 0);
    try std.testing.expect(run_id > 0);

    var record = (try loadRun(&db, allocator, run_id)).?;
    defer freeRunRecord(allocator, &record);

    try std.testing.expect(std.mem.eql(u8, "generic_dungeon", record.biome_id));
    try std.testing.expectEqual(@as(u8, 1), record.floor_number);
    try std.testing.expectEqual(@as(u32, 0), record.currency);
    try std.testing.expect(std.mem.eql(u8, "in_progress", record.outcome));
    try std.testing.expectEqual(@as(u64, 42), record.seed);
}

test "update run progress" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    const allocator = std.testing.allocator;

    const run_id = try saveRun(&db, "generic_dungeon", 99, 1, 0);
    try updateRun(&db, run_id, 5, 150);

    var record = (try loadRun(&db, allocator, run_id)).?;
    defer freeRunRecord(allocator, &record);

    try std.testing.expectEqual(@as(u8, 5), record.floor_number);
    try std.testing.expectEqual(@as(u32, 150), record.currency);
}

test "end run updates outcome" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    const allocator = std.testing.allocator;

    const run_id = try saveRun(&db, "generic_dungeon", 42, 1, 0);
    try endRun(&db, run_id, "extracted");

    var record = (try loadRun(&db, allocator, run_id)).?;
    defer freeRunRecord(allocator, &record);

    try std.testing.expect(std.mem.eql(u8, "extracted", record.outcome));
}

test "save and load run party" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    const allocator = std.testing.allocator;

    // Need a critter in the DB first for foreign key
    const critter = critter_mod.Critter{
        .id = 0,
        .species_id = "println",
        .nickname = null,
        .level = 10,
        .xp = 0,
        .current_hp = 80,
        .max_hp = 100,
        .logic = 50,
        .resolve = 40,
        .speed = 45,
        .move_slot_1 = "log_dump",
        .move_slot_2 = null,
        .move_slot_3 = null,
        .scars = &.{},
        .cooldown_until = null,
    };
    // Insert critter directly
    try db.conn.exec(
        \\INSERT INTO critters (species_id, level, xp, current_hp, max_hp, logic, resolve, speed, move_slot_1)
        \\VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
    , .{
        critter.species_id,
        @as(i64, critter.level),
        @as(i64, critter.xp),
        @as(i64, critter.current_hp),
        @as(i64, critter.max_hp),
        @as(i64, critter.logic),
        @as(i64, critter.resolve),
        @as(i64, critter.speed),
        critter.move_slot_1,
    });
    const critter_id = db.conn.lastInsertedRowId();

    const run_id = try saveRun(&db, "generic_dungeon", 42, 1, 0);
    try saveRunPartySlot(&db, run_id, 0, critter_id, 80);

    const party = try loadRunParty(&db, allocator, run_id);
    defer allocator.free(party);

    try std.testing.expectEqual(@as(usize, 1), party.len);
    try std.testing.expectEqual(critter_id, party[0].critter_id);
    try std.testing.expectEqual(@as(u16, 80), party[0].current_hp);
}

test "save and load run catches" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    const allocator = std.testing.allocator;

    const run_id = try saveRun(&db, "generic_dungeon", 42, 1, 0);
    try saveRunCatch(&db, run_id, "glitch", 8, 2);
    try saveRunCatch(&db, run_id, "monad", 12, 4);

    const catches = try loadRunCatches(&db, allocator, run_id);
    defer freeRunCatches(allocator, catches);

    try std.testing.expectEqual(@as(usize, 2), catches.len);
    try std.testing.expect(std.mem.eql(u8, "glitch", catches[0].species_id));
    try std.testing.expectEqual(@as(u8, 8), catches[0].level);
    try std.testing.expectEqual(@as(u8, 2), catches[0].floor_caught);
}

test "find active run" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    // No runs yet
    const none = try findActiveRun(&db);
    try std.testing.expectEqual(@as(?i64, null), none);

    // Create a run
    const run_id = try saveRun(&db, "generic_dungeon", 42, 1, 0);

    const active = try findActiveRun(&db);
    try std.testing.expectEqual(run_id, active.?);

    // End it
    try endRun(&db, run_id, "wiped");
    const after_end = try findActiveRun(&db);
    try std.testing.expectEqual(@as(?i64, null), after_end);
}
