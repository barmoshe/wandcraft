# Wandcraft: handoff (2026-09-25)

> **Since this handoff:** D6, D8, D9 and store prep are done (0.14.0; ADRs 0018-0021). For the current state read `STATUS.md`; for the order of work and every commit, `research/mvp-finish-plan.md`; for publishing on iOS, `store/ios-release.md`. The rest of this file is the state at the split, kept as it was.

This hands off the design-first MVP after D0–D7, the point where Wandcraft moved out of `bar_builds/projects/wandcraft` into its own sibling repo, `barmoshe/wandcraft`, for local work. The full history came along: `git log` goes back to the first mobile milestone.

## Where it is

| | |
|---|---|
| Version | **0.10.0** (Android versionCode 12, iOS build 12) |
| Web build | https://wandcraft-test.vercel.app. Live build is `e8ce86a` (0.9.0); 0.10.0 is not deployed yet. |
| Last APK sent | 0.9.0 |
| Tests | `tools/test.sh`: 154 tests, 153 pass. The failing one is the stress budget; see *Open issues*. |
| Bench | `tools/balance.sh`: the editing bot survives 80%, the never-editing bot 10% |

**Milestones** (plan: `research/design-plan.md`; ADR 0011 made it design-first):

| | Milestone | Version | ADR |
|---|---|---|---|
| D0 | Design bible, game feel (trauma shake, hit-stop, camera), audio quick wins | 0.5.0 | 0011 |
| D1 | Art direction: quiet floor, outline rule, reserved `threat` red | 0.5.0 | 0012 |
| D2 | Spell system: 56 spells, Debugger runes, familiars, statuses, reactions, the wand-editing bot | 0.6.0 | 0013 |
| D3 | 38 relics, Merge Commits, Corrupted relics and the Glitch Door, 6 Compile evolutions | 0.7.0 | 0014 |
| D4 | Counters (shield/pierce, armour/blast, ward/shock), 4 new enemies, elite affixes, encounter director | 0.8.0 | 0015 |
| D5 | 18 room layouts (S/M/L), pits, brambles, pods, pylons, secrets, the 3-lane map, Altar, Terminal | 0.9.0 | 0016 |
| D7 | Bosses: Copy-Paste copies your wand; the Loop has an armoured head, breakable body, pylon derail and 3 phases | 0.10.0 | 0017 |

D6 was skipped ahead of D7 on purpose. The bosses changed shape, so their rigs should be drawn once, after that.

## What is left (in order)

1. **D6, animation rigs.**
   - `RigDef` and `RigBaker`: parts as ASCII stamps with pivots, poses as integer offsets, baked to atlases.
   - The hero: 2 facings, about 50 frames, the wand pre-rotated to 16 angles.
   - Rigs and frame budgets for all 10 enemies and both bosses.
   - Effects: hit sparks, an 8-frame explosion, dithered trails, 3-tier damage numbers that merge within 150 ms.
   - Ambient life and floor telegraph decals.
   - The front-cap y-sort overlay, deferred from D1 and D5.
   - Exit: Bar approves the art sheets (`tools/artsheet.sh`), and performance holds.
2. **D8, music and sound.**
   - `assets_src/audio/LICENSES.csv`, with a test that fails on a missing row. `tools/audio_norm.gd` measures loudness to BS.1770.
   - 6 music cues from the free shortlist in `research/design-research.md` §4. Bar picks by ear. The budget is $0: CC0, or CC-BY with a credit.
   - About 70 sound effects with variants.
   - Mixing: Master, Music, SFX and Critical buses, ducking, priority classes.
   - A credits screen generated from the CC-BY rows, and haptics mapping.
   - A music layer per area (Cellar and Grove).
   - `tools/webtest.sh` also checks the music bus.
3. **D9, onboarding and meta.**
   - A tutorial first run: first edit by 120 s, first trigger by 180 s, with a test.
   - Source Fragments (meta unlocks), the Codex, Bug Reports heat tiers, and the dash.
   - Menus rebuilt in Godot's standard UI (Control nodes) where the new screens need it.
   - The never-editing bot's 15–30% target should be re-checked here: the tutorial run changes the early game.
4. **After D9** (ADR 0010, M10–M11):
   - Store-ready at $0: listings, privacy, screenshots (`store/`).
   - CI. It lives in this repo now, so it no longer needs bar_builds' root-scope approval.
   - TestFlight and Play betas. These wait on Bar's Apple ($99) and Google Play ($25) accounts.

