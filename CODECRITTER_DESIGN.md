# Codecritter — Game Design Document

## Vision

Codecritter is a Pokemon-style roguelike that lives in your terminal. Every critter is a programming concept, bug, tool, or language spirit. You catch them, build a party, and descend through procedurally generated dungeons themed around programming languages. Between runs, a passive ambient layer rewards real coding work with XP and items — connecting the game to your actual development workflow via Claude Code integration.

**Tech stack:** Zig + libvaxis. SQLite for persistence. CLI subcommands + Claude Code hooks/skills for integration (separate repo).

---

## Core Loop

1. **Manage your roster** — level critters, equip Move Discs, plan your party
2. **Pick 3 critters** for a dungeon run
3. **Descend floor-by-floor** — fight wild critters, catch new ones, buy items at shops
4. **Go deeper each run** — difficulty scales with floor depth, not meta-progression
5. **Extract or wipe** — keep caught critters and loot, or lose your run progress
6. **Code in the real world** — passive layer earns XP and items for your favorite critter between runs

---

## Type System

7 types. Each has 2 strengths, 2 weaknesses, 4 neutral (including self). Balanced pentagonal-plus-two structure.

| | DBG | PAT | CHS | WIS | SNK | VBE | LGC |
|---|---|---|---|---|---|---|---|
| **DEBUG** | — | · | ▲ | ▼ | · | ▲ | ▼ |
| **PATIENCE** | · | — | ▼ | ▲ | ▼ | ▲ | · |
| **CHAOS** | ▼ | ▲ | — | · | ▲ | · | ▼ |
| **WISDOM** | ▲ | ▼ | · | — | ▼ | · | ▲ |
| **SNARK** | · | ▲ | ▼ | ▲ | — | ▼ | · |
| **VIBE** | ▼ | ▼ | · | · | ▲ | — | ▲ |
| **LEGACY** | ▲ | · | ▲ | ▼ | · | ▼ | — |

**Narrative logic (each matchup should tell a one-sentence developer story):**

- DEBUG beats CHAOS ("debugging tames messy code"), VIBE ("vibed code collapses under real debugging")
- PATIENCE beats WISDOM ("patience outlasts overthinking"), VIBE ("patience untangles what was vibed together")
- CHAOS beats PATIENCE ("chaos overwhelms the patient"), SNARK ("chaos breaks the snarky")
- WISDOM beats DEBUGGING ("wisdom prevents bugs before they exist"), LEGACY ("wisdom refactors legacy")
- SNARK beats PATIENCE ("snark demoralizes the patient"), WISDOM ("snark deflates the wise")
- VIBE beats SNARK ("you can't mock someone who doesn't care"), LEGACY ("vibe coding replaces legacy overnight")
- LEGACY beats DEBUGGING ("legacy resists debugging"), CHAOS ("legacy has already survived everything")

**Single-type critters.** No dual-typing on species. Off-type coverage comes from moves.

---

## Combat Stats

3 combat stats + HP:

- **LOGIC** — attack power, how hard moves hit
- **RESOLVE** — defense, damage reduction
- **SPEED** — turn order, dodge chance

The 7 types are identity, not stats. A DEBUG-type critter might have high LOGIC and low SPEED (methodical but slow). A CHAOS-type might have high SPEED and low RESOLVE (fast but fragile).

---

## Damage Formula

```
damage = move_power × type_effectiveness × (attacker_logic / defender_resolve) × variance
```

Type effectiveness: ▲ = 1.5x, · = 1.0x, ▼ = 0.5x.

SPEED determines turn order. Ties broken randomly.

---

## Status Conditions

| Condition | Inflicted by | Effect |
|---|---|---|
| **Blocked** | PATIENCE | Skip next turn (mutex lock) |
| **Deprecated** | LEGACY | Stats decay each turn |
| **Segfaulted** | CHAOS | Random chance to hurt yourself |
| **Linted** | DEBUG | Can't use off-type moves |
| **Tilted** | SNARK | Accuracy drops |
| **In The Zone** | VIBE (self-inflicted) | Power boost, defense drops |
| **Spaghettified** | LEGACY/CHAOS | Moves execute in random order |

---

## Move System

Each critter has **3 move slots:**

- **Slot 1: Signature move** — always the critter's own type, learned at base form
- **Slot 2: Secondary move** — own type or related type, learned at evolution or mid-level
- **Slot 3: Loadout slot** — equip a Move Disc found as dungeon loot

