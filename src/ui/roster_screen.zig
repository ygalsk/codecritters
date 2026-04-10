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
const anim_mod = @import("anim.zig");
const sprite_mod = @import("sprite.zig");

const Window = ui.Window;
const writeText = ui.writeText;
const writeFmt = ui.writeFmt;

pub const MAX_DISCS = 16;

const ViewMode = enum {
    browsing,
    equip_disc,
    swapping,
};

pub const DiscEquipEvent = struct {
    critter_idx: u8,
    item_id: []const u8,
};

pub const SwapEvent = struct {
    id_a: u64,
    id_b: u64,
};

pub const RosterScreen = struct {
    roster: []critter_mod.Critter,
    roster_species: []?*const species_mod.Species,
    inventory: []const InventoryEntry,
    game_data: *const game_data_mod.GameData,
    sprite_map: *const sprite_mod.SpriteMap,
    use_kitty: bool,
    cursor: u8,
    mode: ViewMode,
    disc_cursor: u8,
    disc_count: u8,
    disc_ids: [MAX_DISCS][]const u8,
    done: bool,
    dirty: bool,
    log: ui.MessageLog,
    pending_equip: ?DiscEquipEvent,
    pending_swap: ?SwapEvent,
    swap_origin: ?u8,
    anim_timer: anim_mod.AnimTimer,

    pub const InventoryEntry = struct {
        item_id: []const u8,
        quantity: i64,
    };

    pub fn init(
        roster: []critter_mod.Critter,
        roster_species: []?*const species_mod.Species,
        inventory: []const InventoryEntry,
        game_data: *const game_data_mod.GameData,
        sprite_map: *const sprite_mod.SpriteMap,
        use_kitty: bool,
    ) RosterScreen {
        var screen = RosterScreen{
            .roster = roster,
            .roster_species = roster_species,
            .inventory = inventory,
            .game_data = game_data,
            .sprite_map = sprite_map,
            .use_kitty = use_kitty,
            .cursor = 0,
            .mode = .browsing,
            .disc_cursor = 0,
            .disc_count = 0,
            .disc_ids = undefined,
            .done = false,
            .dirty = true,
            .log = ui.MessageLog.init(),
            .pending_equip = null,
            .pending_swap = null,
            .swap_origin = null,
            .anim_timer = anim_mod.AnimTimer.init(500),
        };
        screen.buildDiscList();
        return screen;
    }

    pub fn updateAnimation(self: *RosterScreen) void {
        if (self.anim_timer.tick()) self.dirty = true;
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
            .swapping => self.handleSwapping(key),
        }
    }

    fn handleBrowsing(self: *RosterScreen, key: vaxis.Key) void {
        const roster_len: u8 = @intCast(@min(self.roster.len, 255));
        if (key.matches(vaxis.Key.left, .{})) {
            if (self.cursor > 0) self.cursor -= 1;
        } else if (key.matches(vaxis.Key.right, .{})) {
            if (self.cursor + 1 < roster_len) self.cursor += 1;
        } else if (key.matches('d', .{})) {
            if (self.disc_count > 0 and self.roster.len > 0) {
                self.mode = .equip_disc;
                self.disc_cursor = 0;
            }
        } else if (key.matches('s', .{})) {
            if (roster_len > 1) {
                self.mode = .swapping;
                self.swap_origin = self.cursor;
            }
        } else if (key.matches(vaxis.Key.escape, .{}) or key.matches(vaxis.Key.backspace, .{})) {
            self.done = true;
        }
    }

    fn handleSwapping(self: *RosterScreen, key: vaxis.Key) void {
        const roster_len: u8 = @intCast(@min(self.roster.len, 255));
        if (key.matches(vaxis.Key.left, .{})) {
            if (self.cursor > 0) self.cursor -= 1;
        } else if (key.matches(vaxis.Key.right, .{})) {
            if (self.cursor + 1 < roster_len) self.cursor += 1;
        } else if (key.matches('s', .{}) or key.matches(vaxis.Key.enter, .{}) or key.matches(vaxis.Key.space, .{})) {
            const origin = self.swap_origin orelse {
                self.mode = .browsing;
                return;
            };
            if (self.cursor != origin) {
                // Perform the swap
                const id_a = self.roster[origin].id;
                const id_b = self.roster[self.cursor].id;

                const tmp_critter = self.roster[origin];
                self.roster[origin] = self.roster[self.cursor];
                self.roster[self.cursor] = tmp_critter;

                const tmp_species = self.roster_species[origin];
                self.roster_species[origin] = self.roster_species[self.cursor];
                self.roster_species[self.cursor] = tmp_species;

                self.pending_swap = .{
                    .id_a = id_a,
                    .id_b = id_b,
                };

                self.log.push("Swapped positions!");
            }
            self.swap_origin = null;
            self.mode = .browsing;
        } else if (key.matches(vaxis.Key.escape, .{}) or key.matches(vaxis.Key.backspace, .{})) {
            self.swap_origin = null;
            self.mode = .browsing;
        }
    }

    fn handleEquipDisc(self: *RosterScreen, key: vaxis.Key) void {
        const action = input.applyCursor(&self.disc_cursor, self.disc_count, input.menuNav(key));
        switch (action) {
            .confirm => self.doEquip(),
            .back => self.mode = .browsing,
            else => {},
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
        if (layout.tooSmall(win, 40, 12)) return;

        if (self.roster.len == 0) {
            _ = writeText(win, 2, 0, "Roster", theme.heading);
            _ = writeText(win, 2, 2, "No critters yet!", theme.err);
            _ = writeText(win, 2, 4, "[Esc] Back", theme.hint);
            return;
        }

        // Navigation indicator
        var hc = writeFmt(win, 2, 0, theme.heading, "Roster ({d}/{d})", .{ @as(u16, self.cursor) + 1, @as(u16, @intCast(self.roster.len)) });
        if (self.mode == .swapping) {
            hc = writeText(win, hc, 0, "  ", theme.heading);
            _ = writeText(win, hc, 0, "[SWAP]", .{ .fg = theme.gold, .bold = true });
        }

        const critter = &self.roster[self.cursor];
        const sp = if (self.cursor < self.roster_species.len) self.roster_species[self.cursor] else null;
        const name = if (sp) |s| s.name else "???";

        // Sprite in top-right
        if (sp) |s| {
            if (self.sprite_map.get(s.id)) |sheet| {
                const sprite_cols: u16 = @intCast(sheet.frame_width);
                const sprite_rows: u16 = @intCast(sheet.height / 2);
                const col: u16 = if (win.width > sprite_cols + 4) win.width - sprite_cols - 4 else 0;
                const srow: u16 = if (win.height > sprite_rows + 2) 2 else 0;
                sheet.render(win, self.anim_timer.frameMod(2), srow, col, self.use_kitty);
            }
        }

        // Name and level
        var row: u16 = 2;
        const c = writeText(win, 2, row, name, theme.heading);
        _ = writeFmt(win, c, row, theme.heading, "  Lv{d}", .{critter.level});
        row += 1;

        // Type badge
        if (sp) |s| {
            const type_color = theme.typeColor(s.critter_type);
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
            _ = writeFmt(win, 2, row, theme.header, "XP: {d}/{d} to Lv{d}", .{ xp_into_level, xp_needed, critter.level + 1 });
        } else {
            _ = writeText(win, 2, row, "XP: MAX LEVEL", theme.header);
        }
        row += 1;

        // Stats
        row += 1;
        _ = writeText(win, 2, row, "Stats:", theme.header);
        row += 1;

        const eff_hp = critter.effectiveStat(.hp);
        const hp_color = theme.hpColor(critter.current_hp, eff_hp);
        _ = writeFmt(win, 4, row, .{ .fg = hp_color }, "HP:      {d}/{d}", .{ critter.current_hp, eff_hp });
        self.renderScarNote(win, critter, .hp, row);
        row += 1;
        _ = writeFmt(win, 4, row, theme.header, "Logic:   {d}", .{critter.effectiveStat(.logic)});
        self.renderScarNote(win, critter, .logic, row);
        row += 1;
        _ = writeFmt(win, 4, row, theme.header, "Resolve: {d}", .{critter.effectiveStat(.resolve)});
        self.renderScarNote(win, critter, .resolve, row);
        row += 1;
        _ = writeFmt(win, 4, row, theme.header, "Speed:   {d}", .{critter.effectiveStat(.speed)});
        self.renderScarNote(win, critter, .speed, row);
        row += 1;

        // Moves
        row += 1;
        _ = writeText(win, 2, row, "Moves:", theme.header);
        row += 1;
        self.renderMoveSlot(win, critter.move_slot_1, "1", row);
        row += 1;
        self.renderMoveSlot(win, critter.move_slot_2, "2", row);
        row += 1;
        self.renderMoveSlot(win, critter.move_slot_3, "3", row);
        row += 1;

        // Cooldown
        if (critter.cooldown_runs > 0) {
            row += 1;
            _ = writeFmt(win, 2, row, .{ .fg = theme.status_red }, "COOLDOWN: {d} run(s) remaining", .{critter.cooldown_runs});
            row += 1;
        }

        // Scars
        if (critter.scars.len > 0) {
            row += 1;
            _ = writeFmt(win, 2, row, .{ .fg = theme.scar_label }, "Scars: {d}", .{critter.scars.len});
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
        const hint = switch (self.mode) {
            .browsing => "[Left/Right] Browse  [S] Swap  [D] Equip Disc  [Esc] Back",
            .equip_disc => "[Up/Down] Select  [Enter] Equip  [Esc] Cancel",
            .swapping => "[Left/Right] Target  [S/Enter] Confirm Swap  [Esc] Cancel",
        };
        widgets.renderHintAt(win, 2, hint);
    }

    fn renderScarNote(self: *const RosterScreen, win: Window, critter: *const critter_mod.Critter, stat: critter_mod.StatKind, row: u16) void {
        _ = self;
        var total: i16 = 0;
        for (critter.scars) |scar| {
            if (scar.stat == stat) total += scar.amount;
        }
        if (total != 0) {
            _ = writeFmt(win, 22, row, .{ .fg = theme.scar_red }, " ({d})", .{total});
        }
    }

    fn renderMoveSlot(self: *const RosterScreen, win: Window, slot: ?[]const u8, label: []const u8, row: u16) void {
        if (slot) |move_id| {
            const move = self.game_data.findMove(move_id);
            if (move) |m| {
                var mc = writeFmt(win, 4, row, theme.body, "{s}. {s}", .{ label, m.name });
                const type_color = theme.typeColor(m.move_type);
                mc = writeText(win, mc, row, " ", .{});
                mc = writeText(win, mc, row, m.move_type.displayName(), .{ .fg = type_color });
                _ = writeFmt(win, mc, row, .{ .fg = theme.move_info }, " pow:{d} acc:{d}%", .{ m.power, m.accuracy });
            } else {
                _ = writeFmt(win, 4, row, .{ .fg = theme.move_info }, "{s}. {s}", .{ label, move_id });
            }
        } else {
            _ = writeFmt(win, 4, row, theme.dim, "{s}. (empty)", .{label});
        }
    }

    fn renderDiscOverlay(self: *const RosterScreen, win: Window) void {
        // Draw disc selection overlay on the right side
        const box_w: u16 = 30;
        const box_x: u16 = if (win.width > box_w + 2) win.width - box_w - 2 else 0;
        const box_y: u16 = 2;

        _ = writeText(win, box_x, box_y, "Equip Move Disc:", theme.category);

        var row = box_y + 1;
        var i: u8 = 0;
        while (i < self.disc_count) : (i += 1) {
            if (row >= win.height -| 3) break;
            const item = self.game_data.findItem(self.disc_ids[i]) orelse continue;
            const is_sel = self.disc_cursor == i;
            const prefix: []const u8 = if (is_sel) "> " else "  ";
            const style: theme.Style = if (is_sel) theme.selected_text else theme.header;

            var dc = writeText(win, box_x, row, prefix, style);
            dc = writeText(win, dc, row, item.name, style);

            // Show quantity
            for (self.inventory) |entry| {
                if (std.mem.eql(u8, entry.item_id, self.disc_ids[i])) {
                    _ = writeFmt(win, dc, row, style, " x{d}", .{entry.quantity});
                    break;
                }
            }
            row += 1;
        }

        if (self.disc_count == 0) {
            _ = writeText(win, box_x + 2, row, "(no discs available)", theme.dim);
        }
    }
};
