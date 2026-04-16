local Status = {}

-- Status effect definitions
Status.EFFECTS = {
    linted = {
        duration    = 2,
        description = "Accuracy reduced by 20%",
    },
    segfaulted = {
        duration    = 3,
        description = "Takes 25% max HP damage each turn",
    },
    deprecated = {
        duration    = 3,
        description = "All stats decrease by 5% per turn",
    },
}

-- Apply a status effect to a creature.
-- If the creature already has the same status, refresh the duration.
-- If it has a different status, replace it.
-- creature.status = { name = effect_name, turns_left = duration, stacks = 1 }
function Status.apply(creature, effect_name)
    local effect = Status.EFFECTS[effect_name]
    if not effect then return end

    if creature.status and creature.status.name == effect_name then
        -- Refresh duration, keep stacks
        creature.status.turns_left = effect.duration
    else
        -- Replace any existing status
        creature.status = {
            name       = effect_name,
            turns_left = effect.duration,
            stacks     = 1,
        }
    end
end

-- Tick status effects (called at end of each turn).
-- Applies per-turn effects, increments stacks where relevant,
-- decrements turns_left, and removes the status when it expires.
-- Returns a table of strings describing what happened.
function Status.tick(creature)
    local messages = {}

    if not creature.status then
        return messages
    end

    local name = creature.status.name

    if name == "segfaulted" then
        local damage = math.max(1, math.floor(creature.max_hp * 0.25))
        creature:take_damage(damage)
        table.insert(messages, creature.name .. " is segfaulted! Took " .. damage .. " damage!")

    elseif name == "deprecated" then
        -- Stacks increment each turn (was 1 on application; becomes 2 on turn 1, etc.)
        -- The multiplier used by get_stat_mod reads stacks directly, so increment first
        -- so that on the first tick the penalty is already -5% (stacks == 1 set at apply,
        -- and we increment here to 2 only on the *second* turn).
        -- Design intent: turn 1 = -5%, turn 2 = -10%, turn 3 = -15%.
        -- stacks starts at 1 (applied), so we do NOT increment on the first tick —
        -- instead we increment after the first turn resolves, i.e. when turns_left goes
        -- from 3 → 2 we bump stacks from 1 → 2, and so on.
        table.insert(messages, creature.name .. " is deprecated! Stats are reduced!")
    end

    -- Decrement duration
    creature.status.turns_left = creature.status.turns_left - 1

    -- Increment deprecated stacks after the current turn's effect (for next turn)
    if name == "deprecated" and creature.status.turns_left > 0 then
        creature.status.stacks = creature.status.stacks + 1
    end

    -- Remove expired status
    if creature.status.turns_left <= 0 then
        table.insert(messages, creature.name .. "'s " .. name .. " wore off!")
        creature.status = nil
    end

    return messages
end

-- Remove status from a creature immediately.
function Status.remove(creature)
    creature.status = nil
end

-- Get accuracy modifier (multiplier) for a creature.
-- Returns 0.8 if linted, 1.0 otherwise.
function Status.get_accuracy_mod(creature)
    if creature.status and creature.status.name == "linted" then
        return 0.8
    end
    return 1.0
end

-- Get stat modifier (multiplier) for a creature.
-- Returns 1.0 - (0.05 * stacks) if deprecated, 1.0 otherwise.
function Status.get_stat_mod(creature)
    if creature.status and creature.status.name == "deprecated" then
        return 1.0 - (0.05 * creature.status.stacks)
    end
    return 1.0
end

return Status
