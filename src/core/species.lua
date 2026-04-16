local Species = {}

-- Species.REGISTRY[id] = { name, type, base_stats, moves, sprite, stage }
--
-- Sprite sheet conventions:
--   "base"  stage: 352x32 PNG, 11 frames @ 32x32 (indices 0-10)
--     idle: 0-3 | attack: 4-6 | hit: 7-8 | faint: 9-10
--   "final" stage: 448x32 PNG, 14 frames @ 32x32 (indices 0-13)
--     idle: 0-5 | attack: 6-8 | hit: 9-10 | faint: 11-13

Species.REGISTRY = {

    -- Starters
    println = {
        name       = "Println",
        type       = "DEBUG",
        base_stats = { hp = 45, logic = 35, resolve = 30, speed = 40 },
        moves      = { "log_dump", "stack_trace" },
        sprite     = "assets/sprites/println.png",
        stage      = "base",
    },
    ["goto"] = {
        name       = "Goto",
        type       = "LEGACY",
        base_stats = { hp = 55, logic = 30, resolve = 40, speed = 25 },
        moves      = { "jump_table", "legacy_slam" },
        sprite     = "assets/sprites/goto.png",
        stage      = "base",
    },
    glitch = {
        name       = "Glitch",
        type       = "CHAOS",
        base_stats = { hp = 40, logic = 40, resolve = 25, speed = 45 },
        moves      = { "bit_flip", "crash_dump" },
        sprite     = "assets/sprites/glitch.png",
        stage      = "base",
    },

    -- Floor 1 enemies (level ~5)
    printf = {
        name       = "Printf",
        type       = "DEBUG",
        base_stats = { hp = 35, logic = 30, resolve = 25, speed = 35 },
        moves      = { "type_check", "null_ref" },
        sprite     = "assets/sprites/printf.png",
        stage      = "base",
    },
    segfault = {
        name       = "Segfault",
        type       = "CHAOS",
        base_stats = { hp = 30, logic = 35, resolve = 20, speed = 40 },
        moves      = { "null_ref", "bit_flip" },
        sprite     = "assets/sprites/segfault.png",
        stage      = "base",
    },
    singleton = {
        name       = "Singleton",
        type       = "PATIENCE",
        base_stats = { hp = 40, logic = 25, resolve = 35, speed = 25 },
        moves      = { "spin_lock", "type_check" },
        sprite     = "assets/sprites/singleton.png",
        stage      = "base",
    },

    -- Floor 2 enemies (level ~7)
    mutex = {
        name       = "Mutex",
        type       = "PATIENCE",
        base_stats = { hp = 45, logic = 30, resolve = 35, speed = 30 },
        moves      = { "spin_lock", "tech_debt" },
        sprite     = "assets/sprites/mutex.png",
        stage      = "base",
    },
    monad = {
        name       = "Monad",
        type       = "WISDOM",
        base_stats = { hp = 35, logic = 40, resolve = 30, speed = 35 },
        moves      = { "abstract_away", "code_smell" },
        sprite     = "assets/sprites/monad.png",
        stage      = "base",
    },
    lgtm = {
        name       = "LGTM",
        type       = "SNARK",
        base_stats = { hp = 35, logic = 35, resolve = 25, speed = 40 },
        moves      = { "code_smell", "vibe_check" },
        sprite     = "assets/sprites/lgtm.png",
        stage      = "base",
    },
    copilot = {
        name       = "Copilot",
        type       = "VIBE",
        base_stats = { hp = 40, logic = 35, resolve = 30, speed = 35 },
        moves      = { "vibe_check", "abstract_away" },
        sprite     = "assets/sprites/copilot.png",
        stage      = "base",
    },

    -- Floor 3 boss (level ~12)
    profiler = {
        name       = "Profiler",
        type       = "DEBUG",
        base_stats = { hp = 70, logic = 45, resolve = 40, speed = 35 },
        moves      = { "deep_scan", "memory_leak" },
        sprite     = "assets/sprites/profiler.png",
        stage      = "final",
    },
}

-- Starter selection pool
Species.STARTERS = { "println", "goto", "glitch" }

-- Enemy pools keyed by floor number
Species.FLOOR_ENEMIES = {
    [1] = { "printf", "segfault", "singleton" },
    [2] = { "mutex", "monad", "lgtm", "copilot" },
    [3] = { "profiler" },
}

-- Base encounter level per floor
Species.FLOOR_LEVELS = {
    [1] = 5,
    [2] = 7,
    [3] = 12,
}

return Species
