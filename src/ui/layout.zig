const vaxis = @import("vaxis");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");

pub const Window = vaxis.Window;

/// Center a known-width element within a container width.
pub fn centerCol(container_w: u16, content_w: u16) u16 {
    return if (container_w > content_w) (container_w - content_w) / 2 else 0;
}

/// Center text horizontally (accepts runtime slice length).
pub fn centerText(win_width: u16, text_len: usize) u16 {
    const w: u16 = @intCast(@min(text_len, @as(usize, @intCast(win_width))));
    return centerCol(win_width, w);
}

/// Vertical centering within a region.
pub fn centerRow(container_h: u16, content_h: u16) u16 {
    return if (container_h > content_h) (container_h - content_h) / 2 else 0;
}

/// Return row pinned to bottom of window with a given margin from the bottom.
pub fn bottomRow(win_height: u16, margin: u16) u16 {
    return if (win_height > margin) win_height - margin else 0;
}

/// Check if terminal is too small. Writes error message and returns true if so.
pub fn tooSmall(win: Window, min_w: u16, min_h: u16) bool {
    if (win.width < min_w or win.height < min_h) {
        _ = ui.writeText(win, 0, 0, "Terminal too small", theme.err);
        return true;
    }
    return false;
}
