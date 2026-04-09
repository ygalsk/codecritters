const std = @import("std");
const vaxis = @import("vaxis");
const dungeon_mod = @import("dungeon");
const game_data_mod = @import("game_data");
const critter_mod = @import("critter");
const colors = @import("colors.zig");
const ui = @import("ui_common.zig");

const shop_mod = dungeon_mod.shop;

const Window = ui.Window;
const Style = ui.Style;
const Key = ui.Key;
const writeText = ui.writeText;
const writeFmt = ui.writeFmt;

pub const ShopScreen = struct {
    dungeon: *dungeon_mod.DungeonState,
    game_data: *const game_data_mod.GameData,
    cursor: u8,
    log: ui.MessageLog,
    done: bool,
    extracted: bool,
    dirty: bool,

    pub fn init(
        dungeon: *dungeon_mod.DungeonState,
        game_data: *const game_data_mod.GameData,
    ) ShopScreen {
        var screen = ShopScreen{
            .dungeon = dungeon,
            .game_data = game_data,
            .cursor = 0,
            .log = ui.MessageLog.init(),
            .done = false,
            .extracted = false,
            .dirty = true,
        };
        screen.log.push("Welcome to the shop!");
        return screen;
    }

    pub fn handleInput(self: *ShopScreen, key: vaxis.Key) void {
        self.dirty = true;

        const shop_state = self.dungeon.current_shop orelse {
            if (key.matches('c', .{})) {
                self.done = true;
            } else if (key.matches('e', .{})) {
                self.done = true;
                self.extracted = true;
            }
            return;
        };

        if (key.matches(Key.up, .{})) {
            if (self.cursor > 0) self.cursor -= 1;
        } else if (key.matches(Key.down, .{})) {
            if (self.cursor + 1 < shop_state.slot_count) self.cursor += 1;
        } else if (key.matches(Key.enter, .{}) or key.matches(' ', .{})) {
            self.tryBuy();
        } else if (key.matches('c', .{})) {
            self.done = true;
        } else if (key.matches('e', .{})) {
            self.done = true;
            self.extracted = true;
        }
    }

    fn tryBuy(self: *ShopScreen) void {
        const result = dungeon_mod.buyShopItem(self.dungeon, self.cursor);
        switch (result) {
            .success => {
                const shop_state = self.dungeon.current_shop orelse return;
                if (shop_state.slots[self.cursor]) |slot| {
                    const item = self.game_data.findItem(slot.item_id);
                    const name = if (item) |it| it.name else slot.item_id;
                    var buf: [ui.MSG_BUF_LEN]u8 = undefined;
                    const msg = std.fmt.bufPrint(&buf, "Bought {s}!", .{name}) catch "Bought item!";
                    self.log.push(msg);
                } else {
                    self.log.push("Bought item!");
                }
            },
            .insufficient_currency => self.log.push("Not enough currency!"),
            .out_of_stock => self.log.push("Out of stock!"),
            .invalid_slot => self.log.push("Nothing there!"),
        }
    }

    pub fn render(self: *const ShopScreen, win: Window) void {
        win.clear();
        if (win.height < 10 or win.width < 30) {
            _ = win.printSegment(.{ .text = "Terminal too small" }, .{});
            return;
        }

        const white_bold: Style = .{ .fg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true };
        const gold: Style = .{ .fg = .{ .rgb = .{ 255, 200, 40 } }, .bold = true };
        const header: Style = .{ .fg = .{ .rgb = .{ 180, 180, 180 } } };

        _ = writeFmt(win, 2, 0, white_bold, "Between Floors -- Floor {d} Complete!", .{self.dungeon.floor_number});
        _ = writeFmt(win, 2, 1, gold, "Currency: ${d}", .{self.dungeon.currency});

        _ = writeText(win, 2, 3, "Shop:", header);

        const shop_state = self.dungeon.current_shop;
        var shop_rows: u16 = 0;

        if (shop_state) |ss| {
            for (0..shop_mod.MAX_SHOP_SLOTS) |i| {
                const slot = ss.slots[i] orelse continue;
                const idx: u8 = @intCast(i);
                const selected = self.cursor == idx;
                const style: Style = if (selected)
                    .{ .fg = .{ .rgb = .{ 0, 0, 0 } }, .bg = .{ .rgb = .{ 255, 255, 255 } }, .bold = true }
                else
                    .{ .fg = .{ .rgb = .{ 200, 200, 200 } } };

                const row = 4 + shop_rows;
                if (row >= win.height) break;

                const item = self.game_data.findItem(slot.item_id);
                const name = if (item) |it| it.name else slot.item_id;

                const prefix: []const u8 = if (selected) "> " else "  ";
                var c = writeText(win, 2, row, prefix, style);
                c = writeText(win, c, row, name, style);
                c = writeFmt(win, c, row, style, "  ${d}", .{slot.price});
                _ = writeFmt(win, c, row, style, "  x{d}", .{slot.quantity});
                shop_rows += 1;
            }
        }

        if (shop_rows == 0) {
            _ = writeText(win, 4, 4, "(no items available)", .{ .fg = .{ .rgb = .{ 100, 100, 100 } }, .italic = true });
            shop_rows = 1;
        }

        const party_row = 4 + shop_rows + 1;
        if (party_row < win.height) {
            _ = writeText(win, 2, party_row, "Party:", header);
        }

        var pr: u16 = party_row + 1;
        for (self.dungeon.party) |maybe_critter| {
            const critter = maybe_critter orelse continue;
            if (pr >= win.height) break;

            const sp = ui.findSpeciesForCritter(self.dungeon, &critter);
            const name = if (sp) |s| s.name else "???";
            const hp_color = colors.hpColor(critter.current_hp, critter.max_hp);

            var c = writeText(win, 4, pr, name, .{ .fg = .{ .rgb = .{ 200, 200, 200 } } });
            c = writeFmt(win, c, pr, .{ .fg = .{ .rgb = .{ 200, 200, 200 } } }, "  Lv{d}", .{critter.level});
            _ = writeFmt(win, c, pr, .{ .fg = hp_color }, "  HP {d}/{d}", .{ critter.current_hp, critter.max_hp });
            pr += 1;
        }

        const msg_row = pr + 1;
        self.log.render(win, msg_row, 2);

        const ctrl_row = msg_row + @as(u16, @min(self.log.msg_count, 2)) + 1;
        if (ctrl_row < win.height) {
            _ = writeText(win, 2, ctrl_row, "[Enter] Buy  [c] Continue  [e] Extract", ui.dim_style);
        }
    }
};
