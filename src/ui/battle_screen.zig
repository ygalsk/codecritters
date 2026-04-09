const std = @import("std");
const vaxis = @import("vaxis");
const battle = @import("battle");
const game_data_mod = @import("game_data");
const types = @import("types");
const moves_mod = @import("moves");
const items_mod = @import("items");
const species_mod = @import("species");
const colors = @import("colors.zig");
const text = @import("text.zig");
const sprite_mod = @import("sprite.zig");

const Window = vaxis.Window;
const Color = vaxis.Cell.Color;
const Style = vaxis.Cell.Style;
const Key = vaxis.Key;

// Comptime ASCII grapheme table: each entry is a static 1-byte string slice.
// This avoids dangling pointers when using writeCell — the grapheme slices
// live in static memory, not on the stack.
const ascii_graphemes: [128][]const u8 = blk: {
    var table: [128][]const u8 = undefined;
    for (0..128) |i| {
        const bytes = [1]u8{@intCast(i)};
        table[i] = &bytes;
    }
    break :blk table;
};

/// Write text directly to window cells using static grapheme references.
/// Returns the column after the last written character.
fn writeText(win: Window, col: u16, row: u16, str: []const u8, style: Style) u16 {
    var c = col;
    for (str) |byte| {
        if (c >= win.width) break;
        if (byte < 128) {
            win.writeCell(c, row, .{ .char = .{ .grapheme = ascii_graphemes[byte], .width = 1 }, .style = style });
        }
        c += 1;
    }
    return c;
}

/// Format text into a temporary buffer, then write it cell-by-cell via writeText.
/// The buffer is only needed during this call — no dangling references.
fn writeFmt(win: Window, col: u16, row: u16, style: Style, comptime fmt: []const u8, args: anytype) u16 {
    var buf: [128]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, fmt, args) catch return col;
    return writeText(win, col, row, str, style);
}

pub const InventorySlot = struct {
    item: *const items_mod.Item,
    count: u8,
};

const MenuState = enum {
    main_menu,
    select_attack,
    select_swap,
    select_item,
    select_catch_tool,
    animating,
    battle_over,
};

const MAX_MESSAGES = 4;
const MSG_BUF_LEN = 128;

pub const SpriteMap = sprite_mod.SpriteMap;

