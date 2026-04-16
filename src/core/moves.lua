local Moves = {}

-- Moves.REGISTRY[move_id] = {name, type, power, accuracy, status_effect, status_chance}
Moves.REGISTRY = {

    -- Starter moves: Println (DEBUG)
    log_dump = {
        name           = "Log Dump",
        type           = "DEBUG",
        power          = 45,
        accuracy       = 95,
        status_effect  = "linted",
        status_chance  = 20,
    },
    stack_trace = {
        name           = "Stack Trace",
        type           = "DEBUG",
        power          = 70,
        accuracy       = 85,
        status_effect  = nil,
        status_chance  = nil,
    },

    -- Starter moves: Goto (LEGACY)
    jump_table = {
        name           = "Jump Table",
        type           = "LEGACY",
        power          = 45,
        accuracy       = 95,
        status_effect  = "deprecated",
        status_chance  = 20,
    },
    legacy_slam = {
        name           = "Legacy Slam",
        type           = "LEGACY",
        power          = 70,
        accuracy       = 85,
        status_effect  = nil,
        status_chance  = nil,
    },

    -- Starter moves: Glitch (CHAOS)
    bit_flip = {
        name           = "Bit Flip",
        type           = "CHAOS",
        power          = 45,
        accuracy       = 95,
        status_effect  = "segfaulted",
        status_chance  = 20,
    },
    crash_dump = {
        name           = "Crash Dump",
        type           = "CHAOS",
        power          = 70,
        accuracy       = 85,
        status_effect  = nil,
        status_chance  = nil,
    },

    -- Wild enemy moves (floors 1-2)
    null_ref = {
        name           = "Null Reference",
        type           = "CHAOS",
        power          = 40,
        accuracy       = 90,
        status_effect  = nil,
        status_chance  = nil,
    },
    spin_lock = {
        name           = "Spin Lock",
        type           = "PATIENCE",
        power          = 35,
        accuracy       = 95,
        status_effect  = nil,
        status_chance  = nil,
    },
    type_check = {
        name           = "Type Check",
        type           = "DEBUG",
        power          = 40,
        accuracy       = 90,
        status_effect  = nil,
        status_chance  = nil,
    },
    code_smell = {
        name           = "Code Smell",
        type           = "SNARK",
        power          = 45,
        accuracy       = 85,
        status_effect  = nil,
        status_chance  = nil,
    },
    abstract_away = {
        name           = "Abstract Away",
        type           = "WISDOM",
        power          = 40,
        accuracy       = 90,
        status_effect  = nil,
        status_chance  = nil,
    },
    vibe_check = {
        name           = "Vibe Check",
        type           = "VIBE",
        power          = 45,
        accuracy       = 85,
        status_effect  = nil,
        status_chance  = nil,
    },
    tech_debt = {
        name           = "Tech Debt",
        type           = "LEGACY",
        power          = 50,
        accuracy       = 80,
        status_effect  = nil,
        status_chance  = nil,
    },

    -- Boss moves: Profiler (floor 3)
    deep_scan = {
        name           = "Deep Scan",
        type           = "DEBUG",
        power          = 80,
        accuracy       = 80,
        status_effect  = "linted",
        status_chance  = 30,
    },
    memory_leak = {
        name           = "Memory Leak",
        type           = "CHAOS",
        power          = 75,
        accuracy       = 85,
        status_effect  = "segfaulted",
        status_chance  = 25,
    },
}

return Moves
