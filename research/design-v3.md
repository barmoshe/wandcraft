# Wandcraft design v3: look and sound finished, fights and runs that differ

## Context
- **Where we are:** design v2 (0.15.0, ADR 0022) is live, with all tests passing and pushed.
  - It fixed clarity: the workbench with its firing range, four kinds, one vocabulary, goals, heroes, threat doors, and the ghost-hand coach.
- **Bar's asks:**
  - "Research, design, renovate and reinvent all aspects, the best MVP you can, plan first."
  - Asked what's weakest, he answered: **it looks and sounds unfinished.**
  - **Constraint:** assets stay **code-generated only**, with no packs.
- **MVP bar (unchanged):** a friend plays 3 runs without being asked.

**What the new audit (0.15.0) found:**
- **Combat reads as generic next to the title screen.**
  - Enemies are 10–14 px blobs, the green enemies sit on a green-flecked floor, and the forest border is mostly empty.
  - Normal kills get no hit-stop.
  - The program only visibly fires in the editor.
- **Bosses don't feel like bosses.**
  - Copy-Paste is a recoloured hero, and its copy mechanic is invisible.
  - The Loop reads as a small lizard. It lasts 57 s against the mini-boss's 52 s, and phase 3 cuts its moves.
  - There's no intro or arena change.
- **Runs 2 and 3 are the same as run 1:**
  - One enemy set for both areas, two waves per room, and two fixed bosses.
  - Heat is numbers only.
  - Goals mostly widen the pool.
- **Economy:**
  - Shops buy one thing and heals are automatic, so neither is a decision.
  - Evolutions are out of reach; Singularity can't be built from the core.
  - The damage/s chip favours shooters over boosts (clustered, unshielded dummies).
  - The end screen is only text.
- **Phones:** the stress tick is 8–9 ms on the Mac against a 10 ms budget, the effect caps are high, and the firing range steps the world 24 times a frame.

**What the research says** (sources in `research/design-v3.md` at the start of the work):
- **Vlambeer's "Art of Screenshake"** (Nijman 2013) is a checklist of small feel tweaks: kick, sleep frames, lingering corpses, big bullets.
- **Readability** (Kubodera 2022): a telegraph is pose + flash + sound; enemy effects must never look like the player's.
- **Enemy roles:** give each enemy a purpose, a counter and a role in a group (Level Design Book; McMackin 2017).
- **Bosses:** one new idea per phase, learnable in a death (Dunlop 2024). Music comes in layers and goes full band for bosses (Korb/Hades).
- **Builds and rewards:** no dead picks, "every card has a place" (Giovannetti, GDC 2019). Evolutions come as a maxed spell plus a catalyst (Vampire Survivors).
- **Risk and progress:** risk doors (Hades Chaos and Erebus gates), progress on every run, and an opt-in easy mode (Hades God Mode).
- **Haptics:** one pattern per cause, used sparingly (Apple HIG).

**The goal:** make every second on screen look and sound finished, and make runs 2 and 3 play differently. Then prove it with a playtest.

## Pillars (v3)
1. **It looks finished.** Readable at phone size, a distinct identity for each area, and every effect built on purpose.
2. **It sounds finished.** A living mix: layered adaptive music, sound by element, and a boss theme for each boss.
3. **Every hit lands, visibly your build.** The program fires in combat, and boosted shots look boosted.
4. **Bosses are events.** An intro, readable phases, and a spectacle to finish.
5. **Run 2 is not run 1.** New enemies per area, varied room goals, a boss pool, decisions in shops and on healing.

## Milestones (each ships web + APK for Bar, commits per step, STATUS log)

### V0. Playtest log + phone budget (small, first)
- **Hidden run log:** `user://runlog.json` records rooms, time per room, deaths ("killed by" from `player.last_hurt_by`), edits, picks and skips. A debug page reads it. This feeds R8, and the friend playtest is scheduled with Bar.
- **Mobile effect caps:** halve the `fx_layer.gd` caps on touch devices. `WandLab.PROBE_STEPS_PER_FRAME` goes from 24 to 6 on phones.
- **Stress test:** its ratio assertion is kept, and a web build check runs in the browser pane.

### V1. Art direction v3: readable and bold (the biggest lever)
- **Scale:**
  - The world camera zooms in so the room fills most of the screen (the dead forest border goes).
  - The hero, enemies and bosses get redrawn rigs at larger size (enemies about 1.6x) in `art/bestiary.gd`, `art/hero.gd`, `art/rig_baker.gd`.
  - The pixel-perfect scale is kept (an integer upscale of rig parts, not a blurred zoom).
- **Colour roles,** extending `art/style.gd`:
  - anchors warm, pressure cool, elites with their affix outline
  - enemy shots in the reserved threat red only
  - player magic in its element colours
  - Floors drop a value step so actors pop. There's a per-role silhouette check in `tools/artsheet.sh`.
