const std = @import("std");
const zqlite = @import("zqlite");
const db_mod = @import("db.zig");
const critter_mod = @import("critter");

const Critter = critter_mod.Critter;
const Scar = critter_mod.Scar;
const StatKind = critter_mod.StatKind;
const Db = db_mod.Db;

pub fn saveCritter(db: *Db, critter: *const Critter) !i64 {
    if (critter.id != 0) {
        try db.conn.exec(
            \\UPDATE critters SET
            \\  species_id=?1, nickname=?2, level=?3, xp=?4,
            \\  current_hp=?5, max_hp=?6, logic=?7, resolve=?8, speed=?9,
            \\  move_slot_1=?10, move_slot_2=?11, move_slot_3=?12, cooldown_until=?13
            \\WHERE id=?14
        , .{
            critter.species_id,
            critter.nickname,
            @as(i64, critter.level),
            @as(i64, critter.xp),
            @as(i64, critter.current_hp),
            @as(i64, critter.max_hp),
            @as(i64, critter.logic),
            @as(i64, critter.resolve),
            @as(i64, critter.speed),
            critter.move_slot_1,
            critter.move_slot_2,
            critter.move_slot_3,
            critter.cooldown_until,
            @as(i64, @intCast(critter.id)),
        });
        return @intCast(critter.id);
    } else {
        try db.conn.exec(
            \\INSERT INTO critters
            \\  (species_id, nickname, level, xp, current_hp, max_hp,
            \\   logic, resolve, speed, move_slot_1, move_slot_2, move_slot_3, cooldown_until)
            \\VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13)
        , .{
            critter.species_id,
            critter.nickname,
            @as(i64, critter.level),
            @as(i64, critter.xp),
            @as(i64, critter.current_hp),
            @as(i64, critter.max_hp),
            @as(i64, critter.logic),
            @as(i64, critter.resolve),
            @as(i64, critter.speed),
            critter.move_slot_1,
            critter.move_slot_2,
            critter.move_slot_3,
            critter.cooldown_until,
        });
        return db.conn.lastInsertedRowId();
    }
}

pub fn addScar(db: *Db, critter_id: i64, stat: StatKind, amount: i8) !void {
    const stat_str: []const u8 = switch (stat) {
        .hp => "hp",
        .logic => "logic",
        .resolve => "resolve",
        .speed => "speed",
    };
    try db.conn.exec(
        "INSERT INTO scars (critter_id, stat, amount) VALUES (?1, ?2, ?3)",
        .{ critter_id, stat_str, @as(i64, amount) },
    );
}

pub fn loadCritter(db: *Db, allocator: std.mem.Allocator, id: i64) !?Critter {
    const maybe_row = try db.conn.row(
        \\SELECT id, species_id, nickname, level, xp, current_hp, max_hp,
        \\  logic, resolve, speed, move_slot_1, move_slot_2, move_slot_3, cooldown_until
        \\FROM critters WHERE id = ?1
    , .{id});

    if (maybe_row) |row| {
        defer row.deinit();
        const critter_id: u64 = @intCast(row.int(0));

        const species_id = try allocator.dupe(u8, row.text(1));
        errdefer allocator.free(species_id);

        const nickname = if (row.nullableText(2)) |n| try allocator.dupe(u8, n) else null;
        errdefer if (nickname) |n| allocator.free(n);

        const ms1 = if (row.nullableText(10)) |m| try allocator.dupe(u8, m) else null;
        errdefer if (ms1) |m| allocator.free(m);
        const ms2 = if (row.nullableText(11)) |m| try allocator.dupe(u8, m) else null;
        errdefer if (ms2) |m| allocator.free(m);
        const ms3 = if (row.nullableText(12)) |m| try allocator.dupe(u8, m) else null;
        errdefer if (ms3) |m| allocator.free(m);

        const scars = try loadScars(db, allocator, critter_id);

        return Critter{
            .id = critter_id,
            .species_id = species_id,
            .nickname = nickname,
            .level = @intCast(row.int(3)),
            .xp = @intCast(row.int(4)),
            .current_hp = @intCast(row.int(5)),
            .max_hp = @intCast(row.int(6)),
            .logic = @intCast(row.int(7)),
            .resolve = @intCast(row.int(8)),
            .speed = @intCast(row.int(9)),
            .move_slot_1 = ms1,
            .move_slot_2 = ms2,
            .move_slot_3 = ms3,
            .scars = scars,
            .cooldown_until = row.nullableInt(13),
        };
    }
    return null;
}

