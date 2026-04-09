const types = @import("types");
const vaxis = @import("vaxis");

pub const Color = vaxis.Cell.Color;

/// Map each CritterType to a distinct display color.
pub fn typeColor(t: types.CritterType) Color {
    return switch (t) {
        .debug => .{ .rgb = .{ 0, 180, 255 } }, // cyan-blue
        .patience => .{ .rgb = .{ 180, 180, 180 } }, // silver
        .chaos => .{ .rgb = .{ 255, 60, 60 } }, // red
        .wisdom => .{ .rgb = .{ 180, 120, 255 } }, // purple
        .snark => .{ .rgb = .{ 255, 200, 40 } }, // gold
        .vibe => .{ .rgb = .{ 80, 255, 120 } }, // green
        .legacy => .{ .rgb = .{ 160, 100, 50 } }, // brown
    };
}

/// HP bar color based on percentage remaining.
pub fn hpColor(current: u16, max: u16) Color {
    if (max == 0) return .{ .rgb = .{ 255, 0, 0 } };
    const pct = (@as(u32, current) * 100) / @as(u32, max);
    if (pct > 50) return .{ .rgb = .{ 0, 200, 0 } }; // green
    if (pct > 25) return .{ .rgb = .{ 255, 200, 0 } }; // yellow
    return .{ .rgb = .{ 255, 0, 0 } }; // red
}

