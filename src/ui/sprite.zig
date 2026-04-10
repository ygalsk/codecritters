const std = @import("std");
const vaxis = @import("vaxis");

const Window = vaxis.Window;
const Image = vaxis.Image;

pub const Pixel = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

/// Max number of sprite sheets that can be loaded.
const MAX_SPRITES = 16;

pub const SpriteMap = struct {
    entries: [MAX_SPRITES]Entry = undefined,
    count: u8 = 0,

    const Entry = struct {
        species_id: []const u8,
        sheet: *SpriteSheet,
    };

    pub fn get(self: *const SpriteMap, species_id: []const u8) ?*const SpriteSheet {
        for (self.entries[0..self.count]) |entry| {
            if (std.mem.eql(u8, entry.species_id, species_id)) return entry.sheet;
        }
        return null;
    }

    pub fn put(self: *SpriteMap, species_id: []const u8, sheet: *SpriteSheet) void {
        if (self.count < MAX_SPRITES) {
            self.entries[self.count] = .{ .species_id = species_id, .sheet = sheet };
            self.count += 1;
        }
    }
};

pub const SpriteSheet = struct {
    width: u32,
    height: u32,
    frame_width: u32,
    frame_count: u8,
    pixels: []Pixel,
    kitty_image: ?Image,
    alloc: std.mem.Allocator,

    const ALPHA_THRESHOLD: u8 = 128;
    // Static UTF-8 strings for half-block characters (avoids dangling pointers)
    const half_block = "▄";
    const upper_half = "▀";

    pub fn loadFromFile(alloc: std.mem.Allocator, path: []const u8) !SpriteSheet {
        const zigimg = vaxis.zigimg;
        var read_buf: [4096]u8 = undefined;
        var img = try zigimg.Image.fromFilePath(alloc, path, &read_buf);
        defer img.deinit(alloc);

        const w: u32 = @intCast(img.width);
        const h: u32 = @intCast(img.height);
        const pixel_count = w * h;
        const frame_w = w / 2; // 2 frames side by side

        var pixels = try alloc.alloc(Pixel, pixel_count);

        // Convert pixels via format-agnostic iterator (Colorf32 → u8 RGBA)
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
            .width = w,
            .height = h,
            .frame_width = frame_w,
            .frame_count = 2,
            .pixels = pixels,
            .kitty_image = null,
            .alloc = alloc,
        };
    }

    /// Load the kitty graphics image for terminals that support it.
    /// Call after loadFromFile. Pass the vaxis instance and writer from the main loop.
    pub fn loadKittyImage(self: *SpriteSheet, vx: *vaxis.Vaxis, alloc: std.mem.Allocator, tty: *std.io.Writer, path: []const u8) !void {
        if (!vx.caps.kitty_graphics) return;
        self.kitty_image = try vx.loadImage(alloc, tty, .{ .path = path });
    }

    /// Get pixel at (x, y) within a specific frame.
    fn getFramePixel(self: *const SpriteSheet, frame: u8, x: u32, y: u32) Pixel {
        const frame_x = @as(u32, frame) * self.frame_width + x;
        if (frame_x >= self.width or y >= self.height) return .{ .r = 0, .g = 0, .b = 0, .a = 0 };
        return self.pixels[y * self.width + frame_x];
    }

    /// Render sprite at given position. Automatically uses kitty if available,
    /// falls back to half-block rendering.
    pub fn render(self: *const SpriteSheet, win: Window, frame: u8, row: u16, col: u16, use_kitty: bool) void {
        if (use_kitty) {
            if (self.kitty_image) |img| {
                if (self.renderKitty(win, img, frame, row, col)) return;
            }
        }
        self.renderHalfBlock(win, frame, row, col);
    }

    /// Half-block rendering: each terminal cell = 2 vertical pixels.
    /// Uses ▄ (lower half block) with fg=bottom pixel, bg=top pixel.
    /// A 16×16 sprite renders as 16 cols × 8 rows.
    fn renderHalfBlock(self: *const SpriteSheet, win: Window, frame: u8, row: u16, col: u16) void {
        const cell_rows: u32 = self.height / 2;
        var cy: u32 = 0;
        while (cy < cell_rows) : (cy += 1) {
            const top_y = cy * 2;
            const bot_y = cy * 2 + 1;
            var cx: u32 = 0;
            while (cx < self.frame_width) : (cx += 1) {
                const top = self.getFramePixel(frame, cx, top_y);
                const bot = self.getFramePixel(frame, cx, bot_y);

                const win_col = col + @as(u16, @intCast(cx));
                const win_row = row + @as(u16, @intCast(cy));
                if (win_col >= win.width or win_row >= win.height) continue;

                const top_vis = top.a >= ALPHA_THRESHOLD;
                const bot_vis = bot.a >= ALPHA_THRESHOLD;

                if (!top_vis and !bot_vis) continue;

                if (top_vis and bot_vis) {
                    win.writeCell(win_col, win_row, .{
                        .char = .{ .grapheme = half_block, .width = 1 },
                        .style = .{
                            .fg = .{ .rgb = .{ bot.r, bot.g, bot.b } },
                            .bg = .{ .rgb = .{ top.r, top.g, top.b } },
                        },
                    });
                } else if (top_vis) {
                    win.writeCell(win_col, win_row, .{
                        .char = .{ .grapheme = upper_half, .width = 1 },
                        .style = .{
                            .fg = .{ .rgb = .{ top.r, top.g, top.b } },
                        },
                    });
                } else {
                    win.writeCell(win_col, win_row, .{
                        .char = .{ .grapheme = half_block, .width = 1 },
                        .style = .{
                            .fg = .{ .rgb = .{ bot.r, bot.g, bot.b } },
                        },
                    });
                }
            }
        }
    }

    /// Kitty graphics rendering: uses vaxis Image API with clip_region for frame selection.
    /// Returns true on success, false on failure (caller should fall back to half-block).
    fn renderKitty(self: *const SpriteSheet, win: Window, img: Image, frame: u8, row: u16, col: u16) bool {
        const frame_x: u16 = @as(u16, frame) * @as(u16, @intCast(self.frame_width));
        const sprite_cols: u16 = @intCast(self.frame_width);
        const sprite_rows: u16 = @intCast(self.height / 2);

        const sub = win.child(.{
            .x_off = @intCast(col),
            .y_off = @intCast(row),
            .width = sprite_cols,
            .height = sprite_rows,
        });

        img.draw(sub, .{
            .clip_region = .{
                .x = frame_x,
                .y = 0,
                .width = @intCast(self.frame_width),
                .height = @intCast(self.height),
            },
            .scale = .fit,
        }) catch return false;
        return true;
    }

    /// Returns the terminal dimensions of a rendered sprite.
    pub fn displaySize(self: *const SpriteSheet) struct { cols: u16, rows: u16 } {
        return .{
            .cols = @intCast(self.frame_width),
            .rows = @intCast(self.height / 2),
        };
    }

    /// Render sprite frame as ANSI escape code string (for CLI output without vaxis).
    /// Returns allocated string with half-block characters and 24-bit color escapes.
    /// Each row ends with a reset and newline. Caller must free returned slice.
    pub fn renderToAnsi(self: *const SpriteSheet, alloc: std.mem.Allocator, frame: u8) ![]u8 {
        var out: std.ArrayList(u8) = .{};
        errdefer out.deinit(alloc);
        const w = out.writer(alloc);

        const cell_rows: u32 = self.height / 2;
        var cy: u32 = 0;
        while (cy < cell_rows) : (cy += 1) {
            const top_y = cy * 2;
            const bot_y = cy * 2 + 1;
            var cx: u32 = 0;
            while (cx < self.frame_width) : (cx += 1) {
                const top = self.getFramePixel(frame, cx, top_y);
                const bot = self.getFramePixel(frame, cx, bot_y);

                const top_vis = top.a >= ALPHA_THRESHOLD;
                const bot_vis = bot.a >= ALPHA_THRESHOLD;

                if (!top_vis and !bot_vis) {
                    try w.writeAll(" ");
                } else if (top_vis and bot_vis) {
                    try w.print("\x1b[38;2;{d};{d};{d}m\x1b[48;2;{d};{d};{d}m" ++ half_block, .{
                        bot.r, bot.g, bot.b, top.r, top.g, top.b,
                    });
                } else if (top_vis) {
                    try w.print("\x1b[38;2;{d};{d};{d}m" ++ upper_half, .{ top.r, top.g, top.b });
                } else {
                    try w.print("\x1b[38;2;{d};{d};{d}m" ++ half_block, .{ bot.r, bot.g, bot.b });
                }
            }
            try w.writeAll("\x1b[0m\n");
        }

        return out.toOwnedSlice(alloc);
    }

    pub fn deinit(self: *SpriteSheet) void {
        self.alloc.free(self.pixels);
    }

    /// Free kitty graphics image if loaded. Call before deinit.
    pub fn freeKittyImage(self: *SpriteSheet, vx: *vaxis.Vaxis, tty: anytype) void {
        if (self.kitty_image) |img| {
            vx.freeImage(tty, img.id);
            self.kitty_image = null;
        }
    }
};

