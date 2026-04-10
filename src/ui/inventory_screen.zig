const std = @import("std");
const vaxis = @import("vaxis");
const items_mod = @import("items");
const game_data_mod = @import("game_data");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const input = @import("input.zig");

const Window = ui.Window;
const writeText = ui.writeText;
const writeFmt = ui.writeFmt;

pub const InventoryEntry = struct {
    item_id: []const u8,
    quantity: i64,
};

pub const InventoryScreen = struct {
    entries: []const InventoryEntry,
    game_data: *const game_data_mod.GameData,
    currency: u32,
    cursor: u8,
    total_count: u8,
    done: bool,
    dirty: bool,

    pub fn init(
        entries: []const InventoryEntry,
        game_data: *const game_data_mod.GameData,
        currency: u32,
    ) InventoryScreen {
        var count: u8 = 0;
        for (entries) |entry| {
            if (game_data.findItem(entry.item_id) != null) count += 1;
        }
        return .{
            .entries = entries,
            .game_data = game_data,
            .currency = currency,
            .cursor = 0,
            .total_count = count,
            .done = false,
            .dirty = true,
        };
    }

    pub fn handleInput(self: *InventoryScreen, key: vaxis.Key) void {
        self.dirty = true;
        const action = input.applyCursor(&self.cursor, self.total_count, input.menuNav(key));
        if (action == .back) {
            self.done = true;
        }
    }

    pub fn render(self: *const InventoryScreen, win: Window) void {
        win.clear();
        if (layout.tooSmall(win, 30, 10)) return;

        // Title
        _ = writeText(win, 2, 1, "Inventory", theme.title);
        _ = writeFmt(win, 14, 1, theme.currency, "  ${d}", .{self.currency});

        var row: u16 = 3;
        var display_idx: u8 = 0;

        // Catch Tools
        if (self.hasCategoryItems(.catch_tool)) {
            _ = writeText(win, 2, row, "Catch Tools", theme.category);
            row += 1;
            row = self.renderCategory(win, row, .catch_tool, &display_idx);
            row += 1;
        }

        // Healing Items
        if (self.hasCategoryItems(.healing)) {
            _ = writeText(win, 2, row, "Healing Items", theme.category);
            row += 1;
            row = self.renderCategory(win, row, .healing, &display_idx);
            row += 1;
        }

        // Move Discs
        if (self.hasCategoryItems(.move_disc)) {
            _ = writeText(win, 2, row, "Move Discs", theme.category);
            row += 1;
            row = self.renderCategory(win, row, .move_disc, &display_idx);
            row += 1;
        }

        if (display_idx == 0) {
            _ = writeText(win, 2, row, "(empty)", .{ .fg = theme.muted, .italic = true });
        }

        // Controls hint
        widgets.renderHintAt(win, 2, "[Up/Down] Navigate  [Esc] Back");
    }

    fn renderCategory(self: *const InventoryScreen, win: Window, start_row: u16, kind: items_mod.ItemKind, display_idx: *u8) u16 {
        var row = start_row;
        for (self.entries) |entry| {
            const item = self.game_data.findItem(entry.item_id) orelse continue;
            if (item.kind != kind) continue;

            const is_sel = self.cursor == display_idx.*;
            const style: theme.Style = if (is_sel) theme.selected else theme.unselected;

            const prefix: []const u8 = if (is_sel) "> " else "  ";
            var c = writeText(win, 2, row, prefix, style);
            c = writeText(win, c, row, item.name, style);
            c = writeFmt(win, c, row, style, "  x{d}", .{entry.quantity});

            // Show extra info for catch tools
            if (kind == .catch_tool) {
                if (item.base_catch_rate) |rate| {
                    _ = writeFmt(win, c, row, .{ .fg = theme.info_gray }, "  ({d}%)", .{rate});
                }
            } else if (kind == .healing) {
                if (item.heal_amount) |heal| {
                    _ = writeFmt(win, c, row, .{ .fg = theme.info_gray }, "  (+{d} HP)", .{heal});
                }
            }

            row += 1;
            display_idx.* += 1;
        }
        return row;
    }

    fn hasCategoryItems(self: *const InventoryScreen, kind: items_mod.ItemKind) bool {
        for (self.entries) |entry| {
            const item = self.game_data.findItem(entry.item_id) orelse continue;
            if (item.kind == kind) return true;
        }
        return false;
    }
};
