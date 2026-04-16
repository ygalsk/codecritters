# Types

Types determine: what matchups you have, what status effects your moves inflict, and your [[critters|critter's]] thematic identity.

## The 7 Types

| Type | Theme | Strong vs | Weak vs | Inflicts |
|---|---|---|---|---|
| **DEBUG** | Methodical analysis | CHAOS, VIBE | WISDOM, LEGACY | Linted |
| **CHAOS** | Entropy, crashes, glitches | PATIENCE, SNARK, LEGACY | DEBUG, WISDOM | Segfaulted |
| **PATIENCE** | Concurrency, waiting | CHAOS, WISDOM | VIBE, SNARK | Blocked |
| **WISDOM** | Abstraction, theory | DEBUG, PATIENCE | LEGACY, SNARK | Enlightened |
| **SNARK** | Critique, mockery | PATIENCE, WISDOM | CHAOS, VIBE | Tilted |
| **VIBE** | Vibes, velocity, autonomy | SNARK, LEGACY | DEBUG, PATIENCE | Hallucinating |
| **LEGACY** | Old code, persistence | DEBUG, WISDOM | CHAOS, VIBE | Deprecated |

Type effectiveness: strong = 1.5x, neutral = 1.0x, weak = 0.5x.

**Starter triangle:** Glitch (CHAOS) > Goto (LEGACY) > Println (DEBUG) > Glitch
See [[critters#Starter Selection|starter selection]] for the first-launch flow.

## Status Effects

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

Some [[items#Hold Items|hold items]] interact with status: Mutex Lock (immune to Blocked), Garbage Collector (cleanses every 2nd turn), Tech Debt (starts with In The Zone).
