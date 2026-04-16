local C     = require("src.core.constants")
local Types = require("src.core.types")
local HPBar = require("src.ui.hp_bar")
local Text  = require("src.ui.text")
local Panel = require("src.ui.panel")
local Menu  = require("src.ui.menu")

local BattleUI = {}

local move_menu = nil

BattleUI.help_text = {
    { key = "1-4",   description = "Select move" },
    { key = "Enter", description = "Confirm move" },
    { key = "?",     description = "Show this help" },
}

function BattleUI.create_move_menu(player, enemy)
    local items = {}
    for i = 1, 4 do
        local move = player:get_move(i)
        if move then
            items[#items + 1] = {
                text       = move.name,
                move       = move,
                index      = i,
                enemy_type = enemy.type,
            }
        end
    end

    local function render(item, px, py, is_selected, fg)
        -- Row highlight for selected
        if is_selected then
            engine.graphics.pixel.rect(8, py - 2, C.SCREEN_W / 2 - 16, 26, C.COLOR_HIGHLIGHT_BG)
        end

        -- Type dot
        local dot_color = Types.COLORS[item.move.type] or C.COLOR_GRAY
        engine.graphics.pixel.circle(px + 12, py + 10, 4, dot_color)

        -- Move label with index prefix
        local label = (is_selected and ">" or " ") .. "[" .. item.index .. "] " .. item.move.name
        engine.graphics.draw_text(px + 22, py + 4, label, fg)

        -- Power bar (relative to 120 max)
        engine.graphics.pixel.rect(192, py + 6, 40, 8, C.COLOR_PANEL_BORDER)
        engine.graphics.pixel.rect(192, py + 6, math.floor((item.move.power / 120) * 40), 8, dot_color)

        -- Effectiveness label
        local eff = Types.get_effectiveness(item.move.type, item.enemy_type)
        if eff > 1.0 then
            engine.graphics.draw_text(242, py + 4, "\xE2\x96\xB2 SUPER", C.COLOR_SUPER_EFF)
        elseif eff < 1.0 then
            engine.graphics.draw_text(242, py + 4, "\xE2\x96\xBC RESIST", C.COLOR_RESIST)
        end
    end

    move_menu = Menu.new(items, 8, 218, { shortcuts = true, render = render, row_height = Text.height() + 20 })
end

function BattleUI.get_move_menu()
    return move_menu
end

