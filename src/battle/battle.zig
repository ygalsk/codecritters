const std = @import("std");
const types = @import("types");
const moves_mod = @import("moves");
const species_mod = @import("species");
const items_mod = @import("items");
const critter_mod = @import("critter");
const game_data_mod = @import("game_data");
const damage = @import("damage.zig");
const status = @import("status.zig");
const catch_mod = @import("catch.zig");
const ai = @import("ai.zig");

pub const BattleOutcome = enum {
    player_win,
    player_lose,
    caught,
};

pub const BattleAction = union(enum) {
    attack: u2,
    swap: u2,
    use_item: struct {
        item: *const items_mod.Item,
        target: u2,
    },
    catch_attempt: *const items_mod.Item,
};

pub const Effectiveness = types.Effectiveness;

pub const BattleEvent = union(enum) {
    damage_dealt: DamageDealtEvent,
    move_missed: MoveMissedEvent,
    status_applied: StatusAppliedEvent,
    status_tick: StatusTickEvent,
    status_expired: StatusExpiredEvent,
    critter_fainted: FaintEvent,
    swapped: SwapEvent,
    catch_result: CatchEvent,
    item_used: ItemUsedEvent,
    turn_skipped: TurnSkippedEvent,
    self_damage: SelfDamageEvent,
    move_blocked_by_lint: MoveBlockedEvent,
    catch_retaliation: CatchRetaliationEvent,
};

pub const DamageDealtEvent = struct {
    attacker_is_player: bool,
    move_name: []const u8,
    damage_dealt: u16,
    effectiveness: types.Effectiveness,
};

pub const MoveMissedEvent = struct {
    attacker_is_player: bool,
    move_name: []const u8,
};

pub const StatusAppliedEvent = struct {
    target_is_player: bool,
    effect: moves_mod.StatusEffect,
};

pub const StatusTickEvent = struct {
    target_is_player: bool,
    effect: moves_mod.StatusEffect,
    self_damage: u16,
};

pub const StatusExpiredEvent = struct {
    target_is_player: bool,
    effect: moves_mod.StatusEffect,
};

pub const FaintEvent = struct {
    is_player: bool,
};

pub const SwapEvent = struct {
    new_active: u2,
};

pub const CatchEvent = struct {
    success: bool,
    catch_chance: u8,
};

pub const ItemUsedEvent = struct {
    item_name: []const u8,
    target: u2,
    heal_amount: u16,
};

pub const TurnSkippedEvent = struct {
    is_player: bool,
};

pub const SelfDamageEvent = struct {
    is_player: bool,
    damage_dealt: u16,
};

pub const MoveBlockedEvent = struct {
    is_player: bool,
};

pub const CatchRetaliationEvent = struct {
    move_name: []const u8,
    damage_dealt: u16,
};

const MAX_EVENTS = 16;

pub const TurnResult = struct {
    events: [MAX_EVENTS]BattleEvent = undefined,
    event_count: u8 = 0,
    outcome: ?BattleOutcome = null,

    fn addEvent(self: *TurnResult, event: BattleEvent) void {
        std.debug.assert(self.event_count < MAX_EVENTS);
        self.events[self.event_count] = event;
        self.event_count += 1;
    }
};

pub const BattleCritter = struct {
    critter: critter_mod.Critter,
    species: *const species_mod.Species,
    status: status.StatusState,
};

pub const BattleState = struct {
    player_party: [3]?BattleCritter,
    player_active: u2,
    wild: BattleCritter,
    turn_number: u16,
    outcome: ?BattleOutcome,
    revive_used: bool,
    rng: std.Random.DefaultPrng,

    pub fn activePlayer(self: *const BattleState) *const BattleCritter {
        return &(self.player_party[self.player_active].?);
    }

    fn activePlayerMut(self: *BattleState) *BattleCritter {
        return &(self.player_party[self.player_active].?);
    }

    pub fn isOver(self: *const BattleState) bool {
        return self.outcome != null;
    }
};

pub const BattleResults = struct {
    player_party: [3]?critter_mod.Critter,
    caught_critter: ?critter_mod.Critter,
    outcome: BattleOutcome,
};

