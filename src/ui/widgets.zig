const std = @import("std");
const vaxis = @import("vaxis");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");

const Window = vaxis.Window;
const Style = theme.Style;
const writeText = ui.writeText;
const writeFmt = ui.writeFmt;

// ─── Menu Widget ───

pub const MenuItem = struct {
    label: []const u8,
    enabled: bool = true,
};

pub fn renderMenu(
    win: Window,
    items: []const MenuItem,
    cursor: u8,
    col: u16,
    start_row: u16,
) void {
    for (items, 0..) |item, i| {
        const row = start_row + @as(u16, @intCast(i));
        if (row >= win.height) break;
        const is_sel = cursor == @as(u8, @intCast(i));
        const style: Style = if (!item.enabled)
            theme.dim
        else if (is_sel)
            theme.selected
        else
            theme.unselected;

        const prefix: []const u8 = if (is_sel) "> " else "  ";
        const c = writeText(win, col, row, prefix, style);
        _ = writeText(win, c, row, item.label, style);
    }
}

pub fn renderMenuCentered(
    win: Window,
    items: []const MenuItem,
    cursor: u8,
    start_row: u16,
) void {
    for (items, 0..) |item, i| {
        const row = start_row + @as(u16, @intCast(i));
        if (row >= win.height) break;
        const is_sel = cursor == @as(u8, @intCast(i));
        const style: Style = if (!item.enabled)
            theme.dim
        else if (is_sel)
            theme.selected_text
        else
            theme.unselected;

        const prefix: []const u8 = if (is_sel) "> " else "  ";
        const total_len = prefix.len + item.label.len;
        const col = layout.centerText(win.width, total_len);
        const c = writeText(win, col, row, prefix, style);
        _ = writeText(win, c, row, item.label, style);
    }
}

// ─── HP Bar Widget ───

pub const BarStyle = enum { full, compact };

pub fn renderHpBar(
    win: Window,
    current: u16,
    max: u16,
    row: u16,
    col: u16,
    style: BarStyle,
) u16 {
    const hp_color = theme.hpColor(current, max);
    switch (style) {
        .full => {
            const bar_width: u16 = 20;
            var c = writeText(win, col, row, "HP ", theme.body);
            const filled: u16 = if (max > 0) @intCast((@as(u32, current) * bar_width) / @as(u32, max)) else 0;
            var j: u16 = 0;
            while (j < bar_width) : (j += 1) {
                if (c >= win.width) break;
                if (j < filled) {
                    win.writeCell(c, row, .{ .char = .{ .grapheme = "\xe2\x96\x88", .width = 1 }, .style = .{ .fg = hp_color } });
                } else {
                    win.writeCell(c, row, .{ .char = .{ .grapheme = "\xe2\x96\x91", .width = 1 }, .style = .{ .fg = theme.bar_empty } });
                }
                c += 1;
            }
            return writeFmt(win, c, row, theme.body, " {d}/{d}", .{ current, max });
        },
        .compact => {
            return writeFmt(win, col, row, .{ .fg = hp_color }, " {d}/{d}", .{ current, max });
        },
    }
}

// ─── Separator Widget ───

pub fn renderSeparator(win: Window, row: u16) void {
    var i: u16 = 0;
    while (i < win.width) : (i += 1) {
        win.writeCell(i, row, .{
            .char = .{ .grapheme = "\xe2\x94\x80", .width = 1 },
            .style = .{ .fg = theme.separator },
        });
    }
}

// ─── Hint Bar Widget ───

pub fn renderHint(win: Window, text: []const u8) void {
    const row = layout.bottomRow(win.height, 2);
    if (row < win.height) {
        const col = layout.centerText(win.width, text.len);
        _ = writeText(win, col, row, text, theme.hint);
    }
}

pub fn renderHintAt(win: Window, col: u16, text: []const u8) void {
    const row = layout.bottomRow(win.height, 2);
    if (row < win.height) {
        _ = writeText(win, col, row, text, theme.hint);
    }
}

// ─── Color Border Widget ───

pub fn renderColorBorder(win: Window, color: [3]u8) void {
    const w = win.width;
    const h = win.height;
    const style = Style{ .fg = .{ .rgb = color } };

    // Top and bottom
    var c: u16 = 0;
    while (c < w) : (c += 1) {
        win.writeCell(c, 0, .{ .char = .{ .grapheme = "\xe2\x94\x80", .width = 1 }, .style = style });
        if (h > 1) win.writeCell(c, h - 1, .{ .char = .{ .grapheme = "\xe2\x94\x80", .width = 1 }, .style = style });
    }
    // Left and right
    var r: u16 = 1;
    while (r < h -| 1) : (r += 1) {
        win.writeCell(0, r, .{ .char = .{ .grapheme = "\xe2\x94\x82", .width = 1 }, .style = style });
        if (w > 1) win.writeCell(w - 1, r, .{ .char = .{ .grapheme = "\xe2\x94\x82", .width = 1 }, .style = style });
    }
    // Corners
    win.writeCell(0, 0, .{ .char = .{ .grapheme = "\xe2\x95\xad", .width = 1 }, .style = style });
    if (w > 1) win.writeCell(w - 1, 0, .{ .char = .{ .grapheme = "\xe2\x95\xae", .width = 1 }, .style = style });
    if (h > 1) win.writeCell(0, h - 1, .{ .char = .{ .grapheme = "\xe2\x95\xb0", .width = 1 }, .style = style });
    if (w > 1 and h > 1) win.writeCell(w - 1, h - 1, .{ .char = .{ .grapheme = "\xe2\x95\xaf", .width = 1 }, .style = style });
}

// ─── Thin Separator Widget ───

pub fn renderThinSeparator(win: Window, row: u16, color: [3]u8) void {
    const sep_style = Style{ .fg = .{ .rgb = color } };
    var c: u16 = 2;
    while (c < win.width -| 2) : (c += 1) {
        win.writeCell(c, row, .{
            .char = .{ .grapheme = "\xe2\x94\x80", .width = 1 },
            .style = sep_style,
        });
    }
}

// ─── Centered Text ───

pub fn renderCenteredText(win: Window, row: u16, text: []const u8, style: Style) void {
    const col = layout.centerText(win.width, text.len);
    _ = writeText(win, col, row, text, style);
}

// ─── Dancing Title ───

const fx = @import("fx.zig");

pub fn renderDancingTitle(win: Window, title: []const u8, row: u16, base_color: [3]u8, time_ms: i64) void {
    const col = layout.centerText(win.width, title.len);
    for (title, 0..) |ch, i| {
        const ci: u16 = @intCast(i);
        const danced = fx.dancingColor(base_color, time_ms, col + ci, row);
        var char_buf: [1]u8 = .{ch};
        _ = writeText(win, col + ci, row, &char_buf, .{
            .fg = .{ .rgb = danced },
            .bold = true,
        });
    }
}
