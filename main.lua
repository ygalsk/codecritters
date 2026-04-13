-- CodeCritters
-- Pokemon-style roguelike for the terminal

function engine.load()
end

function engine.update(dt)
end

function engine.draw()
end

function engine.on_key(key, action)
    if key == "escape" and action == "press" then
        engine.quit_game()
    end
end