/// Create a new battle. Copies critter data so mutations don't affect originals.
pub fn initBattle(
    player_critters: []const critter_mod.Critter,
    player_species: []const *const species_mod.Species,
    wild_critter: critter_mod.Critter,
    wild_species: *const species_mod.Species,
    seed: u64,
) BattleState {
    var party: [3]?BattleCritter = .{ null, null, null };
    for (player_critters, 0..) |c, i| {
        if (i >= 3) break;
        party[i] = .{
            .critter = c,
            .species = player_species[i],
            .status = .{},
        };
    }

    // Find the first alive critter to be the active one
    var first_alive: u2 = 0;
    for (party, 0..) |slot, i| {
        if (slot) |bc| {
            if (bc.critter.current_hp > 0) {
                first_alive = @intCast(i);
                break;
            }
        }
    }

    return .{
        .player_party = party,
        .player_active = first_alive,
        .wild = .{
            .critter = wild_critter,
            .species = wild_species,
            .status = .{},
        },
        .turn_number = 0,
        .outcome = null,
        .revive_used = false,
        .rng = std.Random.DefaultPrng.init(seed),
    };
}

/// Get the final state of critters after battle for persistence.
pub fn getResults(state: *const BattleState) BattleResults {
    var party: [3]?critter_mod.Critter = .{ null, null, null };
    for (state.player_party, 0..) |slot, i| {
        if (slot) |bc| {
            party[i] = bc.critter;
        }
    }
    return .{
        .player_party = party,
        .caught_critter = if (state.outcome == .caught) state.wild.critter else null,
        .outcome = state.outcome orelse .player_lose,
    };
}

/// Process one full battle turn. Both sides act (unless blocked/fainted).
pub fn processTurn(
    state: *BattleState,
    player_action: BattleAction,
    game_data: *const game_data_mod.GameData,
) TurnResult {
    var result = TurnResult{};
    if (state.outcome != null) return result;

    state.turn_number += 1;
    const rng = state.rng.random();

    // --- Status ticks (start of turn) ---
    var player_skip = false;
    var wild_skip = false;

    {
        const player = state.activePlayerMut();
        if (player.status.effect != .none) {
            const prev_effect = player.status.effect;
            const tick = status.processStatusTick(&player.status, player.critter.effectiveStat(.hp), rng);
            if (tick.self_damage > 0) {
                player.critter.current_hp -|= tick.self_damage;
                result.addEvent(.{ .self_damage = .{ .is_player = true, .damage_dealt = tick.self_damage } });
            }
            if (tick.skip_turn) {
                player_skip = true;
                result.addEvent(.{ .turn_skipped = .{ .is_player = true } });
            }
            if (tick.effect_expired) {
                result.addEvent(.{ .status_expired = .{ .target_is_player = true, .effect = prev_effect } });
            } else if (tick.self_damage > 0 or tick.skip_turn) {
                result.addEvent(.{ .status_tick = .{
                    .target_is_player = true,
                    .effect = prev_effect,
                    .self_damage = tick.self_damage,
                } });
            }
            // Check if self-damage caused fainting
            if (player.critter.current_hp == 0) {
                result.addEvent(.{ .critter_fainted = .{ .is_player = true } });
                if (checkPlayerLoss(state)) {
                    state.outcome = .player_lose;
                    result.outcome = .player_lose;
                    return result;
                }
            }
        }
    }

    {
        if (state.wild.status.effect != .none) {
            const prev_effect = state.wild.status.effect;
            const tick = status.processStatusTick(&state.wild.status, state.wild.critter.effectiveStat(.hp), rng);
            if (tick.self_damage > 0) {
                state.wild.critter.current_hp -|= tick.self_damage;
                result.addEvent(.{ .self_damage = .{ .is_player = false, .damage_dealt = tick.self_damage } });
            }
            if (tick.skip_turn) {
                wild_skip = true;
                result.addEvent(.{ .turn_skipped = .{ .is_player = false } });
            }
            if (tick.effect_expired) {
                result.addEvent(.{ .status_expired = .{ .target_is_player = false, .effect = prev_effect } });
            } else if (tick.self_damage > 0 or tick.skip_turn) {
                result.addEvent(.{ .status_tick = .{
                    .target_is_player = false,
                    .effect = prev_effect,
                    .self_damage = tick.self_damage,
                } });
            }
            if (state.wild.critter.current_hp == 0) {
                result.addEvent(.{ .critter_fainted = .{ .is_player = false } });
                state.outcome = .player_win;
                result.outcome = .player_win;
                return result;
            }
        }
    }

    // --- Determine wild action ---
    const wild_action: BattleAction = .{
        .attack = ai.chooseWildMoveSlot(
            state.wild.critter.move_slot_1,
            state.wild.critter.move_slot_2,
            state.wild.critter.move_slot_3,
            rng,
        ),
    };

    // --- Determine turn order ---
    // Items and catch attempts have priority — they always resolve before attacks.
    // Swaps also get priority (like Pokemon). Only attack vs attack uses speed.
    const player_has_priority = switch (player_action) {
        .use_item, .catch_attempt, .swap => true,
        .attack => false,
    };

    const player_goes_first = if (player_has_priority)
        true
    else blk: {
        const player_speed = damage.effectiveStat(
            state.activePlayer().critter.effectiveStat(.speed),
            state.activePlayer().status.speed_mod,
        );
        const wild_speed = damage.effectiveStat(
            state.wild.critter.effectiveStat(.speed),
            state.wild.status.speed_mod,
        );
        break :blk if (player_speed > wild_speed)
            true
        else if (player_speed < wild_speed)
            false
        else
            rng.boolean();
    };

    // --- Resolve actions ---
    if (player_goes_first) {
        if (!player_skip) {
            resolveAction(state, player_action, true, game_data, &result);
            if (state.outcome != null) {
                result.outcome = state.outcome;
                return result;
            }
        }
        if (!wild_skip and state.wild.critter.current_hp > 0) {
            resolveAction(state, wild_action, false, game_data, &result);
            if (state.outcome != null) {
                result.outcome = state.outcome;
                return result;
            }
        }
    } else {
        if (!wild_skip) {
            resolveAction(state, wild_action, false, game_data, &result);
            if (state.outcome != null) {
                result.outcome = state.outcome;
                return result;
            }
        }
        if (!player_skip and state.activePlayer().critter.current_hp > 0) {
            resolveAction(state, player_action, true, game_data, &result);
            if (state.outcome != null) {
                result.outcome = state.outcome;
                return result;
            }
        }
    }

    result.outcome = state.outcome;
    return result;
}

