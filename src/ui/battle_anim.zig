const std = @import("std");
const battle = @import("battle");
const types = @import("types");
const anim = @import("anim.zig");
const sound = @import("sound.zig");

/// Maximum animation steps per sequence.
const MAX_STEPS = 24;

/// Step types in a battle animation sequence.
const StepKind = enum {
    /// Attacker slides toward defender
    slide_forward,
    /// Attack effect plays on the target
    play_effect,
    /// Screen flashes white (super-effective)
    flash,
    /// Show damage / log the event message
    show_event,
    /// Defender shakes from the hit
    shake,
    /// Brief pause between events
    pause,
};

const AnimStep = struct {
    kind: StepKind,
    duration_ms: i64,
    /// Index into the TurnResult event array (for show_event steps).
    event_index: u8 = 0,
    /// Which side is attacking (for slide/effect positioning).
    attacker_is_player: bool = true,
    /// Move type for effect sprite lookup.
    move_type: types.CritterType = .debug,
    /// Whether this hit was super-effective (for flash).
    super_effective: bool = false,
};

/// Interpolated animation state — read by the renderer each frame.
pub const AnimState = struct {
    /// Horizontal offset for player sprite (positive = toward wild).
    player_x_offset: i16 = 0,
    /// Horizontal offset for wild sprite (negative = toward player).
    wild_x_offset: i16 = 0,
    /// Effect frame to render (null = no effect visible).
    effect_frame: ?u8 = null,
    /// Which type's effect to show.
    effect_type: types.CritterType = .debug,
    /// Whether the effect targets the player or wild critter.
    effect_on_player: bool = false,
    /// Screen flash intensity (0.0 = none, 1.0 = full white).
    flash_intensity: f32 = 0.0,
    /// Horizontal shake offset (oscillates during shake step).
    shake_offset: i16 = 0,
};

