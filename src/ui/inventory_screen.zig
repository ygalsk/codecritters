const std = @import("std");
const vaxis = @import("vaxis");
const items_mod = @import("items");
const game_data_mod = @import("game_data");
const ui = @import("ui_common.zig");

const Window = ui.Window;
const Style = ui.Style;
const Key = ui.Key;
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
        if (key.matches(Key.escape, .{}) or key.matches(Key.backspace, .{})) {
            self.done = true;
            return;
        }
        const total = self.total_count;
        if (key.matches(Key.up, .{})) {
            if (self.cursor > 0) self.cursor -= 1;
        } else if (key.matches(Key.down, .{})) {
            if (self.cursor + 1 < total) self.cursor += 1;
        }
    }

    pub fn render(self: *const InventoryScreen, win: Window) void {
        win.clear();
        const w = win.width;
        const h = win.height;
        if (w < 30 or h < 10) {
            _ = writeText(win, 0, 0, "Terminal too small", .{ .fg = .{ .rgb = .{ 255, 60, 60 } } });
            return;
        }

        const header_style: Style = .{ .fg = .{ .rgb = .{ 80, 200, 255 } }, .bold = true };
        const category_style: Style = .{ .fg = .{ .rgb = .{ 255, 200, 80 } }, .bold = true };
        const dim_style: Style = .{ .fg = .{ .rgb = .{ 100, 100, 100 } } };

        // Title
        _ = writeText(win, 2, 1, "Inventory", header_style);
        _ = writeFmt(win, 14, 1, .{ .fg = .{ .rgb = .{ 180, 180, 100 } } }, "  ${d}", .{self.currency});

        var row: u16 = 3;
        var display_idx: u8 = 0;

        // Catch Tools
        if (self.hasCategoryItems(.catch_tool)) {
            _ = writeText(win, 2, row, "Catch Tools", category_style);
            row += 1;
            row = self.renderCategory(win, row, .catch_tool, &display_idx);
            row += 1;
        }

        // Healing Items
        if (self.hasCategoryItems(.healing)) {
            _ = writeText(win, 2, row, "Healing Items", category_style);
            row += 1;
            row = self.renderCategory(win, row, .healing, &display_idx);
            row += 1;
        }

        // Move Discs
        if (self.hasCategoryItems(.move_disc)) {
            _ = writeText(win, 2, row, "Move Discs", category_style);
            row += 1;
            row = self.renderCategory(win, row, .move_disc, &display_idx);
            row += 1;
        }

        if (display_idx == 0) {
            _ = writeText(win, 2, row, "(empty)", .{ .fg = .{ .rgb = .{ 140, 140, 160 } }, .italic = true });
        }

        // Controls hint
        const hint = "[Up/Down] Navigate  [Esc] Back";
        const hint_row: u16 = if (h > 2) h - 2 else h;
        if (hint_row < h) {
            _ = writeText(win, 2, hint_row, hint, dim_style);
        }
    }

    fn renderCategory(self: *const InventoryScreen, win: Window, start_row: u16, kind: items_mod.ItemKind, display_idx: *u8) u16 {
        var row = start_row;
        for (self.entries) |entry| {
            const item = self.game_data.findItem(entry.item_id) orelse continue;
            if (item.kind != kind) continue;

            const selected = self.cursor == display_idx.*;
            const style: Style = if (selected)
                .{ .fg = .{ .rgb = .{ 0, 0, 0 } }, .bg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true }
            else
                .{ .fg = .{ .rgb = .{ 200, 200, 200 } } };

            const prefix: []const u8 = if (selected) "> " else "  ";
            var c = writeText(win, 2, row, prefix, style);
            c = writeText(win, c, row, item.name, style);
            c = writeFmt(win, c, row, style, "  x{d}", .{entry.quantity});

            // Show extra info for catch tools
            if (kind == .catch_tool) {
                if (item.base_catch_rate) |rate| {
                    _ = writeFmt(win, c, row, .{ .fg = .{ .rgb = .{ 120, 120, 140 } } }, "  ({d}%)", .{rate});
                }
            } else if (kind == .healing) {
                if (item.heal_amount) |heal| {
                    _ = writeFmt(win, c, row, .{ .fg = .{ .rgb = .{ 120, 120, 140 } } }, "  (+{d} HP)", .{heal});
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
