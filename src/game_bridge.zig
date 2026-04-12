// Game bridge — logic that connects engines (battle, dungeon) to persistence (db)
// and handles run lifecycle. No rendering or vaxis dependencies.

const std = @import("std");
const game_data_mod = @import("game_data");
const species_mod = @import("species");
const critter_mod = @import("critter");
const battle = @import("battle");
const dungeon_mod = @import("dungeon");
const leveling = @import("leveling");
const db = @import("db/db.zig");
const roster_db = @import("db/roster.zig");
const meta_upgrades = @import("ui/meta_upgrades.zig");
const sound = @import("ui/sound.zig");
const battle_screen_mod = @import("ui/battle_screen.zig");
const InventorySlot = battle_screen_mod.InventorySlot;

pub fn seedStartersIfEmpty(database: *db.Db, gd: *const game_data_mod.GameData) !void {
    const roster = try roster_db.loadRoster(database, std.heap.page_allocator);
    defer roster_db.freeRoster(std.heap.page_allocator, roster);
    if (roster.len > 0) return;

    const println_sp = gd.findSpecies("println") orelse return;
    const goto_sp = gd.findSpecies("goto") orelse return;

    var println = critter_mod.Critter.createFromSpecies(println_sp, 5);
    var goto_c = critter_mod.Critter.createFromSpecies(goto_sp, 5);

    _ = try roster_db.saveCritter(database, &println);
    _ = try roster_db.saveCritter(database, &goto_c);
}

/// Copy non-null dungeon party members into compact buffers, returning count and sparse index mapping.
pub fn compactDungeonParty(
    state: *const dungeon_mod.DungeonState,
    buf: *[3]critter_mod.Critter,
    sp_buf: *[3]?*const species_mod.Species,
    map: *[3]u8,
) usize {
    var count: usize = 0;
    for (state.party, 0..) |maybe, i| {
        if (maybe) |c| {
            buf[count] = c;
            sp_buf[count] = state.party_species[i];
            map[count] = @intCast(i);
            count += 1;
        }
    }
    return count;
}

pub fn rosterCount(database: *db.Db) u16 {
    return roster_db.countCritters(database);
}

pub fn startBattle(
    dungeon_state: *dungeon_mod.DungeonState,
    info: dungeon_mod.EncounterInfo,
    gd: *const game_data_mod.GameData,
    inv_bridge: *[dungeon_mod.MAX_RUN_ITEMS]InventorySlot,
    inv_bridge_count: *usize,
    inv_pre_counts: *[dungeon_mod.MAX_RUN_ITEMS]u8,
    battle_state: *battle.BattleState,
) bool {
    const wild_sp = gd.findSpecies(info.species_id) orelse return false;
    const wild_critter = critter_mod.Critter.createFromSpecies(wild_sp, info.level);

    var party_critters: [3]critter_mod.Critter = undefined;
    var party_species: [3]*const species_mod.Species = undefined;
    var party_count: usize = 0;
    for (dungeon_state.party, 0..) |maybe, i| {
        if (maybe) |c| {
            if (dungeon_state.party_species[i]) |sp| {
                party_critters[i] = c;
                party_species[i] = sp;
                party_count = i + 1;
            }
        }
    }
    if (party_count == 0) return false;

    inv_bridge_count.* = 0;
    for (dungeon_state.run_inventory[0..dungeon_state.run_inventory_count]) |maybe_item| {
        const item = maybe_item orelse continue;
        const game_item = gd.findItem(item.item_id) orelse continue;
        const count: u8 = @intCast(@min(item.count, 255));
        inv_bridge[inv_bridge_count.*] = .{ .item = game_item, .count = count };
        inv_pre_counts[inv_bridge_count.*] = count;
        inv_bridge_count.* += 1;
    }

    const seed: u64 = @intCast(std.time.milliTimestamp());
    battle_state.* = battle.initBattle(
        party_critters[0..party_count],
        party_species[0..party_count],
        wild_critter,
        wild_sp,
        seed,
    );
    return true;
}

pub fn finishBattle(
    dungeon_state: *dungeon_mod.DungeonState,
    battle_state: *const battle.BattleState,
    inv_bridge: *const [dungeon_mod.MAX_RUN_ITEMS]InventorySlot,
    inv_bridge_count: usize,
    inv_pre_counts: *const [dungeon_mod.MAX_RUN_ITEMS]u8,
) dungeon_mod.EncounterResult {
    const b_outcome = battle_state.outcome orelse .player_lose;
    const d_outcome: dungeon_mod.EncounterOutcome = switch (b_outcome) {
        .player_win => .player_win,
        .player_lose => .player_lose,
        .caught => .caught,
    };

    var updated_party: [3]?critter_mod.Critter = .{ null, null, null };
    for (battle_state.player_party, 0..) |maybe_bc, i| {
        if (maybe_bc) |bc| {
            updated_party[i] = bc.critter;
        }
    }

    var caught_species_id: ?[]const u8 = null;
    var caught_level: u8 = 0;
    if (b_outcome == .caught) {
        caught_species_id = battle_state.wild.species.id;
        caught_level = battle_state.wild.critter.level;
    }

    const enc_result = dungeon_mod.resolveEncounter(dungeon_state, d_outcome, updated_party, caught_species_id, caught_level);

    // Sync consumed inventory items back to dungeon
    var bridge_idx: usize = 0;
    for (dungeon_state.run_inventory[0..dungeon_state.run_inventory_count]) |*maybe_item| {
        if (maybe_item.*) |*item| {
            if (bridge_idx < inv_bridge_count) {
                const consumed = inv_pre_counts[bridge_idx] -| inv_bridge[bridge_idx].count;
                if (consumed > 0) {
                    item.count -|= consumed;
                }
                bridge_idx += 1;
            }
        }
    }

    return enc_result;
}

