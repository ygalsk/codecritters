# Codecritter — Game Design Document (Vexel Port)

> A Pokemon-style roguelike for the terminal. Every critter is a programming concept.
> Built on Vexel (Zig + Lua). 640×360 via kitty graphics protocol.

---

## Vision

Codecritter is a Pokemon-style roguelike that lives in your terminal. Every critter is a programming concept — a bug, a tool, a language spirit, a design pattern. You catch them, build a party, and descend through procedurally generated dungeons themed around programming languages.

This is not a tutorial. It does not hold your hand. But it will teach you through play: type matchups reveal themselves through losses, status effects make sense the moment they happen to you, and the first time Load Balancer saves your Println from a KO, you understand why the Reviewer archetype exists.

Think LÖVE, but for the terminal. Think Pokemon Gold, but your party knows what a mutex is.

---

## Core Loop

1. **Hub** — manage your roster, equip move discs and hold items, plan your party
2. **Party select** — pick 3 (or 4 after unlock) critters for the run
3. **Dungeon** — descend floor-by-floor through procedurally generated rooms
4. **Encounters** — walk into enemies (no escape). Fight, catch, or conserve.
5. **Boss** — every 5 floors: a boss team. Defeats it means a shop and full party heal.
6. **Extract or push** — keep going for better loot and XP, or bank what you have
7. **Run over** — catches kept, scars applied, cooldowns start. Back to the hub.

The loop is short enough for a single session (15 floors ≈ 45–60 min). The meta is long enough for dozens.

---

## Critter Biology

### Stats (4)
- **HP** — hit points. Reaches zero = fainted. Scar applied. 1-run cooldown begins.
- **Logic** — attack power. How hard moves hit.
- **Resolve** — defense. Damage reduction.
- **Speed** — turn order. Higher Speed acts first. Ties broken randomly.

### Stat Growth
`stat_at_level = base_stat × (1 + level / 50)`

Level 5 = +10% over base. Level 25 = +50%. Level 50 = +100% (doubled).

### Critter Loadout (4 slots)
```
[Signature move] [Secondary move] [Move Disc] [Hold Item]
```
- **Signature move** — always own type, learned at base form. Cannot be changed.
- **Secondary move** — own or related type, learned at evolution or mid-level. Cannot be changed.
- **Move Disc** — equippable off-type coverage move. Swappable at hub between runs.
- **Hold item** — equippable passive/active modifier. Persists on critter across runs.

---

## The 7 Types

Types determine: what matchups you have, what status effects your moves inflict, and your critter's thematic identity.

| Type | Theme | Strong vs | Weak vs | Inflicts |
|---|---|---|---|---|
| **DEBUG** | Methodical analysis | CHAOS, VIBE | WISDOM, LEGACY | Linted |
| **CHAOS** | Entropy, crashes, glitches | PATIENCE, SNARK, LEGACY | DEBUG, WISDOM | Segfaulted |
| **PATIENCE** | Concurrency, waiting | CHAOS, WISDOM | VIBE, SNARK | Blocked |
| **WISDOM** | Abstraction, theory | DEBUG, PATIENCE | LEGACY, SNARK | Enlightened |
| **SNARK** | Critique, mockery | PATIENCE, WISDOM | CHAOS, VIBE | Tilted |
| **VIBE** | Vibes, velocity, autonomy | SNARK, LEGACY | DEBUG, PATIENCE | Hallucinating |
| **LEGACY** | Old code, persistence | DEBUG, WISDOM | CHAOS, VIBE | Deprecated |

Type effectiveness: strong = 1.5×, neutral = 1.0×, weak = 0.5×.

**Starter triangle:** Glitch (CHAOS) > Goto (LEGACY) > Println (DEBUG) > Glitch

---

## The 7 Archetypes

Archetypes are orthogonal to type. **Type = matchups and flavor. Archetype = combat role.**
Every type contains all 7 archetypes. A DEBUG wall plays differently from a CHAOS wall, but both are walls.

| Archetype | Dev Name | Stats | Win Condition |
|---|---|---|---|
| Striker | **Deployer** | High Logic, Med Speed, Med bulk | Consistent 2–3 hit KOs |
| Speedster | **Hotfix** | High Speed, Med Logic, Low Resolve | Move first, set up before opponent reacts |
| Bruiser | **Monolith** | High Logic, Low Speed, Med HP | Massive delayed hits |
| Sentinel | **Uptime** | High Resolve+HP, Low Logic | Outlast through attrition and status |
| Disruptor | **Regression** | Mixed, status-heavy moveset | Control win through status application |
| Support | **Reviewer** | High Resolve+Speed, Very Low Logic | Enable carries; elevated bench assist |
| Wild Card | **Zero Day** | Extreme one stat, severe weakness | Unique mechanic (always the Epic slot) |

