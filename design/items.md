# Items

## Hold Items (13 total)

Equippable passive/active combat modifiers. One per [[critters|critter]]. Persists across runs. Equipped in the [[critters#Critter Loadout|4th loadout slot]].

| Item | Effect |
|---|---|
| **Config File** | Set one chosen stat to its maximum value for the battle |
| **SSD Cache** | First move each battle ignores accuracy roll (always hits) |
| **Memory Leak** | Recover 5% max HP at end of each turn |
| **Mutex Lock** | Immune to [[types#Status Effects|Blocked]] status |
| **Tech Debt** | Start battle with [[types#Status Effects|In The Zone]] (power+, defense-) |
| **Unit Tests** | When HP drops below 25%, negate all damage that turn once |
| **Root Access** | All moves deal minimum 1.0x effectiveness (no type resistance) |
| **Two Monitors** | Use two actions per turn, each at 50% power |
| **Syntax Error** | Opponent wastes their first turn on battle entry |
| **Documentation** | Reveal enemy's full moveset and stats at battle start |
| **Garbage Collector** | Remove own status effect every 2nd turn |
| **Fork Bomb** | On faint, deal 30% of max HP as damage to opponent |
| **Singleton Pattern** | Last critter in party alive: +25% to all stats |

Hold items and Move Discs are never sold in shops (drops only from [[dungeon#Chest Room Rewards|chest rooms]]).

## Catch Tools

```
catch_chance = tool_base_rate + type_bonus - (current_hp/max_hp x 30) - rarity_penalty
```
Clamped to 5-100%.

| Tool | Base Rate | Notes |
|---|---|---|
| Print Statement | 20% | Starter tool |
| Breakpoint | 40% | |
| Try-Catch | 60% | If it fails, enemy gets a free hit |
| Linter | 50% | +bonus vs specific types |
| Formal Proof | 70% | Rare |

Weaken first. Rarer tools needed for rarer critters.

### Rarity Catch Penalties

| Rarity | Penalty |
|---|---|
| Common | 0 |
| Uncommon | -10 |
| Rare | -20 |
| Epic | -35 |
| Legendary | -50 |

Shops sell catch tools, healing, and XP items. See [[progression#Economy|economy]].
