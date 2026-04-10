const std = @import("std");

/// Shared animation frame counter. Embed in any screen struct.
pub const AnimTimer = struct {
    frame: u8 = 0,
    last_ms: i64 = 0,
    interval_ms: i64 = 500,

    pub fn init(interval_ms: i64) AnimTimer {
        return .{ .frame = 0, .last_ms = 0, .interval_ms = interval_ms };
    }

    /// Tick the timer. Returns true if the frame advanced (screen should redraw).
    pub fn tick(self: *AnimTimer) bool {
        const now = std.time.milliTimestamp();
        if (now - self.last_ms >= self.interval_ms) {
            self.frame +%= 1;
            self.last_ms = now;
            return true;
        }
        return false;
    }

    /// Current frame modulo n (for sprite sheets with n frames).
    pub fn frameMod(self: *const AnimTimer, n: u8) u8 {
        return if (n > 0) self.frame % n else 0;
    }
};
