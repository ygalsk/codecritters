const std = @import("std");

/// Emit a terminal bell (BEL character) for audio feedback.
pub fn beep() void {
    const stdout = std.fs.File.stdout();
    stdout.writeAll("\x07") catch {};
}