// --- Tests ---

test "pixel indexing" {
    // 4x2 sprite sheet (2 frames of 2x2)
    var pixels = [_]Pixel{
        // Row 0: frame0(0,0), frame0(1,0), frame1(0,0), frame1(1,0)
        .{ .r = 255, .g = 0, .b = 0, .a = 255 },
        .{ .r = 0, .g = 255, .b = 0, .a = 255 },
        .{ .r = 0, .g = 0, .b = 255, .a = 255 },
        .{ .r = 255, .g = 255, .b = 0, .a = 255 },
        // Row 1
        .{ .r = 100, .g = 100, .b = 100, .a = 255 },
        .{ .r = 200, .g = 200, .b = 200, .a = 255 },
        .{ .r = 50, .g = 50, .b = 50, .a = 255 },
        .{ .r = 150, .g = 150, .b = 150, .a = 255 },
    };

    const sheet = SpriteSheet{
        .width = 4,
        .height = 2,
        .frame_width = 2,
        .frame_count = 2,
        .pixels = &pixels,
        .kitty_image = null,
        .alloc = std.testing.allocator,
    };

    // Frame 0, (0,0) = red
    const p00 = sheet.getFramePixel(0, 0, 0);
    try std.testing.expectEqual(@as(u8, 255), p00.r);
    try std.testing.expectEqual(@as(u8, 0), p00.g);

    // Frame 0, (1,0) = green
    const p10 = sheet.getFramePixel(0, 1, 0);
    try std.testing.expectEqual(@as(u8, 0), p10.r);
    try std.testing.expectEqual(@as(u8, 255), p10.g);

    // Frame 1, (0,0) = blue
    const p_f1 = sheet.getFramePixel(1, 0, 0);
    try std.testing.expectEqual(@as(u8, 0), p_f1.r);
    try std.testing.expectEqual(@as(u8, 0), p_f1.g);
    try std.testing.expectEqual(@as(u8, 255), p_f1.b);

    // Out of bounds = transparent black
    const oob = sheet.getFramePixel(0, 10, 10);
    try std.testing.expectEqual(@as(u8, 0), oob.a);
}