pub const BattleAnimSequencer = struct {
    steps: [MAX_STEPS]AnimStep = undefined,
    step_count: u8 = 0,
    current_step: u8 = 0,
    step_start_ms: i64 = 0,
    finished: bool = true,

    /// Current interpolated state for the renderer.
    state: AnimState = .{},

    /// Events that were "shown" this tick (caller should log them).
    pending_event: ?u8 = null,

    /// Build an animation sequence from a set of battle events.
    pub fn buildFromEvents(result: battle.TurnResult) BattleAnimSequencer {
        var seq = BattleAnimSequencer{
            .finished = false,
            .step_start_ms = std.time.milliTimestamp(),
        };

        var i: u8 = 0;
        while (i < result.event_count) : (i += 1) {
            const event = result.events[i];
            switch (event) {
                .damage_dealt => |d| {
                    // Slide attacker forward
                    seq.addStep(.{
                        .kind = .slide_forward,
                        .duration_ms = 200,
                        .attacker_is_player = d.attacker_is_player,
                    });
                    // Play effect on defender
                    seq.addStep(.{
                        .kind = .play_effect,
                        .duration_ms = 320,
                        .attacker_is_player = d.attacker_is_player,
                        .move_type = d.move_type,
                    });
                    // Flash if super effective
                    if (d.effectiveness == .strong) {
                        seq.addStep(.{
                            .kind = .flash,
                            .duration_ms = 120,
                            .super_effective = true,
                        });
                    }
                    // Show the damage message
                    seq.addStep(.{
                        .kind = .show_event,
                        .duration_ms = 300,
                        .event_index = i,
                    });
                    // Shake defender
                    seq.addStep(.{
                        .kind = .shake,
                        .duration_ms = 200,
                        .attacker_is_player = d.attacker_is_player,
                    });
                },
                .critter_fainted => {
                    seq.addStep(.{ .kind = .show_event, .duration_ms = 500, .event_index = i });
                },
                .move_missed => {
                    seq.addStep(.{ .kind = .show_event, .duration_ms = 400, .event_index = i });
                },
                .catch_result => {
                    seq.addStep(.{ .kind = .show_event, .duration_ms = 500, .event_index = i });
                },
                else => {
                    // Status, swap, item, etc. — just show the message
                    seq.addStep(.{ .kind = .show_event, .duration_ms = 300, .event_index = i });
                },
            }
            // Brief pause between events
            if (i + 1 < result.event_count) {
                seq.addStep(.{ .kind = .pause, .duration_ms = 100 });
            }
        }

        return seq;
    }

    fn addStep(self: *BattleAnimSequencer, step: AnimStep) void {
        if (self.step_count < MAX_STEPS) {
            self.steps[self.step_count] = step;
            self.step_count += 1;
        }
    }

    /// Advance the animation. Call every frame.
    /// Returns the event index if a show_event step just completed.
    pub fn tick(self: *BattleAnimSequencer) ?u8 {
        if (self.finished) return null;

        const now = std.time.milliTimestamp();
        const elapsed = now - self.step_start_ms;

        if (self.current_step >= self.step_count) {
            self.finished = true;
            self.state = .{};
            return null;
        }

        const step = self.steps[self.current_step];
        const t = if (step.duration_ms > 0) @as(f32, @floatFromInt(@min(elapsed, step.duration_ms))) / @as(f32, @floatFromInt(step.duration_ms)) else 1.0;

        // Update interpolated state based on current step
        self.updateState(step, t);

        // Check if step is complete
        if (elapsed >= step.duration_ms) {
            const result = self.completeStep(step);
            self.current_step += 1;
            self.step_start_ms = now;

            // Reset state for next step
            self.state = .{};

            if (self.current_step >= self.step_count) {
                self.finished = true;
            }

            return result;
        }

        return null;
    }

    fn updateState(self: *BattleAnimSequencer, step: AnimStep, t: f32) void {
        switch (step.kind) {
            .slide_forward => {
                const ease_t = anim.easeOutQuad(t);
                const offset = anim.lerpI16(0, 4, ease_t);
                if (step.attacker_is_player) {
                    self.state.player_x_offset = offset;
                } else {
                    self.state.wild_x_offset = -offset;
                }
            },
            .play_effect => {
                // Determine which frame of the effect to show
                const frame: u8 = @intFromFloat(t * 4.0); // 4 frames
                self.state.effect_frame = @min(frame, 3);
                self.state.effect_type = step.move_type;
                self.state.effect_on_player = !step.attacker_is_player;
            },
            .flash => {
                // Flash peaks at middle, fades out
                if (t < 0.5) {
                    self.state.flash_intensity = t * 2.0;
                } else {
                    self.state.flash_intensity = (1.0 - t) * 2.0;
                }
            },
            .shake => {
                // Oscillating shake on the defender
                const time_ms: f32 = t * @as(f32, @floatFromInt(step.duration_ms));
                const shake = @as(i16, @intFromFloat(@sin(time_ms * 0.05) * 2.0));
                if (step.attacker_is_player) {
                    self.state.wild_x_offset = shake;
                } else {
                    self.state.player_x_offset = shake;
                }
            },
            .show_event, .pause => {},
        }
    }

    fn completeStep(self: *BattleAnimSequencer, step: AnimStep) ?u8 {
        _ = self;
        switch (step.kind) {
            .show_event => {
                return step.event_index;
            },
            .flash => {
                if (step.super_effective) sound.beep();
            },
            else => {},
        }
        return null;
    }

    /// Skip the entire animation sequence immediately.
    /// Returns all remaining event indices that haven't been shown yet.
    pub fn skip(self: *BattleAnimSequencer, shown_events: *[16]u8) u8 {
        var count: u8 = 0;
        while (self.current_step < self.step_count) : (self.current_step += 1) {
            const step = self.steps[self.current_step];
            if (step.kind == .show_event) {
                if (count < 16) {
                    shown_events[count] = step.event_index;
                    count += 1;
                }
                if (step.kind == .flash and step.super_effective) sound.beep();
            }
        }
        self.finished = true;
        self.state = .{};
        return count;
    }

    pub fn isFinished(self: *const BattleAnimSequencer) bool {
        return self.finished;
    }
};
