# 0022. Design v2: less to read, more to see (the 1.0 reinvention)

- Date: 2026-09-25
- Status: Accepted
- Plan and evidence: `research/design-v2.md`. The design-plan milestones (ADR 0011) are done; this sets the next arc.

## Context
- **What Bar found on a phone:** spells and relics were unclear, and the UI disagreed with the logic.
- **What the code audit found:**
  - The editor preview hides boosts.
  - About 25 player-facing concepts, and about 6 taught.
  - Name collisions: six "Loop"s.
  - Mana never binds early.
  - The final boss is shorter than the mini-boss.
  - A 366-fragment meta tax.
- **What genre research found:** Magicraft players ask "which spells fire?". Noita players needed an outside simulator. Balatro teaches by animating the scoring. Mobile runs work best at 10 to 15 min.
- **Bar's grant:** he opened every aspect to change and gave full autonomy. The MVP bar is a friend playing 3 runs without being asked.

## Decision
Nine milestones, R0 to R8, as `research/design-v2.md` lists them:
- **The model:** 4 kinds with their own socket shapes; slot numbers, chevrons and boost brackets everywhere; insert-on-drop.
- **The workbench:** a firing-range simulator with before and after deltas.
- **A core pool:** 26 spells, 18 relics plus 4 Corrupted and 2 Duos, 6 wands. The rest are later unlocks.
- **Run shape:** 2 areas of 5 rooms; the final boss is the peak; doors say what a room asks for; 3 heroes.
- **Onboarding:** puzzle lessons with a ghost-hand coach.
- **Combat:** a HUD that shows the program firing; thumb-reachable controls.
- **Replay:** goals instead of fragments, a Codex that works as a book, a daily seed.
- **One vocabulary**, enforced by tests.

## Consequences
- Content leaves the default pool but stays in the code and the tests, so nothing already built is lost.
- Each milestone ships web and APK builds and a STATUS line. A friend playtest (R8) is the acceptance test.
