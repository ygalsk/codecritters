const std = @import("std");
const vaxis = @import("vaxis");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const input = @import("input.zig");
const ScreenResult = @import("screen_result.zig").ScreenResult;
const meta_upgrades = @import("meta_upgrades.zig");
const Window = ui.Window;
const writeText = ui.writeText;
const writeFmt = ui.writeFmt;

pub const MetaShopScreen = struct {
    cursor: u8,
    dirty: bool,
    currency: u32,
    upgrade_levels: [meta_upgrades.UPGRADE_COUNT]u8,
    log: ui.MessageLog,

    pub fn init(currency: u32, upgrade_levels: [meta_upgrades.UPGRADE_COUNT]u8) MetaShopScreen {
        var screen = MetaShopScreen{
            .cursor = 0,
            .dirty = true,
            .currency = currency,
            .upgrade_levels = upgrade_levels,
            .log = ui.MessageLog.init(),
        };
        screen.log.push("Welcome to the Meta Shop!");
        return screen;
    }

    pub fn handleInput(self: *MetaShopScreen, key: vaxis.Key) ?ScreenResult {
        self.dirty = true;

        const action = input.applyCursor(&self.cursor, meta_upgrades.UPGRADE_COUNT, input.menuNav(key));
        if (action == .confirm) {
            return self.tryPurchase();
        } else if (action == .back) {
            return .goto_hub;
        }
        return null;
    }

    fn tryPurchase(self: *MetaShopScreen) ?ScreenResult {
        const upgrade = &meta_upgrades.all_upgrades[self.cursor];
        const level = self.upgrade_levels[self.cursor];
        const maybe_cost = meta_upgrades.costForNextLevel(upgrade, level);

        if (maybe_cost) |cost| {
            if (self.currency < cost) {
                self.log.push("Not enough currency!");
                return null;
            }
            return .{ .persist_meta_purchase = .{ .upgrade_index = self.cursor } };
        } else {
            self.log.push("Already maxed!");
            return null;
        }
    }

    /// Called by main loop after a successful purchase to update local state.
    pub fn applyPurchase(self: *MetaShopScreen, upgrade_index: u8, cost: u32) void {
        self.currency -= cost;
        self.upgrade_levels[upgrade_index] += 1;
        self.dirty = true;

        const upgrade = &meta_upgrades.all_upgrades[upgrade_index];
        var buf: [ui.MSG_BUF_LEN]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Purchased {s} Lv{d}!", .{ upgrade.name, self.upgrade_levels[upgrade_index] }) catch "Purchased!";
        self.log.push(msg);
    }

    /// Called by main loop when a purchase fails.
    pub fn applyPurchaseFailed(self: *MetaShopScreen) void {
        self.log.push("Purchase failed!");
        self.dirty = true;
    }

    pub fn render(self: *const MetaShopScreen, win: Window) void {
        win.clear();
        if (layout.tooSmall(win, 40, 14)) return;

        const time_ms = std.time.milliTimestamp();

        widgets.renderColorBorder(win, .{ 40, 60, 50 });
        widgets.renderDancingTitle(win, "META SHOP", 1, .{ 180, 140, 255 }, time_ms);

        _ = writeFmt(win, 3, 3, theme.currency_bold, "Currency: ${d}", .{self.currency});
        widgets.renderThinSeparator(win, 4, .{ 40, 60, 50 });

        // Upgrade list
        var row: u16 = 5;
        for (meta_upgrades.all_upgrades, 0..) |upgrade, i| {
            if (row + 2 >= win.height) break;
            const idx: u8 = @intCast(i);
            const level = self.upgrade_levels[idx];
            const is_sel = self.cursor == idx;
            const maxed = level >= upgrade.max_level;

            const prefix: []const u8 = if (is_sel) "> " else "  ";
            const name_style = if (is_sel) theme.selected else if (maxed) theme.dim else theme.unselected;
            var c = writeText(win, 2, row, prefix, name_style);
            c = writeText(win, c, row, upgrade.name, name_style);

            if (maxed) {
                _ = writeFmt(win, c, row, if (is_sel) theme.selected else theme.dim, "  [MAX]", .{});
            } else {
                const cost = meta_upgrades.costForNextLevel(&upgrade, level).?;
                _ = writeFmt(win, c, row, if (is_sel) theme.selected else theme.currency, "  Lv{d}/{d}  ${d}", .{ level, upgrade.max_level, cost });
            }

            row += 1;
            if (row < win.height) {
                _ = writeFmt(win, 6, row, theme.dim, "{s}", .{upgrade.description});
            }
            row += 1;
        }

        row += 1;
        if (row < win.height) {
            self.log.render(win, row, 2);
        }

        widgets.renderHint(win, "[Up/Down] Navigate  [Enter] Buy  [Esc] Back");
    }
};
