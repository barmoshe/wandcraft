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
| (3) | `kernel()` | ??? | ??? | Where the bug lives. The ending teases it: `mkdir /world3` |

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
   - Ten entries. Debug Terminals give the plain ones in order, and story beats give their own (`at`: the Grove, the Loop's fall, Deadlock's fall, the win).
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
