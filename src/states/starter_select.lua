local Game       = require("src.core.game")
local C          = require("src.core.constants")
local Species    = require("src.core.species")
local Types      = require("src.core.types")
local Creature   = require("src.core.creature")
local Animator   = require("src.core.animator")
local Text       = require("src.ui.text")
local flux       = require("lib.flux")
local Transition = require("src.ui.transition")

local StarterSelect = {}

-- ── help overlay entries ─────────────────────────────────────────────────────
StarterSelect.help_text = {
    { key = "Left/Right", description = "Select critter" },
    { key = "Enter",      description = "Confirm selection" },
    { key = "Escape",     description = "Back to title" },
    { key = "?",          description = "Show this help" },
}

-- ── constants ─────────────────────────────────────────────────────────────────

-- Layout: 640px split into 3 columns of ~213px each
local COLS      = 3
local COL_W     = math.floor(C.SCREEN_W / COLS)   -- 213
local SPRITE_Y  = 80    -- pixel y for sprite top-left
local SPRITE_S  = 3     -- scale (3×32 = 96px)
local NAME_PY   = 190   -- approximate pixel y for name text
local TYPE_PY   = 208   -- type badge row
local FLAVOR_PY = 228   -- flavor text row

-- Starter data (flavor text lives here, not in the species registry)
local STARTERS = {
    {
        id     = "println",
        flavor = "Methodical debugger. Logs everything.",
    },
    {
        id     = "goto",
        flavor = "Ancient and resilient. Jumps anywhere.",
    },
    {
        id     = "glitch",
        flavor = "Chaotic. Breaks things on purpose.",
    },
}

-- ── internal state ────────────────────────────────────────────────────────────
local cursor        = 1        -- 1-based selected column
local animators     = {}       -- one Animator per starter
local confirmed     = false    -- guard against double-press
local confirm_flash = { v = 0.0 }  -- flash brightness on confirm
local specs         = {}       -- cached Species.REGISTRY entries for each starter

-- ── helpers ───────────────────────────────────────────────────────────────────

-- Center pixel x for column index (1-based)
local function col_center(i)
    return math.floor((i - 1) * COL_W + COL_W / 2)
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────

function StarterSelect:enter()
    engine.graphics.set_layer(C.LAYER_MODAL)
    cursor          = 1
    confirmed       = false
    confirm_flash.v = 0.0
    animators       = {}
    specs           = {}

    for i, s in ipairs(STARTERS) do
        local spec = Species.REGISTRY[s.id]
        specs[i] = spec
        local anim = Animator:new(spec.sprite, spec.stage, 8)
        anim.scale = SPRITE_S
        anim:play("idle")
        animators[i] = anim
    end
end

function StarterSelect:exit()
    -- Release sprite handles
    for _, anim in ipairs(animators) do
        anim:destroy()
    end
    animators = {}
end

-- ── update ────────────────────────────────────────────────────────────────────

function StarterSelect:update(dt)
    for _, anim in ipairs(animators) do
        anim:update(dt)
    end
end

-- ── draw ──────────────────────────────────────────────────────────────────────

function StarterSelect:draw()
    engine.graphics.set_layer(C.LAYER_MODAL)

    -- Background
    engine.graphics.pixel.rect(0, 0, C.SCREEN_W, C.SCREEN_H, C.COLOR_BG)

    -- Header
    local header  = "Choose Your Critter"
    Text.draw_centered_at(20, header, C.COLOR_GOLD)

    for i, s in ipairs(STARTERS) do
        local spec  = specs[i]
        local cx    = col_center(i)                         -- pixel centre of column
        local sx    = cx - math.floor(32 * SPRITE_S / 2)   -- sprite top-left x

        -- Highlight box behind the selected starter
        if i == cursor then
            local bx = (i - 1) * COL_W + 4
            local by = SPRITE_Y - 8
            local bw = COL_W - 8
            local bh = FLAVOR_PY + 20 - by

            engine.graphics.pixel.rect(bx, by, bw, bh, C.COLOR_HIGHLIGHT_BG)

            -- Border color: lerp to white during confirm flash
            local border_color
            if confirmed then
                local r = math.floor(0x44 + (0xFF - 0x44) * confirm_flash.v)
                local g = math.floor(0xAA + (0xFF - 0xAA) * confirm_flash.v)
                local b = math.floor(0xFF + (0xFF - 0xFF) * confirm_flash.v)
                border_color = r * 0x10000 + g * 0x100 + b
            else
                border_color = C.COLOR_HIGHLIGHT_BORDER
            end

            engine.graphics.pixel.rect(bx, by, bw, 1, border_color)
            engine.graphics.pixel.rect(bx, by + bh - 1, bw, 1, border_color)
            engine.graphics.pixel.rect(bx, by, 1, bh, border_color)
            engine.graphics.pixel.rect(bx + bw - 1, by, 1, bh, border_color)
        end

        -- Animated sprite
        animators[i]:draw(sx, SPRITE_Y)

        -- Name (centred)
        local name_fg = (i == cursor) and C.COLOR_GOLD or C.COLOR_WHITE
        engine.graphics.draw_text(cx - math.floor(Text.width(spec.name) / 2), NAME_PY, spec.name, name_fg)

        -- Type badge (centered on column)
        local badge_w = Text.width(spec.type) + 8
        Text.draw_type_badge(cx - math.floor(badge_w / 2), TYPE_PY, spec.type,
            Types.COLORS[spec.type] or C.COLOR_GRAY)

        -- Flavor text (left-aligned within column, clipped if too long)
        local col_x = (i - 1) * COL_W
        local flavor_x = col_x + 8
        engine.graphics.set_scissor(col_x + 4, FLAVOR_PY, COL_W - 8, Text.height() + 4)
        engine.graphics.draw_text(flavor_x, FLAVOR_PY, s.flavor, C.COLOR_GRAY)
        engine.graphics.set_scissor(0, 0, C.SCREEN_W, C.SCREEN_H)
    end

    -- Footer hint
    local hint   = "Left/Right: select    Enter: confirm"
    Text.draw_centered_at(C.SCREEN_H - 24, hint, C.COLOR_GRAY)
end

-- ── input ─────────────────────────────────────────────────────────────────────

function StarterSelect:on_key(key, action)
    if action ~= "press" or confirmed then return end

    if key == "left" then
        cursor = cursor - 1
        if cursor < 1 then cursor = COLS end
    elseif key == "right" then
        cursor = cursor + 1
        if cursor > COLS then cursor = 1 end
    elseif key == "return" then
        confirmed = true

        local species_id          = STARTERS[cursor].id
        Game.data.player_creature = Creature:new(species_id, 5)
        Game.data.party           = { Game.data.player_creature }

        -- Flash the selected column border to white, then transition
        confirm_flash.v = 0.0
        flux.to(confirm_flash, 0.05, { v = 1.0 }):ease("linear"):oncomplete(function()
            flux.to(confirm_flash, 0.30, { v = 1.0 }):oncomplete(function()
                Transition.start(function() Game.fsm:to_hub() end)
            end)
        end)
    elseif key == "escape" then
        Game.fsm:back_to_title()
    end
end

-- ── registration ──────────────────────────────────────────────────────────────

Game.register_state("starter_select", StarterSelect)
return StarterSelect