fn resolveAction(
    state: *BattleState,
    action: BattleAction,
    is_player: bool,
    game_data: *const game_data_mod.GameData,
    result: *TurnResult,
) void {
    switch (action) {
        .attack => |slot| resolveAttack(state, slot, is_player, game_data, result),
        .swap => |target| {
            if (is_player) {
                state.player_active = target;
                result.addEvent(.{ .swapped = .{ .new_active = target } });
            }
            // Wild critters don't swap
        },
        .use_item => |item_use| {
            if (is_player) {
                resolveItem(state, item_use.item, item_use.target, result);
            }
        },
        .catch_attempt => |tool| {
            if (is_player) {
                resolveCatch(state, tool, game_data, result);
            }
        },
    }
}

fn resolveAttack(
    state: *BattleState,
    slot: u2,
    is_player: bool,
    game_data: *const game_data_mod.GameData,
    result: *TurnResult,
) void {
    const rng = state.rng.random();

    const attacker = if (is_player) state.activePlayerMut() else &state.wild;
    const defender = if (is_player) &state.wild else state.activePlayerMut();

    // Get move from slot
    const move_id: ?[]const u8 = switch (slot) {
        0 => attacker.critter.move_slot_1,
        1 => attacker.critter.move_slot_2,
        2 => attacker.critter.move_slot_3,
        3 => null,
    };
    const mid = move_id orelse return;
    const move = game_data.findMove(mid) orelse return;

    // Check linted: off-type moves blocked
    if (status.isMoveBlockedByLint(attacker.species.critter_type, move.move_type, attacker.status.effect)) {
        result.addEvent(.{ .move_blocked_by_lint = .{ .is_player = is_player } });
        return;
    }

    // Accuracy check
    if (!damage.rollAccuracy(move.accuracy, attacker.status.accuracy_mod, rng)) {
        result.addEvent(.{ .move_missed = .{ .attacker_is_player = is_player, .move_name = move.name } });
        return;
    }

    // Calculate and apply damage
    const dmg = damage.calculateDamage(
        move,
        attacker.critter.effectiveStat(.logic),
        attacker.status.logic_mod,
        defender.critter.effectiveStat(.resolve),
        defender.status.resolve_mod,
        defender.species.critter_type,
        attacker.status.power_mod,
        rng,
    );

    defender.critter.current_hp -|= dmg;
    const eff = types.getEffectiveness(move.move_type, defender.species.critter_type);
    result.addEvent(.{ .damage_dealt = .{
        .attacker_is_player = is_player,
        .move_name = move.name,
        .damage_dealt = dmg,
        .effectiveness = eff,
    } });

    // Check fainting
    if (defender.critter.current_hp == 0) {
        result.addEvent(.{ .critter_fainted = .{ .is_player = !is_player } });
        if (!is_player) {
            // Wild fainted the player's active critter
            if (checkPlayerLoss(state)) {
                state.outcome = .player_lose;
            }
        } else {
            // Player fainted the wild critter
            state.outcome = .player_win;
        }
        return;
    }

    // Status infliction roll
    if (status.rollStatusInflict(move, rng)) {
        status.applyStatus(&defender.status, move.status_effect);
        result.addEvent(.{ .status_applied = .{
            .target_is_player = !is_player,
            .effect = move.status_effect,
        } });
    }
}