fn loadScars(db: *Db, allocator: std.mem.Allocator, critter_id: u64) ![]Scar {
    var scars: std.ArrayList(Scar) = .{};
    errdefer scars.deinit(allocator);

    var rows = try db.conn.rows(
        "SELECT stat, amount FROM scars WHERE critter_id = ?1",
        .{@as(i64, @intCast(critter_id))},
    );
    defer rows.deinit();

    while (rows.next()) |row| {
        const stat_str = row.text(0);
        const stat: StatKind = if (std.mem.eql(u8, stat_str, "hp"))
            .hp
        else if (std.mem.eql(u8, stat_str, "logic"))
            .logic
        else if (std.mem.eql(u8, stat_str, "resolve"))
            .resolve
        else
            .speed;

        try scars.append(allocator, .{
            .stat = stat,
            .amount = @intCast(row.int(1)),
        });
    }
    if (rows.err) |err| return err;

    return scars.toOwnedSlice(allocator);
}

pub fn loadRoster(db: *Db, allocator: std.mem.Allocator) ![]Critter {
    var critters: std.ArrayList(Critter) = .{};
    errdefer {
        for (critters.items) |*c| freeCritter(allocator, c);
        critters.deinit(allocator);
    }

    var rows = try db.conn.rows("SELECT id FROM critters ORDER BY id", .{});
    defer rows.deinit();

    var ids: std.ArrayList(i64) = .{};
    defer ids.deinit(allocator);

    while (rows.next()) |row| {
        try ids.append(allocator, row.int(0));
    }
    if (rows.err) |err| return err;

    for (ids.items) |id| {
        if (try loadCritter(db, allocator, id)) |critter| {
            try critters.append(allocator, critter);
        }
    }

    return critters.toOwnedSlice(allocator);
}

pub fn freeCritter(allocator: std.mem.Allocator, critter: *Critter) void {
    allocator.free(critter.species_id);
    if (critter.nickname) |n| allocator.free(n);
    if (critter.move_slot_1) |m| allocator.free(m);
    if (critter.move_slot_2) |m| allocator.free(m);
    if (critter.move_slot_3) |m| allocator.free(m);
    allocator.free(critter.scars);
}

pub fn freeRoster(allocator: std.mem.Allocator, roster: []Critter) void {
    for (roster) |*c| freeCritter(allocator, c);
    allocator.free(roster);
}

// --- Inventory ---

pub fn addInventoryItem(db: *Db, item_id: []const u8, quantity: i64) !void {
    try db.conn.exec(
        \\INSERT INTO inventory (item_id, quantity) VALUES (?1, ?2)
        \\ON CONFLICT(item_id) DO UPDATE SET quantity = quantity + ?2
    , .{ item_id, quantity });
}

pub const InventoryEntry = struct {
    item_id: []const u8,
    quantity: i64,
};

pub fn removeInventoryItem(database: *Db, item_id: []const u8, quantity: i64) !void {
    try database.conn.exec(
        \\UPDATE inventory SET quantity = quantity - ?2 WHERE item_id = ?1;
        \\DELETE FROM inventory WHERE item_id = ?1 AND quantity <= 0
    , .{ item_id, quantity });
}

