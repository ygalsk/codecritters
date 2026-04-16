local C       = require("src.core.constants")
local Creature = require("src.core.creature")
local Animator = require("src.core.animator")
local Species  = require("src.core.species")

local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(species_id, level, x, y, room_index)
    local spec = Species.REGISTRY[species_id]
    local self = setmetatable({}, Enemy)
    self.creature  = Creature:new(species_id, level)
    self.animator  = Animator:new(spec.sprite, spec.stage, 6)
    self.animator.scale = 1   -- 32x32 sprite, drawn as colored rect in dungeon
    self.x         = x
    self.y         = y
    self.room_index = room_index
    self.active    = true     -- set false after defeat
    self.state     = "patrol" -- "patrol" or "chase"
    -- Patrol waypoints: bounce back and forth within a small area
    self.patrol_origin_x = x
    self.patrol_origin_y = y
    self.patrol_dir      = 1  -- 1 or -1
    self.patrol_range    = 32 -- pixels to patrol each direction
    return self
end

function Enemy:update(dt, player_x, player_y)
    if not self.active then return end

    self.animator:update(dt)

    -- Distance to player
    local dx   = player_x - self.x
    local dy   = player_y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist < C.DETECT_DIST then
        self.state = "chase"
    else
        self.state = "patrol"
    end

    if self.state == "chase" then
        -- Move toward player
        if dist > 0 then
            local speed = C.ENEMY_SPEED * dt
            self.x = self.x + (dx / dist) * speed
            self.y = self.y + (dy / dist) * speed
        end
    else
        -- Patrol: bounce back and forth horizontally
        self.x = self.x + self.patrol_dir * C.ENEMY_SPEED * dt
        if math.abs(self.x - self.patrol_origin_x) > self.patrol_range then
            self.patrol_dir = -self.patrol_dir
        end
    end
end

-- Returns true when the player is close enough to trigger a battle.
function Enemy:check_contact(player_x, player_y)
    if not self.active then return false end
    local dx = player_x - self.x
    local dy = player_y - self.y
    return (dx * dx + dy * dy) < (C.CONTACT_DIST * C.CONTACT_DIST)
end

function Enemy:destroy()
    if self.animator then
        self.animator:destroy()
        self.animator = nil
    end
end

return Enemy
