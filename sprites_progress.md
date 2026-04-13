# Sprite Progress Tracker

61 species | **30 done, 31 remain** | **Current: Phase 7 (TODO)**

---

## Reference

### Frame Counts by Stage
| Stage | Idle | Attack | Hit | Faint | Total | Canvas |
|---|---|---|---|---|---|---|
| Base | 4 | 3 | 2 | 2 | 11 | 352x32 |
| Mid | 5 | 3 | 2 | 2 | 12 | 384x32 |
| Final | 6 | 3 | 2 | 3 | 14 | 448x32 |

### Animation Speeds
- Idle: 0.35–0.5s/frame — CHAOS/VIBE: 0.35, PATIENCE: 0.5, others: 0.4–0.45
- Attack: 0.12–0.18s | Hit: 0.15–0.2s | Faint: 0.25–0.35s

### Type Palettes
| Type | Palette |
|---|---|
| DEBUG | outline=#0A2E2E  dark=#1A4A4A  mid=#2E8A8A  light=#50C8B0  bright=#80E8D0  eye=#E0F8F0 |
| CHAOS | outline=#2A0A0A  dark=#5A1A1A  mid=#A03030  light=#D05050  bright=#F08070  eye=#F0E0D0 |
| PATIENCE | outline=#0A1A30  dark=#1A3060  mid=#3060A0  light=#5090D0  bright=#80B8E8  eye=#E0F0F8 |
| WISDOM | outline=#1A0F30  dark=#2D1B4E  mid=#6B3FA0  light=#B088D0  bright=#D4B8E8  eye=#E0D0F0 |
| SNARK | outline=#2B3A10  dark=#4A5F20  mid=#7BA830  light=#A8D440  bright=#D4F060  eye=#F0F0E0 |
| VIBE | outline=#0A3320  dark=#1A5A38  mid=#30A060  light=#60D088  bright=#90F0B0  eye=#E0F8E8 |
| LEGACY | outline=#1A1008  dark=#3A2818  mid=#7A5A30  light=#B08848  bright=#D0B068  eye=#E0D8C0 |

### Design Rules
1. Silhouette reads at 32×32 filled black
2. Chibi base forms; colored outlines (darkest shade); top-left light source
3. 4–8 colors, hue-shifted ramps; evolution = same palette, bigger/more complex silhouette
4. Idle cycle = body language for the programming concept

### Registry Template
```lua
-- Base (11f): idle={0-3}, attack={4-6}, hit={7-8}, faint={9-10}
-- Mid  (12f): idle={0-4}, attack={5-7}, hit={8-9}, faint={10-11}
-- Final(14f): idle={0-5}, attack={6-8}, hit={9-10}, faint={11-13}
entry("name", {
  idle   = { frames = {…}, speed = X, loop = true },
  attack = { frames = {…}, speed = X, loop = false },
  hit    = { frames = {…}, speed = X, loop = false },
  faint  = { frames = {…}, speed = X, loop = false, stay_on_last = true },
})
```

---

## Completed (phases 1–5)

| # | Name | Type | Stage | Idle |
|---|---|---|---|---|
| 1 | println | DEBUG | Base | 0.4 |
| 2 | glitch | CHAOS | Base | 0.35 |
| 3 | goto | LEGACY | Base | 0.45 |
| 4 | monad | WISDOM | Base | 0.45 |
| 5 | copilot | VIBE | Base | 0.35 |
| 6 | segfault | CHAOS | Base | 0.35 |
| 7 | mutex | PATIENCE | Base | 0.5 |
| 8 | lgtm | SNARK | Base | 0.4 |
| 9 | singleton | LEGACY | Base | 0.45 |
| 10 | printf | DEBUG | Base | 0.4 |
| 11 | tracer | DEBUG | Mid | 0.4 |
| 12 | gremlin | CHAOS | Mid | 0.35 |
| 13 | spaghetto | LEGACY | Mid | 0.45 |
| 14 | functor | WISDOM | Mid | 0.45 |
| 15 | autopilot | VIBE | Mid | 0.35 |
| 16 | stack_overflow | CHAOS | Mid | 0.35 |
| 17 | god_object | LEGACY | Mid | 0.45 |
| 18 | semaphore | PATIENCE | Mid | 0.5 |
| 19 | nitpick | SNARK | Mid | 0.4 |
| 20 | fprintf | DEBUG | Mid | 0.4 |
| 21 | pandemonium | CHAOS | Final | 0.35 |
| 22 | dependency | LEGACY | Final | 0.45 |
| 23 | profiler | DEBUG | Final | 0.4 |
| 24 | logstash | DEBUG | Final | 0.4 |
| 25 | kernel_panic_critter | CHAOS | Final | 0.35 |
| 26 | monolith | LEGACY | Final | 0.45 |
| 27 | deadlock | PATIENCE | Final | 0.5 |
| 28 | burrito | WISDOM | Final | 0.45 |
| 29 | bikeshed | SNARK | Final | 0.4 |
| 30 | hallucination | VIBE | Final | 0.35 |

