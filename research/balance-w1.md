# World 1 balance: v0.3 (2026-09-24)

**How it's measured:** `tools/balance.sh` (tests/bench/test_balance.gd). A bot plays World 1 **without god mode** on 10 seeds. It always takes the first reward offered, never uses the wand editor, and never buys anything.
- It aims perfectly and dodges with a short look-ahead (predicted bullet approach over 0.4 s, plus bodies).
- That makes it a stand-in for a new player who fights well but builds nothing.

## Targets
- **Survival: 40–85%.** A new player should clear World 1 in 2–4 tries, since it is the free tier and has to hook people.
- **Mini-boss fight (Copy-Paste): 20–90 s.** Boss fight (The Infinite Loop): 30–150 s.
- **No stalls.** Every run ends in a win or a death; a stall means a bot or game bug, never "balance".

## Result after tuning

| Metric | Value |
|---|---|
| Survival | **80%** (8 of 10). Both deaths happen at the final boss. |
| Mini-boss | about 47 s on average |
| Boss | about 55 s on average |
| Run length | 130–280 s of simulated play. Humans take longer (menus, editing, walking). |
| Main source of damage | contact with the Loop's body during lap charges, then Copy-Paste's shots |

## What changed (from v0.2)

| Knob | v0.2 | v0.3 |
|---|---|---|
| Player max HP | 100 | 120 |
| Invulnerability after a hit | 0.7 s | 0.9 s |
| Heal on room clear | none | +8 HP |
| Spike plate | 10 | 6 |
| Contact damage: slime / weaver / ram / bugling / puffcap | 8 / 10 / 14 / 6 / 9 | 5 / 8 / 8 / 3 / 8 |
| Enemy bullets | 0.9 × contact | 0.6 × contact |
| Bugling speed | 62 | 50 |
| Thornback | keeps charging after a hit | the charge ends on impact (stun) |
| Boss bullets / contact | 12 / 16 | 6 / 12; Loop segments 0.5× |
| Copy-Paste | 560 HP, 5-shot fans | 360 HP, 3-shot fans (5 in phase 2), slower shots |
| The Infinite Loop | 1300 HP, lap charge ×3.2 | 850 HP, lap charge ×2.4 |
| Apprentice Rod | cast 0.15 s, recharge 0.5 s | cast 0.12 s, recharge 0.4 s |

## Bugs the balance pass found (all fixed)
Every one of these would also hit real players:
- A wand reward went straight into your hand. New wands arrive empty, so you could not cast. Now a new wand never takes the hand, a full belt replaces the emptiest wand, and an empty wand in hand switches to one that can cast.
- A Thornback could slide into a wall corner and become unreachable. Now anything inside a wall is nudged back onto open floor.
- Auto-aim was measured from the feet, but spells leave the hand 8 px higher. Past a wall corner every shot hit the wall. Aim and sight now come from the hand.
- Crates blocked sight even though spells smash them. Now they block movement and enemy shots, but not aim.

## Caveats
- The bot is not a human. Early human play should be easier than this (people adapt to patterns), and the Loop may feel harder (the body is hard to read on a small screen). Re-check on the first real-device build.
- Numbers live in data (`Enemy.DEFS`, the boss `_init_boss`, `World._compose_waves`, `RunState`), so tuning after device tests does not touch logic.

## After the 0.4 arsenal (2026-09-24)
New spells and relics, tag-weighted rewards and +20% base auto-aim reach (Keen Scope cut). Same bench, 10 seeds: **70% survival**, mini-boss about 58 s, boss about 41 s, no stalls. It stays inside the guardrail (40–85%), so no tuning was needed.

## D2 spell system: two bots (2026-09-25)
The bench now runs two bots over the same 10 seeds (`tests/bench/test_balance.gd`):
- **Editing bot** (`WandPlanner`):
  - Takes the offer that raises a rough DPS estimate most.
  - Equips from the bag and reorders the wand.
  - Buys a forge slot and a shop spell when they help.
  - **Survival 70%**, mini-boss about 61 s, boss about 41 s. No stalls.
- **Never-editing bot:**
  - Takes the first offer and leaves the bag alone, so it plays a whole run with the starting Mote.
  - **Survival 0%.** Every run dies at the boss, after beating the mini-boss in about 82 s.

Editing the wand now decides the run, as the design wants. The D4 target for the bot that never edits is 15–30%, not 0%: the enemy counters and the curriculum first run should leave a non-editor some chance, and early rewards may need to lean toward shooting spells.

## D3 relics (2026-09-25)
Same bench, two bots, 10 seeds:
- **Editing bot: survival 70%.** Mini-boss about 57 s, boss about 54 s.
- **Never-editing bot: survival 30%** (up from 0%). Relics that act on a plain wand now carry a lone Mote further: Cold Start, Tail Call, Loop Counter, Empty Set and Uptime.

Both bots already sit inside the D4 targets (60–80% and 15–30%). D4's enemy counters should hold that gap, not widen it.

## D4 enemies (2026-09-25)
Same bench, after shields, armour, wards, the four new enemies and the wave grammar:
- **Editing bot: 80%.**
- **Never-editing bot: 10%.**

A softer golem slam (12 → 10) and a shield that wears out after 8 blocked hits (was 10) did not move either number. The bot that never edits dies almost only at the final boss (8 of 9 runs), so its 15–30% target is left for D7's boss rework.
