const std = @import("std");

pub const FLOOR_WIDTH: u8 = 24;
pub const FLOOR_HEIGHT: u8 = 18;

pub const Tile = enum {
    wall,
    floor,
    encounter,
    stairs,
    entrance,
};

pub const Floor = struct {
    tiles: [FLOOR_HEIGHT][FLOOR_WIDTH]Tile,
    entrance_x: u8,
    entrance_y: u8,
    stairs_x: u8,
    stairs_y: u8,
};

const Room = struct {
    x: u8,
    y: u8,
    w: u8,
    h: u8,

    fn centerX(self: Room) u8 {
        return self.x + self.w / 2;
    }

    fn centerY(self: Room) u8 {
        return self.y + self.h / 2;
    }

    fn overlaps(self: Room, other: Room) bool {
        // 1-tile margin between rooms
        return self.x -| 1 < other.x + other.w + 1 and
            other.x -| 1 < self.x + self.w + 1 and
            self.y -| 1 < other.y + other.h + 1 and
            other.y -| 1 < self.y + self.h + 1;
    }
};

pub fn generateFloor(floor_number: u8, rng: std.Random) Floor {
    var floor = Floor{
        .tiles = [_][FLOOR_WIDTH]Tile{[_]Tile{.wall} ** FLOOR_WIDTH} ** FLOOR_HEIGHT,
        .entrance_x = 0,
        .entrance_y = 0,
        .stairs_x = 0,
        .stairs_y = 0,
    };

    const room_count_range: u8 = 3;
    const num_rooms: u8 = 3 + rng.intRangeAtMost(u8, 0, room_count_range - 1);
    var rooms: [5]Room = undefined;
    var placed: u8 = 0;

    var attempts: u16 = 0;
    while (placed < num_rooms and attempts < 200) : (attempts += 1) {
        const w = rng.intRangeAtMost(u8, 4, 8);
        const h = rng.intRangeAtMost(u8, 3, 6);
        const x = rng.intRangeAtMost(u8, 1, FLOOR_WIDTH - w - 1);
        const y = rng.intRangeAtMost(u8, 1, FLOOR_HEIGHT - h - 1);

        const candidate = Room{ .x = x, .y = y, .w = w, .h = h };

        var overlapping = false;
        for (rooms[0..placed]) |existing| {
            if (candidate.overlaps(existing)) {
                overlapping = true;
                break;
            }
        }

        if (!overlapping) {
            rooms[placed] = candidate;
            placed += 1;
        }
    }

    // If we couldn't place at least 2 rooms, force a fallback layout
    if (placed < 2) {
        rooms[0] = Room{ .x = 2, .y = 2, .w = 6, .h = 5 };
        rooms[1] = Room{ .x = 14, .y = 10, .w = 6, .h = 5 };
        placed = 2;
    }

    for (rooms[0..placed]) |room| {
        var ry: u8 = room.y;
        while (ry < room.y + room.h) : (ry += 1) {
            var rx: u8 = room.x;
            while (rx < room.x + room.w) : (rx += 1) {
                floor.tiles[ry][rx] = .floor;
            }
        }
    }

    var i: u8 = 0;
    while (i + 1 < placed) : (i += 1) {
        const a = rooms[i];
        const b = rooms[i + 1];
        carveCorridor(&floor, a.centerX(), a.centerY(), b.centerX(), b.centerY(), rng);
    }

    floor.entrance_x = rooms[0].centerX();
    floor.entrance_y = rooms[0].centerY();
    floor.tiles[floor.entrance_y][floor.entrance_x] = .entrance;

    const last = rooms[placed - 1];
    floor.stairs_x = last.centerX();
    floor.stairs_y = last.centerY();
    floor.tiles[floor.stairs_y][floor.stairs_x] = .stairs;

    const max_encounters: u8 = @min(8, 3 + floor_number / 2);
    var encounters_placed: u8 = 0;
    var enc_attempts: u16 = 0;
    while (encounters_placed < max_encounters and enc_attempts < 500) : (enc_attempts += 1) {
        const ex = rng.intRangeAtMost(u8, 0, FLOOR_WIDTH - 1);
        const ey = rng.intRangeAtMost(u8, 0, FLOOR_HEIGHT - 1);

        if (floor.tiles[ey][ex] != .floor) continue;
        if (isAdjacentTo(&floor, ex, ey, .entrance) or isAdjacentTo(&floor, ex, ey, .stairs)) continue;

        floor.tiles[ey][ex] = .encounter;
        encounters_placed += 1;
    }

    return floor;
}

fn carveCorridor(floor: *Floor, x1: u8, y1: u8, x2: u8, y2: u8, rng: std.Random) void {
    // L-shaped: horizontal first or vertical first, randomly chosen
    if (rng.boolean()) {
        carveHorizontal(floor, x1, x2, y1);
        carveVertical(floor, x2, y1, y2);
    } else {
        carveVertical(floor, x1, y1, y2);
        carveHorizontal(floor, x1, x2, y2);
    }
}

fn carveHorizontal(floor: *Floor, x1: u8, x2: u8, y: u8) void {
    const start = @min(x1, x2);
    const end = @max(x1, x2);
    var x = start;
    while (x <= end) : (x += 1) {
        if (floor.tiles[y][x] == .wall) {
            floor.tiles[y][x] = .floor;
        }
    }
}

fn carveVertical(floor: *Floor, x: u8, y1: u8, y2: u8) void {
    const start = @min(y1, y2);
    const end = @max(y1, y2);
    var y = start;
    while (y <= end) : (y += 1) {
        if (floor.tiles[y][x] == .wall) {
            floor.tiles[y][x] = .floor;
        }
    }
}

