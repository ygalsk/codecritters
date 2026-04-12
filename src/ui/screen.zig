const std = @import("std");
const vaxis = @import("vaxis");
const ScreenResult = @import("screen_result.zig").ScreenResult;

const TitleScreen = @import("title_screen.zig").TitleScreen;
const RecapScreen = @import("recap_screen.zig").RecapScreen;
const HubScreen = @import("hub_screen.zig").HubScreen;
const PartySelectScreen = @import("party_select_screen.zig").PartySelectScreen;
const RosterScreen = @import("roster_screen.zig").RosterScreen;
const InventoryScreen = @import("inventory_screen.zig").InventoryScreen;
const DungeonScreen = @import("dungeon_screen.zig").DungeonScreen;
const BattleScreen = @import("battle_screen.zig").BattleScreen;
const ShopScreen = @import("shop_screen.zig").ShopScreen;
const RunOverScreen = @import("run_over_screen.zig").RunOverScreen;
const MetaShopScreen = @import("meta_shop_screen.zig").MetaShopScreen;
const CodexScreen = @import("codex_screen.zig").CodexScreen;

pub const Screen = union(enum) {
    title: TitleScreen,
    recap: RecapScreen,
    hub: HubScreen,
    party_select: PartySelectScreen,
    roster_view: RosterScreen,
    inventory: InventoryScreen,
    dungeon: DungeonScreen,
    battle: BattleScreen,
    shop: ShopScreen,
    run_over: RunOverScreen,
    meta_shop: MetaShopScreen,
    codex: CodexScreen,

    pub fn handleInput(self: *Screen, key: vaxis.Key) ?ScreenResult {
        switch (self.*) {
            inline else => |*s| return s.handleInput(key),
        }
    }

    pub fn render(self: *Screen, win: vaxis.Window) void {
        switch (self.*) {
            inline else => |*s| s.render(win),
        }
    }

    pub fn dirtyPtr(self: *Screen) *bool {
        switch (self.*) {
            inline else => |*s| return &s.dirty,
        }
    }

    pub fn updateAnimation(self: *Screen) void {
        switch (self.*) {
            inline else => |*s| {
                if (@hasDecl(@TypeOf(s.*), "updateAnimation")) {
                    s.updateAnimation();
                }
            },
        }
    }

    pub fn alwaysDirty(self: Screen) bool {
        return switch (self) {
            .dungeon, .meta_shop, .codex => true,
            else => false,
        };
    }

    pub fn tag(self: Screen) std.meta.Tag(Screen) {
        return self;
    }
};
