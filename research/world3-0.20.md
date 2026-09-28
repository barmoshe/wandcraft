# Wandcraft 0.20: the Kernel (research and design)

**Bar's ask (28 Sep 2026):** "Research design, work fully autonomous, improve the story and more NPC, more graphics, more worlds. Do your best." Then, on the plan: "Be creative, be innovative. Research about roguelikes, research about storytelling, research about game hubs."

The plan is `~/.claude/plans/research-design-folio-autonomous-cozy-avalanche.md`, and the decision record is ADR 0028. Five research agents fed this document. Their full, sourced notes are in `research/world3/`:

| File | Topic | Sources |
|---|---|---|
| `world3/1-roguelikes.md` | What's new in roguelites 2024–2026: later worlds, final bosses, meta, mobile run length | 33 |
| `world3/2-storytelling.md` | Story under repetition, twists where the player is the cause, two voices, a World 3 beat outline | 41 |
| `world3/3-hubs.md` | Hubs that grow and feel alive | 30 |
| `world3/4-npcs.md` | NPC design, found NPCs, a proposed cast | 33 |
| `world3/5-graphics.md` | Pixel graphics at 480x270, World 3 palettes, portraits | 40 |

**Caveat:** the proxy blocked page fetches for most game sites, so the agents worked from search-result summaries of the cited pages. Details that rest on one source should be checked before they are quoted outside this repo. Anything marked *[I]* is an inference.

## 1. What the research says (the short version)

### Roguelikes
- **Later worlds feel new when the room structure changes**, not only the enemies (Hades II's open areas with sealed encounters; Slay the Spire 2's alternate acts) [R].
- **Final bosses that use the player's build:** stealing items reads as unfair (Risk of Rain 2); mirroring reads as fair and clever (Inscryption's death cards, Hades II's final boss that rewinds time) [R]. *[I]* Mirror the build, never take it away.
- **Magicraft's warning:** reviews call its last levels too cluttered to track your character. World 3 should be visually quieter than World 2 [R].
- **Mobile:** short, fixed runs win (Megabonk about 10 minutes, Brotato 15–20). Returnal's long runs with no mid-run save were its loudest complaint [R]. Wandcraft saves at every room, so three worlds of about 10 rooms fit *[I]*.
- **Meta without power creep:** unlocks that add options (Dead Cells), cosmetic rewards, and rule-changing modes [R].