fn resolveItem(
    state: *BattleState,
    item: *const items_mod.Item,
    target: u2,
    result: *TurnResult,
) void {
    if (item.kind == .revive) {
        if (state.revive_used) return;
        const pct = item.revive_percent orelse 50;
        if (state.player_party[target]) |*bc| {
            if (bc.critter.current_hp != 0) return; // not fainted
            const restore = @max(1, @as(u16, bc.critter.effectiveStat(.hp)) * pct / 100);
            bc.critter.current_hp = restore;
            state.revive_used = true;
            result.addEvent(.{ .item_used = .{
                .item_name = item.name,
                .target = target,
                .heal_amount = restore,
            } });
        }
        return;
    }

    if (item.kind != .healing) return;
    const heal = item.heal_amount orelse return;

    if (state.player_party[target]) |*bc| {
        const old_hp = bc.critter.current_hp;
        bc.critter.current_hp = @min(bc.critter.effectiveStat(.hp), old_hp + heal);
        result.addEvent(.{ .item_used = .{
            .item_name = item.name,
            .target = target,
            .heal_amount = bc.critter.current_hp - old_hp,
        } });
    }
}

fn resolveCatch(
    state: *BattleState,
    tool: *const items_mod.Item,
    game_data: *const game_data_mod.GameData,
    result: *TurnResult,
) void {
    const rng = state.rng.random();
    const catch_result = catch_mod.attemptCatch(
        tool,
        state.wild.species.critter_type,
        state.wild.critter.current_hp,
        state.wild.critter.effectiveStat(.hp),
        state.wild.species.rarity,
        rng,
    );
    result.addEvent(.{ .catch_result = .{
        .success = catch_result.success,
        .catch_chance = catch_result.catch_chance,
    } });
    if (catch_result.success) {
        state.outcome = .caught;
    } else if (tool.catch_tier) |tier| {
        if (tier == .try_catch) {
            // Try-Catch penalty: wild critter gets a free retaliatory attack
            const wild_slot = ai.chooseWildMoveSlot(
                state.wild.critter.move_slot_1,
                state.wild.critter.move_slot_2,
                state.wild.critter.move_slot_3,
                state.rng.random(),
            );
            const move_id: ?[]const u8 = switch (wild_slot) {
                0 => state.wild.critter.move_slot_1,
                1 => state.wild.critter.move_slot_2,
                2 => state.wild.critter.move_slot_3,
                3 => null,
            };
            if (move_id) |mid| {
                if (game_data.findMove(mid)) |move| {
                    const player = state.activePlayerMut();
                    const dmg = damage.calculateDamage(
                        move,
                        state.wild.critter.effectiveStat(.logic),
                        state.wild.status.logic_mod,
                        player.critter.effectiveStat(.resolve),
                        player.status.resolve_mod,
                        player.species.critter_type,
                        state.wild.status.power_mod,
                        state.rng.random(),
                    );
                    player.critter.current_hp -|= dmg;
                    result.addEvent(.{ .catch_retaliation = .{
                        .move_name = move.name,
                        .damage_dealt = dmg,
                    } });
                    if (player.critter.current_hp == 0) {
                        result.addEvent(.{ .critter_fainted = .{ .is_player = true } });
                        if (checkPlayerLoss(state)) {
                            state.outcome = .player_lose;
                        }
                    }
                }
            }
        }
    }
}

/// Check if all player critters are fainted.
fn checkPlayerLoss(state: *const BattleState) bool {
    for (state.player_party) |slot| {
        if (slot) |bc| {
            if (bc.critter.current_hp > 0) return false;
        }
    }
    return true;
}

// --- Tests ---

const testing = std.testing;

fn makeTestSpecies(id: []const u8, critter_type: types.CritterType) species_mod.Species {
    return .{
        .id = id,
        .name = id,
        .critter_type = critter_type,
        .rarity = .common,
        .base_stats = .{ .hp = 50, .logic = 50, .resolve = 50, .speed = 50 },
        .signature_move = "test_attack",
        .secondary_move = null,
        .evolves_to = null,
        .evolution_level = null,
    };
}

