# Wandcraft 0.20: the arsenal (spells, relics, wands) and the lessons

**Bar's ask (28 Sep 2026):** "Fix all lessons. Research design, add more relics, add more spells, add more wands."

Two research agents fed this. Their full, sourced notes are in `research/arsenal-0.20/`:
- `6-spells-wands.md` covers Noita, Magicraft, Wizard of Legend, Mages of Mystralia, Magicka, Vampire Survivors, Brotato and Balatro (17 sources).
- `7-relics.md` covers Slay the Spire, Isaac, Hades, Balatro, Risk of Rain 2, Gungeon, Dead Cells, Brotato and Magicraft (19 sources).

The proxy blocked several wikis, so some claims rest on search-result summaries. Anything marked *[I]* is an inference. Mechanics only: every name and every number is our own (ADR 0002).

## 1. The lessons (fixed first)
An audit played every path through the three lessons: both lesson-2 picks, both lesson-3 picks, with and without the extra starting slot. It found three faults.

1. **The coach bumped spells.** It placed the prize first, often onto a spell you already had, which went to the bag, and then asked you to drag it back.
   - Now it moves spells into empty slots first, then places the prize, so nothing is ever bumped.
   - Every step says why: the lesson's reason, then "First, make room: drag X", or "Drag X onto the lit slot".
2. **Lesson 2 offered a boost.** Phase (a boost) left the wand one shooting spell short, which broke the old trigger lesson (Bar's screenshot). It now offers two shooting pierce spells, Needle or Prism Lance.
3. **Every lesson wand ran out of mana.**
   - Empower plus the Mote used 17.8 mana/s against the Twig's 16; lesson 3 wands used 25–31 and ran dry in about 5 s.
   - The Twig now refills 22/s. Lesson 3 offers the cheaper Frost Shard or Chain Spark and teaches the mana bar.
   - Lessons 1 and 2 never run dry. Lesson 3 runs dry after 20–40 s of non-stop casting, which is the point of that lesson.

`test_every_lesson_path_coaches_cleanly` walks all eight paths.

## 2. What the research says (short)
- **Cards that bend the program beat bigger numbers.**
  - Noita's depth is copy spells, "divide by", negative mana, conditions, shuffle and Always Cast.
  - Magicraft puts much of its variety in wand passives, while only 4 of our 12 wands had a rule.
- **Balatro:** a build needs a scaling source and a positional finisher; order matters. For us, "boosts reach what's on their right" is joker order, so cards that move *where* a boost applies are the real rule-breakers.
- **Events read well on a phone:** Wizard of Legend's arcana, and Dead Cells' short buffs after a visible event.
- **Relics** (Slay the Spire, Hades, Brotato):
  - counters that show on the icon
  - drawbacks a build can plan around
  - duos that add a rule, not a number
  - world-scoped pools, so no dead picks
- **Our gaps:**
  - nothing reacted to the player
  - nothing scaled within a room
  - there was no two-spell carrier
  - empty slots did nothing
  - only the Mirror Rod changed the reading order
  - almost no relic read the wand's shape
  - nothing answered World 3's Interrupt, Page Leak, Data Race or revert

## 3. The new cards
**Spells** (14):
- **Counters:** Drill Bit (shields), Zip Bomb (armour), Blue Screen (wards).
- **Carrier and trigger:** Tarball (carries two), Await (the right spell fires at what the left one hit).
- **Boosts that change the flow:** Buffering, Retry, Just-in-Time, End Block.
- **Runes:** Alt+Tab, Autocomplete, Ctrl+Alt+Del.
- **Passives:** Virtual Memory, Cache Hit.

**Wands** (5), each with one rule:
- **Shuffle Play:** a new, visible order each recharge.
- **Pinned Tab:** slot 1 joins every cast.
- **Palindrome Staff:** reads there and back.
- **Double Buffer:** two pages that swap.
- **Recycle Bin:** kills refill its mana.

**Relics** (16):

| Group | Relics | What they do |
|---|---|---|
| Kernel Mode | Graceful Degrade, Swap Space, Thread Join, Undo Stack, Warm Cache | Turn World 3's tricks around; only offered from World 3 on |
| Refactor | Hoisting, Polyglot, Short Circuit, End of Life, Technical Debt (Corrupted) | Read the wand's shape |
| Core | Lazy Eval, Context Switch, Cold Storage, Shared Memory | |
| Merge Commit duos | Cron Job, Superconductor | |

The exact rules, numbers and deviations are in ADR 0030 and the code (`Catalog`, `Relics`).

## 4. Where they live (packs: content, never power)
New cards come in packs at the Merchant, like 0.19's, so a first run's pool stays small.
- **Interrupts** (`irq.pkg`): spells that answer when you're hit, when you miss, when you land.
- **Memory** (`mem.pkg`, after Deadlock): buffers, paging and borrowed mana.
- **Compiler** (`cc.pkg`): where you put a spell matters.
- **Kernel Mode** (`kernel.pkg`, after Deadlock) and **Refactor** (`refactor.pkg`, after the Loop): relic packs.
- **The two duos** join the core pool, since both of their parents are core relics.

## 5. Progress
(Filled in as it lands.)
