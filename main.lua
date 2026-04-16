-- CodeCritters
-- Pokemon-style roguelike for the terminal

local Game = require("src.core.game")

-- Require all state modules (they self-register with Game)
require("src.states.title")
require("src.states.starter_select")
require("src.states.hub")
require("src.states.dungeon")
require("src.states.battle")
require("src.states.victory")
require("src.states.defeat")

engine.debug = true   -- F3: FPS counter, F5: hot reload

function engine.load()
    engine.graphics.set_resolution(640, 360)
    Game.init()
end

function engine.update(dt)
    Game.update(dt)
end

function engine.draw()
    Game.draw()
end

function engine.on_key(key, action)
    Game.on_key(key, action)
end