---

## TODO / IN PROGRESS

*Format: `### N. name (TYPE, canvas) — idle Xs`*

---

---

### Phase 7 — Uncommon Standalone + Mid-tier

### 31. todo (SNARK, 448x32) — idle 0.4s
Standalone final. Sticky note with "TODO" written on it, slightly curled corner. Passive-aggressive face. Bounces with impatience.

### 32. readme (VIBE, 448x32) — idle 0.35s
Standalone final. Open book/document with visible text lines. Friendly, welcoming face. Pages flutter in idle.

### 33. makefile (LEGACY, 448x32) — idle 0.45s
Standalone final. Gear/cog with scroll/recipe attached. Mechanical, reliable look. Steady rotation in idle.

### 34. breakpoint (DEBUG, 384x32) — idle 0.4s
Mid form. Red dot/circle (IDE breakpoint marker) with stern face. Hand up in "stop" gesture. Pauses momentarily in idle.

### 35. fuzzer (CHAOS, 384x32) — idle 0.35s
Mid form. Fuzzy/static ball of TV-noise shaped into a creature. Edges constantly shifting, random pixels flickering.

### 36. queue (PATIENCE, 384x32) — idle 0.5s
Mid form. Series of small blocks lined up forming a body. Patient face on front block. Blocks shift forward one position each idle cycle.

### 37. hashmap (WISDOM, 384x32) — idle 0.45s
Mid form. Grid/table with visible key-value pairs. Lookup animation in idle — key goes in, value lights up.

---

### Phase 8 — Rare Final Forms batch 1

### 38. watchpoint (DEBUG, 448x32) — idle 0.4s
Final breakpoint. All-seeing eye embedded in a data stream. Multiple sensor tendrils. Alert glow in idle. Triggers on change.

### 39. chaos_monkey (CHAOS, 448x32) — idle 0.35s
Final fuzzer. Mischievous monkey made of static/chaos energy. Throwing sparks, breaking things intentionally. Wild, gleeful destruction.

### 40. priority_queue (PATIENCE, 448x32) — idle 0.5s
Final queue. Heap/pyramid of blocks, most important on top glowing gold. Blocks rearrange as priorities shift in idle.

### 41. b_tree (WISDOM, 448x32) — idle 0.45s
Final hashmap. Tree structure — trunk with branching nodes, leaves containing data. Balanced, symmetric. Nodes light up as data traverses.

### 42. fixme (SNARK, 448x32) — idle 0.4s
Final todo. Angry sticky note with "FIXME" in red, crumpled/torn edges. More aggressive than todo. Shaking with urgency.

### 43. no_tests (VIBE, 448x32) — idle 0.35s
Final readme. Document with big red X over it. Confident but hollow. Test coverage bar at 0%. Vibes-only.

### 44. jenkins (LEGACY, 448x32) — idle 0.45s
Final makefile. Butler/servant robot — old, dutiful, slightly broken. Bowtie, tray, tired eyes. Creaky idle movement.

---

### Phase 9 — Rare Final Forms batch 2

### 45. heisenbug (DEBUG, 448x32) — idle 0.4s
Standalone rare. Bug/beetle flickering between visible and invisible. Semi-transparent in some frames. When you look, it changes.

