-- Dungeon exploration state.
-- Handles tile-based map rendering, player movement with wall collision,
-- enemy AI, battle triggers, room reveal, and floor progression.

local C         = require("src.core.constants")
local Game      = require("src.core.game")
local Generator = require("src.dungeon.generator")
local Enemy     = require("src.dungeon.enemy")
local HUD       = require("src.ui.hud")
local bump      = require("lib.bump")
local Animator  = require("src.core.animator")
local Species   = require("src.core.species")
local HPBar     = require("src.ui.hp_bar")

local DungeonState = {}

-- -----------------------------------------------------------------------
-- Internal state
-- -----------------------------------------------------------------------
local tiles         = nil   -- [row][col]: 0=wall, 1=floor
local rooms         = nil   -- list of Room objects
local enemies       = {}    -- list of Enemy objects
local player_x      = 0
local player_y      = 0
local world         = nil   -- bump physics world
local player_item   = nil   -- bump item for player
local floor_data    = nil   -- result from Generator.generate()
local boss_defeated = false -- true once the floor boss is beaten

local initialized_floor  = 0     -- which floor the data was generated for
local revealed_room_cells = {}    -- cached fog-of-war cell set (key = r*(COLS+1)+c)
local fog_dirty           = true  -- true whenever the revealed set needs rebuilding
local player_anim         = nil   -- Animator for the player sprite in dungeon

-- Tile and player dimensions in pixels
local TS = C.TILE_SIZE          -- 16
local PS = C.TILE_SIZE          -- player visual + AABB size: 16x16

-- -----------------------------------------------------------------------
-- Bump collision filter
-- Walls are static items; player slides against them.
-- Everything else (enemies) is ignored by the bump world.
-- -----------------------------------------------------------------------
local function collision_filter(item, other)
    -- only interact with wall items (tables with wall=true)
    if other.wall then
        return "slide"
    end
    return false  -- ignore all other items (cross)
end

-- -----------------------------------------------------------------------
-- Build bump world from tile data
-- -----------------------------------------------------------------------
local function build_bump_world(tile_grid)
    local w = bump.newWorld(TS)
    -- Add a wall item for each solid tile
    for row = 1, C.GRID_ROWS do
        for col = 1, C.GRID_COLS do
            if tile_grid[row][col] == 0 then
                local wx = (col - 1) * TS
                local wy = (row - 1) * TS
                local wall_item = { wall = true, col = col, row = row }
                w:add(wall_item, wx, wy, TS, TS)
            end
        end
    end
    return w
end

-- -----------------------------------------------------------------------
-- Room reveal: mark the room the player is currently in as revealed.
-- -----------------------------------------------------------------------
local function reveal_current_room(px, py)
    local cx = math.floor(px / TS) + 1
    local cy = math.floor(py / TS) + 1
    for _, room in ipairs(rooms or {}) do
        if cx >= room.tx and cx < room.tx + room.tw and
           cy >= room.ty and cy < room.ty + room.th then
            if not room.revealed then
                room.revealed = true
                fog_dirty = true
            end
        end
    end
end

-- -----------------------------------------------------------------------
-- Check whether the player is standing on the stairs tile.
-- Stairs are stored in floor_data.stairs = {col, row} (1-based tile coords).
-- -----------------------------------------------------------------------
local function player_on_stairs(px, py)
    if not floor_data or not floor_data.stairs then return false end
    local sc = floor_data.stairs.col
    local sr = floor_data.stairs.row
    local player_col = math.floor(px / TS) + 1
    local player_row = math.floor(py / TS) + 1
    return player_col == sc and player_row == sr
end

