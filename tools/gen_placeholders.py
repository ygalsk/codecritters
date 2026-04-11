#!/usr/bin/env python3
"""Generate placeholder tileset and background PNGs for Phase 25a.

Tilesets: 96x16 horizontal strips (6 tiles of 16x16).
    Tile order: [wall][floor][encounter][stairs][entrance][player]

Backgrounds: 384x288 (24*16 x 18*16) gradient fills in biome colors.
"""

from PIL import Image, ImageDraw
import os

# Biome definitions: id -> (wall_rgb, floor_rgb, accent_rgb)
BIOMES = {
    "generic_dungeon":  ((60, 60, 60),    (100, 100, 100), (150, 150, 150)),
    "pythonic_caves":   ((40, 60, 30),    (80, 110, 70),   (120, 180, 80)),
    "node_abyss":       ((50, 30, 60),    (90, 70, 110),   (140, 100, 200)),
    "rustacean_depths": ((180, 100, 40),  (210, 140, 70),  (240, 160, 60)),
    "gopher_tunnels":   ((40, 140, 150),  (70, 180, 190),  (100, 220, 230)),
    "c_catacombs":      ((50, 45, 45),    (90, 75, 75),    (140, 100, 100)),
    "shell_scripts":    ((30, 70, 30),    (50, 140, 50),   (80, 200, 80)),
}

# Tile colors: wall, floor, encounter(gold), stairs(green), entrance(blue), player(white)
ENCOUNTER_COLOR = (255, 200, 40)
STAIRS_COLOR    = (80, 255, 120)
ENTRANCE_COLOR  = (0, 180, 255)
PLAYER_COLOR    = (255, 255, 255)


def draw_textured_tile(draw, x0, y0, base_color, pattern="solid"):
    """Draw a 16x16 tile with some basic texture."""
    for y in range(16):
        for x in range(16):
            px, py = x0 + x, y0 + y
            r, g, b = base_color

            if pattern == "brick":
                # Brick pattern for walls
                row_offset = 8 if (y // 4) % 2 else 0
                if y % 4 == 0 or (x + row_offset) % 8 == 0:
                    r = max(0, r - 20)
                    g = max(0, g - 20)
                    b = max(0, b - 20)
            elif pattern == "dots":
                # Scattered dots for floor
                if (x * 7 + y * 13) % 11 == 0:
                    r = min(255, r + 30)
                    g = min(255, g + 30)
                    b = min(255, b + 30)
            elif pattern == "star":
                # Star/sparkle for encounter
                cx, cy = 8, 8
                dx, dy = abs(x - cx), abs(y - cy)
                if (dx == 0 and dy < 5) or (dy == 0 and dx < 5) or (dx == dy and dx < 3):
                    r = min(255, r + 80)
                    g = min(255, g + 80)
                    b = min(255, b + 80)
            elif pattern == "arrow_down":
                # Down arrow for stairs
                cx = 8
                half_w = max(0, 7 - abs(y - 4))
                if abs(x - cx) <= half_w and y > 2 and y < 13:
                    r = min(255, r + 60)
                    g = min(255, g + 60)
                    b = min(255, b + 60)
                else:
                    r = max(0, r - 40)
                    g = max(0, g - 40)
                    b = max(0, b - 40)
            elif pattern == "arrow_up":
                # Up arrow for entrance
                cx = 8
                half_w = max(0, 7 - abs(11 - y))
                if abs(x - cx) <= half_w and y > 2 and y < 13:
                    r = min(255, r + 60)
                    g = min(255, g + 60)
                    b = min(255, b + 60)
                else:
                    r = max(0, r - 40)
                    g = max(0, g - 40)
                    b = max(0, b - 40)
            elif pattern == "at_sign":
                # Simple @ shape for player
                cx, cy = 8, 8
                dist = ((x - cx)**2 + (y - cy)**2) ** 0.5
                if 3 < dist < 6:
                    pass  # ring
                elif dist <= 3 and x >= cx:
                    pass  # inner right
                else:
                    r = max(0, r - 180)
                    g = max(0, g - 180)
                    b = max(0, b - 180)

            draw.point((px, py), (r, g, b, 255))


def generate_tileset(biome_id, wall_color, floor_color, accent_color):
    """Generate a 96x16 tileset PNG."""
    img = Image.new("RGBA", (96, 16), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    tiles = [
        (wall_color, "brick"),        # wall
        (floor_color, "dots"),        # floor
        (ENCOUNTER_COLOR, "star"),    # encounter
        (STAIRS_COLOR, "arrow_down"), # stairs
        (ENTRANCE_COLOR, "arrow_up"), # entrance
        (PLAYER_COLOR, "at_sign"),    # player
    ]

    for i, (color, pattern) in enumerate(tiles):
        draw_textured_tile(draw, i * 16, 0, color, pattern)

    path = f"assets/tiles/{biome_id}.png"
    img.save(path)
    print(f"  Tileset: {path}")


def generate_background(biome_id, wall_color, floor_color, accent_color):
    """Generate a 960x480 background PNG with gradient (60*16 x 30*16)."""
    w, h = 960, 480
    img = Image.new("RGBA", (w, h), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # Vertical gradient from dark wall to darker floor
    dark_top = tuple(max(0, c // 3) for c in wall_color)
    dark_bot = tuple(max(0, c // 4) for c in floor_color)

    for y in range(h):
        t = y / h
        r = int(dark_top[0] * (1 - t) + dark_bot[0] * t)
        g = int(dark_top[1] * (1 - t) + dark_bot[1] * t)
        b = int(dark_top[2] * (1 - t) + dark_bot[2] * t)
        draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    # Scatter some accent-colored "particles" for atmosphere
    import random
    random.seed(hash(biome_id))
    for _ in range(40):
        px = random.randint(0, w - 1)
        py = random.randint(0, h - 1)
        r, g, b = accent_color
        alpha = random.randint(20, 60)
        size = random.randint(1, 3)
        for dx in range(-size, size + 1):
            for dy in range(-size, size + 1):
                nx, ny = px + dx, py + dy
                if 0 <= nx < w and 0 <= ny < h:
                    existing = img.getpixel((nx, ny))
                    # Alpha blend
                    a = alpha / 255
                    nr = int(existing[0] * (1 - a) + r * a)
                    ng = int(existing[1] * (1 - a) + g * a)
                    nb = int(existing[2] * (1 - a) + b * a)
                    draw.point((nx, ny), (nr, ng, nb, 255))

    path = f"assets/backgrounds/{biome_id}.png"
    img.save(path)
    print(f"  Background: {path}")


def main():
    os.makedirs("assets/tiles", exist_ok=True)
    os.makedirs("assets/backgrounds", exist_ok=True)

    for biome_id, (wall, floor, accent) in BIOMES.items():
        print(f"\n{biome_id}:")
        generate_tileset(biome_id, wall, floor, accent)
        generate_background(biome_id, wall, floor, accent)

    print("\nDone! Generated 7 tilesets + 7 backgrounds.")


if __name__ == "__main__":
    main()
