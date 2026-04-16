local Game = require("src.core.game")
local C = require("src.core.constants")
local BattleEngine = require("src.battle.engine")
local BattleUI = require("src.battle.ui")
local Animator = require("src.core.animator")
local Species = require("src.core.species")

local BattleState = {}

function BattleState:enter()
    local enemy = Game.data.battle_enemy
    self.engine = BattleEngine.new(Game.data.player_creature, enemy.creature)

    -- Create animators for battle sprites (3x scale)
    local player_spec = Species.REGISTRY[Game.data.player_creature.species_id]
    self.player_anim = Animator:new(player_spec.sprite, player_spec.stage, 8)
    self.player_anim.scale = 3

    local enemy_spec = Species.REGISTRY[enemy.creature.species_id]
    self.enemy_anim = Animator:new(enemy_spec.sprite, enemy_spec.stage, 8)
    self.enemy_anim.scale = 3

    self.last_anim_index = 0
    BattleUI.create_move_menu(self.engine.player, self.engine.enemy)
end

function BattleState:exit()
    if self.player_anim then self.player_anim:destroy() end
    if self.enemy_anim then self.enemy_anim:destroy() end
    engine.graphics.set_layer(C.LAYER_BATTLE)
    engine.graphics.pixel.clear()
end

function BattleState:update(dt)
    self.engine:update(dt)
    if self.player_anim then self.player_anim:update(dt) end
    if self.enemy_anim then self.enemy_anim:update(dt) end

    local eng = self.engine
    if eng.phase == "animate" then
        if eng.anim_index ~= self.last_anim_index and eng.anim_index > 0 then
            self.last_anim_index = eng.anim_index
            local action = eng.anim_queue[eng.anim_index]
            if action then
                if action.type == "attack" then
                    local anim = action.is_player and self.player_anim or self.enemy_anim
                    if anim then anim:play("attack") end
                elseif action.type == "hit" then
                    local anim = action.is_player and self.player_anim or self.enemy_anim
                    if anim then anim:play("hit") end
                end
            end
        end
    elseif self.last_anim_index > 0 then
        -- animate phase ended; reset both to idle
        self.last_anim_index = 0
        if self.player_anim then self.player_anim:play("idle") end
        if self.enemy_anim then self.enemy_anim:play("idle") end
    end
end

function BattleState:draw()
    BattleUI.draw(self.engine, self.player_anim, self.enemy_anim)
end

function BattleState:on_key(key, action)
    if action ~= "press" then return end

    local eng = self.engine

    if eng.phase == "select" then
        local menu = BattleUI.get_move_menu()
        if menu then
            local chosen = menu:on_key(key, action)
            if chosen then
                eng:select_player_move(chosen.index)
            end
        end
    elseif eng.phase == "end_victory" then
        if key == "return" then
            Game.data.battle_result = "victory"
            Game.data.run_stats.battles_won = Game.data.run_stats.battles_won + 1
            Game.fsm:end_battle()
        end
    elseif eng.phase == "end_defeat" then
        if key == "return" then
            Game.data.battle_result = "defeat"
            Game.fsm:lose_run()
        end
    end
end

-- Expose BattleUI help_text so the global ? handler can find it
BattleState.help_text = BattleUI.help_text

Game.register_state("battle", BattleState)
return BattleState
