const std = @import("std");
const vaxis = @import("vaxis");
const critter_mod = @import("critter");
const species_mod = @import("species");
const items_mod = @import("items");
const game_data_mod = @import("game_data");
const colors = @import("colors.zig");
const ui = @import("ui_common.zig");

const Window = ui.Window;
const Style = ui.Style;
const Key = ui.Key;
const writeText = ui.writeText;
const writeFmt = ui.writeFmt;

pub const MAX_DISCS = 16;

const ViewMode = enum {
    browsing,
    equip_disc,
};

pub const DiscEquipEvent = struct {
    critter_idx: u8,
    item_id: []const u8,
};

pub const RosterScreen = struct {
    roster: []critter_mod.Critter,
    roster_species: []const ?*const species_mod.Species,
    inventory: []const InventoryEntry,
    game_data: *const game_data_mod.GameData,
    cursor: u8,
    mode: ViewMode,
    disc_cursor: u8,
    disc_count: u8,
    disc_ids: [MAX_DISCS][]const u8,
    done: bool,
    dirty: bool,
    log: ui.MessageLog,
    pending_equip: ?DiscEquipEvent,
    current_time: i64,

    pub const InventoryEntry = struct {
        item_id: []const u8,
        quantity: i64,
    };

    pub fn init(
        roster: []critter_mod.Critter,
        roster_species: []const ?*const species_mod.Species,
        inventory: []const InventoryEntry,
        game_data: *const game_data_mod.GameData,
    ) RosterScreen {
        var screen = RosterScreen{
            .roster = roster,
            .roster_species = roster_species,
            .inventory = inventory,
            .game_data = game_data,
            .cursor = 0,
            .mode = .browsing,
            .disc_cursor = 0,
            .disc_count = 0,
            .disc_ids = undefined,
            .done = false,
            .dirty = true,
            .log = ui.MessageLog.init(),
            .pending_equip = null,
            .current_time = std.time.timestamp(),
        };
        screen.buildDiscList();
        return screen;
    }

    fn buildDiscList(self: *RosterScreen) void {
        self.disc_count = 0;
        for (self.inventory) |entry| {
            if (entry.quantity <= 0) continue;
            const item = self.game_data.findItem(entry.item_id) orelse continue;
            if (item.kind == .move_disc) {
                if (self.disc_count < MAX_DISCS) {
                    self.disc_ids[self.disc_count] = entry.item_id;
                    self.disc_count += 1;
                }
            }
        }
    }

    pub fn handleInput(self: *RosterScreen, key: vaxis.Key) void {
        self.dirty = true;
        switch (self.mode) {
            .browsing => self.handleBrowsing(key),
            .equip_disc => self.handleEquipDisc(key),
        }
    }

    fn handleBrowsing(self: *RosterScreen, key: vaxis.Key) void {
        const roster_len: u8 = @intCast(@min(self.roster.len, 255));
        if (key.matches(Key.left, .{})) {
            if (self.cursor > 0) self.cursor -= 1;
        } else if (key.matches(Key.right, .{})) {
            if (self.cursor + 1 < roster_len) self.cursor += 1;
        } else if (key.matches('d', .{})) {
            if (self.disc_count > 0 and self.roster.len > 0) {
                self.mode = .equip_disc;
                self.disc_cursor = 0;
            }
        } else if (key.matches(Key.escape, .{}) or key.matches(Key.backspace, .{})) {
            self.done = true;
        }
    }

    fn handleEquipDisc(self: *RosterScreen, key: vaxis.Key) void {
        if (key.matches(Key.up, .{})) {
            if (self.disc_cursor > 0) self.disc_cursor -= 1;
        } else if (key.matches(Key.down, .{})) {
            if (self.disc_cursor + 1 < self.disc_count) self.disc_cursor += 1;
        } else if (key.matches(Key.enter, .{}) or key.matches(' ', .{})) {
            self.doEquip();
        } else if (key.matches(Key.escape, .{}) or key.matches(Key.backspace, .{})) {
            self.mode = .browsing;
        }
    }

    fn doEquip(self: *RosterScreen) void {
        if (self.cursor >= self.roster.len) return;
        if (self.disc_cursor >= self.disc_count) return;

        const disc_item_id = self.disc_ids[self.disc_cursor];
        const item = self.game_data.findItem(disc_item_id) orelse return;
        if (item.kind != .move_disc) return;
        const move_id = item.move_id orelse return;

        // Apply equip to critter
        self.roster[self.cursor].move_slot_3 = move_id;

        // Store pending equip event for main.zig to persist
        self.pending_equip = .{
            .critter_idx = self.cursor,
            .item_id = disc_item_id,
        };

        var buf: [ui.MSG_BUF_LEN]u8 = undefined;
        const move = self.game_data.findMove(move_id);
        const move_name = if (move) |m| m.name else move_id;
        const msg = std.fmt.bufPrint(&buf, "Equipped {s}!", .{move_name}) catch "Equipped move!";
        self.log.push(msg);

        self.mode = .browsing;
    }

    pub fn render(self: *const RosterScreen, win: Window) void {
        win.clear();
        if (win.height < 12 or win.width < 40) {
            _ = writeText(win, 0, 0, "Terminal too small", .{ .fg = .{ .rgb = .{ 255, 60, 60 } } });
            return;
        }

        const white_bold: Style = .{ .fg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true };
        const header_style: Style = .{ .fg = .{ .rgb = .{ 180, 180, 180 } } };

        if (self.roster.len == 0) {
            _ = writeText(win, 2, 0, "Roster", white_bold);
            _ = writeText(win, 2, 2, "No critters yet!", .{ .fg = .{ .rgb = .{ 255, 100, 100 } } });
            _ = writeText(win, 2, 4, "[Esc] Back", ui.dim_style);
            return;
        }

        // Navigation indicator
        _ = writeFmt(win, 2, 0, white_bold, "Roster ({d}/{d})", .{ @as(u16, self.cursor) + 1, @as(u16, @intCast(self.roster.len)) });

        const critter = &self.roster[self.cursor];
        const sp = if (self.cursor < self.roster_species.len) self.roster_species[self.cursor] else null;
        const name = if (sp) |s| s.name else "???";

        // Name and level
        var row: u16 = 2;
        const c = writeText(win, 2, row, name, white_bold);
        _ = writeFmt(win, c, row, white_bold, "  Lv{d}", .{critter.level});
        row += 1;

        // Type badge
        if (sp) |s| {
            const type_color = colors.typeColor(s.critter_type);
            _ = writeText(win, 2, row, s.critter_type.displayName(), .{ .fg = type_color, .bold = true });
        }
        row += 1;

        // XP progress
        if (critter.level < 100) {
            const leveling = @import("leveling");
            const current_xp = critter.xp;
            const next_level_xp = leveling.xpForLevel(critter.level + 1);
            const prev_level_xp = if (critter.level > 0) leveling.xpForLevel(critter.level) else 0;
            const xp_into_level = current_xp -| prev_level_xp;
            const xp_needed = next_level_xp -| prev_level_xp;
            _ = writeFmt(win, 2, row, header_style, "XP: {d}/{d} to Lv{d}", .{ xp_into_level, xp_needed, critter.level + 1 });
        } else {
            _ = writeText(win, 2, row, "XP: MAX LEVEL", header_style);
        }
        row += 1;

        // Stats
        row += 1;
        _ = writeText(win, 2, row, "Stats:", header_style);
        row += 1;

        const hp_color = colors.hpColor(critter.current_hp, critter.max_hp);
        _ = writeFmt(win, 4, row, .{ .fg = hp_color }, "HP:      {d}/{d}", .{ critter.current_hp, critter.max_hp });
        self.renderScarNote(win, critter, .hp, row);
        row += 1;
        _ = writeFmt(win, 4, row, header_style, "Logic:   {d}", .{critter.logic});
        self.renderScarNote(win, critter, .logic, row);
        row += 1;
        _ = writeFmt(win, 4, row, header_style, "Resolve: {d}", .{critter.resolve});
        self.renderScarNote(win, critter, .resolve, row);
        row += 1;
        _ = writeFmt(win, 4, row, header_style, "Speed:   {d}", .{critter.speed});
        self.renderScarNote(win, critter, .speed, row);
        row += 1;

        // Moves
        row += 1;
        _ = writeText(win, 2, row, "Moves:", header_style);
        row += 1;
        self.renderMoveSlot(win, critter.move_slot_1, "1", row);
        row += 1;
        self.renderMoveSlot(win, critter.move_slot_2, "2", row);
        row += 1;
        self.renderMoveSlot(win, critter.move_slot_3, "3", row);
        row += 1;

        // Cooldown
        if (critter.cooldown_until) |cd| {
            if (cd > self.current_time) {
                row += 1;
                const remaining = cd - self.current_time;
                const mins = @divFloor(remaining, 60);
                _ = writeFmt(win, 2, row, .{ .fg = .{ .rgb = .{ 255, 100, 100 } } }, "COOLDOWN: {d}m remaining", .{mins});
                row += 1;
            }
        }

        // Scars
        if (critter.scars.len > 0) {
            row += 1;
            _ = writeFmt(win, 2, row, .{ .fg = .{ .rgb = .{ 200, 100, 100 } } }, "Scars: {d}", .{critter.scars.len});
            row += 1;
        }

        // Message log
        if (self.log.msg_count > 0) {
            row += 1;
            self.log.render(win, row, 2);
        }

        // Equip disc overlay
        if (self.mode == .equip_disc) {
            self.renderDiscOverlay(win);
        }

        // Controls
        const ctrl_row: u16 = if (win.height > 2) win.height - 2 else win.height;
        if (ctrl_row < win.height) {
            const hint = switch (self.mode) {
                .browsing => "[Left/Right] Browse  [D] Equip Disc  [Esc] Back",
                .equip_disc => "[Up/Down] Select  [Enter] Equip  [Esc] Cancel",
            };
            _ = writeText(win, 2, ctrl_row, hint, ui.dim_style);
        }
    }

    fn renderScarNote(self: *const RosterScreen, win: Window, critter: *const critter_mod.Critter, stat: critter_mod.StatKind, row: u16) void {
        _ = self;
        var total: i16 = 0;
        for (critter.scars) |scar| {
            if (scar.stat == stat) total += scar.amount;
        }
        if (total != 0) {
            _ = writeFmt(win, 22, row, .{ .fg = .{ .rgb = .{ 255, 80, 80 } } }, " ({d})", .{total});
        }
    }

    fn renderMoveSlot(self: *const RosterScreen, win: Window, slot: ?[]const u8, label: []const u8, row: u16) void {
        if (slot) |move_id| {
            const move = self.game_data.findMove(move_id);
            if (move) |m| {
                var c = writeFmt(win, 4, row, .{ .fg = .{ .rgb = .{ 200, 200, 200 } } }, "{s}. {s}", .{ label, m.name });
                const type_color = colors.typeColor(m.move_type);
                c = writeText(win, c, row, " ", .{});
                c = writeText(win, c, row, m.move_type.displayName(), .{ .fg = type_color });
                _ = writeFmt(win, c, row, .{ .fg = .{ .rgb = .{ 150, 150, 150 } } }, " pow:{d} acc:{d}%", .{ m.power, m.accuracy });
            } else {
                _ = writeFmt(win, 4, row, .{ .fg = .{ .rgb = .{ 150, 150, 150 } } }, "{s}. {s}", .{ label, move_id });
            }
        } else {
            _ = writeFmt(win, 4, row, .{ .fg = .{ .rgb = .{ 80, 80, 80 } } }, "{s}. (empty)", .{label});
        }
    }

    fn renderDiscOverlay(self: *const RosterScreen, win: Window) void {
        // Draw disc selection overlay on the right side
        const box_w: u16 = 30;
        const box_x: u16 = if (win.width > box_w + 2) win.width - box_w - 2 else 0;
        const box_y: u16 = 2;

        _ = writeText(win, box_x, box_y, "Equip Move Disc:", .{ .fg = .{ .rgb = .{ 255, 200, 40 } }, .bold = true });

        var row = box_y + 1;
        var i: u8 = 0;
        while (i < self.disc_count) : (i += 1) {
            if (row >= win.height -| 3) break;
            const item = self.game_data.findItem(self.disc_ids[i]) orelse continue;
            const selected = self.disc_cursor == i;
            const prefix: []const u8 = if (selected) "> " else "  ";
            const style: Style = if (selected)
                .{ .fg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true }
            else
                .{ .fg = .{ .rgb = .{ 180, 180, 180 } } };

            var c = writeText(win, box_x, row, prefix, style);
            c = writeText(win, c, row, item.name, style);

            // Show quantity
            for (self.inventory) |entry| {
                if (std.mem.eql(u8, entry.item_id, self.disc_ids[i])) {
                    _ = writeFmt(win, c, row, style, " x{d}", .{entry.quantity});
                    break;
                }
            }
            row += 1;
        }

        if (self.disc_count == 0) {
            _ = writeText(win, box_x + 2, row, "(no discs available)", .{ .fg = .{ .rgb = .{ 100, 100, 100 } } });
        }
    }
};
