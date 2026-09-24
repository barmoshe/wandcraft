# 0008. v0.4.1: enemies path around cover; the web build drops its service worker

- Date: 2026-09-24
- Status: Accepted

## Context
Bar played the web build on his iPhone 15 Pro Max from the Home Screen icon. Two complaints remained after the touch fixes:

**"The enemies AI is awful, they seem stuck."**
- Every enemy steered in a straight line at the player, with no pathfinding. A pillar, crate, the donut ring or the split wall stopped them dead.
- The shooters, the turrets and the ram's charge never checked line of sight. They kept shooting pillars and charging into walls.
- A BFS pathfinder already existed (`World.path_dir`), but only the test bot used it.

**No sound on the iPhone.** Chromium was fine. On the iPhone:
- The silent switch mutes web audio.
- iOS only unlocks audio on a touch's end.
- Godot's PWA service worker served the game cache-first, so a Home Screen app could keep running a stale build without anyone being able to tell.

## Decision
- **Enemies path around cover** (`World.chase_dir`):
  - One BFS distance field toward the player's tile, shared by every enemy. It is rebuilt only when the player changes tile or the grid changes.
  - An enemy goes straight at the player when a body-wide lane is clear. Otherwise it aims at the furthest tile of the path it can reach in a straight line.
  - Each enemy re-plans its route every 0.1 s, but a clear lane follows the player every tick.
- **Sight rules:**
  - Weavers and turrets fire only with a clear line to the player (crates block it, as they stop enemy shots). A weaver without a line walks around the cover.
  - The ram winds up a charge only down a clear lane.
  - A weaver that strafes into a wall turns around.
- **Spawns** check that the whole body fits clear of walls.
- **Balance:** the spawn freeze drops from 0.7–1.1 s to 0.5–0.8 s, which brings the bench back inside its band (90% → 80% survival). Enemy speeds are unchanged.
- **The web build has no service worker.**
  - The engine's PWA export is off.
  - The manifest and icons ship from `tools/web/`.
  - A kill-switch worker at the old path deletes the old caches and unregisters itself on phones that still have one.
- **iPhone audio** (`game/web/shell.html`):
  - Set `audioSession` to `playback`.
  - Play a silent looping `<audio>` on the first tap, so the silent switch no longer mutes the game.
  - Resume the engine's audio contexts on touchend, click and keydown, and when the page becomes visible.
- **The web build shows its build stamp** (git commit) on the title, and a one-line sound report on the pause screen. A tester can report what's wrong without a Mac inspector.

## Consequences
- **Enemies are harder:**
  - They reach you around cover.
  - Weavers reposition instead of wasting shots.
  - Turrets behind pillars go quiet until you step into view.
- **Tests:** `tests/unit/test_enemy_path.gd` guards pathing, sight and spawn fit. The 45-enemy stress tick costs about 1 ms more.
- **Web build:** there is no offline play, but a new deploy reaches phones on the next launch.
- **Sound side effect:** it pauses other audio (music, podcasts), like a video does.
