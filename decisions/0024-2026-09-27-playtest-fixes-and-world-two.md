# 0024. The first playtest's fixes, and a second world

- Date: 2026-09-27
- Status: Accepted
- Builds on ADR 0023 (design v3). Findings, fixes and the World 2 design: `research/design-w2.md`.

## Context

- **The playtest:** Bar shared 0.16.0 (the web link and the APK) with friends and a game-dev WhatsApp group.
- **What testers reported:**
  - Auto-aim fired at walls in the final boss fight.
  - The game stalled when the boss appeared.
  - The Loop's last phase couldn't be outrun.
  - Standing outside the snake's ring was safe.
  - Shots passed through the hero.
  - Copy-Paste had no wand.
  - The wand sat at the hips.
  - The camera swung in big rooms.
  - The run felt easy.
- **Bar's asks:** "Fix and improve". Then, on learning there is one world: "at least 2 worlds".

## Decision

- **Fix every report at its cause.** The details are in `research/design-w2.md`; the most important two:
  - Spells no longer spawn inside walls.
  - The Loop's head angles are drawn lazily, one at a time as each is needed, instead of all at once when it spawns.
- **Run length:** a run is two worlds of the same shape.
  - `RunState.world` counts worlds and `step` counts rooms within the world.
  - `Chapter.depth()` feeds difficulty across both worlds.
  - The Loop's exit leads into World 2, the Overheated Foundry. World 2 has two new area themes, three new enemies, the other mini-boss at 2.0, the boss Deadlock, and generated music and ambience.
- **Goals:** a win means clearing both worlds. The new goal "Defeat the Infinite Loop" takes over the first-win unlock, and old wins count toward it.

## Consequences

- A full run roughly doubles in length, to about 25 minutes for a human.
- The balance band now applies to clearing World 1. The full-run win rate and Deadlock's fight length are reported alongside it.
- World 2 reuses the boss music and some World 1 enemies. A third world would follow the same pattern (`Chapter.WORLDS`).