**Deferred inside finished milestones** (listed in each ADR's Consequences):
- Doors on side walls.
- One-way vine gates.
- Corrupted *spells*: Corrupted stays a relic rarity.
- The combat half of splitting `world.gd`.
- A guaranteed counter offer right before each boss (a weaker always-on version exists).
- Hex Cursor revealing Copy-Paste's real copy.

## Open issues

1. **The stress test budget (`tests/unit/test_world.gd::test_stress_tick_budget`).**
   - The average tick in the 1,300-bullet storm is about 10.0–10.5 ms against a 10 ms budget on the cloud dev container.
   - Timing each commit showed no regression from D2–D7 (D4 10.4, D5 10.0, D7 about 10.4). The container is slower now than when the budget was set (8.6 ms).
   - Separately, the test picks enemies with `Enemy.DEFS.keys()[i % 4]`, so D4's new entries silently changed its roster (slimelets replaced buglings).
   - **Proposed, not applied:** pin the roster to `[&"slime", &"weaver", &"ram", &"bugling"]`, then decide the budget on Bar's Mac, which is faster than the container.
2. **The never-editing bot survives 10%** (target 15–30%). It loses almost only at the final boss. Re-check after D9.
3. **`tools/webtest.sh` failed once in five runs, for a reason not seen.** Every later run passed, with sound peaks from 0.033 to 0.093. The sound check may need a lower threshold or a retry.
4. **Deploy check:** always confirm the live build stamp after `tools/deploy_web.sh`. Vercel's edge can serve the old `index.html` for a few seconds, so query with `?t=<now>`.

## Working locally

- **Godot 4.7.2.** `tools/godot.sh` finds it through `$GODOT`, `godot` on PATH, or `/Applications/Godot.app`.
- **Run it:** open `game/` in the editor, or run `tools/godot.sh --path game`.
- **Handy arguments for `--path game -- ...`:**
  - `--demo`: the bot plays.
  - `--step=N --kind=fight|mini|boss`
  - `--room=<layout>` (the layouts are in `scripts/world/room_layouts.gd`)
  - `--loadout=strong|d2|d3`
  - `--screen=editor|reward|shop|forge|map|pause|end` (with `--offer=start|spell|relic|...`)
- **Check commands:**
  - Tests: `tools/test.sh`
  - Tap test: `tools/taptest.sh`, plus `--rotate` and `--ios`. Run it after any UI or input change.
  - Bench: `tools/balance.sh`, about 20 minutes.
  - Screenshots: `tools/shots.sh <name> <args>`. It uses Xvfb on Linux; on a Mac, run the game and screenshot it.
  - Art sheets: `tools/artsheet.sh [chars|icons|tiles|fx|ui|check]`
- **Builds:**
  - APK: `tools/build_android.sh`. The SDK cache lives in `~/.cache/wandcraft-build`.
  - Web: `tools/build_web.sh`, `tools/webtest.sh`, then `tools/deploy_web.sh`. This needs the Vercel CLI logged in to the `wandcraft-test` project; `.env.local` is never deployed or committed.
  - iOS: `tools/export_ios.sh` on the Mac (see `store/ios-test.md`).

## Where things are

- **`game/scripts/sim/`:** pure data, no nodes:
  - `catalog.gd`: spells, wands, evolutions
  - `wand_program.gd`: the compiler
  - `relics.gd`: relic defs and stats
  - `rewards.gd`: offers, Compile, Enables
  - `chapter.gd`: the plan and the 3-lane map
  - `run_state.gd`: the run and saves
  - `wand_planner.gd`: the bot's editor
- **`game/scripts/world/`:**
  - `world.gd`: rooms, damage, statuses, terrain, the bot
  - `spell_runner.gd`: spells in the world
  - `enemy.gd`: the roster and AI
  - `encounter.gd`: waves and spawns
  - `boss*.gd`
  - `room_layouts.gd` and `room_painter.gd`
- **`game/scripts/ui/`:** the screens (editor, reward, shop/forge, map, pause, HUD).
- **`game/scripts/art/`:** code-drawn art (Style ramps, icons, bestiary, props, projectiles).
- **Docs:**
  - `decisions/`: ADRs 0001–0017, append-only.
  - `research/`: `design-plan.md` is the plan; `balance-w1.md` is every bench result.
  - `STATUS.md`
  - `store/`

## Conventions that still hold

- **Original content only** (ADR 0002). Mechanics may be inspired by other games; names, text and numbers may not.
- **Art:** drawn in code with the Style ramps, no inline hex in new art. The `threat` ramp is only for enemy attacks. New spells and relics need icons, which a test checks.
- **Pixel base:** 480×270, never a fractional scale.
- **Every milestone ends with:** tests green, a bench run recorded in `research/balance-w1.md`, an ADR, a STATUS update, a version bump, a web deploy with the live stamp checked, and an APK for Bar.
- **Secrets never committed:** signing keys, keystores, `.env.local`.
