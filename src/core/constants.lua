-- All magic numbers for the game
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- VISUAL LANGUAGE SPEC
-- ═══════════════════════════════════════════════════════════════════════════════
--
-- Panel Style
--   Fill: C.COLOR_PANEL_BG (dark navy)
--   Border: C.COLOR_PANEL_BORDER (muted gray-purple)
--   Dark variant (battle): C.COLOR_PANEL_DARK
--
-- Highlight Style (selected items)
--   Fill: C.COLOR_HIGHLIGHT_BG (dark blue tint)
--   Border: C.COLOR_HIGHLIGHT_BORDER (bright blue)
--
-- Typography
--   Gold    = headers / titles
--   White   = primary text
--   Gray    = secondary text / hints
--   Type-color = badges (type-colored bg, white text, 2px padding)
--
-- Effectiveness Labels
--   ▲ SUPER EFFECTIVE  →  C.COLOR_SUPER_EFF  (bright green)
--   ▼ RESIST           →  C.COLOR_RESIST     (dim red)
--
-- Status Badge
--   Background: type-colored, Text: white, Padding: 2px
--
-- ═══════════════════════════════════════════════════════════════════════════════
-- ESC NAVIGATION CONTRACT
-- ═══════════════════════════════════════════════════════════════════════════════
--
--   title          → confirm quit dialog
--   starter_select → title (back_to_title)
--   hub            → title (back_to_title)
--   battle         → no-op (cannot flee via ESC)
--   dungeon        → no-op (use stairs / menu instead)
--   victory        → no-op (must press Enter)
--   defeat         → no-op (must press Enter)
--
-- ═══════════════════════════════════════════════════════════════════════════════

local C = {}

C.SCREEN_W = 640
C.SCREEN_H = 360
C.TILE_SIZE = 16
C.DUNGEON_W = 640      -- full width
C.DUNGEON_H = 320      -- viewport height (screen minus HUD)
C.HUD_Y = 320          -- HUD strip starts here
C.HUD_H = 40           -- HUD strip height

-- Compositing layers
C.LAYER_BG = 0
C.LAYER_TILES = 1
C.LAYER_ENTITIES = 2
C.LAYER_UI = 3
C.LAYER_BATTLE = 4
C.LAYER_MODAL = 5

-- Dungeon grid
C.GRID_COLS = 40        -- 640 / 16
C.GRID_ROWS = 20        -- 320 / 16

-- Movement
C.PLAYER_SPEED = 96     -- pixels/sec
C.ENEMY_SPEED = 48      -- pixels/sec
C.CONTACT_DIST = 8      -- pixels, triggers battle
C.DETECT_DIST = 48      -- pixels, enemy chase range

-- Color palette (hex integers for engine API)
C.COLOR_BG = 0x0a0a1a
C.COLOR_WALL = 0x333333
C.COLOR_FLOOR = 0x1a1a2e
C.COLOR_PLAYER = 0x44FF44
C.COLOR_ENEMY = 0xFF6666
C.COLOR_HUD_BG = 0x1a1a2e
C.COLOR_WHITE = 0xFFFFFF
C.COLOR_BLACK = 0x000000
C.COLOR_GRAY = 0x888888
C.COLOR_GOLD = 0xFFD700
C.COLOR_RED = 0xFF4444
C.COLOR_GREEN = 0x44FF44
C.COLOR_YELLOW = 0xFFFF44

-- Dungeon progression
C.FLOOR_MAX = 15

-- Panel colors
C.COLOR_PANEL_BG     = 0x1a1a2e   -- dark panel fill
C.COLOR_PANEL_BORDER = 0x444466   -- panel border
C.COLOR_PANEL_DARK   = 0x111120   -- darker bg (battle)

-- Highlight colors (selected items)
C.COLOR_HIGHLIGHT_BG     = 0x1e2a3a   -- selected item fill
C.COLOR_HIGHLIGHT_BORDER = 0x44AAFF   -- selected item border

-- Effectiveness colors
C.COLOR_SUPER_EFF = 0x00FF88   -- ▲ SUPER EFFECTIVE (bright green)
C.COLOR_RESIST    = 0x884444   -- ▼ RESIST (dim red)

return C
