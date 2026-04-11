const std = @import("std");
const vaxis = @import("vaxis");

const Image = vaxis.Image;

/// Maximum number of cached Kitty images.
const MAX_IMAGES = 128;
const KEY_LEN = 64;

/// Caches Kitty graphics protocol images to avoid duplicate transmissions.
/// String-keyed: callers use descriptive keys like "bg:pythonic_caves" or "tiles:node_abyss".
pub const KittyManager = struct {
    entries: [MAX_IMAGES]ImageEntry = undefined,
    count: u16 = 0,

    const ImageEntry = struct {
        key: [KEY_LEN]u8 = undefined,
        key_len: u8 = 0,
        image: Image = undefined,

        fn keySlice(self: *const ImageEntry) []const u8 {
            return self.key[0..self.key_len];
        }
    };

    /// Load an image from file, or return the cached version if already loaded.
    pub fn loadOrGet(
        self: *KittyManager,
        vx: *vaxis.Vaxis,
        alloc: std.mem.Allocator,
        tty: anytype,
        key: []const u8,
        path: []const u8,
    ) !Image {
        // Check cache first
        if (self.get(key)) |img| return img;

        // Load new image
        const img = try vx.loadImage(alloc, tty, .{ .path = path });

        // Cache it
        if (self.count < MAX_IMAGES) {
            var entry = &self.entries[self.count];
            const len: u8 = @intCast(@min(key.len, KEY_LEN));
            @memcpy(entry.key[0..len], key[0..len]);
            entry.key_len = len;
            entry.image = img;
            self.count += 1;
        }

        return img;
    }

    /// Look up a cached image by key.
    pub fn get(self: *const KittyManager, key: []const u8) ?Image {
        for (self.entries[0..self.count]) |*entry| {
            if (std.mem.eql(u8, entry.keySlice(), key)) return entry.image;
        }
        return null;
    }

    /// Free a specific image by key.
    pub fn free(self: *KittyManager, vx: *vaxis.Vaxis, tty: anytype, key: []const u8) void {
        for (self.entries[0..self.count], 0..) |*entry, i| {
            if (std.mem.eql(u8, entry.keySlice(), key)) {
                vx.freeImage(tty, entry.image.id);
                // Swap-remove
                if (i < self.count - 1) {
                    self.entries[i] = self.entries[self.count - 1];
                }
                self.count -= 1;
                return;
            }
        }
    }

    /// Free all cached images.
    pub fn freeAll(self: *KittyManager, vx: *vaxis.Vaxis, tty: anytype) void {
        for (self.entries[0..self.count]) |*entry| {
            vx.freeImage(tty, entry.image.id);
        }
        self.count = 0;
    }
};