Archetype displayed in the codex entry. Tooltips clarify the combat role.

---

## The 9 Status Effects

| Status | Inflicted by | Duration | Effect |
|---|---|---|---|
| **Blocked** | PATIENCE | 1 turn | Skip next turn entirely |
| **Linted** | DEBUG | 2 turns | Can only use own-type moves |
| **Spaghettified** | CHAOS/LEGACY | 2 turns | Moves execute in random order |
| **Enlightened** | WISDOM | 2 turns | Random move selection (confused by own clarity) |
| **Deprecated** | LEGACY | 3 turns | -5% to all stats per turn (stacks) |
| **Segfaulted** | CHAOS | 3 turns | 25% chance to deal damage to self each turn |
| **Tilted** | SNARK | 3 turns | Accuracy reduced by 25% |
| **In The Zone** | VIBE (self) | 3 turns | +30% Logic, -20% Resolve |
| **Hallucinating** | VIBE | 3 turns | 30% chance to target wrong enemy |

Status stacking: disabled. Last applied wins.

---

## Damage Formula

```
damage = move_power × type_effectiveness × (attacker_logic / defender_resolve) × rand(0.85, 1.0)
```

Minimum damage: 1. All values use level-adjusted stats.

**Type effectiveness:** 1.5× (strong), 1.0× (neutral), 0.5× (weak).

**Speed** determines turn order within a round. Both combatants select actions, then resolve in Speed order. Fastest goes first. A Hotfix archetype almost always acts first.

---

## Move System

### Move Properties
- Name, type, power (0–120), accuracy (50–100%), status effect (optional), status chance (%)

### Move Power Distribution
- Low (30–50): reliable, always-hits utility moves
- Mid (55–80): standard damage, common
- High (85–120): high risk/reward with reduced accuracy

### Move Discs (21 total)
Off-type coverage in the loadout slot. Found in dungeons and shops.

| Tier | Power | Accuracy | Rarity |
|---|---|---|---|
| Disc I | 50 | 95% | Common |
| Disc II | 70 | 85% | Uncommon |
| Disc III | 90 | 75% | Rare |

One disc per type × 3 tiers = 21 discs. A CHAOS Disc III on a PATIENCE critter covers matchups it would otherwise lose.

---

## Hold Items (13 total)

Equippable passive/active combat modifiers. One per critter. Persists across runs.

| Item | Effect |
|---|---|
| **Config File** | Set one chosen stat to its maximum value for the battle |
| **SSD Cache** | First move each battle ignores accuracy roll (always hits) |
| **Memory Leak** | Recover 5% max HP at end of each turn |
| **Mutex Lock** | Immune to Blocked status |
| **Tech Debt** | Start battle with In The Zone (power+, defense-) |
| **Unit Tests** | When HP drops below 25%, negate all damage that turn once |
| **Root Access** | All moves deal minimum 1.0× effectiveness (no type resistance) |
| **Two Monitors** | Use two actions per turn, each at 50% power |
| **Syntax Error** | Opponent wastes their first turn on battle entry |
| **Documentation** | Reveal enemy's full moveset and stats at battle start |
| **Garbage Collector** | Remove own status effect every 2nd turn |
| **Fork Bomb** | On faint, deal 30% of max HP as damage to opponent |
| **Singleton Pattern** | Last critter in party alive: +25% to all stats |

---

## Battle System

### Encounter Types

**1. Standard wild (1v1)**
One wild critter. Your active critter fights it. Bench exists for swaps only.

**2. Trainer boss teams (all bosses)**
Boss has a party of 2-3 critters sent sequentially. After each falls, the next enters. Your critter's HP and status carry over between sub-fights. Boss header shows: `[BOSS] Profiler — Party: ●●○`

**3. Boss + minion**
Some bosses arrive with a support critter simultaneously active. The minion acts every turn (heals boss, removes your status, debuffs you). Bench assist model activates:
- **Non-Reviewer bench**: item / swap / weakest move
- **Reviewer bench**: all above + their Support Special

**4. Swarm (floor 11+ only)**
3 consecutive 1v1 fights. No HP recovery between. Room is visually distinct (3 enemies visible). Entering is a choice.

