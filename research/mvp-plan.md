# Wandcraft MVP plan: from POC to a store-ready World 1

- Approved by Bar: 2026-09-24. The decision record is ADR 0010, and the evidence is in `mvp-research.md`.
- This file is the working plan. Milestone progress is tracked in `STATUS.md`, and any change to scope needs an ADR.

## Context
Bar: "treat this as a POC and let's create MVP. The MVP will be better in every aspect. Research the design and plan."

**Where the POC (v0.4.1) stands.** It works: World 1, 40 spells, 28 relics, 6 enemies, 2 bosses, 69 tests, and web and APK builds. An honest audit found:
- **The core pitch is optional.** The balance bot never opens the wand editor and still survives 70–80%.
- **The player has few verbs.** Move plus auto-fire; one thumb plays the game.
- **Runs are short.** About 4 minutes of combat, linear, 5 layouts, no meta-progression.
- **`world.gd` is a god object** (1,431 lines). Relic effects are 31 scattered `has_relic` checks. Content is positional code tables.
- **The UI is hand-placed.** 102 `Rect2`s at an 8 px base, no `tr()`, no layout or text scale.
- **Art and audio hit their ceilings.** Enemies animate in 2 frames. Audio is a 22 kHz synth with three 35 s loops.
- **Nothing has been measured on a device**, and none of the store work is done.