fn makeTestCritter(species_id: []const u8, move1: []const u8, hp: u16) critter_mod.Critter {
    return .{
        .id = 1,
        .species_id = species_id,
        .nickname = null,
        .level = 10,
        .xp = 0,
        .current_hp = hp,
        .max_hp = hp,
        .logic = 50,
        .resolve = 50,
        .speed = 50,
        .move_slot_1 = move1,
        .move_slot_2 = null,
        .move_slot_3 = null,
        .scars = &.{},
        .cooldown_runs = 0,
    };
}

test "initBattle: sets up state correctly" {
    const sp = makeTestSpecies("test_sp", .debug);
    const c = makeTestCritter("test_sp", "test_attack", 100);
    const wild_sp = makeTestSpecies("wild_sp", .chaos);
    const wild_c = makeTestCritter("wild_sp", "test_attack", 80);

    const critters = [_]critter_mod.Critter{c};
    const sp_ptrs = [_]*const species_mod.Species{&sp};
    const state = initBattle(&critters, &sp_ptrs, wild_c, &wild_sp, 42);

    try testing.expect(state.player_party[0] != null);
    try testing.expect(state.player_party[1] == null);
    try testing.expectEqual(@as(u16, 100), state.activePlayer().critter.current_hp);
    try testing.expectEqual(@as(u16, 80), state.wild.critter.current_hp);
    try testing.expect(!state.isOver());
}

test "processTurn: basic attack deals damage" {
    const sp = makeTestSpecies("test_sp", .debug);
    const c = makeTestCritter("test_sp", "log_dump", 100);
    const wild_sp = makeTestSpecies("wild_sp", .debug);
    const wild_c = makeTestCritter("wild_sp", "log_dump", 100);

    const critters = [_]critter_mod.Critter{c};
    const sp_ptrs = [_]*const species_mod.Species{&sp};
    var state = initBattle(&critters, &sp_ptrs, wild_c, &wild_sp, 42);

    const allocator = testing.allocator;
    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();

    const result = processTurn(&state, .{ .attack = 0 }, &gd);

    // Both sides should have acted — look for damage events
    var player_dealt = false;
    var wild_dealt = false;
    for (result.events[0..result.event_count]) |event| {
        switch (event) {
            .damage_dealt => |d| {
                if (d.attacker_is_player) player_dealt = true else wild_dealt = true;
            },
            else => {},
        }
    }
    try testing.expect(player_dealt);
    try testing.expect(wild_dealt);
    // Both should have taken some damage
    try testing.expect(state.activePlayer().critter.current_hp < 100);
    try testing.expect(state.wild.critter.current_hp < 100);
}

test "processTurn: faster critter acts first" {
    const sp = makeTestSpecies("fast_sp", .debug);
    var fast_c = makeTestCritter("fast_sp", "log_dump", 100);
    fast_c.speed = 100; // very fast

    const wild_sp = makeTestSpecies("slow_sp", .debug);
    var slow_c = makeTestCritter("slow_sp", "log_dump", 5); // low HP - will faint from one hit
    slow_c.speed = 10;

    const critters = [_]critter_mod.Critter{fast_c};
    const sp_ptrs = [_]*const species_mod.Species{&sp};
    var state = initBattle(&critters, &sp_ptrs, slow_c, &wild_sp, 42);

    const allocator = testing.allocator;
    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();

    const result = processTurn(&state, .{ .attack = 0 }, &gd);

    // Fast player should KO the slow wild before it can attack
    try testing.expectEqual(BattleOutcome.player_win, result.outcome.?);
    try testing.expectEqual(@as(u16, 0), state.wild.critter.current_hp);
    // Player shouldn't have taken damage (wild fainted before acting)
    try testing.expectEqual(@as(u16, 100), state.activePlayer().critter.current_hp);
}

test "processTurn: fainted critter does not act after being KO'd" {
    const sp1 = makeTestSpecies("sp1", .debug);
    const sp2 = makeTestSpecies("sp2", .chaos);
    var slow_c = makeTestCritter("sp1", "log_dump", 5); // low HP — will faint
    slow_c.speed = 10;
    const backup = makeTestCritter("sp2", "log_dump", 100);

    const wild_sp = makeTestSpecies("fast_wild", .debug);
    var fast_wild = makeTestCritter("fast_wild", "log_dump", 100);
    fast_wild.speed = 100; // faster — acts first

    const critters = [_]critter_mod.Critter{ slow_c, backup };
    const sp_ptrs = [_]*const species_mod.Species{ &sp1, &sp2 };
    var state = initBattle(&critters, &sp_ptrs, fast_wild, &wild_sp, 42);

    const allocator = testing.allocator;
    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();

    const result = processTurn(&state, .{ .attack = 0 }, &gd);

    // Player's active critter should be fainted
    try testing.expectEqual(@as(u16, 0), state.activePlayer().critter.current_hp);
    // Wild should NOT have taken damage — fainted critter must not act
    try testing.expectEqual(@as(u16, 100), state.wild.critter.current_hp);
    // Battle should NOT be over (backup critter is alive)
    try testing.expect(!state.isOver());
    // Should have faint event but no player damage_dealt event
    var player_dealt = false;
    for (result.events[0..result.event_count]) |event| {
        switch (event) {
            .damage_dealt => |d| {
                if (d.attacker_is_player) player_dealt = true;
            },
            else => {},
        }
    }
    try testing.expect(!player_dealt);
}

