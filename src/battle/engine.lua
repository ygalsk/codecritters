local Types = require("src.core.types")
local Moves = require("src.core.moves")
local Status = require("src.core.status")

local BattleEngine = {}
BattleEngine.__index = BattleEngine

function BattleEngine.new(player_creature, enemy_creature)
    local self = setmetatable({}, BattleEngine)
    self.player = player_creature
    self.enemy = enemy_creature
    self.phase = "intro"  -- intro, select, resolve, animate, check, end_victory, end_defeat
    self.phase_timer = 0
    self.player_move = nil  -- index chosen by player
    self.enemy_move = nil   -- index chosen by AI
    self.log = {}           -- battle log messages (last 4)
    self.turn = 0
    self.result = nil       -- "victory" or "defeat" when done
    self.anim_queue = {}    -- queued animation actions
    self.anim_index = 0
    return self
end

function BattleEngine:add_log(msg)
    table.insert(self.log, msg)
    if #self.log > 4 then
        table.remove(self.log, 1)
    end
end

function BattleEngine:update(dt)
    self.phase_timer = self.phase_timer + dt

    if self.phase == "intro" then
        if self.phase_timer >= 1.0 then
            self:add_log("A wild " .. self.enemy.name .. " appeared!")
            self.phase = "select"
            self.phase_timer = 0
        end

    elseif self.phase == "resolve" then
        self:resolve_turn()

    elseif self.phase == "animate" then
        -- Wait for animation timer to advance through queued actions
        if self.phase_timer >= 0.8 then
            self.anim_index = self.anim_index + 1
            self.phase_timer = 0
            if self.anim_index > #self.anim_queue then
                self.phase = "check"
                self.phase_timer = 0
            end
        end

    elseif self.phase == "check" then
        self:check_battle_end()
    end
end

function BattleEngine:select_player_move(index)
    if self.phase ~= "select" then return end
    self.player_move = index
    -- AI picks simultaneously
    local AI = require("src.battle.ai")
    self.enemy_move = AI.pick_move(self.enemy, self.player)
    self.phase = "resolve"
    self.phase_timer = 0
end

function BattleEngine:resolve_turn()
    self.turn = self.turn + 1
    self.anim_queue = {}
    self.anim_index = 0

    local player_speed = self.player:get_stat("speed")
    local enemy_speed = self.enemy:get_stat("speed")

    -- Determine order
    local first, second, first_move_idx, second_move_idx, first_is_player
    if player_speed >= enemy_speed then
        first = self.player
        second = self.enemy
        first_move_idx = self.player_move
        second_move_idx = self.enemy_move
        first_is_player = true
    else
        first = self.enemy
        second = self.player
        first_move_idx = self.enemy_move
        second_move_idx = self.player_move
        first_is_player = false
    end

    -- Resolve first action
    self:resolve_action(first, second, first_move_idx, first_is_player)

    -- Resolve second action (if not fainted)
    if not second:is_fainted() and not first:is_fainted() then
        self:resolve_action(second, first, second_move_idx, not first_is_player)
    end

    -- Tick status effects
    local player_msgs = Status.tick(self.player)
    for _, msg in ipairs(player_msgs) do self:add_log(msg) end
    local enemy_msgs = Status.tick(self.enemy)
    for _, msg in ipairs(enemy_msgs) do self:add_log(msg) end

    self.phase = "animate"
    self.phase_timer = 0
    self.anim_index = 0
end

function BattleEngine:resolve_action(attacker, defender, move_idx, is_player)
    local move_data = attacker:get_move(move_idx)
    if not move_data then return end

    self:add_log(attacker.name .. " used " .. move_data.name .. "!")
    table.insert(self.anim_queue, {type = "attack", is_player = is_player})

    -- Accuracy check
    local acc = move_data.accuracy * Status.get_accuracy_mod(attacker) / 100
    if math.random() > acc then
        self:add_log("It missed!")
        return
    end

    -- Damage calculation
    local effectiveness = Types.get_effectiveness(move_data.type, defender.type)
    local atk_logic = attacker:get_stat("logic")
    local def_resolve = math.max(defender:get_stat("resolve"), 1)
    local rand_factor = 0.85 + math.random() * 0.15
    local damage = math.floor(move_data.power * effectiveness * (atk_logic / def_resolve) * rand_factor)
    damage = math.max(1, damage)

    defender:take_damage(damage)
    table.insert(self.anim_queue, {type = "hit", is_player = not is_player})

    -- Effectiveness message
    if effectiveness > 1.0 then
        self:add_log("It's super effective!")
    elseif effectiveness < 1.0 then
        self:add_log("It's not very effective...")
    end

    -- Status effect roll
    if move_data.status_effect and move_data.status_chance then
        if math.random(100) <= move_data.status_chance then
            Status.apply(defender, move_data.status_effect)
            self:add_log(defender.name .. " is " .. move_data.status_effect .. "!")
        end
    end
end

function BattleEngine:check_battle_end()
    if self.enemy:is_fainted() then
        self:add_log(self.enemy.name .. " fainted!")
        -- Award XP
        local xp = self.enemy.level * 10
        local leveled = self.player:add_xp(xp)
        self:add_log("Gained " .. xp .. " XP!")
        if leveled then
            self:add_log(self.player.name .. " leveled up to " .. self.player.level .. "!")
        end
        self.result = "victory"
        self.phase = "end_victory"
    elseif self.player:is_fainted() then
        self:add_log(self.player.name .. " fainted!")
        self.result = "defeat"
        self.phase = "end_defeat"
    else
        -- Next turn
        self.phase = "select"
        self.phase_timer = 0
        self.player_move = nil
        self.enemy_move = nil
    end
end

function BattleEngine:is_over()
    return self.result ~= nil
end

return BattleEngine