Move Discs are a loot drop category. A CHAOS-type Move Disc on a PATIENCE critter gives coverage it wouldn't normally have. The loadout slot is extensible — a future update could add a second loadout slot without breaking anything.

**Move properties:** name, type, power, accuracy, optional status effect.

---

## Critter Roster

### Rarity Tiers

- **Common** — base forms, found everywhere
- **Uncommon** — mid-evolutions and solid utility picks
- **Rare** — strong standalone or short evo line peaks
- **Epic** — once-per-run-if-lucky, defining drawbacks
- **Legendary** — 3 total, milestone-locked, typed (not above the chart)

### Per-Type Structure

Each type has:
- 1 three-stage evolution line (Common → Common → Uncommon)
- 1 two-stage evolution line (Uncommon → Rare)
- 1 standalone Rare
- 1 standalone Epic with a defining drawback

7 types × 7 critters = 49, plus 9 starters and 3 legendaries = **61 critters total**.

### Starters

Three starters forming a type triangle: LEGACY → DEBUG → CHAOS → LEGACY.

| Stage | LEGACY Starter | DEBUG Starter | CHAOS Starter |
|---|---|---|---|
| Base | **Goto** | **Println** | **Glitch** |
| Mid | **Spaghetto** | **Tracer** | **Gremlin** |
| Final | **Dependency** | **Profiler** | **Pandemonium** |

- **Goto → Spaghetto → Dependency** — a goto tangles into spaghetti code, becomes an unresolvable dependency tree
- **Println → Tracer → Profiler** — the debugging competence arc from print statements to full profiling
- **Glitch → Gremlin → Pandemonium** — a visual glitch becomes mischief becomes systemic chaos

### DEBUG Type

| Name | Stage | Rarity | Concept |
|---|---|---|---|
| Printf | Base | Common | The humble print debugger |
| Fprintf | Mid | Common | Formatted, more precise |
| Logstash | Final | Uncommon | Structured observability |
| Breakpoint | Base | Uncommon | Stops everything, inspects |
| Watchpoint | Evolved | Rare | Tracks state changes passively |
| Heisenbug | Standalone | Rare | Disappears when observed, high evasion |
| Valgrind | Standalone | Epic | Devastating vs CHAOS, slow — **always acts last** |

### CHAOS Type

| Name | Stage | Rarity | Concept |
|---|---|---|---|
| Segfault | Base | Common | The classic crash |
| Stack Overflow | Mid | Common | Overflows into everything |
| Kernel Panic | Final | Uncommon | System-level catastrophe |
| Fuzzer | Base | Uncommon | Throws random input, sometimes finds gold |
| Chaos Monkey | Evolved | Rare | Netflix-inspired, kills processes for fun |
| Bobby Tables | Standalone | Rare | SQL injection incarnate, bypasses defense |
| Race Condition | Standalone | Epic | **Sometimes acts twice, sometimes zero times** — genuinely random turn count |

### PATIENCE Type

| Name | Stage | Rarity | Concept |
|---|---|---|---|
| Mutex | Base | Common | Blocks one thing at a time |
| Semaphore | Mid | Common | Blocks with counting precision |
| Deadlock | Final | Uncommon | Locks everything, including itself |
| Queue | Base | Uncommon | FIFO, waits its turn |
| Priority Queue | Evolved | Rare | Knows who's important |
| Cron | Standalone | Rare | Scheduled strikes, delayed massive damage |
| Load Balancer | Standalone | Epic | Distributes incoming damage across party — **can't swap out, own attacks weakened** |

### WISDOM Type

| Name | Stage | Rarity | Concept |
|---|---|---|---|
| Monad | Base | Common | Nobody understands it at first |
| Functor | Mid | Common | Maps over things, growing in abstraction |
| Burrito | Final | Uncommon | The meme that transcended |
| Hashmap | Base | Uncommon | O(1) lookup, instant knowledge |
| B-Tree | Evolved | Rare | Balanced, deep, structured |
| Rubber Duck | Standalone | Rare | Debuffs enemies by making them explain themselves |
| Turing Machine | Standalone | Epic | Can learn any move from any type — **takes 2 turns to execute each move** |

### SNARK Type

| Name | Stage | Rarity | Concept |
|---|---|---|---|
| LGTM | Base | Common | Approves without reading |
| Nitpick | Mid | Common | Finds fault in everything |
| Bikeshed | Final | Uncommon | Derails progress arguing about trivial things |
| TODO | Base | Uncommon | Empty promise, placeholder attack |
| FIXME | Evolved | Rare | Urgent, sharper, angrier TODO |
| 404 | Standalone | Rare | Not found, impossible to hit |
| Regex | Standalone | Epic | "Now you have two problems" — **50% chance to confuse itself instead of the enemy** |

