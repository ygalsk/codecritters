// CLI subcommand handlers — independent of the TUI game loop.

const std = @import("std");
const game_data_mod = @import("game_data");
const critter_mod = @import("critter");
const leveling = @import("leveling");
const db = @import("db/db.zig");
const roster_db = @import("db/roster.zig");
const passive_store = @import("db/passive_store.zig");
const run_store = @import("db/run_store.zig");
const sprite_mod = @import("ui/sprite.zig");

var sprite_path_buf: [64]u8 = undefined;

fn spritePath(id: []const u8) ?[]const u8 {
    return std.fmt.bufPrint(&sprite_path_buf, "assets/sprites/{s}.png", .{id}) catch null;
}

fn writeOut(comptime fmt: []const u8, args: anytype) void {
    var buf: [2048]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, fmt, args) catch return;
    std.fs.File.stdout().writeAll(str) catch {};
}

pub fn openDb() ?db.Db {
    var database = db.Db.open("codecritter.db") catch |err| {
        std.debug.print("Failed to open database: {}\n", .{err});
        return null;
    };
    database.initSchema() catch {
        database.close();
        return null;
    };
    return database;
}

pub fn printUsage() void {
    std.fs.File.stdout().writeAll(
        \\Usage: codecritter [command]
        \\
        \\Commands:
        \\  (no args)              Launch the game
        \\  log-event <type>       Log a coding event (bash, edit, write, etc.)
        \\  set-favorite <id>      Set which critter earns passive XP
        \\  status                 Output detailed favorite critter + game state as JSON
        \\  roster                 Output full roster as JSON array
        \\  statusline             Output critter sprite + info for terminal statusline
        \\
    ) catch {};
}

pub fn handleLogEvent(event_type: []const u8) void {
    var database = openDb() orelse return;
    defer database.close();

    passive_store.logEvent(&database, event_type) catch |err| {
        std.debug.print("Failed to log event: {}\n", .{err});
    };
}

pub fn handleSetFavorite(alloc: std.mem.Allocator, id_str: []const u8) void {
    const critter_id = std.fmt.parseInt(i64, id_str, 10) catch {
        std.debug.print("Invalid critter ID: {s}\n", .{id_str});
        return;
    };
    var database = openDb() orelse return;
    defer database.close();

    if (roster_db.loadCritter(&database, alloc, critter_id) catch null) |critter| {
        var c = critter;
        roster_db.freeCritter(alloc, &c);
    } else {
        std.debug.print("No critter with ID {d}\n", .{critter_id});
        return;
    }

    passive_store.setFavoriteCritterId(&database, critter_id) catch |err| {
        std.debug.print("Failed to set favorite: {}\n", .{err});
        return;
    };

    writeOut("Favorite critter set to ID {d}\n", .{critter_id});
}

pub fn handleStatus(alloc: std.mem.Allocator) void {
    var database = openDb() orelse return;
    defer database.close();

    var gd = game_data_mod.GameData.load(alloc) catch |err| {
        std.debug.print("Failed to load game data: {}\n", .{err});
        return;
    };
    defer gd.deinit();

    const fav_id = passive_store.getFavoriteCritterId(&database) orelse getFirstCritterId(&database);
    const pending = passive_store.countUnprocessedEvents(&database);
    const roster_count = roster_db.countCritters(&database);
    const on_cooldown = countCooldowns(&database);
    const currency = roster_db.getCurrency(&database);

    var out: std.ArrayList(u8) = .{};
    defer out.deinit(alloc);
    const w = out.writer(alloc);

    w.writeAll("{\"favorite\":") catch return;
    if (fav_id) |id| {
        if (roster_db.loadCritter(&database, alloc, id) catch null) |critter| {
            var c = critter;
            defer roster_db.freeCritter(alloc, &c);
            writeCritterJson(w, &c, &gd);
        } else {
            w.writeAll("null") catch return;
        }
    } else {
        w.writeAll("null") catch return;
    }

    w.print(",\"roster\":{{\"count\":{d},\"on_cooldown\":{d}}}", .{ roster_count, on_cooldown }) catch return;
    w.print(",\"currency\":{d}", .{currency}) catch return;

    // Active run info
    if (run_store.findActiveRun(&database) catch null) |run_id| {
        if (run_store.loadRun(&database, alloc, run_id) catch null) |record| {
            var rec = record;
            defer run_store.freeRunRecord(alloc, &rec);
            w.print(",\"active_run\":{{\"biome\":\"{s}\",\"floor\":{d},\"currency\":{d}}}", .{ rec.biome_id, rec.floor_number, rec.currency }) catch return;
        } else {
            w.writeAll(",\"active_run\":null") catch return;
        }
    } else {
        w.writeAll(",\"active_run\":null") catch return;
    }

    w.print(",\"pending_events\":{d}}}\n", .{pending}) catch return;

    std.fs.File.stdout().writeAll(out.items) catch {};
}

pub fn handleRoster(alloc: std.mem.Allocator) void {
    var database = openDb() orelse return;
    defer database.close();

    var gd = game_data_mod.GameData.load(alloc) catch |err| {
        std.debug.print("Failed to load game data: {}\n", .{err});
        return;
    };
    defer gd.deinit();

    const roster = roster_db.loadRoster(&database, alloc) catch |err| {
        std.debug.print("Failed to load roster: {}\n", .{err});
        return;
    };
    defer roster_db.freeRoster(alloc, roster);

    var out: std.ArrayList(u8) = .{};
    defer out.deinit(alloc);
    const w = out.writer(alloc);

    w.writeAll("[") catch return;
    for (roster, 0..) |*c, i| {
        if (i > 0) w.writeAll(",") catch return;
        writeCritterJson(w, c, &gd);
    }
    w.writeAll("]\n") catch return;

    std.fs.File.stdout().writeAll(out.items) catch {};
}

