const std = @import("std");

// ── Dancing Colors ──
// Brogue-style sine-wave RGB offset per tile position and time.
// Phase-shifted per channel so colors shift hue, not just brightness.

pub fn dancingColor(base: [3]u8, time_ms: i64, x: u16, y: u16) [3]u8 {
    const amplitude: f32 = 18.0;
    const t: f32 = @as(f32, @floatFromInt(time_ms)) * 0.003;
    const fx: f32 = @floatFromInt(x);
    const fy: f32 = @floatFromInt(y);

    const r_off = @sin(t + fx * 0.5) * amplitude;
    const g_off = @sin(t + fy * 0.5 + 2.094) * amplitude; // +2pi/3
    const b_off = @sin(t + (fx + fy) * 0.3 + 4.189) * amplitude; // +4pi/3

    return .{
        clampAdd(base[0], r_off),
        clampAdd(base[1], g_off),
        clampAdd(base[2], b_off),
    };
}

/// High-amplitude dancing color for pulsing/blinking elements (encounters, cursors).
pub fn pulsingColor(base: [3]u8, time_ms: i64, x: u16, y: u16) [3]u8 {
    const amplitude: f32 = 50.0;
    const t: f32 = @as(f32, @floatFromInt(time_ms)) * 0.006;
    const fx: f32 = @floatFromInt(x);
    const fy: f32 = @floatFromInt(y);

    const off = @sin(t + fx * 0.3 + fy * 0.3) * amplitude;
    return .{
        clampAdd(base[0], off),
        clampAdd(base[1], off),
        clampAdd(base[2], off),
    };
}

// ── Lighting ──

/// Smooth light attenuation based on distance from light source.
/// Returns brightness factor: 1.0 at center, fading to min_bright at radius edge.
/// Beyond radius (visited tiles): dim_bright. Unseen tiles should not call this.
pub fn lightAttenuation(distance: f32, radius: f32) f32 {
    if (distance > radius) return 0.15; // visited but out of range
    return @max(0.2, 1.0 - (distance / radius));
}

/// Apply brightness multiplier to an RGB color.
pub fn applyBrightness(rgb: [3]u8, brightness: f32) [3]u8 {
    return .{
        @intFromFloat(@min(255.0, @as(f32, @floatFromInt(rgb[0])) * brightness)),
        @intFromFloat(@min(255.0, @as(f32, @floatFromInt(rgb[1])) * brightness)),
        @intFromFloat(@min(255.0, @as(f32, @floatFromInt(rgb[2])) * brightness)),
    };
}

/// Blend a color toward a tint. factor=0.0 → original, factor=1.0 → tint.
pub fn tintColor(rgb: [3]u8, tint: [3]u8, factor: f32) [3]u8 {
    const f = @max(0.0, @min(1.0, factor));
    const inv = 1.0 - f;
    return .{
        @intFromFloat(@as(f32, @floatFromInt(rgb[0])) * inv + @as(f32, @floatFromInt(tint[0])) * f),
        @intFromFloat(@as(f32, @floatFromInt(rgb[1])) * inv + @as(f32, @floatFromInt(tint[1])) * f),
        @intFromFloat(@as(f32, @floatFromInt(rgb[2])) * inv + @as(f32, @floatFromInt(tint[2])) * f),
    };
}

// ── Helpers ──

fn clampAdd(base: u8, offset: f32) u8 {
    const result = @as(f32, @floatFromInt(base)) + offset;
    return @intFromFloat(@max(0.0, @min(255.0, result)));
}

// ── Tests ──

test "dancingColor stays within u8 range" {
    // Test with extreme values — should never overflow
    const white = dancingColor(.{ 255, 255, 255 }, 0, 0, 0);
    const black = dancingColor(.{ 0, 0, 0 }, 0, 0, 0);
    _ = white;
    _ = black;
    // With varied time
    for (0..100) |i| {
        const time: i64 = @intCast(i * 100);
        const c = dancingColor(.{ 128, 64, 200 }, time, 12, 7);
        _ = c;
    }
}

test "lightAttenuation smooth falloff" {
    const at_center = lightAttenuation(0.0, 5.0);
    const at_edge = lightAttenuation(5.0, 5.0);
    const beyond = lightAttenuation(6.0, 5.0);
    const mid = lightAttenuation(2.5, 5.0);

    try std.testing.expect(at_center >= 0.95);
    try std.testing.expect(at_edge >= 0.19);
    try std.testing.expectApproxEqAbs(beyond, 0.15, 0.01);
    try std.testing.expect(mid > at_edge);
    try std.testing.expect(mid < at_center);
}

test "applyBrightness" {
    const half = applyBrightness(.{ 200, 100, 50 }, 0.5);
    try std.testing.expectEqual(@as(u8, 100), half[0]);
    try std.testing.expectEqual(@as(u8, 50), half[1]);
    try std.testing.expectEqual(@as(u8, 25), half[2]);

    const full = applyBrightness(.{ 200, 100, 50 }, 1.0);
    try std.testing.expectEqual(@as(u8, 200), full[0]);
}

test "tintColor blends correctly" {
    const orig: [3]u8 = .{ 100, 100, 100 };
    const tint: [3]u8 = .{ 200, 0, 50 };

    const no_tint = tintColor(orig, tint, 0.0);
    try std.testing.expectEqual(orig, no_tint);

    const full_tint = tintColor(orig, tint, 1.0);
    try std.testing.expectEqual(tint, full_tint);

    const half = tintColor(orig, tint, 0.5);
    try std.testing.expectEqual(@as(u8, 150), half[0]);
    try std.testing.expectEqual(@as(u8, 50), half[1]);
    try std.testing.expectEqual(@as(u8, 75), half[2]);
}
