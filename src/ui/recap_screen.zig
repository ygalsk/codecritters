const vaxis = @import("vaxis");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const ScreenResult = @import("screen_result.zig").ScreenResult;
pub const RecapScreen = struct {
    dirty: bool,
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

    pub fn handleInput(self: *RecapScreen, key: vaxis.Key) ?ScreenResult {
        _ = key;
        _ = self;
        return .goto_hub;
    }

    pub fn render(self: *const RecapScreen, win: vaxis.Window) void {
        win.clear();
        const h = win.height;

        // Green border (passive rewards = positive)
        widgets.renderColorBorder(win, .{ 40, 120, 60 });

        const name = self.critter_name[0..self.critter_name_len];

        const title = "\xe2\x9c\xa8 While you were coding... \xe2\x9c\xa8";
        const start_row: u16 = if (h > 12) h / 3 else 1;
        widgets.renderCenteredText(win, start_row, title, theme.title);

        var row: u16 = start_row + 2;

        if (self.xp_awarded > 0) {
            _ = ui.writeFmt(win, 4, row, theme.xp, "{s} gained {d} XP!", .{ name, self.xp_awarded });
            row += 1;
        }

        if (self.level_after > self.level_before) {
            _ = ui.writeFmt(win, 4, row, theme.level_up, "{s} leveled up! (Lv {d} -> Lv {d})", .{ name, self.level_before, self.level_after });
            row += 1;
        }

        if (self.evolved) {
            _ = ui.writeFmt(win, 4, row, theme.level_up, "{s} evolved!", .{name});
            row += 1;
        }

        var i: u8 = 0;
        while (i < self.item_count) : (i += 1) {
            const item_name = self.items[i].name[0..self.items[i].name_len];
            _ = ui.writeFmt(win, 4, row, theme.item_found, "{s} found a {s}!", .{ name, item_name });
            row += 1;
        }

        row += 1;
        _ = ui.writeFmt(win, 4, row, theme.body_bright, "({d} coding events processed)", .{self.events_processed});

        widgets.renderHint(win, "[Press any key to continue]");
    }

};
