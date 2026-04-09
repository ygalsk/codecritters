const std = @import("std");
const vaxis = @import("vaxis");

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

        const title = "Codecritter v0.0.0 — Press q to quit";
        const col: u16 = if (win.width > title.len) (win.width - @as(u16, @intCast(title.len))) / 2 else 0;
        const row: u16 = win.height / 2;
        _ = win.printSegment(.{ .text = title, .style = .{ .fg = .{ .rgb = .{ 0, 200, 120 } }, .bold = true } }, .{ .col_offset = col, .row_offset = row });

        try vx.render(writer);
        try writer.flush();
    }
}
