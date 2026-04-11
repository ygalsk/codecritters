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
    has_codex: bool,
    stats: HubStats,

    pub const HubStats = struct {
        total_runs: u64 = 0,
        deepest_floor: u64 = 0,
        critters_caught: u64 = 0,
        species_discovered: u64 = 0,
        bosses_defeated: u64 = 0,
    };

    const MAX_MENU = 6;

    const Action = enum {
        new_run,
        view_roster,
        inventory,
        meta_shop,
        codex,
        quit,
    };

    fn buildMenu(self: *const HubScreen) struct { items: [MAX_MENU]widgets.MenuItem, actions: [MAX_MENU]Action, count: u8 } {
        var items: [MAX_MENU]widgets.MenuItem = undefined;
        var actions: [MAX_MENU]Action = undefined;
        var count: u8 = 0;

        const entries = [_]struct { label: []const u8, action: Action, always: bool }{
            .{ .label = "New Run", .action = .new_run, .always = true },
            .{ .label = "View Roster", .action = .view_roster, .always = true },
            .{ .label = "Inventory", .action = .inventory, .always = true },
            .{ .label = "Meta Shop", .action = .meta_shop, .always = true },
            .{ .label = "Codex", .action = .codex, .always = false },
            .{ .label = "Quit", .action = .quit, .always = true },
        };

        for (entries) |e| {
            if (e.always or (e.action == .codex and self.has_codex)) {
                items[count] = .{ .label = e.label };
                actions[count] = e.action;
                count += 1;
            }
        }

        return .{ .items = items, .actions = actions, .count = count };
    }

    pub fn init(roster_count: u16, currency: u32) HubScreen {
        return initFull(roster_count, currency, null, false, false, .{});
    }

    pub fn initFull(roster_count: u16, currency: u32, favorite_sprite: ?*const sprite_mod.SpriteSheet, use_kitty: bool, has_codex: bool, stats: HubStats) HubScreen {
        return .{
            .cursor = 0,
            .dirty = true,
            .roster_count = roster_count,
            .currency = currency,
            .favorite_sprite = favorite_sprite,
            .use_kitty = use_kitty,
            .anim_timer = anim_mod.AnimTimer.init(500),
            .has_codex = has_codex,
            .stats = stats,
        };
    }

    pub fn handleInput(self: *HubScreen, key: vaxis.Key) ?ScreenResult {
        self.dirty = true;
        const menu = self.buildMenu();
        const action = input.applyCursor(&self.cursor, menu.count, input.menuNav(key));
        if (action == .confirm and self.cursor < menu.count) {
            return switch (menu.actions[self.cursor]) {
                .new_run => .goto_party_select,
                .view_roster => ScreenResult{ .goto_roster = .from_hub },
                .inventory => ScreenResult{ .goto_inventory = .from_hub },
                .meta_shop => .goto_meta_shop,
                .codex => .goto_codex,
                .quit => .quit,
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

        const title_row: u16 = h / 4;
        widgets.renderDancingTitle(win, "CODECRITTER", title_row, .{ 80, 200, 255 }, time_ms);

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
        const menu = self.buildMenu();
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

        widgets.renderMenuCentered(win, menu.items[0..menu.count], self.cursor, menu_start_row);

        // ── Stats HUD ──
        const stats_row = menu_start_row + menu.count + 1;
        if (stats_row + 2 < h) {
            widgets.renderThinSeparator(win, stats_row, .{ 50, 50, 70 });
            var stat_buf1: [80]u8 = undefined;
            const stat_line1 = std.fmt.bufPrint(&stat_buf1, "Runs: {d}  |  Deepest: Floor {d}", .{
                self.stats.total_runs,
                self.stats.deepest_floor,
            }) catch "Runs: ?";
            widgets.renderCenteredText(win, stats_row + 1, stat_line1, .{ .fg = theme.muted });

            var stat_buf2: [80]u8 = undefined;
            const stat_line2 = std.fmt.bufPrint(&stat_buf2, "Caught: {d}  |  Species: {d}/61  |  Bosses: {d}", .{
                self.stats.critters_caught,
                self.stats.species_discovered,
                self.stats.bosses_defeated,
            }) catch "Caught: ?";
            widgets.renderCenteredText(win, stats_row + 2, stat_line2, .{ .fg = theme.muted });
        }

        // Controls hint
        widgets.renderHint(win, "[Up/Down] Navigate  [Enter] Select");
    }

};