- **Two areas that look different** (`world/room_painter.gd`, `world/ambient.gd`, `art/props.gd`):
  - **The Mossy Root Cellar:** cool stone, roots, dripping moss, warm torch pools.
  - **The Corrupted Grove:** violet rot, glitch-pixel foliage, floating debris, flickering light, a scanline shimmer on walls.
  - Each gets a set of props (clusters, not scatter), foreground canopy parallax, ambient creatures and fog.
- **Room features tie to threats:** armor doors get spore pods, ward doors get rune pylons, shield rooms get cover pillars.

### V2. VFX and juice v3 (the Vlambeer checklist, audited item by item)
- **Per-element projectiles and trails** (`art/projectiles.gd`): arcane, fire, ice, shock, rot, pierce.
  - Muzzle flashes per element.
  - Impact bursts per element (`world/fx_layer.gd`).
  - Deaths per element: burn-out, shatter, zap-dust.
  - Corpses and debris that linger (capped).
- **Hits:**
  - 2–3 frames of hit-stop on normal kills (today only crits and elites get it).
  - Screen kick opposite the firing direction.
  - Shake that scales with the hit's boosted damage.
  - Damage numbers styled by crit, boosted and element.
- **Readability budget:** past 25 player projectiles, player effects fade to 50%. Telegraphs follow one standard: pose + flash + sound, at least 0.4 s (`world/enemy.gd`).
- **The program fires in combat:**
  - A cast banner over the wand row ("EMPOWER > MOTE x2", icons, 0.6 s).
  - A trigger link line drawn from a spell to what it releases.
  - Boosted shots get a gold rim.
- **UI motion:**
  - Screen fades and wipes between rooms and menus.
  - Reward cards flip in, one after another.
  - The chosen card flies to the bag or wand.
  - The orb opens with a burst.
  - The editor socket snaps.

### V3. Bosses as events
- **Intros:** a camera pan, a name card with a subtitle, the music drops out and in, and an arena light change. Each boss has 3 phases with one new idea per phase. Phase changes get a banner, a shockwave (it exists) and an arena change.
- **Copy-Paste becomes a glitched mirror-mage** with its own rig. A floating clipboard shows **your copied spell icons** ("COPIED: EMBER BOLT x3") before it casts them.
  - Phase 2 casts your wand reversed, which teaches left-to-right order.
  - Phase 3 splits into ghosts.
- **The Infinite Loop becomes a large serpent of glowing code blocks**, about 3x its current size, with an armoured head and bright exposed joints that take damage.
  - Phase 3: the arena shrinks and a wand-reading bite arrives.
  - Target 90–150 s, with HP scaled toward the build's measured damage/s (the WandLab probe) so it's never a slog.
- **A second mini-boss for the pool: "The Garbage Collector"**, a hulking bin-golem that eats your projectiles and spits them back until you use Blast.
  - Runs pick between Copy-Paste and the Garbage Collector.
  - The goal "Defeat both mini-bosses" unlocks it.

### V4. Audio v3 (generated, `tools/gen_music.gd`, `tools/gen_audio.gd`, `autoload/audio.gd`)
- **Synth upgrades:**
  - Stereo, with a delay and reverb send.
  - Chorus on pads, sidechain pump.
  - Noise-based textures: wind, drips, glitch crackle.
  - Sample-accurate humanisation.
