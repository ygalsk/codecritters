local C = require("src.core.constants")

local Panel = {}

-- Draw a filled panel with an optional 1px border.
-- x, y, w, h: pixel position and size.
-- opts: { bg=color, border=color } (both optional, use defaults if omitted).
function Panel.draw(x, y, w, h, opts)
    local o = opts or {}
    engine.graphics.pixel.rect(x, y, w, h, o.bg or C.COLOR_PANEL_BG)
    if o.border then
        engine.graphics.pixel.rect(x,         y,         w, 1, o.border)
        engine.graphics.pixel.rect(x,         y + h - 1, w, 1, o.border)
        engine.graphics.pixel.rect(x,         y,         1, h, o.border)
        engine.graphics.pixel.rect(x + w - 1, y,         1, h, o.border)
    end
    if o.scissor then
        engine.graphics.set_scissor(x + 1, y + 1, w - 2, h - 2)
    end
end

-- Reset scissor to full screen.
function Panel.clear_scissor()
    engine.graphics.set_scissor(0, 0, C.SCREEN_W, C.SCREEN_H)
end

-- Draw a panel centered on screen. Returns x, y for content positioning.
-- w, h: panel size. opts: same as Panel.draw.
function Panel.draw_centered(w, h, opts)
    local x = math.floor((C.SCREEN_W - w) / 2)
    local y = math.floor((C.SCREEN_H - h) / 2)
    Panel.draw(x, y, w, h, opts)
    return x, y
end

return Panel
