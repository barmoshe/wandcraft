# 0031. The NPCs speak in the world: companions, speech bubbles, and no overlapping text (0.21)

- Date: 2026-09-28
- Status: Accepted
- Follows ADR 0026 (the story's voices) and ADR 0028 (the residents). Research: `research/speak-up-0.21.md`.

## Context
Bar played 0.20 and asked for three things:
- "Fix the HUD and text elements overlapping each other, go over all the game."
- "The NPCs need to be in the world and not in the HUD. Above their head should be a speech bubble."

How speech worked before this change:
- Every line showed in a box at the bottom of the HUD, with a small face.
- The Duck and LINT, who say almost every line, had no body in a run.
- In the Workshop, a resident's talk opened a full screen that paused the world.

The overlap audit (below) found collisions at the bottom of the HUD during boss fights: the tip, the spoken line and the phase banner landed on each other. It also found text running off screen on a 4:3 iPad. The cause there was the pixel scale: it rounded 1536 / 270 up to 6, which left a view only 341 px wide.

Bar's choices:
- The Duck and LINT become companions in a run.
- Residents talk in bubbles, and their service opens a compact panel.

## Decision
**Companions** (`world/companion.gd`, `art/companion_art.gd`):
- The Duck waddles beside the hero and LINT hovers at head height, both on the side away from the aim.
- They ease after the hero and never stray more than 40 px. They step around walls, never stand on the hero, and snap in when a room opens.
- They are only looks: never in `enemies` or the spatial hash.
- The Duck's beak moves and LINT's eye pulses while they speak.
- They are hidden in the Workshop, where the fixed Duck and LINT stand.

**Speech bubbles** (`ui/bubbles.gd`, drawn by the HUD):
- **Where the bubble goes:** the speaker's own head.
  - A companion in a run.
  - A spot in the Workshop.
  - A caged resident.
- **Layout:**
  - Above the head, leaning away from the hero.
  - Flipped under the speaker when the top of the screen, the HUD or the hero is in the way.
  - Pinned at the edge with an arrow when the speaker is off screen.
- **Look:** the name in the speaker's colour, a typewriter at 30 characters a second or faster (all out by 60% of the line), 2 lines in a fight and 3 in the Workshop, and see-through in a fight.
- **Fallback:** a voice with no body here keeps the old box.
- **Timing (`Dialogue`):**
  - A line with no voice file stays up for n/30 + max(1.5, n/15) + 0.5 s.
  - The rest of an exchange waits on the line playing instead of going stale.
  - `drop_prefix` ends a resident's talk when you walk away.

**Residents** (`hub.resident_use`, `main._hub_use`, `ResidentScreen`):
- The first USE: they talk in bubbles, and the world keeps running.
- The second USE (the button reads ASK, SKINS or PAGES) opens a compact panel with their service and story pips.
- Opening a resident from the menu goes straight to the panel.
- A freed resident speaks after the cage opens, and "JOINS THE WORKSHOP" sits under the cage.

**No overlaps:**
- **`UiAudit`** records every string, panel and button drawn by the HUD, the menus and the Workshop labels. `tools/uiaudit.sh` renders every screen and HUD state at 2556x1179, 2048x1536 and 1920x1080 and lists collisions. Each render has a timeout.
- **HUD messages** (tip, spoken line, banners, toasts) are placed around what the HUD already covers (`_taken`, `_place`), and glide when a tip pushes them.
- **HUD elements:**
  - The room strip keeps clear of the first wand row.
  - The boss bar keeps clear of the vitals.
- **Pixel scale:** it never leaves a view narrower than 480 or shorter than 270 (`Game.scale_for`).
- **Menus:**
  - `Screen.fit` cuts a label to its box.
  - Buttons break a long label onto two lines.
  - Chips fold into "+N".
  - The glossary goes to two columns, the forge compacts its tiles, the credits wrap, and the map legend wraps.
  - The map shows the right world (it said WORLD 1 in every world).

## Consequences
- Tests: `test_bubbles` (anchors, wrap, timing, layout, following, exchanges) and `test_hud_layout` (placement and the pixel scale).
- The overlap audit is a tool, not a unit test: it needs a display.
- Bubbles appear only while the HUD shows; a line that starts behind a menu plays as sound only.
