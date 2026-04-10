const std = @import("std");
const vaxis = @import("vaxis");
const critter_mod = @import("critter");
const species_mod = @import("species");
const items_mod = @import("items");
const game_data_mod = @import("game_data");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const input = @import("input.zig");
const ScreenResult = @import("screen_result.zig").ScreenResult;

const Window = ui.Window;
const writeText = ui.writeText;
const writeFmt = ui.writeFmt;

pub const MAX_ROSTER = 64;
pub const MAX_PARTY = 3;
pub const MAX_PACK_SLOTS: u8 = 6;

pub const PackedItem = struct {
    item_id: []const u8,
    quantity: i64,
};

const Tab = enum { party, items };

pub const PartySelectScreen = struct {
    roster: []const critter_mod.Critter,
    roster_species: []const ?*const species_mod.Species,
    selected: [MAX_PARTY]?usize, // indices into roster
    select_count: u8,
    cursor: u8,
    scroll_offset: u8,
    dirty: bool,
    swap_mark: ?u8, // party slot index (0-2) being swapped

    // Item packing
    tab: Tab,
    inventory: []const ui.InventoryEntry,
    game_data: *const game_data_mod.GameData,
    packed_items: [MAX_PACK_SLOTS]?PackedItem,
    pack_count: u8,
    item_cursor: u8,
    item_scroll: u8,

    pub fn init(
        roster: []const critter_mod.Critter,
        roster_species: []const ?*const species_mod.Species,
        inventory: []const ui.InventoryEntry,
        game_data: *const game_data_mod.GameData,
    ) PartySelectScreen {
        return .{
            .roster = roster,
            .roster_species = roster_species,
            .selected = .{ null, null, null },
            .select_count = 0,
            .cursor = 0,
            .scroll_offset = 0,
            .dirty = true,
            .swap_mark = null,
            .tab = .party,
            .inventory = inventory,
            .game_data = game_data,
            .packed_items = .{null} ** MAX_PACK_SLOTS,
            .pack_count = 0,
            .item_cursor = 0,
            .item_scroll = 0,
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

    // ─── Input ───

    pub fn handleInput(self: *PartySelectScreen, key: vaxis.Key) ?ScreenResult {
        self.dirty = true;

        // Tab switching
        if (key.matches('i', .{}) or key.matches(vaxis.Key.tab, .{})) {
            self.tab = if (self.tab == .party) .items else .party;
            return null;
        }

        return switch (self.tab) {
            .party => self.handlePartyInput(key),
            .items => self.handleItemsInput(key),
        };
    }

    fn handlePartyInput(self: *PartySelectScreen, key: vaxis.Key) ?ScreenResult {
        const roster_len: u8 = @intCast(@min(self.roster.len, MAX_ROSTER));

        const action = input.applyCursor(&self.cursor, roster_len, input.menuNav(key));
        switch (action) {
            .confirm => self.toggleSelect(self.cursor),
            .back => {
                if (self.swap_mark != null) {
                    self.swap_mark = null;
                } else {
                    return .goto_hub;
                }
            },
            else => {
                if (key.matches('c', .{})) {
                    if (self.select_count > 0) {
                        return .goto_dungeon;
                    }
                } else if (key.matches('s', .{})) {
                    if (self.selectedSlot(self.cursor)) |slot| {
                        if (self.swap_mark) |mark| {
                            if (mark == slot) {
                                self.swap_mark = null;
                            } else {
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
        return null;
    }

    fn handleItemsInput(self: *PartySelectScreen, key: vaxis.Key) ?ScreenResult {
        const total = self.countValidItems();
        if (total == 0) {
            const action = input.applyCursor(&self.item_cursor, 0, input.menuNav(key));
            if (action == .back) self.tab = .party;
            return null;
        }

        const action = input.applyCursor(&self.item_cursor, total, input.menuNav(key));
        switch (action) {
            .confirm => self.togglePackItem(),
            .back => self.tab = .party,
            else => {},
        }
        return null;
    }

    // ─── Item packing ───

    fn countValidItems(self: *const PartySelectScreen) u8 {
        var count: u8 = 0;
        for (self.inventory) |e| {
            if (e.quantity > 0 and self.game_data.findItem(e.item_id) != null) count += 1;
        }
        return count;
    }

    fn togglePackItem(self: *PartySelectScreen) void {
        const entry = self.lookupItemIdx(self.item_cursor) orelse return;

        // Check if already packed — unpack it
        for (&self.packed_items) |*slot| {
            if (slot.*) |pack_entry| {
                if (std.mem.eql(u8, pack_entry.item_id, entry.item_id)) {
                    slot.* = null;
                    self.pack_count -= 1;
                    return;
                }
            }
        }

        // Not packed yet — add if room
        if (self.pack_count >= MAX_PACK_SLOTS) return;
        for (&self.packed_items) |*slot| {
            if (slot.* == null) {
                slot.* = .{ .item_id = entry.item_id, .quantity = entry.quantity };
                self.pack_count += 1;
                return;
            }
        }
    }

    fn lookupItemIdx(self: *const PartySelectScreen, target: u8) ?*const ui.InventoryEntry {
        var idx: u8 = 0;
        for (self.inventory) |*entry| {
            if (entry.quantity <= 0) continue;
            if (self.game_data.findItem(entry.item_id) == null) continue;
            if (idx == target) return entry;
            idx += 1;
        }
        return null;
    }

    fn isItemPacked(self: *const PartySelectScreen, item_id: []const u8) bool {
        for (self.packed_items) |maybe| {
            if (maybe) |pack_entry| {
                if (std.mem.eql(u8, pack_entry.item_id, item_id)) return true;
            }
        }
        return false;
    }

    // ─── Rendering ───

    pub fn render(self: *PartySelectScreen, win: Window) void {
        win.clear();
        if (layout.tooSmall(win, 40, 10)) return;

        switch (self.tab) {
            .party => self.renderParty(win),
            .items => self.renderItems(win),
        }
    }

    fn renderParty(self: *PartySelectScreen, win: Window) void {
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
        if (self.cursor < self.scroll_offset) self.scroll_offset = self.cursor;
        if (self.cursor >= self.scroll_offset + list_height) self.scroll_offset = self.cursor - list_height + 1;

        var row: u16 = 2;
        var i: u8 = self.scroll_offset;
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

        // Pack summary (compact)
        if (self.pack_count > 0) {
            row += 1;
            if (row < win.height) {
                _ = writeFmt(win, 2, row, theme.heading, "Packed: {d}/{d} items", .{ self.pack_count, MAX_PACK_SLOTS });
            }
        }

        // Controls
        const hint = if (self.swap_mark != null)
            "[S] Swap With  [Esc] Cancel  [Enter] Toggle  [C] Confirm"
        else
            "[Enter] Toggle  [S] Swap  [I] Pack Items  [C] Confirm  [Esc] Back";
        widgets.renderHintAt(win, 2, hint);
    }

    fn renderItems(self: *PartySelectScreen, win: Window) void {
        _ = writeFmt(win, 2, 0, theme.heading, "Pack Items ({d}/{d})", .{ self.pack_count, MAX_PACK_SLOTS });

        // Compact party summary on line 1
        var c: u16 = 2;
        c = writeText(win, c, 1, "Party: ", .{ .fg = theme.muted });
        for (self.selected) |maybe| {
            if (maybe) |idx| {
                if (idx < self.roster.len) {
                    const sp = if (idx < self.roster_species.len) self.roster_species[idx] else null;
                    const name = if (sp) |s| s.name else "???";
                    c = writeText(win, c, 1, name, .{ .fg = theme.party_green });
                    c = writeText(win, c, 1, "  ", theme.body);
                }
            }
        }

        const total = self.countValidItems();
        if (total == 0) {
            _ = writeText(win, 2, 3, "No items in inventory.", .{ .fg = theme.muted, .italic = true });
            widgets.renderHintAt(win, 2, "[I/Tab] Party  [Esc] Back to Party");
            return;
        }

        // Scrollable item list starting at row 3
        const list_height: u8 = @intCast(@min(win.height -| 8, 16));
        if (self.item_cursor < self.item_scroll) self.item_scroll = self.item_cursor;
        if (self.item_cursor >= self.item_scroll + list_height) self.item_scroll = self.item_cursor - list_height + 1;

        var row: u16 = 3;
        var display_idx: u8 = 0;
        for (self.inventory) |entry| {
            if (entry.quantity <= 0) continue;
            const item = self.game_data.findItem(entry.item_id) orelse continue;

            if (display_idx < self.item_scroll) {
                display_idx += 1;
                continue;
            }
            if (row >= 3 + @as(u16, list_height)) break;

            const is_cur = self.item_cursor == display_idx;
            const is_packed = self.isItemPacked(entry.item_id);

            const marker: []const u8 = if (is_packed) "[*]" else "[ ]";
            const prefix: []const u8 = if (is_cur) "> " else "  ";

            var style: theme.Style = if (is_cur) theme.heading else theme.body;
            if (is_packed) style = .{ .fg = theme.party_green, .bold = true };

            var col = writeText(win, 2, row, prefix, style);
            col = writeText(win, col, row, marker, style);
            col = writeText(win, col, row, " ", style);
            col = writeText(win, col, row, item.name, style);
            _ = writeFmt(win, col, row, style, "  x{d}", .{entry.quantity});

            row += 1;
            display_idx += 1;
        }

        // Packed items summary at bottom
        row = win.height -| (2 + @as(u16, self.pack_count));
        if (self.pack_count > 0 and row > 3 + @as(u16, list_height)) {
            _ = writeText(win, 2, row, "Packed:", theme.heading);
            row += 1;
            for (self.packed_items) |maybe| {
                if (maybe) |pack_entry| {
                    const item = self.game_data.findItem(pack_entry.item_id) orelse continue;
                    _ = writeFmt(win, 4, row, .{ .fg = theme.party_green }, "{s} x{d}", .{ item.name, pack_entry.quantity });
                    row += 1;
                }
            }
        }

        widgets.renderHintAt(win, 2, "[Enter] Toggle  [I/Tab] Party  [Esc] Back to Party");
    }
};
