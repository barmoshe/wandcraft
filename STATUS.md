# wandcraft — STATUS

- Updated: 2026-09-24

## Where we are
- **M0 Foundation: done.**
  - Project folder, ADRs 0001-0004 and research notes.
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

## Next action
- **M2 original content:**
  - About 60 spells, 40 relics, 20 wands, 17 enemies, 10 bosses and 5 worlds, with original names and text and our own balance formulas.
  - A DPS balance simulation, and a boss framework with all 10 bosses killable in a simulation.
- **Carried over from M1:**
  - Crates (`c`) are plain floor for now.
  - The enemy spawn rune is faint under the ambient tint.
  - The auto-aim does not lead moving targets.
  - The camera ignores physics interpolation (fine at 60 Hz; revisit for 120 Hz).

## How to look at it
- Tests: `tools/test.sh`
- Screenshots: `tools/shots.sh`. For a staged fight: `tools/shots.sh show --showcase --frames=130 --wand=2`
- Playing on the Mac: open `game/project.godot` in Godot 4.7.2 and press Play.
  - Controls: WASD to move, hold the mouse button to aim and fire, 1/2 to switch wands, F to toggle auto-fire.

## Waiting on Bar
- [ ] **Apple:** enroll in the Apple Developer Program ($99/yr). Decide between individual and organization (an organization needs a D-U-N-S number).
- [ ] **Google:** open a Google Play Console account ($25, identity verification). If it's a personal account, plan the closed test (about 12 testers for 14 days).
- [ ] **Mac:** install Xcode 26 on the Mac.
- [ ] **Pricing:** choose the unlock price (around $4.99 suggested).
- [ ] **Title:** confirm "Wandcraft", or pick a new one. It still needs a store and trademark check.

## Blockers
None. The first iOS build will need the Apple account and Xcode.
