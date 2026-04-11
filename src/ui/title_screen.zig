const std = @import("std");
const vaxis = @import("vaxis");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const anim = @import("anim.zig");
const sprite_mod = @import("sprite.zig");
const ScreenResult = @import("screen_result.zig").ScreenResult;
const fx = @import("fx.zig");

const Window = vaxis.Window;
const writeText = ui.writeText;

pub const TitleScreen = struct {
    dirty: bool,
    title_sprite: ?*const sprite_mod.SpriteSheet,
    critter_sprite: ?*const sprite_mod.SpriteSheet,
    use_kitty: bool,
    anim_timer: anim.AnimTimer,
    frames_shown: u16,

    // Ignore input for the first few frames to avoid terminal query responses
    // being interpreted as key presses
    const INPUT_GUARD_FRAMES: u16 = 3;

    pub fn init(
        title_sprite: ?*const sprite_mod.SpriteSheet,
        critter_sprite: ?*const sprite_mod.SpriteSheet,
        use_kitty: bool,
    ) TitleScreen {
        return .{
            .dirty = true,
            .title_sprite = title_sprite,
            .critter_sprite = critter_sprite,
            .use_kitty = use_kitty,
            .anim_timer = anim.AnimTimer.init(500),
            .frames_shown = 0,
        };
    }

    pub fn handleInput(self: *TitleScreen, key: vaxis.Key) ?ScreenResult {
        _ = key;
        if (self.frames_shown >= INPUT_GUARD_FRAMES) {
            return .goto_hub;
        }
        return null;
    }

    pub fn updateAnimation(self: *TitleScreen) void {
        if (self.frames_shown < INPUT_GUARD_FRAMES) {
            self.frames_shown += 1;
        }
        if (self.anim_timer.tick()) self.dirty = true;
    }

    pub fn render(self: *const TitleScreen, win: Window) void {
        win.clear();
        if (layout.tooSmall(win, 30, 12)) return;
        const w = win.width;
        const h = win.height;
        const time_ms = std.time.milliTimestamp();

        const frame = self.anim_timer.frameMod(2);

        var content_height: u16 = 0;
        var logo_rows: u16 = 0;
        if (self.title_sprite) |ts| {
            logo_rows = @intCast(ts.height / 2);
            content_height += logo_rows;
        }
        content_height += 4;
        var critter_rows: u16 = 0;
        if (self.critter_sprite) |cs| {
            critter_rows = @intCast(cs.height / 2);
            content_height += critter_rows + 1;
        }

        const start_row: u16 = if (h > content_height + 6) (h - content_height) / 3 else 1;
        var row = start_row;

        if (self.title_sprite) |ts| {
            const logo_cols: u16 = @intCast(ts.frame_width);
            const col = layout.centerCol(w, logo_cols);
            ts.render(win, frame, row, col, self.use_kitty);
            row += logo_rows + 2;
        }

        // Subtitle with breathing brightness
        if (row < h) {
            const subtitle = "A Roguelike for Your Terminal";
            const breath = 0.5 + 0.4 * @sin(@as(f32, @floatFromInt(time_ms)) * 0.0015);
            const sub_color = fx.applyBrightness(.{ 180, 180, 200 }, breath);
            widgets.renderCenteredText(win, row, subtitle, .{ .fg = .{ .rgb = sub_color } });
            row += 2;
        }

        // Critter sprite with float animation (y_offset oscillates +/- 1)
        if (self.critter_sprite) |cs| {
            const sprite_cols: u16 = @intCast(cs.frame_width);
            const col = layout.centerCol(w, sprite_cols);
            if (row < h) {
                const float_offset: f32 = @sin(@as(f32, @floatFromInt(time_ms)) * 0.003);
                const y_off: i16 = if (float_offset > 0.3) -1 else if (float_offset < -0.3) 1 else 0;
                const sprite_row: u16 = @intCast(@max(0, @as(i32, row) + y_off));
                cs.render(win, frame, sprite_row, col, self.use_kitty);
            }
        }

        // Hint with subtle pulse
        const hint_brightness = 0.4 + 0.2 * @sin(@as(f32, @floatFromInt(time_ms)) * 0.003);
        const hint_color = fx.applyBrightness(.{ 150, 150, 150 }, hint_brightness);
        if (h > 2) {
            const hint = "[Press any key to start]";
            widgets.renderCenteredText(win, h - 2, hint, .{ .fg = .{ .rgb = hint_color } });
        }
    }
};
