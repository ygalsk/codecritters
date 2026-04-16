local Game     = require("src.core.game")
local C        = require("src.core.constants")
local Types    = require("src.core.types")
local Animator = require("src.core.animator")
local HPBar    = require("src.ui.hp_bar")
local Text     = require("src.ui.text")
local Menu     = require("src.ui.menu")
local flux     = require("lib.flux")
local Panel    = require("src.ui.panel")

local HubState = {}

-- ── layout constants (pixel) ──────────────────────────────────────────────────
local SPRITE_SCALE  = 3

local TABS = { "Party", "Roster", "Items", "Records" }

local tab_items = {}
for i, name in ipairs(TABS) do
    tab_items[i] = { text = "[" .. i .. "] " .. name, index = i }
end
local tab_menu = nil

-- Stat label fixed-column offsets
local STAT_LABEL_X = 80
local STAT_VALUE_X = 80 + 72

-- ── internal state ────────────────────────────────────────────────────────────
local anim          = nil
local active_tab    = 1
local selected_slot = 1
local btn_pulse     = { v = 0.0 }

-- ── helpers ───────────────────────────────────────────────────────────────────

local function lerp_color(c1, c2, t)
    local r1 = math.floor(c1 / 0x10000) % 256
    local g1 = math.floor(c1 / 0x100) % 256
    local b1 = c1 % 256
    local r2 = math.floor(c2 / 0x10000) % 256
    local g2 = math.floor(c2 / 0x100) % 256
    local b2 = c2 % 256
    local r = math.floor(r1 + (r2 - r1) * t)
    local g = math.floor(g1 + (g2 - g1) * t)
    local b = math.floor(b1 + (b2 - b1) * t)
    return r * 0x10000 + g * 0x100 + b
end

local function start_pulse()
    btn_pulse.v = 0.0
    flux.to(btn_pulse, 1.2, { v = 1.0 }):ease("sineinout"):oncomplete(function()
        flux.to(btn_pulse, 1.2, { v = 0.0 }):ease("sineinout"):oncomplete(start_pulse)
    end)
end

-- Draw a small filled circle (type dot) followed by move info on one row
local function draw_move_row(px, py, move)
    if not move then return end
    local dot_color = Types.COLORS[move.type] or C.COLOR_GRAY
    engine.graphics.pixel.circle(px + 3, py + 4, 3, dot_color)
    engine.graphics.draw_text(px + 10, py, move.name .. "  " .. tostring(move.power), C.COLOR_WHITE)
end

-- ── lifecycle ─────────────────────────────────────────────────────────────────

