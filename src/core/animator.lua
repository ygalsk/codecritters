local class = require("lib.middleclass")

local Animator = class("Animator")

-- Animation definitions by stage
-- base: 11 frames (352x32), final: 14 frames (448x32)
local ANIM_DEFS = {
    base = {
        idle   = { start = 0, count = 4, loop = true },
        attack = { start = 4, count = 3, loop = false },
        hit    = { start = 7, count = 2, loop = false },
        faint  = { start = 9, count = 2, loop = false },
    },
    final = {
        idle   = { start = 0, count = 6, loop = true },
        attack = { start = 6, count = 3, loop = false },
        hit    = { start = 9, count = 2, loop = false },
        faint  = { start = 11, count = 3, loop = false },
    },
}

-- Constructor: load a sprite sheet and set up animation state
-- sprite_path: relative path like "assets/sprites/println.png"
-- stage: "base" or "final"
-- fps: animation speed (default 8)
function Animator:initialize(sprite_path, stage, fps)
    self.sprite = engine.graphics.load_spritesheet(sprite_path, 32, 32)
    self.stage = stage or "base"
    self.defs = ANIM_DEFS[self.stage]
    self.fps = fps or 8
    self.current_anim = "idle"
    self.frame_timer = 0
    self.frame_index = 0  -- index within the current animation (0-based)
    self.done = false
    self.scale = 1
end

-- Switch to a named animation ("idle", "attack", "hit", "faint")
function Animator:play(anim_name)
    if not self.defs[anim_name] then return end
    self.current_anim = anim_name
    self.frame_index = 0
    self.frame_timer = 0
    self.done = false
end

-- Advance the animation by dt seconds
function Animator:update(dt)
    local def = self.defs[self.current_anim]
    if not def then return end

    self.frame_timer = self.frame_timer + dt
    local frame_dur = 1 / self.fps

    while self.frame_timer >= frame_dur do
        self.frame_timer = self.frame_timer - frame_dur

        if self.done then
            -- Hold on last frame
        elseif def.loop then
            self.frame_index = (self.frame_index + 1) % def.count
        else
            if self.frame_index < def.count - 1 then
                self.frame_index = self.frame_index + 1
            else
                self.done = true
            end
        end
    end
end

-- Draw the current frame at pixel position (x, y)
function Animator:draw(x, y)
    local def = self.defs[self.current_anim]
    if not def or not self.sprite then return end

    local frame = def.start + self.frame_index
    engine.graphics.draw_sprite(self.sprite, x, y, {
        frame = frame,
        scale = self.scale,
    })
end

-- Returns true if a non-looping animation has finished
function Animator:is_done()
    return self.done
end

-- Get the current absolute frame index (for external use)
function Animator:get_frame()
    local def = self.defs[self.current_anim]
    if not def then return 0 end
    return def.start + self.frame_index
end

-- Clean up sprite resource
function Animator:destroy()
    if self.sprite then
        engine.graphics.unload_image(self.sprite)
        self.sprite = nil
    end
end

return Animator
