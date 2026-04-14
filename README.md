# Codecritter

**Catch bugs. Train abstractions. Mass panic the kernel.**

> **Note:** Codecritter is currently being rebuilt on the [Vexel engine](https://github.com/ygalsk/vexel).

Codecritter is a roguelike that runs in your terminal. Every critter is a programming concept — from the humble `Printf` to the terrifying `Kernel Panic`. Build a party, descend through procedurally generated dungeons, and catch the bugs that haunt your codebase.

The twist: your dungeons are themed to whatever you're actually working on. `cd` into a Python project and you'll explore the **Pythonic Caves**. A Rust project spawns the **Rustacean Depths**. And your real coding sessions fuel the game — tool usage earns XP, coding sessions surface rare items, and your favorite critter can live in your terminal statusline.

## Play It

### Download

```sh
curl -fsSL https://raw.githubusercontent.com/ygalsk/codecritters/main/install.sh | sh
```

### Or build from source

```sh
git clone https://github.com/ygalsk/codecritters.git
cd codecritters
zig build run
```

Needs [Zig 0.15.2+](https://ziglang.org/download/). Dependencies are fetched automatically.

**Terminal:** Best in [Ghostty](https://ghostty.org), [Kitty](https://sw.kovidgoyal.net/kitty/), or [WezTerm](https://wezfurlong.org/wezterm/) — you get actual pixel sprites via the Kitty graphics protocol. Any truecolor terminal works too (half-block fallback with 24-bit color). Minimum 80x24.

---

## What You Do

Pick 3 critters from your roster and descend into a dungeon. Each floor is procedurally generated — explore rooms and corridors, fight wild critters, catch new ones. Every 5 floors there's a boss. Between floors, spend your currency at the shop.

Go as deep as you can. When you're ready, extract — you keep everything you caught and earned. If your whole party faints, you wipe. Caught critters are safe, but your party takes scars (permanent stat penalties) and goes on cooldown for 2 runs.

Between runs, manage your roster. Level critters, equip Move Discs to teach new attacks, plan your next party. If you're using Claude Code, your real coding work earns your favorite critter XP and rolls for rare items while you work.

## The World

Your dungeon is themed to your codebase. Codecritter reads your working directory and picks a biome:

| Biome | Triggers | Flavor |
|---|---|---|
| **Pythonic Caves** | `.py` files, `pyproject.toml` | Indented tunnels. Whitespace is load-bearing. |
| **Node Modules Abyss** | `package.json`, `.js/.ts` | It's deeper than you think. |
| **Rustacean Depths** | `Cargo.toml`, `.rs` files | Strict corridors. No unsafe zones. |
| **Gopher Tunnels** | `go.mod`, `.go` files | Clean, concurrent, surprisingly spacious. |
| **C Catacombs** | `.c/.h` files, `Makefile` | Ancient stone. Manual memory management. |
| **Shell Scripts** | `.sh/.bash` files | Pipes everywhere. Glue holds it together. |
| **Generic Dungeon** | Everything else | For the polyglots and the unknown. |

Each biome has its own encounter tables, boss pools, shop items, and color theme.

## The Critters

61 critters across 5 rarity tiers. Three-stage evolution lines, two-stage rares, epics with real drawbacks, and 3 legendaries you won't find in any encounter table.

| Critter | Type | What's its deal |
|---|---|---|
| Segfault -> Kernel Panic | CHAOS | The classic crash cascade. |
| Mutex -> Deadlock | PATIENCE | Locks everything. Including itself. |
| LGTM -> Bikeshed | SNARK | Approves without reading, evolves into arguing about naming. |
| Copilot -> Hallucination | VIBE | Starts helpful, ends confidently wrong. |
| Singleton -> Monolith | LEGACY | There can only be one, and it's unkillable. |
| Rubber Duck | WISDOM | Debuffs enemies by making them explain themselves. |
| 404 | SNARK | Not found. Good luck hitting it. |
| Bobby Tables | CHAOS | SQL injection incarnate. Bypasses defense. |
| COBOL | LEGACY | Ancient. Terrifying stats. Still runs the banks. |
| Load Balancer | PATIENCE | Distributes damage across your party — but can't swap out and hits weaker. |

## The Type Chart

7 types. Each has 2 strengths and 2 weaknesses. Every matchup tells a story.

| | DBG | PAT | CHS | WIS | SNK | VBE | LGC |
|---|---|---|---|---|---|---|---|
| **DEBUG** | -- | . | **W** | L | . | **W** | L |
| **PATIENCE** | . | -- | L | **W** | L | **W** | . |
| **CHAOS** | L | **W** | -- | . | **W** | . | L |
| **WISDOM** | **W** | L | . | -- | L | . | **W** |
| **SNARK** | . | **W** | L | **W** | -- | L | . |
| **VIBE** | L | L | . | . | **W** | -- | **W** |
| **LEGACY** | **W** | . | **W** | L | . | L | -- |

**W** = super effective, **L** = not very effective

- DEBUG beats CHAOS — debugging tames messy code.
- PATIENCE beats WISDOM — patience outlasts overthinking.
- CHAOS beats PATIENCE — chaos overwhelms the patient.
- WISDOM beats LEGACY — wisdom refactors legacy.
- SNARK beats WISDOM — snark deflates the wise.
- VIBE beats LEGACY — vibe coding replaces legacy overnight.
- LEGACY beats DEBUG — legacy resists debugging.

## Your Code Fuels the Game

Codecritter integrates with [Claude Code](https://claude.com/claude-code). When you're coding — running commands, editing files, writing code — those events feed into the game. Your favorite critter earns XP passively, and you get loot rolls for items.

Your party is fully queryable from the CLI:

| Command | What it does |
|---|---|
| `codecritter` | Launch the game |
| `codecritter log-event <type>` | Log a coding event (bash, edit, write) |
| `codecritter set-favorite <id>` | Set which critter earns passive XP |
| `codecritter status` | JSON dump of game state + favorite critter |
| `codecritter roster` | Full roster as JSON |
| `codecritter statusline` | Critter sprite + info for your terminal prompt |

Hooks and skills for Claude Code live in the companion repo: [ygalsk/codecritter](https://github.com/ygalsk/codecritter).

## Controls

| Screen | Keys |
|---|---|
| **Hub** | Arrow keys to navigate, Enter to select |
| **Dungeon** | Arrow keys to move, `M` for quick menu |
| **Battle** | Arrows to pick action, Enter to confirm, Esc to go back |
| **Shop** | Arrows to browse, Enter to buy, `C` continue, `E` extract |
| **Party Select** | Arrows + Enter to toggle, `S` to swap, Tab for items tab, `C` to start |
| **Roster** | Left/Right to browse, `S` to swap positions, `D` to equip discs |
| **Inventory** | Arrows to browse, Enter to use item |

---

## For Developers

### Build and Test

```sh
zig build          # compile
zig build run      # launch the game
zig build test     # run 234 unit tests
```

**Tech:** Zig 0.15.2 + [libvaxis](https://github.com/rockorager/libvaxis) (terminal rendering, Kitty graphics) + [zqlite](https://github.com/karlseguin/zqlite.zig) (SQLite persistence).

### Project Layout

```
src/data/       Species, moves, items, type chart, leveling, equip logic
src/battle/     Battle engine — damage, status, catch, AI (no UI)
src/dungeon/    Dungeon engine — floor gen, biomes, shop, run state (no UI)
src/passive/    Passive XP/item engine (no UI)
src/ui/         All screens — hub, dungeon, battle, shop, roster, etc.
src/db/         SQLite persistence layer
src/main.zig    TUI entry point + CLI subcommands
data/*.json     Species, moves, items, biomes (data-driven, no recompile needed)
assets/         Sprites (32x16 PNG), backgrounds, tilesets, effects
```

Game logic is fully separated from rendering. The battle engine, dungeon engine, and passive engine are testable without any UI.

### Game Data

All game data lives in 4 JSON files in `data/`:

- `species.json` — 61 critter definitions (stats, moves, evolutions)
- `moves.json` — 50 moves (type, power, accuracy, status effects)
- `items.json` — 11 items (catch tools, healing, move discs)
- `biomes.json` — 7 biomes (encounters, bosses, shops, themes)

These are intentionally monolithic per category. At ~52KB total, splitting into per-entity files would add filesystem complexity for no benefit. To add a new critter, move, or item, just add an entry to the relevant JSON file.

### Contributing

Contributions welcome — bug fixes, new critter ideas, balance tweaks, sprites, anything.

**Sprites** are 32x16 PNG sheets with 2 animation frames (left frame = idle, right frame = bounce). See `assets/sprites/` for examples. We need sprites for all 61 critters.

**Adding critters:** Add a species entry to `data/species.json`, add any new moves to `data/moves.json`, create a sprite in `assets/sprites/<id>.png`, and add the species to the appropriate biome encounter table in `data/biomes.json`.

To contribute: fork, branch, PR. For larger changes, open an issue first.

### Design Docs

- [CODECRITTER_DESIGN.md](CODECRITTER_DESIGN.md) — full game design document
- [AGENT_INSTRUCTIONS.md](AGENT_INSTRUCTIONS.md) — implementation roadmap and phase workflow

## License

[MIT](LICENSE)