-- -----------------------------------------------------------------------
-- Spawn all enemies from floor_data
-- -----------------------------------------------------------------------
local function spawn_enemies()
    enemies = {}
    for _, sd in ipairs(floor_data.enemies) do
        local e = Enemy.new(sd.species_id, sd.level, sd.x, sd.y, sd.room_index)
        enemies[#enemies + 1] = e
    end
end

-- -----------------------------------------------------------------------
-- Full floor initialisation (called on new floor or new run)
-- -----------------------------------------------------------------------
local function init_floor()
    -- Clean up previous enemies and player animator
    for _, e in ipairs(enemies) do
        e:destroy()
    end
    enemies = {}
    if player_anim then player_anim:destroy() end
    local p_spec = Species.REGISTRY[Game.data.player_creature.species_id]
    player_anim  = Animator:new(p_spec.sprite, p_spec.stage, 6)
    player_anim.scale = 1

    -- Generate floor data
    floor_data = Generator.generate(Game.data.floor)
    tiles      = floor_data.tiles
    rooms      = floor_data.rooms

    boss_defeated = false
    fog_dirty     = true

    -- Build physics world
    world = build_bump_world(tiles)

    -- Place player at start position
    player_x = floor_data.player_start.x
    player_y = floor_data.player_start.y

    -- Add player to bump world
    player_item = { player = true }
    world:add(player_item, player_x, player_y, PS, PS)

    -- Spawn enemies
    spawn_enemies()

    -- Reveal start room
    reveal_current_room(player_x, player_y)

    initialized_floor = Game.data.floor
end

-- -----------------------------------------------------------------------
-- Handle battle victory: deactivate the defeated enemy; check win conditions.
-- Returns true if the win transition was fired (caller should not continue).
-- -----------------------------------------------------------------------
local function handle_battle_return()
    if Game.data.battle_result ~= "victory" then
        Game.data.battle_result = nil
        return false
    end
    Game.data.battle_result = nil

    local defeated = Game.data.battle_enemy
    Game.data.battle_enemy = nil
    if not defeated then return false end

    -- Deactivate and free sprite resources
    defeated.active = false
    defeated:destroy()

    -- Check if this was the boss room enemy on floor 3
    local is_floor3_boss = (Game.data.floor == 3) and
                           (defeated.room_index == floor_data.boss_room_index)

    -- Check if this was the boss room enemy on floors 1-2
    local is_boss_room   = (defeated.room_index == floor_data.boss_room_index)

    if is_floor3_boss then
        -- Win the run
        Game.fsm:win_run()
        return true
    end

    if is_boss_room then
        -- Place stairs in the boss room centre after boss defeat
        boss_defeated = true
        local boss_room = rooms[floor_data.boss_room_index]
        if boss_room then
            local sc = boss_room.tx + math.floor(boss_room.tw / 2)
            local sr = boss_room.ty + math.floor(boss_room.th / 2)
            floor_data.stairs = { col = sc, row = sr }
        end
    end

    return false
end

-- -----------------------------------------------------------------------
-- State interface
-- -----------------------------------------------------------------------
function DungeonState:enter()
    -- Returning from battle?
    if initialized_floor == Game.data.floor then
        -- Handle the result and stay in dungeon (or trigger win)
        local transitioned = handle_battle_return()
        if transitioned then return end
        -- Restore the player item in the bump world (it was not removed,
        -- but re-add defensively in case of edge-cases)
        if world and not world:hasItem(player_item) then
            world:add(player_item, player_x, player_y, PS, PS)
        end
        return
    end

    -- New floor or fresh run: generate everything
    init_floor()
end

function DungeonState:exit()
    -- Nothing to tear down per-exit; we keep state for battle returns.
end

function DungeonState:update(dt)
    -- ------------------------------------------------------------------
    -- Player movement: poll arrow keys
    -- ------------------------------------------------------------------
    local vx, vy = 0, 0
    if engine.input.is_key_down("up")    then vy = -1 end
    if engine.input.is_key_down("down")  then vy =  1 end
    if engine.input.is_key_down("left")  then vx = -1 end
    if engine.input.is_key_down("right") then vx =  1 end

    if vx ~= 0 and vy ~= 0 then
        -- Normalise diagonal movement
        local inv = 1 / math.sqrt(2)
        vx = vx * inv
        vy = vy * inv
    end

    local speed  = C.PLAYER_SPEED * dt
    local goal_x = player_x + vx * speed
    local goal_y = player_y + vy * speed

    -- Clamp to dungeon viewport boundaries
    goal_x = math.max(0, math.min(C.SCREEN_W - PS, goal_x))
    goal_y = math.max(0, math.min(C.DUNGEON_H - PS, goal_y))

    -- Move via bump (slides around walls)
    local actual_x, actual_y = world:move(player_item, goal_x, goal_y, collision_filter)
    player_x = actual_x
    player_y = actual_y

    if player_anim then player_anim:update(dt) end

    -- Reveal room at new position
    reveal_current_room(player_x, player_y)

    -- ------------------------------------------------------------------
    -- Enemy AI update + contact check
    -- ------------------------------------------------------------------
    for _, e in ipairs(enemies) do
        if e.active then
            e:update(dt, player_x, player_y)

            if e:check_contact(player_x, player_y) then
                -- Trigger battle
                Game.data.battle_enemy  = e
                Game.data.battle_result = nil
                Game.fsm:start_battle()
                return  -- stop processing this frame
            end
        end
    end

    -- ------------------------------------------------------------------
    -- Stairs check (advance floor or win)
    -- ------------------------------------------------------------------
    if boss_defeated and player_on_stairs(player_x, player_y) then
        if Game.data.floor >= 3 then
            Game.fsm:win_run()
        else
            -- Advance to next floor
            Game.data.floor = Game.data.floor + 1
            Game.data.run_stats.floors_cleared = Game.data.run_stats.floors_cleared + 1
            init_floor()
        end
    end
end

function DungeonState:draw()
    -- ------------------------------------------------------------------
    -- Layer 0: background fill
    -- ------------------------------------------------------------------
    engine.graphics.set_layer(C.LAYER_BG)
    engine.graphics.pixel.rect(0, 0, C.SCREEN_W, C.DUNGEON_H, C.COLOR_BG)

    -- ------------------------------------------------------------------
    -- Layer 1: tiles
    -- Only draw tiles that belong to revealed rooms (or corridors touching
    -- revealed rooms).  For simplicity we draw all floor tiles and only
    -- wall tiles adjacent to revealed rooms (fog of war is coarse-grained).
    -- ------------------------------------------------------------------
    engine.graphics.set_layer(C.LAYER_TILES)
    engine.graphics.pixel.clear()

    -- Rebuild fog-of-war cell set only when a new room is revealed
    if fog_dirty then
        revealed_room_cells = {}
        if rooms then
            for _, room in ipairs(rooms) do
                if room.revealed then
                    for r = room.ty, room.ty + room.th - 1 do
                        for c = room.tx, room.tx + room.tw - 1 do
                            revealed_room_cells[r * (C.GRID_COLS + 1) + c] = true
                        end
                    end
                end
            end
        end
        fog_dirty = false
    end

    if tiles then
        local stairs_col = floor_data and floor_data.stairs and floor_data.stairs.col
        local stairs_row = floor_data and floor_data.stairs and floor_data.stairs.row

        for row = 1, C.GRID_ROWS do
            for col = 1, C.GRID_COLS do
                local v   = tiles[row][col]
                local px  = (col - 1) * TS
                local py  = (row - 1) * TS

                if v == 1 then
                    -- Floor tile: always draw (corridors provide connectivity)
                    local in_revealed = revealed_room_cells[row * (C.GRID_COLS + 1) + col]
                    local color = in_revealed and C.COLOR_FLOOR or 0x111122
                    engine.graphics.pixel.rect(px, py, TS, TS, color)

                    -- Stairs tile?
                    if stairs_col and col == stairs_col and row == stairs_row and boss_defeated then
                        engine.graphics.pixel.rect(px + 2, py + 2, TS - 4, TS - 4, C.COLOR_GOLD)
                    end
                else
                    -- Wall tile
                    engine.graphics.pixel.rect(px, py, TS, TS, C.COLOR_WALL)
                end
            end
        end
    end

    -- ------------------------------------------------------------------
    -- Layer 2: entities (player and enemies)
    -- Scissor-clip to dungeon viewport to prevent bleed into HUD strip.
    -- ------------------------------------------------------------------
    engine.graphics.set_layer(C.LAYER_ENTITIES)
    engine.graphics.pixel.clear()
    engine.graphics.set_scissor(0, 0, C.DUNGEON_W, C.DUNGEON_H)

    -- Enemies
    for _, e in ipairs(enemies) do
        if e.active then
            local ex = math.floor(e.x)
            local ey = math.floor(e.y)
            e.animator:draw(ex - 8, ey - 8)
            local hp_ratio = e.creature.hp / e.creature.max_hp
            HPBar.draw(ex - 4, ey - 6, hp_ratio, 24, 3)
        end
    end

    -- Player (drawn on top of enemies)
    if player_anim then
        player_anim:draw(math.floor(player_x) - 8, math.floor(player_y) - 8)
    end

    engine.graphics.set_scissor(0, 0, C.SCREEN_W, C.SCREEN_H)

    -- ------------------------------------------------------------------
    -- Layer 3: HUD
    -- ------------------------------------------------------------------
    engine.graphics.set_layer(C.LAYER_UI)
    engine.graphics.pixel.clear()
    HUD.draw()
end

function DungeonState:on_key(key, action)
    -- Movement is polled in update(); nothing to handle here.
end

-- Register with the game FSM
Game.register_state("dungeon", DungeonState)

return DungeonState