**Research** (three sourced briefs, in `research/mvp-research.md`). The key lessons:
- **Automate the trigger, program the wand** (Soul Knight, Archero, Brotato).
- **Keep the wand a linear timeline, with a live "what this fires" preview.** Noita players built outside simulators, and about 30% never reached wand editing.
- **First wand edit within 2 minutes.**
- **Runs of 12–18 minutes, split into 1–2 minute rooms**, with door rewards on a branching map that rejoins (Hades, Slay the Spire).
- **Meta unlocks new content, not stats** (Balatro unlocks 45 of 150 items; stat grind is Archero's flaw).
- **Back in a run within 3 s of dying.**
- **Enemy bullets in a reserved, readable style.**
- **Premium works on phones:** Balatro, Dead Cells and Brotato show it.
- **Engine and web:**
  - Use the Compatibility renderer everywhere.
  - Keep the web on Stream audio (Sample mode still crashes iOS Safari, #116750).
  - Build for TestFlight on GitHub `macos-26` runners with fastlane and an API key.
  - Google Play's closed test (12 testers for 14 days) is still required.

**Bar's decisions (fixed):**
- **Finish line:** a store-ready World 1.
- **Art:** keep it drawn in code, but raise the ceiling.
- **Audio:** CC0 sound effects plus free-licensed music (CC0, or CC-BY with a credit).
- **Budget:** $0. The only unavoidable costs are Apple ($99/yr) and Google Play ($25). Everything is built to store standard for free; submission sits behind a gate marked "needs the accounts".
- **Caveat:** the public store launch also needs World 2, because App Review won't approve an unlock purchase for content that doesn't exist. So the MVP ends at live betas with the purchase flow verified.

## MVP definition (World 1)

### Run
- **Length:** 12–18 min. Rooms take 60–100 s, with a save at every room.
- **Map:** 3 lanes that rejoin, about 11 nodes. The route: 3 rooms → an elite or risk node → mini-boss → 3 rooms → rest or shop → boss.
- **Doors:** every door shows its reward, reusing the `Chapter.POOL` idea.

### Content
| Area | POC → MVP |
|---|---|
| Fight layouts | 5 → 12, plus 4 special rooms and 2 boss arenas |
| Enemy archetypes | 6 → 8: the 6 redesigned plus 2 new (a shield-bearer that punishes single-bolt wands, a splitter that rewards area damage) |
| Animation | idle, move, telegraph, attack, hurt and death, 4–8 frames each |
| Elite affixes | 3 new: Armored, Hasted, Forked, each with an outline shader |
| Bosses | Copy-Paste: 2 phases × 3 attacks. The Infinite Loop: 3 phases, 5 attacks, an intro and a death sequence. |
| Spells | 24 at the start, 16 unlockable, plus 3 "Debugger" runes (the signature twist from ADR 0002) |
| Relics | 20 at the start, 16 unlockable |
| Loadouts | 2 at the start, 3 unlockable |

### Player verbs
- **Floating move stick.**
- **Auto-fire**, aimed in a 30° cone with a visible lock marker. Manual twin-stick aim becomes an option.
- **Dash (new):** 0.22 s of invincibility, 1.1 s cooldown.
- **Tap a wand row** to switch wands, plus the editor button.

### Meta-progression
- About 30 unlocks, each with a visible condition, shown in a Codex ("X/30").
- Shards from every run can buy items directly.
- Corruption difficulty tiers 1–3 after the first win.
- Pace: roughly one unlock every 1–2 runs.

### Onboarding
- A scripted first run hands you a boost at about 0:50, and the editor coaches the drag.
- It hands you a trigger at about 1:40.
- Measured by test: the first edit happens by 120 s of game time and the first trigger by 180 s.

### Editor
- A linear timeline with slots of 44 pt or more.
- Drag or tap to place; long-press pins the tooltip.
- A live readout built from `WandProgram`, for example "Ember Bolt ×2 → on hit: Rune Burst".
- A firing-range dummy that shows DPS and mana per second.

### HUD and UI
- UI draws at native resolution, integer-scaled pixel panels, everything inside the safe area.

### Accessibility
- Text at 100, 150 and 200%.
- Enemy bullets in a reserved shape and colour family, with 3 colourblind presets and high contrast.
- A shake slider, flashes off, hit-stop reduced or off, haptics off.
- A control layout editor, a left-handed mirror, and a deadzone setting.

### Quality bars
- **iPhone 15 Pro Max:** 120 fps in a normal fight, 90 fps or more under stress (45 enemies, 1200 bullets).
- **Mid-range Android:** 60 fps, with p99 frame time under 20 ms.
- **Sim tick:** 4 ms or less on the device.
- **Load times:** cold start 3 s or less (5 s on Android); death to a new run 3 s or less.
- **Size:** AAB 40 MB or less; web 20 MB or less compressed.
- **Stability:** a 200-run bot soak with no crashes; memory 400 MB or less; 20 minutes of play without thermal throttling.

## Architecture: rebuild in place, inside `game/`
Rebuild in place instead of starting a new folder. Most of the value carries over:
- the wand engine and its tests
- the tools and export presets
- the web fixes
- git history

New modules take over piece by piece behind the existing seams (`ui_request`, `auto_step`, bot). Each old file is deleted in the milestone that replaces it, and tests stay green on every commit.

**Kept:**
- `sim/wand_program`, `wand_state`, `mods`, `cast_node`, `save_game`
- `world/bullet_pool`, `spatial_hash`
- `art/style`, `pixel_art`, and the icon files
- all of `tools/*.sh` and `tools/web/`
- `Game.fit_pixels`, the safe-area bridge, and the iOS touch-id handling

**The new layout:**
- `scripts/content/`: definition classes (`SpellDef`, `RelicDef`, `EnemyDef`, `AttackDef`, `EliteAffixDef`, `EncounterDef`, `RoomDef`, `BiomeDef`, `UnlockDef`) plus a `ContentDB` autoload that loads and validates them.
  - `content/`: the data as `.tres` text files. `RoomDef` keeps ASCII rows as data and renders them through a `TileMapLayer`.
- `scripts/sim/effects/`: `Stats` (stat modifiers) plus `Hooks`: `on_room_enter`, `on_cast`, `on_hit_dealt`, `on_hurt`, `on_kill`, `on_dash`, `on_heal`. These replace the 31 `has_relic` checks. Relic ids stay the same so saves keep working, and each relic gets a parity test.
- `scripts/sim/`, new files:
  - `map_gen.gd` (from `chapter.gd`)
  - `meta/` (Profile, unlock evaluation)
  - `editor_model.gd` (place, move and revert commands, shared by the UI and the bot)
- `scripts/world/`:

| File | What it does |
|---|---|
| `world_root.gd` | 250 lines or fewer |
| `room_loader.gd` | builds rooms from `RoomDef` |
| `nav.gd` | ported `move_body`, line of sight, flow field |
| `encounter_director.gd` | waves, elites, spawns |
| `combat.gd` | the damage pipeline, with hooks |
| `spell_runner.gd` | ported |
| `enemies/` | enemy brains from `EnemyDef` |
| `bosses/` | bosses as phase and attack tables |
| `interactables.gd` | doors, orbs, NPCs, crates |
| `juice.gd` | hit-stop, shake, flash, haptics |

- `scripts/dev/bot.gd`: the bot moves out of `world.gd`.

**UI:**
- The world renders in a pixel-base `SubViewport`; the UI runs at native resolution with `Control` nodes and containers.
- A theme generated in code from the Style ramps.
- Pixel fonts at integer multiples only.
- `tr()` with `locale/en.csv`.
- A `UiRoot` that applies the safe area.

**Art (still drawn in code):**
- 32 px actors built from `Rig` resources: parts, bones and keyframes per action, with anticipation, smear and secondary motion.
- `tools/bake_art.sh` bakes lossless atlases into `assets/baked/`. CI re-bakes and compares hashes.
- A palette-swap shader per biome.
- Baked light cookies instead of live `PointLight2D`.
- Shaders for dissolve, elite outline and glitch.

**Audio ($0):**
- Sound effects from ChipTone or jsfxr and the Sonniss bundle; CC0 or CC-BY music.
- `assets_src/audio/LICENSES.csv` records every file, and a test fails on any asset without a row. The credits screen is generated from it.
- A normalization script.
- QOA for sound effects, OGG for music.
- Buses: Master, Music, SFX and UI.
- About 70 sound effects and 6 music cues, each loop 2 minutes or longer.

## Milestones
Every milestone ends with a web build on Vercel, an APK, `STATUS.md` updated, commits pushed, and Bar's device check.

### Step 1 (right after approval)
- Save the research into the repo: `research/mvp-research.md`, the three briefs with sources.
- Write `research/mvp-plan.md` from this plan.
- Record ADR 0010 (the MVP plan and Bar's decisions) and update `STATUS.md`.
- **Scope note:** `scope.md` changes only through an ADR, so ADR 0010 amends its acceptance criteria.

### M0: foundations and baselines
- ADR 0011: move to the Compatibility renderer, after before/after screenshots and a glow check.
- CI on Linux through GitHub Actions: `test.sh`, `taptest.sh` in 3 modes, content validation, web export plus `webtest.sh`, and a nightly balance run.
- A `--perf` overlay, opened by tapping the build stamp 5 times.
- Screenshot goldens.
- A shortlist of music and sound candidates.
- **Exit:** CI is green, and Bar records baseline performance in `research/perf.md`.

### M1: content as data, plus effects and hooks
- **Exit:**
  - `has_relic` exists only in `effects/`.
  - The golden tests and the spell sweep pass unchanged.
  - The bench stays within ±5 of 80% survival.

### M2: break up `world.gd` into the modules above
- **Exit:**
  - `world_root.gd` is 250 lines or fewer.
  - Test parity, and the stress tick within +10% of baseline.

### M3: UI foundation
- Controls, theme, `tr()`, safe area and text scale, for the title, pause, settings, reward screens and HUD.
- **Exit:**
  - Tap test passes in 3 modes.
  - Goldens pass at 16:9, 19.5:9 and 20:9.
  - No literal strings in `ui/`.
  - Bar checks 200% text on the iPhone.

### M4: controls, dash and editor
- A floating stick, dash, the aim cone with its marker, and the layout editor.
- `EditorModel` and the new editor, with live preview.
- **Exit:**
  - The tap test drags a spell with real touch input.
  - The bot edits wands through `EditorModel`.

### M5: onboarding and run structure
- `map_gen`, elite and risk nodes, rest nodes, the scripted first run, and retry in 3 s or less.
- **Exit:**
  - The onboarding test passes.
  - Bar plays a full run in 12–18 minutes.
  - **Suggestion:** open the Play account now, so the 14-day closed-test clock runs during M6–M10.

### M6: raise the art ceiling
- First, spike one enemy fully on the new rig.
- Then the 32 px hero and 4 enemies, the palette shader, light cookies, the enemy-bullet family and colourblind presets.
- **Exit:** Bar approves the art sheets, and performance holds.

### M7: enemies, elites, bosses
- The rest of the roster, 2 new archetypes, 3 affixes, deeper bosses.
- **Exit:** bench targets are met, and Bar plays 3 runs.

### M8: meta-progression
- `meta.json` v2 with migration, unlock conditions, Shards, Codex, run summary, Corruption 1–3.
- **Exit:**
  - A test for every unlock condition.
  - A 20-run soak shows an unlock in run 1 and about 50% unlocked by run 10.

### M9: audio
- The manifest pipeline, the sound-effect pass, layered music, credits, haptics mapping.
- **Exit:**
  - The license test passes.
  - `webtest.sh` measures audio output.
  - Bar checks sound on the iPhone.

### M10: store-ready at $0
- A `Store` autoload with three backends: a mock, StoreKit 2 (GodotApplePlugins) and Play Billing 3.x.
- The World 2 gate with Restore Purchases, labelled as a trial.
- Store build settings:
  - an AAB targeting API 36 with 16 KB page alignment
  - iOS plist keys for 120 Hz and export compliance
  - the privacy manifest
  - a layered icon
  - store screenshots
  - a privacy-policy page
  - age-rating answers
- Fastlane and macOS workflows, committed but switched off.
- **Exit:**
  - Mock purchase and restore tests pass.
  - A local `.storekit` purchase works on Bar's iPhone through the free Xcode path.
  - The AAB validates.
  - Device performance meets the bars.

### GATE: needs the accounts (Apple $99/yr, Play $25)

### M11: betas
- App Store Connect: the app record, the unlock purchase, sandbox testers, TestFlight builds through `pilot`.
- Play: a closed test with 12 testers for 14 days, plus license testing.
- Game Center and Play Games achievements.
- **The MVP is done when** both betas are live and purchase and restore are verified in both sandboxes. The public launch comes after World 2.

### What to cut first if we slip
1. Achievements.
2. The second new archetype.
3. Corruption tiers above 1.
4. Free control layout, in favour of presets.
5. Music layering.
6. The firing-range view.
7. 8-frame animations, down to 4–6.
8. Screenshot goldens.

**Never cut:** onboarding into a wand edit, the dash, the editor, basic meta, the purchase wiring, and the tap and CI tests.

## Risks
| Risk | Mitigation |
|---|---|
| Regressions while splitting `world.gd` | Parity tests and bench tolerance, one module per PR |
| Control-based UI failing to take taps, as in 0.3.0 | The tap test covers every new screen in all 3 modes |
| The renderer switch changes the look | An A/B check in M0; the fallback is Mobile on native only |
| Device performance is unknown | Baseline in M0 and budget tests; GDExtension only after profiling |
| Code-drawn art hits its ceiling | A spike before committing, with a 4–6 frame fallback |
| Free music quality | Shortlist early; CC-BY with a credit |
| Store plugins versus Godot 4.7.2 | Pin versions and spike with a local `.storekit` file |
| Play's 14-day closed test | Open the account at M5 |
| POC saves | Reset with a notice, with versioned saves from now on |

## Verification
**Automated, run in CI:**
- **Unit and golden tests:** the wand engine; the spell × boost sweep; content validation (doors reachable, spawns on floor, icons and `tr` keys present, animations complete); relic hook parity; map generation; unlock conditions; save migration; mock purchase and restore.
- **Tap test** in 3 modes, covering every screen, an editor drag, the dash and the control layout.
- **Balance bench, where the bot now edits wands** through a greedy `WandPlanner`:
  - The editing bot survives 55–80%.
  - A bot that never edits survives 40% or less.
  - The gap between them is at least 15 points.
  - No stalls.
- **Onboarding timing test:** first edit by 120 s, first trigger by 180 s.
- **Performance budgets:** stress tick within +10% of baseline, plus caps on draw calls and entities.
- **`webtest.sh`:** the canvas fills the window, no errors, audio actually plays. Also run nightly against Vercel.
- **Screenshot goldens** at 3 aspect ratios.
- **A 200-run soak.**

**Bar, on every milestone build:**
- Check the build stamp.
- Menus take taps.
- Sound plays.
- Nothing sits under the island or the home bar.
- The perf overlay shows p99 on the iPhone and Android.
- Play one full run.
- Plus that milestone's own checks listed above.
