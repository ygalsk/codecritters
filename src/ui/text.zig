const std = @import("std");
const battle = @import("battle");
const moves_mod = @import("moves");

/// Format a BattleEvent into a human-readable message.
pub fn formatEvent(event: battle.BattleEvent, buf: []u8) []const u8 {
    return switch (event) {
        .damage_dealt => |d| {
            const eff_str = switch (d.effectiveness) {
                .strong => " It's super effective!",
                .weak => " Not very effective...",
                .neutral => "",
            };
            const who = if (d.attacker_is_player) "Your critter" else "Wild critter";
            return std.fmt.bufPrint(buf, "{s} used {s}! {d} damage.{s}", .{ who, d.move_name, d.damage_dealt, eff_str }) catch "...";
        },
        .move_missed => |d| {
            const who = if (d.attacker_is_player) "Your critter" else "Wild critter";
            return std.fmt.bufPrint(buf, "{s} used {s}... but it missed!", .{ who, d.move_name }) catch "...";
        },
        .status_applied => |d| {
            const target = if (d.target_is_player) "Your critter" else "Wild critter";
            return std.fmt.bufPrint(buf, "{s} is now {s}!", .{ target, statusName(d.effect) }) catch "...";
        },
        .status_tick => |d| {
            const target = if (d.target_is_player) "Your critter" else "Wild critter";
            if (d.self_damage > 0) {
                return std.fmt.bufPrint(buf, "{s} took {d} damage from {s}!", .{ target, d.self_damage, statusName(d.effect) }) catch "...";
            }
            return std.fmt.bufPrint(buf, "{s} is affected by {s}.", .{ target, statusName(d.effect) }) catch "...";
        },
        .status_expired => |d| {
            const target = if (d.target_is_player) "Your critter" else "Wild critter";
            return std.fmt.bufPrint(buf, "{s} recovered from {s}.", .{ target, statusName(d.effect) }) catch "...";
        },
        .critter_fainted => |d| {
            const who = if (d.is_player) "Your critter" else "Wild critter";
            return std.fmt.bufPrint(buf, "{s} fainted!", .{who}) catch "...";
        },
        .swapped => |d| {
            return std.fmt.bufPrint(buf, "Swapped to party slot {d}!", .{@as(u8, d.new_active) + 1}) catch "...";
        },
        .catch_result => |d| {
            if (d.success) {
                return std.fmt.bufPrint(buf, "Caught it! ({d}% chance)", .{d.catch_chance}) catch "...";
            }
            return std.fmt.bufPrint(buf, "It broke free! ({d}% chance)", .{d.catch_chance}) catch "...";
        },
        .item_used => |d| {
            return std.fmt.bufPrint(buf, "Used {s}! Healed {d} HP.", .{ d.item_name, d.heal_amount }) catch "...";
        },
        .turn_skipped => |d| {
            const who = if (d.is_player) "Your critter" else "Wild critter";
            return std.fmt.bufPrint(buf, "{s} is blocked and can't move!", .{who}) catch "...";
        },
        .self_damage => |d| {
            const who = if (d.is_player) "Your critter" else "Wild critter";
            return std.fmt.bufPrint(buf, "{s} hurt itself! {d} damage.", .{ who, d.damage_dealt }) catch "...";
        },
        .move_blocked_by_lint => |d| {
            const who = if (d.is_player) "Your critter" else "Wild critter";
            return std.fmt.bufPrint(buf, "{s}'s move was blocked by Lint!", .{who}) catch "...";
        },
    };
}

pub fn statusName(effect: moves_mod.StatusEffect) []const u8 {
    return switch (effect) {
        .none => "none",
        .blocked => "BLOCKED",
        .deprecated => "DEPRECATED",
        .segfaulted => "SEGFAULTED",
        .linted => "LINTED",
        .tilted => "TILTED",
        .in_the_zone => "IN THE ZONE",
        .spaghettified => "SPAGHETTIFIED",
    };
}

pub fn formatOutcome(outcome: battle.BattleOutcome) []const u8 {
    return switch (outcome) {
        .player_win => "You win!",
        .player_lose => "You lost...",
        .caught => "Critter caught!",
    };
}
