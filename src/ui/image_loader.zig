// Shared PNG pixel loading — eliminates duplication across sprite, tileset, and effect_sprites.

const std = @import("std");
const vaxis = @import("vaxis");
const sprite_mod = @import("sprite.zig");

pub const Pixel = sprite_mod.Pixel;

pub const LoadResult = struct {
    pixels: []Pixel,
    width: u32,
    height: u32,
};

/// Load a PNG file and convert its pixels to u8 RGBA via zigimg's format-agnostic iterator.
pub fn loadPixels(alloc: std.mem.Allocator, path: []const u8) !LoadResult {
    const zigimg = vaxis.zigimg;
    var read_buf: [4096]u8 = undefined;
    var img = try zigimg.Image.fromFilePath(alloc, path, &read_buf);
    defer img.deinit(alloc);

    const w: u32 = @intCast(img.width);
    const h: u32 = @intCast(img.height);
    const pixel_count = w * h;
    var pixels = try alloc.alloc(Pixel, pixel_count);

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
        .width = w,
        .height = h,
    };
}
