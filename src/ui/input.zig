const vaxis = @import("vaxis");
const Key = vaxis.Key;

/// Standard vertical menu navigation result.
pub const NavAction = enum {
    none,
    up,
    down,
    confirm,
    back,
};

/// Map a key press to a standard menu navigation action.
pub fn menuNav(key: Key) NavAction {
    if (key.matches(Key.up, .{})) return .up;
    if (key.matches(Key.down, .{})) return .down;
    if (key.matches(Key.enter, .{}) or key.matches(' ', .{})) return .confirm;
    if (key.matches(Key.escape, .{}) or key.matches(Key.backspace, .{})) return .back;
    return .none;
}

/// Apply standard cursor movement within count items. Returns the action for further handling.
pub fn applyCursor(cursor: *u8, count: u8, action: NavAction) NavAction {
    switch (action) {
        .up => {
            if (cursor.* > 0) cursor.* -= 1;
        },
        .down => {
            if (cursor.* + 1 < count) cursor.* += 1;
        },
        else => {},
    }
    return action;
}

/// Grid navigation (2-column, used by battle main menu).
pub const GridAction = enum { none, confirm, back };

pub fn gridNav(key: Key, cursor: *u8, cols: u8, total: u8) GridAction {
    if (key.matches(Key.up, .{})) {
        if (cursor.* >= cols) cursor.* -= cols;
    } else if (key.matches(Key.down, .{})) {
        if (cursor.* + cols < total) cursor.* += cols;
    } else if (key.matches(Key.left, .{})) {
        if (cursor.* % cols > 0) cursor.* -= 1;
    } else if (key.matches(Key.right, .{})) {
        if (cursor.* % cols + 1 < cols and cursor.* + 1 < total) cursor.* += 1;
    } else if (key.matches(Key.enter, .{}) or key.matches(' ', .{})) {
        return .confirm;
    } else if (key.matches(Key.escape, .{}) or key.matches(Key.backspace, .{})) {
        return .back;
    }
    return .none;
}
