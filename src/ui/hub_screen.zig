const std = @import("std");
const vaxis = @import("vaxis");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const input = @import("input.zig");

pub const HubChoice = enum {
    new_run,
    view_roster,
    view_inventory,
    quit,
};

pub const HubScreen = struct {
    cursor: u8,
    selection: ?HubChoice,
    done: bool,
    dirty: bool,
    roster_count: u16,
    currency: u32,

    const menu_items = [_]widgets.MenuItem{
        .{ .label = "New Run" },
        .{ .label = "View Roster" },
        .{ .label = "Inventory" },
        .{ .label = "Quit" },
    };

    pub fn init(roster_count: u16, currency: u32) HubScreen {
        return .{
            .cursor = 0,
            .selection = null,
            .done = false,
            .dirty = true,
            .roster_count = roster_count,
            .currency = currency,
        };
    }

    pub fn handleInput(self: *HubScreen, key: vaxis.Key) void {
        self.dirty = true;
        const action = input.applyCursor(&self.cursor, menu_items.len, input.menuNav(key));
        if (action == .confirm) {
            self.selection = switch (self.cursor) {
                0 => .new_run,
                1 => .view_roster,
                2 => .view_inventory,
                3 => .quit,
                else => null,
            };
            if (self.selection != null) self.done = true;
        }
    }

    pub fn render(self: *const HubScreen, win: vaxis.Window) void {
        win.clear();
        if (layout.tooSmall(win, 30, 15)) return;

        const h = win.height;

        // Title
        const title = "CODECRITTER";
        var title_row: u16 = h / 4;
        widgets.renderCenteredText(win, title_row, title, theme.title);

        const subtitle = "A Roguelike for Your Terminal";
        widgets.renderCenteredText(win, title_row + 1, subtitle, .{ .fg = theme.muted });

        // Roster count + currency
        title_row += 3;
        var roster_buf: [64]u8 = undefined;
        const roster_str = std.fmt.bufPrint(&roster_buf, "Roster: {d} critter{s}  |  ${d}", .{
            self.roster_count,
            if (self.roster_count != 1) "s" else "",
            self.currency,
        }) catch "Roster: ?";
        widgets.renderCenteredText(win, title_row, roster_str, theme.currency);

        // Menu
        const menu_start_row = title_row + 2;
        widgets.renderMenuCentered(win, &menu_items, self.cursor, menu_start_row);

        // Controls hint
        widgets.renderHint(win, "[Up/Down] Navigate  [Enter] Select");
    }
};
