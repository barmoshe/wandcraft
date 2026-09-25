# Wandcraft 1.0 design v2: reinvent the game into the best MVP

- Approved by Bar 2026-09-25 ("Build, do your best"; "You decide what is best, fully autonomous"). ADR 0022. Progress log at the bottom.

## Context
- **What exists:**
  - D0 to D9 are done: art, spells, relics, enemies, levels, animation, bosses, audio, onboarding and store prep.
  - World 1 plays end to end with 56 spells, 38 relics and 11 wands. It passes 184 tests and is live on the web and as an APK.
- **What Bar found on a phone:** the spells and relics weren't clear, and the UI didn't agree with the logic.
- **His call:** everything is open to change.
- **MVP bar:** a friend who has never seen it plays **3 runs without being asked**.

**What the two research passes found:**
- **The audit of our code:**
  - The game shows its rules in one set of words and runs them with others.
  - The editor preview hides boosts, so the core pitch ("my Empower powers my Mote") can't be checked.
  - About 25 player-facing concepts, and about 6 taught.
  - Name collisions: six things are called "Loop", Watchdog vs Watchdog Turret, Merge vs Merge Commit.
  - Mana never matters early.
  - The final boss is shorter than the mini-boss.
  - Meta unlocks cost about 366 fragments and add complexity, not goals.
  - One live bug from today's slot-direction change: Legacy Code still rewards slot index 0 (`spell_runner.gd:192`), which is now the empty left slot.
- **Genre research (sources in the research report):**
  - Magicraft's top complaints are "which spells actually fire?", unclear skill text and grindy meta.
  - Noita players needed an outside wand simulator to understand their wands.
  - Balatro teaches by animating the scoring left to right.
  - Slay the Spire uses one keyword template everywhere.
  - Mobile runs work best at 10 to 15 min.
  - A strong MVP polishes one biome with about 6 enemies, about 20 build pieces and about 15 relics.

**The fix in one line:** less to read, more to see. Any spell is understood in 2 seconds and any wand in 5, by watching it fire.

## Targets (measured at every milestone)
- **First session:** in play within 60 s, first edit within 30 s of the first reward, no more than 3 sentences read before the boss.
- **Runs:** 12 to 15 min. Death to a new run in 3 s or less. The final boss is the hardest and longest fight.
- **Build variety:** 5 archetypes each win in the bot bench (50 seeds). The editing bot wins at least 60%, the non-editing bot 10% or less.
- **Clarity:** a friend can say what their wand does after run 1, and plays run 2 and 3 unprompted.

## Pillars
1. **See it before you cast it.** The in-game wand simulator is the core UI.
2. **One vocabulary, one card template, four shapes.** Enforced by tests.
3. **Your wand is the answer.** Rooms ask a visible question; the wand answers it.
4. **Every hit lands.** Keep D0/D6 feel, and make the program visibly fire in combat.
5. **Short runs with a reason for the next one.** Goals, not grind.

## The redesign, system by system

### 1. Wand model: 4 kinds, every rule visible
- **Four kinds**, each with its own socket shape and frame (the shape reads without text):
  - **Spell** (round): shoots or summons.
  - **Boost** (diamond, with an arrow pointing right): powers up spells on its right until the wand recharges. This covers multicast (Twin, Chorus) and coats.
  - **Trigger** (hexagon): the next spell on its left releases the next spell on its right. Carriers fold in here.
  - **Passive** (square): works from any slot.
- **Debugger runes and the Mirror Rod leave the MVP.** They go to a later unlock. This removes the reversed direction from the MVP entirely.
- **Visible rules everywhere:**
  - Slot numbers 1..N on sockets.
  - Chevrons in the HUD rows too, not just the editor.
  - A bracket under the slots a boost covers.
  - Cast-group bubbles (Cast 1, Cast 2) with the same numbering in the editor, HUD and preview.
  - Mana drawn per wand as number/max with notches per cast.
  - Recharge as a sweep over the row.
- **Editor drops insert, they don't swap.** Spells shift over, so putting a boost in front never kicks a spell into the bag.
- **Mana matters from room 1:** the starter wand plus its first boost overspends, so the sustain bar teaches mana in the first lesson.
- **Engine:** `sim/wand_program.gd` keeps its rules. Only the Legacy Code bug is fixed, and it gets rewritten as "the first spell each cast".

