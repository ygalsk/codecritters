const std = @import("std");
const vaxis = @import("vaxis");
const critter_mod = @import("critter");
const species_mod = @import("species");
const colors = @import("colors.zig");
const ui = @import("ui_common.zig");

const Window = ui.Window;
const Style = ui.Style;
const Key = ui.Key;
const writeText = ui.writeText;
const writeFmt = ui.writeFmt;

pub const MAX_ROSTER = 64;
pub const MAX_PARTY = 3;

pub const PartySelectScreen = struct {
    roster: []const critter_mod.Critter,
    roster_species: []const ?*const species_mod.Species,
    selected: [MAX_PARTY]?usize, // indices into roster
    select_count: u8,
    cursor: u8,
    scroll_offset: u8,
    done: bool,
    confirmed: bool,
    dirty: bool,

    pub fn init(
        roster: []const critter_mod.Critter,
        roster_species: []const ?*const species_mod.Species,
    ) PartySelectScreen {
        return .{
            .roster = roster,
            .roster_species = roster_species,
            .selected = .{ null, null, null },
            .select_count = 0,
            .cursor = 0,
            .scroll_offset = 0,
            .done = false,
            .confirmed = false,
            .dirty = true,
        };
    }

    fn isSelected(self: *const PartySelectScreen, idx: usize) bool {
        for (self.selected) |maybe| {
            if (maybe) |s| {
                if (s == idx) return true;
            }
        }
        return false;
    }

    fn toggleSelect(self: *PartySelectScreen, idx: usize) void {
        // Deselect if already selected
        for (&self.selected) |*maybe| {
            if (maybe.*) |s| {
                if (s == idx) {
                    maybe.* = null;
                    self.select_count -= 1;
                    return;
                }
            }
        }
        // Select if room and not on cooldown
        if (self.select_count >= MAX_PARTY) return;
        if (idx >= self.roster.len) return;
        if (self.isOnCooldown(idx)) return;

        for (&self.selected) |*maybe| {
            if (maybe.* == null) {
                maybe.* = idx;
                self.select_count += 1;
                return;
            }
        }
    }

    fn isOnCooldown(self: *const PartySelectScreen, idx: usize) bool {
        if (idx >= self.roster.len) return false;
        return self.roster[idx].cooldown_runs > 0;
    }

    pub fn handleInput(self: *PartySelectScreen, key: vaxis.Key) void {
        self.dirty = true;
        const roster_len: u8 = @intCast(@min(self.roster.len, MAX_ROSTER));

        if (key.matches(Key.up, .{})) {
            if (self.cursor > 0) self.cursor -= 1;
        } else if (key.matches(Key.down, .{})) {
            if (self.cursor + 1 < roster_len) self.cursor += 1;
        } else if (key.matches(Key.enter, .{}) or key.matches(' ', .{})) {
            self.toggleSelect(self.cursor);
        } else if (key.matches('c', .{})) {
            if (self.select_count > 0) {
                self.done = true;
                self.confirmed = true;
            }
        } else if (key.matches(Key.escape, .{}) or key.matches(Key.backspace, .{})) {
            self.done = true;
            self.confirmed = false;
        }
    }

    pub fn render(self: *const PartySelectScreen, win: Window) void {
        win.clear();
        if (win.height < 10 or win.width < 40) {
            _ = writeText(win, 0, 0, "Terminal too small", .{ .fg = .{ .rgb = .{ 255, 60, 60 } } });
            return;
        }

        const white_bold: Style = .{ .fg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true };

        _ = writeFmt(win, 2, 0, white_bold, "Select Party ({d}/{d})", .{ self.select_count, MAX_PARTY });

        if (self.roster.len == 0) {
            _ = writeText(win, 2, 2, "No critters in roster!", .{ .fg = .{ .rgb = .{ 255, 100, 100 } } });
            _ = writeText(win, 2, 4, "[Esc] Back", ui.dim_style);
            return;
        }

        // Scrollable list area
        const list_height: u8 = @intCast(@min(win.height -| 6, 20));
        const roster_len: u8 = @intCast(@min(self.roster.len, MAX_ROSTER));

        // Auto-scroll to keep cursor visible
        var scroll = self.scroll_offset;
        if (self.cursor < scroll) scroll = self.cursor;
        if (self.cursor >= scroll + list_height) scroll = self.cursor - list_height + 1;

        var row: u16 = 2;
        var i: u8 = scroll;
        while (i < roster_len and row < 2 + @as(u16, list_height)) : (i += 1) {
            const critter = &self.roster[i];
            const sp = if (i < self.roster_species.len) self.roster_species[i] else null;
            const name = if (sp) |s| s.name else "???";
            const is_cur = self.cursor == i;
            const is_sel = self.isSelected(i);
            const on_cd = self.isOnCooldown(i);

            const marker: []const u8 = if (is_sel) "[*]" else "[ ]";
            const prefix: []const u8 = if (is_cur) "> " else "  ";

            var style: Style = .{ .fg = .{ .rgb = .{ 200, 200, 200 } } };
            if (on_cd) {
                style = .{ .fg = .{ .rgb = .{ 120, 60, 60 } } };
            } else if (is_cur) {
                style = .{ .fg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true };
            }

            var c = writeText(win, 2, row, prefix, style);
            c = writeText(win, c, row, marker, style);
            c = writeText(win, c, row, " ", style);
            c = writeText(win, c, row, name, style);
            c = writeFmt(win, c, row, style, " Lv{d}", .{critter.level});

            // Type badge
            if (sp) |s| {
                const type_color = colors.typeColor(s.critter_type);
                c = writeText(win, c, row, " ", style);
                c = writeText(win, c, row, s.critter_type.displayName(), .{ .fg = type_color, .bold = true });
            }

            // HP
            const eff_hp = critter.effectiveStat(.hp);
            const hp_color = colors.hpColor(critter.current_hp, eff_hp);
            c = writeFmt(win, c, row, .{ .fg = hp_color }, " HP {d}/{d}", .{ critter.current_hp, eff_hp });

            if (on_cd) {
                _ = writeFmt(win, c, row, .{ .fg = .{ .rgb = .{ 200, 60, 60 } } }, " [COOLDOWN {d} run(s)]", .{critter.cooldown_runs});
            }

            row += 1;
        }

        // Selected party summary
        row += 1;
        if (row < win.height) {
            _ = writeText(win, 2, row, "Party:", white_bold);
            row += 1;
        }
        for (self.selected) |maybe| {
            if (maybe) |idx| {
                if (row >= win.height) break;
                if (idx < self.roster.len) {
                    const critter = &self.roster[idx];
                    const sp = if (idx < self.roster_species.len) self.roster_species[idx] else null;
                    const name = if (sp) |s| s.name else "???";
                    _ = writeFmt(win, 4, row, .{ .fg = .{ .rgb = .{ 150, 255, 150 } } }, "- {s} Lv{d}", .{ name, critter.level });
                    row += 1;
                }
            }
        }

        // Controls
        const ctrl_row: u16 = if (win.height > 2) win.height - 2 else win.height;
        if (ctrl_row < win.height) {
            _ = writeText(win, 2, ctrl_row, "[Enter] Toggle  [C] Confirm  [Esc] Back", ui.dim_style);
        }
    }
};