pub fn awardBattleXp(
    dungeon_state: *dungeon_mod.DungeonState,
    gd: *const game_data_mod.GameData,
    active_idx: u2,
    enemy_level: u8,
    is_boss: bool,
) u32 {
    const xp_amount = leveling.battleXpAward(enemy_level, is_boss);
    const i: usize = active_idx;

    if (dungeon_state.party[i]) |*critter| {
        if (critter.current_hp == 0) return xp_amount;
        const result = leveling.awardXp(critter, xp_amount, gd);

        if (result.evolved) {
            if (result.new_species_id) |new_id| {
                dungeon_state.party_species[i] = gd.findSpecies(new_id);
            }
            sound.beep();
        } else if (result.levels_gained > 0) {
            sound.beep();
        }
    }
    return xp_amount;
}

pub fn persistCatches(
    dungeon_state: *const dungeon_mod.DungeonState,
    gd: *const game_data_mod.GameData,
    database: *db.Db,
) void {
    for (dungeon_state.catches[0..dungeon_state.catch_count]) |maybe_catch| {
        const catch_rec = maybe_catch orelse continue;
        const sp = gd.findSpecies(catch_rec.species_id) orelse continue;
        var new_critter = critter_mod.Critter.createFromSpecies(sp, catch_rec.level);
        _ = roster_db.saveCritter(database, &new_critter) catch |err| {
            std.log.err("persistCatches: saveCritter failed: {}", .{err});
        };
    }
}

pub fn handleExtraction(
    dungeon_state: *dungeon_mod.DungeonState,
    gd: *const game_data_mod.GameData,
    database: *db.Db,
) void {
    persistCatches(dungeon_state, gd, database);
    persistRunInventory(dungeon_state, database);
    awardExtractionXp(dungeon_state, gd);
    healPartyOnExtraction(dungeon_state);
}

pub fn awardExtractionXp(
    dungeon_state: *dungeon_mod.DungeonState,
    gd: *const game_data_mod.GameData,
) void {
    const bonus = 5 + @as(u32, dungeon_state.floor_number) * 2;
    for (&dungeon_state.party, 0..) |*maybe_critter, i| {
        if (maybe_critter.*) |*critter| {
            if (critter.current_hp == 0) continue;
            const result = leveling.awardXp(critter, bonus, gd);
            if (result.evolved) {
                if (result.new_species_id) |new_id| {
                    dungeon_state.party_species[i] = gd.findSpecies(new_id);
                }
                sound.beep();
            } else if (result.levels_gained > 0) {
                sound.beep();
            }
        }
    }
}

pub fn healPartyOnExtraction(dungeon_state: *dungeon_mod.DungeonState) void {
    for (&dungeon_state.party) |*maybe_critter| {
        if (maybe_critter.*) |*c| {
            if (c.current_hp > 0) {
                c.current_hp = c.effectiveStat(.hp);
            } else {
                c.cooldown_runs = 1;
            }
        }
    }
}

pub fn allUnavailable(roster: []const critter_mod.Critter) bool {
    for (roster) |critter| {
        if (critter.isAvailable()) return false;
    }
    return true;
}

pub fn decrementCooldowns(roster: []critter_mod.Critter, database: *db.Db) void {
    for (roster) |*critter| {
        if (critter.cooldown_runs > 0) {
            critter.cooldown_runs -= 1;
            // Heal to full when cooldown expires
            if (critter.cooldown_runs == 0) {
                critter.current_hp = critter.effectiveStat(.hp);
            }
            _ = roster_db.saveCritter(database, critter) catch |err| {
                std.log.err("decrementCooldowns: saveCritter failed: {}", .{err});
            };
        }
    }
}

pub fn persistPendingScars(
    dungeon_state: *const dungeon_mod.DungeonState,
    database: *db.Db,
    run_party_ids: *const [3]u64,
) void {
    for (dungeon_state.pending_scars[0..dungeon_state.pending_scar_count]) |scar| {
        const critter_id = run_party_ids[scar.party_index];
        if (critter_id != 0) {
            roster_db.addScar(database, @intCast(critter_id), scar.stat, -1) catch |err| {
                std.log.err("persistPendingScars: addScar failed: {}", .{err});
            };
        }
    }
}

pub fn savePartyState(
    dungeon_state: *const dungeon_mod.DungeonState,
    database: *db.Db,
    run_party_ids: *const [3]u64,
) void {
    for (dungeon_state.party, 0..) |maybe_critter, i| {
        if (maybe_critter) |critter| {
            if (run_party_ids[i] != 0) {
                var save_critter = critter;
                save_critter.id = run_party_ids[i];
                _ = roster_db.saveCritter(database, &save_critter) catch |err| {
                    std.log.err("savePartyState: saveCritter failed: {}", .{err});
                };
            }
        }
    }
}

pub fn persistRunInventory(
    dungeon_state: *const dungeon_mod.DungeonState,
    database: *db.Db,
) void {
    for (dungeon_state.run_inventory[0..dungeon_state.run_inventory_count]) |maybe_item| {
        const item = maybe_item orelse continue;
        if (item.count > 0) {
            roster_db.addInventoryItem(database, item.item_id, @intCast(item.count)) catch |err| {
                std.log.err("persistRunInventory: addInventoryItem failed: {}", .{err});
            };
        }
    }
    if (dungeon_state.currency > 0) {
        roster_db.addCurrency(database, dungeon_state.currency) catch |err| {
            std.log.err("persistRunInventory: addCurrency failed: {}", .{err});
        };
        // Track lifetime currency earned
        roster_db.incrementMetaStat(database, meta_upgrades.STAT_CURRENCY_EARNED, dungeon_state.currency) catch {};
    }
}