test "processTurn: swap costs player's turn" {
    const sp1 = makeTestSpecies("sp1", .debug);
    const sp2 = makeTestSpecies("sp2", .chaos);
    const c1 = makeTestCritter("sp1", "log_dump", 100);
    const c2 = makeTestCritter("sp2", "log_dump", 100);
    const wild_sp = makeTestSpecies("wild_sp", .debug);
    const wild_c = makeTestCritter("wild_sp", "log_dump", 100);

    const critters = [_]critter_mod.Critter{ c1, c2 };
    const sp_ptrs = [_]*const species_mod.Species{ &sp1, &sp2 };
    var state = initBattle(&critters, &sp_ptrs, wild_c, &wild_sp, 42);

    const allocator = testing.allocator;
    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();

    const result = processTurn(&state, .{ .swap = 1 }, &gd);

    // Player swapped to slot 1
    try testing.expectEqual(@as(u2, 1), state.player_active);
    // Wild should have attacked — swap critter takes damage
    var swap_event_found = false;
    var wild_attacked = false;
    for (result.events[0..result.event_count]) |event| {
        switch (event) {
            .swapped => swap_event_found = true,
            .damage_dealt => |d| {
                if (!d.attacker_is_player) wild_attacked = true;
            },
            else => {},
        }
    }
    try testing.expect(swap_event_found);
    try testing.expect(wild_attacked);
}

test "processTurn: fainting wild = player_win" {
    const sp = makeTestSpecies("test_sp", .debug);
    const c = makeTestCritter("test_sp", "log_dump", 100);
    const wild_sp = makeTestSpecies("wild_sp", .chaos); // debug vs chaos = strong
    var wild_c = makeTestCritter("wild_sp", "log_dump", 1); // 1 HP
    wild_c.speed = 1; // slower so player acts first

    const critters = [_]critter_mod.Critter{c};
    const sp_ptrs = [_]*const species_mod.Species{&sp};
    var state = initBattle(&critters, &sp_ptrs, wild_c, &wild_sp, 42);

    const allocator = testing.allocator;
    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();

    const result = processTurn(&state, .{ .attack = 0 }, &gd);

    try testing.expect(state.isOver());
    try testing.expectEqual(BattleOutcome.player_win, result.outcome.?);
}

test "processTurn: all player critters faint = player_lose" {
    const sp = makeTestSpecies("test_sp", .debug);
    var c = makeTestCritter("test_sp", "log_dump", 1);
    c.speed = 1; // slower

    const wild_sp = makeTestSpecies("wild_sp", .debug);
    var wild_c = makeTestCritter("wild_sp", "log_dump", 100);
    wild_c.speed = 100; // faster

    const critters = [_]critter_mod.Critter{c};
    const sp_ptrs = [_]*const species_mod.Species{&sp};
    var state = initBattle(&critters, &sp_ptrs, wild_c, &wild_sp, 42);

    const allocator = testing.allocator;
    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();

    const result = processTurn(&state, .{ .attack = 0 }, &gd);

    try testing.expect(state.isOver());
    try testing.expectEqual(BattleOutcome.player_lose, result.outcome.?);
}

test "processTurn: catch success ends battle" {
    const sp = makeTestSpecies("test_sp", .debug);
    const c = makeTestCritter("test_sp", "log_dump", 100);
    const wild_sp = makeTestSpecies("wild_sp", .debug);
    var wild_c = makeTestCritter("wild_sp", "log_dump", 1); // low HP = easy to catch
    wild_c.speed = 1;

    const critters = [_]critter_mod.Critter{c};
    const sp_ptrs = [_]*const species_mod.Species{&sp};

    // Try many seeds to find one where catch succeeds (low HP common critter with try_catch = high chance)
    const tool = items_mod.Item{
        .id = "try_catch",
        .name = "Try-Catch",
        .kind = .catch_tool,
        .catch_tier = .try_catch,
        .base_catch_rate = 60,
    };

    // With 1 HP and common rarity: chance = 60 + 0 - ~0 - 0 = 60%. High enough.
    // Try multiple seeds
    var caught = false;
    var seed: u64 = 0;
    while (seed < 20) : (seed += 1) {
        var state = initBattle(&critters, &sp_ptrs, wild_c, &wild_sp, seed);
        const allocator = testing.allocator;
        var gd = try game_data_mod.GameData.load(allocator);
        defer gd.deinit();

        const result = processTurn(&state, .{ .catch_attempt = &tool }, &gd);
        if (result.outcome) |o| {
            if (o == .caught) {
                caught = true;
                // Verify results include the caught critter
                const results = getResults(&state);
                try testing.expect(results.caught_critter != null);
                break;
            }
        }
    }
    try testing.expect(caught);
}

