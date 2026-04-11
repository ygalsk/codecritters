const std = @import("std");
const vaxis = @import("vaxis");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const input = @import("input.zig");
const ScreenResult = @import("screen_result.zig").ScreenResult;
const game_data_mod = @import("game_data");
const species_mod = @import("species");
const roster_db = @import("../db/roster.zig");
const db_mod = @import("../db/db.zig");

const Window = ui.Window;
const writeText = ui.writeText;
const writeFmt = ui.writeFmt;

pub const CodexScreen = struct {
    cursor: u16,
    dirty: bool,
    scroll_offset: u16,
    species_count: u16,
    discovered_count: u16,
    game_data: *const game_data_mod.GameData,
    discovered: [MAX_SPECIES]bool,

    const MAX_SPECIES = 128;
    const VISIBLE_ROWS = 16;

    pub fn init(
        game_data: *const game_data_mod.GameData,
        database: *db_mod.Db,
    ) CodexScreen {
        const all = game_data.species();
        var discovered_flags: [MAX_SPECIES]bool = .{false} ** MAX_SPECIES;
        var discovered: u16 = 0;
        for (all, 0..) |sp, i| {
            if (i >= MAX_SPECIES) break;
            if (roster_db.isSpeciesDiscovered(database, sp.id)) {
                discovered_flags[i] = true;
                discovered += 1;
            }
        }
        return .{
            .cursor = 0,
            .dirty = true,
            .scroll_offset = 0,
            .species_count = @intCast(@min(all.len, MAX_SPECIES)),
            .discovered_count = discovered,
            .game_data = game_data,
            .discovered = discovered_flags,
        };
    }

    pub fn handleInput(self: *CodexScreen, key: vaxis.Key) ?ScreenResult {
        self.dirty = true;

        const nav = input.menuNav(key);
        switch (nav) {
            .up => {
                if (self.cursor > 0) self.cursor -= 1;
                self.adjustScroll();
            },
            .down => {
                if (self.cursor + 1 < self.species_count) self.cursor += 1;
                self.adjustScroll();
            },
            .back => return .goto_hub,
            else => {},
        }
        return null;
    }

    fn adjustScroll(self: *CodexScreen) void {
        if (self.cursor < self.scroll_offset) {
            self.scroll_offset = self.cursor;
        } else if (self.cursor >= self.scroll_offset + VISIBLE_ROWS) {
            self.scroll_offset = self.cursor - VISIBLE_ROWS + 1;
        }
    }

    pub fn render(self: *const CodexScreen, win: Window) void {
        win.clear();
        if (layout.tooSmall(win, 40, 12)) return;

        const time_ms = std.time.milliTimestamp();

        widgets.renderColorBorder(win, .{ 50, 60, 40 });
        widgets.renderDancingTitle(win, "SPECIES CODEX", 1, .{ 100, 220, 160 }, time_ms);

        _ = writeFmt(win, 3, 3, theme.currency_bold, "Discovered: {d}/{d}", .{ self.discovered_count, self.species_count });
        widgets.renderThinSeparator(win, 4, .{ 50, 60, 40 });

        const all = self.game_data.species();
        const max_visible = @min(VISIBLE_ROWS, win.height -| 8);
        var row: u16 = 5;
        var idx: u16 = self.scroll_offset;
        while (idx < self.species_count and row < 5 + max_visible) : (idx += 1) {
            const sp = &all[idx];
            const is_sel = self.cursor == idx;
            const discovered = self.discovered[idx];

            const prefix: []const u8 = if (is_sel) "> " else "  ";
            const check: []const u8 = if (discovered) "\xe2\x9c\x93 " else "? ";

            if (discovered) {
                const type_color = theme.typeColor(sp.critter_type);
                const rarity_color = theme.rarityColor(sp.rarity);
                const name_style = if (is_sel) theme.selected else theme.unselected;

                var c = writeText(win, 2, row, prefix, name_style);
                c = writeText(win, c, row, check, .{ .fg = theme.green });
                var name_buf: [20]u8 = undefined;
                const padded = padRight(&name_buf, sp.name, 16);
                c = writeText(win, c, row, padded, name_style);
                c = writeText(win, c, row, " ", name_style);
                var type_buf: [12]u8 = undefined;
                const type_padded = padRight(&type_buf, sp.critter_type.displayName(), 10);
                c = writeText(win, c, row, type_padded, .{ .fg = type_color });
                _ = writeText(win, c, row, sp.rarity.displayName(), .{ .fg = rarity_color });
            } else {
                const unk_style = if (is_sel) theme.selected else theme.dim;
                var c = writeText(win, 2, row, prefix, unk_style);
                c = writeText(win, c, row, check, unk_style);
                _ = writeText(win, c, row, "???", unk_style);
            }
            row += 1;
        }

        if (self.scroll_offset > 0) {
            _ = writeText(win, @as(u16, win.width -| 3), 5, "\xe2\x96\xb2", theme.dim);
        }
        if (self.scroll_offset + max_visible < self.species_count) {
            _ = writeText(win, @as(u16, win.width -| 3), 5 + max_visible -| 1, "\xe2\x96\xbc", theme.dim);
        }

        widgets.renderHint(win, "[Up/Down] Scroll  [Esc] Back");
    }

    fn padRight(buf: []u8, str: []const u8, width: usize) []const u8 {
        const len = @min(str.len, buf.len);
        @memcpy(buf[0..len], str[0..len]);
        const pad_end = @min(width, buf.len);
        if (len < pad_end) {
            @memset(buf[len..pad_end], ' ');
        }
        return buf[0..pad_end];
    }
};
