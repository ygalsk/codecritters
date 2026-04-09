const std = @import("std");
const vaxis = @import("vaxis");
const dungeon_mod = @import("dungeon");
const species_mod = @import("species");
const critter_mod = @import("critter");

pub const Window = vaxis.Window;
pub const Color = vaxis.Cell.Color;
pub const Style = vaxis.Cell.Style;
pub const Key = vaxis.Key;

// Comptime ASCII grapheme table: each entry is a static 1-byte string slice.
// This avoids dangling pointers when using writeCell — the grapheme slices
// live in static memory, not on the stack.
pub const ascii_graphemes: [128][]const u8 = blk: {
    var table: [128][]const u8 = undefined;
    for (0..128) |i| {
        const bytes = [1]u8{@intCast(i)};
        table[i] = &bytes;
    }
    break :blk table;
};

pub fn writeText(win: Window, col: u16, row: u16, str: []const u8, style: Style) u16 {
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

pub fn writeFmt(win: Window, col: u16, row: u16, style: Style, comptime fmt: []const u8, args: anytype) u16 {
    var buf: [128]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, fmt, args) catch return col;
    return writeText(win, col, row, str, style);
}

pub const MAX_MESSAGES = 4;
pub const MSG_BUF_LEN = 128;

pub const MessageLog = struct {
    messages: [MAX_MESSAGES][MSG_BUF_LEN]u8,
    msg_lens: [MAX_MESSAGES]u8,
    msg_count: u8,

    pub fn init() MessageLog {
        return .{
            .messages = undefined,
            .msg_lens = .{ 0, 0, 0, 0 },
            .msg_count = 0,
        };
    }

    pub fn push(self: *MessageLog, msg: []const u8) void {
        if (self.msg_count < MAX_MESSAGES) {
            const len: u8 = @intCast(@min(msg.len, MSG_BUF_LEN));
            @memcpy(self.messages[self.msg_count][0..len], msg[0..len]);
            self.msg_lens[self.msg_count] = len;
            self.msg_count += 1;
        } else {
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

    pub fn render(self: *const MessageLog, win: Window, start_row: u16, max_lines: u16) void {
        const count: u16 = @intCast(self.msg_count);
        const show = @min(count, max_lines);
        const skip = if (count > show) count - show else 0;
        const msg_style: Style = .{ .fg = .{ .rgb = .{ 220, 220, 220 } } };

        var i: u16 = 0;
        while (i < show) : (i += 1) {
            const msg_idx = skip + i;
            const len = self.msg_lens[msg_idx];
            if (len > 0 and start_row + i < win.height) {
                _ = writeText(win, 2, start_row + i, self.messages[msg_idx][0..len], msg_style);
            }
        }
    }
};

pub fn findSpeciesForCritter(dungeon_state: *const dungeon_mod.DungeonState, critter: *const critter_mod.Critter) ?*const species_mod.Species {
    for (dungeon_state.party, 0..) |maybe, i| {
        if (maybe) |c| {
            if (std.mem.eql(u8, c.species_id, critter.species_id)) {
                return dungeon_state.party_species[i];
            }
        }
    }
    return null;
}

pub const dim_style: Style = .{ .fg = .{ .rgb = .{ 100, 100, 100 } } };