### Storytelling
- **Death moves the story on** (Hades), and big story beats outrank chatter in a pool of conditional lines [S].
- **Fact matching** (Valve's GDC 2012 talk): each run writes a few facts, and the most specific line that matches wins. It makes "react to the last run" cheap [S].
- **Twists where the player is the cause** (Braid, Returnal, NieR, Spec Ops) work when the reveal lives in a mechanic the player already trusts, the evidence is the player's own data, guilt is followed by a real choice, and the tone stays warm [S].
- **Two voices** (Disco Elysium's inner voices, Portal 2's pairs): one states, the other interprets; each has a tell it breaks once, late [S].
- **The true ending after N wins, and the epilogue as a state of the hub** (Hades), not a cutscene [S].
- **Found on our own board:** the first win (at Deadlock) already said "revert" and "it was you". World 3 has to take the twist further, not repeat it [S].

### Hubs
- **Every rescue adds a verb or something to see** (Gungeon's Breach, Hollow Knight's Dirtmouth) [H].
- **The hub changes on events, not real time** (Hades II's garden grows per encounter) [H].
- **React to the last run first.** `Hub.greeting` already does this for the Duck and LINT; spread it to the new residents [H].
- **Never block the portal**, and a station's owner is never away when you need the station [H].
- **Phones:** a "!" marker, not forced dialogue; three lines or fewer [H].

### NPCs
- **A want, a quirk, a secret and a change** make a character in 4–6 conversations [N].
- **Rescue with a move the player already uses** (Hollow Knight's shopkeeper, Gungeon's cells), and moving into the hub is the payoff [N].
- **Services add choice or information, never power** [N].
- **Readability at 20 px:** one lopsided prop and a colour no enemy uses; the `glitch`, `threat` and `moss` ramps belong to enemies [N].

### Graphics
- **Palette swaps, colour cycling, dithered fog, procedural decoration and particles** are the cheap ways a small team gets "more graphics" [G].
- **Three light tiers:** a tint per area, a small shift per room mood, and mostly fake additive lights; at most 2–4 real Godot lights per room on phones [G].
- **A digital world that isn't Tron:** show the metaphor's material (paper, brass, ink), put curves on traces instead of neon grids (Transistor), keep one hue for meaning [G].
- **Readability risks for World 3:** a cream floor would erase white bullet cores, so the Archive floor stays dark; threat red on near-black needs a dark halo [G].

## 2. Ideas, scored
Each agent brought 5–8 original ideas. Scored 1–3 on fun, fit with the code-magic theme, cost (3 = cheap) and phone-friendliness.

| Idea | From | Fun | Fit | Cost | Phone | Verdict |
|---|---|---|---|---|---|---|
| An enemy that suspends one of your wand's spells while it lives | R (syscall parasites) | 3 | 3 | 2 | 3 | **In:** the Interrupt |
| Two halves that must die close together | R | 3 | 3 | 3 | 3 | **In:** Data Race |
| The final boss unwinds the stack: echoes of the run's earlier bosses | *[I]* from R and S | 3 | 3 | 2 | 3 | **In:** the Glitch, phase 2 |
| Revert glyphs that rewind the boss and the room's rewrite | S, R | 3 | 3 | 2 | 3 | **In:** the Glitch, phase 3 |
| Revert or fix forward: two endings, the true one earned by knowing the story | S | 3 | 3 | 2 | 3 | **In** |
| The Duck exists because of your bug (log `16:59:01`); LINT warned you and you pushed anyway | S | 3 | 3 | 3 | 3 | **In** |
| The reviewer who approved your commit without reading it | N | 3 | 3 | 3 | 3 | **In:** Grep's secret |
| The archivist is the backup that makes revert possible | N | 3 | 3 | 3 | 3 | **In:** Cache's secret |
| NPCs as orphaned processes your bug left running | S, H | 2 | 3 | 3 | 3 | **In:** as framing |
| The wall clock descends 16:59:57, :58, :59 | S | 2 | 3 | 3 | 3 | **In** |
| Boss "compile" entrance, drawn in row by row | G | 3 | 3 | 3 | 3 | **In** |
| NPC reveal by rows (a code-style arrival) | N, G | 3 | 3 | 3 | 3 | **In** |
| Lost Pages as tiny source files whose comments tell the history | *[I]* | 2 | 3 | 3 | 3 | **In** |
| Hub residents react to the last run | H | 3 | 3 | 3 | 3 | **In** |
| Scheduler rooms (two fights swap on a timer) | R | 3 | 3 | 1 | 2 | Later |
| Regression tests (enemies replay your own recorded run) | R | 3 | 3 | 1 | 3 | Later |
| `git bisect` true-ending runs | R, S | 2 | 3 | 1 | 2 | Later |
| Pull requests as gifting | H | 2 | 3 | 1 | 2 | Later |
| The Workshop compiles itself (missing textures fill in) | H | 2 | 3 | 2 | 3 | Later |
| Walls that syntax-highlight near your spells | G | 2 | 3 | 1 | 2 | Later |

**The innovation bar** (three devices no researched game does the same way): the Interrupt edits your program while it lives; the Glitch's stack unwind and revert glyphs; the true ending gated on a confession, not on a win count.

## 3. The design

### World 3: `kernel()`
- **Where:** below the Foundry, where the bug lives. The same 11-step plan as the other worlds (a per-world plan was considered and dropped: the run already saves at every room, and a third world of about 10 rooms keeps a full win near 30 minutes).
- **Areas:**
  - **The Page Archive** (rooms 0–5): endless shelves of paged memory. A dark ink floor (the Archive floor stays dark so white bullet cores read), paper and amber on wall tops and props, verdigris label plates.
  - **Ring Zero** (rooms 6–10): the Kernel's heart. A near-black void floor with curved brass circuit traces, phosphor pulses, and the Glitch's nest in `nest` magenta (never threat red).
- **Enemies** (each with a counter, all original):

| Enemy | Role | What it does | Counter |
|---|---|---|---|
| **Page Leak** | anchor | Drifts slowly and drips puddles that grow while it lives and slow you inside them. Killing it frees its memory: every puddle it left dries up | Kill it early; don't fight inside its puddles |
| **Dangling Pointer** | pressure | Draws a pointer line toward you, then blinks to the line's end and snaps in a small ring | Step off the line |
| **Interrupt** | support | While it lives, one of your wand's boosts or triggers is suspended (the HUD slot shows a lock, and the wand reads it as empty). It keeps away from you | Kill it first; it is fragile |

- **Mini-boss: Data Race.** Two threads, A and B, lap the arena in opposite directions and burst where their paths cross. When one falls, the other has 3 seconds: if it isn't down too, the first one respawns at 30% HP. The counter is the wand, not the aim: split damage, then finish both.
- **Boss: the Glitch.** Titled "THE GLITCH", subtitled "commit a1f00d, author: you". Three phases:
  1. **Diff** (100–66%): red "−" rows are telegraphed across the arena and burn a moment later; green "+" rows stay safe. It shoots aimed bursts between diffs.
  2. **Stack unwind** (66–33%): the call stack unwinds through the run: echoes of the Loop (two Loop Jr.) and of Deadlock (a sweeping beam) come back in miniature, once each, while it keeps up the diffs.
  3. **Revert** (33–0%): the room is rewritten from the edges inward. The Duck: "Revert it! Grab the old code!" Green revert glyphs appear on the floor one at a time; touching one reverts the Glitch (a chunk of its HP and a stun) and pushes the rewrite back.
- **The world tag** reads W3, the descent screen shows a third frame, the map and pause name the world, and the Kernel has its own music and ambience.

### The story
- **The twist, taken further.** World 2's ending no longer ends the game: Deadlock's fall grants Kernel access and the descent goes on. In the Kernel, the story turns three times:
  - **LINT warned you.** A log entry: `warning: untested change to mana regen. Push anyway? [y/N] y`. LINT's old deadpan "You will not read it" was literal.
  - **The Duck exists because of your bug.** Data Race's fall drops `init: rubber duck. Friday, 16:59:01.` Its warmth was never neutral.
  - **Nobody read it.** Grep, the reviewer who approved your commit, confesses once you reach the Kernel: "I wrote 'looks good to me'. I never read it." The failure was the process, not one person.
- **Two endings:**
  - **Revert** (every win): the Source rolls back to 16:58. The moss closes its eyes, and the Duck goes quiet mid-quack. A final card shows the unpushed commit. It is a win with a cost.
  - **Fix forward** (the true ending): after one win, with all three residents rescued and Grep's confession heard, the Glitch's fall offers a choice. Fix forward keeps what grew from the bug (the moss keeps its eyes, the residents stay, the Duck keeps talking), and the Workshop holds a blameless post-mortem.
- **The commit log** grows from 10 to 16 entries (append only: the voice files depend on the ids). `mkdir /world3` moves from the win to Deadlock's fall, where it now leads somewhere.
- **The clock** on a wall in each world's start room reads 16:59:57, 16:59:58 and 16:59:59. Nobody explains it.
- **The rules** from `research/story.md` stand: a line fits a phone (about 60 characters), no em dashes, one line at a time, never in the way.

### The residents (orphaned processes your bug left running)
Each is found in a run in a new **Resident** room (a door that shows a caged figure). Clear the room and the cage opens: the resident arrives by rows, like code drawing in, says a few words and moves into the Workshop. The door appears in its own world until the resident is rescued, guaranteed in the first rooms of their world.

| | **Grep** (World 1) | **Hotfix** (World 2) | **Cache** (World 3) |
|---|---|---|---|
| Look at 20 px | Hunched bone-grey hermit, moss beard, lantern on a pole | Squat golem of mismatched rust plates, ember core, a white tape X | Tall, thin, violet; a leaning tower of pages on her back; cyan eyes |
| Want | To be left alone; really, to be forgiven | To make one thing that lasts | To finish indexing the Lost Pages |
| Quirk | Takes every question literally | Fixes everything on sight (he has taped the Duck) | Remembers your last run perfectly and forgets anything older |
| Secret | He approved your Friday commit without reading it | He is a Glitch copy who chose to fix instead of break; LINT flags him every time | She is the backup: revert only works because her snapshot exists |
| Service | **Search:** one true hint per run about something you haven't found | **Skin Forge:** wand skins for Bits (looks, never power) | **The Stacks:** the Lost Pages, 12 short source files whose comments tell the Arcanum's history |

- **Arcs:** 4–6 conversations each, picked by conditions (runs since rescue, bosses beaten, pages found, the Kernel reached), with a "!" over them when a new one is ready.
- **Reactions:** each resident has a line for how the last run went (died to a boss, won, quit), as the Duck and LINT already do.
- **The Lost Pages:** once Cache is rescued, each boss and mini-boss drops the next page.

### The Workshop grows
- Three new corners, empty until their resident moves in: Grep by the Bounty Board, Hotfix by the Merchant, Cache by the Compendium.
- A trophy for the Glitch beside the others.
- After the true ending, the post-mortem epilogue: each resident and the Duck and LINT have epilogue lines.

### Graphics
- **Two Kernel themes** in `RoomPainter.THEMES`, with new Style ramps: `vellum`, `quill`, `amber`, `verdigris` (the Archive) and `void`, `brass`, `phosphor`, `nest` (Ring Zero).
- **A backdrop per world:** the Cellar's roots, the Foundry's chimneys and glow, the Kernel's shelves and rings.
- **Sprites:** three enemies, the twins, the Glitch with a look per phase, three residents with idle rigs, and their dialogue portraits in the speech box.
- **Props:** cages, the wall clock, revert glyphs, leak puddles, diff rows.
- **Boss entrances compile:** every boss draws in row by row under a `LOADING` card.
- **Wand skins:** palette and gem swaps on the existing wand drawing.

### Rewards
- New bounties: reach the Kernel, beat the Glitch, rescue each resident, find every Lost Page, the true ending.
- Compendium entries for every new enemy and boss.

## 4. Progress
- `6f846d2` Research and design.
- `a3f0b83` World 3, the residents and the two endings (the art agent's work included).
- `ea22203` Kernel sound, compile-in boss entrances, resident progress, docs; version 0.20.0.
- `baeb611` Voices for the residents and every new line (218 lines in all).
- **Bar's feedback on 0.19 (ADR 0029):** the wizard's wand arm, the third lesson, and triggers as a pack.
- **The Kernel bench** (`BENCH=kernel tools/balance.sh`): each seed starts in the Kernel with a mid-game kit, played by the editing bot without god mode.

| Pass | What changed | World 3 cleared | Data Race | The Glitch |
|---|---|---|---|---|
| 1 | first run; the kit was swapped for a one-spell wand (a bench bug) | 0% (died in room 1) | never reached | never reached |
| 2 | the kit kept; depth scaling slowed past Deadlock | 10% | 48 s | 47 s (one run) |
| 3 | Data Race smaller bursts, no Sentries in the Kernel, the Glitch 3000 HP; a leak stall fixed | 10% | 41 s | 50 s (one run) |
| 4 | Data Race at World 1 bullet damage, the Glitch 3400 HP, pointers snap less | 0% (4 reached the Glitch) | 41 s | none cleared |
| 5 | Data Race threads 440 HP, a 3 s window and a 30% respawn | 0% (3 reached the Glitch) | 53 s | none cleared |

*[I]* The bench bot never dashes and doesn't play Data Race's rule (it shoots the nearest thread, so the other keeps respawning), so these are floors, not a player's odds. The playtest decides the next pass. The first things to try if it's too hard: fewer Dangling Pointers in the pressure pool, and a spring before Data Race.