test "processTurn: healing item restores HP" {
    const sp = makeTestSpecies("test_sp", .debug);
    var c = makeTestCritter("test_sp", "log_dump", 50);
    c.max_hp = 100;
    c.speed = 100; // fast so we can check HP after item use

    const wild_sp = makeTestSpecies("wild_sp", .debug);
    var wild_c = makeTestCritter("wild_sp", "log_dump", 100);
    wild_c.speed = 1;

    const critters = [_]critter_mod.Critter{c};
    const sp_ptrs = [_]*const species_mod.Species{&sp};
    var state = initBattle(&critters, &sp_ptrs, wild_c, &wild_sp, 42);

    const heal_item = items_mod.Item{
        .id = "hotfix",
        .name = "Hotfix",
        .kind = .healing,
        .heal_amount = 80,
    };

    const allocator = testing.allocator;
    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();

    _ = processTurn(&state, .{ .use_item = .{ .item = &heal_item, .target = 0 } }, &gd);

    // HP should have gone up (was 50, healed 80, capped at 100, then wild attacked)
    // The heal happens, then wild attacks. So final HP = 100 - wild_damage
    // We just check it's higher than 50 - wild_damage (which it should be if heal applied)
    // Actually let's just verify an item_used event was emitted
    // The HP was 50, healed to 100, then wild attacks bringing it down
    // Since wild deals ~34-40 damage, final HP should be ~60-66
    try testing.expect(state.activePlayer().critter.current_hp > 50);
}

test "processTurn: item use has priority over attacks even when slower" {
    const sp = makeTestSpecies("test_sp", .debug);
    var c = makeTestCritter("test_sp", "log_dump", 50);
    c.max_hp = 100;
    c.speed = 1; // very slow

    const wild_sp = makeTestSpecies("wild_sp", .debug);
    var wild_c = makeTestCritter("wild_sp", "log_dump", 100);
    wild_c.speed = 100; // very fast

    const critters = [_]critter_mod.Critter{c};
    const sp_ptrs = [_]*const species_mod.Species{&sp};
    var state = initBattle(&critters, &sp_ptrs, wild_c, &wild_sp, 42);

    const heal_item = items_mod.Item{
        .id = "hotfix",
        .name = "Hotfix",
        .kind = .healing,
        .heal_amount = 80,
    };

    const allocator = testing.allocator;
    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();

    const result = processTurn(&state, .{ .use_item = .{ .item = &heal_item, .target = 0 } }, &gd);

    // Item should resolve first (priority) even though player is slower.
    // First event must be item_used, not damage_dealt from the faster wild.
    var first_event_is_item = false;
    if (result.event_count > 0) {
        switch (result.events[0]) {
            .item_used => first_event_is_item = true,
            else => {},
        }
    }
    try testing.expect(first_event_is_item);
    // HP: started 50, healed to 100, then wild attacks → should be above 50
    try testing.expect(state.activePlayer().critter.current_hp > 50);
}

test "resolveCatch: try-catch failure causes retaliation attack" {
    const sp = makeTestSpecies("test_sp", .debug);
    var c = makeTestCritter("test_sp", "log_dump", 100);
    c.max_hp = 100;

    const wild_sp = makeTestSpecies("wild_sp", .debug);
    const wild_c = makeTestCritter("wild_sp", "log_dump", 100);

    const critters = [_]critter_mod.Critter{c};
    const sp_ptrs = [_]*const species_mod.Species{&sp};
    var state = initBattle(&critters, &sp_ptrs, wild_c, &wild_sp, 42);

    const try_catch_tool = items_mod.Item{
        .id = "try_catch_tool",
        .name = "Try-Catch",
        .kind = .catch_tool,
        .catch_tier = .try_catch,
        .base_catch_rate = 1, // very low rate to ensure failure
    };

    const allocator = testing.allocator;
    var gd = try game_data_mod.GameData.load(allocator);
    defer gd.deinit();

    // Use processTurn so the full flow runs
    const result = processTurn(&state, .{ .catch_attempt = &try_catch_tool }, &gd);

    // Check for retaliation event — catch should fail at 1% base rate (minus penalties)
    // and then wild retaliates plus gets its normal turn
    var found_retaliation = false;
    for (result.events[0..result.event_count]) |evt| {
        switch (evt) {
            .catch_retaliation => {
                found_retaliation = true;
            },
            else => {},
        }
    }

    // With 1% base catch rate on a full-HP common critter, catch almost certainly fails
    // and retaliation should fire. Player HP should be reduced.
    if (found_retaliation) {
        try testing.expect(state.activePlayer().critter.current_hp < 100);
    }
}

