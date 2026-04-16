local C     = require("src.core.constants")
local Game  = require("src.core.game")
local HPBar = require("src.ui.hp_bar")
local Text  = require("src.ui.text")

local HUD = {}

local ZONE_W = 213

function HUD.draw()
    -- HUD background strip (640x40 starting at y=320)
    engine.graphics.pixel.rect(0, C.HUD_Y, C.SCREEN_W, C.HUD_H, C.COLOR_HUD_BG)
    -- Top border
    engine.graphics.pixel.rect(0, C.HUD_Y, C.SCREEN_W, 1, C.COLOR_PANEL_BORDER)

    -- Build party list, falling back to single player_creature
    local party = Game.data.party
    if not party or #party == 0 then
        party = Game.data.player_creature and { Game.data.player_creature } or {}
    end

    -- Draw up to 3 party slots
    for i = 1, 3 do
        local zone_x = (i - 1) * ZONE_W
        local creature = party[i]
        if creature then
            -- Name (truncated to 8 chars)
            local name = string.sub(creature.name, 1, 8)
            local fg = (i == 1) and C.COLOR_WHITE or C.COLOR_GRAY
            Text.draw(zone_x + 10, C.HUD_Y + 4, name, fg)

            -- HP bar
            local ratio = creature.hp / creature.max_hp
            HPBar.draw(zone_x + 10, C.HUD_Y + 16, ratio, 80, 5)

            -- HP numbers
            local hp_text = creature.hp .. "/" .. creature.max_hp
            Text.draw(zone_x + 95, C.HUD_Y + 16, hp_text, C.COLOR_GRAY)
        end
    end

    -- Slot dividers
    engine.graphics.pixel.rect(213, C.HUD_Y + 4, 1, 32, C.COLOR_PANEL_BORDER)
    engine.graphics.pixel.rect(426, C.HUD_Y + 4, 1, 32, C.COLOR_PANEL_BORDER)

    -- Gold counter
    local gold_text = "G:" .. tostring(Game.data.gold or 0) .. "g"
    Text.draw(470, C.HUD_Y + 14, gold_text, C.COLOR_GOLD)

    -- Floor counter
    local floor_text = "Floor " .. tostring(Game.data.floor or 1) .. "/" .. C.FLOOR_MAX
    Text.draw(550, C.HUD_Y + 14, floor_text, C.COLOR_WHITE)
end

return HUD
