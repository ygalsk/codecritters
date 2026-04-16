# Presentation

## Hub

Four tabs. `[1] Party  [2] Roster  [3] Items  [4] Records`

**Party tab**: Select active [[critters|critters]] (up to 3, or 4 after [[progression#Meta Progression|unlock]]). Drag to reorder. Equip [[battle-system#Move Discs|move discs]] and [[items#Hold Items|hold items]]. Pack run inventory. "Start Run" button.

**Roster tab**: All caught critters. Filter by [[types|type]] or [[archetypes|archetype]]. Critter detail panel: sprite, name, level, type badge, archetype badge, HP bar, stats ([[progression#Scars|scar]] penalties in red), moves with type/power/status, equipped items.

**Items tab**: Inventory grouped by category. Use healing/revive from hub. Preview item effects.

**Records tab**: Species codex (discovered = name/type shown, caught = full entry), [[progression#Achievements|Commits]] achievement list, lifetime stats (runs, deepest floor, catches, bosses), unlocks tracker.

## Full-Screen Moments

These pause the game and take over the screen. They are the memories players carry between sessions.

- **First scar**: dark overlay, critter sprite, red stat reduction text, "permanently" in smaller text
- **Evolution**: full-screen flash -> new sprite -> stat comparison (+X to each stat)
- **First catch ever**: one-time "Println was added to your roster!"
- **Boss clear**: boss name + flavor text overlay
- **Floor 15 clear**: victory screen — run stats, deepest floor, time
- **Wipe**: run over screen — scars applied, critters on cooldown, catches kept

Minor events use the battle log. Full-screen interruptions are reserved for what matters.

## UX Principles Applied

### Apple HIG
- **Clarity**: HP bar colors (green/yellow/red), type badges, damage labels (SUPER EFFECTIVE)
- **Deference**: Battle sprites are the visual focus; UI chrome is subtle (Pixel UI Pack panels)
- **Depth**: Layering — background (0) -> dungeon/entities (1-2) -> UI/HUD (3) -> modals (4+)

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
