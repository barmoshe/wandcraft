# Finishing the MVP: execution plan (2026-09-25)

Bar's go-ahead on 2026-09-25: finish D6, D8 and D9, then store prep, stopping before the
account-gated betas. Music and sound stay generated in code (no downloaded packs). Review
gates do not block: each milestone's sheets, shots and web build go to Bar as they land,
and his feedback becomes a revision pass. The design itself is `design-plan.md`; this file
is the order of work and the log.

## Steps

**Step 0. Toolchain on the Mac.** Godot 4.7.2 and its export templates, the tools ported
from the Linux container, the stress roster pinned.

**D6. Animation (0.11.0, ADR 0018)**
1. `RigDef` and `RigBaker`: parts as ASCII stamps with pivots, poses as integer offsets,
   row squash and stretch, secondary lag, baked and cached, with tests.
2. The hero rig: two facings (front and back), idle 4, run 6, cast 3, dash 4, hurt 2,
   death 6; the wand pre-rotated to 16 angles; the player drives it.
3. Enemy rigs: move 4, telegraph 2, attack 2, a 4-frame death poof, for all ten enemies plus
   the slimelet and Loop Jr.; the enemy AI state picks the clip.
4. Boss rigs: the Loop head (chomp, telegraph, hurt), Copy-Paste inherits the hero rig.
5. VFX: a 3-frame directional hit spark, an 8-frame explosion, dithered trails, 3-tier
   damage numbers that merge within 150 ms, floor telegraph decals that fill.
6. Ambient life (torch, grass, dust, leaves) and the front-cap y-sort overlay.
7. Art sheets (animation strips, value and silhouette), performance check, bench, ADR,
   STATUS, version, web deploy, APK.

**D8. Music and sound (0.12.0, ADR 0019)**
1. `assets_src/audio/LICENSES.csv` with a failing-on-missing-row test; `tools/audio_norm.gd`
   measuring loudness to BS.1770.
2. Six generated cues: title, forge/shop variant, World 1 stems (base, drums, lead),
   Corrupted Grove, the boss (intro, loop, phase-2 layer), and stingers.
3. About 70 sound effects with variants through `AudioStreamRandomizer`.
4. Buses (Master limiter, Music with ducking, SFX, Critical, UI), priority classes,
   haptics mapping, per-area music layer.
5. Credits screen from the manifest; `webtest.sh` checks the music bus.
6. Close-out as in D6.

**D9. Onboarding and meta (0.13.0, ADR 0020)**
1. The dash: 0.18 s, i-frames, afterimages, cooldown.
2. The curriculum first run, with the onboarding timing test (first edit by 120 s, first
   trigger by 180 s).
3. Source Fragments, the meta unlock pool, and the Codex screen.
4. Bug Reports heat tiers.
5. Re-check the never-editing bot (target 15–30%); close-out.

**Store prep and the iOS release (0.14.0, ADR 0021)**
Bar, 2026-09-25: finish D9 first, then publish on iOS. Free, no in-app purchases; an
Individual Apple Developer account (Bar buys it); bundle id `com.barbuilds.wandcraft`.
1. Listings, a hosted privacy policy, screenshots at the App Store sizes, age rating answers.
2. A release script, `tools/release_ios.sh`: build and upload through the Apple ID Bar signs
   in to Xcode himself (the agent never types his Apple ID or password); export compliance set.
3. CI in this repo: tests on every push.
4. TestFlight, then App Store review, each after Bar says go (an outward action).

## EXECUTION LOG
- `33605c6` step 0: tools run on macOS with Godot 4.7.2; stress roster pinned; 154/154 tests, stress 8.6 ms.
- `2971dfc` D6.1: RigDef + RigBaker (squash rows, lag, tears, crumble, RotSprite-style rotation).
- `1aed2dd` D6.2: hero rig, 2 facings x 25 frames, wand at 16 angles, player drives clips; 154/154.
- `dc493bc` D6.3: 12 enemy rigs (move/tele/attack), AI-driven clips, death poof; stress 8.5-8.8 ms.
- `d8b9640` D6.4: Loop head rig (12 frames x 16 headings), Copy-Paste on glitched hero clips; 154/154.
- `4397b5d` D6.5: hit sparks, 8-frame explosions, trails, 3-tier merged numbers, filling floor decals; 162/162.
- `4acd779` D6.6: ambient tufts/motes/leaves (8 fps, visual-only), front-cap lips y-sorted with actors; 163/163.
- `5f5c13a` HUD icons (Bar, mid-D6): pre-rotated per-gem wand badge, ramp-drawn coin/pause/bag/heart/drop, in-cell 3x5 relic counters; 163/163.
- `ef4ae82` D6 close-out: ADR 0018, 0.11.0 (build 13); web live at ef4ae82 (checked in the browser, no console errors); APK 0.11.0 built. Bench: see balance-w1.md.
- `83f28b4` D6 muzzle fix: bench back to 80/10 (identical to D7); the 90/0 reading came from a 1 px muzzle shift, not the Mac.
- `05bf6f5` D8.1-3: BS.1770 meter, 5 generated cues + 5 stingers, 84 effects with variants, licence manifest.
- `d02d6c1` D8.4: buses + sidechain duck, voice classes, layered/interactive music, stingers, haptics, all sounds wired.
- `2a84448` D8.5: credits screen (engine licences), web music-bus check.
- `8fdc714` perf/tests: O(1) number merge; stress test = best-of-2 quiet quartile (desktop load swings the mean 9-18 ms); 168/168.
- `bdafb9d` fix: freed wave enemies count as down (typed lambda errors on web since D4); bench unchanged 80/10.
- `0bac598` D9.1: the dash (i-frames, afterimages, cooldown; keys, pad, touch button).
- `b9796e2` tests: stress guard = storm/calibration ratio (< 5.2; reads 4.2-4.4 under any load) + one-frame ceiling; 170/170.
- `beea0ef` D9.2: first-run curriculum (3 lessons + coach toward a fixed layout), counter/dash tips; onboarding test: edit ~10 s, trigger ~42 s; 174/174.
- `5220e79` D9.3-4: Source Fragments + 26 Codex unlocks + starting slot; Bug Reports 5 tiers; 180/180.
- `c5fc0c2` D9 close-out: ADR 0020, 0.13.0 (build 15), web live (tutorial path checked in the browser, no console errors), APK built; bench 80/10.
- `a08108c` fix (Bar): start pick shows the locked Stub greyed, stats lines fit, TAKE centred.
