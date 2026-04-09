const std = @import("std");
const zqlite = @import("zqlite");

pub const Db = struct {
    conn: zqlite.Conn,

    pub fn open(path: [*:0]const u8) !Db {
        const conn = try zqlite.open(path, zqlite.OpenFlags.Create);
        try conn.execNoArgs("PRAGMA journal_mode=WAL");
        try conn.execNoArgs("PRAGMA busy_timeout=3000");
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
            \\  cooldown_runs INTEGER NOT NULL DEFAULT 0,
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
        try self.conn.execNoArgs(
            \\CREATE TABLE IF NOT EXISTS runs (
            \\  id           INTEGER PRIMARY KEY AUTOINCREMENT,
            \\  biome_id     TEXT NOT NULL,
            \\  floor_number INTEGER NOT NULL DEFAULT 1,
            \\  currency     INTEGER NOT NULL DEFAULT 0,
            \\  outcome      TEXT NOT NULL DEFAULT 'in_progress'
            \\               CHECK(outcome IN ('in_progress','extracted','wiped')),
            \\  seed         INTEGER NOT NULL,
            \\  started_at   INTEGER NOT NULL DEFAULT (unixepoch()),
            \\  ended_at     INTEGER
            \\)
        );
        try self.conn.execNoArgs(
            \\CREATE TABLE IF NOT EXISTS run_party (
            \\  run_id     INTEGER NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
            \\  slot       INTEGER NOT NULL CHECK(slot BETWEEN 0 AND 2),
            \\  critter_id INTEGER NOT NULL REFERENCES critters(id),
            \\  current_hp INTEGER NOT NULL,
            \\  PRIMARY KEY (run_id, slot)
            \\)
        );
        try self.conn.execNoArgs(
            \\CREATE TABLE IF NOT EXISTS run_inventory (
            \\  run_id   INTEGER NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
            \\  item_id  TEXT NOT NULL,
            \\  quantity INTEGER NOT NULL DEFAULT 1,
            \\  PRIMARY KEY (run_id, item_id)
            \\)
        );
        try self.conn.execNoArgs(
            \\CREATE TABLE IF NOT EXISTS run_catches (
            \\  id           INTEGER PRIMARY KEY AUTOINCREMENT,
            \\  run_id       INTEGER NOT NULL REFERENCES runs(id) ON DELETE CASCADE,
            \\  species_id   TEXT NOT NULL,
            \\  level        INTEGER NOT NULL,
            \\  floor_caught INTEGER NOT NULL
            \\)
        );
        try self.conn.execNoArgs(
            \\CREATE TABLE IF NOT EXISTS events (
            \\  id         INTEGER PRIMARY KEY AUTOINCREMENT,
            \\  event_type TEXT NOT NULL,
            \\  timestamp  INTEGER NOT NULL DEFAULT (unixepoch()),
            \\  processed  INTEGER NOT NULL DEFAULT 0
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
