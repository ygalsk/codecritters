const std = @import("std");
const vaxis = @import("vaxis");
const dungeon_mod = @import("dungeon");
const game_data_mod = @import("game_data");
const species_mod = @import("species");
const critter_mod = @import("critter");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");

const floor_gen = dungeon_mod.floor_gen;
const biome_mod = dungeon_mod.biome;

const Window = ui.Window;
const writeText = ui.writeText;
const writeFmt = ui.writeFmt;

const VISIBILITY_RADIUS: i16 = 5;

pub const DungeonScreen = struct {
    dungeon: *dungeon_mod.DungeonState,
    game_data: *const game_data_mod.GameData,

    // Fog of war
    visited: [floor_gen.FLOOR_HEIGHT][floor_gen.FLOOR_WIDTH]bool,

    log: ui.MessageLog,

    // Transition signal (checked by main.zig after handleInput)
    pending_battle: ?dungeon_mod.EncounterInfo,
    pending_is_boss: bool,
    pending_shop: bool,

    dirty: bool,

    pub fn init(
        dungeon: *dungeon_mod.DungeonState,
        game_data: *const game_data_mod.GameData,
    ) DungeonScreen {
        var screen = DungeonScreen{
            .dungeon = dungeon,
            .game_data = game_data,
            .visited = .{.{false} ** floor_gen.FLOOR_WIDTH} ** floor_gen.FLOOR_HEIGHT,
            .log = ui.MessageLog.init(),
            .pending_battle = null,
            .pending_is_boss = false,
            .pending_shop = false,
            .dirty = true,
        };
        screen.updateVisited();
        screen.log.push("Entered the dungeon - Floor 1");
        return screen;
    }

    pub fn handleInput(self: *DungeonScreen, key: vaxis.Key) void {
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
                    self.pending_battle = info;
                    self.pending_is_boss = false;
                    self.log.push("A wild critter appeared!");
                },
                .boss_triggered => |info| {
                    self.updateVisited();
                    self.pending_battle = info;
                    self.pending_is_boss = true;
                    self.log.push("A powerful boss blocks your path!");
                },
                .stairs_reached => {
                    self.updateVisited();
                    self.pending_shop = true;
                },
            }
        }
    }

    pub fn render(self: *const DungeonScreen, win: Window) void {
        win.clear();
        if (layout.tooSmall(win, 30, 14)) return;

        const hud_height: u16 = 2;
        const map_width: u16 = floor_gen.FLOOR_WIDTH;
        const map_height: u16 = floor_gen.FLOOR_HEIGHT;

        // Center map horizontally
        const map_col = layout.centerCol(win.width, map_width);
        const map_row: u16 = hud_height;

        self.renderHud(win, map_col);
        self.renderMap(win, map_row, map_col);

        const msg_row = map_row + map_height + 1;
        self.log.render(win, msg_row, 2);

        const ctrl_row = msg_row + @as(u16, @min(self.log.msg_count, 2)) + 1;
        if (ctrl_row < win.height) {
            _ = writeText(win, 2, ctrl_row, "[arrows] Move", theme.hint);
        }
    }

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

        for (0..floor_gen.FLOOR_HEIGHT) |yi| {
            const y: i16 = @intCast(yi);
            const row = map_row + @as(u16, @intCast(yi));
            if (row >= win.height) break;

            for (0..floor_gen.FLOOR_WIDTH) |xi| {
                const x: i16 = @intCast(xi);
                const col = map_col + @as(u16, @intCast(xi));
                if (col >= win.width) break;

                if (xi == self.dungeon.player_x and yi == self.dungeon.player_y) {
                    win.writeCell(col, row, .{
                        .char = .{ .grapheme = "@", .width = 1 },
                        .style = theme.heading,
                    });
                    continue;
                }

                const dist = absI16(x - px) + absI16(y - py);
                const tile = self.dungeon.current_floor.tiles[yi][xi];

                if (dist <= VISIBILITY_RADIUS) {
                    win.writeCell(col, row, .{
                        .char = .{ .grapheme = tileChar(tile), .width = 1 },
                        .style = tileStyleFor(tile, self.dungeon.biome_ptr.theme, false),
                    });
                } else if (self.visited[yi][xi]) {
                    win.writeCell(col, row, .{
                        .char = .{ .grapheme = tileChar(tile), .width = 1 },
                        .style = tileStyleFor(tile, self.dungeon.biome_ptr.theme, true),
                    });
                }
            }
        }
    }

    pub fn resetVisited(self: *DungeonScreen) void {
        self.visited = .{.{false} ** floor_gen.FLOOR_WIDTH} ** floor_gen.FLOOR_HEIGHT;
        self.updateVisited();
    }

    fn updateVisited(self: *DungeonScreen) void {
        const px: i16 = @intCast(self.dungeon.player_x);
        const py: i16 = @intCast(self.dungeon.player_y);

        for (0..floor_gen.FLOOR_HEIGHT) |yi| {
            const y: i16 = @intCast(yi);
            for (0..floor_gen.FLOOR_WIDTH) |xi| {
                const x: i16 = @intCast(xi);
                if (absI16(x - px) + absI16(y - py) <= VISIBILITY_RADIUS) {
                    self.visited[yi][xi] = true;
                }
            }
        }
    }

    fn tileChar(tile: floor_gen.Tile) []const u8 {
        return switch (tile) {
            .wall => "\xe2\x96\x88",
            .floor => "\xc2\xb7",
            .encounter => "!",
            .stairs => ">",
            .entrance => "<",
        };
    }

    fn tileStyleFor(tile: floor_gen.Tile, biome_theme: biome_mod.Theme, dim: bool) theme.Style {
        return switch (tile) {
            .wall => .{ .fg = .{ .rgb = if (dim) biome_theme.wall_dim_fg else biome_theme.wall_fg } },
            .floor => .{ .fg = .{ .rgb = if (dim) biome_theme.floor_dim_fg else biome_theme.floor_fg } },
            .encounter => .{ .fg = .{ .rgb = if (dim) .{ 100, 80, 16 } else .{ 255, 200, 40 } }, .bold = !dim },
            .stairs => .{ .fg = .{ .rgb = if (dim) .{ 32, 100, 48 } else .{ 80, 255, 120 } }, .bold = !dim },
            .entrance => .{ .fg = .{ .rgb = if (dim) .{ 0, 72, 100 } else .{ 0, 180, 255 } } },
        };
    }

    fn absI16(v: i16) i16 {
        return if (v < 0) -v else v;
    }
};