pub const BattleScreen = struct {
    state: *battle.BattleState,
    game_data: *const game_data_mod.GameData,
    menu_state: MenuState,
    cursor: u8,
    current_result: ?battle.TurnResult,
    event_index: u8,
    messages: [MAX_MESSAGES][MSG_BUF_LEN]u8,
    msg_lens: [MAX_MESSAGES]u8,
    msg_count: u8,
    inventory: []InventorySlot,
    done: bool,
    outcome: ?battle.BattleOutcome,
    sprites: *const SpriteMap,
    use_kitty: bool,
    anim_frame: u8,
    last_anim_ms: i64,
    dirty: bool,

    const ANIM_INTERVAL_MS: i64 = 500;

    pub fn init(
        state: *battle.BattleState,
        game_data: *const game_data_mod.GameData,
        inventory: []InventorySlot,
        sprites: *const SpriteMap,
        use_kitty: bool,
    ) BattleScreen {
        var screen = BattleScreen{
            .state = state,
            .game_data = game_data,
            .menu_state = .main_menu,
            .cursor = 0,
            .current_result = null,
            .event_index = 0,
            .messages = undefined,
            .msg_lens = .{ 0, 0, 0, 0 },
            .msg_count = 0,
            .inventory = inventory,
            .done = false,
            .outcome = null,
            .sprites = sprites,
            .use_kitty = use_kitty,
            .anim_frame = 0,
            .last_anim_ms = std.time.milliTimestamp(),
            .dirty = true,
        };
        screen.pushMessage("A wild critter appeared!");
        return screen;
    }

    pub fn handleInput(self: *BattleScreen, key: vaxis.Key) void {
        self.dirty = true;
        switch (self.menu_state) {
            .main_menu => self.handleMainMenu(key),
            .select_attack => self.handleSelectAttack(key),
            .select_swap => self.handleSelectSwap(key),
            .select_item => self.handleSelectItem(key),
            .select_catch_tool => self.handleSelectCatchTool(key),
            .animating => self.handleAnimating(key),
            .battle_over => {
                self.done = true;
            },
        }
    }

    fn handleMainMenu(self: *BattleScreen, key: vaxis.Key) void {
        if (key.matches(Key.up, .{})) {
            if (self.cursor >= 2) self.cursor -= 2;
        } else if (key.matches(Key.down, .{})) {
            if (self.cursor + 2 < 4) self.cursor += 2;
        } else if (key.matches(Key.left, .{})) {
            if (self.cursor % 2 == 1) self.cursor -= 1;
        } else if (key.matches(Key.right, .{})) {
            if (self.cursor % 2 == 0 and self.cursor + 1 < 4) self.cursor += 1;
        } else if (key.matches(Key.enter, .{}) or key.matches(' ', .{})) {
            switch (self.cursor) {
                0 => {
                    self.menu_state = .select_attack;
                    self.cursor = 0;
                },
                1 => {
                    self.menu_state = .select_catch_tool;
                    self.cursor = 0;
                },
                2 => {
                    self.menu_state = .select_swap;
                    self.cursor = 0;
                },
                3 => {
                    self.menu_state = .select_item;
                    self.cursor = 0;
                },
                else => {},
            }
        }
    }

    fn handleSelectAttack(self: *BattleScreen, key: vaxis.Key) void {
        const slot_count = self.countMoveSlots();
        if (key.matches(Key.escape, .{}) or key.matches(Key.backspace, .{})) {
            self.menu_state = .main_menu;
            self.cursor = 0;
            return;
        }
        if (key.matches(Key.up, .{})) {
            if (self.cursor > 0) self.cursor -= 1;
        } else if (key.matches(Key.down, .{})) {
            if (self.cursor + 1 < slot_count) self.cursor += 1;
        } else if (key.matches(Key.enter, .{}) or key.matches(' ', .{})) {
            if (self.cursor < slot_count) {
                self.submitAction(.{ .attack = @intCast(self.cursor) });
            }
        }
    }

    fn handleSelectSwap(self: *BattleScreen, key: vaxis.Key) void {
        if (key.matches(Key.escape, .{}) or key.matches(Key.backspace, .{})) {
            // Can't escape forced swap
            if (!self.isForcedSwap()) {
                self.menu_state = .main_menu;
                self.cursor = 0;
            }
            return;
        }
        const party_count = self.countAliveParty();
        if (key.matches(Key.up, .{})) {
            if (self.cursor > 0) self.cursor -= 1;
        } else if (key.matches(Key.down, .{})) {
            if (self.cursor + 1 < party_count) self.cursor += 1;
        } else if (key.matches(Key.enter, .{}) or key.matches(' ', .{})) {
            if (self.getSwapTarget(self.cursor)) |target| {
                self.submitAction(.{ .swap = target });
            }
        }
    }

    fn handleSelectItem(self: *BattleScreen, key: vaxis.Key) void {
        if (key.matches(Key.escape, .{}) or key.matches(Key.backspace, .{})) {
            self.menu_state = .main_menu;
            self.cursor = 0;
            return;
        }
        const count = self.countItemsByKind(.healing);
        if (count == 0) return;
        if (key.matches(Key.up, .{})) {
            if (self.cursor > 0) self.cursor -= 1;
        } else if (key.matches(Key.down, .{})) {
            if (self.cursor + 1 < count) self.cursor += 1;
        } else if (key.matches(Key.enter, .{}) or key.matches(' ', .{})) {
            if (self.getNthItemByKind(.healing, self.cursor)) |slot_idx| {
                const slot = &self.inventory[slot_idx];
                self.submitAction(.{ .use_item = .{
                    .item = slot.item,
                    .target = self.state.player_active,
                } });
                slot.count -|= 1;
            }
        }
    }

    fn handleSelectCatchTool(self: *BattleScreen, key: vaxis.Key) void {
        if (key.matches(Key.escape, .{}) or key.matches(Key.backspace, .{})) {
            self.menu_state = .main_menu;
            self.cursor = 0;
            return;
        }
        const count = self.countItemsByKind(.catch_tool);
        if (count == 0) return;
        if (key.matches(Key.up, .{})) {
            if (self.cursor > 0) self.cursor -= 1;
        } else if (key.matches(Key.down, .{})) {
            if (self.cursor + 1 < count) self.cursor += 1;
        } else if (key.matches(Key.enter, .{}) or key.matches(' ', .{})) {
            if (self.getNthItemByKind(.catch_tool, self.cursor)) |slot_idx| {
                const slot = &self.inventory[slot_idx];
                self.submitAction(.{ .catch_attempt = slot.item });
                slot.count -|= 1;
            }
        }
    }

    fn handleAnimating(self: *BattleScreen, key: vaxis.Key) void {
        _ = key;
        const result = self.current_result orelse return;
        if (self.event_index < result.event_count) {
            const event = result.events[self.event_index];
            var buf: [MSG_BUF_LEN]u8 = undefined;
            const msg = text.formatEvent(event, &buf);
            self.pushMessage(msg);
            self.event_index += 1;
        } else {
            self.current_result = null;
            if (result.outcome) |outcome| {
                self.outcome = outcome;
                if (outcome == .player_lose or outcome == .player_win or outcome == .caught) {
                    self.menu_state = .battle_over;
                    self.pushMessage(text.formatOutcome(outcome));
                }
            } else {
                if (self.state.activePlayer().critter.current_hp == 0 and self.hasAlivePartyMember()) {
                    self.menu_state = .select_swap;
                    self.cursor = 0;
                    self.pushMessage("Choose a critter to send in!");
                } else {
                    self.menu_state = .main_menu;
                    self.cursor = 0;
                }
            }
        }
    }

    fn submitAction(self: *BattleScreen, action: battle.BattleAction) void {
        const result = battle.processTurn(self.state, action, self.game_data);
        self.current_result = result;
        self.event_index = 0;
        self.menu_state = .animating;
        if (result.event_count > 0) {
            var buf: [MSG_BUF_LEN]u8 = undefined;
            const msg = text.formatEvent(result.events[0], &buf);
            self.pushMessage(msg);
            self.event_index = 1;
        }
    }

    pub fn render(self: *const BattleScreen, win: Window) void {
        win.clear();
        if (win.height < 10 or win.width < 40) {
            _ = win.printSegment(.{ .text = "Terminal too small" }, .{});
            return;
        }

        // Layout zones — sprites are 16 cols × 8 rows (half-block)
        const info_height: u16 = 3;
        const sprite_height: u16 = 8;
        const sprite_width: u16 = 16;
        const separator_row: u16 = if (win.height > 24) win.height - 9 else win.height / 2 + 4;
        const msg_start: u16 = separator_row + 1;
        const menu_start: u16 = if (win.height > 20) win.height - 5 else msg_start + 2;

        // Wild critter (top-right)
        self.renderCritterInfo(win, &self.state.wild, true, 1, win.width / 2);
        self.renderSprite(win, &self.state.wild, info_height + 1, win.width -| (sprite_width + 2));

        // Player critter (bottom-left)
        const player = self.state.activePlayer();
        const player_info_row = separator_row -| (info_height + sprite_height + 1);
        self.renderSprite(win, player, player_info_row, 2);
        self.renderCritterInfo(win, player, false, player_info_row + sprite_height, 2);

        // Separator
        self.renderSeparator(win, separator_row);

        // Messages
        self.renderMessages(win, msg_start, menu_start);

        // Menu
        self.renderMenu(win, menu_start);
    }

    fn renderCritterInfo(self: *const BattleScreen, win: Window, bc: *const battle.BattleCritter, is_wild: bool, row: u16, col: u16) void {
        const white_bold: Style = .{ .fg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true };
        const type_color = colors.typeColor(bc.species.critter_type);
        const type_bold: Style = .{ .fg = type_color, .bold = true };

        // Line 1: Name  Lv##  [TYPE]
        var c = col;
        if (is_wild) c = writeText(win, c, row, "Wild ", white_bold);
        c = writeText(win, c, row, bc.species.name, white_bold);
        c = writeFmt(win, c, row, white_bold, "  Lv{d}  ", .{bc.critter.level});
        c = writeText(win, c, row, "[", type_bold);
        c = writeText(win, c, row, bc.species.critter_type.displayName(), type_bold);
        _ = writeText(win, c, row, "]", type_bold);

        // Line 2: HP bar
        self.renderHpBar(win, bc.critter.current_hp, bc.critter.max_hp, row + 1, col);

        // Line 3: Status (if any)
        if (bc.status.effect != .none) {
            const status_style: Style = .{ .fg = .{ .rgb = .{ 255, 100, 100 } } };
            var sc = writeText(win, col, row + 2, "[", status_style);
            sc = writeText(win, sc, row + 2, text.statusName(bc.status.effect), status_style);
            _ = writeFmt(win, sc, row + 2, status_style, " {d}t]", .{bc.status.turns_remaining});
        }
    }

    fn renderHpBar(_: *const BattleScreen, win: Window, current: u16, max: u16, row: u16, col: u16) void {
        const bar_width: u16 = 20;
        const hp_color = colors.hpColor(current, max);
        const gray: Style = .{ .fg = .{ .rgb = .{ 200, 200, 200 } } };

        var c = writeText(win, col, row, "HP ", gray);

        const filled: u16 = if (max > 0) @intCast((@as(u32, current) * bar_width) / @as(u32, max)) else 0;

        var i: u16 = 0;
        while (i < bar_width) : (i += 1) {
            if (c >= win.width) break;
            if (i < filled) {
                win.writeCell(c, row, .{ .char = .{ .grapheme = "█", .width = 1 }, .style = .{ .fg = hp_color } });
            } else {
                win.writeCell(c, row, .{ .char = .{ .grapheme = "░", .width = 1 }, .style = .{ .fg = .{ .rgb = .{ 60, 60, 60 } } } });
            }
            c += 1;
        }

        _ = writeFmt(win, c, row, gray, " {d}/{d}", .{ current, max });
    }

    fn renderSprite(self: *const BattleScreen, win: Window, bc: *const battle.BattleCritter, row: u16, col: u16) void {
        // Try sprite sheet first
        if (self.sprites.get(bc.species.id)) |sheet| {
            const frame = self.anim_frame % sheet.frame_count;
            sheet.render(win, frame, row, col, self.use_kitty);
            return;
        }

        // Fallback: colored rectangle (same as Phase 3)
        const sprite_w: u16 = 16;
        const sprite_h: u16 = 8;
        const tc = colors.typeColor(bc.species.critter_type);

        var r: u16 = 0;
        while (r < sprite_h) : (r += 1) {
            var c: u16 = 0;
            while (c < sprite_w) : (c += 1) {
                if (col + c < win.width and row + r < win.height) {
                    win.writeCell(col + c, row + r, .{ .char = .{ .grapheme = " ", .width = 1 }, .style = .{ .bg = tc } });
                }
            }
        }

        const name = bc.species.name;
        const name_len = @as(u16, @intCast(name.len));
        const name_col = if (sprite_w > name_len) col + (sprite_w - name_len) / 2 else col;
        const name_row = row + sprite_h / 2;
        if (name_row < win.height) {
            _ = writeText(win, name_col, name_row, name, .{ .fg = .{ .rgb = .{ 0, 0, 0 } }, .bg = tc, .bold = true });
        }
    }

    /// Advance animation frame based on elapsed time. Returns true if frame changed.
    pub fn updateAnimation(self: *BattleScreen) void {
        const now = std.time.milliTimestamp();
        if (now - self.last_anim_ms >= ANIM_INTERVAL_MS) {
            self.anim_frame +%= 1;
            self.last_anim_ms = now;
            self.dirty = true;
        }
    }

    fn renderSeparator(_: *const BattleScreen, win: Window, row: u16) void {
        var i: u16 = 0;
        while (i < win.width) : (i += 1) {
            win.writeCell(i, row, .{ .char = .{ .grapheme = "─", .width = 1 }, .style = .{ .fg = .{ .rgb = .{ 80, 80, 80 } } } });
        }
    }

    fn renderMessages(self: *const BattleScreen, win: Window, start_row: u16, end_row: u16) void {
        const available = if (end_row > start_row) end_row - start_row else 0;
        const count: u16 = @intCast(self.msg_count);
        const show = @min(count, available);
        const skip = if (count > show) count - show else 0;
        const msg_style: Style = .{ .fg = .{ .rgb = .{ 220, 220, 220 } } };

        var i: u16 = 0;
        while (i < show) : (i += 1) {
            const msg_idx = skip + i;
            const len = self.msg_lens[msg_idx];
            if (len > 0) {
                _ = writeText(win, 2, start_row + i, self.messages[msg_idx][0..len], msg_style);
            }
        }
    }

    fn renderMenu(self: *const BattleScreen, win: Window, start_row: u16) void {
        switch (self.menu_state) {
            .main_menu => self.renderMainMenu(win, start_row),
            .select_attack => self.renderAttackMenu(win, start_row),
            .select_swap => self.renderSwapMenu(win, start_row),
            .select_item => self.renderItemList(win, start_row, .healing),
            .select_catch_tool => self.renderItemList(win, start_row, .catch_tool),
            .animating => {
                _ = writeText(win, 2, start_row + 1, "[Press any key to continue]", .{ .fg = .{ .rgb = .{ 150, 150, 150 } }, .italic = true });
            },
            .battle_over => {
                if (self.outcome) |outcome| {
                    _ = writeText(win, 2, start_row, text.formatOutcome(outcome), .{ .fg = .{ .rgb = .{ 255, 255, 100 } }, .bold = true });
                }
                _ = writeText(win, 2, start_row + 2, "[Press any key to exit]", .{ .fg = .{ .rgb = .{ 150, 150, 150 } }, .italic = true });
            },
        }
    }

    fn renderMainMenu(self: *const BattleScreen, win: Window, row: u16) void {
        const labels = [_][]const u8{ "Attack", "Catch", "Swap", "Item" };
        for (labels, 0..) |label, i| {
            const menu_col: u16 = if (i % 2 == 0) 4 else 24;
            const menu_row: u16 = row + @as(u16, @intCast(i / 2));
            const selected = self.cursor == @as(u8, @intCast(i));
            const style: Style = if (selected)
                .{ .fg = .{ .rgb = .{ 0, 0, 0 } }, .bg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true }
            else
                .{ .fg = .{ .rgb = .{ 200, 200, 200 } } };

            const prefix: []const u8 = if (selected) "> " else "  ";
            const c = writeText(win, menu_col - 2, menu_row, prefix, style);
            _ = writeText(win, c, menu_row, label, style);
        }
    }

    fn renderAttackMenu(self: *const BattleScreen, win: Window, row: u16) void {
        const player = self.state.activePlayer();
        const slots = [_]?[]const u8{ player.critter.move_slot_1, player.critter.move_slot_2, player.critter.move_slot_3 };

        _ = writeText(win, 2, row, "Choose a move:", header_style);

        var display_idx: u8 = 0;
        for (slots, 0..) |slot, i| {
            const move_id = slot orelse continue;
            const move = self.game_data.findMove(move_id);
            const move_name = if (move) |m| m.name else move_id;
            const move_type_name = if (move) |m| m.move_type.displayName() else "???";
            const move_power: u16 = if (move) |m| m.power else 0;

            const selected = self.cursor == display_idx;
            const style: Style = if (selected)
                .{ .fg = .{ .rgb = .{ 0, 0, 0 } }, .bg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true }
            else
                .{ .fg = .{ .rgb = .{ 200, 200, 200 } } };
            const r = row + 1 + @as(u16, display_idx);
            const prefix: []const u8 = if (selected) "> " else "  ";
            var c = writeText(win, 2, r, prefix, style);
            c = writeFmt(win, c, r, style, "{d}. ", .{i + 1});
            c = writeText(win, c, r, move_name, style);
            c = writeText(win, c, r, "  [", style);
            c = writeText(win, c, r, move_type_name, style);
            c = writeText(win, c, r, "]  Pow:", style);
            _ = writeFmt(win, c, r, style, "{d}", .{move_power});
            display_idx += 1;
        }

        _ = writeText(win, 2, row + 1 + @as(u16, display_idx) + 1, "[Esc] Back", dim_style);
    }

    fn renderSwapMenu(self: *const BattleScreen, win: Window, row: u16) void {
        const label: []const u8 = if (self.isForcedSwap()) "Choose a replacement:" else "Swap to:";
        _ = writeText(win, 2, row, label, header_style);

        var display_idx: u8 = 0;
        for (self.state.player_party, 0..) |slot, i| {
            const bc = slot orelse continue;
            if (i == self.state.player_active and bc.critter.current_hp > 0) continue;
            if (bc.critter.current_hp == 0) continue;

            const selected = self.cursor == display_idx;
            const style: Style = if (selected)
                .{ .fg = .{ .rgb = .{ 0, 0, 0 } }, .bg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true }
            else
                .{ .fg = .{ .rgb = .{ 200, 200, 200 } } };
            const r = row + 1 + @as(u16, display_idx);
            const prefix: []const u8 = if (selected) "> " else "  ";
            var c = writeText(win, 2, r, prefix, style);
            c = writeText(win, c, r, bc.species.name, style);
            _ = writeFmt(win, c, r, style, "  Lv{d}  HP:{d}/{d}", .{ bc.critter.level, bc.critter.current_hp, bc.critter.max_hp });
            display_idx += 1;
        }

        if (!self.isForcedSwap()) {
            _ = writeText(win, 2, row + 1 + @as(u16, display_idx) + 1, "[Esc] Back", dim_style);
        }
    }

    fn renderItemList(self: *const BattleScreen, win: Window, row: u16, kind: items_mod.ItemKind) void {
        const label: []const u8 = if (kind == .catch_tool) "Use catch tool:" else "Use item:";
        _ = writeText(win, 2, row, label, header_style);

        var display_idx: u8 = 0;
        for (self.inventory) |slot| {
            if (slot.item.kind != kind or slot.count == 0) continue;

            const selected = self.cursor == display_idx;
            const style: Style = if (selected)
                .{ .fg = .{ .rgb = .{ 0, 0, 0 } }, .bg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true }
            else
                .{ .fg = .{ .rgb = .{ 200, 200, 200 } } };
            const r = row + 1 + @as(u16, display_idx);
            const prefix: []const u8 = if (selected) "> " else "  ";
            var c = writeText(win, 2, r, prefix, style);
            c = writeText(win, c, r, slot.item.name, style);
            _ = writeFmt(win, c, r, style, "  x{d}", .{slot.count});
            display_idx += 1;
        }

        if (display_idx == 0) {
            _ = writeText(win, 2, row + 1, "  (none available)", .{ .fg = dim_style.fg, .italic = true });
        }

        _ = writeText(win, 2, row + 2 + @as(u16, display_idx), "[Esc] Back", dim_style);
    }

    const dim_style: Style = .{ .fg = .{ .rgb = .{ 100, 100, 100 } } };
    const header_style: Style = .{ .fg = .{ .rgb = .{ 180, 180, 180 } } };

    fn pushMessage(self: *BattleScreen, msg: []const u8) void {
        if (self.msg_count < MAX_MESSAGES) {
            const len: u8 = @intCast(@min(msg.len, MSG_BUF_LEN));
            @memcpy(self.messages[self.msg_count][0..len], msg[0..len]);
            self.msg_lens[self.msg_count] = len;
            self.msg_count += 1;
        } else {
            // Shift up
            var i: u8 = 0;
            while (i < MAX_MESSAGES - 1) : (i += 1) {
                self.messages[i] = self.messages[i + 1];
                self.msg_lens[i] = self.msg_lens[i + 1];
            }
            const len: u8 = @intCast(@min(msg.len, MSG_BUF_LEN));
            @memcpy(self.messages[MAX_MESSAGES - 1][0..len], msg[0..len]);
            self.msg_lens[MAX_MESSAGES - 1] = len;
        }
    }

    fn countMoveSlots(self: *const BattleScreen) u8 {
        const player = self.state.activePlayer();
        var count: u8 = 0;
        if (player.critter.move_slot_1 != null) count += 1;
        if (player.critter.move_slot_2 != null) count += 1;
        if (player.critter.move_slot_3 != null) count += 1;
        return count;
    }

    fn countAliveParty(self: *const BattleScreen) u8 {
        var count: u8 = 0;
        for (self.state.player_party, 0..) |slot, i| {
            const bc = slot orelse continue;
            if (i == self.state.player_active and bc.critter.current_hp > 0) continue;
            if (bc.critter.current_hp == 0) continue;
            count += 1;
        }
        return count;
    }

    fn getSwapTarget(self: *const BattleScreen, display_idx: u8) ?u2 {
        var count: u8 = 0;
        for (self.state.player_party, 0..) |slot, i| {
            const bc = slot orelse continue;
            if (i == self.state.player_active and bc.critter.current_hp > 0) continue;
            if (bc.critter.current_hp == 0) continue;
            if (count == display_idx) return @intCast(i);
            count += 1;
        }
        return null;
    }

    fn isForcedSwap(self: *const BattleScreen) bool {
        return self.state.activePlayer().critter.current_hp == 0;
    }

    fn hasAlivePartyMember(self: *const BattleScreen) bool {
        for (self.state.player_party, 0..) |slot, i| {
            if (i == self.state.player_active) continue;
            const bc = slot orelse continue;
            if (bc.critter.current_hp > 0) return true;
        }
        return false;
    }

    fn countItemsByKind(self: *const BattleScreen, kind: items_mod.ItemKind) u8 {
        var count: u8 = 0;
        for (self.inventory) |slot| {
            if (slot.item.kind == kind and slot.count > 0) count += 1;
        }
        return count;
    }

    fn getNthItemByKind(self: *const BattleScreen, kind: items_mod.ItemKind, n: u8) ?usize {
        var count: u8 = 0;
        for (self.inventory, 0..) |slot, i| {
            if (slot.item.kind != kind or slot.count == 0) continue;
            if (count == n) return i;
            count += 1;
        }
        return null;
    }
};
