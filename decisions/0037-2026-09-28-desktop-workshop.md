# 0037. The Workshop on desktop: keys where you look, a click to go, bubbles off the stations (0.25)

- Date: 2026-09-28
- Status: Accepted
- Builds on ADR 0027 (the Workshop) and ADR 0031 (speech bubbles).

## Context
Bar: "fix desktop workshop ux/ui". At desktop sizes the Workshop showed five problems:
- The Duck's and LINT's speech bubbles sat over the BENCH, SHOP and RUN names, because they stood in the middle of the stations.
- The USE control was the phone's round button, in the far corner, with a small "E" beside it.
- A mouse could do nothing but aim.
- The entry banner landed on the room's top wall and the portal.
- The menu button had no key.

Bar chose to fix all five.

## Decision
- **The Duck and LINT** stand by the way in, below the open floor. Their bubbles rise over empty floor.
- **Bubbles keep off every station's name** (`Hub.label_rects`, added to the bubble's keep-out list). A bubble that leans away from the hero and hits something tries centred, then the other lean, before searching further.
- **On desktop, the key prompt is at the station:** a boxed "E" and what it does (USE, TALK, ASK...) over the station's name. Nearby names step aside, and a sub-line that only repeats the verb is left out.
  - The round USE button is for touch only.
  - `Hub.use_verb` is the one place the verb is decided, for both.
- **A click on a station** (or its name) walks the hero there on the room's path and uses it. The portal opens by walking in, as always. Any key or stick takes back control.
  - Under the mouse, a station names itself with "Click to go there".
- **The Workshop's banner** sits at the top of the screen, over the forest. On desktop it says "Walk to a station, or click one".
- **The menu button** shows ESC on desktop.

## Consequences
- `test_hub` checks:
  - a click finds its station, pedestal or name;
  - the prompt's verb;
  - the bubble space above the Duck and LINT holds no station.
- A headless run confirmed a click walks the hero to the Terminal and opens it.
- Touch is unchanged: the USE button, the dash, and tap to talk.
