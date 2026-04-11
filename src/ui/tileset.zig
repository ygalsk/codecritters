const std = @import("std");
const vaxis = @import("vaxis");
const sprite_mod = @import("sprite.zig");
const fx = @import("fx.zig");

const Window = vaxis.Window;
const Image = vaxis.Image;

/// Tile indices in the tileset sprite strip.
/// Tileset PNG layout: [wall][floor][encounter][stairs][entrance][player] = 6 tiles.
pub const TileIndex = enum(u3) {
    wall = 0,
    floor = 1,
    encounter = 2,
    stairs = 3,
    entrance = 4,
    player = 5,
};

/// Number of tile types in a tileset strip.
pub const TILE_COUNT: u8 = 6;

/// Pixels per tile in the tileset PNG.
pub const TILE_PX: u16 = 16;

pub const Tileset = struct {
    /// Kitty image for the tileset strip (null if not in Kitty mode or load failed).
    kitty_image: ?Image = null,
    /// Pixel data for half-block fallback rendering.
    pixels: ?[]sprite_mod.Pixel = null,
    /// Width of the full tileset strip in pixels.
    sheet_width: u32 = 0,
    /// Height of the tileset strip in pixels.
    sheet_height: u32 = 0,

    /// Load pixel data from a tileset PNG (horizontal strip of TILE_COUNT tiles).
    pub fn loadFromFile(alloc: std.mem.Allocator, path: []const u8) !Tileset {
        const zigimg = vaxis.zigimg;
        var read_buf: [4096]u8 = undefined;
        var img = try zigimg.Image.fromFilePath(alloc, path, &read_buf);
        defer img.deinit(alloc);

        const w: u32 = @intCast(img.width);
        const h: u32 = @intCast(img.height);
        const pixel_count = w * h;
        var pixels = try alloc.alloc(sprite_mod.Pixel, pixel_count);

        var iter = img.iterator();
        var i: usize = 0;
        while (i < pixel_count) : (i += 1) {
            if (iter.next()) |c| {
                pixels[i] = .{
                    .r = @intFromFloat(@max(0.0, @min(1.0, c.r)) * 255.0),
                    .g = @intFromFloat(@max(0.0, @min(1.0, c.g)) * 255.0),
                    .b = @intFromFloat(@max(0.0, @min(1.0, c.b)) * 255.0),
                    .a = @intFromFloat(@max(0.0, @min(1.0, c.a)) * 255.0),
                };
            } else break;
        }

        return .{
            .pixels = pixels,
            .sheet_width = w,
            .sheet_height = h,
        };
    }

    /// Load the Kitty image for terminals that support it.
    pub fn loadKittyImage(self: *Tileset, vx: *vaxis.Vaxis, alloc: std.mem.Allocator, tty: anytype, path: []const u8) !void {
        if (!vx.caps.kitty_graphics) return;
        self.kitty_image = try vx.loadImage(alloc, tty, .{ .path = path });
    }

    /// Render a single tile at a terminal cell position.
    /// In Kitty mode: draws the tile from the sprite strip using clip_region.
    /// In fallback mode: uses half-block rendering from pixel data.
    pub fn renderTile(
        self: *const Tileset,
        win: Window,
        tile: TileIndex,
        row: u16,
        col: u16,
        use_kitty: bool,
        brightness: f32,
    ) void {
        if (use_kitty) {
            if (self.kitty_image) |img| {
                if (self.renderKittyTile(win, img, tile, row, col)) return;
            }
        }
        self.renderHalfBlockTile(win, tile, row, col, brightness);
    }

    fn renderKittyTile(self: *const Tileset, win: Window, img: Image, tile: TileIndex, row: u16, col: u16) bool {
        _ = self;
        const tile_x: u16 = @as(u16, @intFromEnum(tile)) * TILE_PX;

        const sub = win.child(.{
            .x_off = col,
            .y_off = row,
            .width = 1,
            .height = 1,
        });

        img.draw(sub, .{
            .clip_region = .{
                .x = tile_x,
                .y = 0,
                .width = TILE_PX,
                .height = TILE_PX,
            },
            .scale = .fill,
        }) catch return false;
        return true;
    }

    fn renderHalfBlockTile(self: *const Tileset, win: Window, tile: TileIndex, row: u16, col: u16, brightness: f32) void {
        const pixels = self.pixels orelse return;
        const tile_x_start: u32 = @as(u32, @intFromEnum(tile)) * TILE_PX;
        const h = self.sheet_height;
        const w = self.sheet_width;

        // Average the 16x16 tile pixels into a single half-block cell (top + bottom half)
        // Top half = rows 0..7, Bottom half = rows 8..15
        const top_color = averageRegion(pixels, w, tile_x_start, 0, TILE_PX, @intCast(h / 2));
        const bot_color = averageRegion(pixels, w, tile_x_start, @intCast(h / 2), TILE_PX, @intCast(h / 2));

        if (col >= win.width or row >= win.height) return;

        const top_rgb = fx.applyBrightness(top_color, brightness);
        const bot_rgb = fx.applyBrightness(bot_color, brightness);

        win.writeCell(col, row, .{
            .char = .{ .grapheme = "\xe2\x96\x84", .width = 1 }, // ▄
            .style = .{
                .fg = .{ .rgb = bot_rgb },
                .bg = .{ .rgb = top_rgb },
            },
        });
    }

    /// Free Kitty image if loaded.
    pub fn freeKittyImage(self: *Tileset, vx: *vaxis.Vaxis, tty: anytype) void {
        if (self.kitty_image) |img| {
            vx.freeImage(tty, img.id);
            self.kitty_image = null;
        }
    }

    pub fn deinit(self: *Tileset, alloc: std.mem.Allocator) void {
        if (self.pixels) |p| alloc.free(p);
        self.pixels = null;
    }
};

/// Average the RGB values in a rectangular region of pixel data.
fn averageRegion(pixels: []const sprite_mod.Pixel, sheet_width: u32, x0: u32, y0: u32, w: u16, h: u16) [3]u8 {
    var r_sum: u32 = 0;
    var g_sum: u32 = 0;
    var b_sum: u32 = 0;
    var count: u32 = 0;

    var y: u32 = y0;
    while (y < y0 + h) : (y += 1) {
        var x: u32 = x0;
        while (x < x0 + w) : (x += 1) {
            const idx = y * sheet_width + x;
            if (idx < pixels.len) {
                const p = pixels[idx];
                if (p.a >= 128) {
                    r_sum += p.r;
                    g_sum += p.g;
                    b_sum += p.b;
                    count += 1;
                }
            }
        }
    }

    if (count == 0) return .{ 0, 0, 0 };
    return .{
        @intCast(r_sum / count),
        @intCast(g_sum / count),
        @intCast(b_sum / count),
    };
}
