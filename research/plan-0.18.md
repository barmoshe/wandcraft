# Wandcraft: next steps after the first playtest (plan for 0.18.0)

## Context
The whole session's transcript has been mined (25–27 Sep).

**Shipped:**

| Version | What |
|---|---|
| 0.14–0.16 | The MVP, design v2 and design v3 |
| 0.17.0 (27 Sep, live, APK built) | Every tester report fixed: Yossi, JM, Rom, Maor, Yoaviko |
| 0.17.0 | World 2, the Overheated Foundry |
| 0.17.0 | Magicraft progression research (`research/magicraft-progression.md`) |

**Bar's open asks, in order:**
1. **"Keep going" on the Magicraft lessons.** This was interrupted after only a survey of the heat code.
2. **"Make the switch between worlds clearer and more fun, improve the storyline, research, design, improve."** This is in progress and uncommitted. HEAD is `16986eb`.
   - **Untracked:** `game/scripts/sim/story.gd`, holding the Duck's lines, a 10-entry commit log, and the intro, ending and world cards.
   - **Modified:**
     - `autoload/events.gd`: a `say` signal.
     - `ui/hud.gd`: the Duck's speech box and `duck_face()`.
     - `world/world.gd`: `_story_on_enter` plus the boss beats.
   - **None of it is tested.** The descent screen isn't written, and `research/story.md`, which `story.gd` cites, doesn't exist.

**Carried over:**
- Yoaviko's "tell me when it's out", which has no mechanism yet.
- The Loop fight is 71 s against a 90 s target.
- Hero sprites on start cards, Codex sample wands, and an animated title.
- `STATUS.md`'s "Next action" section is stale.
- The store is paused by Bar (Apple and Google accounts).

## Progress (2026-09-27, paused by Bar: another session is doing sound v2)
- **Done in the working tree, uncommitted and untested:**
  - `sim/story.gd`
  - The Duck's speech box: `autoload/events.gd` (`say`) and `ui/hud.gd`
  - The story hooks in `world.gd`: `_story_on_enter`, boss entrance and fall
  - The "descend" door: `chapter.gd` `door_options` and INFO, `icons.gd` DOOR_GLYPH
  - `world.gd`:
    - `go_through` emits `ui_request(&"world")`, or switches straight away when there is no listener or it's the bot
    - `enter_next_world()` with `WORLD_BONUS_HP`
    - `_draw_descent()` for the portal
