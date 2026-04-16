local class   = require("lib.middleclass")
local Species = require("src.core.species")
local Status  = require("src.core.status")

local Creature = class("Creature")

-- Initialize a Creature from a species_id and level.
-- Stats are computed as: base × (1 + level / 50)
function Creature:initialize(species_id, level)
    local spec = Species.REGISTRY[species_id]

    self.species_id = species_id
    self.species    = spec
    self.name       = spec.name
    self.type       = spec.type
    self.level      = level

    -- Compute stats
    local mult      = 1 + level / 50
    self.max_hp     = math.floor(spec.base_stats.hp      * mult)
    self.hp         = self.max_hp
    self.logic      = math.floor(spec.base_stats.logic   * mult)
    self.resolve    = math.floor(spec.base_stats.resolve * mult)
    self.speed      = math.floor(spec.base_stats.speed   * mult)

    -- Copy move list
    self.moves = {}
    for i, move_id in ipairs(spec.moves) do
        self.moves[i] = move_id
    end

    -- Status effect: nil or { name, turns_left, stacks }
    self.status = nil

    -- XP tracking
    self.xp         = 0
    self.xp_to_next = level * 20
end

-- Reduce HP by n, floored at 0.
function Creature:take_damage(n)
    self.hp = math.max(0, self.hp - n)
end

-- Restore HP by n, capped at max_hp.
function Creature:heal(n)
    self.hp = math.min(self.max_hp, self.hp + n)
end

-- Returns true when HP has reached 0.
function Creature:is_fainted()
    return self.hp <= 0
end

-- Get the effective value of a stat, applying any active status modifiers.
-- stat_name: "hp" | "max_hp" | "logic" | "resolve" | "speed"
function Creature:get_stat(stat_name)
    local base_val
    if stat_name == "hp" then
        return self.hp
    elseif stat_name == "max_hp" then
        return self.max_hp
    elseif stat_name == "logic" then
        base_val = self.logic
    elseif stat_name == "resolve" then
        base_val = self.resolve
    elseif stat_name == "speed" then
        base_val = self.speed
    else
        return 0
    end
    return math.floor(base_val * Status.get_stat_mod(self))
end

-- Return the move definition table for the move at the given index (1-based),
-- or nil if the slot is empty.
function Creature:get_move(index)
    local Moves   = require("src.core.moves")
    local move_id = self.moves[index]
    if move_id then
        return Moves.REGISTRY[move_id]
    end
    return nil
end

-- Recompute stats after a level-up; heals the creature by the HP increase.
function Creature:level_up()
    self.level   = self.level + 1
    local spec   = self.species
    local mult   = 1 + self.level / 50
    local old_max = self.max_hp

    self.max_hp  = math.floor(spec.base_stats.hp      * mult)
    self.hp      = self.hp + (self.max_hp - old_max)  -- heal by the HP increase
    self.logic   = math.floor(spec.base_stats.logic   * mult)
    self.resolve = math.floor(spec.base_stats.resolve * mult)
    self.speed   = math.floor(spec.base_stats.speed   * mult)

    self.xp_to_next = self.level * 20
end

-- Add XP and trigger level-ups as needed.
-- Returns true if the creature leveled up at least once, false otherwise.
function Creature:add_xp(amount)
    self.xp     = self.xp + amount
    local leveled = false
    while self.xp >= self.xp_to_next do
        self.xp = self.xp - self.xp_to_next
        self:level_up()
        leveled = true
    end
    return leveled
end

return Creature