### 2. The workbench editor (the biggest clarity win)
- **Firing range:** a live panel where the wand fires on loop at training dummies (a sandboxed mini-`World` reusing `SpellRunner`). Each slot lights as it's read, left to right, the way Balatro scores. It shows damage per second, mana per cast and whether the wand sustains.
- **Preview as chains:** each cast shows boost icons → spell → payload, with resolved numbers ("Mote 6 → 9 dmg"). Tapping a cast highlights the slots it read.
- **Before and after:** dragging over a slot shows "DPS 42 → 71, mana 12 → 18" in green or red before you drop. Reward cards, the shop and the forge show the same +DPS chip against your current wand.
- **Touch:** sockets are at least 32 px, and the bag is paged at 6 to 8. Tap inspects, drag places; nothing irreversible happens on a tap.
- **Files:**
  - `ui/editor_screen.gd`, rebuilt.
  - A new `ui/wand_sim.gd`.
  - `WandProgram.preview_cycle` and `editor_screen.rotation()` feed the numbers.

### 3. Content: fewer, plainer, each with a job
- **About 24 spells:**
  - 8 spells, 6 boosts (including 2 coats and Twin), 4 triggers (THEN, Callback, Loop, Seed as "Carry"), 2 passives, 2 summons.
  - Ranked by one-line clarity plus bench archetype value. The rest move to a `LATER` list that the Codex unlocks. Saves stay safe through `ALIASES`.
- **About 16 relics**, each either a build-around or something with a visible HUD pip.
  - Plain names, with the theme as flavour. For example, "Garbage Collector" becomes "Mana on Kill" with the old name as flavour text.
  - Invisible "+X% when..." relics are cut.
  - Duos (renamed from Merge Commit) and Corrupted relics appear only after run 3.
- **Wands:** 6 (Birch, Fork Branch and the debug-only Apprentice are cut).
- **One enemy set per biome:** about 6 enemies, each with one idea. Shields, armor and wards each come with a door icon.
- **Name hygiene:** every collision renamed (the Loops, Watchdog, Static, Fork, Mirror, Glitch). A test fails on duplicate words across names.
- **Files:** `sim/catalog.gd`, `sim/relics.gd`, `sim/meta.gd`, `world/enemy.gd`.

### 4. Run shape and variety
- **Route:** 2 areas of 5 rooms. The mini-boss ends area 1, and the boss ends area 2, with 3 phases and about 90 s. The run is about 12 to 15 min.
- **Doors say what the room is and asks for:** "Fight · Spell reward · Shielded foes (bring Pierce)". The room banner shows the area, not the reward.
- **Even reward rhythm:** gold and HP also give a card beat. Every room ends with one tap on an orb, one choice, then the door.
- **3 heroes** replace the Twig/Stub pick. Each has a starter wand and one twist, for example Apprentice, Pyromancer and Tinkerer (triggers cheaper). The first run offers only the Apprentice, with no fake locked card.
- **Files:** `sim/chapter.gd`, `sim/run_state.gd` (`LOADOUTS` becomes heroes), `world/encounter.gd`, `ui/map_screen.gd`, `world/boss_loop.gd`.

### 5. Onboarding: show, don't tell
- **The first run keeps 3 lessons,** but each is a 20-second puzzle: a dummy that dies only to the right edit.
  - Boost lesson: Empower on the left of the Mote.
  - Mana lesson: an overspending wand, fixed by a passive.
  - Trigger lesson: THEN between two spells, in one insert.
- **Coach:** a ghost-hand drag animation replaces the paragraph.
- **Everything else appears on first contact,** one tip each through the existing `Hints`: statuses with a pip legend, Overclocked as floating text, heat, relic rarities.
- **Files:** `sim/tutorial.gd`, `ui/hints.gd`, the coach in `ui/editor_screen.gd`.