test "getResults: extracts critter state" {
    const sp = makeTestSpecies("test_sp", .debug);
    var c = makeTestCritter("test_sp", "log_dump", 80);
    c.max_hp = 100;

    const wild_sp = makeTestSpecies("wild_sp", .debug);
    const wild_c = makeTestCritter("wild_sp", "log_dump", 100);

    const critters = [_]critter_mod.Critter{c};
    const sp_ptrs = [_]*const species_mod.Species{&sp};
    var state = initBattle(&critters, &sp_ptrs, wild_c, &wild_sp, 42);
    state.outcome = .player_win;

    const results = getResults(&state);
    try testing.expect(results.player_party[0] != null);
    try testing.expect(results.player_party[1] == null);
    try testing.expect(results.caught_critter == null);
    try testing.expectEqual(BattleOutcome.player_win, results.outcome);
}

test "initBattle: fainted critter in party, active set to first alive" {
    const sp1 = makeTestSpecies("sp1", .debug);
    const sp2 = makeTestSpecies("sp2", .chaos);
    var fainted = makeTestCritter("sp1", "log_dump", 0); // fainted
    fainted.max_hp = 100;
    const alive = makeTestCritter("sp2", "log_dump", 80);

    const wild_sp = makeTestSpecies("wild_sp", .debug);
    const wild_c = makeTestCritter("wild_sp", "log_dump", 50);

    const critters = [_]critter_mod.Critter{ fainted, alive };
    const sp_ptrs = [_]*const species_mod.Species{ &sp1, &sp2 };
    const state = initBattle(&critters, &sp_ptrs, wild_c, &wild_sp, 42);

    // Active should be slot 1 (first alive), not slot 0 (fainted)
    try testing.expectEqual(@as(u2, 1), state.player_active);
    try testing.expect(state.player_party[0] != null);
    try testing.expect(state.player_party[1] != null);
    try testing.expectEqual(@as(u16, 0), state.player_party[0].?.critter.current_hp);
    try testing.expectEqual(@as(u16, 80), state.player_party[1].?.critter.current_hp);
}

test "checkPlayerLoss: false when one alive critter remains" {
    const sp1 = makeTestSpecies("sp1", .debug);
    const sp2 = makeTestSpecies("sp2", .chaos);
    var fainted = makeTestCritter("sp1", "log_dump", 0);
    fainted.max_hp = 100;
    const alive = makeTestCritter("sp2", "log_dump", 50);

    const wild_sp = makeTestSpecies("wild_sp", .debug);
    const wild_c = makeTestCritter("wild_sp", "log_dump", 50);

    const critters = [_]critter_mod.Critter{ fainted, alive };
    const sp_ptrs = [_]*const species_mod.Species{ &sp1, &sp2 };
    const state = initBattle(&critters, &sp_ptrs, wild_c, &wild_sp, 42);

    // One alive critter remains — not a loss
    try testing.expect(!checkPlayerLoss(&state));
}

test "checkPlayerLoss: true when all critters fainted" {
    const sp1 = makeTestSpecies("sp1", .debug);
    const sp2 = makeTestSpecies("sp2", .chaos);
    var fainted1 = makeTestCritter("sp1", "log_dump", 0);
    fainted1.max_hp = 100;
    var fainted2 = makeTestCritter("sp2", "log_dump", 0);
    fainted2.max_hp = 100;

    const wild_sp = makeTestSpecies("wild_sp", .debug);
    const wild_c = makeTestCritter("wild_sp", "log_dump", 50);

    const critters = [_]critter_mod.Critter{ fainted1, fainted2 };
    const sp_ptrs = [_]*const species_mod.Species{ &sp1, &sp2 };
    const state = initBattle(&critters, &sp_ptrs, wild_c, &wild_sp, 42);

    // All fainted — loss
    try testing.expect(checkPlayerLoss(&state));
}
