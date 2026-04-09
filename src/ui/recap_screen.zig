const vaxis = @import("vaxis");
const ui = @import("ui_common.zig");

pub const RecapScreen = struct {
    dirty: bool,
    done: bool,
    xp_awarded: u32,
    events_processed: u32,
    level_before: u8,
    level_after: u8,
    evolved: bool,
    items: [4]ItemDisplay,
    item_count: u8,
    critter_name: [32]u8,
    critter_name_len: u8,

    pub const ItemDisplay = struct {
        name: [32]u8,
        name_len: u8,
    };

    pub fn handleInput(self: *RecapScreen, key: vaxis.Key) void {
        _ = key;
        self.done = true;
    }

    pub fn render(self: *const RecapScreen, win: vaxis.Window) void {
        win.clear();
        const w = win.width;
        const h = win.height;

        const title_style: ui.Style = .{ .fg = .{ .rgb = .{ 80, 200, 255 } }, .bold = true };
        const text_style: ui.Style = .{ .fg = .{ .rgb = .{ 220, 220, 220 } } };
        const xp_style: ui.Style = .{ .fg = .{ .rgb = .{ 255, 200, 40 } }, .bold = true };
        const level_style: ui.Style = .{ .fg = .{ .rgb = .{ 80, 255, 120 } }, .bold = true };
        const item_style: ui.Style = .{ .fg = .{ .rgb = .{ 180, 140, 255 } } };

        const name = self.critter_name[0..self.critter_name_len];

        const title = "While you were coding...";
        const title_col: u16 = if (w > title.len) @intCast((w - title.len) / 2) else 0;
        const start_row: u16 = if (h > 12) h / 3 else 1;
        _ = ui.writeText(win, title_col, start_row, title, title_style);

        var row: u16 = start_row + 2;

        if (self.xp_awarded > 0) {
            _ = ui.writeFmt(win, 4, row, xp_style, "{s} gained {d} XP!", .{ name, self.xp_awarded });
            row += 1;
        }

        if (self.level_after > self.level_before) {
            _ = ui.writeFmt(win, 4, row, level_style, "{s} leveled up! (Lv {d} -> Lv {d})", .{ name, self.level_before, self.level_after });
            row += 1;
        }

        if (self.evolved) {
            _ = ui.writeFmt(win, 4, row, level_style, "{s} evolved!", .{name});
            row += 1;
        }

        var i: u8 = 0;
        while (i < self.item_count) : (i += 1) {
            const item_name = self.items[i].name[0..self.items[i].name_len];
            _ = ui.writeFmt(win, 4, row, item_style, "{s} found a {s}!", .{ name, item_name });
            row += 1;
        }

        row += 1;
        _ = ui.writeFmt(win, 4, row, text_style, "({d} coding events processed)", .{self.events_processed});

        const hint_row = if (h > 4) h - 2 else h;
        if (hint_row < h) {
            const hint = "[Press any key to continue]";
            const hint_col: u16 = if (w > hint.len) @intCast((w - hint.len) / 2) else 0;
            _ = ui.writeText(win, hint_col, hint_row, hint, ui.dim_style);
        }
    }
};
