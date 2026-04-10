const vaxis = @import("vaxis");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const anim = @import("anim.zig");
const sprite_mod = @import("sprite.zig");
const ScreenResult = @import("screen_result.zig").ScreenResult;

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

    pub fn render(self: *const TitleScreen, win: vaxis.Window) void {
        win.clear();
        const w = win.width;
        const h = win.height;

        const frame = self.anim_timer.frameMod(2);

        var content_height: u16 = 0;
        var logo_rows: u16 = 0;
        if (self.title_sprite) |ts| {
            logo_rows = @intCast(ts.height / 2);
            content_height += logo_rows;
        }
        content_height += 4; // subtitle + gap + critter label space
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

        if (row < h) {
            widgets.renderCenteredText(win, row, "A Roguelike for Your Terminal", theme.header);
            row += 2;
        }

        if (self.critter_sprite) |cs| {
            const sprite_cols: u16 = @intCast(cs.frame_width);
            const col = layout.centerCol(w, sprite_cols);
            if (row < h) {
                cs.render(win, frame, row, col, self.use_kitty);
            }
        }

        widgets.renderHint(win, "[Press any key to start]");
    }
};
