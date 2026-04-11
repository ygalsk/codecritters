const std = @import("std");
const vaxis = @import("vaxis");
const types = @import("types");
const sprite_mod = @import("sprite.zig");
const fx = @import("fx.zig");

const Window = vaxis.Window;
const Image = vaxis.Image;
const CritterType = types.CritterType;

/// Number of critter types (effect animations mapped 1:1).
const TYPE_COUNT = 7;

/// Per-type attack effect animation.
/// Loaded from horizontal strip PNGs (N frames of 16x16).
pub const EffectSprite = struct {
    pixels: ?[]sprite_mod.Pixel = null,
    kitty_image: ?Image = null,
    sheet_width: u32 = 0,
    sheet_height: u32 = 0,
    frame_count: u8 = 0,
    frame_width: u32 = 0,
    frame_duration_ms: i64 = 80,

    pub fn loadFromFile(alloc: std.mem.Allocator, path: []const u8) !EffectSprite {
        const zigimg = vaxis.zigimg;
        var read_buf: [4096]u8 = undefined;
        var img = try zigimg.Image.fromFilePath(alloc, path, &read_buf);
        defer img.deinit(alloc);

        const w: u32 = @intCast(img.width);
        const h: u32 = @intCast(img.height);
        const pixel_count = w * h;
        const frame_w = h; // assume square frames: each frame is h x h pixels
        const fc: u8 = @intCast(w / frame_w);

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
            .frame_count = fc,
            .frame_width = frame_w,
        };
    }

    pub fn loadKittyImage(self: *EffectSprite, vx: *vaxis.Vaxis, alloc: std.mem.Allocator, tty: anytype, path: []const u8) !void {
        if (!vx.caps.kitty_graphics) return;
        self.kitty_image = try vx.loadImage(alloc, tty, .{ .path = path });
    }

    /// Render a specific frame of the effect at the given position.
    /// Uses Kitty or half-block rendering.
    pub fn renderFrame(self: *const EffectSprite, win: Window, frame: u8, row: u16, col: u16, use_kitty: bool) void {
        if (use_kitty) {
            if (self.kitty_image) |img| {
                if (self.renderKittyFrame(win, img, frame, row, col)) return;
            }
        }
        self.renderHalfBlockFrame(win, frame, row, col);
    }

    fn renderKittyFrame(self: *const EffectSprite, win: Window, img: Image, frame: u8, row: u16, col: u16) bool {
        const fw: u16 = @intCast(self.frame_width);
        const frame_x: u16 = @as(u16, frame) * fw;
        const sprite_cols: u16 = fw;
        const sprite_rows: u16 = @intCast(self.sheet_height / 2);

        const sub = win.child(.{
            .x_off = col,
            .y_off = row,
            .width = sprite_cols,
            .height = sprite_rows,
        });

        img.draw(sub, .{
            .clip_region = .{
                .x = frame_x,
                .y = 0,
                .width = fw,
                .height = @intCast(self.sheet_height),
            },
            .scale = .fit,
            .z_index = 10, // above sprites
        }) catch return false;
        return true;
    }

    fn renderHalfBlockFrame(self: *const EffectSprite, win: Window, frame: u8, row: u16, col: u16) void {
        const pixels = self.pixels orelse return;
        const fw = self.frame_width;
        const h = self.sheet_height;
        const cell_rows: u32 = h / 2;
        const frame_x_start: u32 = @as(u32, frame) * fw;

        var cy: u32 = 0;
        while (cy < cell_rows) : (cy += 1) {
            var cx: u32 = 0;
            while (cx < fw) : (cx += 1) {
                const top_idx = (cy * 2) * self.sheet_width + (frame_x_start + cx);
                const bot_idx = (cy * 2 + 1) * self.sheet_width + (frame_x_start + cx);

                const top = if (top_idx < pixels.len) pixels[top_idx] else sprite_mod.Pixel{ .r = 0, .g = 0, .b = 0, .a = 0 };
                const bot = if (bot_idx < pixels.len) pixels[bot_idx] else sprite_mod.Pixel{ .r = 0, .g = 0, .b = 0, .a = 0 };

                const top_vis = top.a >= 128;
                const bot_vis = bot.a >= 128;
                if (!top_vis and !bot_vis) continue;

                const win_col = col + @as(u16, @intCast(cx));
                const win_row = row + @as(u16, @intCast(cy));
                if (win_col >= win.width or win_row >= win.height) continue;

                if (top_vis and bot_vis) {
                    win.writeCell(win_col, win_row, .{
                        .char = .{ .grapheme = "\xe2\x96\x84", .width = 1 }, // ▄
                        .style = .{
                            .fg = .{ .rgb = .{ bot.r, bot.g, bot.b } },
                            .bg = .{ .rgb = .{ top.r, top.g, top.b } },
                        },
                    });
                } else if (top_vis) {
                    win.writeCell(win_col, win_row, .{
                        .char = .{ .grapheme = "\xe2\x96\x80", .width = 1 }, // ▀
                        .style = .{ .fg = .{ .rgb = .{ top.r, top.g, top.b } } },
                    });
                } else {
                    win.writeCell(win_col, win_row, .{
                        .char = .{ .grapheme = "\xe2\x96\x84", .width = 1 }, // ▄
                        .style = .{ .fg = .{ .rgb = .{ bot.r, bot.g, bot.b } } },
                    });
                }
            }
        }
    }

    pub fn totalDurationMs(self: *const EffectSprite) i64 {
        return @as(i64, self.frame_count) * self.frame_duration_ms;
    }

    pub fn freeKittyImage(self: *EffectSprite, vx: *vaxis.Vaxis, tty: anytype) void {
        if (self.kitty_image) |img| {
            vx.freeImage(tty, img.id);
            self.kitty_image = null;
        }
    }

    pub fn deinit(self: *EffectSprite, alloc: std.mem.Allocator) void {
        if (self.pixels) |p| alloc.free(p);
        self.pixels = null;
    }
};

