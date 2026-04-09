const std = @import("std");
const zqlite = @import("zqlite");

pub const Db = struct {
    conn: zqlite.Conn,

    pub fn open(path: [*:0]const u8) !Db {
        const conn = try zqlite.open(path, zqlite.OpenFlags.Create);
        try conn.execNoArgs("PRAGMA journal_mode=WAL");
        try conn.execNoArgs("PRAGMA foreign_keys=ON");
        return .{ .conn = conn };
    }

    pub fn openMemory() !Db {
        return open(":memory:");
    }

    pub fn close(self: *Db) void {
        self.conn.close();
    }

    pub fn initSchema(self: *Db) !void {
        try self.conn.execNoArgs(
            \\CREATE TABLE IF NOT EXISTS meta (
            \\  key   TEXT PRIMARY KEY,
            \\  value TEXT NOT NULL
            \\)
        );
        try self.conn.execNoArgs(
            \\INSERT OR IGNORE INTO meta (key, value) VALUES ('schema_version', '1')
        );
        try self.conn.execNoArgs(
            \\CREATE TABLE IF NOT EXISTS critters (
            \\  id             INTEGER PRIMARY KEY AUTOINCREMENT,
            \\  species_id     TEXT NOT NULL,
            \\  nickname       TEXT,
            \\  level          INTEGER NOT NULL DEFAULT 1,
            \\  xp             INTEGER NOT NULL DEFAULT 0,
            \\  current_hp     INTEGER NOT NULL,
            \\  max_hp         INTEGER NOT NULL,
            \\  logic          INTEGER NOT NULL,
            \\  resolve        INTEGER NOT NULL,
            \\  speed          INTEGER NOT NULL,
            \\  move_slot_1    TEXT,
            \\  move_slot_2    TEXT,
            \\  move_slot_3    TEXT,
            \\  cooldown_until INTEGER,
            \\  created_at     INTEGER NOT NULL DEFAULT (unixepoch())
            \\)
        );
        try self.conn.execNoArgs(
            \\CREATE TABLE IF NOT EXISTS scars (
            \\  id         INTEGER PRIMARY KEY AUTOINCREMENT,
            \\  critter_id INTEGER NOT NULL REFERENCES critters(id) ON DELETE CASCADE,
            \\  stat       TEXT NOT NULL CHECK(stat IN ('hp','logic','resolve','speed')),
            \\  amount     INTEGER NOT NULL DEFAULT -1
            \\)
        );
        try self.conn.execNoArgs(
            \\CREATE TABLE IF NOT EXISTS inventory (
            \\  id       INTEGER PRIMARY KEY AUTOINCREMENT,
            \\  item_id  TEXT NOT NULL UNIQUE,
            \\  quantity INTEGER NOT NULL DEFAULT 1
            \\)
        );
        try self.conn.execNoArgs(
            \\CREATE TABLE IF NOT EXISTS settings (
            \\  key   TEXT PRIMARY KEY,
            \\  value TEXT NOT NULL
            \\)
        );
    }
};

test "open in-memory database and init schema" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    // Verify schema version
    if (try db.conn.row("SELECT value FROM meta WHERE key = 'schema_version'", .{})) |row| {
        defer row.deinit();
        const version = row.text(0);
        try std.testing.expect(std.mem.eql(u8, "1", version));
    } else {
        return error.TestUnexpectedResult;
    }
}