function HubState:enter()
    engine.graphics.set_layer(C.LAYER_MODAL)
    active_tab    = 1
    selected_slot = 1

    local creature = Game.data.player_creature
    if creature then
        local spec = creature.species
        anim = Animator:new(spec.sprite, spec.stage, 8)
        anim.scale = SPRITE_SCALE
        anim:play("idle")
    end

    tab_menu = Menu.new(tab_items, 0, 20, {
        horizontal = true,
        shortcuts  = true,
        render     = function(item, px, py, is_selected, fg)
            local tab_w = math.floor(C.SCREEN_W / #TABS)
            local tx = (item.index - 1) * tab_w + math.floor((tab_w - Text.width(item.text)) / 2)
            engine.graphics.draw_text(tx, py, item.text, fg)
            if is_selected then
                engine.graphics.pixel.rect(tx - 4, py + 12, Text.width(item.text) + 8, 2, C.COLOR_GOLD)
            end
        end,
    })

    start_pulse()
end

function HubState:exit()
    if anim then
        anim:destroy()
        anim = nil
    end
end

-- ── update ────────────────────────────────────────────────────────────────────

function HubState:update(dt)
    if anim then anim:update(dt) end
end

-- ── draw ──────────────────────────────────────────────────────────────────────

local function draw_tab_bar()
    -- Header
    Text.draw_centered_at(4, "Hub", C.COLOR_GOLD)
    engine.graphics.pixel.rect(20, 16, C.SCREEN_W - 40, 1, C.COLOR_GRAY)
    engine.graphics.pixel.rect(20, 38, C.SCREEN_W - 40, 1, C.COLOR_GRAY)

    if tab_menu then tab_menu:draw() end
end

local function draw_party_tab()
    local party = Game.data.party
    if not party or #party == 0 then
        party = Game.data.player_creature and { Game.data.player_creature } or {}
    end

    for i = 1, 3 do
        local slot_y = 50 + (i - 1) * 85
        local creature = party[i]

        if creature then
            -- Selected vs non-selected background
            if i == selected_slot then
                Panel.draw(20, slot_y - 4, C.SCREEN_W - 40, 78, { bg = C.COLOR_HIGHLIGHT_BG, border = C.COLOR_HIGHLIGHT_BORDER })
            else
                Panel.draw(20, slot_y - 4, C.SCREEN_W - 40, 78, {})
            end

            -- Type-colored placeholder rect (or anim for slot 1)
            if i == 1 and anim then
                anim:draw(30, slot_y + 8)
            else
                local type_color = Types.COLORS[creature.type] or C.COLOR_GRAY
                engine.graphics.pixel.rect(30, slot_y + 8, 32, 32, type_color)
            end

            -- Name + level
            local name_label = creature.name .. " Lv." .. creature.level
            engine.graphics.draw_text(80, slot_y, name_label, C.COLOR_WHITE)

            -- Type badge
            Text.draw_type_badge(80, slot_y + 16, creature.type, Types.COLORS[creature.type] or C.COLOR_GRAY)

            -- HP bar
            local hp_ratio = creature.hp / creature.max_hp
            HPBar.draw(80, slot_y + 32, hp_ratio, 160, 6)

            -- HP text
            local hp_text = creature.hp .. "/" .. creature.max_hp
            engine.graphics.draw_text(250, slot_y + 32, hp_text, C.COLOR_GRAY)

            -- Slot number
            local slot_label = "(" .. i .. "/3)"
            engine.graphics.draw_text(C.SCREEN_W - 60, slot_y, slot_label, C.COLOR_GRAY)
        else
            -- Empty slot
            engine.graphics.pixel.rect(20, slot_y - 4, C.SCREEN_W - 40, 78, C.COLOR_PANEL_BG)
            local msg = "-- empty --"
            engine.graphics.draw_text(Text.center_x(msg), slot_y + 30, msg, C.COLOR_GRAY)
        end
    end
end

local function draw_placeholder_tab()
    local px, py = Panel.draw_centered(300, 80, { border = C.COLOR_PANEL_BORDER })

    local msg = "Coming in next update"
    engine.graphics.draw_text(px + math.floor((300 - Text.width(msg)) / 2), py + 35, msg, C.COLOR_GRAY)
end

local function draw_start_button()
    local btn_py = C.SCREEN_H - 45
    local btn_w, btn_h = 140, 22
    local btn_x = math.floor(C.SCREEN_W / 2) - math.floor(btn_w / 2)

    -- Button panel with pulsing border
    local border_color = lerp_color(C.COLOR_PANEL_BORDER, C.COLOR_HIGHLIGHT_BORDER, btn_pulse.v)
    Panel.draw(btn_x, btn_py, btn_w, btn_h, { border = border_color })

    -- Button text (always visible)
    local btn_text = "[ Start Run  >  Enter ]"
    Text.draw_centered_at(btn_py + 5, btn_text, C.COLOR_GOLD)
end

function HubState:draw()
    engine.graphics.set_layer(C.LAYER_MODAL)

    -- Background
    engine.graphics.pixel.rect(0, 0, C.SCREEN_W, C.SCREEN_H, C.COLOR_BG)

    -- Tab bar + header
    draw_tab_bar()

    -- Active tab content
    if active_tab == 1 then
        draw_party_tab()
    else
        draw_placeholder_tab()
    end

    -- Start Run button
    draw_start_button()

    -- Floor counter
    local floor_text = "Floor " .. tostring(Game.data.floor) .. "/" .. C.FLOOR_MAX
    engine.graphics.draw_text(20, C.SCREEN_H - 14, floor_text, C.COLOR_GRAY)
end

-- ── input ─────────────────────────────────────────────────────────────────────

HubState.help_text = {
    { key = "1-4",      description = "Switch tabs" },
    { key = "Up/Down",  description = "Select critter" },
    { key = "Enter",    description = "Start run" },
    { key = "Escape",   description = "Back to title" },
    { key = "?",        description = "Show this help" },
}

function HubState:on_key(key, action)
    if action ~= "press" then return end

    if tab_menu and key ~= "up" and key ~= "down" and key ~= "return" and key ~= "escape" then
        local chosen = tab_menu:on_key(key, action)
        if chosen then
            active_tab = chosen.index
            return
        end
    end

    if key == "up" then
        selected_slot = selected_slot - 1
        if selected_slot < 1 then selected_slot = 1 end
    elseif key == "down" then
        local party = Game.data.party
        local max_slots = (party and #party > 0) and #party or 1
        selected_slot = selected_slot + 1
        if selected_slot > max_slots then selected_slot = max_slots end
    elseif key == "return" then
        Game.reset_run()
        Game.fsm:start_run()
    elseif key == "escape" then
        Game.fsm:back_to_title()
    end
end

-- ── registration ──────────────────────────────────────────────────────────────

Game.register_state("hub", HubState)
return HubState
