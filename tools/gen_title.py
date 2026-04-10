#!/usr/bin/env python3
"""Generate title logo sprite sheet for CodeCritter title screen.

Output: assets/sprites/title.png — a 2-frame sprite sheet.
Frame 2 is shifted up 1px for idle bounce, matching critter sprite format.

Target: fits in 80-col terminal with margin via half-block rendering.
"""

from PIL import Image, ImageDraw

# Colors
CODE_COL = (80, 200, 255, 255)
CRIT_COL = (200, 240, 255, 255)

# Pixel font: 9px tall, 2px strokes, compact widths.
# Each fn returns (rects, advance_width including 1px trailing gap).

def C():
    return [(2,0,3,2), (0,2,2,5), (2,7,3,2)], 6

def o():
    return [(2,0,2,2), (0,2,2,5), (4,2,2,5), (2,7,2,2)], 6

def d():
    return [(0,0,3,2), (0,2,2,5), (3,2,2,5), (0,7,3,2)], 6

def e():
    return [(0,0,5,2), (0,2,2,1), (0,3,4,2), (0,5,2,2), (0,7,5,2)], 6

def r():
    return [(0,0,4,2), (0,2,2,1), (4,2,2,1), (0,3,4,2), (0,5,2,2), (3,6,2,1), (4,7,2,2)], 6

def i():
    return [(1,0,2,2), (1,3,2,4), (0,7,4,2)], 5

def t():
    return [(0,0,5,2), (1,2,2,7)], 5

def space():
    return [], 3

WORD = [C, o, d, e, space, C, r, i, t, t, e, r]
SPLIT = 5

def measure_word(letters, gap=1):
    return sum(fn()[1] + gap for fn in letters) - gap

def draw_letters(img, letters, sx, sy, colors, split, gap=1):
    d = ImageDraw.Draw(img)
    x = sx
    for idx, fn in enumerate(letters):
        rects, w = fn()
        col = colors[0] if idx < split else colors[1]
        for (rx, ry, rw, rh) in rects:
            d.rectangle([x+rx, sy+ry, x+rx+rw-1, sy+ry+rh-1], fill=col)
        x += w + gap

def generate_title():
    gap = 1
    text_w = measure_word(WORD, gap)

    pad_x = 1
    frame_w = text_w + pad_x * 2
    frame_h = 12  # 9px letters + padding + bounce room, even number

    sheet_w = frame_w * 2
    sheet_h = frame_h

    img = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))

    ty = 2  # room for upward bounce

    draw_letters(img, WORD, pad_x, ty, [CODE_COL, CRIT_COL], SPLIT, gap)
    draw_letters(img, WORD, frame_w + pad_x, ty - 1, [CODE_COL, CRIT_COL], SPLIT, gap)

    return img, frame_w, frame_h

if __name__ == "__main__":
    import os
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
    os.makedirs(out_dir, exist_ok=True)

    img, fw, fh = generate_title()
    path = os.path.join(out_dir, "title.png")
    img.save(path)
    print(f"  {path} ({img.size[0]}x{img.size[1]}, frame {fw}x{fh})")
    print(f"  Terminal display: {fw} cols x {fh//2} rows")
    print("Done!")