### VIBE Type

| Name | Stage | Rarity | Concept |
|---|---|---|---|
| Copilot | Base | Common | Suggests things, sometimes right |
| Autopilot | Mid | Common | Fully autonomous, accuracy optional |
| Hallucination | Final | Uncommon | Confidently wrong, high attack, low accuracy |
| README | Base | Uncommon | Looks complete from outside, hollow inside |
| No Tests | Evolved | Rare | "It works on my machine" glass cannon |
| YOLO | Standalone | Rare | One massive hit, git push --force energy |
| Prompt Engineer | Standalone | Epic | Buffs allies massively — **zero attack, cannot deal damage alone** |

### LEGACY Type

| Name | Stage | Rarity | Concept |
|---|---|---|---|
| Singleton | Base | Common | There can only be one |
| God Object | Mid | Common | Does everything, badly |
| Monolith | Final | Uncommon | Unkillable, eternal |
| Makefile | Base | Uncommon | Ancient build ritual, tabs not spaces |
| Jenkins | Evolved | Rare | The CI that refuses to die |
| COBOL | Standalone | Rare | Runs the banks, terrifying stats |
| Mainframe | Standalone | Epic | Highest base HP in the game — **cannot dodge, cannot be healed** |

### Legendaries

| Name | Type | Concept | Signature Mechanic |
|---|---|---|---|
| **Root** | LEGACY | The superuser | Signature move ignores type effectiveness |
| **Zero Day** | CHAOS | Unknown exploit | Signature move always has priority (acts first) |
| **Linus** | WISDOM | The kernel creator | Signature move "Revert" undoes the opponent's last action |

---

## Evolution

**Trigger: level threshold.** Simple, predictable. Each species has an evolution level defined in data.

Critters evolve through 3 stages (base → mid → final) for main lines, or 2 stages for shorter lines. Rares and Epics do not evolve.

---

## Party & Roster

- **Persistent roster** across sessions — you keep everything you catch
- **Pick 3** critters per dungeon run
- **Swap in battle** — swapping costs your turn

### Death & Recovery

When a critter faints in a dungeon:

- **Cooldown** — critter is unavailable for a real-world time period, healed while you code (passive layer synergy)
- **Scarring** — permanent -1 to a random stat. Gives critters history. A veteran with 3 scars tells a story.

This combination forces roster rotation (you need a deep bench) and creates attachment (your scarred veteran matters more, not less).

---

## Catch System

Resource-based catching. Weaken the critter, then use a catch tool.

### Catch Tools (5 tiers)

