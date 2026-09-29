# 0038. The hero redrawn in 3/4 view, with a scarf, a free hand and a fidget (0.26)

- Date: 2026-09-29
- Status: Accepted
- Builds on ADR 0007 (the hipster mage), ADR 0018 (D6 rigs) and ADR 0029 (the wand arm).
- Changes the hero's frame budget in `research/design-plan.md` §8 (25 frames per facing, now 44).

## Context
Bar: "improve the main character design and animations, be creative and do your best".

The design plan (§7) asked for the hero "on a chunky 3/4-view rig" with "visible arms, and a hand that holds the wand". What shipped in D6 was a front view with the arms baked into the torso:
- He faced the camera while running sideways. Only the fist and the flipped sprite said which way he went.
- The run moved the legs alone, the idle was a one-pixel bob, and the cast shifted him one pixel.
- Hurt and dash barely changed the pixels, and nothing trailed behind him.
- The wand did not move with the body: it sat at the grip while the fist bobbed.

## Decision
- **Keep the identity** (ADR 0007): the quiff, the teal shades, the full beard, the yellow shirt, the red tie, the teal suspenders, the slim red trousers.
- **Redraw him in 3/4 view**, on a 24x36 canvas (was 20x36) with the feet at the same point, so the grip, hurt zone and spell origin are unchanged:
  - The head is turned toward where he faces. The pompadour rises at the front and sweeps back to the nape, the ear sits behind the face, the nose breaks the outline, and the shades' temple arm runs back to the ear.
  - The far lens is foreshortened, and the shoes (brogues now) point where he goes.
  - The back view (aiming up) is a rounded, combed-back head with a nape, a neck and an ear.
- **New parts on the rig:**
  - **A knit scarf** (arcane with frost stripes), wrapped at the neck, whose tail hangs, sways, waves on the run and streams straight back on the dash. It lags the body by a frame. Each look recolours it: an ember sash for the Pyromancer, a red rag for the Tinkerer.
  - **The free arm** (`arm_b`): hangs, swings against the near leg, flicks a spark on the cast, flails when hit.
  - **The shades** are their own part, so they can pop up, fly off and slide down the nose.
  - **A reach hand** in front of the face (the fidget).
- **Legs are drawn from joints** (`Hero.legs(knee, ankle, knee, ankle)`): each leg is a stepped 3-pixel column from the hip through the knee to the ankle, then the cuff and the shoe. The far leg is a step darker, so the crossing reads.
- **The clips** (per facing: idle 6, run 8, cast 4, dash 5, hurt 3, death 8, fidget 10):
  - **Idle:** breathing, and the scarf sways.
  - **Run:** contact, down, passing and up on each leg; the head leads by a pixel, the free arm swings and the scarf waves.
  - **Cast:** anticipation (lean back, the free hand up), release (lean in, a spark leaves the free hand, the sleeve smears), follow-through, settle.
  - **Dash:** crouch, a stretched launch, two airborne frames with the knees tucked and the scarf straight back, the landing.
  - **Hurt:** the head snaps back, the shades jump up his forehead so his eyes show, and his mouth opens; then they drop back. `hurt_t` is 0.25 s so all three frames play.
  - **Death, "the crash":** hit; the shades fly off and land by his feet; he sinks to his knees; the whole sprite goes blue-screen (every ramp step moved to arcane and frost); then he tears and crumbles to pixels as before.
  - **Fidget (new):** after 4 s standing still, and every 7 s while he stays put, he pushes his shades up his nose. A glint runs across the lenses, then a small pleased nod. From behind he scratches his head, and the Tinkerer, who has no shades, twirls his moustache. A cast or any movement cuts it off.
- **The looks** (the Pyromancer and the Tinkerer, 0.19, ADR 0027) are redrawn on the same rig. A look can now:
  - make palette keys flicker (`flicker`): the Pyromancer's flame quiff burns frame by frame;
  - move the reach hand (`reach_off`).
- **The wand follows the fist:** `Hero.hand_offset` gives the hand's pose offset. `Player._animate` draws the wand and its tip glow there. Spells still leave from `Player.grip()`, so no aim or test fixture moves.
- **Review tooling:** `tools/artsheet.sh hero [-- --only=<look>]` draws every clip of every look, both facings.

## Consequences
- The hero's frame budget is 44 per facing (88 per look, 264 for the three heroes). Frames are 26x38 px and baked lazily per clip on first use, as before. `test_anim_d6` checks the new budget.
- New tests:
  - the fidget starts after standing still, plays through, and gives way to a cast;
  - the wand's offset follows the cast, idle and run poses;
  - every look changes its pixels when hurt and during the fidget.
- Copy-Paste copies the hero's clips, so it gets the new animation (and the new silhouette) for free.
- Menus that draw `Hero.frames()` (the Hero Hall, start cards, the descent screen) centre by width and take the wider frame unchanged. `frames()` still returns 7 poses.
- The old `wizard (old)` sprites are untouched.
- **Bar:** play it, and watch the idle (stand still for 4 seconds), the dash and a death. Does the 3/4 turn read on a phone, and is the scarf too busy in a fight?
