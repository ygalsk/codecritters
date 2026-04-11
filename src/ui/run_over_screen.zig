const std = @import("std");
const vaxis = @import("vaxis");
const dungeon_mod = @import("dungeon");
const game_data_mod = @import("game_data");
const leveling = @import("leveling");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const ScreenResult = @import("screen_result.zig").ScreenResult;
pub const RunOverScreen = struct {
    dungeon_state: *const dungeon_mod.DungeonState,
    game_data: *const game_data_mod.GameData,
    dirty: bool,

    pub fn init(
        dungeon_state: *const dungeon_mod.DungeonState,
        game_data: *const game_data_mod.GameData,
    ) RunOverScreen {
        return .{
            .dungeon_state = dungeon_state,
            .game_data = game_data,
            .dirty = true,
        };
    }

    pub fn handleInput(self: *RunOverScreen, key: vaxis.Key) ?ScreenResult {
        _ = key;
        _ = self;
        return .goto_hub;
    }

    pub fn render(self: *const RunOverScreen, win: vaxis.Window) void {
        win.clear();
        if (layout.tooSmall(win, 40, 10)) return;

        // Colored border: green for extraction, red for wipe
        const border_color: [3]u8 = if (self.dungeon_state.outcome == .extracted) .{ 40, 180, 80 } else .{ 180, 40, 40 };
        widgets.renderColorBorder(win, border_color);

        const title = switch (self.dungeon_state.outcome) {
            .extracted => "Run Complete - Extracted!",
            .wiped => "Run Over - Wiped!",
            .in_progress => "Run Over",
        };

        const title_color: theme.Style = if (self.dungeon_state.outcome == .extracted)
            theme.level_up
        else
            .{ .fg = theme.error_red, .bold = true };

        _ = ui.writeText(win, 2, 1, title, title_color);

        _ = ui.writeFmt(win, 2, 3, theme.heading, "Floors cleared: {d}", .{self.dungeon_state.floor_number});
        _ = ui.writeFmt(win, 2, 4, theme.currency_bold, "Currency earned: ${d}", .{self.dungeon_state.currency});
        _ = ui.writeFmt(win, 2, 5, theme.header, "Critters caught: {d}", .{self.dungeon_state.catch_count});

        var row: u16 = 7;

        if (self.dungeon_state.catch_count > 0) {
            _ = ui.writeText(win, 2, row, "Catches:", theme.header);
            row += 1;
            for (self.dungeon_state.catches[0..self.dungeon_state.catch_count]) |maybe_catch| {
                const catch_rec = maybe_catch orelse continue;
                if (row >= win.height) break;
                _ = ui.writeFmt(win, 4, row, theme.header, "{s} Lv{d} (floor {d})", .{ catch_rec.species_id, catch_rec.level, catch_rec.floor_caught });
                row += 1;
            }
            row += 1;
        }

        const scar_style: theme.Style = .{ .fg = theme.scar_label };
        if (self.dungeon_state.pending_scar_count > 0) {
            _ = ui.writeText(win, 2, row, "Scars:", scar_style);
            row += 1;
            for (self.dungeon_state.pending_scars[0..self.dungeon_state.pending_scar_count]) |scar| {
                if (row >= win.height) break;
                if (self.dungeon_state.party[scar.party_index]) |c| {
                    _ = ui.writeFmt(win, 4, row, scar_style, "{s}: -1 {s}", .{ c.species_id, scar.stat.displayName() });
                } else {
                    _ = ui.writeFmt(win, 4, row, scar_style, "Party #{d}: -1 {s}", .{ scar.party_index + 1, scar.stat.displayName() });
                }
                row += 1;
            }
            row += 1;
        }

        if (self.dungeon_state.outcome == .extracted) {
            _ = ui.writeText(win, 2, row, "Party:", theme.heading);
            row += 1;
            for (self.dungeon_state.party) |maybe_critter| {
                const critter = maybe_critter orelse continue;
                if (row >= win.height -| 2) break;
                const sp = self.game_data.findSpecies(critter.species_id);
                const name = if (sp) |s| s.name else critter.species_id;
                if (critter.level < 100) {
                    const current_xp = critter.xp;
                    const next_level_xp = leveling.xpForLevel(critter.level + 1);
                    const prev_level_xp = leveling.xpForLevel(critter.level);
                    const xp_into = current_xp -| prev_level_xp;
                    const xp_needed = next_level_xp -| prev_level_xp;
                    _ = ui.writeFmt(win, 4, row, theme.xp, "{s} Lv{d}  XP: {d}/{d}", .{ name, critter.level, xp_into, xp_needed });
                } else {
                    _ = ui.writeFmt(win, 4, row, theme.xp, "{s} Lv{d}  MAX", .{ name, critter.level });
                }
                row += 1;
            }
        } else if (self.dungeon_state.outcome == .wiped) {
            _ = ui.writeText(win, 2, row, "Your critters need 2 runs to recover.", .{ .fg = theme.status_red, .bold = true });
        }

        widgets.renderHintAt(win, 3, "[Press any key to continue]");
    }

};