fn isAdjacentTo(floor: *const Floor, x: u8, y: u8, tile_type: Tile) bool {
    const dx = [_]i8{ -1, 0, 1, 0 };
    const dy = [_]i8{ 0, -1, 0, 1 };
    for (dx, dy) |ddx, ddy| {
        const nx: i16 = @as(i16, x) + ddx;
        const ny: i16 = @as(i16, y) + ddy;
        if (nx >= 0 and nx < FLOOR_WIDTH and ny >= 0 and ny < FLOOR_HEIGHT) {
            if (floor.tiles[@intCast(ny)][@intCast(nx)] == tile_type) return true;
        }
    }
    return false;
}

pub fn isReachable(floor: *const Floor, from_x: u8, from_y: u8, to_x: u8, to_y: u8) bool {
    var visited: [FLOOR_HEIGHT][FLOOR_WIDTH]bool = [_][FLOOR_WIDTH]bool{[_]bool{false} ** FLOOR_WIDTH} ** FLOOR_HEIGHT;
    var queue: [@as(u16, FLOOR_WIDTH) * FLOOR_HEIGHT][2]u8 = undefined;
    var head: u16 = 0;
    var tail: u16 = 0;

    queue[tail] = .{ from_x, from_y };
    tail += 1;
    visited[from_y][from_x] = true;

    const offsets = [_]i8{ -1, 0, 1, 0 };
    const offsets_y = [_]i8{ 0, -1, 0, 1 };

    while (head < tail) {
        const cx = queue[head][0];
        const cy = queue[head][1];
        head += 1;

        if (cx == to_x and cy == to_y) return true;

        for (offsets, offsets_y) |odx, ody| {
            const nx_i: i16 = @as(i16, cx) + odx;
            const ny_i: i16 = @as(i16, cy) + ody;
            if (nx_i < 0 or nx_i >= FLOOR_WIDTH or ny_i < 0 or ny_i >= FLOOR_HEIGHT) continue;
            const nx: u8 = @intCast(nx_i);
            const ny: u8 = @intCast(ny_i);
            if (visited[ny][nx]) continue;
            if (floor.tiles[ny][nx] == .wall) continue;
            visited[ny][nx] = true;
            queue[tail] = .{ nx, ny };
            tail += 1;
        }
    }

    return false;
}

// --- Tests ---

test "generated floor has entrance and stairs" {
    var prng = std.Random.DefaultPrng.init(42);
    const floor = generateFloor(1, prng.random());
    try std.testing.expectEqual(Tile.entrance, floor.tiles[floor.entrance_y][floor.entrance_x]);
    try std.testing.expectEqual(Tile.stairs, floor.tiles[floor.stairs_y][floor.stairs_x]);
}

test "generated floor is connected - entrance reaches stairs" {
    var prng = std.Random.DefaultPrng.init(42);
    const floor = generateFloor(1, prng.random());
    try std.testing.expect(isReachable(&floor, floor.entrance_x, floor.entrance_y, floor.stairs_x, floor.stairs_y));
}

test "connectivity holds across many seeds" {
    var seed: u64 = 0;
    while (seed < 50) : (seed += 1) {
        var prng = std.Random.DefaultPrng.init(seed);
        const floor = generateFloor(@intCast(seed % 20 + 1), prng.random());
        try std.testing.expect(isReachable(&floor, floor.entrance_x, floor.entrance_y, floor.stairs_x, floor.stairs_y));
    }
}

test "encounter tile count scales with floor number" {
    var prng1 = std.Random.DefaultPrng.init(99);
    const floor1 = generateFloor(1, prng1.random());
    const count1 = countTiles(&floor1, .encounter);

    var prng2 = std.Random.DefaultPrng.init(99);
    const floor10 = generateFloor(10, prng2.random());
    const count10 = countTiles(&floor10, .encounter);

    // Floor 10 should have more encounters than floor 1
    // (3 + 10/2 = 8 max vs 3 + 1/2 = 3 max)
    try std.testing.expect(count10 >= count1);
}

test "deterministic generation with same seed" {
    var prng1 = std.Random.DefaultPrng.init(12345);
    const floor_a = generateFloor(3, prng1.random());

    var prng2 = std.Random.DefaultPrng.init(12345);
    const floor_b = generateFloor(3, prng2.random());

    try std.testing.expectEqual(floor_a.entrance_x, floor_b.entrance_x);
    try std.testing.expectEqual(floor_a.entrance_y, floor_b.entrance_y);
    try std.testing.expectEqual(floor_a.stairs_x, floor_b.stairs_x);
    try std.testing.expectEqual(floor_a.stairs_y, floor_b.stairs_y);
    // Check full grid equality
    for (0..FLOOR_HEIGHT) |y| {
        for (0..FLOOR_WIDTH) |x| {
            try std.testing.expectEqual(floor_a.tiles[y][x], floor_b.tiles[y][x]);
        }
    }
}

test "no encounters adjacent to entrance or stairs" {
    var prng = std.Random.DefaultPrng.init(77);
    const floor = generateFloor(10, prng.random());

    // Check no encounter tile is adjacent to entrance or stairs
    for (0..FLOOR_HEIGHT) |y| {
        for (0..FLOOR_WIDTH) |x| {
            if (floor.tiles[y][x] == .encounter) {
                try std.testing.expect(!isAdjacentTo(&floor, @intCast(x), @intCast(y), .entrance));
                try std.testing.expect(!isAdjacentTo(&floor, @intCast(x), @intCast(y), .stairs));
            }
        }
    }
}

fn countTiles(floor: *const Floor, tile_type: Tile) u16 {
    var count: u16 = 0;
    for (0..FLOOR_HEIGHT) |y| {
        for (0..FLOOR_WIDTH) |x| {
            if (floor.tiles[y][x] == tile_type) count += 1;
        }
    }
    return count;
}
