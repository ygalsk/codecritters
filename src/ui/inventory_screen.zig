const std = @import("std");
const vaxis = @import("vaxis");
const items_mod = @import("items");
const critter_mod = @import("critter");
const species_mod = @import("species");
const game_data_mod = @import("game_data");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const input = @import("input.zig");

const Window = ui.Window;
const writeText = ui.writeText;
const writeFmt = ui.writeFmt;

pub const InventoryEntry = struct {
    item_id: []const u8,
    quantity: i64,
};

pub const ItemUseResult = struct {
    item_id: []const u8,
    target_idx: u8,
    heal_amount: u16,
};

const Mode = enum {
    browsing,
    select_target,
};

pub const InventoryScreen = struct {
    entries: []InventoryEntry,
    game_data: *const game_data_mod.GameData,
    currency: u32,
    cursor: u8,
    total_count: u8,
    done: bool,
    dirty: bool,
    mode: Mode,
    pending_item_idx: u8,
    target_cursor: u8,
    roster: []critter_mod.Critter,
    roster_species: []const ?*const species_mod.Species,
    use_result: ?ItemUseResult,

    pub fn init(
        entries: []InventoryEntry,
        game_data: *const game_data_mod.GameData,
        currency: u32,
        roster: []critter_mod.Critter,
        roster_species: []const ?*const species_mod.Species,
    ) InventoryScreen {
        var count: u8 = 0;
        for (entries) |entry| {
            if (game_data.findItem(entry.item_id) != null) count += 1;
        }
        return .{
            .entries = entries,
            .game_data = game_data,
            .currency = currency,
            .cursor = 0,
            .total_count = count,
            .done = false,
            .dirty = true,
            .mode = .browsing,
            .pending_item_idx = 0,
            .target_cursor = 0,
            .roster = roster,
            .roster_species = roster_species,
            .use_result = null,
        };
    }

    pub fn handleInput(self: *InventoryScreen, key: vaxis.Key) void {
        self.dirty = true;
        switch (self.mode) {
            .browsing => self.handleBrowsing(key),
            .select_target => self.handleSelectTarget(key),
        }
    }

    fn handleBrowsing(self: *InventoryScreen, key: vaxis.Key) void {
        const action = input.applyCursor(&self.cursor, self.total_count, input.menuNav(key));
        switch (action) {
            .back => {
                self.done = true;
            },
            .confirm => {
                if (self.lookupDisplayIdx(self.cursor)) |lookup| {
                    const item = lookup.item;
                    if (item.kind == .healing or item.kind == .revive) {
                        if (self.hasValidTarget(item)) {
                            self.pending_item_idx = self.cursor;
                            self.target_cursor = 0;
                            self.mode = .select_target;
                        }
                    }
                }
            },
            else => {},
        }
    }

    fn handleSelectTarget(self: *InventoryScreen, key: vaxis.Key) void {
        const roster_len: u8 = @intCast(@min(self.roster.len, 255));
        const action = input.applyCursor(&self.target_cursor, roster_len, input.menuNav(key));
        switch (action) {
            .back => {
                self.mode = .browsing;
            },
            .confirm => {
                const lookup = self.lookupDisplayIdx(self.pending_item_idx) orelse return;
                const item = lookup.item;
                const idx = self.target_cursor;
                if (idx >= self.roster.len) return;
                if (!self.isValidTarget(item, idx)) return;

                // Apply the effect
                const critter = &self.roster[idx];
                var heal_amount: u16 = 0;

                if (item.kind == .healing) {
                    const heal = item.heal_amount orelse return;
                    const max_hp = critter.effectiveStat(.hp);
                    const old_hp = critter.current_hp;
                    critter.current_hp = @min(max_hp, old_hp + heal);
                    heal_amount = critter.current_hp - old_hp;
                } else if (item.kind == .revive) {
                    const pct = item.revive_percent orelse 50;
                    const max_hp = critter.effectiveStat(.hp);
                    const restore = @max(1, @as(u16, max_hp) * pct / 100);
                    critter.current_hp = restore;
                    heal_amount = restore;
                }

                self.use_result = .{
                    .item_id = item.id,
                    .target_idx = idx,
                    .heal_amount = heal_amount,
                };

                // Decrement local quantity for display
                self.entries[lookup.entry_idx].quantity -= 1;
                if (self.entries[lookup.entry_idx].quantity <= 0) {
                    self.total_count -|= 1;
                    if (self.cursor >= self.total_count and self.total_count > 0) {
                        self.cursor = self.total_count - 1;
                    }
                }

                self.mode = .browsing;
            },
            else => {},
        }
    }

    pub fn render(self: *const InventoryScreen, win: Window) void {
        win.clear();
        if (layout.tooSmall(win, 30, 10)) return;

        switch (self.mode) {
            .browsing => self.renderBrowsing(win),
            .select_target => self.renderTargetSelect(win),
        }
    }

    fn renderBrowsing(self: *const InventoryScreen, win: Window) void {
        // Title
        _ = writeText(win, 2, 1, "Inventory", theme.title);
        _ = writeFmt(win, 14, 1, theme.currency, "  ${d}", .{self.currency});

        var row: u16 = 3;
        var display_idx: u8 = 0;

        // Catch Tools
        if (self.hasCategoryItems(.catch_tool)) {
            _ = writeText(win, 2, row, "Catch Tools", theme.category);
            row += 1;
            row = self.renderCategory(win, row, .catch_tool, &display_idx);
            row += 1;
        }

        // Healing Items
        if (self.hasCategoryItems(.healing)) {
            _ = writeText(win, 2, row, "Healing Items", theme.category);
            row += 1;
            row = self.renderCategory(win, row, .healing, &display_idx);
            row += 1;
        }

        // Revive Items
        if (self.hasCategoryItems(.revive)) {
            _ = writeText(win, 2, row, "Revive Items", theme.category);
            row += 1;
            row = self.renderCategory(win, row, .revive, &display_idx);
            row += 1;
        }

        // Move Discs
        if (self.hasCategoryItems(.move_disc)) {
            _ = writeText(win, 2, row, "Move Discs", theme.category);
            row += 1;
            row = self.renderCategory(win, row, .move_disc, &display_idx);
            row += 1;
        }

        if (display_idx == 0) {
            _ = writeText(win, 2, row, "(empty)", .{ .fg = theme.muted, .italic = true });
        }

        // Controls hint
        widgets.renderHintAt(win, 2, "[Up/Down] Navigate  [Enter] Use  [Esc] Back");
    }

    fn renderTargetSelect(self: *const InventoryScreen, win: Window) void {
        const item = if (self.lookupDisplayIdx(self.pending_item_idx)) |l| l.item else return;

        _ = writeText(win, 2, 1, "Use: ", theme.title);
        _ = writeText(win, 7, 1, item.name, theme.title);

        const prompt: []const u8 = if (item.kind == .revive) "Choose a fainted critter:" else "Choose a critter to heal:";
        _ = writeText(win, 2, 3, prompt, theme.category);

        var row: u16 = 5;
        for (self.roster, 0..) |critter, i| {
            const sp = if (i < self.roster_species.len) self.roster_species[i] else null;
            const name = if (critter.nickname) |n| n else if (sp) |s| s.name else "???";
            const is_sel = self.target_cursor == @as(u8, @intCast(i));
            const valid = self.isValidTarget(item, @intCast(i));

            const style: theme.Style = if (is_sel and valid)
                theme.selected
            else if (valid)
                theme.unselected
            else
                .{ .fg = theme.muted };

            const prefix: []const u8 = if (is_sel) "> " else "  ";
            var c = writeText(win, 2, row, prefix, style);
            c = writeText(win, c, row, name, style);

            const max_hp = critter.effectiveStat(.hp);
            c = writeFmt(win, c, row, style, "  Lv{d}", .{critter.level});
            if (critter.current_hp == 0) {
                _ = writeFmt(win, c, row, .{ .fg = theme.cooldown_red }, "  FAINTED", .{});
            } else {
                _ = writeFmt(win, c, row, style, "  {d}/{d} HP", .{ critter.current_hp, max_hp });
            }

            row += 1;
        }

        widgets.renderHintAt(win, 2, "[Up/Down] Navigate  [Enter] Confirm  [Esc] Cancel");
    }

    fn renderCategory(self: *const InventoryScreen, win: Window, start_row: u16, kind: items_mod.ItemKind, display_idx: *u8) u16 {
        var row = start_row;
        for (self.entries) |entry| {
            if (entry.quantity <= 0) continue;
            const item = self.game_data.findItem(entry.item_id) orelse continue;
            if (item.kind != kind) continue;

            const is_sel = self.cursor == display_idx.*;
            const style: theme.Style = if (is_sel) theme.selected else theme.unselected;

            const prefix: []const u8 = if (is_sel) "> " else "  ";
            var c = writeText(win, 2, row, prefix, style);
            c = writeText(win, c, row, item.name, style);
            c = writeFmt(win, c, row, style, "  x{d}", .{entry.quantity});

            // Show extra info for catch tools
            if (kind == .catch_tool) {
                if (item.base_catch_rate) |rate| {
                    _ = writeFmt(win, c, row, .{ .fg = theme.info_gray }, "  ({d}%)", .{rate});
                }
            } else if (kind == .healing) {
                if (item.heal_amount) |heal| {
                    _ = writeFmt(win, c, row, .{ .fg = theme.info_gray }, "  (+{d} HP)", .{heal});
                }
            } else if (kind == .revive) {
                if (item.revive_percent) |pct| {
                    _ = writeFmt(win, c, row, .{ .fg = theme.info_gray }, "  ({d}%)", .{pct});
                }
            }

            row += 1;
            display_idx.* += 1;
        }
        return row;
    }

    fn hasCategoryItems(self: *const InventoryScreen, kind: items_mod.ItemKind) bool {
        for (self.entries) |entry| {
            if (entry.quantity <= 0) continue;
            const item = self.game_data.findItem(entry.item_id) orelse continue;
            if (item.kind == kind) return true;
        }
        return false;
    }

    const DisplayLookup = struct {
        item: *const items_mod.Item,
        entry_idx: usize,
    };

    fn lookupDisplayIdx(self: *const InventoryScreen, target_idx: u8) ?DisplayLookup {
        var display_idx: u8 = 0;
        for (self.entries, 0..) |entry, i| {
            if (entry.quantity <= 0) continue;
            const item = self.game_data.findItem(entry.item_id) orelse continue;
            if (display_idx == target_idx) return .{ .item = item, .entry_idx = i };
            display_idx += 1;
        }
        return null;
    }

    fn hasValidTarget(self: *const InventoryScreen, item: *const items_mod.Item) bool {
        for (self.roster, 0..) |_, i| {
            if (self.isValidTarget(item, @intCast(i))) return true;
        }
        return false;
    }

    fn isValidTarget(self: *const InventoryScreen, item: *const items_mod.Item, idx: u8) bool {
        if (idx >= self.roster.len) return false;
        const critter = self.roster[idx];
        if (item.kind == .healing) {
            return critter.current_hp > 0 and critter.current_hp < critter.effectiveStat(.hp);
        } else if (item.kind == .revive) {
            return critter.current_hp == 0;
        }
        return false;
    }
};
