-- Procedural dungeon floor generator.
-- Produces a 40x20 tile grid (1=floor, 0=wall), a list of Room objects,
-- a pixel-space player start position, and enemy spawn data.

local Room    = require("src.dungeon.room")
local Species = require("src.core.species")

local Generator = {}

-- Meta-grid dimensions
local META_COLS = 3
local META_ROWS = 2
local GRID_COLS = 40
local GRID_ROWS = 20

-- Tile size of each meta-cell
local CELL_W = math.floor(GRID_COLS / META_COLS)   -- 13
local CELL_H = math.floor(GRID_ROWS / META_ROWS)    -- 10

-- Pixel size of a tile
local TILE_SIZE = 16

-- -----------------------------------------------------------------------
-- Helper: simple seeded pseudo-random using Lua's built-in math.random.
-- We reseed each generation from os.time so runs differ.
-- -----------------------------------------------------------------------

-- Fill a 2D tile grid entirely with walls (0)
local function make_grid()
    local g = {}
    for r = 1, GRID_ROWS do
        g[r] = {}
        for c = 1, GRID_COLS do
            g[r][c] = 0
        end
    end
    return g
end

-- Carve a rectangular area of the grid to floor (1).
-- tx, ty: top-left tile col/row (1-based)
-- tw, th: width/height in tiles
local function carve_rect(grid, tx, ty, tw, th)
    for r = ty, ty + th - 1 do
        for c = tx, tx + tw - 1 do
            if r >= 1 and r <= GRID_ROWS and c >= 1 and c <= GRID_COLS then
                grid[r][c] = 1
            end
        end
    end
end

-- Carve a 2-tile-wide L-shaped corridor between two room centres.
-- Both centres are tile coords (1-based col, row).
local function carve_corridor(grid, c1, r1, c2, r2)
    -- Horizontal leg first, then vertical leg
    local min_c = math.min(c1, c2)
    local max_c = math.max(c1, c2)
    for c = min_c, max_c do
        for dr = 0, 1 do
            local row = r1 + dr
            if row >= 1 and row <= GRID_ROWS and c >= 1 and c <= GRID_COLS then
                grid[row][c] = 1
            end
        end
    end
    local min_r = math.min(r1, r2)
    local max_r = math.max(r1, r2)
    for r = min_r, max_r do
        for dc = 0, 1 do
            local col = c2 + dc
            if r >= 1 and r <= GRID_ROWS and col >= 1 and col <= GRID_COLS then
                grid[r][col] = 1
            end
        end
    end
end

-- Return the tile-space centre of a room
local function room_centre(room)
    return
        room.tx + math.floor(room.tw / 2),
        room.ty + math.floor(room.th / 2)
end

-- Carve a room into the grid and return its centre tile coords
local function place_room(grid, room)
    carve_rect(grid, room.tx, room.ty, room.tw, room.th)
    return room_centre(room)
end

-- Check whether a tile position is a floor tile and at least 'dist' tiles
-- from every edge of the given room (door buffer zone).
local function is_valid_enemy_tile(grid, col, row, room, dist)
    if grid[row] == nil or grid[row][col] ~= 1 then return false end
    if col < room.tx + dist or col > room.tx + room.tw - 1 - dist then return false end
    if row < room.ty + dist or row > room.ty + room.th - 1 - dist then return false end
    return true
end

