local Room = {}

function Room.new(opts)
    return {
        gx = opts.gx or 0,          -- grid cell col (in the 3x2 meta-grid, 0-based)
        gy = opts.gy or 0,           -- grid cell row (0-based)
        tx = opts.tx or 0,           -- tile x position of top-left corner (1-based)
        ty = opts.ty or 0,           -- tile y position of top-left corner (1-based)
        tw = opts.tw or 8,           -- width in tiles
        th = opts.th or 7,           -- height in tiles
        type = opts.type or "normal", -- "start", "enemy", "boss"
        enemies = {},                 -- enemy references
        revealed = opts.revealed or false,
        connections = {},             -- list of connected room indices
    }
end

return Room
