-- CodeCritters type system: 7 types with effectiveness, status effects, and badge colors
local Types = {}

Types.LIST = {"DEBUG", "CHAOS", "PATIENCE", "WISDOM", "SNARK", "VIBE", "LEGACY"}

-- EFFECTIVENESS[attacker][defender] = multiplier
-- 1.5 = super effective, 1.0 = neutral, 0.5 = not very effective
-- Source: design doc type chart
--   DEBUG    strong vs CHAOS, VIBE        weak vs WISDOM, LEGACY
--   CHAOS    strong vs PATIENCE, SNARK, LEGACY   weak vs DEBUG, WISDOM
--   PATIENCE strong vs CHAOS, WISDOM      weak vs VIBE, SNARK
--   WISDOM   strong vs DEBUG, PATIENCE    weak vs LEGACY, SNARK
--   SNARK    strong vs PATIENCE, WISDOM   weak vs CHAOS, VIBE
--   VIBE     strong vs SNARK, LEGACY      weak vs DEBUG, PATIENCE
--   LEGACY   strong vs DEBUG, WISDOM      weak vs CHAOS, VIBE

local function build_effectiveness()
    local t = {}

    -- Initialize all matchups to 1.0
    for _, atk in ipairs(Types.LIST) do
        t[atk] = {}
        for _, def in ipairs(Types.LIST) do
            t[atk][def] = 1.0
        end
    end

    -- Helper to set strong/weak entries
    local function set(atk, strong_list, weak_list)
        for _, def in ipairs(strong_list) do
            t[atk][def] = 1.5
        end
        for _, def in ipairs(weak_list) do
            t[atk][def] = 0.5
        end
    end

    set("DEBUG",    {"CHAOS",   "VIBE"},             {"WISDOM",   "LEGACY"})
    set("CHAOS",    {"PATIENCE","SNARK",  "LEGACY"},  {"DEBUG",    "WISDOM"})
    set("PATIENCE", {"CHAOS",   "WISDOM"},            {"VIBE",     "SNARK"})
    set("WISDOM",   {"DEBUG",   "PATIENCE"},          {"LEGACY",   "SNARK"})
    set("SNARK",    {"PATIENCE","WISDOM"},            {"CHAOS",    "VIBE"})
    set("VIBE",     {"SNARK",   "LEGACY"},            {"DEBUG",    "PATIENCE"})
    set("LEGACY",   {"DEBUG",   "WISDOM"},            {"CHAOS",    "VIBE"})

    return t
end

Types.EFFECTIVENESS = build_effectiveness()

-- Status effect inflicted when a type lands a hit
Types.STATUS = {
    DEBUG    = "linted",
    CHAOS    = "segfaulted",
    PATIENCE = "blocked",
    WISDOM   = "enlightened",
    SNARK    = "tilted",
    VIBE     = "hallucinating",
    LEGACY   = "deprecated",
}

-- Badge colors (hex integers)
Types.COLORS = {
    DEBUG    = 0x4FC3F7,  -- light blue
    CHAOS    = 0xFF5252,  -- red
    PATIENCE = 0xFFB74D,  -- orange
    WISDOM   = 0xAB47BC,  -- purple
    SNARK    = 0xF06292,  -- pink
    VIBE     = 0x66BB6A,  -- green
    LEGACY   = 0x8D6E63,  -- brown
}

-- Convenience function: returns the damage multiplier for an attack matchup
-- atk_type and def_type must be strings from Types.LIST
function Types.get_effectiveness(atk_type, def_type)
    local row = Types.EFFECTIVENESS[atk_type]
    if row then
        return row[def_type] or 1.0
    end
    return 1.0
end

return Types
