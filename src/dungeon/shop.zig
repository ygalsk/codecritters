const std = @import("std");
const items_mod = @import("items");
const game_data_mod = @import("game_data");
const biome_mod = @import("biome.zig");

pub const ShopSlot = struct {
    item_id: []const u8,
    price: u16,
    quantity: u8,
};

pub const MAX_SHOP_SLOTS: u8 = 6;

pub const ShopState = struct {
    slots: [MAX_SHOP_SLOTS]?ShopSlot,
    slot_count: u8,

    pub fn init() ShopState {
        return .{
            .slots = .{null} ** MAX_SHOP_SLOTS,
            .slot_count = 0,
        };
    }
};

/// Generate a between-floor shop using the biome's shop bias and floor depth.
/// Prices scale with floor number (+10% per floor).
pub fn generateShop(
    biome: *const biome_mod.Biome,
    floor_number: u8,
    game_data: *const game_data_mod.GameData,
    rng: std.Random,
) ShopState {
    var state = ShopState.init();
    if (biome.shop_bias.len == 0) return state;

    // Calculate total weight for weighted selection
    var total_weight: u32 = 0;
    for (biome.shop_bias) |entry| {
        total_weight += entry.weight;
    }
    if (total_weight == 0) return state;

    // Pick 3-6 shop slots (more variety on deeper floors)
    const slot_target: u8 = @min(MAX_SHOP_SLOTS, 3 + floor_number / 4);

    var attempts: u16 = 0;
    while (state.slot_count < slot_target and attempts < 100) : (attempts += 1) {
        // Weighted random item selection
        var roll = rng.intRangeLessThan(u32, 0, total_weight);
        var selected_id: ?[]const u8 = null;
        for (biome.shop_bias) |entry| {
            if (roll < entry.weight) {
                selected_id = entry.item_id;
                break;
            }
            roll -= entry.weight;
        }

        const item_id = selected_id orelse continue;

        var already_present = false;
        for (state.slots) |maybe_slot| {
            if (maybe_slot) |slot| {
                if (std.mem.eql(u8, slot.item_id, item_id)) {
                    already_present = true;
                    break;
                }
            }
        }
        if (already_present) continue;

        // Look up base price from game data
        const item = game_data.findItem(item_id) orelse continue;
        // Scale price: +10% per floor (floor 1 = base price)
        const price_scale: u32 = 100 + @as(u32, floor_number -| 1) * 10;
        const scaled_price: u16 = @intCast(@min(9999, @as(u32, item.buy_price) * price_scale / 100));

        state.slots[state.slot_count] = .{
            .item_id = item_id,
            .price = scaled_price,
            .quantity = rng.intRangeAtMost(u8, 1, 3),
        };
        state.slot_count += 1;
    }

    return state;
}

pub const BuyResult = enum {
    success,
    insufficient_currency,
    out_of_stock,
    invalid_slot,
};

/// Buy an item from the shop. Returns whether the purchase succeeded.
/// On success, decrements shop quantity, deducts currency, and returns the item_id.
pub fn buyItem(state: *ShopState, slot_index: u8, currency: *u32) BuyResult {
    if (slot_index >= MAX_SHOP_SLOTS) return .invalid_slot;
    const slot_ptr = &state.slots[slot_index];
    const slot = slot_ptr.* orelse return .invalid_slot;
    if (slot.quantity == 0) return .out_of_stock;
    if (currency.* < slot.price) return .insufficient_currency;

    currency.* -= slot.price;
    slot_ptr.*.?.quantity -= 1;
    if (slot_ptr.*.?.quantity == 0) {
        slot_ptr.* = null;
    }
    return .success;
}

// --- Tests ---

test "generateShop produces valid items" {
    const allocator = std.testing.allocator;
    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();

    const biomes_parsed = try biome_mod.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();

    const biome = &biomes_parsed.value[0];
    var prng = std.Random.DefaultPrng.init(42);
    const shop = generateShop(biome, 3, &gd, prng.random());

    try std.testing.expect(shop.slot_count >= 3);

    // All items should exist in game data
    for (shop.slots[0..shop.slot_count]) |maybe_slot| {
        if (maybe_slot) |slot| {
            try std.testing.expect(gd.findItem(slot.item_id) != null);
            try std.testing.expect(slot.price > 0);
            try std.testing.expect(slot.quantity >= 1 and slot.quantity <= 3);
        }
    }
}

test "shop prices scale with floor" {
    const allocator = std.testing.allocator;
    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();

    const biomes_parsed = try biome_mod.load(allocator, "data/biomes.json");
    defer biomes_parsed.deinit();

    const biome = &biomes_parsed.value[0];

    // Generate shops on floor 1 and floor 10 with same seed
    var prng1 = std.Random.DefaultPrng.init(55);
    const shop1 = generateShop(biome, 1, &gd, prng1.random());

    var prng2 = std.Random.DefaultPrng.init(55);
    const shop10 = generateShop(biome, 10, &gd, prng2.random());

    // Find a common item and compare prices
    if (shop1.slot_count > 0 and shop10.slot_count > 0) {
        if (shop1.slots[0]) |s1| {
            for (shop10.slots[0..shop10.slot_count]) |maybe_s10| {
                if (maybe_s10) |s10| {
                    if (std.mem.eql(u8, s1.item_id, s10.item_id)) {
                        // Floor 10 should be more expensive
                        try std.testing.expect(s10.price >= s1.price);
                        break;
                    }
                }
            }
        }
    }
}

test "buyItem deducts currency" {
    var state = ShopState.init();
    state.slots[0] = .{ .item_id = "small_patch", .price = 40, .quantity = 2 };
    state.slot_count = 1;

    var currency: u32 = 100;
    const result = buyItem(&state, 0, &currency);
    try std.testing.expectEqual(BuyResult.success, result);
    try std.testing.expectEqual(@as(u32, 60), currency);
    // Quantity decremented
    try std.testing.expectEqual(@as(u8, 1), state.slots[0].?.quantity);
}

test "buyItem fails with insufficient currency" {
    var state = ShopState.init();
    state.slots[0] = .{ .item_id = "hotfix", .price = 100, .quantity = 1 };
    state.slot_count = 1;

    var currency: u32 = 50;
    const result = buyItem(&state, 0, &currency);
    try std.testing.expectEqual(BuyResult.insufficient_currency, result);
    try std.testing.expectEqual(@as(u32, 50), currency);
}

test "buyItem removes slot when quantity reaches zero" {
    var state = ShopState.init();
    state.slots[0] = .{ .item_id = "small_patch", .price = 40, .quantity = 1 };
    state.slot_count = 1;

    var currency: u32 = 100;
    const result = buyItem(&state, 0, &currency);
    try std.testing.expectEqual(BuyResult.success, result);
    try std.testing.expectEqual(@as(?ShopSlot, null), state.slots[0]);
}

test "buyItem invalid slot" {
    var state = ShopState.init();
    var currency: u32 = 100;
    const result = buyItem(&state, 0, &currency);
    try std.testing.expectEqual(BuyResult.invalid_slot, result);
}
