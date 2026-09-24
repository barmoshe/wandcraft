# wandcraft — STATUS

- Updated: 2026-09-24

## Where we are
- **M0 Foundation: done.**
  - Project folder, ADRs 0001-0006 and research notes.
  - Godot 4.7.2 headless toolchain.
  - Test runner (`tools/test.sh`) and a screenshot tool (`tools/shots.sh`, Xvfb plus Mesa, Mobile renderer).
- **M1 Vertical slice: done. It is playable on desktop, and the touch controls are in.**
  - **Wand engine** (`game/scripts/sim/`): a typed port of the prototype rules, covered by 14 golden tests. Boosts carry to the right until recharge; Chorus draws more spells; triggers (THEN, Callback, While Loop, Fork Bomb) glue two spells; carriers (Payload Seed, Starwheel) take payloads in a fresh count scope; Mirror duplicates; each slot is read at most once; nesting is capped at depth 3.
  - **World** (`game/scripts/world/`):
    - One world tileset, painted procedurally, with raised stone walls, spike plates and torches.
    - Three room templates. Two doors on the top wall (fight, elite or treasure) open when the room is cleared.
    - Two enemy waves per room, with four enemies:
      - Moss Blob (chase)
      - Hex Weaver (keeps range and shoots)
      - Thornback (telegraphs, then charges)
      - Rune Sentry (burst turret)
    - Treasure rooms drop a spell, which goes into an empty slot or the bag.
  - **Combat:** a pooled BulletPool (2048 bullets, one MultiMesh draw) and a SpellRunner for bolts, beams, bursts and the Starwheel, plus every trigger event, shatter, pierce, bounce and homing.
  - **Player:** twin-stick movement (no dash, as in Magicraft), aim assist, and auto-fire at the nearest visible enemy (one thumb is enough). Two starting wands: Apprentice Rod (Payload Seed → Rune Burst, Arcane Mote) and Chorus Harp.
  - **UI:**
    - The HUD follows the prototype v5 layout: wand rows with round sockets, a pointer and a recharge sweep; the bag; HP and MP bars; gold, room and kills.
    - A room banner.
    - Floating twin sticks (move / aim), inside the safe area; tap a wand row to switch wands.
    - Pixel fonts: Silkscreen and Pixelify Sans (OFL).
  - **Look:**
    - 2D lighting: an ambient tint, torch lights and a light around the wizard.
    - LDR glow (ADR 0004).
    - Integer pixel scaling. It was checked at 1440×810 and at 2556×1179 (iPhone landscape, which gives a 639×295 virtual view).
  - **Tests:** 23 headless tests pass.
    - Every shooting spell × every boost deals damage.
    - Every trigger releases its payload.
    - The Starwheel sprays 16 times.
    - The bot clears 3 rooms and walks through the doors.
    - Death restarts the run, walls stop bodies, and the pool recycles.
    - Stress: 45 enemies and ~1100 bullets average 6.4 ms per tick on the dev container.

- **v0.2 "World 1, complete": done (ADR 0005). The free tier plays end to end.**
  - **Research:** `research/run-structure-and-mobile-ux.md`, on Magicraft's run systems (mechanics only) and mobile UX. It led to:
    - Shorter chapters.
    - Every reward is a choice of 3.
    - Tap-to-pick/tap-to-place editing.
    - Saves at room boundaries.
  - **Chapter:**
    - The route is start → 3 chosen rooms → Copy-Paste (mini-boss) → 3 chosen rooms → The Infinite Loop (boss) → exit. The bot finishes a run in about 4 simulated minutes; humans will take longer.
    - Doors show their reward: spell, relic, gold, max HP, wand, challenge, shop, spring or forge.
    - The room before a boss always offers a spring or a shop.
  - **Rewards:**
    - Every reward is a choice of 3. A tap inspects a card and TAKE confirms it; SKIP pays gold.
    - Three copies of a spell merge into the next level.
    - The shop sells spells, a relic, a heal and a wand. The forge upgrades a spell for gold.
  - **Content (all original):**
    - 33 spells: new are Glitch Needle, Ember Bolt, Chain Spark, Frost Shard, Heavy/Wide Rune, Linger, Keen Edge, Ember/Frost Coat and Regen Coil. Burn and chill are new statuses.
    - 7 wands and 22 relics.
    - 6 enemies: new are Bugling and Puffcap.
    - 2 bosses, with a telegraph → act → recover framework and HP phases.
  - **Screens** (`game/scripts/ui/`, drawn immediate-mode at pixel resolution, taps ≥ 32 px):
    - Title, pause (relics, auto-fire / shake / flash settings, two-tap abandon), reward, shop/forge, victory and defeat.
    - Wand editor: tap-to-pick/tap-to-place plus drag, a fixed info panel, a live cast preview and REVERT.
  - **HUD:** the chapter map strip, pause and editor buttons, relics, and the boss bar.
  - **Saves:**
    - `user://run.json` is written on room entry, when a reward or shop screen closes, and when the app is paused. The file is written then renamed, so a kill mid-write can't corrupt it.
    - CONTINUE resumes into the pause menu.
    - Lifetime stats go in `user://meta.json`.
  - **Tests:** 43 headless tests pass.
    - Run state, merges, moves, chapter doors, rewards, relics and the save round trip.
    - Screen logic.
    - Both bosses beaten in simulation.
    - **A bot completes World 1.**
    - The combo sweep and the stress tick (about 7 ms for 45 enemies and 1300 bullets).

