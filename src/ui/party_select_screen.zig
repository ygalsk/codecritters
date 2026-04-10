const std = @import("std");
const vaxis = @import("vaxis");
const critter_mod = @import("critter");
const species_mod = @import("species");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const input = @import("input.zig");

const Window = ui.Window;
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
    swap_mark: ?u8, // party slot index (0-2) being swapped

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
            .swap_mark = null,
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
        // Select if room and not unavailable (cooldown or fainted)
        if (self.select_count >= MAX_PARTY) return;
        if (idx >= self.roster.len) return;
        if (self.isUnavailable(idx)) return;

        for (&self.selected) |*maybe| {
            if (maybe.* == null) {
                maybe.* = idx;
                self.select_count += 1;
                return;
            }
        }
    }

    fn selectedSlot(self: *const PartySelectScreen, roster_idx: usize) ?u8 {
        for (self.selected, 0..) |maybe, i| {
            if (maybe) |s| {
                if (s == roster_idx) return @intCast(i);
            }
        }
        return null;
    }

    fn isUnavailable(self: *const PartySelectScreen, idx: usize) bool {
        if (idx >= self.roster.len) return false;
        return !self.roster[idx].isAvailable();
    }

    pub fn handleInput(self: *PartySelectScreen, key: vaxis.Key) void {
        self.dirty = true;
        const roster_len: u8 = @intCast(@min(self.roster.len, MAX_ROSTER));

        const action = input.applyCursor(&self.cursor, roster_len, input.menuNav(key));
        switch (action) {
            .confirm => self.toggleSelect(self.cursor),
            .back => {
                if (self.swap_mark != null) {
                    self.swap_mark = null;
                } else {
                    self.done = true;
                    self.confirmed = false;
                }
            },
            else => {
                if (key.matches('c', .{})) {
                    if (self.select_count > 0) {
                        self.done = true;
                        self.confirmed = true;
                    }
                } else if (key.matches('s', .{})) {
                    if (self.selectedSlot(self.cursor)) |slot| {
                        if (self.swap_mark) |mark| {
                            if (mark == slot) {
                                // Same slot — cancel
                                self.swap_mark = null;
                            } else {
                                // Swap the two selected slots
                                const tmp = self.selected[mark];
                                self.selected[mark] = self.selected[slot];
                                self.selected[slot] = tmp;
                                self.swap_mark = null;
                            }
                        } else {
                            self.swap_mark = slot;
                        }
                    }
                }
            },
        }
    }

    pub fn render(self: *const PartySelectScreen, win: Window) void {
        win.clear();
        if (layout.tooSmall(win, 40, 10)) return;

        _ = writeFmt(win, 2, 0, theme.heading, "Select Party ({d}/{d})", .{ self.select_count, MAX_PARTY });

        if (self.roster.len == 0) {
            _ = writeText(win, 2, 2, "No critters in roster!", theme.err);
            _ = writeText(win, 2, 4, "[Esc] Back", theme.hint);
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
            const unavail = self.isUnavailable(i);

            const marker: []const u8 = if (is_sel) "[*]" else "[ ]";
            const prefix: []const u8 = if (is_cur) "> " else "  ";

            var style: theme.Style = theme.body;
            if (unavail) {
                style = .{ .fg = theme.cooldown_dim };
            } else if (is_cur) {
                style = theme.heading;
            }

            var c = writeText(win, 2, row, prefix, style);
            c = writeText(win, c, row, marker, style);
            c = writeText(win, c, row, " ", style);
            c = writeText(win, c, row, name, style);
            c = writeFmt(win, c, row, style, " Lv{d}", .{critter.level});

            // Type badge
            if (sp) |s| {
                const type_color = theme.typeColor(s.critter_type);
                c = writeText(win, c, row, " ", style);
                c = writeText(win, c, row, s.critter_type.displayName(), .{ .fg = type_color, .bold = true });
            }

            // HP
            const eff_hp = critter.effectiveStat(.hp);
            const hp_color = theme.hpColor(critter.current_hp, eff_hp);
            c = writeFmt(win, c, row, .{ .fg = hp_color }, " HP {d}/{d}", .{ critter.current_hp, eff_hp });

            if (critter.cooldown_runs > 0) {
                _ = writeFmt(win, c, row, .{ .fg = theme.cooldown_red }, " [COOLDOWN {d} run(s)]", .{critter.cooldown_runs});
            } else if (critter.current_hp == 0) {
                _ = writeFmt(win, c, row, .{ .fg = theme.cooldown_red }, " [FAINTED]", .{});
            }

            row += 1;
        }

        // Selected party summary
        row += 1;
        if (row < win.height) {
            _ = writeText(win, 2, row, "Party:", theme.heading);
            row += 1;
        }
        for (self.selected, 0..) |maybe, slot_i| {
            if (maybe) |idx| {
                if (row >= win.height) break;
                if (idx < self.roster.len) {
                    const critter = &self.roster[idx];
                    const sp = if (idx < self.roster_species.len) self.roster_species[idx] else null;
                    const name = if (sp) |s| s.name else "???";
                    const is_swap_marked = if (self.swap_mark) |m| m == @as(u8, @intCast(slot_i)) else false;
                    const marker: []const u8 = if (is_swap_marked) "[S] " else "";
                    const style: theme.Style = if (is_swap_marked) .{ .fg = theme.gold, .bold = true } else .{ .fg = theme.party_green };
                    _ = writeFmt(win, 4, row, style, "{d}. {s}{s} Lv{d}", .{ slot_i + 1, marker, name, critter.level });
                    row += 1;
                }
            }
        }

        // Controls
        const hint = if (self.swap_mark != null)
            "[S] Swap With  [Esc] Cancel  [Enter] Toggle  [C] Confirm"
        else
            "[Enter] Toggle  [S] Swap Slot  [C] Confirm  [Esc] Back";
        widgets.renderHintAt(win, 2, hint);
    }
};
