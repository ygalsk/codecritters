const std = @import("std");
const vaxis = @import("vaxis");

const game_data = @import("data/game_data.zig");
const db = @import("db/db.zig");

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

    var gd = game_data.GameData.load(alloc) catch |err| {
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

    var status_buf: [128]u8 = undefined;
    const status = std.fmt.bufPrint(&status_buf, "Codecritter v0.1.0 | {d} species, {d} moves, {d} items loaded", .{
        gd.species().len,
        gd.moves().len,
        gd.items().len,
    }) catch "Codecritter v0.1.0";

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
            },
            .winsize => |ws| try vx.resize(alloc, writer, ws),
            else => {},
        }

        const win = vx.window();
        win.clear();

        const row: u16 = win.height / 2;
        _ = win.printSegment(.{ .text = status, .style = .{ .fg = .{ .rgb = .{ 0, 200, 120 } }, .bold = true } }, .{ .col_offset = centerCol(win.width, status.len), .row_offset = row });

        const hint = "Press q to quit";
        _ = win.printSegment(.{ .text = hint, .style = .{ .fg = .{ .rgb = .{ 100, 100, 100 } } } }, .{ .col_offset = centerCol(win.width, hint.len), .row_offset = row + 2 });

        try vx.render(writer);
        try writer.flush();
    }
}

fn centerCol(win_width: u16, text_len: usize) u16 {
    return if (win_width > text_len) (win_width - @as(u16, @intCast(text_len))) / 2 else 0;
}
