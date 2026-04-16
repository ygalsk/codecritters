local Game  = require("src.core.game")
local C     = require("src.core.constants")
local Text  = require("src.ui.text")
local Panel = require("src.ui.panel")

local VictoryState = {}

-- ── internal state ────────────────────────────────────────────────────────────
local stat_lines = {}

-- ── lifecycle ─────────────────────────────────────────────────────────────────

function VictoryState:enter()
    engine.graphics.set_layer(C.LAYER_MODAL)

    local stats = Game.data.run_stats or {}
    local caught = stats.caught_this_run or {}
    local scars = stats.scars or {}

    -- Build caught string
    local caught_str
    if #caught > 0 then
        local names = {}
        for _, c in ipairs(caught) do names[#names + 1] = c.name end
        caught_str = table.concat(names, ", ")
    else
        caught_str = "None"
    end

    -- Build scars string
    local scar_str
    if #scars > 0 then
        local ss = {}
        for _, s in ipairs(scars) do ss[#ss + 1] = s.creature_name .. " -1 " .. s.stat end
        scar_str = table.concat(ss, ", ")
    else
        scar_str = "None"
    end

    stat_lines = {
        { text = "Floors cleared: " .. tostring(stats.floors_cleared or 0), color = C.COLOR_WHITE },
        { text = "Battles won: "    .. tostring(stats.battles_won    or 0), color = C.COLOR_WHITE },
        { text = "Gold earned: "    .. tostring(Game.data.gold or 0) .. "g", color = C.COLOR_GOLD },
        { text = "Catches: " .. caught_str, color = C.COLOR_WHITE },
        { text = "Scars: " .. scar_str, color = (#scars > 0) and C.COLOR_RED or C.COLOR_GRAY },
    }
end

function VictoryState:exit() end

function VictoryState:update(dt) end

-- ── draw ──────────────────────────────────────────────────────────────────────

function VictoryState:draw()
    engine.graphics.set_layer(C.LAYER_MODAL)

    -- Dark full-screen background
    engine.graphics.pixel.rect(0, 0, C.SCREEN_W, C.SCREEN_H, C.COLOR_BG)

    -- Panel
    local px, py = Panel.draw_centered(400, 240, { border = C.COLOR_PANEL_BORDER })

    -- "Victory!" header centered
    local title = "Victory!"
    engine.graphics.draw_text(
        Text.center_x(title), py + 10,
        title, C.COLOR_GOLD)

    -- Gold rule below header
    engine.graphics.pixel.rect(px + 10, py + 28, pw - 20, 1, C.COLOR_GOLD)

    -- Stat lines
    local line_y = py + 38
    for _, line in ipairs(stat_lines) do
        engine.graphics.draw_text(px + 16, line_y, line.text, line.color)
        line_y = line_y + Text.height() + 12
    end

    -- Gray rule above footer
    engine.graphics.pixel.rect(px + 10, py + ph - 30, pw - 20, 1, C.COLOR_GRAY)

    -- Footer (static, not blinking)
    local footer = "Press Enter -- Return to Hub"
    engine.graphics.draw_text(
        Text.center_x(footer), py + ph - 18,
        footer, C.COLOR_YELLOW)
end

-- ── input ─────────────────────────────────────────────────────────────────────

function VictoryState:on_key(key, action)
    if action ~= "press" then return end
    if key == "return" then
        Game.reset_all()
        Game.fsm:restart()
    end
end

-- ── registration ──────────────────────────────────────────────────────────────

Game.register_state("victory", VictoryState)
return VictoryState
