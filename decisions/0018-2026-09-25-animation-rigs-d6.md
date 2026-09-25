# 0018. Animation on rigs, whole-pixel VFX, and a HUD drawn like the rest (D6)

- Date: 2026-09-25
- Status: Accepted
- Builds on `research/design-plan.md` §7 (pipeline, VFX) and §8 (frame budgets), and ADR 0012 (art direction). D6 was done after D7 on purpose (see HANDOFF.md), so the bosses' final shapes could be rigged once.

## Context
Before D6 every actor had two frames. The hero was a 7-frame strip, enemies swapped a "b" layer, the held wand and the Loop's head were rotated as sprites (fractional rotation of pixel art, which the pixel rule forbids), and telegraphs were thin lines drawn on the actors. Bar also asked, mid-milestone, for the HUD icons to be fixed.

## Decision
- **`RigDef` and `RigBaker`** (`scripts/art/`): a rig is ASCII parts sharing one Style palette. Poses move parts by whole pixels, swap a part's rows, squash or stretch a part by removing or repeating its plainest middle row (the feet stay planted, eyes survive), lag a part one frame behind a leader (the hero's quiff), tear scan lines, crumble in a fixed Bayer order, and recolour palette keys. Every frame goes through `PixelArt.layered`, so rigs keep the rim light and sel-out outline. Baked clips are cached per rig.
- **The hero:** two facings (the back view turns on when aiming up, with hysteresis), idle 4, run 6, cast 3, dash 4, hurt 2, death 6: 50 frames. The cast replays from its anticipation frame on every shot. The death folds, tears and crumbles to pixels through the world's retry countdown.
- **Pre-rotation instead of sprite rotation:** a RotSprite-style voter (`RigBaker.rotations`, 3x3 samples per pixel, no new colours) bakes the wand at 16 angles and the Loop's head, every frame, at 16 headings (left headings use the frame flipped first). Nothing in the game rotates pixel art at draw time any more.
- **Enemies:** every bestiary entry becomes a rig with move 4, tele 2 (squash, eyes to the threat ramp) and attack 2 (stretch and lunge). The AI state picks the clip: wind-ups, the sentry's aim and the tick's fuse telegraph; shots, charges, slams and summons attack. Deaths add a 4-frame dithered poof. Copy-Paste runs on glitched copies of every hero clip.
- **VFX:** a 3-frame hit spark along the hit, an 8-frame explosion baked per radius (four hot frames tinted by the spell, four frames of stone-ramp smoke), dithered trails behind the first 300 player bullets, and damage numbers in three tiers where hits on one target within 150 ms merge.
- **Telegraphs are floor decals** (line, circle, cone, box) under the actors, filling from their source as the attack nears, for enemies and bosses alike.
- **Ambient life** (visual only, never the sim's rng): grass that leans away from walkers, dust motes around torches, falling leaves, stepped at 8 fps.
- **The front cap:** a wall with open floor behind it raises its cap 6 px as a lip sprite y-sorted with the actors, so pillars and the south wall hide the feet of whatever stands behind them.
- **The HUD icons** (Bar's request): the wand badge is the pre-rotated wand with its gem in the wand's colour; coin, pause and bag are ramp-drawn sprites instead of flat plate glyphs; the bars get a heart and a mana drop; relic counters use a 3x5 pixel font inside the icon.

## Consequences
- 163 tests (a new `test_anim_d6.gd` covers frame budgets, deterministic whole-pixel bakes, squash, the wand's angles, facing, decal fill, number merging, lips and tufts). The stress tick stays at 8–9 ms on the Mac: caching baked clips and skipping unchanged texture sets were needed to get there.
- New art review: `tools/artsheet.sh anim` (every clip as a strip) and `ui` (HUD icons, wand gems).
- The tools run on macOS now (`tools/lib/platform.sh`), with Godot 4.7.2 found ahead of an older Godot on PATH.
- **Deferred:** Copy-Paste still draws at a 1.25 scale (a D7 choice; a native-size mini-boss rig is the fix); the room painter's dual-grid autotiling and stamp scatter (RoomPainter v2) are not part of D6; the Loop's body segments use the generic enemy rig; torches keep their 3-frame flame.
