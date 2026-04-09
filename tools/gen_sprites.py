#!/usr/bin/env python3
"""Generate 16x16 sprite sheets (2 frames, 32x16) for test critters."""

from PIL import Image, ImageDraw

FRAME_W, FRAME_H = 16, 16
SHEET_W = FRAME_W * 2  # 2 frames side by side

# Type colors: (primary, dark outline)
COLORS = {
    "debug":   ((0, 206, 209), (0, 140, 142)),
    "chaos":   ((255, 68, 68),  (178, 34, 34)),
    "legacy":  ((139, 105, 20), (100, 70, 10)),
    "wisdom":  ((155, 89, 182), (110, 60, 140)),
}

def make_sheet(draw_fn, primary, dark):
    """Create a 32x16 RGBA sprite sheet with 2 frames (frame 2 = 1px bounce up)."""
    img = Image.new("RGBA", (SHEET_W, FRAME_H), (0, 0, 0, 0))

    # Frame 0: normal position
    frame0 = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d0 = ImageDraw.Draw(frame0)
    draw_fn(d0, primary, dark, offset_y=0)
    img.paste(frame0, (0, 0))

    # Frame 1: shifted up 1px (idle bounce)
    frame1 = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d1 = ImageDraw.Draw(frame1)
    draw_fn(d1, primary, dark, offset_y=-1)
    img.paste(frame1, (FRAME_W, 0))

    return img

def draw_println(d, pri, dark, offset_y=0):
    """Terminal/monitor shape - DEBUG type."""
    y = 2 + offset_y
    # Monitor body
    d.rectangle([2, y, 13, y+9], fill=dark, outline=pri)
    # Screen
    d.rectangle([3, y+1, 12, y+7], fill=(0, 40, 40, 255))
    # Prompt "> _"
    d.rectangle([4, y+3, 5, y+4], fill=pri)  # >
    d.rectangle([7, y+4, 9, y+5], fill=pri)  # _
    # Stand
    d.rectangle([6, y+10, 9, y+11], fill=dark)
    d.rectangle([4, y+12, 11, y+12], fill=dark)

def draw_tracer(d, pri, dark, offset_y=0):
    """Magnifying glass - DEBUG type."""
    y = 2 + offset_y
    # Lens (circle approximation)
    d.ellipse([3, y, 11, y+8], fill=(0, 60, 60, 200), outline=pri, width=2)
    # Highlight
    d.rectangle([5, y+2, 6, y+3], fill=(200, 255, 255, 180))
    # Handle
    d.line([10, y+7, 13, y+11], fill=dark, width=2)

def draw_glitch(d, pri, dark, offset_y=0):
    """Jagged lightning/glitch - CHAOS type."""
    y = 1 + offset_y
    # Glitchy zigzag body
    points = [
        (7, y), (10, y+3), (8, y+4), (12, y+7),
        (9, y+8), (11, y+11), (6, y+7), (8, y+6),
        (4, y+3), (7, y+4), (5, y+1)
    ]
    d.polygon(points, fill=pri, outline=dark)
    # Glitch artifacts - small displaced rectangles
    d.rectangle([2, y+5, 4, y+6], fill=pri)
    d.rectangle([11, y+2, 13, y+3], fill=pri)
    d.rectangle([1, y+9, 3, y+10], fill=(255, 200, 0, 200))

def draw_goto(d, pri, dark, offset_y=0):
    """Circular arrow (goto loop) - LEGACY type."""
    y = 2 + offset_y
    # Outer circle
    d.ellipse([2, y, 13, y+11], fill=None, outline=pri, width=2)
    # Inner fill (darker)
    d.ellipse([4, y+2, 11, y+9], fill=dark)
    # Arrow head pointing right at top
    d.polygon([(10, y), (14, y+3), (10, y+3)], fill=pri)
    # "GO" text hint
    d.rectangle([6, y+4, 7, y+6], fill=pri)
    d.rectangle([9, y+4, 10, y+6], fill=pri)

def draw_monad(d, pri, dark, offset_y=0):
    """Nested boxes/brackets - WISDOM type."""
    y = 1 + offset_y
    # Outer bracket
    d.rectangle([1, y, 14, y+13], fill=None, outline=pri, width=1)
    # Middle bracket
    d.rectangle([3, y+2, 12, y+11], fill=None, outline=dark, width=1)
    # Inner core
    d.rectangle([5, y+4, 10, y+9], fill=pri)
    # Lambda symbol (λ) hint - two lines
    d.line([6, y+5, 8, y+8], fill=(0, 0, 0, 255), width=1)
    d.line([8, y+8, 10, y+5], fill=(0, 0, 0, 255), width=1)

def draw_profiler(d, pri, dark, offset_y=0):
    """Flame graph / stacked bars - DEBUG final."""
    y = 2 + offset_y
    # Stacked horizontal bars of varying widths (flame graph)
    d.rectangle([5, y, 10, y+2], fill=pri)        # top narrow bar
    d.rectangle([3, y+2, 12, y+4], fill=dark)      # wider bar
    d.rectangle([2, y+4, 13, y+6], fill=pri)       # widest bar
    d.rectangle([4, y+6, 11, y+8], fill=dark)      # mid bar
    d.rectangle([3, y+8, 12, y+10], fill=pri)      # wide bar
    # Base/stand
    d.rectangle([5, y+10, 10, y+11], fill=dark)
    # Highlight peak
    d.rectangle([7, y, 8, y+1], fill=(200, 255, 255, 200))

