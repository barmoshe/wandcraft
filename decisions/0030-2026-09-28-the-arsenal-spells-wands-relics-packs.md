# 0030. The arsenal: 14 spells, 5 rule wands and 16 relics, sold in five packs (0.20)

- Date: 2026-09-28
- Status: Accepted
- Follows ADR 0027 (packs are content, never power) and ADR 0029 (triggers leave the core). Research: `research/arsenal-0.20.md` and `research/arsenal-0.20/`.

## Context
Bar asked: "Research design, add more relics, add more spells, add more wands." The research (Noita, Magicraft, Balatro, Slay the Spire, Hades, Brotato and others) found gaps in our pool:
- Nothing reacted to the player.
- Nothing scaled within a room, and there was no two-spell carrier.
- Only the Mirror Rod changed the reading order.
- Almost no relic read the wand's shape.
- Nothing answered World 3's Interrupt, Page Leak, Data Race or revert.

Mechanics are free to use. Every name and number is ours (ADR 0002).

## Decision
**Spells** (`Catalog`, with tags and icons in `IconSpellsE`):
- Counters: Drill Bit (shields), Zip Bomb (armour), Blue Screen (wards).
- Tarball carries two spells. Await fires the right spell at what the left one hit, paying each time it fires.
- Boosts that bend the flow:
  - Buffering... holds spells until the wrap.
  - Retry recasts misses at the nearest enemy; walls and orbits never retry.
  - Just-in-Time.
  - End Block }.
- Runes:
  - Alt+Tab keeps parity through `WandState.cycles`.
  - Autocomplete makes copies at normal mana.
  - Ctrl+Alt+Del holds the next slot and fires it out 4 ways when you're hit, with a cooldown per rune.
- Passives: Virtual Memory (mana debt shows red on the HUD) and Cache Hit (repeats are cheaper).

**Wands**, each with one rule (`WandDef.rule`):
- Shuffle Play shuffles its order each recharge, shown on the HUD.
- Pinned Tab adds slot 1 to every cast.
- Palindrome Staff reads there and back.
- Double Buffer has two pages that swap; an empty page turns over at once.
- Recycle Bin refills mana on a kill.

**Relics** (`Relics.DEFS`, HUD pips where they have a state):
- Kernel Mode:
  - Graceful Degrade and Swap Space (only from World 3, `"from": 2`).
  - Thread Join: Finisher, never on bosses. On Data Race, a thread falling finishes its twin under 15%.
  - Undo Stack: Take-Back, which keeps Untouched Streak.
  - Warm Cache.
- Refactor, which read the wand's shape:
  - Hoisting: Tail Boost, at 1.5x boost mana.
  - Polyglot.
  - Short Circuit.
  - End of Life: Buyback, uses the shop's BAN.
  - Technical Debt: Corrupted. +2 slots, recharge x1.5.
- Core:
  - Lazy Eval refunds only the spell's own mana on a plain miss.
  - Context Switch.
  - Cold Storage pays Bits.
  - Shared Memory: Contagion, within 90 px.
- Merge Commit duos: Cron Job (Double Tick) and Superconductor (Cold Current).

**Where they live:** the Merchant's packs (`Meta.PACKS`), so a first run's pool stays small.

| Pack | Price | Unlocked by | Holds |
|---|---|---|---|
| Refactor (`refactor.pkg`) | 100 | the Loop | the five shape relics |
| Interrupts (`irq.pkg`) | 120 | | Ctrl+Alt+Del, Retry, Await, Blue Screen, Pinned Tab, Context Switch |
| Compiler (`cc.pkg`) | 120 | | Zip Bomb, Drill Bit, JIT, End Block, Alt+Tab, Palindrome, Shuffle Play, Shared Memory |
| Kernel Mode (`kernel.pkg`) | 120 | Deadlock | the five Kernel relics |
| Memory (`mem.pkg`) | 140 | Deadlock | Buffering, Virtual Memory, Cache Hit, Tarball, Autocomplete, Double Buffer, Recycle Bin, Lazy Eval, Cold Storage |

- The two duos join `Meta.CORE_RELICS`, since both of their parents are core.
- Every pack item is in `Catalog.PACK_ITEMS`, so it needs an icon and is never core.

## Consequences
- Pool sizes: 88 spells, 15 wands, 58 relics, 15 packs.
- Tests:
  - `test_arsenal_0_20` (24): a behaviour test for each spell and each wand rule.
  - `test_relics_0_20` (20).
  - `test_meta_d9`, `test_packs` and `test_spells_packs` check placement and icons.
- Still thin: Burn, Frost, Rot, Shock, summons, and relics for Area. The next round (0.21) aims there.