/// Map of effect sprites indexed by CritterType.
pub const EffectSpriteMap = struct {
    effects: [TYPE_COUNT]EffectSprite = .{EffectSprite{}} ** TYPE_COUNT,
    loaded: [TYPE_COUNT]bool = .{false} ** TYPE_COUNT,

    pub fn load(self: *EffectSpriteMap, alloc: std.mem.Allocator) void {
        const type_names = [_][]const u8{ "debug", "patience", "chaos", "wisdom", "snark", "vibe", "legacy" };
        for (type_names, 0..) |name, i| {
            var path_buf: [128]u8 = undefined;
            const path = std.fmt.bufPrint(&path_buf, "assets/effects/{s}.png", .{name}) catch continue;
            if (EffectSprite.loadFromFile(alloc, path)) |es| {
                self.effects[i] = es;
                self.loaded[i] = true;
            } else |_| {}
        }
    }

    pub fn loadKittyImages(self: *EffectSpriteMap, vx: *vaxis.Vaxis, alloc: std.mem.Allocator, tty: anytype) void {
        const type_names = [_][]const u8{ "debug", "patience", "chaos", "wisdom", "snark", "vibe", "legacy" };
        for (type_names, 0..) |name, i| {
            if (!self.loaded[i]) continue;
            var path_buf: [128]u8 = undefined;
            const path = std.fmt.bufPrint(&path_buf, "assets/effects/{s}.png", .{name}) catch continue;
            self.effects[i].loadKittyImage(vx, alloc, tty, path) catch {};
        }
    }

    pub fn get(self: *const EffectSpriteMap, critter_type: CritterType) ?*const EffectSprite {
        const idx = @intFromEnum(critter_type);
        if (idx < TYPE_COUNT and self.loaded[idx]) return &self.effects[idx];
        return null;
    }

    pub fn deinit(self: *EffectSpriteMap, alloc: std.mem.Allocator, vx: *vaxis.Vaxis, tty: anytype) void {
        for (&self.effects, 0..) |*e, i| {
            if (self.loaded[i]) {
                e.freeKittyImage(vx, tty);
                e.deinit(alloc);
            }
        }
    }
};
