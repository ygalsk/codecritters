local C = require("src.core.constants")
local flux = require("lib.flux")

local Transition = {}

local state = { progress = 0 }  -- 0=transparent, 1=black
local callback_fn = nil
local active = false

function Transition.start(cb)
    active = true
    callback_fn = cb
    state.progress = 0
    -- Fade to black
    flux.to(state, 0.15, { progress = 1 }):ease("linear"):oncomplete(function()
        if callback_fn then callback_fn() end
        -- Fade from black
        flux.to(state, 0.15, { progress = 0 }):ease("linear"):oncomplete(function()
            active = false
        end)
    end)
end

function Transition.active()
    return active
end

function Transition.draw()
    if not active or state.progress <= 0.01 then return end
    -- Lerp between COLOR_BG and black based on progress
    local bg_r = 0x0a
    local bg_g = 0x0a
    local bg_b = 0x1a
    local r = math.floor(bg_r * (1 - state.progress))
    local g = math.floor(bg_g * (1 - state.progress))
    local b = math.floor(bg_b * (1 - state.progress))
    local color = r * 0x10000 + g * 0x100 + b
    engine.graphics.set_layer(C.LAYER_MODAL)
    engine.graphics.pixel.rect(0, 0, C.SCREEN_W, C.SCREEN_H, color)
end

return Transition
