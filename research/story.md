# Wandcraft: the story bible

Written 2026-09-27 for plan 0.18 Step 1 (Bar's ask: "make the switch between worlds clearer and more fun, and improve the storyline"). The lines themselves live in `game/scripts/sim/story.gd`; this file is the why and the rules. Voices come next, in `research/voices-plan.md`.

## The premise
- **The world:** the Arcanum runs on the Source, one great spell-program. Every tree, torch and door is code.
- **The inciting bug:** on your first day as a spellwright, Friday at 4:59 pm, you pushed one small fix to mana regen. It compiled. Then the moss grew eyes: the Glitch was loose, rewriting everything it touched.
- **The guide:** your rubber duck, the one you debug out loud to, talks back. It is warm, dry and on your side.
- **The shape of a run:** you follow the bug's stack trace down through its frames. That makes the world switch a descent: each world is a deeper frame of the same call stack.

| World | Frame | Areas | Boss | What it means |
|---|---|---|---|---|
| 1 | `root_cellar()` | The Mossy Root Cellar, the Corrupted Grove | The Infinite Loop | The Loop spins the world at 100%. Breaking it drops the world to 99%, and its heat drains down |
| 2 | `foundry()` | The Cooling Vents, the Molten Core | Deadlock | The Foundry forges the world's spells, and runs hot. Two locks wait on each other in front of the Kernel |
| 3 | `kernel()` | The Page Archive, Ring Zero | The Glitch | Where the world remembers, and where the bug lives. Built in 0.20 (`research/world3-0.20.md`) |

**The twist**, told by the commit log and the ending: the bug was your own commit. Copy-Paste's log entry is your commit message word for word. The fix is the oldest spell there is, revert. The Duck's verdict is "Everyone pushes on a Friday".

## The cast
- **You:** a new spellwright. You never speak; the Duck speaks to you.
- **The Duck:** the only voice in World 1, and later one of two (with LINT, `voices-plan.md`). It gives tips, reactions and jokes, and never gives orders.
- **The Glitch:** the bug, never seen whole. Its creatures are copies and corruptions: moss with eyes, copied wands, loops that won't end. Its lines in the log are signed "???".
- **The bosses:** each is a real bug named for what it does.
  - Copy-Paste copies your wand.
  - The Garbage Collector keeps what you throw.
  - The Infinite Loop never stops.
  - Deadlock is two locks each waiting for the other.

## How it's told (the rules)
1. **One line at a time, never in the way.** This is Hades' rule: story is a reward for playing, not a gate in front of it.
   - The Duck speaks in a box at the bottom middle, clear of the thumbs, and waits for room banners to finish.
   - At most two lines wait in the queue, and nothing pauses the game.
2. **In order first, then at random.** Each event plays its lines in order the first time through the story, so the story is told in sequence, then picks among them. Seen counts live in `meta.json` (`story_seen`).
3. **The beats:**
   - Run start: "first_run" on a first run, then "run".
   - Area and world changes: "grove", "world2", "core".
   - Boss entrances ("boss:<title>") and falls ("down:<title>", "down:mini").
   - Deaths: "death", shown on the end screen.
4. **The commit log** is the collectible thread.
   - Seventeen entries since round 2 (ten at first, sixteen after 0.20). Debug Terminals give the plain ones in order, and story beats give their own (`at`: the Grove, the Loop's fall, Deadlock's fall, the win, and later the residents' beats).
   - The Codex LOGS tab lists them, with "??????" for the ones not yet found.
   - Read in order, they tell the twist without a cutscene.
5. **Panels only twice.** The intro shows before a first run and the ending on a first win, four panels each. Tap to go on, and SKIP leaves at once. Each shows once (`intro_seen`, `ending_seen`).
6. **The descent screen** makes the world switch a moment, not a loading screen.
   - The stack trace fills in with `root_cellar()` ticked OK.
   - The hero drops to the next frame, and embers rise.
   - Then the new world's name and line, the enemies new there, and the world-clear bonus (+10 max HP and a full heal).
   - DESCEND lights up once the drop lands.
7. **Plain and short.** A line fits on a phone, at about 60 characters, two lines at most. There are no em dashes. Jokes come from programming, and they should still land for someone who doesn't code.

## Research behind it
The pending research agent on roguelite story and transitions never reported back. These points are from the design discussion, not from sources, and should be read as inference:
- **Hades:** story is paid out per run and per death, and each death advances something. The Duck's death lines and the log follow that.
- **Dead Cells and Hades:** biome transitions are short set pieces with a name card. The descent screen is that set piece, with the stack trace as the map.
- **Slay the Spire, Gungeon:** lore collected piecemeal in a codex rewards curiosity without forcing reading. The LOGS tab follows that.

If the research returns, merge its sourced findings here.

## Progress
- `e0f84c8` Story part 1: `story.gd`, the Duck's box, the story beats in `world.gd`, the descend door.
- `5d18b84` Story part 2: the descent screen (WorldScreen) and its tests.
- Part 3: the intro and ending panels (StoryScreen), the Duck on the end screen, the Codex LOGS tab, the HUD world tag, `best_step` by depth.

## 0.20: the Kernel, the residents and two endings
Bar's ask (28 Sep): "improve the story, more NPC, more worlds". The research is in `research/world3/2-storytelling.md` and `research/world3/4-npcs.md`; the design in `research/world3-0.20.md`. The first win (at Deadlock) had already told the twist, so World 3 takes it further instead of repeating it.

- **Deadlock's fall is no longer the end.** LINT grants Kernel access and `mkdir /world3` (log `c10ud0`) now drops there, where it leads somewhere.
- **The twist, three more turns** (all append-only log entries, so the voice files keep their ids):
  - `5a1e0f` LINT warned you: "Push anyway? [y/N] y". Found on entering the Kernel. LINT's old "You will not read it" was literal.
  - `1a7e57` Grep approved your commit without reading it ("LGTM"). Told in his fourth conversation, once you've been in the Kernel. The failure was the process, not one person.
  - `d0c0de` The Duck was initialised at 16:59:01: it exists because of your bug. Found when Data Race falls.
  - `bac0up` Cache keeps the snapshot from 16:58. Revert only works through her.
  - `fa11ed` a kernel panic (a Debug Terminal's), and `f1x3d0` the fix, written only in the true ending.
- **The clock descends.** Each world's start room has a wall clock: 16:59:57, 16:59:58, 16:59:59. Nobody explains it.
- **The residents** (`game/scripts/sim/residents.gd`): Grep, Hotfix and Cache, orphaned processes your bug left running, one caged in each world. Each has a want, a quirk and a secret, an arc of five beats gated on play (runs since the rescue, how deep you've been, wins, Lost Pages, story flags), a word on the last run, and idle lines. A "!" in the Workshop marks a new beat.
- **Two endings.** Every win at the Glitch reverts: the Source rolls back to 16:58, the moss closes its eyes, and the Duck goes quiet (`ENDING`). With a win behind you, every resident rescued and Grep's confession heard, the Glitch's fall asks first (CommitScreen): REVERT or FIX FORWARD. Fixing forward keeps what grew from the bug (`TRUE_ENDING`), LINT says "I" for the first time ("I approve this commit"), and the Workshop holds a blameless post-mortem (`hub_epilogue`, the residents' `EPILOGUE` lines).
- **The Lost Pages:** twelve tiny source files whose comments tell the Arcanum's history, found one per boss once Cache has moved in, read at her station.
- **Voices:** Grep, Hotfix and Cache each get a Kokoro voice and chain (`research/voices-plan.md`).

## Round 2: companions, barks and arcs (28 Sep)
The NPCs leave the HUD for the world. In a run the Duck waddles beside you and LINT hovers behind as a monitor drone; their lines are bubbles over their heads (about 48 characters reads best, two short lines in combat). Grep, Hotfix and Cache talk in bubbles in the Workshop. The lines and the picking are pure sim (`story.gd`, `residents.gd`, `barks.gd`); the bubbles and the hooks are the lead's.

### Bark rules (`game/scripts/sim/barks.gd`)
Valve's dynamic dialog (rules matched against facts) with Hades' priority buckets. These are design inferences, not sourced findings:
- **A rule** has an event, criteria over a facts Dictionary (a value, or `[op, v]` with `< <= > >= == != in`), a priority, a `once` flag, `carry`, `sets` (memory) and its entries. Remembered facts come along as `mem.<key>`.
- **Picking:** the highest priority wins, then the most specific rule (more criteria), then the earlier one. Entries play in order the first time through (seen counts in `meta.json` under `barks`), then at random.
- **No immediate repeats:** a ring of each speaker's last 3 lines. In a small pool, anything but that speaker's very last line.
- **Cooldowns:** 3 s after any bark and 8 s per speaker, so the Duck and LINT take turns. The Workshop's moments (`hub_return`, `carry`, `lint`) ignore both, and so does a boss changing phase.
- **Carry-over (Hades II's Hecate):** a `carry` rule held back by a cooldown is saved (up to 6, one per event), and `carry_over()` brings the best of them up at the next Workshop visit, then clears them.
- **The post-mortem:** `end_run()` stashes the run's facts before the save counts it (died_to, world, step, depth, won, quit, record, first_win, heat, relics, the wand's rule, pack_new, same_killer, killer_count). `hub_return()` picks from 43 entries (23 rules): the first win (framed, and the frame is called back later), a nemesis (three deaths to the same thing), the same killer twice, a depth record, each boss, a short run, a quit, a new pack, a rule wand, relic hauls, heat, then the generic ones.
- **Combat barks** (40 characters at most, the Duck warm and wry, LINT pedantic and dry): low HP, a fast room, a big hit, an elite, an empty wand, a rule wand's first cast (shuffle, pinned, palindrome, pages, recycle), status builds (burn, frost, rot, shock) and boss phases.

### The log's seventeenth entry: Hotfix's secret
`h07f1x`, "hotfix: mute failing tests. Build green. Friday, 16:59:30." Your push turned the Guild's tests red. The Glitch's first copy did what it was made for and muted them, so Guild CI passed (`b00b1e`) and shipped your bug into the Source. Hotfix has been fixing things ever since, for real this time. It is his sixth beat, told once Grep has confessed and four runs have passed since Hotfix's rescue. The twist now has four authors: you pushed, LINT warned, Grep approved unread and Hotfix hid it. That makes the blameless post-mortem earned rather than generous.

### Arcs
- **LINT's code smells:** `Story.smells(wand)` reads a wand without changing it. It flags no shooting spell, a trigger with no spell to its right, a boost with no spell to its right, the same spell three times in a row, and an empty slot between spells. It follows the wand's reading order and leaves out what the wand's rule makes fine. `Barks.lint_review()` flags the worst smell it hasn't raised yet. When a flagged smell is gone, that counts as advice followed. The third one unlocks LINT's trick.
- **LINT's trick, Red Squiggle:** once a room, LINT underlines one enemy with a red squiggle, the elite or the toughest one on screen. It shows that enemy's next attack a moment early and takes a little more damage from you. It is a reward for listening to the linter, and it is the lead's to wire and tune.
- **Residents:** seven beats each, gated on different things: heat (Grep), skins owned (Hotfix), lifetime runs (Cache), flags (confessed, hotfix_told, fixed_forward), pages and runs since the rescue. Cache's last beat is that she kept Hotfix's commit and never deleted it.
- **Chatter:** 11 overheard exchanges of 2 or 3 lines (`Residents.CHATTER`), between residents and with the Duck and LINT, each gated on who lives there and on story flags. The last one calls back the first: "It wasn't broken." There are also opinions (`Residents.OPINIONS`): what each resident thinks of each neighbour, the Duck and LINT.
- **More lines** for the thin events, a new `archive` event (the Page Archive), and a word for every pack bought (`pkg_bought:<pack id>`).
