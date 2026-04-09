const std = @import("std");

pub const CritterType = enum {
    debug,
    patience,
    chaos,
    wisdom,
    snark,
    vibe,
    legacy,

    pub fn displayName(self: CritterType) []const u8 {
        return switch (self) {
            .debug => "DEBUG",
            .patience => "PATIENCE",
            .chaos => "CHAOS",
            .wisdom => "WISDOM",
            .snark => "SNARK",
            .vibe => "VIBE",
            .legacy => "LEGACY",
        };
    }
};

pub const Effectiveness = enum {
    weak,
    neutral,
    strong,

    pub fn multiplier(self: Effectiveness) f32 {
        return switch (self) {
            .weak => 0.5,
            .neutral => 1.0,
            .strong => 1.5,
        };
    }
};

/// Row = attacker type, Col = defender type.
/// Matches the chart in CODECRITTER_DESIGN.md.
const W = Effectiveness.weak;
const N = Effectiveness.neutral;
const S = Effectiveness.strong;

pub const type_chart: [7][7]Effectiveness = .{
    .{ N, N, S, W, N, S, W }, // debug
    .{ N, N, W, S, W, S, N }, // patience
    .{ W, S, N, N, S, N, W }, // chaos
    .{ S, W, N, N, W, N, S }, // wisdom
    .{ N, S, W, S, N, W, N }, // snark
    .{ W, W, N, N, S, N, S }, // vibe
    .{ S, N, S, W, N, W, N }, // legacy
};

pub fn getEffectiveness(attacker: CritterType, defender: CritterType) Effectiveness {
    return type_chart[@intFromEnum(attacker)][@intFromEnum(defender)];
}

// --- Tests ---

test "type chart symmetry: DEBUG beats CHAOS" {
    try std.testing.expectEqual(Effectiveness.strong, getEffectiveness(.debug, .chaos));
}

test "type chart symmetry: CHAOS resists DEBUG" {
    try std.testing.expectEqual(Effectiveness.weak, getEffectiveness(.chaos, .debug));
}

test "type chart: self is neutral" {
    inline for (0..7) |i| {
        try std.testing.expectEqual(Effectiveness.neutral, type_chart[i][i]);
    }
}

test "type chart: multiplier values" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), Effectiveness.weak.multiplier(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), Effectiveness.neutral.multiplier(), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), Effectiveness.strong.multiplier(), 0.001);
}

test "type chart: specific matchups from design doc" {
    // DEBUG beats CHAOS and VIBE
    try std.testing.expectEqual(Effectiveness.strong, getEffectiveness(.debug, .chaos));
    try std.testing.expectEqual(Effectiveness.strong, getEffectiveness(.debug, .vibe));
    // DEBUG weak to WISDOM and LEGACY
    try std.testing.expectEqual(Effectiveness.weak, getEffectiveness(.debug, .wisdom));
    try std.testing.expectEqual(Effectiveness.weak, getEffectiveness(.debug, .legacy));
    // LEGACY beats DEBUG and CHAOS
    try std.testing.expectEqual(Effectiveness.strong, getEffectiveness(.legacy, .debug));
    try std.testing.expectEqual(Effectiveness.strong, getEffectiveness(.legacy, .chaos));
    // VIBE beats SNARK and LEGACY
    try std.testing.expectEqual(Effectiveness.strong, getEffectiveness(.vibe, .snark));
    try std.testing.expectEqual(Effectiveness.strong, getEffectiveness(.vibe, .legacy));
}
