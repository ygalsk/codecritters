const std = @import("std");
const vaxis = @import("vaxis");
const dungeon_mod = @import("dungeon");
const game_data_mod = @import("game_data");
const species_mod = @import("species");
const critter_mod = @import("critter");
const items_mod = @import("items");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const input = @import("input.zig");
const screen_result = @import("screen_result.zig");
const ScreenResult = screen_result.ScreenResult;
const fx = @import("fx.zig");
const tileset_mod = @import("tileset.zig");
const biome_bg_mod = @import("biome_background.zig");

const floor_gen = dungeon_mod.floor_gen;
const biome_mod = dungeon_mod.biome;

const Window = ui.Window;
const writeText = ui.writeText;
const writeFmt = ui.writeFmt;

const VISIBILITY_RADIUS: i16 = 8;

const MenuMode = enum {
    exploring,
    quick_menu,
};

pub const DungeonScreen = struct {
    dungeon: *dungeon_mod.DungeonState,
    game_data: *const game_data_mod.GameData,

    // Fog of war
    visited: [floor_gen.MAX_HEIGHT][floor_gen.MAX_WIDTH]bool,

    log: ui.MessageLog,

    // Quick menu state
    menu_mode: MenuMode,
    menu_cursor: u8,

    dirty: bool,

    // Graphics overhaul (Phase 25a)
    tileset: ?*const tileset_mod.Tileset,
    biome_bg: ?*biome_bg_mod.BiomeBackground,
    use_kitty: bool,

    pub fn init(
        dungeon: *dungeon_mod.DungeonState,
        game_data: *const game_data_mod.GameData,
        tileset: ?*const tileset_mod.Tileset,
        biome_bg: ?*biome_bg_mod.BiomeBackground,
        use_kitty: bool,
    ) DungeonScreen {
        var screen = DungeonScreen{
            .dungeon = dungeon,
            .game_data = game_data,
            .visited = .{.{false} ** floor_gen.MAX_WIDTH} ** floor_gen.MAX_HEIGHT,
            .log = ui.MessageLog.init(),
            .menu_mode = .exploring,
            .menu_cursor = 0,
            .dirty = true,
            .tileset = tileset,
            .biome_bg = biome_bg,
            .use_kitty = use_kitty,
        };
        screen.updateVisited();
        screen.log.push("Entered the dungeon - Floor 1");
        return screen;
    }

    pub fn handleInput(self: *DungeonScreen, key: vaxis.Key) ?ScreenResult {
        return switch (self.menu_mode) {
            .exploring => self.handleExploring(key),
            .quick_menu => self.handleQuickMenu(key),
        };
    }

    fn handleExploring(self: *DungeonScreen, key: vaxis.Key) ?ScreenResult {
        if (key.matches('m', .{})) {
            self.menu_mode = .quick_menu;
            self.menu_cursor = 0;
            self.dirty = true;
            return null;
        }

        const dir: ?dungeon_mod.Direction = if (key.matches(vaxis.Key.up, .{}))
            .up
        else if (key.matches(vaxis.Key.down, .{}))
            .down
        else if (key.matches(vaxis.Key.left, .{}))
            .left
        else if (key.matches(vaxis.Key.right, .{}))
            .right
        else
            null;

        if (dir) |d| {
            const result = dungeon_mod.movePlayer(self.dungeon, d);
            self.dirty = true;

            switch (result) {
                .moved => {
                    self.updateVisited();
                },
                .blocked => {},
                .encounter_triggered => |info| {
                    self.updateVisited();
                    self.log.push("A wild critter appeared!");
                    return ScreenResult{ .goto_battle = .{
                        .species_id = info.species_id,
                        .level = info.level,
                        .is_boss = false,
                    } };
                },
                .boss_triggered => |info| {
                    self.updateVisited();
                    self.log.push("A powerful boss blocks your path!");
                    return ScreenResult{ .goto_battle = .{
                        .species_id = info.species_id,
                        .level = info.level,
                        .is_boss = true,
                    } };
                },
                .stairs_reached => {
                    self.updateVisited();
                    return .goto_shop;
                },
            }
        }
        return null;
    }

    fn handleQuickMenu(self: *DungeonScreen, key: vaxis.Key) ?ScreenResult {
        const action = input.applyCursor(&self.menu_cursor, 3, input.menuNav(key));
        if (action != .none) self.dirty = true;
        switch (action) {
            .back => {
                self.menu_mode = .exploring;
            },
            .confirm => {
                switch (self.menu_cursor) {
                    0 => { // Items
                        self.menu_mode = .exploring;
                        return ScreenResult{ .goto_inventory = .from_dungeon };
                    },
                    1 => { // Party
                        self.menu_mode = .exploring;
                        return ScreenResult{ .goto_roster = .from_dungeon };
                    },
                    2 => { // Close
                        self.menu_mode = .exploring;
                    },
                    else => {},
                }
            },
            else => {},
        }
        return null;
    }

    // ─── Rendering ───

    pub fn render(self: *const DungeonScreen, win: Window) void {
        win.clear();
        if (layout.tooSmall(win, 30, 14)) return;

        const hud_height: u16 = 2;
        const map_width: u16 = self.dungeon.current_floor.width;
        const map_height: u16 = self.dungeon.current_floor.height;

        // Center map horizontally
        const map_col = layout.centerCol(win.width, map_width);
        const map_row: u16 = hud_height;

        self.renderHud(win, map_col);

        // Biome background (Kitty only — drawn under everything)
        if (self.biome_bg) |bg| {
            bg.render(win, map_row, map_col, map_width, map_height);
        }

        self.renderMap(win, map_row, map_col);

        const msg_row = map_row + map_height + 1;
        self.log.render(win, msg_row, 2);

        switch (self.menu_mode) {
            .exploring => {
                const ctrl_row = msg_row + @as(u16, @min(self.log.msg_count, 2)) + 1;
                if (ctrl_row < win.height) {
                    _ = writeText(win, 2, ctrl_row, "[arrows] Move  [m] Menu", theme.hint);
                }
            },
            .quick_menu => self.renderQuickMenu(win),
        }
    }

    fn renderQuickMenu(self: *const DungeonScreen, win: Window) void {
        const col: u16 = 2;
        const row: u16 = 3;

        _ = writeText(win, col, row, "Quick Menu", theme.heading);

        const items = [_]widgets.MenuItem{
            .{ .label = "Items" },
            .{ .label = "Party" },
            .{ .label = "Close" },
        };
        widgets.renderMenu(win, &items, self.menu_cursor, col, row + 2);

        widgets.renderHintAt(win, 2, "[Up/Down] Select  [Enter] Confirm  [Esc] Close");
    }

    // ─── Map / HUD ───

    fn renderHud(self: *const DungeonScreen, win: Window, col: u16) void {
        var c = writeFmt(win, col, 0, theme.heading, "Floor {d}", .{self.dungeon.floor_number});
        c = writeText(win, c + 2, 0, "  ", .{});
        _ = writeFmt(win, c, 0, theme.currency_bold, "${d}", .{self.dungeon.currency});

        c = col;
        for (self.dungeon.party) |maybe_critter| {
            const critter = maybe_critter orelse continue;
            const sp = ui.findSpeciesForCritter(self.dungeon, &critter);
            const name = if (sp) |s| s.name else "???";
            const hp_color = theme.hpColor(critter.current_hp, critter.max_hp);
            c = writeText(win, c, 1, name, theme.body);
            c = writeFmt(win, c, 1, .{ .fg = hp_color }, " {d}/{d}", .{ critter.current_hp, critter.max_hp });
            c += 2;
        }
    }

    fn renderMap(self: *const DungeonScreen, win: Window, map_row: u16, map_col: u16) void {
        const px: i16 = @intCast(self.dungeon.player_x);
        const py: i16 = @intCast(self.dungeon.player_y);
        const time_ms = std.time.milliTimestamp();
        const biome_theme = self.dungeon.biome_ptr.theme;

        const fw: u16 = self.dungeon.current_floor.width;
        const fh: u16 = self.dungeon.current_floor.height;

        for (0..fh) |yi| {
            const y: i16 = @intCast(yi);
            const row = map_row + @as(u16, @intCast(yi));
            if (row >= win.height) break;

            for (0..fw) |xi| {
                const x: i16 = @intCast(xi);
                const col = map_col + @as(u16, @intCast(xi));
                if (col >= win.width) break;

                const tile = self.dungeon.current_floor.tiles[yi][xi];
                const dist = absI16(x - px) + absI16(y - py);

                // Player character
                if (xi == self.dungeon.player_x and yi == self.dungeon.player_y) {
                    const player_color = fx.pulsingColor(.{ 255, 255, 255 }, time_ms, @intCast(xi), @intCast(yi));
                    win.writeCell(col, row, .{
                        .char = .{ .grapheme = "@", .width = 1 },
                        .style = .{ .fg = .{ .rgb = player_color }, .bold = true },
                    });
                    continue;
                }

                if (dist <= VISIBILITY_RADIUS) {
                    // Visible: smooth lighting + dancing colors
                    const brightness = fx.lightAttenuation(@floatFromInt(dist), @floatFromInt(VISIBILITY_RADIUS));

                    if (self.use_kitty) {
                        if (self.tileset) |ts| {
                            const tile_idx = tileToIndex(tile);
                            ts.renderTile(win, tile_idx, row, col, true, brightness);
                            continue;
                        }
                    }

                    // Enhanced Unicode fallback with dancing colors + smooth lighting
                    const base_color = tileBaseColor(tile, biome_theme);
                    const danced = fx.dancingColor(base_color, time_ms, @intCast(xi), @intCast(yi));
                    const lit = fx.applyBrightness(danced, brightness);
                    const glyph = enhancedTileChar(tile, @intCast(xi), @intCast(yi));

                    win.writeCell(col, row, .{
                        .char = .{ .grapheme = glyph, .width = 1 },
                        .style = .{
                            .fg = .{ .rgb = lit },
                            .bold = tile == .encounter or tile == .stairs,
                        },
                    });
                } else if (self.visited[yi][xi]) {
                    // Visited but out of range: dim
                    const brightness: f32 = 0.15;

                    if (self.use_kitty) {
                        if (self.tileset) |ts| {
                            const tile_idx = tileToIndex(tile);
                            ts.renderTile(win, tile_idx, row, col, true, brightness);
                            continue;
                        }
                    }

                    const base_color = tileBaseColor(tile, biome_theme);
                    const dimmed = fx.applyBrightness(base_color, brightness);

                    win.writeCell(col, row, .{
                        .char = .{ .grapheme = enhancedTileChar(tile, @intCast(xi), @intCast(yi)), .width = 1 },
                        .style = .{ .fg = .{ .rgb = dimmed } },
                    });
                }
                // Unseen tiles: remain black (default clear)
            }
        }
    }

    pub fn resetVisited(self: *DungeonScreen) void {
        self.visited = .{.{false} ** floor_gen.MAX_WIDTH} ** floor_gen.MAX_HEIGHT;
        self.updateVisited();
    }

    fn updateVisited(self: *DungeonScreen) void {
        const px: i16 = @intCast(self.dungeon.player_x);
        const py: i16 = @intCast(self.dungeon.player_y);
        const fw: u16 = self.dungeon.current_floor.width;
        const fh: u16 = self.dungeon.current_floor.height;

        for (0..fh) |yi| {
            const y: i16 = @intCast(yi);
            for (0..fw) |xi| {
                const x: i16 = @intCast(xi);
                if (absI16(x - px) + absI16(y - py) <= VISIBILITY_RADIUS) {
                    self.visited[yi][xi] = true;
                }
            }
        }
    }

    // ─── Tile Mapping ───

    /// Map floor_gen.Tile to tileset index.
    fn tileToIndex(tile: floor_gen.Tile) tileset_mod.TileIndex {
        return switch (tile) {
            .wall => .wall,
            .floor => .floor,
            .encounter => .encounter,
            .stairs => .stairs,
            .entrance => .entrance,
        };
    }

    /// Enhanced tile characters with position-based variation.
    fn enhancedTileChar(tile: floor_gen.Tile, x: u16, y: u16) []const u8 {
        return switch (tile) {
            .wall => switch ((x *% 7 +% y *% 13) % 3) {
                0 => "\xe2\x96\x88", // █
                1 => "\xe2\x96\x93", // ▓
                else => "\xe2\x96\x92", // ▒
            },
            .floor => switch ((x *% 11 +% y *% 17) % 3) {
                0 => "\xc2\xb7", // ·
                1 => "\xe2\x88\x98", // ∘
                else => "\xe2\x8b\x85", // ⋅
            },
            .encounter => "\xe2\x9c\xa6", // ✦
            .stairs => "\xe2\x96\xbc", // ▼
            .entrance => "\xe2\x96\xb2", // ▲
        };
    }

    /// Get base RGB color for a tile type from the biome theme.
    fn tileBaseColor(tile: floor_gen.Tile, biome_theme: biome_mod.Theme) [3]u8 {
        return switch (tile) {
            .wall => biome_theme.wall_fg,
            .floor => biome_theme.floor_fg,
            .encounter => .{ 255, 200, 40 },
            .stairs => .{ 80, 255, 120 },
            .entrance => .{ 0, 180, 255 },
        };
    }

    fn absI16(v: i16) i16 {
        return if (v < 0) -v else v;
    }
};