-- Pick up to 'count' random valid floor tiles for enemy spawns inside a room.
local function pick_spawn_tiles(grid, room, count, dist)
    local candidates = {}
    for r = room.ty, room.ty + room.th - 1 do
        for c = room.tx, room.tx + room.tw - 1 do
            if is_valid_enemy_tile(grid, c, r, room, dist) then
                candidates[#candidates + 1] = { c = c, r = r }
            end
        end
    end
    -- Shuffle candidates via Fisher-Yates
    for i = #candidates, 2, -1 do
        local j = math.random(1, i)
        candidates[i], candidates[j] = candidates[j], candidates[i]
    end
    local result = {}
    for i = 1, math.min(count, #candidates) do
        result[#result + 1] = candidates[i]
    end
    return result
end

-- -----------------------------------------------------------------------
-- Main generation function
-- -----------------------------------------------------------------------
function Generator.generate(floor_num)
    math.randomseed(os.time() + floor_num * 7919)

    local grid  = make_grid()
    local rooms = {}

    -- Room size ranges
    local MIN_W, MAX_W = 7, 11
    local MIN_H, MAX_H = 5, 8

    -- Build a room centered in its meta-cell.
    -- gx, gy are 0-based meta-grid coords.
    local function make_room_in_cell(gx, gy, room_type, revealed)
        local tw = math.random(MIN_W, MAX_W)
        local th = math.random(MIN_H, MAX_H)
        -- Cell top-left in tile coords (1-based)
        local cell_tx = gx * CELL_W + 1
        local cell_ty = gy * CELL_H + 1
        -- Centre the room in the cell
        local tx = cell_tx + math.floor((CELL_W - tw) / 2)
        local ty = cell_ty + math.floor((CELL_H - th) / 2)
        -- Clamp so room stays within grid
        tx = math.max(1, math.min(GRID_COLS - tw + 1, tx))
        ty = math.max(1, math.min(GRID_ROWS - th + 1, ty))
        return Room.new({
            gx = gx, gy = gy,
            tx = tx, ty = ty,
            tw = tw, th = th,
            type = room_type,
            revealed = revealed or false,
        })
    end

    -- Determine which meta-cells get rooms.
    -- Fixed: start=(0,0), boss=(2,1)
    -- Random: 1-2 enemy rooms from the remaining 4 cells.
    local used = {}
    used["0,0"] = true
    used["2,1"] = true

    local all_cells = {}
    for gy = 0, META_ROWS - 1 do
        for gx = 0, META_COLS - 1 do
            local key = gx .. "," .. gy
            if not used[key] then
                all_cells[#all_cells + 1] = { gx = gx, gy = gy }
            end
        end
    end
    -- Shuffle
    for i = #all_cells, 2, -1 do
        local j = math.random(1, i)
        all_cells[i], all_cells[j] = all_cells[j], all_cells[i]
    end
    local num_enemy_rooms = math.random(1, 2)
    local enemy_cells = {}
    for i = 1, math.min(num_enemy_rooms, #all_cells) do
        enemy_cells[#enemy_cells + 1] = all_cells[i]
    end

    -- Create room objects
    local start_room = make_room_in_cell(0, 0, "start", true)
    local boss_room  = make_room_in_cell(2, 1, "boss",  false)
    rooms[#rooms + 1] = start_room   -- index 1
    rooms[#rooms + 1] = boss_room    -- index 2
    local boss_room_index = 2

    local enemy_room_indices = {}
    for _, cell in ipairs(enemy_cells) do
        local r = make_room_in_cell(cell.gx, cell.gy, "enemy", false)
        rooms[#rooms + 1] = r
        enemy_room_indices[#enemy_room_indices + 1] = #rooms
    end

    -- Carve all rooms into the grid
    for _, room in ipairs(rooms) do
        place_room(grid, room)
    end

    -- Connect rooms via a spanning tree to ensure all are reachable.
    -- Build adjacency using a simple Euclidean distance heuristic: connect
    -- each room to the nearest not-yet-connected room (Prim-like).
    local connected = { [1] = true }
    local remaining = {}
    for i = 2, #rooms do remaining[i] = true end

    local function room_dist(a, b)
        local ac, ar = room_centre(a)
        local bc, br = room_centre(b)
        local dc = ac - bc
        local dr = ar - br
        return dc * dc + dr * dr
    end

    while next(remaining) do
        local best_d = math.huge
        local best_from, best_to
        for from_i in pairs(connected) do
            for to_i in pairs(remaining) do
                local d = room_dist(rooms[from_i], rooms[to_i])
                if d < best_d then
                    best_d = d
                    best_from = from_i
                    best_to   = to_i
                end
            end
        end
        if best_from and best_to then
            -- Carve corridor
            local c1, r1 = room_centre(rooms[best_from])
            local c2, r2 = room_centre(rooms[best_to])
            carve_corridor(grid, c1, r1, c2, r2)
            -- Record connection (bidirectional)
            rooms[best_from].connections[#rooms[best_from].connections + 1] = best_to
            rooms[best_to].connections[#rooms[best_to].connections + 1] = best_from
            -- Move best_to to connected
            connected[best_to] = true
            remaining[best_to] = nil
        else
            break  -- safety
        end
    end

    -- -----------------------------------------------------------------------
    -- Player start: centre of start room in pixel coords (top-left of tile)
    -- -----------------------------------------------------------------------
    local sc, sr = room_centre(start_room)
    local player_start = {
        x = (sc - 1) * TILE_SIZE,
        y = (sr - 1) * TILE_SIZE,
    }

    -- -----------------------------------------------------------------------
    -- Enemy spawns
    -- -----------------------------------------------------------------------
    local enemy_pool   = Species.FLOOR_ENEMIES[floor_num] or { "printf" }
    local enemy_level  = Species.FLOOR_LEVELS[floor_num]  or 5
    local spawn_data   = {}

    -- Spawn enemies in enemy rooms
    for _, room_index in ipairs(enemy_room_indices) do
        local room = rooms[room_index]
        local count = math.random(1, 2)
        local tiles = pick_spawn_tiles(grid, room, count, 2)
        for _, tile in ipairs(tiles) do
            local sid = enemy_pool[math.random(1, #enemy_pool)]
            spawn_data[#spawn_data + 1] = {
                species_id = sid,
                level      = enemy_level,
                x          = (tile.c - 1) * TILE_SIZE,
                y          = (tile.r - 1) * TILE_SIZE,
                room_index = room_index,
            }
        end
    end

    -- Floor 3 boss room: place one profiler boss
    if floor_num == 3 then
        local bc, br = room_centre(boss_room)
        spawn_data[#spawn_data + 1] = {
            species_id = "profiler",
            level      = Species.FLOOR_LEVELS[3] or 12,
            x          = (bc - 1) * TILE_SIZE,
            y          = (br - 1) * TILE_SIZE,
            room_index = boss_room_index,
        }
    else
        -- Floors 1-2: also put enemies in the boss room (not a real boss yet)
        local boss_count = 1
        local boss_tiles = pick_spawn_tiles(grid, boss_room, boss_count, 2)
        for _, tile in ipairs(boss_tiles) do
            local sid = enemy_pool[math.random(1, #enemy_pool)]
            spawn_data[#spawn_data + 1] = {
                species_id = sid,
                level      = enemy_level + 1,  -- slightly tougher
                x          = (tile.c - 1) * TILE_SIZE,
                y          = (tile.r - 1) * TILE_SIZE,
                room_index = boss_room_index,
            }
        end
    end

    return {
        tiles        = grid,
        rooms        = rooms,
        player_start = player_start,
        enemies      = spawn_data,
        boss_room_index = boss_room_index,
    }
end

return Generator