### 6. Combat readability and controls at phone size
- **HUD:** a larger active-wand strip where the lit slot pulses on each cast. Tap a relic to read it in-run. Relic counters stay.
- **Controls:**
  - Keep the floating stick, auto-fire and aim assist.
  - A wand-swap button near the right thumb.
  - DASH moved out of the aim zone.
  - An optional right-stick aim override.
- **Audit at 2556×1179:** telegraphs lead by at least 0.5 s, bullet colours stay in the reserved threat red, boss bars get phase ticks.
- **Bosses scale by new attacks, not HP.**
- **Files:** `ui/hud.gd`, `ui/touch_controls.gd`, `world/player.gd`, `world/boss_*.gd`.

### 7. Reasons to play again
- **End screen:** your final wand (the row), 3 stats, what unlocked and the **next goal** ("Win with a Burn build: unlocks the Pyromancer"). NEW RUN is focused.
- **Goals replace the fragment tax:** 12 to 15 goals, each unlocking a hero, wand or spell, with an early one in every run. The Codex becomes a collection book: what you've found, a sample wand for each item, your best runs.
- **Daily seed:** an offline run seeded by the date, with your best time and score.
- **Bug Reports (heat)** show from run 2.
- **Files:** `ui/end_screen.gd`, `sim/meta.gd`, `ui/codex_screen.gd`, `sim/save_game.gd`.

### 8. One vocabulary and one skin
- **Glossary** (about 10 words): cast, recharge, mana, spell, boost, trigger, passive, pierce, blast, shock. Long-press any bold word to see it.
- **Banned words in player text:** rotation, cycle, payload, carrier, MP (except as a unit), "L3".
- **One card template:** name, kind chip, a one-line effect with exact numbers (cast delay and recharge included), then keywords.
- **One button hierarchy and one text scale.**
- **Tests:** `test_copy` grows to cover banned words, duplicate names and fit.

## Milestones
Each milestone ships web + APK for Bar, commits per step, and is logged in STATUS.

- **R0: bug fix and design bible v2.**
  - Fix Legacy Code, with a test.
  - Write `research/design-v2.md` (both reports plus this plan) and ADR 0022.
  - Bar approves the cut lists (spells, relics, wands), hero names and the glossary before R1.
- **R1: model and vocabulary.** The 4 kinds and socket shapes, slot numbers, HUD chevrons, boost brackets, per-wand mana, insert-drop, renames, glossary, banned-word tests.
- **R2: the workbench.** Firing range, chain preview, before-and-after deltas, the +DPS chip on rewards, the shop and the forge.
- **R3: content cut and archetypes.** 24 spells, 16 relics, 6 wands, 6 enemies with door icons; the bench shows 5 winning archetypes.
- **R4: run shape and heroes.** 2×5 rooms, the 3-phase final boss, honest doors and banners, 3 heroes, an even reward rhythm.
- **R5: onboarding v2.** Puzzle lessons including mana, the ghost-hand coach, first-contact tips.
- **R6: combat HUD and controls.** Pulsing slots, in-run relic taps, a swap button, DASH placement, the telegraph and boss audit.
- **R7: replay.** End-screen recap and next goal, the goals system, the Codex book, the daily seed.
- **R8: friend playtest.** 2 or 3 people play the web build unassisted. Log observations, fix the top 5, tag 1.0.

## Verification
- **Tests:** `tools/test.sh` green on every step. New tests:
  - the simulator matches live combat damage within 10%
  - Legacy Code
  - insert-drop
  - glossary and banned words, duplicate names, card fit
  - hero loadouts, goals, daily seed determinism
- **Bench:** `tools/balance.sh` checks the win-rate and archetype targets. The onboarding runs check first edit ≤ 30 s and first trigger ≤ 90 s.
- **Screenshots** at 2556×1179 and 1440×810 for every changed screen (`tools/shots.sh`), sent to Bar.
- **Deploy:** web via `tools/build_web.sh` and `tools/deploy_web.sh` (check the live stamp), APK via `tools/build_android.sh`.
- **The real test (R8):** friends play https://wandcraft-test.vercel.app and the APK without help.

