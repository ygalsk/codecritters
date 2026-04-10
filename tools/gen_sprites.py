#!/usr/bin/env python3
"""Generate 16x16 sprite sheets (2 frames, 32x16) for test critters."""

from PIL import Image, ImageDraw

FRAME_W, FRAME_H = 16, 16
SHEET_W = FRAME_W * 2  # 2 frames side by side

# Type colors: (primary, dark outline)
COLORS = {
    "debug":    ((0, 206, 209),   (0, 140, 142)),
    "chaos":    ((255, 68, 68),   (178, 34, 34)),
    "legacy":   ((139, 105, 20),  (100, 70, 10)),
    "wisdom":   ((155, 89, 182),  (110, 60, 140)),
    "patience": ((70, 130, 180),  (40, 90, 130)),
    "snark":    ((255, 165, 0),   (200, 120, 0)),
    "vibe":     ((50, 205, 50),   (30, 140, 30)),
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

def draw_copilot(d, pri, dark, offset_y=0):
    """Robot assistant head - VIBE type."""
    y = 2 + offset_y
    # Antenna
    d.rectangle([7, y, 8, y+2], fill=dark)
    d.ellipse([6, y-1, 9, y+1], fill=pri)
    # Head
    d.rectangle([3, y+2, 12, y+9], fill=dark, outline=pri)
    # Eyes (friendly)
    d.ellipse([4, y+4, 6, y+6], fill=(0, 255, 0, 255))
    d.ellipse([9, y+4, 11, y+6], fill=(0, 255, 0, 255))
    # Smile
    d.arc([5, y+6, 10, y+9], 0, 180, fill=pri, width=1)
    # Body
    d.rectangle([5, y+9, 10, y+12], fill=dark)

def draw_segfault(d, pri, dark, offset_y=0):
    """Cracked memory address - CHAOS type."""
    y = 1 + offset_y
    # Memory block
    d.rectangle([2, y+1, 13, y+10], fill=dark, outline=pri)
    # Crack through the middle
    d.line([7, y+1, 5, y+4], fill=(255, 255, 0, 255), width=1)
    d.line([5, y+4, 9, y+6], fill=(255, 255, 0, 255), width=1)
    d.line([9, y+6, 6, y+10], fill=(255, 255, 0, 255), width=1)
    # "0x" text hint
    d.rectangle([3, y+3, 4, y+4], fill=pri)
    d.rectangle([10, y+7, 12, y+8], fill=pri)
    # Scattered bits
    d.rectangle([1, y+11, 3, y+12], fill=pri)
    d.rectangle([11, y+11, 13, y+12], fill=pri)

def draw_mutex(d, pri, dark, offset_y=0):
    """Padlock - PATIENCE type."""
    y = 1 + offset_y
    # Lock shackle (arc)
    d.arc([4, y, 11, y+6], 180, 360, fill=pri, width=2)
    # Lock body
    d.rectangle([3, y+5, 12, y+12], fill=dark, outline=pri)
    # Keyhole
    d.ellipse([6, y+7, 9, y+9], fill=pri)
    d.rectangle([7, y+9, 8, y+11], fill=pri)

def draw_lgtm(d, pri, dark, offset_y=0):
    """Thumbs up with checkmark - SNARK type."""
    y = 1 + offset_y
    # Thumb
    d.ellipse([5, y, 10, y+5], fill=dark, outline=pri)
    # Hand
    d.rectangle([4, y+5, 11, y+9], fill=dark, outline=pri)
    # Checkmark
    d.line([6, y+7, 7, y+8], fill=(0, 255, 0, 255), width=1)
    d.line([7, y+8, 10, y+5], fill=(0, 255, 0, 255), width=1)
    # Fingers
    d.rectangle([3, y+9, 5, y+11], fill=dark)
    d.rectangle([6, y+9, 8, y+11], fill=dark)
    d.rectangle([9, y+9, 11, y+11], fill=dark)

def draw_singleton(d, pri, dark, offset_y=0):
    """Single dot in a box (one instance) - LEGACY type."""
    y = 1 + offset_y
    # Outer box
    d.rectangle([2, y, 13, y+12], fill=None, outline=pri, width=1)
    # "1" text
    d.rectangle([7, y+2, 8, y+3], fill=dark)
    d.rectangle([6, y+3, 8, y+10], fill=dark)
    d.rectangle([5, y+10, 10, y+11], fill=dark)
    # Lock icon (small)
    d.rectangle([10, y+1, 12, y+3], fill=pri)

def draw_printf(d, pri, dark, offset_y=0):
    """Printf statement - DEBUG type base."""
    y = 2 + offset_y
    # Terminal shape
    d.rectangle([2, y, 13, y+8], fill=(0, 30, 30, 255), outline=pri)
    # "%s" text
    d.rectangle([3, y+2, 4, y+3], fill=(255, 200, 0, 255))  # %
    d.rectangle([5, y+2, 6, y+3], fill=pri)                   # s
    # Cursor blink
    d.rectangle([8, y+4, 9, y+5], fill=pri)
    # Base
    d.rectangle([5, y+9, 10, y+10], fill=dark)

def draw_fprintf(d, pri, dark, offset_y=0):
    """Formatted output with file - DEBUG type mid."""
    y = 1 + offset_y
    # File icon
    d.rectangle([1, y, 7, y+11], fill=dark, outline=pri)
    # Folded corner
    d.polygon([(5, y), (7, y), (7, y+2), (5, y+2)], fill=pri)
    # Lines of text
    d.rectangle([2, y+3, 6, y+4], fill=pri)
    d.rectangle([2, y+5, 5, y+6], fill=pri)
    d.rectangle([2, y+7, 6, y+8], fill=pri)
    # Arrow to output
    d.line([8, y+5, 10, y+5], fill=pri, width=1)
    d.polygon([(10, y+3), (13, y+5), (10, y+7)], fill=pri)

def draw_logstash(d, pri, dark, offset_y=0):
    """Structured log pipeline - DEBUG type final."""
    y = 1 + offset_y
    # Pipeline input
    d.rectangle([1, y+1, 4, y+4], fill=dark, outline=pri)
    d.rectangle([1, y+5, 4, y+8], fill=dark, outline=pri)
    d.rectangle([1, y+9, 4, y+12], fill=dark, outline=pri)
    # Central processor
    d.line([4, y+3, 6, y+6], fill=pri, width=1)
    d.line([4, y+7, 6, y+6], fill=pri, width=1)
    d.line([4, y+11, 6, y+6], fill=pri, width=1)
    d.ellipse([5, y+4, 10, y+9], fill=pri, outline=dark)
    # Output
    d.line([10, y+6, 13, y+6], fill=pri, width=1)
    d.polygon([(12, y+4), (14, y+6), (12, y+8)], fill=(0, 255, 200, 255))

def draw_stack_overflow(d, pri, dark, offset_y=0):
    """Overflowing stack frames - CHAOS type mid."""
    y = 1 + offset_y
    # Stack frames piling up
    d.rectangle([3, y+9, 12, y+11], fill=dark, outline=pri)
    d.rectangle([3, y+7, 12, y+9], fill=pri, outline=dark)
    d.rectangle([3, y+5, 12, y+7], fill=dark, outline=pri)
    d.rectangle([3, y+3, 12, y+5], fill=pri, outline=dark)
    # Overflowing frames tilted
    d.rectangle([2, y+1, 11, y+3], fill=(255, 200, 0, 200), outline=pri)
    d.rectangle([1, y-1, 10, y+1], fill=pri, outline=dark)
    # Danger marks
    d.rectangle([13, y+2, 14, y+3], fill=(255, 255, 0, 255))
    d.rectangle([13, y+5, 14, y+6], fill=(255, 255, 0, 255))

def draw_kernel_panic_critter(d, pri, dark, offset_y=0):
    """Skull on screen (kernel panic) - CHAOS type final."""
    y = 1 + offset_y
    # Monitor
    d.rectangle([1, y, 14, y+10], fill=(40, 0, 0, 255), outline=pri)
    # Skull
    d.ellipse([4, y+1, 11, y+7], fill=(255, 255, 255, 255))
    # Eyes
    d.rectangle([5, y+3, 7, y+5], fill=(0, 0, 0, 255))
    d.rectangle([8, y+3, 10, y+5], fill=(0, 0, 0, 255))
    # Teeth
    d.rectangle([5, y+6, 6, y+7], fill=(0, 0, 0, 255))
    d.rectangle([7, y+6, 8, y+7], fill=(0, 0, 0, 255))
    d.rectangle([9, y+6, 10, y+7], fill=(0, 0, 0, 255))
    # Stand
    d.rectangle([5, y+11, 10, y+12], fill=dark)

def draw_god_object(d, pri, dark, offset_y=0):
    """Bloated class with too many connections - LEGACY type mid."""
    y = 1 + offset_y
    # Large central blob
    d.ellipse([3, y+2, 12, y+11], fill=dark, outline=pri, width=2)
    # Tentacle-like connections
    d.line([3, y+4, 0, y+1], fill=pri, width=1)
    d.line([12, y+4, 15, y+1], fill=pri, width=1)
    d.line([3, y+9, 0, y+12], fill=pri, width=1)
    d.line([12, y+9, 15, y+12], fill=pri, width=1)
    # Crown (god)
    d.polygon([(5, y+2), (4, y), (6, y+1), (7, y-1), (9, y+1), (11, y), (10, y+2)], fill=(255, 215, 0, 255))
    # Inner chaos dots
    d.rectangle([6, y+5, 7, y+6], fill=pri)
    d.rectangle([8, y+7, 9, y+8], fill=pri)
    d.rectangle([5, y+8, 6, y+9], fill=pri)

def draw_monolith(d, pri, dark, offset_y=0):
    """Massive immovable block - LEGACY type final."""
    y = 0 + offset_y
    # Huge rectangle filling most of the frame
    d.rectangle([2, y+1, 13, y+14], fill=dark, outline=pri, width=2)
    # Horizontal division lines (layers of legacy)
    d.line([3, y+4, 12, y+4], fill=pri, width=1)
    d.line([3, y+7, 12, y+7], fill=pri, width=1)
    d.line([3, y+10, 12, y+10], fill=pri, width=1)
    # Small details in each section
    d.rectangle([4, y+2, 6, y+3], fill=pri)
    d.rectangle([8, y+5, 11, y+6], fill=pri)
    d.rectangle([4, y+8, 7, y+9], fill=pri)
    d.rectangle([5, y+11, 10, y+12], fill=pri)

def draw_semaphore(d, pri, dark, offset_y=0):
    """Traffic signal (semaphore) - PATIENCE type mid."""
    y = 1 + offset_y
    # Pole
    d.rectangle([7, y+8, 8, y+13], fill=dark)
    # Signal box
    d.rectangle([3, y, 12, y+9], fill=dark, outline=pri)
    # Three lights
    d.ellipse([5, y+1, 10, y+3], fill=(255, 0, 0, 200))    # red
    d.ellipse([5, y+3, 10, y+5], fill=(255, 200, 0, 200))   # yellow
    d.ellipse([5, y+6, 10, y+8], fill=(0, 255, 0, 200))     # green

def draw_deadlock(d, pri, dark, offset_y=0):
    """Two interlocked arrows that can't proceed - PATIENCE type final."""
    y = 1 + offset_y
    # Two circular arrows locked together
    d.arc([1, y, 9, y+8], 0, 270, fill=pri, width=2)
    d.polygon([(1, y+3), (3, y+1), (3, y+5)], fill=pri)  # arrowhead
    d.arc([6, y+5, 14, y+13], 180, 90, fill=dark, width=2)
    d.polygon([(14, y+9), (12, y+7), (12, y+11)], fill=dark)  # arrowhead
    # Lock symbol in center
    d.rectangle([6, y+5, 9, y+8], fill=pri, outline=dark)
    # X marks deadlock
    d.line([6, y+5, 9, y+8], fill=(255, 0, 0, 255), width=1)
    d.line([9, y+5, 6, y+8], fill=(255, 0, 0, 255), width=1)

def draw_functor(d, pri, dark, offset_y=0):
    """Box with an arrow (mapping) - WISDOM type mid."""
    y = 1 + offset_y
    # Input box
    d.rectangle([1, y+2, 5, y+10], fill=dark, outline=pri)
    # Content "a"
    d.rectangle([2, y+5, 4, y+7], fill=pri)
    # Arrow (fmap)
    d.line([5, y+6, 10, y+6], fill=(200, 200, 255, 255), width=1)
    d.polygon([(9, y+4), (12, y+6), (9, y+8)], fill=pri)
    # Output box
    d.rectangle([10, y+2, 14, y+10], fill=dark, outline=pri)
    # Content "b"
    d.rectangle([11, y+5, 13, y+7], fill=(200, 150, 255, 255))

def draw_burrito(d, pri, dark, offset_y=0):
    """Wrapped burrito (monad meme) - WISDOM type final."""
    y = 2 + offset_y
    # Outer tortilla wrap
    d.ellipse([1, y, 14, y+10], fill=dark, outline=pri, width=2)
    # Inner filling layers
    d.ellipse([3, y+2, 12, y+8], fill=(180, 120, 200, 200))
    # Lambda in center
    d.line([6, y+3, 8, y+6], fill=(255, 255, 255, 255), width=1)
    d.line([8, y+6, 10, y+3], fill=(255, 255, 255, 255), width=1)
    # Wrap fold at bottom
    d.arc([3, y+7, 12, y+12], 0, 180, fill=pri, width=2)

def draw_nitpick(d, pri, dark, offset_y=0):
    """Magnifying glass with red circle - SNARK type mid."""
    y = 1 + offset_y
    # Magnifying glass
    d.ellipse([2, y, 10, y+8], fill=None, outline=pri, width=2)
    # Red circle on found issue
    d.ellipse([4, y+2, 8, y+6], fill=(255, 0, 0, 150))
    # Exclamation mark
    d.rectangle([5, y+3, 6, y+4], fill=(255, 255, 255, 255))
    d.rectangle([5, y+5, 6, y+5], fill=(255, 255, 255, 255))
    # Handle
    d.line([9, y+7, 13, y+11], fill=dark, width=2)

def draw_bikeshed(d, pri, dark, offset_y=0):
    """Colorful shed/house - SNARK type final."""
    y = 1 + offset_y
    # Roof (triangle)
    d.polygon([(1, y+5), (7, y), (14, y+5)], fill=pri, outline=dark)
    # Body of shed
    d.rectangle([2, y+5, 13, y+12], fill=dark, outline=pri)
    # Door
    d.rectangle([6, y+7, 9, y+12], fill=pri)
    # Window
    d.rectangle([3, y+6, 5, y+8], fill=(200, 200, 255, 200))
    d.rectangle([10, y+6, 12, y+8], fill=(200, 200, 255, 200))
    # Paint drips (bikeshedding = arguing about colors)
    d.rectangle([3, y+9, 4, y+11], fill=(255, 100, 100, 200))
    d.rectangle([10, y+9, 11, y+11], fill=(100, 100, 255, 200))

def draw_autopilot(d, pri, dark, offset_y=0):
    """Robot with wings/jet - VIBE type mid."""
    y = 1 + offset_y
    # Head
    d.rectangle([5, y, 10, y+4], fill=dark, outline=pri)
    # Eyes (auto mode)
    d.rectangle([6, y+1, 7, y+2], fill=(0, 255, 0, 255))
    d.rectangle([8, y+1, 9, y+2], fill=(0, 255, 0, 255))
    # Body
    d.rectangle([4, y+4, 11, y+9], fill=dark, outline=pri)
    # Wings
    d.polygon([(4, y+5), (1, y+4), (1, y+7)], fill=pri)
    d.polygon([(11, y+5), (14, y+4), (14, y+7)], fill=pri)
    # Jet trail
    d.rectangle([6, y+9, 9, y+10], fill=(255, 150, 0, 200))
    d.rectangle([7, y+10, 8, y+12], fill=(255, 200, 0, 150))

def draw_hallucination(d, pri, dark, offset_y=0):
    """Swirly distorted face - VIBE type final."""
    y = 1 + offset_y
    # Wavy outline head
    d.ellipse([2, y, 13, y+11], fill=dark, outline=pri, width=2)
    # Spiral eyes
    d.arc([3, y+2, 7, y+6], 0, 300, fill=(0, 255, 0, 255), width=1)
    d.arc([4, y+3, 6, y+5], 0, 200, fill=(0, 255, 0, 255), width=1)
    d.arc([8, y+2, 12, y+6], 0, 300, fill=(0, 255, 0, 255), width=1)
    d.arc([9, y+3, 11, y+5], 0, 200, fill=(0, 255, 0, 255), width=1)
    # Wobbly smile
    d.arc([4, y+6, 11, y+11], 0, 180, fill=pri, width=1)
    # Sparkles/hallucination particles
    d.rectangle([1, y+1, 2, y+2], fill=(255, 255, 100, 200))
    d.rectangle([13, y+3, 14, y+4], fill=(100, 255, 255, 200))
    d.rectangle([0, y+8, 1, y+9], fill=(255, 100, 255, 200))

SPRITES = {
    # DEBUG type
    "println":               (draw_println,               COLORS["debug"]),
    "tracer":                (draw_tracer,                COLORS["debug"]),
    "profiler":              (draw_profiler,              COLORS["debug"]),
    "printf":                (draw_printf,                COLORS["debug"]),
    "fprintf":               (draw_fprintf,               COLORS["debug"]),
    "logstash":              (draw_logstash,              COLORS["debug"]),
    # CHAOS type
    "glitch":                (draw_glitch,                COLORS["chaos"]),
    "gremlin":               (draw_gremlin,               COLORS["chaos"]),
    "pandemonium":           (draw_pandemonium,           COLORS["chaos"]),
    "segfault":              (draw_segfault,              COLORS["chaos"]),
    "stack_overflow":        (draw_stack_overflow,        COLORS["chaos"]),
    "kernel_panic_critter":  (draw_kernel_panic_critter,  COLORS["chaos"]),
    # LEGACY type
    "goto":                  (draw_goto,                  COLORS["legacy"]),
    "spaghetto":             (draw_spaghetto,             COLORS["legacy"]),
    "dependency":            (draw_dependency,            COLORS["legacy"]),
    "singleton":             (draw_singleton,             COLORS["legacy"]),
    "god_object":            (draw_god_object,            COLORS["legacy"]),
    "monolith":              (draw_monolith,              COLORS["legacy"]),
    # WISDOM type
    "monad":                 (draw_monad,                 COLORS["wisdom"]),
    "functor":               (draw_functor,               COLORS["wisdom"]),
    "burrito":               (draw_burrito,               COLORS["wisdom"]),
    # PATIENCE type
    "mutex":                 (draw_mutex,                 COLORS["patience"]),
    "semaphore":             (draw_semaphore,             COLORS["patience"]),
    "deadlock":              (draw_deadlock,              COLORS["patience"]),
    # SNARK type
    "lgtm":                  (draw_lgtm,                  COLORS["snark"]),
    "nitpick":               (draw_nitpick,               COLORS["snark"]),
    "bikeshed":              (draw_bikeshed,              COLORS["snark"]),
    # VIBE type
    "copilot":               (draw_copilot,               COLORS["vibe"]),
    "autopilot":             (draw_autopilot,             COLORS["vibe"]),
    "hallucination":         (draw_hallucination,         COLORS["vibe"]),
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
