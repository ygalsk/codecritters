# Codecritter

**Catch bugs. Train abstractions. Mass panic the kernel.**

Codecritter is a Pokemon-style roguelike that runs in your terminal. Every critter is a programming concept — from the humble `Printf` to the terrifying `Kernel Panic`. Build a party, descend through procedurally generated dungeons themed around programming languages, and catch the bugs that haunt your codebase.

Your real coding work fuels the game. Codecritter integrates with Claude Code: tool usage earns your critters XP, coding sessions surface rare items, and your party state is queryable via CLI so your favorite critter can live in your statusline.

## The Pitch

You `cd` into your Python project. Codecritter detects it and generates the **Pythonic Caves** — indented tunnels where whitespace is load-bearing and VIBE-type critters roam. You descend floor by floor with a party of three: your scarred veteran **Mutex**, a freshly caught **Bobby Tables**, and your starter **Profiler** who's been with you since day one.

On floor 8, you encounter a wild **Heisenbug**. It has insane evasion — it literally disappears when you try to observe it. You burn through two Breakpoints trying to catch it before landing the third. It joins your roster with a DEBUGGING type and a move that makes enemies question their own accuracy.

Floor 10: boss fight. **GIL** locks your critters in place with Blocked status while slowly draining their stats. You swap in Bobby Tables — a CHAOS type that bypasses defense entirely — and brute-force your way through. Your Mutex faints and picks up a scar. It'll be on cooldown for a while, recovering while you write actual code.

Later that evening you're deep in a real debugging session. Claude Code fires off Bash and Edit calls. When you launch Codecritter the next morning: "While you were coding, Profiler found a Formal Proof and gained 340 XP."

## Features

**7 types with a developer-native effectiveness chart.** DEBUG beats CHAOS because debugging tames messy code. LEGACY resists CHAOS because spaghetti that's been in production for 15 years has already survived everything. VIBE beats SNARK because you can't mock someone who doesn't care.

**61 critters across 5 rarity tiers.** Three-stage evolution lines, standalone rares, epics with defining drawbacks, and 3 typed legendaries. Every critter is a joke that's also a real game mechanic — Regex has a 50% chance to confuse itself, Turing Machine can learn any move but takes 2 turns to compute, Prompt Engineer buffs your whole team but literally cannot attack.

**Roguelike dungeon runs.** Pick 3 from your roster, descend as deep as you can. Procedural floors, biome-specific encounters, shops between floors, bosses every 5 levels. Extract with your loot or wipe and face cooldowns and scarring.

**Pixel-art sprites in your terminal.** Half-block rendering (▄/▀) with 24-bit truecolor. Kitty graphics protocol support for terminals that have it (Ghostty, Kitty, WezTerm) with automatic fallback. Idle animations. Two sprites facing off in a proper battle layout.

**Claude Code integration.** Your coding fuels the game through a passive ambient layer. CLI subcommands expose your party state for statusline integration and slash commands. Claude Code hooks and skills live in a companion repo ([ygalsk/codecritter](https://github.com/ygalsk/codecritter)) — including a buddy companion that comments on your work in-character.

**Biomes from your codebase.** Codecritter reads your working directory and generates dungeons themed to the language. Python projects get Pythonic Caves. Node projects get the Node Modules Abyss (it's deeper than you think). Rust projects get the Rustacean Depths, where the corridors are strict and there are no unsafe zones. Unlockable for manual selection after clearing.

## Critter Highlights

| Critter | Type | What's its deal |
|---|---|---|
| Segfault → Kernel Panic | CHAOS | The classic crash cascade |
| Mutex → Deadlock | PATIENCE | Locks everything. Including itself. |
| LGTM → Bikeshed | SNARK | Approves without reading, evolves into arguing about naming |
| Copilot → Hallucination | VIBE | Starts helpful, ends confidently wrong |
| Singleton → Monolith | LEGACY | There can only be one, and it's unkillable |
| Rubber Duck | WISDOM | Debuffs enemies by making them explain themselves |
| 404 | SNARK | Not found. Good luck hitting it. |
| Bobby Tables | CHAOS | SQL injection incarnate. Bypasses defense. |
| COBOL | LEGACY | Ancient. Terrifying stats. Still runs the banks. |
| Load Balancer | PATIENCE | Distributes damage across your party — but can't swap out and hits weaker |

## Tech Stack

- **Zig** — the whole thing
- **libvaxis** — terminal rendering, input handling, Kitty graphics protocol
- **SQLite** — persistent game state
- **CLI subcommands** — `log-event`, `status`, `set-favorite`, `statusline` for Claude Code integration (hooks/skills in [ygalsk/codecritter](https://github.com/ygalsk/codecritter))

## Status

Early development. See [CODECRITTER_DESIGN.md](CODECRITTER_DESIGN.md) for the full game design document and [AGENT_INSTRUCTIONS.md](AGENT_INSTRUCTIONS.md) for the implementation roadmap.

## License

TBD
