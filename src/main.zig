const std = @import("std");
const vaxis = @import("vaxis");

const game_data_mod = @import("game_data");
const species_mod = @import("species");
const items_mod = @import("items");
const critter_mod = @import("critter");
const battle = @import("battle");
const db = @import("db/db.zig");
const BattleScreen = @import("ui/battle_screen.zig").BattleScreen;
const InventorySlot = @import("ui/battle_screen.zig").InventorySlot;

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    focus_in,
    focus_out,
};

pub const panic = vaxis.Panic.call;

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var gd = game_data_mod.GameData.load(alloc) catch |err| {
        std.debug.print("Failed to load game data: {}\n", .{err});
        return err;
    };
    defer gd.deinit();

    var database = db.Db.open("codecritter.db") catch |err| {
        std.debug.print("Failed to open database: {}\n", .{err});
        return err;
    };
    defer database.close();
    try database.initSchema();

    // Setup test battle
    const player_sp = gd.findSpecies("println") orelse return error.MissingSpecies;
    const partner_sp = gd.findSpecies("goto") orelse return error.MissingSpecies;
    const wild_sp = gd.findSpecies("glitch") orelse return error.MissingSpecies;

    const player_critter = critter_mod.Critter.createFromSpecies(player_sp, 10);
    const partner_critter = critter_mod.Critter.createFromSpecies(partner_sp, 10);
    const wild_critter = critter_mod.Critter.createFromSpecies(wild_sp, 8);

    const player_critters = [_]critter_mod.Critter{ player_critter, partner_critter };
    const player_species = [_]*const species_mod.Species{ player_sp, partner_sp };

    const seed: u64 = @intCast(std.time.milliTimestamp());
    var battle_state = battle.initBattle(&player_critters, &player_species, wild_critter, wild_sp, seed);

    // Setup test inventory
    const print_stmt = gd.findItem("print_statement") orelse return error.MissingItem;
    const hotfix = gd.findItem("hotfix") orelse return error.MissingItem;
    var inventory = [_]InventorySlot{
        .{ .item = print_stmt, .count = 3 },
        .{ .item = hotfix, .count = 2 },
    };

    var screen = BattleScreen.init(&battle_state, &gd, &inventory);

    // TUI setup
    var tty_buf: [4096]u8 = undefined;
    var tty = try vaxis.Tty.init(&tty_buf);
    defer tty.deinit();

    const writer = tty.writer();

    var vx = try vaxis.init(alloc, .{});
    defer vx.deinit(alloc, writer);

    var loop: vaxis.Loop(Event) = .{ .vaxis = &vx, .tty = &tty };
    try loop.init();
    try loop.start();
    defer loop.stop();

    try vx.enterAltScreen(writer);
    try vx.queryTerminal(writer, 1 * std.time.ns_per_s);

    while (true) {
        const event = loop.nextEvent();
        switch (event) {
            .key_press => |key| {
                if (key.matches('q', .{}) or key.matches('c', .{ .ctrl = true })) {
                    break;
                }
                screen.handleInput(key);
                if (screen.done) break;
            },
            .winsize => |ws| try vx.resize(alloc, writer, ws),
            else => {},
        }

        const win = vx.window();
        screen.render(win);

        try vx.render(writer);
        try writer.flush();
    }
}
