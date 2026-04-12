const std = @import("std");
const vaxis = @import("vaxis");
const battle = @import("battle");
const game_data_mod = @import("game_data");
const types = @import("types");
const moves_mod = @import("moves");
const items_mod = @import("items");
const species_mod = @import("species");
const text = @import("text.zig");
const sprite_mod = @import("sprite.zig");
const ui = @import("ui_common.zig");
const theme = @import("theme.zig");
const layout = @import("layout.zig");
const widgets = @import("widgets.zig");
const input = @import("input.zig");
const ScreenResult = @import("screen_result.zig").ScreenResult;
const anim_mod = @import("anim.zig");
const sound = @import("sound.zig");
const battle_anim = @import("battle_anim.zig");
const effect_sprites_mod = @import("effect_sprites.zig");
const fx = @import("fx.zig");

const Window = ui.Window;
const Style = theme.Style;
const writeText = ui.writeText;
const writeTextTruncated = ui.writeTextTruncated;
const writeFmt = ui.writeFmt;

pub const InventorySlot = struct {
    item: *const items_mod.Item,
    count: u8,
};

const MenuState = enum {
    main_menu,
    select_attack,
    select_swap,
    select_item,
    select_heal_target,
    select_catch_tool,
    animating,
    battle_over,
};

const MSG_BUF_LEN = ui.MSG_BUF_LEN;

pub const SpriteMap = sprite_mod.SpriteMap;

