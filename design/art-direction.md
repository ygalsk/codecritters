# Art Direction

## Resolution & Layout

- **Resolution**: 640x360 (nearest-neighbor scaled to terminal dimensions)
- **Tile size**: 16x16px for [[dungeon]]. 40x20 visible tiles.
- **Sprite size**: 32x32px minimum for battle sprites
- **Sprite registry**: `sprite/registry.lua` maps species_id -> art config. New art drops in without code changes.

## Assets in Use

- Pixel UI Pack — HP bars, panel borders, badges, buttons
- Legacy Collection (TinyRPG dungeon) — dungeon tileset (purple/blue)
- Legacy Collection (Grotto FX) — battle effects (electro-shock, fire-ball, energy-smack, etc.)
- 42 Clement Panchout WAV tracks — full music coverage

## Per-Type Battle FX

| Type | Effect | Flavor |
|---|---|---|
| DEBUG | electro-shock | methodical electricity |
| CHAOS | fire-ball | chaotic combustion |
| PATIENCE | energy-smack | controlled force |
| WISDOM | sparkle/magic | abstraction made visible |
| SNARK | slash | cutting critique |
| VIBE | glowy ambient | vibes |
| LEGACY | dust/stone | old, heavy |

## Sprite Animation

### Philosophy

Each [[critters|critter's]] animation should express its programming concept through motion. A Glitch jitters and corrupts. A Mutex pulses with lock-like steadiness. A Hallucination shimmers between forms. Animation is personality — the idle cycle is the critter's body language.

Evolution progression is reflected in animation complexity: base forms are simple and readable, mid evolutions add nuance, final forms have the most expressive and complex cycles.

### Frame Layout

All battle sprites are 32x32px per frame, laid out as horizontal strips in PNG sprite sheets. Frame order: idle -> attack -> hit -> faint.

| Stage | Idle | Attack | Hit | Faint | Total | Sheet |
|---|---|---|---|---|---|---|
| Base form | 4 | 3 | 2 | 2 | 11 | 352x32 |
| Mid evolution | 5 | 3 | 2 | 2 | 12 | 384x32 |
| Final form | 6 | 3 | 2 | 3 | 14 | 448x32 |

### Animation Speeds

- **Idle**: 0.35-0.5s/frame. PATIENCE types slower (0.5s), CHAOS/VIBE faster (0.35s).
- **Attack**: 0.12-0.18s/frame. Snappy, impactful.
- **Hit**: 0.15-0.2s/frame. Quick reaction, returns to idle.
- **Faint**: 0.25-0.35s/frame. Dramatic, holds on last frame.

### Per-Type Animation Identity

**DEBUG** (Println -> Tracer -> Profiler): Terminal/data visualization motifs. Blinking cursors, scanning beams, pulsing bar graphs. Teal/cyan palette.

**CHAOS** (Glitch -> Gremlin -> Pandemonium): Corruption and entropy. Pixel jitter, twitchy bouncing, parts flying apart. Red palette.

**PATIENCE** (Mutex -> Semaphore -> Deadlock): Locks and synchronization. Steady pulses, traffic-light cycling, interlocked strain. Blue palette.

**WISDOM** (Monad -> Functor -> Burrito): Abstraction and transformation. Flowing data particles, mapping arrows, wrapped contents shifting. Purple palette.

**SNARK** (LGTM -> Nitpick -> Bikeshed): Critique and judgment. Sarcastic gestures, twitchy inspection, color-shifting surfaces. Yellow/green palette.

**VIBE** (Copilot -> Autopilot -> Hallucination): Autonomy and drift. Eager bouncing, mechanical rotation, reality-warping shimmer. Green/rainbow palette.

**LEGACY** (Goto -> Spaghetto -> Dependency): Old code and entanglement. Nervous jumping, noodle wiggling, ominous tangled rotation. Brown palette.

## Music

| Context | Track |
|---|---|
| Title | "Cheerful Title Screen" |
| Hub | "Life is full of Joy" |
| Dungeon (floors 1-10) | "Space Horror InGame Music (Exploration)" |
| Dungeon (floors 11-15) | "Space Horror InGame Music (Tense)" |
| Battle (wild) | "16-Bit Beat Em All" |
| Battle (boss) | "Chaotic Boss" |
| Shop | "The Chillout Factory" |
| Victory | "Unsettling victory" |
| Defeat/wipe | "Shadows" |

Music crossfades on scene transitions (300ms fade out, 300ms fade in).
