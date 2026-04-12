/// Unified transition type returned by all screen handleInput methods.
/// Replaces per-screen flags (done, selection, pending_*, extracted, etc.)
/// with a single tagged union that the main loop dispatches on.
pub const ScreenResult = union(enum) {
    // Navigation transitions
    goto_hub,
    goto_party_select,
    goto_roster: ScreenContext,
    goto_inventory: ScreenContext,
    goto_dungeon,
    goto_battle: BattleRequest,
    goto_shop,
    goto_run_over,
    goto_meta_shop,
    goto_codex,

    // Domain side-effects (screen asks main to persist something)
    persist_swap: SwapRequest,
    persist_equip: EquipRequest,
    persist_item_use: ItemUseRequest,
    persist_meta_purchase: MetaPurchaseRequest,
    start_extraction,

    // Quit the application
    quit,

    /// Distinguishes whether a screen was opened from the hub or mid-dungeon.
    /// Replaces the old `from_dungeon` boolean flag in main.zig.
    pub const ScreenContext = enum { from_hub, from_dungeon };

    /// Battle encounter data, passed when dungeon triggers a fight.
    /// Fields match dungeon_mod.EncounterInfo but defined inline
    /// to avoid coupling the UI type system to the dungeon engine.
    pub const BattleRequest = struct {
        species_id: []const u8,
        level: u8,
        is_boss: bool,
    };

    /// Roster position swap request.
    pub const SwapRequest = struct {
        id_a: u64,
        id_b: u64,
    };

    /// Move disc equip request.
    pub const EquipRequest = struct {
        critter_idx: u8,
        item_id: []const u8,
        move_id: []const u8,
    };

    /// Meta shop purchase request.
    pub const MetaPurchaseRequest = struct {
        upgrade_index: u8,
    };

    /// Item use request with context for persistence routing.
    pub const ItemUseRequest = struct {
        item_id: []const u8,
        target_idx: u8,
        heal_amount: u16,
        context: ScreenContext,
    };
};
