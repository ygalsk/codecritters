const std = @import("std");
const vaxis = @import("vaxis");
const fx = @import("fx.zig");

const Window = vaxis.Window;

pub const TransitionKind = enum {
    /// Fade through black: darken → black → brighten to new screen
    fade_to_black,
    /// New screen wipes in from right to left
    wipe_left,
    /// Random cells dissolve from old to new
    dissolve,
};

/// Duration of a full transition in milliseconds.
pub const DURATION_MS: i64 = 300;

/// Render a transition overlay for the given progress.
/// progress: 0.0 = start (old screen visible), 1.0 = end (new screen visible).
/// First half (0.0-0.5): old screen darkens. Second half (0.5-1.0): do nothing (new screen shows).
pub fn renderFadeToBlack(win: Window, progress: f32) void {
    if (progress >= 0.5) return; // second half: new screen is already being rendered

    // First half: overlay with increasing opacity black
    const alpha = progress * 2.0; // 0.0 → 1.0 during first half
    const dark = @as(u8, @intFromFloat((1.0 - alpha) * 40.0)); // fade from dim gray to black

    var r: u16 = 0;
    while (r < win.height) : (r += 1) {
        var c: u16 = 0;
        while (c < win.width) : (c += 1) {
            win.writeCell(c, r, .{
                .char = .{ .grapheme = " ", .width = 1 },
                .style = .{ .bg = .{ .rgb = .{ dark, dark, dark } } },
            });
        }
    }
}

/// Render a wipe-left transition. The new screen is revealed from left to right.
pub fn renderWipeLeft(win: Window, progress: f32) void {
    // The cutoff column: everything left of this is the new screen (already rendered),
    // everything right of this should be blacked out (old screen hidden).
    const cutoff: u16 = @intFromFloat(@as(f32, @floatFromInt(win.width)) * progress);

    var r: u16 = 0;
    while (r < win.height) : (r += 1) {
        var c: u16 = cutoff;
        while (c < win.width) : (c += 1) {
            win.writeCell(c, r, .{
                .char = .{ .grapheme = " ", .width = 1 },
                .style = .{ .bg = .{ .rgb = .{ 0, 0, 0 } } },
            });
        }
    }

    // Draw a bright edge at the cutoff for a "sweep" effect
    if (cutoff > 0 and cutoff < win.width) {
        var r2: u16 = 0;
        while (r2 < win.height) : (r2 += 1) {
            win.writeCell(cutoff -| 1, r2, .{
                .char = .{ .grapheme = "\xe2\x96\x88", .width = 1 }, // █
                .style = .{ .fg = .{ .rgb = .{ 200, 200, 255 } } },
            });
        }
    }
}

/// Render a dissolve transition. Cells are "revealed" in a pseudo-random pattern.
pub fn renderDissolve(win: Window, progress: f32) void {
    // Each cell has a pseudo-random threshold; cells above the threshold stay black
    var r: u16 = 0;
    while (r < win.height) : (r += 1) {
        var c: u16 = 0;
        while (c < win.width) : (c += 1) {
            // Deterministic hash for consistent pattern
            const hash = cellHash(c, r);
            const threshold = @as(f32, @floatFromInt(hash)) / 255.0;
            if (threshold > progress) {
                // Not yet revealed — black it out
                win.writeCell(c, r, .{
                    .char = .{ .grapheme = " ", .width = 1 },
                    .style = .{ .bg = .{ .rgb = .{ 0, 0, 0 } } },
                });
            }
        }
    }
}

/// Simple cell hash for dissolve pattern.
fn cellHash(x: u16, y: u16) u8 {
    // Mix x and y into a pseudo-random byte
    var h: u32 = @as(u32, x) *% 2654435761 +% @as(u32, y) *% 2246822519;
    h ^= h >> 16;
    h *%= 2654435761;
    return @truncate(h);
}

/// Pick a transition kind based on the screen change.
/// Battle entries get wipe, hub transitions get fade, dungeon gets dissolve.
pub fn pickTransition(from: anytype, to: anytype) TransitionKind {
    _ = from;
    return switch (to) {
        .battle => .wipe_left,
        .dungeon => .dissolve,
        .hub => .fade_to_black,
        else => .fade_to_black,
    };
}
