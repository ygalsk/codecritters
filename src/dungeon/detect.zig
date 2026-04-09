const std = @import("std");

pub fn detectBiome() []const u8 {
    return detectBiomeInDir(".") catch return "generic_dungeon";
}

pub fn detectBiomeInDir(dir_path: []const u8) ![]const u8 {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var python_score: u16 = 0;
    var node_score: u16 = 0;

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const name = entry.name;

        if (eql(name, "pyproject.toml") or eql(name, "requirements.txt") or
            eql(name, "setup.py") or eql(name, "Pipfile"))
        {
            python_score += 10;
        }
        if (eql(name, "package.json") or eql(name, "node_modules")) {
            node_score += 10;
        }

        if (entry.kind == .file) {
            const ext = std.fs.path.extension(name);
            if (eql(ext, ".py") and python_score < 20) {
                python_score += 1;
            }
            if ((eql(ext, ".js") or eql(ext, ".ts") or eql(ext, ".mjs") or eql(ext, ".cjs")) and node_score < 20) {
                node_score += 1;
            }
        }

        // Early exit: once both have manifest-level signals, further iteration can't change the winner
        if (python_score >= 10 and node_score >= 10) break;
    }

    if (python_score == 0 and node_score == 0) return "generic_dungeon";
    if (python_score >= node_score) return "pythonic_caves";
    return "node_abyss";
}

fn eql(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

// --- Tests ---

test "detectBiome returns generic for empty dir" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(path);

    const result = try detectBiomeInDir(path);
    try std.testing.expect(eql(result, "generic_dungeon"));
}

test "detectBiome returns pythonic_caves for .py files" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    _ = try tmp.dir.createFile("main.py", .{});
    _ = try tmp.dir.createFile("utils.py", .{});
    _ = try tmp.dir.createFile("requirements.txt", .{});
    const path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(path);

    const result = try detectBiomeInDir(path);
    try std.testing.expect(eql(result, "pythonic_caves"));
}

test "detectBiome returns node_abyss for package.json" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    _ = try tmp.dir.createFile("package.json", .{});
    _ = try tmp.dir.createFile("index.js", .{});
    const path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(path);

    const result = try detectBiomeInDir(path);
    try std.testing.expect(eql(result, "node_abyss"));
}

test "detectBiome returns generic on nonexistent path" {
    const result = detectBiomeInDir("/tmp/nonexistent_codecritter_test_dir_xyz") catch "generic_dungeon";
    try std.testing.expect(eql(result, "generic_dungeon"));
}
