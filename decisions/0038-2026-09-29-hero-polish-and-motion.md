# 0038. The hero keeps his look: a pixel polish, a livelier run, and legs that keep running while he fires (0.26)

- Date: 2026-09-29
- Status: Accepted
- Builds on ADR 0007 (the hipster mage), ADR 0018 (D6 rigs) and ADR 0029 (the wand arm).
- Changes the hero's frame budget in `research/design-plan.md` §8 (25 frames per facing, now 30).

## Context
Bar asked to improve the main character's design and animation.

A 3/4-view redraw came first: a turned head and torso, a scarf, new clips. After two passes Bar compared it with the hero as he was in 0.25 and said: "It was better before". That work is kept, unmerged, on the branch `claude/hero-3-4-experiment`.

Bar then asked for web research (`research/hero-motion.md`). The research said: keep one front view, mirrored, and put the effort into motion. He picked three things:
- legs that keep running while he fires;
- a livelier run;
- better graphics, with his drawing kept.

Two problems in 0.25:
- **Firing froze the legs.** The cast clip overrode the run, so firing on the move (most of a twin-stick fight) snapped the legs to a standing pose and he slid.
- **The cast rocked.** Every shot restarted the cast clip, so the body jerked left and right on every shot.

## Decision
- **The design is unchanged:** the same 20x36 canvas, silhouette, colours and parts.
- **A pixel polish** on the same shapes, using Style ramp keys only:
  - a sheen streak through the quiff, and its midtone;
  - two strand highlights in the moustache and two in the beard;
  - collar points around the tie knot;
  - a tuck shadow and suspender buttons at the waist, and a bright buckle;
  - the inner shade of each trouser leg, rolled cuffs at the ankles, and a shine on each toe, in every walk stamp and for every look (`d` and `j` in each look's palette);
  - a sheen through the back of the head, with strands, in the back view.
- **Legs keep running while he fires.** `run_cast` is the run with the free arm held still. It shares the run's legs frame for frame and its phase (`walk_t`), so starting or stopping fire never trips the legs.
- **A burst of fire holds one lean.** `cast` is two frames, both leaning 1 px into the shot: the first carries the sleeve smear and replays on each shot, the second holds.
  - `Player.stance_t` keeps the lean (or `run_cast`) 0.35 s after the last shot.
  - A shot restarts the clip only while he stands still.
- **A livelier run**, from Slynyrd's Pixelblog 55 and Nuclear Throne:
  - the uneven bob: down 1, down 1, up 2 (body at +1, +2, 0 per stride);
  - the head leads the body by a pixel;
  - the free arm swings against the stride. It is lifted off the torso as its own part, from each look's own pixels (`Hero._free_arm`), so every hero swings his own sleeve.
  - Backpedalling (moving against the way he faces) plays the run backwards.
- **The wand stays in the fist.** `Hero.hand_offset` gives the fist's pose offset, and `Player._animate` draws the wand and its tip glow there. Spells still leave from `Player.grip()`, so no aim or test fixture moves.

## Consequences
- The frame budget is 30 per facing: idle 4, run 6, cast 2, run_cast 6, dash 4, hurt 2, death 6. `test_anim_d6` checks it.
- New tests:
  - firing on the move picks `run_cast`, firing still picks `cast`, and the lean ends after the last shot;
  - `run` and `run_cast` share their legs;
  - the cast's first frame carries the smear;
  - the free arm swings and the run bobs over three heights;
  - the wand's offset follows the idle, run and cast poses.
- Copy-Paste copies the hero's clips and asks for "cast" and "run", so it gets the polish and the new run for free.
- Menus draw `Hero.frames()`: the same 7 poses at the same size.
- **Not done, and candidates for later** (`research/hero-motion.md`): a white flash frame when hit, a freeze and stretch on the dash, dust on footfalls and on stopping, and a flash and hold before the death crumble.
- **Bar:** play it. Run while firing, backpedal, and stand still in a burst. Does he still look like himself, and does the run feel better?
