local HPBar = {}

-- Draw an HP bar at pixel position (x, y).
-- hp_ratio: 0.0 (empty) to 1.0 (full).
-- width:    pixel width of the full bar (default 80).
-- height:   pixel height of the bar (default 8).
--
-- The bar is drawn with pixel primitives rather than the PNG assets, which
-- lets us scale it to any size and gives full color-threshold control.
function HPBar.draw(x, y, hp_ratio, width, height)
    width    = width  or 80
    height   = height or 8
    hp_ratio = math.max(0, math.min(1, hp_ratio))

    -- Dark background fill
    engine.graphics.pixel.rect(x, y, width, height, 0x222222)

    -- Colored portion scaled to current HP
    local bar_w = math.floor(width * hp_ratio)
    if bar_w > 0 then
        local color
        if hp_ratio > 0.5 then
            color = 0x44FF44   -- green
        elseif hp_ratio > 0.25 then
            color = 0xFFFF44   -- yellow
        else
            color = 0xFF4444   -- red
        end
        engine.graphics.pixel.rect(x, y, bar_w, height, color)
    end

    -- Single-pixel border (top / bottom / left / right)
    engine.graphics.pixel.rect(x,             y,              width, 1,      0x666666)
    engine.graphics.pixel.rect(x,             y + height - 1, width, 1,      0x666666)
    engine.graphics.pixel.rect(x,             y,              1,     height, 0x666666)
    engine.graphics.pixel.rect(x + width - 1, y,              1,     height, 0x666666)
end

return HPBar
