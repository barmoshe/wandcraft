# 0020. A curriculum first run, Source Fragments, Bug Reports and the dash (D9)

- Date: 2026-09-25
- Status: Accepted
- Builds on `research/design-plan.md` §6 (progression and onboarding) and §10 (the dash).

## Context
The POC taught through six one-line tips. Nothing made a new player open the wand editor, and every run was the same size of pool, so there was nothing to come back for beyond the next attempt. The plan asked for a curriculum first run with a tested timing bar, meta unlocks in the Dead Cells style, heat tiers for replay, and the dash.

## Decision
- **The first run is a curriculum** (`Tutorial`), switched on when a player has no runs yet (`--tutorial` for tools). The plan listed five lessons over five rooms; the chapter has three rooms before the mini-boss, so the lessons fit there:
  - Room 1, buglings: the prize is Empower, the first edit.
  - Room 2, a Hex Weaver among fodder: the prize is Needle or Phase.
  - Room 3, shielded Rune Sentries that show BLOCKED to anything but pierce: the prize is a trigger, plus one wand slot so it has room.
  - The mini-boss, Copy-Paste, as before.
- **The editor coaches** each prize: a line in the info panel and pulsing rings on the spell to move and the slot to drop it in. The goal layout is fixed when the prize is granted (a boost before the first shooting spell, a new shooting spell after the others, a trigger right after the first shooting spell with another after it) and walked one move at a time. The first draft coached "the first empty slot", which put Empower to the right of the Mote (boosts only power what is to their right) and left the trigger with nothing on its left; the wand compiler, not a guess, set the layouts.
- **Armour and wards** are taught by a tip the first time each one stops you, in any run, instead of a forced golem room. Dashing gets a tip the first time a shot lands.
- **Source Fragments and the Codex** (`Meta`): a room 1, the mini-boss 3, the boss 5, a win 5, +20% per heat tier. Twenty-six unlocks join the pool (spells, the four Debugger runes, relics, wands, the Stub start) and one stat upgrade, +1 starting slot. Locking applies only in the running game, so tests and the bench see the full game and never read the machine's save.
- **Bug Reports**: one tier per win, up to five, picked on the title. They stack: an elite in every fight, +20% enemy HP, 15% faster enemy shots, weaker springs and 25% dearer shops, +25% boss HP.
- **The dash**: 0.18 s, 0.14 s of i-frames, three afterimages, a 0.35 s cooldown; Space/Shift, gamepad A/B, and a DASH button once any touch is seen. The bots never dash.

## Consequences
- 180 unit tests plus the tap test (which now presses DASH). `test_onboarding_d9.gd` plays the curriculum as a player who does what the coach says: the first edit at about 10 s and the first trigger at about 42 s, against the plan's 120 s and 180 s. A bot is faster than a person, so this proves the structure; Bar's fresh-eyes playtest is the human check.
- The bench is unchanged by design: no tutorial, no locks, no heat and no dashing in it.
- The never-editing bot stays at 10% (the plan's band is 15-30%). It dies at the final boss, and raising it by softening that boss would also lift the editing bot past its 85% cap. The gap it measures (80% against 10%) is the point of the band, so the number is recorded and left.
- The stress test now asserts a ratio to a calibration workload (ADR-free change, noted in the commit): on a desktop in use the absolute tick swung 8-17 ms while the ratio held at 4.2-4.6.