pub const BattleScreen = struct {
    state: *battle.BattleState,
    game_data: *const game_data_mod.GameData,
    menu_state: MenuState,
    cursor: u8,
    current_result: ?battle.TurnResult,
    event_index: u8,
    log: ui.MessageLog,
    inventory: []InventorySlot,
    pending_heal_item: ?struct { slot_idx: usize, item: *const items_mod.Item } = null,
    outcome: ?battle.BattleOutcome,
    sprites: *const SpriteMap,
    effect_sprites: *const effect_sprites_mod.EffectSpriteMap,
    use_kitty: bool,
    anim_timer: anim_mod.AnimTimer,
    dirty: bool,
    sequencer: battle_anim.BattleAnimSequencer,

    pub fn init(
        state: *battle.BattleState,
        game_data: *const game_data_mod.GameData,
        inventory: []InventorySlot,
        sprites: *const SpriteMap,
        effect_sprites: *const effect_sprites_mod.EffectSpriteMap,
        use_kitty: bool,
    ) BattleScreen {
        var screen = BattleScreen{
            .state = state,
            .game_data = game_data,
            .menu_state = .main_menu,
            .cursor = 0,
            .current_result = null,
            .event_index = 0,
            .log = ui.MessageLog.init(),
            .inventory = inventory,
            .pending_heal_item = null,
            .outcome = null,
            .sprites = sprites,
            .effect_sprites = effect_sprites,
            .use_kitty = use_kitty,
            .anim_timer = anim_mod.AnimTimer.init(500),
            .dirty = true,
            .sequencer = .{},
        };
        screen.log.push("A wild critter appeared!");
        return screen;
    }

    pub fn handleInput(self: *BattleScreen, key: vaxis.Key) ?ScreenResult {
        self.dirty = true;
        switch (self.menu_state) {
            .main_menu => self.handleMainMenu(key),
            .select_attack => self.handleSelectAttack(key),
            .select_swap => self.handleSelectSwap(key),
            .select_item => self.handleSelectItem(key),
            .select_heal_target => self.handleSelectHealTarget(key),
            .select_catch_tool => self.handleSelectCatchTool(key),
            .animating => self.handleAnimating(key),
            .battle_over => {
                return .goto_dungeon;
            },
        }
        return null;
    }

    fn handleMainMenu(self: *BattleScreen, key: vaxis.Key) void {
        const action = input.gridNav(key, &self.cursor, 2, 4);
        if (action == .confirm) {
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
        const action = input.applyCursor(&self.cursor, slot_count, input.menuNav(key));
        switch (action) {
            .back => {
                self.menu_state = .main_menu;
                self.cursor = 0;
            },
            .confirm => {
                if (self.cursor < slot_count) {
                    self.submitAction(.{ .attack = @intCast(self.cursor) });
                }
            },
            else => {},
        }
    }

    fn handleSelectSwap(self: *BattleScreen, key: vaxis.Key) void {
        const party_count = self.countAliveParty();
        const action = input.applyCursor(&self.cursor, party_count, input.menuNav(key));
        switch (action) {
            .back => {
                if (!self.isForcedSwap()) {
                    self.menu_state = .main_menu;
                    self.cursor = 0;
                }
            },
            .confirm => {
                if (self.getSwapTarget(self.cursor)) |target| {
                    self.submitAction(.{ .swap = target });
                }
            },
            else => {},
        }
    }

    fn handleSelectItem(self: *BattleScreen, key: vaxis.Key) void {
        const count = self.countItems(null);
        if (count == 0) {
            if (input.menuNav(key) == .back) {
                self.menu_state = .main_menu;
                self.cursor = 0;
            }
            return;
        }
        const action = input.applyCursor(&self.cursor, count, input.menuNav(key));
        switch (action) {
            .back => {
                self.menu_state = .main_menu;
                self.cursor = 0;
            },
            .confirm => {
                if (self.getNthItem(null, self.cursor)) |slot_idx| {
                    const slot = &self.inventory[slot_idx];
                    if (slot.item.kind == .revive and self.state.revive_used) return;
                    self.pending_heal_item = .{ .slot_idx = slot_idx, .item = slot.item };
                    self.menu_state = .select_heal_target;
                    self.cursor = 0;
                }
            },
            else => {},
        }
    }

    fn handleSelectHealTarget(self: *BattleScreen, key: vaxis.Key) void {
        const is_revive = if (self.pending_heal_item) |h| h.item.kind == .revive else false;
        const count = self.countPartyByHp(is_revive);
        if (count == 0) {
            if (input.menuNav(key) == .back) {
                self.pending_heal_item = null;
                self.menu_state = .select_item;
                self.cursor = 0;
            }
            return;
        }
        const action = input.applyCursor(&self.cursor, count, input.menuNav(key));
        switch (action) {
            .back => {
                self.pending_heal_item = null;
                self.menu_state = .select_item;
                self.cursor = 0;
            },
            .confirm => {
                if (self.pending_heal_item) |heal| {
                    const target = self.getPartyTarget(is_revive, self.cursor);
                    if (target) |t| {
                        self.submitAction(.{ .use_item = .{
                            .item = heal.item,
                            .target = t,
                        } });
                        self.inventory[heal.slot_idx].count -|= 1;
                        self.pending_heal_item = null;
                    }
                }
            },
            else => {},
        }
    }

    fn handleSelectCatchTool(self: *BattleScreen, key: vaxis.Key) void {
        const count = self.countItems(.catch_tool);
        if (count == 0) {
            if (input.menuNav(key) == .back) {
                self.menu_state = .main_menu;
                self.cursor = 0;
            }
            return;
        }
        const action = input.applyCursor(&self.cursor, count, input.menuNav(key));
        switch (action) {
            .back => {
                self.menu_state = .main_menu;
                self.cursor = 0;
            },
            .confirm => {
                if (self.getNthItem(.catch_tool, self.cursor)) |slot_idx| {
                    const slot = &self.inventory[slot_idx];
                    self.submitAction(.{ .catch_attempt = slot.item });
                    slot.count -|= 1;
                }
            },
            else => {},
        }
    }

    fn handleAnimating(self: *BattleScreen, key: vaxis.Key) void {
        // Skip animation on Space or Enter
        if (key.matches(' ', .{}) or key.matches(vaxis.Key.enter, .{})) {
            self.skipAnimation();
            return;
        }

        // Sequencer-driven animation — no keypress needed to advance
    }

    fn skipAnimation(self: *BattleScreen) void {
        const result = self.current_result orelse {
            self.finishAnimating();
            return;
        };

        // Skip remaining animation steps, showing all pending events
        var shown: [16]u8 = undefined;
        const count = self.sequencer.skip(&shown);
        for (shown[0..count]) |idx| {
            if (idx < result.event_count) {
                self.logEvent(result.events[idx]);
            }
        }

        self.finishAnimating();
    }

    fn logEvent(self: *BattleScreen, event: battle.BattleEvent) void {
        var buf: [MSG_BUF_LEN]u8 = undefined;
        const msg = text.formatEvent(event, &buf);
        self.log.push(msg);
        // Sound cues
        switch (event) {
            .critter_fainted => sound.beep(),
            .catch_result => |e| if (e.success) sound.beep(),
            .damage_dealt => |e| if (e.effectiveness == .strong) sound.beep(),
            else => {},
        }
    }

    fn finishAnimating(self: *BattleScreen) void {
        const result = self.current_result orelse return;
        self.current_result = null;
        if (result.outcome) |outcome| {
            self.outcome = outcome;
            if (outcome == .player_lose or outcome == .player_win or outcome == .caught) {
                self.menu_state = .battle_over;
                self.log.push(text.formatOutcome(outcome));
            }
        } else {
            if (self.state.activePlayer().critter.current_hp == 0 and self.hasAlivePartyMember()) {
                self.menu_state = .select_swap;
                self.cursor = 0;
                self.log.push("Choose a critter to send in!");
            } else {
                self.menu_state = .main_menu;
                self.cursor = 0;
            }
        }
    }

    fn submitAction(self: *BattleScreen, action: battle.BattleAction) void {
        // Snapshot HP before mutation for smooth bar animation
        const player_hp_before = self.state.activePlayer().critter.current_hp;
        const wild_hp_before = self.state.wild.critter.current_hp;

        const result = battle.processTurn(self.state, action, self.game_data);
        self.current_result = result;
        self.event_index = 0;
        self.menu_state = .animating;
        // Build animation sequence from battle events
        self.sequencer = battle_anim.BattleAnimSequencer.buildFromEvents(result);
        // Initialize display HP to pre-turn values for tweening
        self.sequencer.state.player_display_hp = player_hp_before;
        self.sequencer.state.wild_display_hp = wild_hp_before;
    }

    pub fn render(self: *const BattleScreen, win: Window) void {
        win.clear();
        if (layout.tooSmall(win, 40, 10)) return;

        const anim_state = self.sequencer.state;

        // Layout zones — sprites are 16 cols × 8 rows (half-block)
        const info_height: u16 = 3;
        const sprite_height: u16 = 8;
        const sprite_width: u16 = 16;
        const separator_row: u16 = if (win.height > 24) win.height - 9 else win.height / 2 + 4;
        const msg_start: u16 = separator_row + 1;
        const menu_start: u16 = if (win.height > 20) win.height - 5 else msg_start + 2;

        // Apply shake offset to the whole battle area
        const shake = anim_state.shake_offset;
        const battle_x_offset: u16 = if (shake > 0) @intCast(shake) else 0;

        // Wild critter (top-right) — apply animation offset
        const wild_base_col = win.width -| (sprite_width + 2);
        const wild_col: u16 = @intCast(@max(0, @as(i32, wild_base_col) + anim_state.wild_x_offset + shake));
        self.renderCritterInfo(win, &self.state.wild, true, 1, @max(win.width / 2, battle_x_offset));
        self.renderSprite(win, &self.state.wild, info_height + 1, wild_col);

        // Player critter (bottom-left) — apply animation offset
        const player = self.state.activePlayer();
        const player_info_row = separator_row -| (info_height + sprite_height + 1);
        const player_base_col: u16 = 2;
        const player_col: u16 = @intCast(@max(0, @as(i32, player_base_col) + anim_state.player_x_offset + shake));
        self.renderSprite(win, player, player_info_row, player_col);
        self.renderCritterInfo(win, player, false, player_info_row + sprite_height, @max(2, battle_x_offset));

        // Render effect sprite if active
        if (anim_state.effect_frame) |frame| {
            const effect_col: u16 = if (anim_state.effect_on_player) player_col else wild_col;
            const effect_row: u16 = if (anim_state.effect_on_player) player_info_row else info_height + 1;
            if (self.effect_sprites.get(anim_state.effect_type)) |effect| {
                effect.renderFrame(win, frame, effect_row, effect_col, self.use_kitty);
            }
        }

        // Separator
        widgets.renderSeparator(win, separator_row);

        // Flash overlay
        if (anim_state.flash_intensity > 0.01) {
            self.renderFlash(win, separator_row, anim_state.flash_intensity);
        }

        // Messages
        self.renderMessages(win, msg_start, menu_start);

        // Menu
        self.renderBattleMenu(win, menu_start);
    }

    fn renderFlash(self: *const BattleScreen, win: Window, separator_row: u16, intensity: f32) void {
        _ = self;
        // Flash the battle area (above separator) with white overlay
        const flash_alpha = @min(intensity, 1.0);
        const white: [3]u8 = .{ 255, 255, 255 };
        var r: u16 = 0;
        while (r < separator_row) : (r += 1) {
            var c: u16 = 0;
            while (c < win.width) : (c += 1) {
                const tinted = fx.tintColor(.{ 0, 0, 0 }, white, flash_alpha);
                win.writeCell(c, r, .{
                    .char = .{ .grapheme = " ", .width = 1 },
                    .style = .{ .bg = .{ .rgb = tinted } },
                });
            }
        }
    }

    fn renderCritterInfo(self: *const BattleScreen, win: Window, bc: *const battle.BattleCritter, is_wild: bool, row: u16, col: u16) void {
        const type_color = theme.typeColor(bc.species.critter_type);
        const type_bold: Style = .{ .fg = type_color, .bold = true };

        // Line 1: Name  Lv##  [TYPE]
        var c = col;
        if (is_wild) c = writeText(win, c, row, "Wild ", theme.heading);
        const name_budget: u16 = if (win.width > c + 18) win.width - c - 18 else 8;
        c = writeTextTruncated(win, c, row, bc.species.name, name_budget, theme.heading);
        c = writeFmt(win, c, row, theme.heading, "  Lv{d}  ", .{bc.critter.level});
        c = writeText(win, c, row, "[", type_bold);
        c = writeText(win, c, row, bc.species.critter_type.displayName(), type_bold);
        _ = writeText(win, c, row, "]", type_bold);

        // Line 2: HP bar — use display HP from animation state if available
        const display_hp = if (is_wild)
            self.sequencer.state.wild_display_hp orelse bc.critter.current_hp
        else
            self.sequencer.state.player_display_hp orelse bc.critter.current_hp;
        _ = widgets.renderHpBar(win, display_hp, bc.critter.effectiveStat(.hp), row + 1, col, .full);

        // Line 3: Status (if any)
        if (bc.status.effect != .none) {
            const status_style: Style = .{ .fg = theme.status_red };
            var sc = writeText(win, col, row + 2, "[", status_style);
            sc = writeText(win, sc, row + 2, text.statusName(bc.status.effect), status_style);
            _ = writeFmt(win, sc, row + 2, status_style, " {d}t]", .{bc.status.turns_remaining});
        }
    }

    fn renderSprite(self: *const BattleScreen, win: Window, bc: *const battle.BattleCritter, row: u16, col: u16) void {
        // Try sprite sheet first
        if (self.sprites.get(bc.species.id)) |sheet| {
            const frame = self.anim_timer.frameMod(sheet.frame_count);
            sheet.render(win, frame, row, col, self.use_kitty);
            return;
        }

        // Fallback: colored rectangle
        const sprite_w: u16 = 16;
        const sprite_h: u16 = 8;
        const tc = theme.typeColor(bc.species.critter_type);

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
            _ = writeText(win, name_col, name_row, name, .{ .fg = theme.black, .bg = tc, .bold = true });
        }
    }

    pub fn updateAnimation(self: *BattleScreen) void {
        if (self.anim_timer.tick()) self.dirty = true;

        // Drive sequencer during animation
        if (self.menu_state == .animating and !self.sequencer.isFinished()) {
            if (self.sequencer.tick()) |event_idx| {
                // An event was shown — log it
                if (self.current_result) |result| {
                    if (event_idx < result.event_count) {
                        self.logEvent(result.events[event_idx]);
                    }
                }
            }
            self.dirty = true;

            // If sequencer finished, wrap up
            if (self.sequencer.isFinished()) {
                self.finishAnimating();
            }
        }
    }

    fn renderMessages(self: *const BattleScreen, win: Window, start_row: u16, end_row: u16) void {
        const available = if (end_row > start_row) end_row - start_row else 0;
        self.log.render(win, start_row, available);
    }

    fn renderBattleMenu(self: *const BattleScreen, win: Window, start_row: u16) void {
        switch (self.menu_state) {
            .main_menu => self.renderMainMenu(win, start_row),
            .select_attack => self.renderAttackMenu(win, start_row),
            .select_swap => self.renderSwapMenu(win, start_row),
            .select_item => self.renderItemList(win, start_row, null),
            .select_heal_target => self.renderHealTargetMenu(win, start_row),
            .select_catch_tool => self.renderItemList(win, start_row, .catch_tool),
            .animating => {
                _ = writeText(win, 2, start_row + 1, "[Space/Enter to skip]", .{ .fg = theme.press_key, .italic = true });
            },
            .battle_over => {
                if (self.outcome) |outcome| {
                    _ = writeText(win, 2, start_row, text.formatOutcome(outcome), .{ .fg = theme.outcome_yellow, .bold = true });
                }
                _ = writeText(win, 2, start_row + 2, "[Press any key to exit]", .{ .fg = theme.press_key, .italic = true });
            },
        }
    }

    fn renderMainMenu(self: *const BattleScreen, win: Window, row: u16) void {
        const labels = [_][]const u8{ "Attack", "Catch", "Swap", "Item" };
        for (labels, 0..) |label, i| {
            const menu_col: u16 = if (i % 2 == 0) 4 else 24;
            const menu_row: u16 = row + @as(u16, @intCast(i / 2));
            const is_sel = self.cursor == @as(u8, @intCast(i));
            const style: Style = if (is_sel) theme.selected else theme.unselected;

            const prefix: []const u8 = if (is_sel) "> " else "  ";
            const c = writeText(win, menu_col - 2, menu_row, prefix, style);
            _ = writeText(win, c, menu_row, label, style);
        }
    }

    fn renderAttackMenu(self: *const BattleScreen, win: Window, row: u16) void {
        const player = self.state.activePlayer();
        const slots = [_]?[]const u8{ player.critter.move_slot_1, player.critter.move_slot_2, player.critter.move_slot_3 };

        _ = writeText(win, 2, row, "Choose a move:", theme.header);

        var display_idx: u8 = 0;
        for (slots, 0..) |slot, i| {
            const move_id = slot orelse continue;
            const move = self.game_data.findMove(move_id);
            const move_name = if (move) |m| m.name else move_id;
            const move_type_name = if (move) |m| m.move_type.displayName() else "???";
            const move_power: u16 = if (move) |m| m.power else 0;

            const is_sel = self.cursor == display_idx;
            const style: Style = if (is_sel) theme.selected else theme.unselected;
            const r = row + 1 + @as(u16, display_idx);
            const prefix: []const u8 = if (is_sel) "> " else "  ";
            var c = writeText(win, 2, r, prefix, style);
            c = writeFmt(win, c, r, style, "{d}. ", .{i + 1});
            c = writeText(win, c, r, move_name, style);
            c = writeText(win, c, r, "  [", style);
            c = writeText(win, c, r, move_type_name, style);
            c = writeText(win, c, r, "]  Pow:", style);
            _ = writeFmt(win, c, r, style, "{d}", .{move_power});
            display_idx += 1;
        }

        _ = writeText(win, 2, row + 1 + @as(u16, display_idx) + 1, "[Esc] Back", theme.hint);
    }

    fn renderSwapMenu(self: *const BattleScreen, win: Window, row: u16) void {
        const label: []const u8 = if (self.isForcedSwap()) "Choose a replacement:" else "Swap to:";
        _ = writeText(win, 2, row, label, theme.header);

        var display_idx: u8 = 0;
        for (self.state.player_party, 0..) |slot, i| {
            const bc = slot orelse continue;
            if (i == self.state.player_active and bc.critter.current_hp > 0) continue;
            if (bc.critter.current_hp == 0) continue;

            const is_sel = self.cursor == display_idx;
            const style: Style = if (is_sel) theme.selected else theme.unselected;
            const r = row + 1 + @as(u16, display_idx);
            const prefix: []const u8 = if (is_sel) "> " else "  ";
            var c = writeText(win, 2, r, prefix, style);
            c = writeTextTruncated(win, c, r, bc.species.name, 20, style);
            _ = writeFmt(win, c, r, style, "  Lv{d}  HP:{d}/{d}", .{ bc.critter.level, bc.critter.current_hp, bc.critter.effectiveStat(.hp) });
            display_idx += 1;
        }

        if (!self.isForcedSwap()) {
            _ = writeText(win, 2, row + 1 + @as(u16, display_idx) + 1, "[Esc] Back", theme.hint);
        }
    }

    fn renderItemList(self: *const BattleScreen, win: Window, row: u16, filter: ?items_mod.ItemKind) void {
        const label: []const u8 = if (filter != null and filter.? == .catch_tool) "Use catch tool:" else "Use item:";
        _ = writeText(win, 2, row, label, theme.header);

        var display_idx: u8 = 0;
        for (self.inventory) |slot| {
            if (!matchesItemFilter(slot.item.kind, filter) or slot.count == 0) continue;

            const is_blocked = slot.item.kind == .revive and self.state.revive_used;
            const is_sel = self.cursor == display_idx;
            const style: Style = if (is_blocked)
                theme.dim
            else if (is_sel)
                theme.selected
            else
                theme.unselected;
            const r = row + 1 + @as(u16, display_idx);
            const prefix: []const u8 = if (is_sel) "> " else "  ";
            var c = writeText(win, 2, r, prefix, style);
            c = writeText(win, c, r, slot.item.name, style);
            if (is_blocked) {
                _ = writeFmt(win, c, r, style, "  x{d} (used)", .{slot.count});
            } else {
                _ = writeFmt(win, c, r, style, "  x{d}", .{slot.count});
            }
            display_idx += 1;
        }

        if (display_idx == 0) {
            _ = writeText(win, 2, row + 1, "  (none available)", .{ .fg = theme.dim_gray, .italic = true });
        }

        _ = writeText(win, 2, row + 2 + @as(u16, display_idx), "[Esc] Back", theme.hint);
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

    /// null = usable items (healing + revive), non-null = exact kind match
    fn matchesItemFilter(kind: items_mod.ItemKind, filter: ?items_mod.ItemKind) bool {
        if (filter) |f| return kind == f;
        return kind == .healing or kind == .revive;
    }

    fn countItems(self: *const BattleScreen, filter: ?items_mod.ItemKind) u8 {
        var count: u8 = 0;
        for (self.inventory) |slot| {
            if (matchesItemFilter(slot.item.kind, filter) and slot.count > 0) count += 1;
        }
        return count;
    }

    fn getNthItem(self: *const BattleScreen, filter: ?items_mod.ItemKind, n: u8) ?usize {
        var count: u8 = 0;
        for (self.inventory, 0..) |slot, i| {
            if (!matchesItemFilter(slot.item.kind, filter) or slot.count == 0) continue;
            if (count == n) return i;
            count += 1;
        }
        return null;
    }

    /// Count all alive party members (including active critter) for heal targeting.
    fn countPartyByHp(self: *const BattleScreen, want_fainted: bool) u8 {
        var count: u8 = 0;
        for (self.state.player_party) |slot| {
            const bc = slot orelse continue;
            if ((bc.critter.current_hp == 0) == want_fainted) count += 1;
        }
        return count;
    }

    fn getPartyTarget(self: *const BattleScreen, want_fainted: bool, display_idx: u8) ?u2 {
        var count: u8 = 0;
        for (self.state.player_party, 0..) |slot, i| {
            const bc = slot orelse continue;
            if ((bc.critter.current_hp == 0) != want_fainted) continue;
            if (count == display_idx) return @intCast(i);
            count += 1;
        }
        return null;
    }

    fn renderHealTargetMenu(self: *const BattleScreen, win: Window, row: u16) void {
        const is_revive = if (self.pending_heal_item) |h| h.item.kind == .revive else false;
        const item_name = if (self.pending_heal_item) |h| h.item.name else "item";
        var label_buf: [64]u8 = undefined;
        const label = std.fmt.bufPrint(&label_buf, "Use {s} on:", .{item_name}) catch "Use item on:";
        _ = writeText(win, 2, row, label, theme.header);

        var display_idx: u8 = 0;
        for (self.state.player_party, 0..) |slot, i| {
            const bc = slot orelse continue;
            // Revive targets fainted critters; healing targets alive critters
            if (is_revive) {
                if (bc.critter.current_hp != 0) continue;
            } else {
                if (bc.critter.current_hp == 0) continue;
            }

            const is_sel = self.cursor == display_idx;
            const is_active = i == self.state.player_active;
            const style: Style = if (is_sel) theme.selected else theme.unselected;
            const r = row + 1 + @as(u16, display_idx);
            const prefix: []const u8 = if (is_sel) "> " else "  ";
            var c = writeText(win, 2, r, prefix, style);
            c = writeTextTruncated(win, c, r, bc.species.name, 18, style);
            if (is_active) {
                c = writeText(win, c, r, " (active)", style);
            }
            _ = writeFmt(win, c, r, style, "  HP:{d}/{d}", .{ bc.critter.current_hp, bc.critter.effectiveStat(.hp) });
            display_idx += 1;
        }

        if (display_idx == 0) {
            const msg: []const u8 = if (is_revive) "  (no fainted critters)" else "  (no targets)";
            _ = writeText(win, 2, row + 1, msg, .{ .fg = theme.dim_gray, .italic = true });
        }

        _ = writeText(win, 2, row + 2 + @as(u16, display_idx), "[Esc] Back", theme.hint);
    }
};
