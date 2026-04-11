const std = @import("std");
const vaxis = @import("vaxis");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const input = @import("input.zig");
const ScreenResult = @import("screen_result.zig").ScreenResult;
const fx = @import("fx.zig");
const anim_mod = @import("anim.zig");
const sprite_mod = @import("sprite.zig");

const Window = vaxis.Window;
const writeText = ui.writeText;
const writeFmt = ui.writeFmt;

pub const HubScreen = struct {
    cursor: u8,
    dirty: bool,
    roster_count: u16,
    currency: u32,
    favorite_sprite: ?*const sprite_mod.SpriteSheet,
    use_kitty: bool,
    anim_timer: anim_mod.AnimTimer,

    const menu_items = [_]widgets.MenuItem{
        .{ .label = "New Run" },
        .{ .label = "View Roster" },
        .{ .label = "Inventory" },
        .{ .label = "Quit" },
    };

    pub fn init(roster_count: u16, currency: u32) HubScreen {
        return initFull(roster_count, currency, null, false);
    }

    pub fn initFull(roster_count: u16, currency: u32, favorite_sprite: ?*const sprite_mod.SpriteSheet, use_kitty: bool) HubScreen {
        return .{
            .cursor = 0,
            .dirty = true,
            .roster_count = roster_count,
            .currency = currency,
            .favorite_sprite = favorite_sprite,
            .use_kitty = use_kitty,
            .anim_timer = anim_mod.AnimTimer.init(500),
        };
    }

    pub fn handleInput(self: *HubScreen, key: vaxis.Key) ?ScreenResult {
        self.dirty = true;
        const action = input.applyCursor(&self.cursor, menu_items.len, input.menuNav(key));
        if (action == .confirm) {
            return switch (self.cursor) {
                0 => .goto_party_select,
                1 => ScreenResult{ .goto_roster = .from_hub },
                2 => ScreenResult{ .goto_inventory = .from_hub },
                3 => .quit,
                else => null,
            };
        }
        return null;
    }

    pub fn updateAnimation(self: *HubScreen) void {
        if (self.anim_timer.tick()) self.dirty = true;
    }

    pub fn render(self: *const HubScreen, win: Window) void {
        win.clear();
        if (layout.tooSmall(win, 30, 15)) return;

        const h = win.height;
        const w = win.width;
        const time_ms = std.time.milliTimestamp();

        // ── Box border ──
        widgets.renderColorBorder(win, .{ 50, 50, 70 });

        // ── Title with dancing colors ──
        const title = "CODECRITTER";
        const title_row: u16 = h / 4;
        const title_col = layout.centerText(w, title.len);
        for (title, 0..) |ch, i| {
            const ci: u16 = @intCast(i);
            const base_color: [3]u8 = .{ 80, 200, 255 }; // cyan
            const danced = fx.dancingColor(base_color, time_ms, title_col + ci, title_row);
            var char_buf: [1]u8 = .{ch};
            _ = writeText(win, title_col + ci, title_row, &char_buf, .{
                .fg = .{ .rgb = danced },
                .bold = true,
            });
        }

        // Subtitle with breathing brightness
        const subtitle = "A Roguelike for Your Terminal";
        const sub_brightness = 0.5 + 0.3 * @sin(@as(f32, @floatFromInt(time_ms)) * 0.002);
        const sub_color = fx.applyBrightness(.{ 140, 140, 160 }, sub_brightness);
        widgets.renderCenteredText(win, title_row + 1, subtitle, .{ .fg = .{ .rgb = sub_color } });

        // ── Separator ──
        const sep_row = title_row + 3;
        widgets.renderThinSeparator(win, sep_row, .{ 50, 50, 70 });

        // ── Roster count + currency ──
        const info_row = sep_row + 1;
        var roster_buf: [64]u8 = undefined;
        const roster_str = std.fmt.bufPrint(&roster_buf, "Roster: {d} critter{s}  |  ${d}", .{
            self.roster_count,
            if (self.roster_count != 1) "s" else "",
            self.currency,
        }) catch "Roster: ?";
        widgets.renderCenteredText(win, info_row, roster_str, theme.currency);

        // ── Menu ──
        const menu_start_row = info_row + 2;

        // If we have a favorite sprite, show it to the left of the menu
        if (self.favorite_sprite) |sprite| {
            const sprite_size = sprite.displaySize();
            const menu_center = w / 2;
            const sprite_col = if (menu_center > sprite_size.cols + 12) menu_center - sprite_size.cols - 4 else 2;
            const sprite_row = menu_start_row;
            const frame = self.anim_timer.frameMod(sprite.frame_count);
            sprite.render(win, frame, sprite_row, sprite_col, self.use_kitty);
        }

        widgets.renderMenuCentered(win, &menu_items, self.cursor, menu_start_row);

        // Controls hint
        widgets.renderHint(win, "[Up/Down] Navigate  [Enter] Select");
    }

};
