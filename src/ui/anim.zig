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

// ── Easing Functions ──
// Input t in [0, 1], output in [0, 1].

pub fn easeOutQuad(t: f32) f32 {
    return 1.0 - (1.0 - t) * (1.0 - t);
}

pub fn easeInOutCubic(t: f32) f32 {
    if (t < 0.5) return 4.0 * t * t * t;
    const p = -2.0 * t + 2.0;
    return 1.0 - p * p * p / 2.0;
}

pub fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + (b - a) * t;
}

pub fn lerpI16(a: i16, b: i16, t: f32) i16 {
    const fa: f32 = @floatFromInt(a);
    const fb: f32 = @floatFromInt(b);
    return @intFromFloat(fa + (fb - fa) * t);
}
