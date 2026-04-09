const std = @import("std");

pub fn loadJsonFile(comptime T: type, allocator: std.mem.Allocator, path: []const u8) !std.json.Parsed([]T) {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const data = try file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(data);
    return std.json.parseFromSlice([]T, allocator, data, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    });
}
