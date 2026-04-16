local C     = require("src.core.constants")
local Text  = require("src.ui.text")
local Panel = require("src.ui.panel")

local HelpModal = {}

local open = false
local current_help = {}

function HelpModal.show(help_text)
    open = true
    current_help = help_text or {}
end

function HelpModal.hide()
    open = false
end

function HelpModal.is_open()
    return open
end

function HelpModal.draw()
    if not open then return end
    engine.graphics.set_layer(C.LAYER_MODAL)
    -- Dark background overlay
    engine.graphics.pixel.rect(0, 0, C.SCREEN_W, C.SCREEN_H, C.COLOR_BLACK)
    -- Panel (centered, 300x200)
    local px, py = Panel.draw_centered(300, 200, { border = C.COLOR_PANEL_BORDER, scissor = true })

    -- Title
    local title = "Help"
    engine.graphics.draw_text(
        Text.center_x(title),
        py + 10,
        title, C.COLOR_GOLD)

    -- Help rows (clipped by scissor if they overflow the panel)
    local row_py = py + 40
    for _, entry in ipairs(current_help) do
        engine.graphics.draw_text(px + 10,  row_py, entry.key,         C.COLOR_YELLOW)
        engine.graphics.draw_text(px + 100, row_py, entry.description, C.COLOR_WHITE)
        row_py = row_py + Text.height() + 10
    end

    -- Footer
    local footer = "Any key to close"
    engine.graphics.draw_text(
        Text.center_x(footer),
        py + 185,
        footer, C.COLOR_GRAY)

    Panel.clear_scissor()
end

function HelpModal.on_key(key, action)
    if not open then return false end
    if action == "press" then
        open = false
        return true
    end
    return false
end

return HelpModal
