local Game  = require("src.core.game")
local C     = require("src.core.constants")
local Text  = require("src.ui.text")
local flux  = require("lib.flux")
local Panel = require("src.ui.panel")

local TitleState = {}

-- ── help overlay entries ─────────────────────────────────────────────────────
TitleState.help_text = {
    { key = "Enter",  description = "Start game" },
    { key = "Escape", description = "Quit" },
    { key = "?",      description = "Show this help" },
}

-- ── internal state ────────────────────────────────────────────────────────────
local fade            = { alpha = 0 }   -- tweened 0 → 1 on enter
local hint_brightness = { v = 1.0 }     -- pulse value for CTA text
local quit_confirm    = false           -- ESC confirm-quit dialog

-- Lerp between gray (0x888888) and gold (0xFFD700) by t
local function lerp_color(t)
    local r = math.floor(0x88 + (0xFF - 0x88) * t)
    local g = math.floor(0x88 + (0xD7 - 0x88) * t)
    local b = math.floor(0x00 + (0x00 - 0x00) * t)
    return r * 0x10000 + g * 0x100 + b
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────

function TitleState:enter()
    engine.graphics.set_layer(C.LAYER_MODAL)
    fade.alpha          = 0
    hint_brightness.v   = 1.0
    quit_confirm        = false

    -- Fade the whole overlay in over 1.2 seconds
    flux.to(fade, 1.2, { alpha = 1 }):ease("quadout")

    -- Gentle pulse: brightness oscillates between 0.6 and 1.0 on a 1.5s loop
    local function pulse_down()
        flux.to(hint_brightness, 1.5, { v = 0.6 }):ease("sineinout"):oncomplete(function()
            flux.to(hint_brightness, 1.5, { v = 1.0 }):ease("sineinout"):oncomplete(pulse_down)
        end)
    end
    pulse_down()
end

function TitleState:exit()
    fade.alpha = 0
end

-- ── update ────────────────────────────────────────────────────────────────────

function TitleState:update(dt)
    -- pulse is driven by flux tweens; nothing else to tick
end

-- ── draw ──────────────────────────────────────────────────────────────────────

function TitleState:draw()
    -- Nothing to draw until the fade has started
    if fade.alpha <= 0.01 then return end

    engine.graphics.set_layer(C.LAYER_MODAL)

    -- Dark full-screen background
    engine.graphics.pixel.rect(0, 0, C.SCREEN_W, C.SCREEN_H, C.COLOR_BG)

    -- Decorative logo frame
    Panel.draw(100, 55, 440, 30, { bg = C.COLOR_BG, border = C.COLOR_PANEL_BORDER })

    -- "CODECRITTERS" — large title
    local title = "CODECRITTERS"
    Text.draw_centered_at(64, title, C.COLOR_GOLD)

    -- Subtitle
    local sub = "A Programming Roguelike"
    Text.draw_centered_at(88, sub, C.COLOR_WHITE)

    -- Decorative rule below subtitle
    engine.graphics.pixel.rect(40, 180, C.SCREEN_W - 80, 1, C.COLOR_GRAY)

    -- Pulsing CTA hint (always visible, color pulses between gray and gold)
    local hint = "Press Enter to Start"
    Text.draw_centered_at(256, hint, lerp_color(hint_brightness.v))

    -- Small credit line at bottom
    local credit = "Enter — Start   ? — Help"
    Text.draw_centered_at(C.SCREEN_H - 24, credit, C.COLOR_GRAY)

    -- ── Quit confirm dialog ──────────────────────────────────────────────────
    if quit_confirm then
        engine.graphics.set_layer(C.LAYER_MODAL)
        local px, py = Panel.draw_centered(200, 80, { border = C.COLOR_PANEL_BORDER })
        -- "Quit game?" centered
        local q_text = "Quit game?"
        engine.graphics.draw_text(
            Text.center_x(q_text), py + 20,
            q_text, C.COLOR_GOLD)
        -- "[Y] Yes   [N] Cancel"
        local opt = "[Y] Yes   [N] Cancel"
        engine.graphics.draw_text(
            Text.center_x(opt), py + 48,
            opt, C.COLOR_WHITE)
    end
end

-- ── input ─────────────────────────────────────────────────────────────────────

function TitleState:on_key(key, action)
    if action ~= "press" then return end

    if quit_confirm then
        if key == "y" or key == "return" then
            engine.quit()
        elseif key == "n" or key == "escape" then
            quit_confirm = false
        end
        return
    end

    if key == "return" or key == "space" then
        Game.fsm:select_starter()
    elseif key == "escape" then
        quit_confirm = true
    end
end

-- ── registration ──────────────────────────────────────────────────────────────

Game.register_state("title", TitleState)
return TitleState
