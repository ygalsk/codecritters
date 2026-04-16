local C    = require("src.core.constants")
local Text = require("src.ui.text")

local Menu = {}
Menu.__index = Menu

-- Create a new cursor menu.
-- items: list of tables with at least a "text" field plus any extra data.
-- px, py: top-left pixel position of the menu.
-- opts: optional table (or legacy highlight color number) with fields:
--   highlight   - hex color for the selected item (default C.COLOR_GOLD)
--   shortcuts   - bool; pressing "1"-"9" selects and confirms that item
--   horizontal  - bool; lay items out left-to-right instead of top-to-bottom
--   render      - function(item, px, py, is_selected, fg); custom row draw
function Menu.new(items, px, py, opts)
    -- Backwards compat: bare color value passed as 4th arg
    if type(opts) == "number" then
        opts = { highlight = opts }
    else
        opts = opts or {}
    end

    return setmetatable({
        items      = items,
        cursor     = 1,
        x          = px,
        y          = py,
        highlight  = opts.highlight or C.COLOR_GOLD,
        shortcuts  = opts.shortcuts  or false,
        horizontal = opts.horizontal or false,
        render     = opts.render,
        row_height = opts.row_height,
    }, Menu)
end

-- Draw each menu item.
-- Vertical mode (default): items stacked top-to-bottom, prefixed with "> ".
-- Horizontal mode: items laid out left-to-right with spacing = text width + 20.
-- render callback: when set, called as render(item, px, py, is_selected, fg)
--   instead of the built-in Text.draw.
function Menu:draw()
    local cx = self.x
    for i, item in ipairs(self.items) do
        local is_sel = (i == self.cursor)
        local fg     = is_sel and self.highlight or C.COLOR_WHITE

        if self.horizontal then
            if self.render then
                self.render(item, cx, self.y, is_sel, fg)
            else
                local prefix = is_sel and "> " or "  "
                Text.draw(cx, self.y, prefix .. item.text, fg)
            end
            cx = cx + Text.width(item.text) + 20
        else
            local py = self.y + (i - 1) * (self.row_height or (Text.height() + 6))
            if self.render then
                self.render(item, self.x, py, is_sel, fg)
            else
                local prefix = is_sel and "> " or "  "
                Text.draw(self.x, py, prefix .. item.text, fg)
            end
        end
    end
end

-- Handle key input. Returns the selected item table when Enter is pressed
-- (or when a shortcut key selects an item), otherwise returns nil.
-- Ignores release events.
-- Supports up/down always; left/right additionally in horizontal mode.
-- When opts.shortcuts is true, keys "1"-"9" select and confirm that item.
function Menu:on_key(key, action)
    if action ~= "press" then return nil end

    -- Number-key shortcuts
    if self.shortcuts then
        local n = tonumber(key)
        if n and n >= 1 and n <= #self.items then
            self.cursor = n
            return self.items[n]
        end
    end

    local prev = (self.horizontal) and "left"  or "up"
    local next = (self.horizontal) and "right" or "down"

    if key == prev or key == "up" then
        self.cursor = self.cursor - 1
        if self.cursor < 1 then self.cursor = #self.items end
    elseif key == next or key == "down" then
        self.cursor = self.cursor + 1
        if self.cursor > #self.items then self.cursor = 1 end
    elseif key == "return" then
        return self.items[self.cursor]
    end

    return nil
end

return Menu