- **Music:**
  - Longer cues with A/B/breakdown sections and variations, so no loop repeats inside a room.
  - Adaptive layers: ambient between waves, drums only while enemies live (Korb's rule), lead on elites and threats.
  - A theme for each area and each boss, with a finale layer for the final phase.
  - Victory and defeat stings with a musical tail.
- **SFX:**
  - Element layers: a cast, a hit and a death per element.
  - Distinct enemy vocal chirps per role (a telegraph cue).
  - UI set: card flip, snap, swoosh.
  - An ambience bed per area.
  - LUFS mastering is kept.
- **Haptics:** one pattern per cause, used sparingly, following Apple's rules (a settings toggle exists).

### V5. Screens v3
- **One skin:** grimoire frames and the button hierarchy on every screen. The three button layouts become one helper in `ui/screen.gd`.
- **Hero select:** the heroes' own animated sprites, a twist line, and the lock shown as its goal.
- **End screen:** your final wand row, "Killed by: Hex Weaver, room 7", the best cast of the run, goals done, the next goal, and one tap to a new run.
- **Title:** animated, with the area vistas and the daily run's rule.
- **Relics get plain names with the joke as flavour** ("Mana on Kill", *Garbage Collector*). The Garbage Collector boss takes that name once it's free.
- **Wording:** DEPRECATE becomes BAN, and Bug Reports becomes Heat.
- **Codex book:** each item shows a sample wand and the "???" entries still undiscovered.

### V6. Runs that differ (gameplay depth from the audit)
- **The Corrupted Grove gets its own enemies:**
  - a Rot Weaver that fires lines
  - a Bramble Crawler that lays thorn trails
  - a Blink Tick that teleports

  Each has a purpose, a counter and a role on a rule sheet in `research/design-v3.md`.
- **Room objectives** in `world/encounter.gd`:
  - an ambush (enemies spawn around you)
  - a summoner ("kill the Brood Stump and the rest flee")
  - defend a pylon
  - a dark room lit only by your spells
  - a timed elite
- **Economy:**
  - The shop gets a reroll (10 gold, rising), selling a spell for half, and one discounted item.
  - Skip pays 15 gold.
  - The per-room heal drops to 4. Springs offer 40% heal or a free reroll.
- **One risk door per run:** clear it without a hit for an upgraded reward; if you're hit, you get a small consolation.
- **Power spikes:**
  - A Compile needs level 2 plus its catalyst.
  - The mini-boss drops the catalyst for a base spell you own.
  - Singularity becomes reachable (Gravity joins the core), or leaves the list.
- **The damage/s chip** measures against the room's threat (moving and shielded dummies) and shows a boost as "x1.25 to the spells on its right".
- **Heat becomes mechanical:** tiers add an affix, a boss move, one fewer door.
- **Daily run:** a rule of the day (a fixed hero plus a modifier) and a shareable result line.
- **Goals become experiences:** a hero, a boss variant, a room type. "Play 3 runs" splits into three goals.
- **An opt-in "Gentle" mode:** +2% damage resistance per death, capped at 40%, never shamed.

### V7. Store refresh + R8 friend playtest
- **Store:** fresh screenshots at 0.16 (`tools/store_shots.sh`), and the store copy updated.
- **Playtest:** Bar sends the web link to 2–3 friends, and the run log gives the numbers. The top 5 findings get fixed, then 1.0 is tagged.

## Order and sizing
1. V0, then V1 and V2 together (presentation first, since that's Bar's complaint).
2. Then V3 bosses, then V4 audio.
3. Then V5 screens, then V6 depth.
4. Then V7.

Each milestone ends with screenshots at 2556×1179 and 1440×810 sent to Bar, plus a live web deploy.

## Verification
- **Tests:** `tools/test.sh` green at every step. New tests:
  - the run-log schema
  - mobile caps applied
  - hit-stop on kills
  - boss phase counts and length (the bench targets 90–150 s)
  - mini-boss pool selection
  - room objectives complete
  - shop reroll and sell
  - risk-door outcomes
  - compile at level 2
  - heat mechanics
  - relic flavour-name vocabulary (`test_copy` bans jargon in titles)
- **Bench** (`tools/balance.sh`, core pool): the editing bot wins 60–85% and the never-editing bot 10% or less. Mini-bosses 40–80 s, the final boss 90–150 s, no stalls.
- **Art:** `tools/artsheet.sh check` passes the value and silhouette tests, including enemy-versus-floor contrast in both areas.
- **Performance:** the stress ratio test, plus a web-build frame check in the browser pane at 4:3 and 19.5:9.
- **Audio:** the loudness meter and licence tests pass, and a preview of every new cue goes to Bar for audition.
- **The real test:** the friend playtest on the live web build and the APK.

## Sources (research pass, 2026-09-26)
- Nijman, The Art of Screenshake (INDIGO 2013): https://www.youtube.com/watch?v=AJdEqssNZ-U ; Wawro, Game Developer, 2014-01-02: https://www.gamedeveloper.com/design/vlambeer-co-founder-shares-advice-on-building-better-action-games
- KirbyKid, Vlambeer Scale (2015-06-11): https://designoriented.net/blog/2015/06/11/2015611vlambeer-scale-on-vlambeer-games/
- Crooks (Dodge Roll) Q&A, Game Developer, 2016-04-19: https://www.gamedeveloper.com/design/q-a-the-guns-and-dungeons-of-i-enter-the-gungeon-i-
- McMackin, Spartaga deep dive (2017-08-31): https://www.gamedeveloper.com/design/game-design-deep-dive-making-i-spartaga-i-a-vr-twin-stick-shooter
- Level Design Book, enemy design: https://book.leveldesignbook.com/process/combat/enemy
- Kubodera, Readability in ARPGs (2022-04-19): https://www.gamedeveloper.com/game-platforms/designing-for-difficulty-readability-in-arpgs
- Dunlop, Boss design principles (2024-04-04): https://plasmabeamgames.wordpress.com/2024/04/04/boss-design-principles/
- Giovannetti, Slay the Spire, GDC 2019: https://media.gdcvault.com/gdc2019/presentations/Giovannetti_Anthony_SlayTheSpire.pdf
- Bénard, Dead Cells, GDC 2019: https://media.gdcvault.com/gdc2019/presentations/Benard-Sebastian-DeepCells.pdf
- Hades God Mode: Franzese, Inverse (2021-08-11): https://www.inverse.com/gaming/hades-god-mode-interview
- Hades music (Korb): https://gameplay.co/hades-game-music-sound-design-darren-korb-supergiant-games/
- Magicraft endgame clutter, Steam (2024-07-15): https://steamcommunity.com/app/2103140/discussions/0/6982351752477252742/
- Apple HIG, Playing haptics: https://developer.apple.com/design/human-interface-guidelines/playing-haptics
- Jonasson & Purho, Juice It or Lose It (GDC Europe 2012): https://www.gdcvault.com/play/1016487/juice-it-or-lose

## Progress log
