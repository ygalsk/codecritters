local Game  = require("src.core.game")
local C     = require("src.core.constants")
local Text  = require("src.ui.text")
local Panel = require("src.ui.panel")

local DefeatState = {}

-- ── internal state ────────────────────────────────────────────────────────────
local stat_lines = {}

-- ── lifecycle ─────────────────────────────────────────────────────────────────

function DefeatState:enter()
    engine.graphics.set_layer(C.LAYER_MODAL)

    local stats = Game.data.run_stats or {}
    local party = Game.data.party or {}
    local scars = stats.scars or {}

    -- Build cooldown list (fainted party members)
    local cooldown_names = {}
    for _, c in ipairs(party) do
        if c.hp == 0 then cooldown_names[#cooldown_names + 1] = c.name end
    end
    local cooldown_str = #cooldown_names > 0 and table.concat(cooldown_names, ", ") or "None"

    -- Build scars list
    local scar_lines = {}
    if #scars > 0 then
        for _, s in ipairs(scars) do
            scar_lines[#scar_lines + 1] = { text = "  " .. s.creature_name .. " -1 " .. s.stat, color = C.COLOR_RED }
        end
    end

    stat_lines = {
        { text = "Floor reached: " .. tostring(Game.data.floor or 0) .. "/" .. C.FLOOR_MAX, color = C.COLOR_WHITE },
        { text = "Battles won: "   .. tostring(stats.battles_won or 0), color = C.COLOR_WHITE },
        { text = "Critters on cooldown: " .. cooldown_str, color = C.COLOR_WHITE },
        { text = "Scars applied:", color = C.COLOR_WHITE },
    }

    if #scar_lines > 0 then
        for _, sl in ipairs(scar_lines) do
            stat_lines[#stat_lines + 1] = sl
        end
    else
        stat_lines[#stat_lines + 1] = { text = "  None", color = C.COLOR_GRAY }
    end
end

function DefeatState:exit() end

function DefeatState:update(dt) end

-- ── draw ──────────────────────────────────────────────────────────────────────

function DefeatState:draw()
    engine.graphics.set_layer(C.LAYER_MODAL)

    -- Dark full-screen background
    engine.graphics.pixel.rect(0, 0, C.SCREEN_W, C.SCREEN_H, C.COLOR_BG)

    -- Panel (darker/redder than victory)
    local px, py = Panel.draw_centered(400, 220, { bg = C.COLOR_PANEL_DARK, border = C.COLOR_RED })

    -- "Run Over." header centered in red
    local title = "Run Over."
    engine.graphics.draw_text(
        Text.center_x(title), py + 10,
        title, C.COLOR_RED)

    -- Red rule below header
    engine.graphics.pixel.rect(px + 10, py + 28, pw - 20, 1, C.COLOR_RED)

    -- Stat lines
    local line_y = py + 38
    for _, line in ipairs(stat_lines) do
        engine.graphics.draw_text(px + 16, line_y, line.text, line.color)
        line_y = line_y + Text.height() + 10
    end

    -- Flavor line
    local flavor = "Catches kept. Come back stronger."
    engine.graphics.draw_text(
        Text.center_x(flavor), py + ph - 44,
        flavor, C.COLOR_GRAY)

    -- Gray rule above footer
    engine.graphics.pixel.rect(px + 10, py + ph - 30, pw - 20, 1, C.COLOR_GRAY)

    -- Footer (static, not blinking)
    local footer = "Press Enter -- Return to Title"
    engine.graphics.draw_text(
        Text.center_x(footer), py + ph - 18,
        footer, C.COLOR_WHITE)
end

-- ── input ─────────────────────────────────────────────────────────────────────

function DefeatState:on_key(key, action)
    if action ~= "press" then return end
    if key == "return" then
        Game.reset_all()
        Game.fsm:restart()
    end
end

-- ── registration ──────────────────────────────────────────────────────────────

Game.register_state("defeat", DefeatState)
return DefeatState
