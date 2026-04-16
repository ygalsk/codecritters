local C = require("src.core.constants")

local Text = {}

-- Draw text at a pixel position (passed directly to vexel's draw_text).
function Text.draw(px, py, text, fg)
    engine.graphics.draw_text(px, py, text, fg)
end

-- Measure the pixel width of a string using the current font.
function Text.width(text)
    return engine.graphics.get_text_width(text)
end

-- Return the pixel height of a line of text in the current font.
function Text.height()
    return engine.graphics.get_text_height()
end

-- Return the pixel x that centers `text` horizontally on screen.
function Text.center_x(text)
    return math.floor((C.SCREEN_W - Text.width(text)) / 2)
end

-- Draw text centered horizontally at a given pixel y.
function Text.draw_centered_at(y, text, fg)
    Text.draw(Text.center_x(text), y, text, fg)
end

-- Draw a colored type badge (filled rect with type label).
-- px, py: top-left pixel position. color: fill color for the rect.
function Text.draw_type_badge(px, py, type_str, color)
    local badge_w = Text.width(type_str) + 8
    local badge_h = Text.height() + 2
    engine.graphics.pixel.rect(px, py, badge_w, badge_h, color)
    engine.graphics.draw_text(px + 4, py + 1, type_str, C.COLOR_BLACK)
end

return Text