pub fn handleStatusline(alloc: std.mem.Allocator) void {
    var database = openDb() orelse return;
    defer database.close();

    var gd = game_data_mod.GameData.load(alloc) catch return;
    defer gd.deinit();

    const fav_id = passive_store.getFavoriteCritterId(&database) orelse getFirstCritterId(&database);
    const stdout = std.fs.File.stdout();

    const id = fav_id orelse {
        stdout.writeAll("No critters yet\n") catch {};
        return;
    };
    const critter = roster_db.loadCritter(&database, alloc, id) catch null orelse {
        stdout.writeAll("No critters yet\n") catch {};
        return;
    };
    var c = critter;
    defer roster_db.freeCritter(alloc, &c);
    const sp_name = if (gd.findSpecies(c.species_id)) |sp| sp.name else c.species_id;

    if (renderSpriteStatusline(alloc, &c, sp_name, stdout)) return;

    // Fallback: plain text
    writeOut("{s} Lv{d} \xe2\x99\xa5{d}/{d}\n", .{ sp_name, c.level, c.current_hp, c.max_hp });
}

fn renderSpriteStatusline(alloc: std.mem.Allocator, c: *const critter_mod.Critter, sp_name: []const u8, stdout: std.fs.File) bool {
    const path = spritePath(c.species_id) orelse return false;
    var sheet = sprite_mod.SpriteSheet.loadFromFile(alloc, path) catch return false;
    defer sheet.deinit();
    const ansi = sheet.renderToAnsi(alloc, 0) catch return false;
    defer alloc.free(ansi);

    var info_buf: [128]u8 = undefined;
    const info = std.fmt.bufPrint(&info_buf, " {s} Lv{d} \xe2\x99\xa5{d}/{d}", .{ sp_name, c.level, c.current_hp, c.max_hp }) catch "";
    const info_row = sheet.height / 2 / 2; // middle row
    var row: u32 = 0;
    var pos: usize = 0;
    while (pos < ansi.len) {
        const nl = std.mem.indexOfScalar(u8, ansi[pos..], '\n') orelse (ansi.len - pos);
        stdout.writeAll(ansi[pos .. pos + nl]) catch {};
        if (row == info_row) stdout.writeAll(info) catch {};
        stdout.writeAll("\n") catch {};
        pos += nl + 1;
        row += 1;
    }
    return true;
}

fn writeCritterJson(w: anytype, c: *const critter_mod.Critter, gd: *const game_data_mod.GameData) void {
    const sp = gd.findSpecies(c.species_id);
    const sp_name = if (sp) |s| s.name else c.species_id;
    const type_name = if (sp) |s| s.critter_type.displayName() else "unknown";
    const next_level_xp = leveling.xpForLevel(c.level + 1);

    w.print("{{\"id\":{d},\"species\":\"{s}\",\"name\":\"{s}\",\"type\":\"{s}\"", .{ c.id, c.species_id, sp_name, type_name }) catch return;
    w.print(",\"level\":{d},\"xp\":{d},\"xp_next\":{d}", .{ c.level, c.xp, next_level_xp }) catch return;
    w.print(",\"hp\":{d},\"max_hp\":{d}", .{ c.current_hp, c.effectiveStat(.hp) }) catch return;
    w.print(",\"stats\":{{\"logic\":{{\"base\":{d},\"effective\":{d}}}", .{ c.logic, c.effectiveStat(.logic) }) catch return;
    w.print(",\"resolve\":{{\"base\":{d},\"effective\":{d}}}", .{ c.resolve, c.effectiveStat(.resolve) }) catch return;
    w.print(",\"speed\":{{\"base\":{d},\"effective\":{d}}}}}", .{ c.speed, c.effectiveStat(.speed) }) catch return;

    // Moves
    w.writeAll(",\"moves\":[") catch return;
    const move_slots = [_]?[]const u8{ c.move_slot_1, c.move_slot_2, c.move_slot_3 };
    for (move_slots, 0..) |slot, i| {
        if (i > 0) w.writeAll(",") catch return;
        if (slot) |move_id| {
            if (gd.findMove(move_id)) |m| {
                w.print("{{\"id\":\"{s}\",\"name\":\"{s}\",\"type\":\"{s}\",\"power\":{d},\"accuracy\":{d}}}", .{
                    m.id, m.name, m.move_type.displayName(), m.power, m.accuracy,
                }) catch return;
            } else {
                w.print("{{\"id\":\"{s}\"}}", .{move_id}) catch return;
            }
        } else {
            w.writeAll("null") catch return;
        }
    }
    w.writeAll("]") catch return;

    // Scars
    w.writeAll(",\"scars\":[") catch return;
    for (c.scars, 0..) |scar, i| {
        if (i > 0) w.writeAll(",") catch return;
        w.print("{{\"stat\":\"{s}\",\"amount\":{d}}}", .{ scar.stat.displayName(), scar.amount }) catch return;
    }
    w.writeAll("]") catch return;

    w.print(",\"cooldown_runs\":{d}}}", .{c.cooldown_runs}) catch return;
}

pub const countCooldowns = roster_db.countCooldowns;
pub const getFirstCritterId = roster_db.getFirstCritterId;