- **Next:** `ui/world_screen.gd`; `main.gd` wiring (`&"world"` in `_on_ui_request` and `_bot_answer`, and the bench's `_answer`); then the rest of Step 1.
- **Coordination:** the sound session owns `autoload/audio.gd`, `tools/gen_*`, `tools/audiosheet.sh`, `research/sound-v2*.md`, and all of `game/assets/audio`. Don't edit those. When committing, stage only this plan's files by path; never `git add -A` while the sound session has uncommitted work.

## Step 1b: Voices (added 2026-09-27)
The Duck and a new robot, LINT, speak real words: Kokoro-82M, pre-rendered and processed per character. The plan is `research/voices-plan.md`; it starts with an audition checkpoint with Bar and needs the sound session to amend its no-voices brief and add a Voice bus.

## Step 1: Finish the story and the world switch (first, since it's half built)
- **Design doc:** write `research/story.md`, the story bible.
  - Premise: the Arcanum runs on the Source. Your Friday 4:59 pm push became the Glitch, and the rubber duck guides you down the bug's stack trace.
  - Cast, beats, the commit log, and the rule that story is one line at a time and never blocks play.
  - Merge the findings from the background research on roguelite story and transitions if it has returned; otherwise note it as pending.
- **Descent portal:** after the Loop, the exit door becomes a portal.
  - In `world.gd`, `_draw_top` gets a swirling ember vortex plus the label "DOWN TO WORLD 2".
  - `Chapter.INFO` / `door_color` get the exit's name and colour.
  - `go_through(exit)` emits `ui_request(&"world")`. `main.gd` opens the new screen, and when it's done calls `world.enter_next_world()`, which is the current `_next_world()` plus the clear bonus of +10 max HP and a full heal.
  - With no listener (tests, the bot or the bench) it switches straight away. `_bot_answer` and the bench's `_answer` handle `&"world"`.
- **New `ui/world_screen.gd`** (extends `Screen`):
  - The left side is a "STACK TRACE": `root_cellar()` is ticked, then `foundry()`, then `kernel() ???`. The hero (`Hero.frames()`) drops from one frame to the next over 1.2 s, with rising embers.
  - The right side shows "WORLD 2", the name in ember, the `Story.WORLD_CARDS` line, "NEW HERE" with `Bestiary.frames()` icons for the Proxy, Kernel Panic and Spark Plug, the carried-over items plus the clear bonus, and a DESCEND button that becomes enabled after the animation.
  - Plays a sting when it opens.
- **Intro panels:** a new `ui/story_screen.gd`, a panel reader with tap to advance and SKIP.
  - The intro (`Story.INTRO`) shows before the first run starts, when `Story.intro_seen()` is false. It's hooked in `main._begin` or `_new_run`, then `Story.mark("intro_seen")`.
  - The ending (`Story.ENDING`) shows on the first win, before `EndScreen`, together with `Story.find_log("win")` twice.
- **End screen:** `EndScreen` shows the Duck's line on a death, via `Story.line("death")` passed in from `main._open_end`. The win subtitle already mentions Deadlock.
- **Codex:** add a LOGS tab (`codex_screen.gd`) listing `Story.logs_found()` against the 10, with "???" for entries not yet found.
- **HUD:** a world tag ("W2") before the map dots, so it's always clear which world you're in.
- **Save:** `SaveGame.record_run` `best_step` → `Chapter.depth(run)`.

## Step 2: The Magicraft lessons ("keep going"), in priority order
1. **Heat changes rules, not HP.** Rewrite `Meta.HEAT` and its uses:
   - **Where it's used:** `world.gd:564` (the +20% HP), `593` (boss HP), `851` (springs), `930` (shot speed), `encounter.gd:90` (elites), `rewards.gd:206` (prices) and `chapter.gd:226` (doors).
   - **The new tiers:**
     - 1: every fight has an elite.
     - 2: enemies move 15% faster, replacing the +20% HP.
     - 3: shots are faster and there's one fewer door.
     - 4: springs heal less and shops cost more.
     - 5: each boss gains an extra move or enrage at 50%, replacing the +25% HP.
   - **Rewards:** each tier adds +10% gold and better spell rarity via `rare_offset`.
   - The title screen's heat line explains the rules.
2. **A no-hit boss bonus.** Beating a mini-boss or boss without taking damage (a boss-room version of `hit_in_room`) leaves a second, gold "UNTOUCHED" orb that holds a rare relic. This reuses the Untouched reward in `Rewards`.
3. **Deadlock works for every build.** Bench single-target and crowd wands against it with a new test, `tests/unit/test_world_two.gd`. Surface what it asks for in its subtitle: "Hit the open lock, dodge the beam".
4. **Rooms under a minute.** Log the time per room in the bench (the RunLog already records `t`), and trim the World 2 wave budget if the average is over 60 s.
5. **The second slot as a goal.** The `slot` unlock already exists in `Meta` under the `runs3` goal. Just verify it and state that in the doc.

## Step 3: Carry-overs (small)
- **The Loop at about 90 s:** try 2000 HP only if the editing bot's World 1 clear rate stays at 50% or higher.
- **Hero sprites on the start cards** (`reward_screen.gd`).
- **"Tell me when it's out":** a title-screen link to a sign-up page. This needs Bar to pick where it goes; it's the one external choice in this plan and is flagged, not built, until he picks.
- **Docs:** refresh `STATUS.md` "Next action"; ADR 0025 (story and world switch); `research/design-w2.md` progress log.
- **Deferred:** Codex sample wands and the animated title.

## Step 4: Ship and playtest round 2
- Bump to 0.18.0 (`tools/bump_version.sh`).
- `tools/build_web.sh` then `deploy_web.sh`, and `tools/build_android.sh`.
- Take screenshots with `tools/shots.sh`: the portal, the descent screen, a Duck line, the intro, and the Codex LOGS tab. Send them to Bar.
- Bar sends the new build to the same testers and asks them about the story and the world switch in particular. `window.wandcraftRunLog()` shows the world for each room.

## Verification
- **Tests:** `tools/test.sh > file; echo exit=$?`. Never pipe it through grep.
- **New tests:**
  - `Story.line` order and the seen tracking.
  - `find_log` beats and the terminal order.
  - The exit leading into the world screen, then World 2 with the clear bonus.
  - Heat tiers change rules, not HP.
  - The no-hit boss orb.
- **Bench:** `tools/balance.sh` (both worlds).
  - Editing bot: World 1 cleared 40–85%.
  - Never-editing bot: 10% or less.
  - Deadlock: 60–150 s.
  - Room averages reported.
- **Visual:** check every new screen with `tools/shots.sh` at 1440×810 and 2556×1179, with the Duck box clear of the thumb sticks and the boss bar.
- **Web:** load the live build in the browser pane, check the console for errors and that the version stamp matches.
- **Commits:** one per step, with the hash logged in the design doc's progress log.
