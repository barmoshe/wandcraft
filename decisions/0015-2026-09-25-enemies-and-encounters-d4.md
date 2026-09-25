# 0015. Enemies, counters and the encounter director (D4)

- Date: 2026-09-25
- Status: Accepted
- Builds on ADR 0013 (resist keywords) and `research/design-plan.md` §3.

## Context
In the POC every enemy was HP and nothing else, so any damage answered every room, and editing the wand was optional (the D2 diagnosis). D2 put resist keywords on every hit. D4 gives them something to answer.

## Decision
- **Defences, each with one keyword that breaks it:**
  - **Frontal shield (Rune Sentry):** frontal hits are BLOCKED. A **pierce** hit breaks it. Eight blocked hits also wear it out, so nothing is ever unkillable.
  - **Armour (Bark Golem, Armored elites):** a steel bar over the health bar soaks everything. **Blast** tears it off at ×3; other hits at ×0.35; damage over time at ×0.2.
  - **Ward (Lantern Wisp, Warded elites):** swallows 3 whole hits. A **shock** hit strips it at once and still lands.
  - Keywords flow through `World.hurt_enemy(..., kw)`: spell hits carry their bullet's keywords, explosions add blast, Static arcs are shock and Bitrot crashes are blast.
- **The roster, 6 → 10 plus the half-slime:**

  | Enemy | Change |
  |---|---|
  | Moss Blob | splits into two halves |
  | Bugling | crouches 0.3 s, then lunges, in packs of three |
  | Hex Weaver | glows 0.5 s, then fires a 3-shot volley |
  | Rune Sentry | frontal shield and a 0.8 s laser sight before its burst |
  | Bark Golem (new) | tank; armour; a slam with a 1 s ring telegraph |
  | Lantern Wisp (new) | support; wards 3 allies every 4 s |
  | Brood Stump (new) | summoner; 2 buglings every 5 s, at most 4 of its own |
  | Glitch Tick (new) | a 0.8 s blinking fuse, then a burst; **frost holds the fuse** |

- **Elite affixes, one per elite, shown by outline colour and a title when it lands:**
  - Armored: steel.
  - Warded: cyan; the ward comes back after 6 s.
  - Hasted: gold; moves and attacks 50% faster.
  - Forked: violet; shots split in three, and it dies in a ring of shots.
  - Mirrored: pink; leaves a 40% copy.
- **The encounter director (`scripts/world/encounter.gd`)**, split out of `world.gd`:
  - **Wave grammar:** each wave is one anchor plus pressure, and a wisp may join an anchor. The first wave of the run is pressure only. No two anchors in a wave before the fourth room.
  - **Pacing:** the next wave comes at 70% down.
  - **Puzzle rooms:** the fight right before the mini-boss (Sentry Wall or Nursery) and before the boss (Golem Pair or Nursery).
- **Spawn rules:**
  - A 0.8–1.0 s rune first.
  - Never within 96 px of the player or in their aim cone.
  - At most 40 shots in the air from normal enemies (bosses exempt).
- **The counter guarantee:** when the run lacks a keyword, one of the three spell offers carries a missing one.
- **The bot's planner** values a wand 20% more for each keyword it can answer.

## Consequences
- **Tests:** 14 behaviour tests (`tests/unit/test_enemies_d4.gd`). 136 tests in all.
- **Bench:** see `research/balance-w1.md`, "D4 enemies".
- **Deferred:**
  - Enemy rigs and frame budgets (D6).
  - The combat half of the `world.gd` split. Damage and statuses stay in World for now: moving them means an extra call on the hottest path.
