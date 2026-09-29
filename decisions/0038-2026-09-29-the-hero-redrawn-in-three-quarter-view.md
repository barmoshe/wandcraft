# 0038. The hero redrawn in 3/4 view, with a scarf, a casting stance and a fidget (0.26)

- Date: 2026-09-29
- Status: Accepted
- Builds on ADR 0007 (the hipster mage), ADR 0018 (D6 rigs) and ADR 0029 (the wand arm).
- Changes the hero's frame budget in `research/design-plan.md` §8 (25 frames per facing, now 52).

## Context
Bar: "improve the main character design and animations, be creative and do your best".

The design plan (§7) asked for the hero "on a chunky 3/4-view rig" with "visible arms, and a hand that holds the wand". What shipped in D6 was a front view with the arms baked into the torso:
- He faced the camera while running sideways. Only the fist and the flipped sprite said which way he went.
- The run moved the legs alone, the idle was a one-pixel bob, and the cast shifted him one pixel.
- Hurt and dash barely changed the pixels, and nothing trailed behind him.
- The wand did not move with the body: it sat at the grip while the fist bobbed.
- **Firing froze the legs.** The cast clip overrode the run, so firing on the move (most of a twin-stick fight) snapped the legs to a standing pose and he slid. Every shot also restarted the cast, so the arm pumped.

A first 3/4 pass (on this branch) looked wrong to Bar: "It look weird". He named all four problems we listed:
- the turned head sat on a flat, front-facing torso;
- the wand arm was a stiff rod;
- the hair and beard made a mask of the face;
- the motion was off.

This ADR records the second pass.

## Decision
- **Keep the identity** (ADR 0007): the quiff, the teal shades, the full beard, the yellow shirt, the red tie, the teal suspenders, the slim red trousers.
- **Redraw him in 3/4 view**, on a 24x36 canvas (was 20x36) with the feet at the same point, so the grip, hurt zone and spell origin are unchanged:
  - **The head** is 12 px wide on a body of 11, so he is no longer bobble-headed.
    - The pompadour juts forward over the brow and slopes to the nape. The hair is a step lighter, with a shadow at the back, so it reads as volume, not a void.
    - The ear sits behind the cheek, the nose breaks the outline, and the shades' temple arm runs back to the ear. The far lens is foreshortened.
    - The beard runs along the jaw under a moustache, with cheek showing above it.
  - **The torso turns with the head:** a lit side plane on the left, the front plane with one strap and the tie right of centre, the far side in shade, tucked high into the belt.
  - **The near arm** (the free one) is drawn in front of the body, with a dark contour so it separates from the shirt.
  - **The wand arm is bent:** a forearm raised from the rolled cuff at the elbow to the fist, which closes over the grip (`Player.GRIP`, unchanged).
  - **Brogues** point where he goes, and the far leg is a step darker.
  - **The back view** (aiming up) is a combed-back head with a nape, a neck and an ear.
- **The scarf:** a knit scarf (arcane with frost stripes) wrapped at the neck. Its tail hangs, sways, waves on the run in three phases and streams straight back on the dash, one frame behind the body. Each look recolours it: an ember sash for the Pyromancer, a red rag for the Tinkerer.
- **Legs are drawn from joints** (`Hero.legs(knee, ankle, knee, ankle)`): each leg is a stepped 3-pixel column from the hip through the knee to the ankle, then the cuff and the shoe.
- **Firing no longer fights the run:**
  - **The casting stance** (`cast`, looped): he leans in, the free hand goes up and back, and its spark flickers.
  - **`run_cast`** is the run holding that stance. It shares the run's legs frame for frame and its phase (`walk_t`), so starting and stopping fire never trips the legs.
  - `Player.stance_t` holds the stance 0.35 s after each shot, so a burst reads as one steady stance. A shot no longer restarts the clip.
- **The other clips** (per facing: idle 6, run 8, cast 4, run_cast 8, dash 5, hurt 3, death 8, fidget 10):
  - **Idle:** breathing, and the scarf sways.
  - **Run:** contact, down, passing and up on each leg; the head leads by a pixel and the near arm swings against the near leg.
  - **Dash:** crouch, a stretched launch, two airborne frames with the knees tucked and the scarf straight back, the landing.
  - **Hurt:** the head snaps back, the shades jump up his forehead so his eyes show, and his mouth opens; then they drop back. `hurt_t` is 0.25 s so all three frames play.
  - **Death, "the crash":** hit; the shades fly off and land by his feet; his knees give and he sinks; the whole sprite goes blue-screen (every ramp step moved to arcane and frost); then he tears and crumbles to pixels.
  - **Fidget (new):**
    - After 4 s standing still, and every 7 s while he stays put, the near hand pushes his shades up his nose, a glint runs across the lenses, and he gives a small pleased nod.
    - From behind he scratches his head, and the Tinkerer, who has no shades, twirls his moustache.
    - A cast or any movement cuts it off.
- **The looks** (the Pyromancer and the Tinkerer, 0.19, ADR 0027) are redrawn on the same rig. A look can now:
  - make palette keys flicker (`flicker`): the Pyromancer's flame quiff burns frame by frame;
  - move the fidget's hand (`reach_off`).
- **The wand follows the fist:** `Hero.hand_offset` gives the hand's pose offset. `Player._animate` draws the wand and its tip glow there. Spells still leave from `Player.grip()`, so no aim or test fixture moves.
- **Review tooling:** `tools/artsheet.sh hero [-- --only=<look>]` draws every clip of every look, both facings.

## Consequences
- The hero's frame budget is 52 per facing (104 per look, 312 for the three heroes). Frames are 26x38 px and baked lazily per clip on first use, as before. `test_anim_d6` checks the new budget.
- New tests:
  - the fidget starts after standing still, plays through, and gives way to a cast;
  - firing on the move picks `run_cast`, firing still picks `cast`, the stance ends after the last shot, and `run` and `run_cast` share their legs frame for frame;
  - the wand's offset follows the cast, idle and run poses;
  - every look changes its pixels when hurt and during the fidget.
- Copy-Paste copies the hero's clips, so it gets the new animation (and the new silhouette) for free.
- Menus that draw `Hero.frames()` (the Hero Hall, start cards, the descent screen) centre by width and take the wider frame unchanged. `frames()` still returns 7 poses.
- The old `wizard (old)` sprites are untouched.
- **Bar:** play it: run while firing, stand still for 4 seconds, dash, and die once. Does he still look weird anywhere, and is the scarf too busy in a fight?
