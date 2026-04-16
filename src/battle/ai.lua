local Types = require("src.core.types")
local AI = {}

-- Pick a move index (1-based) for the enemy
-- 20% random, otherwise prefer super-effective > highest power
function AI.pick_move(enemy, target)
    local num_moves = #enemy.moves
    if num_moves == 0 then return 1 end

    -- 20% random
    if math.random(100) <= 20 then
        return math.random(num_moves)
    end

    -- Score each move
    local best_idx = 1
    local best_score = -1
    for i = 1, num_moves do
        local move = enemy:get_move(i)
        if move then
            local eff = Types.get_effectiveness(move.type, target.type)
            local score = move.power * eff
            if score > best_score then
                best_score = score
                best_idx = i
            end
        end
    end
    return best_idx
end

return AI