- **v0.3 "feel + phone build": done (ADR 0006). An Android APK installs and runs; the iOS project is ready for Bar's Mac.**
  - **Sound:**
    - 34 sound effects and 3 music loops (title, grove, boss), all generated by `tools/gen_audio.gd` from our own synth (deterministic, no licensed audio).
    - The `Audio` autoload handles pooling, rate limits and music crossfades.
    - Sound and Music settings.
  - **Feel:**
    - Hit-stop on crits, elite and boss kills, and boss phases.
    - Enemies dissolve into their own pixels.
    - Dust underfoot.
    - White, rate-limited screen flashes.
    - A slow red edge glow at low HP.
    - Vibration on phones.
    - Every effect can be switched off in pause.
  - **Gameplay gaps closed:**
    - Auto-aim leads moving targets.
    - Aim comes from the hand.
    - Crates are breakable cover that drops gold.
    - Spawn runes are always visible.
    - The Loop's head is brighter and lit.
    - Bodies can no longer get stuck in walls.
    - The camera follows at 120 Hz.
  - **First-run tips:** six contextual tips (move, aim, orb, doors, editor, boss), each shown once and queued. "Show tips again" is in pause.
  - **Balance:** `tools/balance.sh` has a non-god bot play 10 seeds. Result: 80% survival, mini-boss about 47 s, boss about 55 s, no stalls. Numbers, changes and the four bugs it found are in `research/balance-w1.md`.
  - **Phone build:**
    - Generated app icon and splash.
    - `export_presets.cfg` for Android and iOS.
    - `tools/build_android.sh` builds `build/wandcraft-0.3.0.apk`: 27.7 MB (release template, throwaway sideload key), arm64, min SDK 24, landscape, only the VIBRATE permission. The first sideload failed with "problem with the app file" because the copy was truncated in transfer (23.85 of 29.5 MB), so the script now prints the byte size and SHA-256 to check against.
    - Guides: `store/ios-first-build.md` and `store/android-sideload.md`.
    - Reference privacy manifest.
  - **Tests:** 48 headless tests, including a bot clearing World 1, plus the balance bench.

## Next action
- **Bar:** install the APK on an Android phone and/or follow `store/ios-first-build.md` on the Mac. Send a short screen recording of a fight.
- **v0.4, based on device feedback:**
  - Tuning of the touch sticks, text size and difficulty.
  - The performance quality tier (Compatibility renderer on low-end devices).
  - Then M2 breadth (worlds 2–5) and M5 (the paywall with StoreKit 2 and Play Billing, Game Center / Play Games).
- **Known gaps:**
  - Keys, curses, potions and meta unlocks are deferred (ADR 0005).
  - The iOS privacy manifest must be checked against the one Godot generates.
  - The bundle id is a placeholder.

## How to look at it
- Tests: `tools/test.sh`. Balance bench: `tools/balance.sh` (a few minutes).
- Regenerate assets: `tools/audio.sh` (sound and music), `tools/icon.sh` (icon and splash).
- Android APK: `tools/build_android.sh`. It writes to `build/`, and the first run downloads the SDK outside the repo.
- Screenshots: `tools/shots.sh`. Useful options (see `game/scripts/main.gd`):
  - A staged fight: `--showcase --wand=2`.
  - A boss: `--demo --kind=boss --loadout=strong --frames=480`.
  - A screen: `--screen=editor|reward|shop|forge|pause|end|title`.
- Playing on the Mac: open `game/project.godot` in Godot 4.7.2 and press Play.
  - Controls: WASD to move, hold the mouse button to aim and fire, 1/2/3 to switch wands, Tab/E for the wand editor, Esc to pause, F to toggle auto-fire.

## Waiting on Bar
- [ ] **Apple:** enroll in the Apple Developer Program ($99/yr). Decide between individual and organization (an organization needs a D-U-N-S number).
- [ ] **Google:** open a Google Play Console account ($25, identity verification). If it's a personal account, plan the closed test (about 12 testers for 14 days).
- [ ] **Mac:** install Xcode 26 on the Mac.
- [ ] **Pricing:** choose the unlock price (around $4.99 suggested).
- [ ] **Title:** confirm "Wandcraft", or pick a new one. It still needs a store and trademark check.
- [ ] **App id:** choose the final bundle / package id (placeholder `com.barbuilds.wandcraft`). It can't change after the first store upload.
- [ ] **Test on devices:** Android sideload (`store/android-sideload.md`) and the first iPhone build (`store/ios-first-build.md`).

## Blockers
None. The first iOS build will need the Apple account and Xcode.