### 46. bobby_tables (CHAOS, 448x32) — idle 0.35s
Standalone rare. Small child holding "DROP TABLE" sign. Innocent-looking but destructive. Database tables crumbling behind.

### 47. cron (PATIENCE, 448x32) — idle 0.5s
Standalone rare. Clock/alarm with stern scheduling face. Hands tick in idle. Rings precisely on time. Reliable, mechanical.

### 48. rubber_duck (WISDOM, 448x32) — idle 0.45s
Standalone rare. Yellow rubber duck with wise eyes. Floating serenely. Calm, patient, knowing.

### 49. four_oh_four (SNARK, 448x32) — idle 0.4s
Standalone rare. Broken page showing "404". Ghost/phantom — partially visible, partially missing. Flickers between existing and not.

### 50. yolo (VIBE, 448x32) — idle 0.35s
Standalone rare. Reckless character with sunglasses and party hat. No fear, maximum vibes. Bouncing with reckless energy.

### 51. cobol (LEGACY, 448x32) — idle 0.45s
Standalone rare. Ancient stone tablet or punchcard character. Covered in dust, cracks showing age. Slow, heavy, but still running.

---

### Phase 10 — Epic

### 52. valgrind (DEBUG, 448x32) — idle 0.4s
Magnifying glass over memory. Large lens character scanning for leaks. X-ray vision showing hidden problems. Dramatic scanning in idle. Extreme: Logic.

### 53. race_condition (CHAOS, 448x32) — idle 0.35s
Two overlapping ghost-figures racing/phasing through each other. Flickering between two states. Quantum superposition of threads. Extreme: Speed.

### 54. load_balancer (PATIENCE, 448x32) — idle 0.5s
Central hub/nexus with balanced arms/scales distributing work. Multiple connection points. Steady rotation. Calm under pressure. Extreme: Resolve.

### 55. turing_machine (WISDOM, 448x32) — idle 0.45s
Abstract tape machine — a head reading/writing on an infinite tape. Mathematical, elegant. Tape moves through in idle. Extreme: Logic.

### 56. regex (SNARK, 448x32) — idle 0.4s
Twisted knot of symbols/patterns. Looks like line noise but has hidden structure. Shifts and rearranges. Cryptic, powerful. Extreme: Logic.

### 57. prompt_engineer (VIBE, 448x32) — idle 0.35s
Wizard/mage with glowing prompt/wand. Conjuring outputs from vibes. Half-real, half-imagined. Sparkles and confidence. Extreme: Logic.

### 58. mainframe (LEGACY, 448x32) — idle 0.45s
Massive old computer cabinet — blinking lights, tape reels, fills the frame. Green terminal glow. Slow but unstoppable. Extreme: HP.

---

### Phase 11 — Legendary

### 59. root (LEGACY, 448x32) — idle 0.45s
Tree root system that IS the system — tendrils connecting to everything, crown above, deep roots below. Ancient, golden aura.

### 60. zero_day (CHAOS, 448x32) — idle 0.35s
Crack/fissure in reality — dark void energy leaking through. Sharp, angular. Edges seem to break the frame. Ominous pulse.

### 61. linus (WISDOM, 448x32) — idle 0.45s
Wise penguin sage with long beard and kernel symbols. Small but radiates immense power. Calm, knowing, slightly judgmental.

---

## Phase Plan

| Phase | Status | Sprites |
|---|---|---|
| 1 | DONE | println glitch goto monad copilot mutex lgtm |
| 2 | DONE | segfault singleton printf |
| 3 | DONE | tracer gremlin spaghetto functor autopilot |
| 4 | DONE | stack_overflow god_object semaphore nitpick fprintf |
| 5 | DONE | pandemonium dependency profiler logstash kernel_panic_critter |
| 6 | DONE | monolith deadlock burrito bikeshed hallucination |
| 7 | TODO | todo readme makefile breakpoint fuzzer queue hashmap |
| 8 | TODO | watchpoint chaos_monkey priority_queue b_tree fixme no_tests jenkins |
| 9 | TODO | heisenbug bobby_tables cron rubber_duck four_oh_four yolo cobol |
| 10 | TODO | valgrind race_condition load_balancer turing_machine regex prompt_engineer mainframe |
| 11 | TODO | root zero_day linus |