### Turn Structure
1. Player selects action (Attack / Catch / Swap / Item / [Bench] if in boss+minion)
2. Enemy AI selects action
3. Resolve in Speed order
4. Apply damage, status, effects
5. Check for faints
6. Tick status durations
7. Check battle end conditions

### Battle Actions
- **Attack** — choose from 3 moves; show type/power/effectiveness on hover
- **Catch** — choose catch tool; show success % preview
- **Swap** — costs your turn; swap active critter with bench
- **Item** — use healing/buff item; choose target
- **Bench** (boss+minion only) — Reviewer Support Special or basic bench action

### Battle AI
Wild critters: prefer super-effective moves → else highest power → 20% random move selection.

### No Escape
Once an encounter triggers, the fight runs to completion. No flee option.

---

## Reviewer Archetype: Support Specials

In boss+minion fights, the Reviewer bench critter provides a type-specific Support Special:

| Type | Critter | Special | Type |
|---|---|---|---|
| DEBUG | Logstash | **Observe** — see boss's next queued move before deciding | Active |
| CHAOS | *(TBD)* | **Inject** — apply Segfaulted to any enemy from bench | Active |
| PATIENCE | Load Balancer | **Balance** — absorb 30% of next incoming hit | Passive |
| WISDOM | *(TBD)* | **Reflect** — cleanse active's status + +10% Logic | Active |
| SNARK | *(TBD)* | **Critique** — reduce enemy's next move accuracy by 40% | Active |
| VIBE | Prompt Engineer | **Hype** — grant In The Zone without defense drop | Active + Passive |
| LEGACY | *(TBD)* | **Persist** — active critter survives next KO with 1 HP | Active |

