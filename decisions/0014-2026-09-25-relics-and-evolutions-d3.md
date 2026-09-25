# 0014. Relics, Merge Commits, the Glitch Door and Compile (D3)

- Date: 2026-09-25
- Status: Accepted
- Builds on ADR 0013 (D2 spell system) and `research/design-plan.md` §1–2. It replaces the POC's relic list from ADR 0007.

## Context
The POC had 28 relics. Ten of them were flat stat bumps or duplicates, such as +10% crit, 35% bigger blasts or +15% move speed. Those are forgettable picks that never change how you build. The research (`research/design-research.md` §2) points to:
- relics that change *rules* or read the *program*
- relics that pay off a status build
- duos that reward holding two things
- risky Corrupted picks

## Decision
**38 relics.** 18 are kept and 20 are new. Ten flat ones are cut: Blast Radius, Bounce Core, Hotkey Boots, Lucky Bit, Spare Battery, Echo Crystal, Iron Stack, Afterimage, Overclock Chip and Sandbox. Old saves drop them (`Relics.CUT`).

The 20 new relics:

| Group | Relics |
|---|---|
| Conditional | Cold Start, Low Battery, Cornered |
| Scaling | Uptime, Version Control |
| Rule-breakers | Root Access (runes cost nothing), Stack Overflow (nesting depth 5) |
| Program-aware | Off-by-One, Tail Call (Echo folded in), Loop Counter, Empty Set |
| Status | Surge Protector, Rot Index |
| Merge Commit duos | Thermal Throttle (Wildfire + Cold Boot), Zero-Day Exploit (Null Pointer + Cascade Failure), Swarm Protocol (Bug Bounty + Event Loop) |
| Corrupted | Race Condition, Memory Leak, Force Push, Legacy Code |

**How relics work in code:**
- **Stats:** plain numbers sit in each definition (`"stats"`) and fold into `Relics.stat(run, key)`.
  - Multipliers multiply, so two cuts never reach zero.
  - Slots add; nesting depth takes the largest.
  - Wands receive rune cost and nesting depth through `RunState.apply_relics()`.
- **Hooks:** behaviour stays at the event site (`run.has_relic` where it happens). `SpellRunner.cast_bonus()` gathers the per-cast conditions.

**Merge Commits** are offered only when you own both parents, and are three times as likely when they are.

**The Glitch Door:**
- A new door kind from the fourth room on. It shows up only while a Corrupted relic is left to find.
- Walking in costs **10 max HP**.
- It is a slightly harder fight, and pays 2 Corrupted relics plus an epic-leaning spell.
- **Corrupted** is a fourth rarity (pink). Normal offers never include it.

**Compile evolutions** happen at the forge, for free. A level-3 base spell plus a catalyst turns into an evolved spell in place. A relic catalyst stays; a spell catalyst is used up. Evolutions are never offered as rewards.

| Base spell | Catalyst | Evolved spell |
|---|---|---|
| Chain Spark | Cascade Failure | Storm Protocol |
| Null Orb | Gravity Rune | Singularity Kernel (implodes) |
| Ember Bolt | Wildfire | Meltdown |
| Frost Shard | Cold Boot | Absolute Zero (freezes on hit) |
| Arcane Mote | Recursion Charm | Self-Replicating Mote |
| Glitch Needle | Null Pointer | Exploit Needle |

**Freezing:** chill now stacks by level, so a level-3 chill freezes at once.

**"Enables" chips** on offer cards show what a pick would switch on with what you hold: Thermal Shock, Merge Commit, Compile, or Compile at L3.

**Counter pips on the HUD relic column:**
- Counts for Stack Trace and Loop Counter, and the Uptime stack.
- Lit dots for Try/Catch, Cold Start, Low Battery, Cornered, Deadline and Busy Wait.

## Consequences
- **Tests:** 19 behaviour tests for the new relics, the door, Compile and the chips (`tests/unit/test_relics_d3.gd`). The spell sweep now covers the evolutions too. 122 tests.
- **Stress test:** it sits near its 10 ms budget on the dev container before and after this change (A/B: 9.3–9.7 ms now, 10.2–10.7 ms on the previous commit). The budget line is noisy on this machine, not a D3 regression.
- **Deferred:**
  - Corrupted *spells* are not planned. Corrupted stays a relic rarity.
  - The guaranteed "counter" offer before each boss waits for D4's counters.