| Tool | Tier | Base Rate | Type Interaction |
|---|---|---|---|
| **Print Statement** | 1 | Low | None — always available, cheap |
| **Breakpoint** | 2 | Medium | Bonus vs DEBUG types |
| **Try-Catch** | 3 | Medium-High | If it fails, the critter gets a free attack |
| **Linter** | 4 | High | Bonus vs CHAOS, penalty vs WISDOM |
| **Formal Proof** | 5 | Near-guaranteed | Useless against CHAOS (can't formally prove chaos) |

### Catch Rate Formula

```
catch_chance = tool_base_rate
             + type_bonus(tool, critter_type)
             - (critter_current_hp / critter_max_hp) * difficulty_modifier
             - rarity_penalty
```

Weaken first (HP ratio matters), tool choice matters, rare critters are harder.

### Catch Tool Sources

- **Shop** — reliable, primary source
- **Dungeon drops** — lucky finds, creates excitement
- **Passive layer** — ambient critter occasionally finds one while you code

No crafting.

---

## Dungeon Structure

### Run Flow

1. Pick 3 critters from roster
2. Enter a biome (auto-detected or manually selected if unlocked)
3. Descend floor-by-floor — small procedural grid per floor
4. Encounters on tiles — step on a critter tile, battle starts
5. Between floors — shop, heal, swap party order
6. Boss every 5 floors — themed to the biome
7. Run ends on wipe or voluntary extraction. Caught critters and loot persist.

### Difficulty

Floor 1 is always the same difficulty. You're trying to get deeper each run. No meta-scaling that makes early floors easier over time. Your critters get stronger and your roster gets wider — that's your only progression lever.

---

## Biomes

Auto-detected from the working directory's programming language. Unlockable for manual selection after a condition is met (e.g., first clear, passive layer detection over time).

Each biome defines:
- **Encounter table** — which critters spawn and at what rarity
- **Boss pool** — biome-specific bosses every 5 floors
- **Shop inventory bias** — certain tool types and Move Discs are more common
- **Floor aesthetics** — visual theme, flavor text, tile set

### Starting Biomes

| Biome | Detected By | Dominant Types | Flavor |
|---|---|---|---|
| **Pythonic Caves** | .py files | VIBE, WISDOM | Indented tunnels, whitespace matters |
| **Rustacean Depths** | .rs, Cargo.toml | DEBUG, PATIENCE | Strict corridors, no unsafe zones |
| **Node Modules Abyss** | package.json | CHAOS, VIBE | Endlessly deep, folders within folders |
| **Gopher Tunnels** | .go, go.mod | PATIENCE, WISDOM | Clean, boring, efficient |
| **C Catacombs** | .c, .h files | LEGACY, CHAOS | Ancient stone, memory-unsafe traps |
| **Shell Scripts** | .sh, .bash | SNARK, CHAOS | Pipes everywhere, everything is text |
| **Generic Dungeon** | Fallback | All types equal | Default theme |

More biomes can be added as content updates.

---

## Claude Code Integration

The game binary (this repo, `ygalsk/codecritters`) exposes CLI subcommands for integration. The Claude Code side — hooks, skills, and the buddy companion persona — lives in a separate repo (`ygalsk/codecritter`).

### Passive Ambient Layer

Your favorite critter sits in the background while you code. It earns passive XP and occasionally finds items. This is fueled by Claude Code tool-use events (Bash, Edit, Write, etc.).

**Implementation:** Claude Code hooks call `codecritter log-event <type>` on tool use, logging events to SQLite. On game launch, the backlog is reconciled. "While you were coding, Segfault found a Mutex Key!" No daemon, no MCP server — just CLI calls and batch processing.

### CLI Subcommands (this repo)

- `codecritter log-event <type>` — log a coding event (called by Claude Code hooks)
- `codecritter set-favorite <id>` — set which critter earns passive XP
- `codecritter status` — output party status as JSON (consumed by Claude Code skill)
- `codecritter statusline` — output compact one-liner for terminal prompt / editor statusline

### Claude Code Integration (separate repo: `ygalsk/codecritter`)

- **Hooks** — shell commands that fire on tool use, calling `codecritter log-event`
- **`/critter` skill** — check party status, set favorite, view loot found
- **Buddy companion** — critter personality that occasionally comments on your work
- **Statusline config** — show your active critter in your terminal prompt

### Coding Event Rewards

- Tool use (Bash, Edit, Write) → passive XP ticks
- Extended coding sessions → item finds
- Future hooks: CI pass/fail, git commits, PR merges could all feed into the game economy

---

## Rendering

### Sprites

Half-block pixel art (▄/▀) with 24-bit truecolor as the baseline. A 16×16 sprite renders as an 8-row terminal block using foreground/background color pairs.

**Kitty graphics protocol** support for terminals that have it (Ghostty, Kitty, WezTerm) — actual PNG rendering in-cell. Capability detected on startup, automatic fallback to half-blocks.

### Battle Layout

Two sprites facing off — enemy top-right, player bottom-left. HP bars, type indicators, and a 4-option action menu (Attack, Catch, Swap, Item).

### Idle Animation

Minimum 2-frame bounce per critter (shift sprite up 1 row, shift back). Sprite format must support multiple frames.

---

## Economy

### Currency

Single currency earned from battles. Spent at between-floor shops.

### Item Categories

- **Catch tools** — 5 tiers (see Catch System)
- **Healing items** — restore HP during runs
- **Move Discs** — equip in the loadout slot, found as drops and in shops
- **Hold items** — future extensibility slot

### Sources

- Shop (reliable, primary)
- Dungeon drops (excitement)
- Passive layer (between-run bonus)

---

## Open Design Questions (Decide During Implementation)

- Exact stat numbers, level curves, XP tables
- Evolution level thresholds per species
- Specific move names and stats for all 61 critters
- Catch rate percentages per tool tier
- Cooldown duration for fainted critters
- Shop pricing
- Floor grid size and generation algorithm
- Boss mechanics per biome
- Specific conditions for biome manual unlock
- Legendary acquisition conditions
- Passive layer tick rates and item find probabilities