pub fn countCritters(database: *Db) u16 {
    const maybe_row = database.conn.row("SELECT COUNT(*) FROM critters", .{}) catch return 0;
    if (maybe_row) |row| {
        defer row.deinit();
        const count = row.int(0);
        return @intCast(@min(count, 65535));
    }
    return 0;
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

test "save and load critter round-trip" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    const allocator = std.testing.allocator;

    var critter = Critter{
        .id = 0,
        .species_id = "println",
        .nickname = null,
        .level = 10,
        .xp = 250,
        .current_hp = 50,
        .max_hp = 54,
        .logic = 66,
        .resolve = 48,
        .speed = 60,
        .move_slot_1 = "log_dump",
        .move_slot_2 = null,
        .move_slot_3 = null,
        .scars = &.{},
        .cooldown_until = null,
    };

    const id = try saveCritter(&db, &critter);
    try std.testing.expect(id > 0);

    var loaded = (try loadCritter(&db, allocator, id)).?;
    defer freeCritter(allocator, &loaded);

    try std.testing.expectEqual(@as(u64, @intCast(id)), loaded.id);
    try std.testing.expect(std.mem.eql(u8, "println", loaded.species_id));
    try std.testing.expectEqual(@as(u8, 10), loaded.level);
    try std.testing.expectEqual(@as(u32, 250), loaded.xp);
    try std.testing.expectEqual(@as(u16, 50), loaded.current_hp);
    try std.testing.expectEqual(@as(u16, 54), loaded.max_hp);
    try std.testing.expectEqual(@as(u16, 66), loaded.logic);
    try std.testing.expect(std.mem.eql(u8, "log_dump", loaded.move_slot_1.?));
    try std.testing.expectEqual(@as(?[]const u8, null), loaded.move_slot_2);
    try std.testing.expectEqual(loaded.scars.len, 0);
}

test "save critter with scars" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    const allocator = std.testing.allocator;

    var critter = Critter{
        .id = 0,
        .species_id = "glitch",
        .nickname = null,
        .level = 5,
        .xp = 0,
        .current_hp = 40,
        .max_hp = 44,
        .logic = 66,
        .resolve = 38,
        .speed = 71,
        .move_slot_1 = "bit_flip",
        .move_slot_2 = null,
        .move_slot_3 = null,
        .scars = &.{},
        .cooldown_until = null,
    };

    const id = try saveCritter(&db, &critter);
    try addScar(&db, id, .logic, -1);
    try addScar(&db, id, .speed, -1);

    var loaded = (try loadCritter(&db, allocator, id)).?;
    defer freeCritter(allocator, &loaded);

    try std.testing.expectEqual(@as(usize, 2), loaded.scars.len);
    try std.testing.expectEqual(StatKind.logic, loaded.scars[0].stat);
    try std.testing.expectEqual(@as(i8, -1), loaded.scars[0].amount);
}

test "load full roster" {
    var db = try Db.openMemory();
    defer db.close();
    try db.initSchema();

    const allocator = std.testing.allocator;

    var c1 = Critter{
        .id = 0, .species_id = "println", .nickname = null,
        .level = 5, .xp = 0, .current_hp = 40, .max_hp = 40,
        .logic = 55, .resolve = 40, .speed = 50,
        .move_slot_1 = "log_dump", .move_slot_2 = null, .move_slot_3 = null,
        .scars = &.{}, .cooldown_until = null,
    };
    var c2 = Critter{
        .id = 0, .species_id = "glitch", .nickname = null,
        .level = 3, .xp = 0, .current_hp = 35, .max_hp = 35,
        .logic = 60, .resolve = 35, .speed = 65,
        .move_slot_1 = "bit_flip", .move_slot_2 = null, .move_slot_3 = null,
        .scars = &.{}, .cooldown_until = null,
    };

    _ = try saveCritter(&db, &c1);
    _ = try saveCritter(&db, &c2);

    const roster = try loadRoster(&db, allocator);
    defer freeRoster(allocator, roster);

    try std.testing.expectEqual(@as(usize, 2), roster.len);
    try std.testing.expect(std.mem.eql(u8, "println", roster[0].species_id));
    try std.testing.expect(std.mem.eql(u8, "glitch", roster[1].species_id));
}

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