function BattleUI.draw(battle_engine, player_animator, enemy_animator)
    engine.graphics.set_layer(C.LAYER_BATTLE)
    engine.graphics.pixel.clear()

    -- Dark background
    engine.graphics.pixel.rect(0, 0, C.SCREEN_W, C.SCREEN_H, C.COLOR_PANEL_DARK)

    local eng = battle_engine
    local player = eng.player
    local enemy = eng.enemy

    -- Draw enemy sprite (top right)
    if enemy_animator then
        enemy_animator:draw(440, 40)
    end

    -- Enemy name + HP
    engine.graphics.draw_text(420, 140, enemy.name .. " Lv" .. enemy.level, Types.COLORS[enemy.type])
    HPBar.draw(420, 155, enemy.hp / enemy.max_hp, 120, 6)
    -- Enemy status badge
    if enemy.status then
        local badge_color = Types.COLORS[enemy.type] or C.COLOR_GRAY
        local badge_text = enemy.status.name .. " " .. tostring(enemy.status.turns_left)
        local badge_w = Text.width(badge_text) + 8
        local badge_px = 420
        local badge_py = 169
        engine.graphics.pixel.rect(badge_px, badge_py, badge_w, 12, badge_color)
        engine.graphics.draw_text(badge_px + 4, badge_py + 1, badge_text, C.COLOR_WHITE)
    end

    -- Draw player sprite (bottom left, above action panel)
    if player_animator then
        player_animator:draw(80, 60)
    end

    -- Player name + HP (above the action panel divider)
    engine.graphics.draw_text(60, 164, player.name .. " Lv" .. player.level, Types.COLORS[player.type])
    HPBar.draw(60, 180, player.hp / player.max_hp, 120, 6)
    -- Player status badge
    if player.status then
        local badge_color = Types.COLORS[player.type] or C.COLOR_GRAY
        local badge_text = player.status.name .. " " .. tostring(player.status.turns_left)
        local badge_w = Text.width(badge_text) + 8
        local badge_px = 60
        local badge_py = 192
        engine.graphics.pixel.rect(badge_px, badge_py, badge_w, 12, badge_color)
        engine.graphics.draw_text(badge_px + 4, badge_py + 1, badge_text, C.COLOR_WHITE)
    end

    -- Action panel background (bottom portion)
    engine.graphics.pixel.rect(0, 208, C.SCREEN_W, 152, C.COLOR_PANEL_BG)
    engine.graphics.pixel.rect(0, 208, C.SCREEN_W, 1, C.COLOR_PANEL_BORDER)

    -- Move menu (when in select phase)
    if eng.phase == "select" and move_menu then
        move_menu:draw()
    end

    -- Battle log panel (bottom-right of screen, inside action panel)
    local log_pw = 300
    local log_ph = 80
    local log_px = C.SCREEN_W - log_pw - 8
    local log_py = C.SCREEN_H - log_ph - 8
    Panel.draw(log_px, log_py, log_pw, log_ph, { border = C.COLOR_PANEL_BORDER, scissor = true })

    -- Show last 3 messages, newest = white, middle = gray, oldest = dark
    local log = eng.log
    local log_count = #log
    local colors = { 0x555555, C.COLOR_GRAY, C.COLOR_WHITE }  -- oldest to newest
    for offset = 0, 2 do
        local idx = log_count - 2 + offset  -- oldest of last 3
        if idx >= 1 and log[idx] then
            engine.graphics.draw_text(log_px + 6, log_py + 10 + offset * (Text.height() + 12), log[idx], colors[offset + 1])
        end
    end
    Panel.clear_scissor()

    -- Phase messages
    if eng.phase == "intro" then
        local msg = "A wild " .. enemy.name .. " appeared!"
        local msg_w = Text.width(msg) + 20
        local msg_px = math.floor((C.SCREEN_W - msg_w) / 2)
        local msg_py = math.floor(C.SCREEN_H / 2) - 15
        Panel.draw(msg_px, msg_py, msg_w, 24, { border = C.COLOR_PANEL_BORDER })
        engine.graphics.draw_text(msg_px + 10, msg_py + 6, msg, C.COLOR_WHITE)
    elseif eng.phase == "end_victory" then
        local msg = "Victory!"
        local sub = "Press Enter to continue"
        local msg_w = math.max(Text.width(msg), Text.width(sub)) + 20
        local msg_px = math.floor((C.SCREEN_W - msg_w) / 2)
        local msg_py = math.floor(C.SCREEN_H / 2) - 20
        Panel.draw(msg_px, msg_py, msg_w, 38, { border = C.COLOR_PANEL_BORDER })
        engine.graphics.draw_text(msg_px + 10, msg_py + 6,  msg, C.COLOR_GOLD)
        engine.graphics.draw_text(msg_px + 10, msg_py + 22, sub, C.COLOR_GRAY)
    elseif eng.phase == "end_defeat" then
        local msg = "Defeated..."
        local sub = "Press Enter to continue"
        local msg_w = math.max(Text.width(msg), Text.width(sub)) + 20
        local msg_px = math.floor((C.SCREEN_W - msg_w) / 2)
        local msg_py = math.floor(C.SCREEN_H / 2) - 20
        Panel.draw(msg_px, msg_py, msg_w, 38, { border = C.COLOR_PANEL_BORDER })
        engine.graphics.draw_text(msg_px + 10, msg_py + 6,  msg, C.COLOR_RED)
        engine.graphics.draw_text(msg_px + 10, msg_py + 22, sub, C.COLOR_GRAY)
    end
end

return BattleUI