## Decisions (made autonomously under Bar's grant, 2026-09-25)
1. **The MVP pool (the "core")** is what a new player meets. Everything else stays in the code and comes back as unlocks earned by goals (R7).
   - **Spells (26):**
     - Spells: Arcane Mote, Needle, Prism Lance, Spectrum Fan, Seeker Moths, Ember Bolt, Frost Shard, Chain Spark, Rune Burst.
     - Summons: Watchdog Turret (renamed Turret), Daemon.
     - Boosts: Empower, Twin Cast, Keen Edge, Seek, Phase Through, Wide Rune, Ember Coat, Frost Coat, Static Coat.
     - Triggers: THEN, Callback, While Loop (renamed Repeat), Payload Seed (renamed Carry).
     - Passives: Mana Well, Heat Sink.
   - **Relics (18 plus 4 Corrupted and 2 Duos):**
     - Hot Patch, Garbage Collector, Compound Interest, Leech Loop, Buffer Overflow, Try/Catch, Recursion Charm, Wide Aperture, Null Pointer, Cascade Failure, Wildfire, Cold Boot, Event Loop, Off-by-One, Tail Call, Loop Counter, Stack Trace, Surge Protector.
     - Corrupted: Race Condition, Memory Leak, Force Push, Legacy Code.
     - Duos: Thermal Throttle, Zero-Day.
   - **Wands (6):** Twig, Stub, Old Oak Staff, Crystal Wand, Chorus Harp, Daemon Rod.
   - **Later (unlocks):**
     - The Debugger runes and the Mirror Rod.
     - Pipeline, Fork, Finally, Sleep, Ping, Starwheel, Hex Cursor.
     - Bitrot and Rot Coat.
     - Mirror, Chorus, Split, Gravity, Orbit, Reverse, Siphon, Heavy, Long Range, Ricochet.
     - Disc, Mine, Static Cone, Null Orb, Firewall, Duck, Watchdog.
     - The remaining relics and wands.
2. **Heroes:**
   - **Apprentice:** the Twig, with a Mote in the last slot. Balanced; always available.
   - **Pyromancer:** the Stub, with an Ember Bolt. Burns last 50% longer and hit 25% harder. Unlocked by defeating the mini-boss.
   - **Tinkerer:** the Twig, with Carry and Rune Burst. Triggers and carried spells cost 30% less mana. Unlocked by the first win.
3. **Debugger runes and the Mirror Rod** are later unlocks, not cut: the code and tests stay.
4. **A daily seed run is in the MVP** (cheap, offline).
5. **Name collisions** get player-facing titles only (ids stay, so saves and icons keep working):
   - While Loop becomes Repeat.
   - Leech Loop becomes Leech Charm.
   - Event Loop becomes Echo Chamber.
   - Loop Counter becomes Tally Charm.
   - Merge Commit becomes Duo.
   - Glitch Needle becomes Needle.
   - Watchdog Turret becomes Turret.
   - Static Coat becomes Spark Coat, and the status is called "charged".

## Progress log
- R0 `04ef811`: Legacy Code rewards the wand's last slot, with a test.
- R1+R2 `5b4d483`, `1fb131d`: workbench editor with the WandLab firing range (measured damage/s, before > after on drag, cast chains, lit slots), four kinds with socket shapes, insert-on-drop, glossary (editor ? and pause HOW IT WORKS), renames, banned-word and duplicate-name tests, +damage/s chips on reward cards; HUD chevrons, lit casts, mana now/max, SWAP button.
- R3+R7 `5248ab4`: core pool (26 spells, 24 relics, 6 wands), 13 goals replace Source Fragments, three heroes (Apprentice, Pyromancer, Tinkerer), Codex as a goals book, end screen names the next goal; screenshot runs keep their save in memory.
- R4 `4aad090`: 2 areas of 4 rooms; threat badges on doors and the map, banners say what to bring; swarm rooms are packs.
- R5+R7 `a08f67e`: ghost-hand coach, one-hero starts skipped, daily run, Brood Stump brood of 10 (a bench stall).
- `62402c0`: Starwheel sprays in a spiral (Bar's report: it scattered); tap a relic to read it; wrapped toasts.
- Bench (core pool, 10 seeds): editing bot 80%, never-editing 0%, mini-boss 52 s, boss 57 s, no stalls.

