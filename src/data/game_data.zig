const std = @import("std");
const species_mod = @import("species.zig");
const moves_mod = @import("moves.zig");
const items_mod = @import("items.zig");

pub const GameData = struct {
    species_parsed: std.json.Parsed([]species_mod.Species),
    moves_parsed: std.json.Parsed([]moves_mod.Move),
    items_parsed: std.json.Parsed([]items_mod.Item),

    pub fn species(self: *const GameData) []const species_mod.Species {
        return self.species_parsed.value;
    }

    pub fn moves(self: *const GameData) []const moves_mod.Move {
        return self.moves_parsed.value;
    }

    pub fn items(self: *const GameData) []const items_mod.Item {
        return self.items_parsed.value;
    }

    pub fn findSpecies(self: *const GameData, id: []const u8) ?*const species_mod.Species {
        return species_mod.findById(self.species_parsed.value, id);
    }

    pub fn findMove(self: *const GameData, id: []const u8) ?*const moves_mod.Move {
        return moves_mod.findById(self.moves_parsed.value, id);
    }

    pub fn findItem(self: *const GameData, id: []const u8) ?*const items_mod.Item {
        return items_mod.findById(self.items_parsed.value, id);
    }

    pub fn load(allocator: std.mem.Allocator) !GameData {
        const sp = try species_mod.load(allocator, "data/species.json");
        errdefer sp.deinit();
        const mv = try moves_mod.load(allocator, "data/moves.json");
        errdefer mv.deinit();
        const it = try items_mod.load(allocator, "data/items.json");

        return .{
            .species_parsed = sp,
            .moves_parsed = mv,
            .items_parsed = it,
        };
    }

    pub fn deinit(self: *GameData) void {
        self.items_parsed.deinit();
        self.moves_parsed.deinit();
        self.species_parsed.deinit();
    }
};

test "load all game data" {
    const allocator = std.testing.allocator;
    var gd = try GameData.load(allocator);
    defer gd.deinit();

    try std.testing.expect(gd.species().len >= 5);
    try std.testing.expect(gd.moves().len >= 12);
    try std.testing.expect(gd.items().len >= 8);

    // Cross-reference: species signature move exists in moves
    const println = gd.findSpecies("println");
    try std.testing.expect(println != null);
    const sig_move = gd.findMove(println.?.signature_move);
    try std.testing.expect(sig_move != null);
}