test "load PNG sprite sheet" {
    const sheet = try SpriteSheet.loadFromFile(std.testing.allocator, "assets/sprites/println.png");
    var sheet_mut = sheet;
    defer sheet_mut.deinit();

    try std.testing.expectEqual(@as(u32, 32), sheet.width);
    try std.testing.expectEqual(@as(u32, 16), sheet.height);
    try std.testing.expectEqual(@as(u32, 16), sheet.frame_width);
    try std.testing.expectEqual(@as(u8, 2), sheet.frame_count);

    // Check that some pixels were loaded (not all transparent)
    var has_opaque = false;
    for (sheet.pixels) |px| {
        if (px.a > 0) {
            has_opaque = true;
            break;
        }
    }
    try std.testing.expect(has_opaque);
}

test "display size" {
    var pixels = [_]Pixel{.{ .r = 0, .g = 0, .b = 0, .a = 0 }} ** 64;
    const sheet = SpriteSheet{
        .width = 32,
        .height = 16,
        .frame_width = 16,
        .frame_count = 2,
        .pixels = &pixels,
        .kitty_image = null,
        .alloc = std.testing.allocator,
    };

    const size = sheet.displaySize();
    try std.testing.expectEqual(@as(u16, 16), size.cols);
    try std.testing.expectEqual(@as(u16, 8), size.rows);
}
