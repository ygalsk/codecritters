const std = @import("std");

pub fn detectBiome() []const u8 {
    return detectBiomeInDir(".") catch return "generic_dungeon";
}

pub fn detectBiomeInDir(dir_path: []const u8) ![]const u8 {
    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var python_score: u16 = 0;
    var node_score: u16 = 0;
    var rust_score: u16 = 0;
    var go_score: u16 = 0;
    var c_score: u16 = 0;
    var shell_score: u16 = 0;

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        const name = entry.name;

        // Manifest detection (+10)
        if (eql(name, "pyproject.toml") or eql(name, "requirements.txt") or
            eql(name, "setup.py") or eql(name, "Pipfile"))
        {
            python_score += 10;
        }
        if (eql(name, "package.json") or eql(name, "node_modules")) {
            node_score += 10;
        }
        if (eql(name, "Cargo.toml") or eql(name, "Cargo.lock")) {
            rust_score += 10;
        }
        if (eql(name, "go.mod") or eql(name, "go.sum")) {
            go_score += 10;
        }
        if (eql(name, "Makefile") or eql(name, "CMakeLists.txt") or eql(name, "meson.build")) {
            c_score += 10;
        }

        // Extension detection (+1 each, capped at 20)
        if (entry.kind == .file) {
            const ext = std.fs.path.extension(name);
            if (eql(ext, ".py") and python_score < 20) {
                python_score += 1;
            }
            if ((eql(ext, ".js") or eql(ext, ".ts") or eql(ext, ".mjs") or eql(ext, ".cjs")) and node_score < 20) {
                node_score += 1;
            }
            if (eql(ext, ".rs") and rust_score < 20) {
                rust_score += 1;
            }
            if (eql(ext, ".go") and go_score < 20) {
                go_score += 1;
            }
            if ((eql(ext, ".c") or eql(ext, ".h")) and c_score < 20) {
                c_score += 1;
            }
            if ((eql(ext, ".sh") or eql(ext, ".bash") or eql(ext, ".zsh")) and shell_score < 20) {
                shell_score += 1;
            }
        }
    }

    // Pick highest score; tie-break order: python > node > rust > go > c > shell
    const scores = [_]struct { score: u16, id: []const u8 }{
        .{ .score = python_score, .id = "pythonic_caves" },
        .{ .score = node_score, .id = "node_abyss" },
        .{ .score = rust_score, .id = "rustacean_depths" },
        .{ .score = go_score, .id = "gopher_tunnels" },
        .{ .score = c_score, .id = "c_catacombs" },
        .{ .score = shell_score, .id = "shell_scripts" },
    };

    var best_score: u16 = 0;
    var best_id: []const u8 = "generic_dungeon";
    for (&scores) |*entry| {
        if (entry.score > best_score) {
            best_score = entry.score;
            best_id = entry.id;
        }
    }
    return best_id;
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

test "detectBiome returns rustacean_depths for Cargo.toml" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    _ = try tmp.dir.createFile("Cargo.toml", .{});
    _ = try tmp.dir.createFile("main.rs", .{});
    const path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(path);

    const result = try detectBiomeInDir(path);
    try std.testing.expect(eql(result, "rustacean_depths"));
}

test "detectBiome returns gopher_tunnels for go.mod" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    _ = try tmp.dir.createFile("go.mod", .{});
    _ = try tmp.dir.createFile("main.go", .{});
    const path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(path);

    const result = try detectBiomeInDir(path);
    try std.testing.expect(eql(result, "gopher_tunnels"));
}

test "detectBiome returns c_catacombs for .c and .h files" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    _ = try tmp.dir.createFile("Makefile", .{});
    _ = try tmp.dir.createFile("main.c", .{});
    _ = try tmp.dir.createFile("util.h", .{});
    const path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(path);

    const result = try detectBiomeInDir(path);
    try std.testing.expect(eql(result, "c_catacombs"));
}

test "detectBiome returns shell_scripts for .sh files" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    _ = try tmp.dir.createFile("build.sh", .{});
    _ = try tmp.dir.createFile("deploy.sh", .{});
    _ = try tmp.dir.createFile("test.sh", .{});
    _ = try tmp.dir.createFile("install.sh", .{});
    _ = try tmp.dir.createFile("setup.sh", .{});
    const path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(path);

    const result = try detectBiomeInDir(path);
    try std.testing.expect(eql(result, "shell_scripts"));
}

test "detectBiome tie-breaking prefers python over rust" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    _ = try tmp.dir.createFile("requirements.txt", .{});
    _ = try tmp.dir.createFile("Cargo.toml", .{});
    const path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(path);

    const result = try detectBiomeInDir(path);
    try std.testing.expect(eql(result, "pythonic_caves"));
}

test "detectBiome highest score wins regardless of tie-break order" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    _ = try tmp.dir.createFile("Cargo.toml", .{});
    _ = try tmp.dir.createFile("script.py", .{});
    const path = try tmp.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(path);

    const result = try detectBiomeInDir(path);
    try std.testing.expect(eql(result, "rustacean_depths"));
}