def draw_gremlin(d, pri, dark, offset_y=0):
    """Imp creature with horns - CHAOS mid."""
    y = 1 + offset_y
    # Horns
    d.polygon([(4, y+3), (3, y), (5, y+2)], fill=pri)
    d.polygon([(11, y+3), (12, y), (10, y+2)], fill=pri)
    # Head
    d.ellipse([4, y+2, 11, y+7], fill=dark, outline=pri)
    # Eyes (menacing)
    d.rectangle([5, y+4, 6, y+5], fill=(255, 255, 0, 255))
    d.rectangle([9, y+4, 10, y+5], fill=(255, 255, 0, 255))
    # Jagged mouth
    d.polygon([(5, y+6), (6, y+7), (7, y+6), (8, y+7), (9, y+6), (10, y+7)], fill=pri)
    # Body
    d.rectangle([5, y+7, 10, y+11], fill=dark)
    # Arms
    d.line([5, y+8, 2, y+10], fill=pri, width=1)
    d.line([10, y+8, 13, y+10], fill=pri, width=1)
    # Feet
    d.rectangle([4, y+11, 6, y+12], fill=pri)
    d.rectangle([9, y+11, 11, y+12], fill=pri)

def draw_pandemonium(d, pri, dark, offset_y=0):
    """Explosion / shattered fragments - CHAOS final."""
    y = 1 + offset_y
    # Central burst
    d.ellipse([5, y+4, 10, y+9], fill=pri)
    # Radiating jagged lines
    d.line([7, y+4, 7, y], fill=(255, 255, 0, 255), width=1)
    d.line([8, y+4, 12, y+1], fill=pri, width=1)
    d.line([10, y+6, 14, y+5], fill=(255, 200, 0, 200), width=1)
    d.line([10, y+8, 14, y+10], fill=pri, width=1)
    d.line([7, y+9, 7, y+13], fill=(255, 255, 0, 255), width=1)
    d.line([5, y+8, 1, y+11], fill=pri, width=1)
    d.line([5, y+6, 1, y+4], fill=(255, 200, 0, 200), width=1)
    d.line([5, y+5, 2, y+1], fill=pri, width=1)
    # Scattered glitch fragments
    d.rectangle([1, y+1, 3, y+2], fill=pri)
    d.rectangle([12, y+8, 14, y+9], fill=(255, 200, 0, 200))
    d.rectangle([2, y+8, 4, y+9], fill=pri)
    d.rectangle([11, y+2, 13, y+3], fill=(255, 255, 0, 255))

def draw_spaghetto(d, pri, dark, offset_y=0):
    """Tangled lines / spaghetti knot - LEGACY mid."""
    y = 1 + offset_y
    # Overlapping curved lines forming a messy tangle
    d.arc([2, y, 12, y+8], 0, 180, fill=pri, width=2)
    d.arc([3, y+2, 13, y+10], 90, 300, fill=dark, width=2)
    d.arc([1, y+4, 11, y+12], 180, 360, fill=pri, width=2)
    d.arc([4, y+1, 14, y+9], 270, 120, fill=dark, width=1)
    # Central knot
    d.ellipse([5, y+4, 10, y+9], fill=dark, outline=pri)
    # Dangling ends
    d.line([2, y+2, 1, y], fill=pri, width=1)
    d.line([13, y+6, 14, y+8], fill=dark, width=1)
    d.line([3, y+10, 2, y+13], fill=pri, width=1)

def draw_dependency(d, pri, dark, offset_y=0):
    """Inverted dependency tree - LEGACY final."""
    y = 1 + offset_y
    # Root node at top center
    d.rectangle([6, y, 9, y+2], fill=pri, outline=dark)
    # Branches down to 3 mid nodes
    d.line([7, y+2, 3, y+5], fill=dark, width=1)
    d.line([7, y+2, 7, y+5], fill=dark, width=1)
    d.line([8, y+2, 12, y+5], fill=dark, width=1)
    # Mid nodes
    d.rectangle([1, y+5, 4, y+7], fill=pri, outline=dark)
    d.rectangle([5, y+5, 9, y+7], fill=pri, outline=dark)
    d.rectangle([10, y+5, 13, y+7], fill=pri, outline=dark)
    # Branches to leaf nodes
    d.line([2, y+7, 1, y+10], fill=dark, width=1)
    d.line([3, y+7, 4, y+10], fill=dark, width=1)
    d.line([7, y+7, 6, y+10], fill=dark, width=1)
    d.line([7, y+7, 9, y+10], fill=dark, width=1)
    d.line([11, y+7, 10, y+10], fill=dark, width=1)
    d.line([12, y+7, 13, y+10], fill=dark, width=1)
    # Leaf nodes (small)
    for lx in [0, 3, 5, 8, 9, 12]:
        d.rectangle([lx, y+10, lx+2, y+12], fill=dark, outline=pri)

SPRITES = {
    "println":      (draw_println,      COLORS["debug"]),
    "tracer":       (draw_tracer,       COLORS["debug"]),
    "profiler":     (draw_profiler,     COLORS["debug"]),
    "glitch":       (draw_glitch,       COLORS["chaos"]),
    "gremlin":      (draw_gremlin,      COLORS["chaos"]),
    "pandemonium":  (draw_pandemonium,  COLORS["chaos"]),
    "goto":         (draw_goto,         COLORS["legacy"]),
    "spaghetto":    (draw_spaghetto,    COLORS["legacy"]),
    "dependency":   (draw_dependency,   COLORS["legacy"]),
    "monad":        (draw_monad,        COLORS["wisdom"]),
}

if __name__ == "__main__":
    import os
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
    os.makedirs(out_dir, exist_ok=True)

    for name, (draw_fn, (pri, dark)) in SPRITES.items():
        sheet = make_sheet(draw_fn, pri, dark)
        path = os.path.join(out_dir, f"{name}.png")
        sheet.save(path)
        print(f"  {path} ({sheet.size[0]}x{sheet.size[1]})")

    print("Done!")
