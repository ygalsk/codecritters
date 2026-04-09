const vaxis = @import("vaxis");
const ui = @import("ui_common.zig");

pub const HubChoice = enum {
    new_run,
    view_roster,
    quit,
};

pub const HubScreen = struct {
    cursor: u8,
    selection: ?HubChoice,
    done: bool,
    dirty: bool,
    roster_count: u16,

    const menu_items = [_][]const u8{
        "New Run",
        "View Roster",
        "Quit",
    };

    pub fn init(roster_count: u16) HubScreen {
        return .{
            .cursor = 0,
            .selection = null,
            .done = false,
            .dirty = true,
            .roster_count = roster_count,
        };
    }

    pub fn handleInput(self: *HubScreen, key: vaxis.Key) void {
        self.dirty = true;
        if (key.matches(vaxis.Key.up, .{})) {
            if (self.cursor > 0) self.cursor -= 1;
        } else if (key.matches(vaxis.Key.down, .{})) {
            if (self.cursor + 1 < menu_items.len) self.cursor += 1;
        } else if (key.matches(vaxis.Key.enter, .{}) or key.matches(' ', .{})) {
            self.selection = switch (self.cursor) {
                0 => .new_run,
                1 => .view_roster,
                2 => .quit,
                else => null,
            };
            if (self.selection != null) self.done = true;
        }
    }

    pub fn render(self: *const HubScreen, win: vaxis.Window) void {
        win.clear();
        const w = win.width;
        const h = win.height;
        if (w < 30 or h < 15) {
            _ = ui.writeText(win, 0, 0, "Terminal too small", .{ .fg = .{ .rgb = .{ 255, 60, 60 } } });
            return;
        }

        // Title
        const title = "CODECRITTER";
        const title_col: u16 = if (w > title.len) @intCast((w - title.len) / 2) else 0;
        const title_row: u16 = h / 4;
        _ = ui.writeText(win, title_col, title_row, title, .{
            .fg = .{ .rgb = .{ 80, 200, 255 } },
            .bold = true,
        });

        const subtitle = "A Roguelike for Your Terminal";
        const sub_col: u16 = if (w > subtitle.len) @intCast((w - subtitle.len) / 2) else 0;
        _ = ui.writeText(win, sub_col, title_row + 1, subtitle, .{
            .fg = .{ .rgb = .{ 140, 140, 160 } },
        });

        // Roster count
        var roster_buf: [32]u8 = undefined;
        const roster_str = std.fmt.bufPrint(&roster_buf, "Roster: {d} critter{s}", .{
            self.roster_count,
            if (self.roster_count != 1) "s" else "",
        }) catch "Roster: ?";
        const roster_col: u16 = if (w > roster_str.len) @intCast((w - roster_str.len) / 2) else 0;
        _ = ui.writeText(win, roster_col, title_row + 3, roster_str, .{
            .fg = .{ .rgb = .{ 180, 180, 100 } },
        });

        // Menu
        const menu_start_row = title_row + 5;
        for (menu_items, 0..) |item, i| {
            const row: u16 = menu_start_row + @as(u16, @intCast(i));
            const is_selected = self.cursor == @as(u8, @intCast(i));
            const prefix: []const u8 = if (is_selected) "> " else "  ";
            const style: ui.Style = if (is_selected)
                .{ .fg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true }
            else
                .{ .fg = .{ .rgb = .{ 160, 160, 160 } } };

            const total_len = prefix.len + item.len;
            const col: u16 = if (w > total_len) @intCast((w - total_len) / 2) else 0;
            const c = ui.writeText(win, col, row, prefix, style);
            _ = ui.writeText(win, c, row, item, style);
        }

        // Controls hint
        const hint = "[Up/Down] Navigate  [Enter] Select";
        const hint_col: u16 = if (w > hint.len) @intCast((w - hint.len) / 2) else 0;
        const hint_row: u16 = if (h > 2) h - 2 else h;
        if (hint_row < h) {
            _ = ui.writeText(win, hint_col, hint_row, hint, ui.dim_style);
        }
    }
};

const std = @import("std");
