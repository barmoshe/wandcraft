# The Debug Duck: model sheet (0.24)

Bar (28 Sep 2026): "reinvent the duck design and style and art, improve it". He picked the **debug duck**: a glossy classic rubber duck with a big eye, a shine, a slightly smug brow, and one accessory, tiny teal glasses like the hero's.

## Before
The Duck was five drawings that didn't match:
- **A front-on gold bust:** the speech box, the companion and the Workshop.
- **A side-view duck:** the Rubber Duck spell and its icon.
- **Story panels:** the 12 px face blown up 5x.

It never blinked, and in the speech box its beak never moved. The face had an inline white hex.

## The design
- **Shape:** a round head set forward of a big round body, a pointed tail flick at the back, and the bill pointing the way it faces (right; nodes flip it).
- **Gloss:** a `bone:4` shine on the crown and one on the chest. This is what makes it read as a rubber toy, not a chick.
- **Glasses:** the hero's own keys (`Hero.PAL`): a `night:0` frame, `cyan:2` lenses and a `cyan:4` glint. The near lens is big and holds the eye, and the far lens is a sliver past the bridge.
- **Body:** `gold:2` rim, `gold:3` fill, `gold:4` light side, `gold:1` belly and brow.
- **Bill:** `ember:4` on top, `ember:3` below, and `ember:1` for the open mouth.
- **Moods:**
  - **Plain.**
  - **Smug:** the brow down and the lid half over the lens. For lines where it gets to be right (a death, a quit, a dry wand).
  - **Pleased:** the eye an arc. For wins, clears, kills and unlocks.
  - `DuckArt.mood_of(id)` picks one from the line's event.
- **Life:**
  - It blinks every 3 to 4 s.
  - Its bill flaps at about 8 Hz while its line plays: in the speech box, the companion, the Workshop and the story panels.
  - The companion waddles, and the bust bobs on its bath water.

## The pieces (`game/scripts/art/duck_art.gd`)

| Piece | Size (grid) | Where |
|---|---|---|
| `face(mood, talk, blink)` | 12x11 | speech box, story speaker tag, end screen |
| `body(frame, talk, blink)` | 15x16 | the companion in a run |
| `sit(talk, blink, mood)` | 15x14 | the Workshop's Duck, on the floor |
| `familiar(frame)` | 14x11 | the Rubber Duck spell |
| `ICON` | 12x12 | the Rubber Duck spell's icon |
| `bust(talk, blink, ripple)` | 44x40, drawn with shapes | the story panels, in a bath |

The small pieces are hand-placed grids that share one head (`HEAD`, `EYES`, `BLINK`, `BEAK_OPEN`). The bust is drawn with discs and rects, because a 44 px hand grid would be fragile.

Review sheet: `tools/artsheet.sh duck -- --scale=8`. It shows every piece, mood and frame, with the hero, LINT and the old face for comparison.