Passive specials (Load Balancer, Prompt Engineer's aura) trigger automatically. Active specials consume your bench turn.

---

## Dungeon System

### Overview
Free-movement top-down dungeon (Zelda/Undertale feel). Your active critter walks the rooms.
640×320px viewport (40×20 tiles at 16×16px) + 40px HUD strip.

### Floor Layout
4–6 rooms per floor connected by corridors:
- Start room (safe, no enemies)
- 2–3 enemy rooms
- Optional chest room (50% chance per floor)
- Boss room (stairs appear only after boss is defeated)

Boss floors (5, 10, 15) add a locked shop room accessible after the boss.

### Player Movement
- Smooth pixel-level movement, ~96px/sec
- AABB collision against wall tiles
- Active critter sprite walks. Party order determines who you see in the dungeon.

### Enemy Behavior
- **Patrol state**: simple route within home room (back-forth or random walk)
- **Detection**: player within 3 tiles (~48px) switches enemy to chase
- **Chase state**: locks onto player, moves toward them
- **Contact**: ~8px radius. Touch triggers battle.

This creates the sneak opportunity: hug walls, pass through detection edges, observe patrol routes from doorways before committing.

### Fog of War
- Per-room: entering permanently reveals all tiles in that room
- Adjacent rooms visible as dim silhouette through open doorways
- Unexplored rooms completely dark
- Minimap (64×48px overlay, top-right): explored rooms shown as rectangles

### Chest Room Rewards
- 60% — item (healing, catch tool, move disc, or hold item)
- 30% — currency bonus (50–150g)
- 10% — lone wild critter (peaceful, approach to interact/catch)

### HUD Strip
```
[Println ████░] [Goto ████░] [Glitch ████░]  Floor 5/15  💰 340g
```
HP bars color-code: green (>50%) → yellow (25–50%) → red (<25%).

### Optional Room Clearing
Rooms do not need to be cleared to progress. Stairs are blocked only by the boss room.
Strategies emerge: aggressive (clear all for XP), cautious (sneak to boss), greedy (clear chest rooms only).

---

## Run Structure

| | |
|---|---|
| Floors per run | 15 |
| Boss floors | 5, 10, 15 |
| Shop | After each boss (floor 5, 10, 15) — full party heal + buy items |
| HP recovery | Shop only. No auto-heal between fights. |
| Run win condition | Defeat floor 15 boss |
| Floor 16+ | Optional depth mode — no win state, deepest floor = score |
| Enemy level | `3 + floor × 2 ± 1` (cap 50) |
| No escape | Once encounter triggers, fight to completion |

---

## Catch System

```
catch_chance = tool_base_rate + type_bonus - (current_hp/max_hp × 30) - rarity_penalty
```
Clamped to 5–100%.

| Rarity | Catch Penalty |
|---|---|
| Common | 0 |
| Uncommon | -10 |
| Rare | -20 |
| Epic | -35 |
| Legendary | -50 |

Catch tools (5 tiers): Print Statement (20%) → Breakpoint (40%) → Try-Catch (60%) → Linter (50%+bonus) → Formal Proof (70%).

Weaken first. Rarer tools needed for rarer critters. Try-Catch: if it fails, enemy gets a free hit.

---

## Scars and Cooldowns

**Scar** — when a critter faints, it receives a permanent -1 to a random stat. Displayed in red on codex and roster. A critter with 3 scars has a story.

**Cooldown** — after fainting, unavailable for 1 full run. Forces roster rotation. Builds bench depth requirement.

Both mechanics together: losing your best critter costs you a scar (permanent) and a run (temporary). The calculation: push deeper and risk it, or extract and protect.

---

## Currency and Economy

Per-battle: `10 + floor × 5`. Boss: `×2`.
Shop prices scale with floor: `base_price × (1 + (floor-1) × 0.1)`.

Before first shop (floors 1-5): expect ~400-500 gold. Enough for 2-3 items.

Hold items and Move Discs are never sold in shops (drops only). Shops sell: catch tools, healing, XP items.

---

## Starter Selection (First Launch)

First time launching the game, a "Choose your partner" screen appears before the hub:

```
┌─ CHOOSE YOUR PARTNER ─────────────────────────────┐
│                                                   │
│     [Println]        [Goto]        [Glitch]       │
│      DEBUG           LEGACY         CHAOS         │
│                                                   │
│    Deployer         Monolith        Hotfix         │
│  Methodical.      Indestructible.   Fast.          │
│  Lints opponents.  Outlasts all.   Volatile.       │
│                                                   │
│              ◄► to browse, Enter to choose        │
└───────────────────────────────────────────────────┘
```

The other two starters are catchable later in dungeon runs.

---

## Evolution

**Trigger**: level threshold (varies by species).
- 3-stage lines: evolve at levels 12 and 28
- 2-stage lines: evolve at levels 13–15 (first form) and 28–32 (final)

Evolution is a full-screen interruption: flash, sprite transition, stat comparison screen. Permanent and visible in the roster.

---

## Legendary Critters

Three legendaries, each with deep achievement gates:

| Legendary | Type | Unlock Condition |
|---|---|---|
| **Root** | LEGACY | Catch all 7 LEGACY species → appears as floor 13+ rare encounter |
| **Zero Day** | CHAOS | Clear floor 15 with zero catches → appears on floor 15 of next run |
| **Linus** | WISDOM | Fill the complete codex (all 61 species) → appears on floor 15 |

Each legendary's unlock reflects its character. Linus reveals itself only to those who know everything. Zero Day respects efficient violence.

---

## Meta Progression

No meta shop. No power upgrades. All unlocks are skill-gated variety expansions.

| Gate | Unlock |
|---|---|
| Clear floor 5 | Biome selection before each run |
| Clear floor 10 | Hard Mode run flag (+5 enemy levels) |
| Clear floor 15 | Floor 16+ depth mode |
| Catch all 7 type representatives | 4th party slot |
| Fill codex | Secret 4th starter: Heisenbug |
| + Legendary unlock conditions above | |

The 4th party slot is the only power unlock. By the time you earn it, you've demonstrated mastery.

---

## Achievements ("Commits")

Git commit format. Displayed in the Records tab.

```
feat: add critter              First catch
fix: handle edge case          Win at <10% HP
hotfix: prod is down           Win after first critter faints
release: v1.0                  Clear floor 15
feat!: breaking change         First wipe
docs: add comments             Fill the codex
ci: pipeline passes            Clear floor 15 with no faints
revert: this was a mistake     Catch a Legendary
perf: reduce allocations       Win without taking any damage
test: add coverage             Use all 3 catch tool types in one run
chore: clean up globals        Catch full 3-stage evolution line
refactor: extract method       Evolve a critter for the first time
merge conflict resolved        2 scarred critters in same active party
```

Some commits unlock meta content. All are visible in Records tab.

---

## The Hub

Four tabs. `[1] Party  [2] Roster  [3] Items  [4] Records`

**Party tab**: Select active critters (up to 3, or 4 after unlock). Drag to reorder. Equip move discs and hold items. Pack run inventory. "Start Run" button.

**Roster tab**: All caught critters. Filter by type or archetype. Critter detail panel: sprite, name, level, type badge, archetype badge, HP bar, stats (scar penalties in red), moves with type/power/status, equipped items.

**Items tab**: Inventory grouped by category. Use healing/revive from hub. Preview item effects.

**Records tab**: Species codex (discovered = name/type shown, caught = full entry), Commits achievement list, lifetime stats (runs, deepest floor, catches, bosses), unlocks tracker.

---

## Full-Screen Moments

These pause the game and take over the screen. They are the memories players carry between sessions.

- **First scar**: dark overlay, critter sprite, red stat reduction text, "permanently" in smaller text
- **Evolution**: full-screen flash → new sprite → stat comparison (+X to each stat)
- **First catch ever**: one-time "Println was added to your roster!"
- **Boss clear**: boss name + flavor text overlay
- **Floor 15 clear**: victory screen — run stats, deepest floor, time
- **Wipe**: run over screen — scars applied, critters on cooldown, catches kept

Minor events use the battle log. Full-screen interruptions are reserved for what matters.

---

## UX Principles Applied

### Apple HIG
- **Clarity**: HP bar colors (green/yellow/red), type badges, damage labels (▲ SUPER EFFECTIVE)
- **Deference**: Battle sprites are the visual focus; UI chrome is subtle (Pixel UI Pack panels)
- **Depth**: Layering — background (0) → dungeon/entities (1–2) → UI/HUD (3) → modals (4+)

### Nielsen's 10 Heuristics
1. **Visibility**: Always-on HP bars, floor counter, turn indicator
2. **Real world match**: Dev-themed everything — type names, move names, commit achievements
3. **User control**: ESC always backs out; confirm on irreversible actions (extract, use last item)
4. **Consistency**: Arrow keys navigate everywhere, Enter confirms, ESC cancels, number shortcuts
5. **Error prevention**: Grey out unavailable moves; warn before Try-Catch (enemy gets free hit)
6. **Recognition**: Type effectiveness shown on move hover, move stats visible, no memorization required
7. **Flexibility**: 1/2/3 shortcuts for moves; number shortcuts for battle actions; skip animations with Enter
8. **Aesthetic minimalism**: 4-tab hub not 15 screens; show only current-context information
9. **Error recovery**: Battle log explains every event — "Try-Catch failed! Segfault attacks!"
10. **Help**: ? key on every screen shows context-sensitive controls

---

## Art Direction

**Resolution**: 640×360 (nearest-neighbor scaled to terminal dimensions).
**Tile size**: 16×16px for dungeon. 40×20 visible tiles.
**Sprite size**: 32×32px minimum for battle sprites (placeholder: 32×16 2-frame from old Zig project).
**Sprite registry**: `sprite/registry.lua` maps species_id → art config. New art drops in without code changes.

**Assets in use**:
- Pixel UI Pack — HP bars, panel borders, badges, buttons
- Legacy Collection (TinyRPG dungeon) — dungeon tileset (purple/blue)
- Legacy Collection (Grotto FX) — battle effects (electro-shock, fire-ball, energy-smack, etc.)
- 42 Clement Panchout WAV tracks — full music coverage

**Per-type battle FX mapping** (Legacy Collection → type):
- DEBUG → electro-shock (methodical electricity)
- CHAOS → fire-ball (chaotic combustion)
- PATIENCE → energy-smack (controlled force)
- WISDOM → sparkle/magic (abstraction made visible)
- SNARK → slash (cutting critique)
- VIBE → some glowy ambient effect
- LEGACY → dust/stone (old, heavy)

---

## Sprite Animation

### Philosophy

Each critter's animation should express its **programming concept** through motion. A Glitch jitters and corrupts. A Mutex pulses with lock-like steadiness. A Hallucination shimmers between forms. Animation is personality — the idle cycle is the critter's body language.

Evolution progression is reflected in animation complexity: base forms are simple and readable, mid evolutions add nuance, final forms have the most expressive and complex cycles.

### Frame Layout Convention

All battle sprites are 32×32px per frame, laid out as horizontal strips in PNG sprite sheets. Frame order: idle → attack → hit → faint.

| Stage | Idle | Attack | Hit | Faint | Total | Sheet |
|---|---|---|---|---|---|---|
| Base form | 4 | 3 | 2 | 2 | 11 | 352×32 |
| Mid evolution | 5 | 3 | 2 | 2 | 12 | 384×32 |
| Final form | 6 | 3 | 2 | 3 | 14 | 448×32 |

Non-enhanced species use the legacy 2-frame format (64×32) with the shared animation template.

### Animation Speeds

- **Idle**: 0.35–0.5s/frame. Patience types slower (0.5s), Chaos/Vibe faster (0.35s).
- **Attack**: 0.12–0.18s/frame. Snappy, impactful.
- **Hit**: 0.15–0.2s/frame. Quick reaction, returns to idle.
- **Faint**: 0.25–0.35s/frame. Dramatic, holds on last frame.

### Per-Type Animation Identity (Priority Evolution Lines)

**DEBUG** (Println → Tracer → Profiler): Terminal/data visualization motifs. Blinking cursors, scanning beams, pulsing bar graphs. Teal/cyan palette.

**CHAOS** (Glitch → Gremlin → Pandemonium): Corruption and entropy. Pixel jitter, twitchy bouncing, parts flying apart. Red palette.

**PATIENCE** (Mutex → Semaphore → Deadlock): Locks and synchronization. Steady pulses, traffic-light cycling, interlocked strain. Blue palette.

**WISDOM** (Monad → Functor → Burrito): Abstraction and transformation. Flowing data particles, mapping arrows, wrapped contents shifting. Purple palette.

**SNARK** (LGTM → Nitpick → Bikeshed): Critique and judgment. Sarcastic gestures, twitchy inspection, color-shifting surfaces. Yellow/green palette.

**VIBE** (Copilot → Autopilot → Hallucination): Autonomy and drift. Eager bouncing, mechanical rotation, reality-warping shimmer. Green/rainbow palette.

**LEGACY** (Goto → Spaghetto → Dependency): Old code and entanglement. Nervous jumping, noodle wiggling, ominous tangled rotation. Brown palette.

---

## Music

| Context | Track |
|---|---|
| Title | "Cheerful Title Screen" |
| Hub | "Life is full of Joy" |
| Dungeon (floors 1–10) | "Space Horror InGame Music (Exploration)" |
| Dungeon (floors 11–15) | "Space Horror InGame Music (Tense)" |
| Battle (wild) | "16-Bit Beat Em All" |
| Battle (boss) | "Chaotic Boss" |
| Shop | "The Chillout Factory" |
| Victory | "Unsettling victory" |
| Defeat/wipe | "Shadows" |

Music crossfades on scene transitions (300ms fade out, 300ms fade in).

---

## v1 Scope Boundary

**In v1:**
- All 61 species (7 types × 7 critters + 3 starters + 3 legendaries)
- All 52 moves
- All 13 hold items
- All 21 move discs
- 14 combat/utility items
- All 4 encounter types
- All 7 biomes (unlocked via meta progression)
- Full persistence via SQLite
- All 9 sub-phases as listed in roadmap

**Deferred to later:**
- Epic critter special mechanics (Valgrind always-last, Race Condition random turns, etc.) — v1 treats epics as stat-only
- Passive layer / Claude Code integration
- Biome auto-detection from working directory
- CLI subcommands (log-event, statusline, set-favorite)
- Multiplayer / networked play (never, probably)

---

## Emotional Arc of a Complete Run

**Act 1: Floors 1–5 (confidence)**
Your starter demolishes the first commons with type advantage. You catch one critter for the bench. HP starts mattering on floor 3-4. Floor 5 boss has a trainer team (2 critters). You barely make it with Goto grinding down the second critter with Deprecated. Shop. Exhale.

**Act 2: Floors 6–10 (investment)**
Full heal. Spend currency on a Breakpoint. Party is leveling toward evolution at level 12. Floor 7: a Heisenbug in a chest room — you catch it on the third attempt. Floor 9: Goto takes a critical hit. First scar screen. `-1 Logic — permanently.` You look at Goto differently now.

**Act 3: Floors 11–15 (stakes)**
Real danger. Every encounter costs something. Floor 12 has a swarm room — you knew to expect it past floor 11. Floor 14: you see a chest room glow (rare loot indicator). You push for it. A CHAOS Disc III. Worth it. Floor 15: the final boss. Full trainer team. You win with your last Hotfix item.

Run over: 6 catches, 2 scars, 1 evolution, deepest floor 15. Println has 1 scar. Goto has 1 scar. Next run: you know what the type chart does.

---

*This document is the authoritative design reference for `games/codecritter/`. Implementation phases are in `phases/phase-9.1.md` through `phases/phase-9.9.md`.*
