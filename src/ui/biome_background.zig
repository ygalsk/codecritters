const std = @import("std");
const vaxis = @import("vaxis");

const Window = vaxis.Window;
const Image = vaxis.Image;

/// Z-index for biome backgrounds: below text AND below default backgrounds.
const BG_Z_INDEX: i32 = -2_000_000_000;

/// Manages a single per-biome background image rendered behind the dungeon map.
/// Kitty-only: in half-block mode, biome atmosphere is expressed through tile colors.
pub const BiomeBackground = struct {
    image: ?Image = null,

    /// Load a background image for the given biome from assets/backgrounds/<biome_id>.png.
    /// Returns a BiomeBackground (image will be null if file doesn't exist or not Kitty mode).
    pub fn load(
        vx: *vaxis.Vaxis,
        alloc: std.mem.Allocator,
        tty: anytype,
        biome_id: []const u8,
    ) BiomeBackground {
        if (!vx.caps.kitty_graphics) return .{};

        var path_buf: [128]u8 = undefined;
        const path = std.fmt.bufPrint(&path_buf, "assets/backgrounds/{s}.png", .{biome_id}) catch return .{};

        const img = vx.loadImage(alloc, tty, .{ .path = path }) catch return .{};
        return .{ .image = img };
    }

    /// Render the background image to fill the dungeon viewport area.
    /// Call before rendering tiles so it appears behind everything.
    pub fn render(self: *const BiomeBackground, win: Window, map_row: u16, map_col: u16, map_width: u16, map_height: u16) void {
        const img = self.image orelse return;

        const sub = win.child(.{
            .x_off = map_col,
            .y_off = map_row,
            .width = map_width,
            .height = map_height,
        });

        img.draw(sub, .{
            .scale = .fill,
            .z_index = BG_Z_INDEX,
        }) catch {};
    }

    /// Free the Kitty image if loaded.
    pub fn free(self: *BiomeBackground, vx: *vaxis.Vaxis, tty: anytype) void {
        if (self.image) |img| {
            vx.freeImage(tty, img.id);
            self.image = null;
        }
    }
};
