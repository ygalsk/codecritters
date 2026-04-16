local machine = require("lib.statemachine")
local flux = require("lib.flux")
local timer = require("lib.timer")
local Transition = require("src.ui.transition")
local HelpModal = require("src.ui.help_modal")

local Game = {}

-- Shared game data accessible by all states
Game.data = {
    player_creature = nil,
    party = {},
    gold = 0,
    floor = 1,
    run_stats = {
        battles_won = 0,
        floors_cleared = 0,
        caught_this_run = {},
        scars = {},
    },
}

-- State object registry: states[name] = { enter, exit, update, draw, on_key }
Game.states = {}

-- Global timer instance shared by all states
Game.timer = timer.new()

-- Register a state object
function Game.register_state(name, state_obj)
    Game.states[name] = state_obj
end

-- Initialize the FSM and wire up transitions
function Game.init()
    Game.fsm = machine.create({
        initial = "title",
        events = {
            { name = "select_starter",  from = "title",           to = "starter_select" },
            { name = "to_hub",          from = "starter_select",  to = "hub" },
            { name = "start_run",       from = "hub",             to = "dungeon" },
            { name = "start_battle",    from = "dungeon",         to = "battle" },
            { name = "end_battle",      from = "battle",          to = "dungeon" },
            { name = "win_run",         from = {"dungeon", "battle"}, to = "victory" },
            { name = "lose_run",        from = "battle",          to = "defeat" },
            { name = "restart",         from = {"victory", "defeat"}, to = "title" },
            { name = "back_to_title",  from = {"starter_select", "hub"}, to = "title" },
        },
        callbacks = {
            onstatechange = function(self, event_name, from, to)
                -- Call exit on old state
                local old = Game.states[from]
                if old and old.exit then
                    old:exit()
                end
                -- Call enter on new state
                local new = Game.states[to]
                if new and new.enter then
                    new:enter()
                end
            end,
        },
    })

    -- Enter the initial state
    local initial = Game.states["title"]
    if initial and initial.enter then
        initial:enter()
    end
end

function Game.update(dt)
    flux.update(dt)
    Game.timer:update(dt)

    local current = Game.states[Game.fsm.current]
    if current and current.update then
        current:update(dt)
    end
end

function Game.draw()
    engine.graphics.clear_all()
    local current = Game.states[Game.fsm.current]
    if current and current.draw then
        current:draw()
    end
    Transition.draw()
    HelpModal.draw()
end

function Game.on_key(key, action)
    -- Help modal consumes all input when open
    if HelpModal.on_key(key, action) then return end
    -- Global ? opens help with current state's help_text
    if key == "?" and action == "press" then
        local current = Game.states[Game.fsm.current]
        local help = (current and current.help_text) or {}
        HelpModal.show(help)
        return
    end
    local current = Game.states[Game.fsm.current]
    if current and current.on_key then
        current:on_key(key, action)
    end
end

function Game.reset_run()
    Game.data.gold = 0
    Game.data.floor = 1
    Game.data.run_stats = {
        battles_won = 0,
        floors_cleared = 0,
        caught_this_run = {},
        scars = {},
    }
end

function Game.reset_all()
    Game.data.player_creature = nil
    Game.data.party = {}
    Game.reset_run()
end

return Game
