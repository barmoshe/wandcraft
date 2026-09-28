# 0032. Arsenal round 2 (12 spells, 6 wands, 16 relics) and story round 2 (barks, arcs) (0.21)

- Date: 2026-09-28
- Status: Accepted
- Follows ADR 0030 (arsenal round 1) and ADR 0031 (NPCs in the world). Research: `research/speak-up-0.21.md`.

## Decision
- **Spells**, aimed at the thin builds:
  - Burn: Flame Graph, Crunch Time.
  - Frost: Breakpoint, Code Freeze.
  - Rot: Cruft, Worm.
  - Shock: Daisy Chain.
  - Summons: Pair Programmer, Squash.
  - Rule-breakers: *ptr, Symlink, onLoad().
- **Wands**, one rule each: Channel Rod, Unsafe Staff (costs HP, never below 1), Singleton Wand, Decorator Rod, Hot-Reload Wand, Monorepo.
- **Relics** (the first Area relics):
  - Area: Crowd Blast, Blast Share, Scorch Zone.
  - Familiar: Shared Boosts, Summon Refund.
  - Shock: Shock Charge, Charged Strike.
  - Frost: Frost Spread, Quick Freeze.
  - Others: Clean Streak, Risky Code, Relic Copy, Fixed Vitals, Wand Variety.
  - Two super relics (`Relics.DEPENDS`): Aftershock needs 2 Area; Summon Volley needs 2 Familiar.
  - One rival pair (`Relics.RIVALS`): Clean Streak or Risky Code.
- **Packs:**

  | Pack | Price | Needs |
  |---|---|---|
  | Blast Radius | 100 | |
  | Status Codes | 120 | |
  | Daemons | 120 | |
  | Linker | 120 | world1 |
  | Unsafe Code | 140 | world2 |

  Each super is in a pack with relics that meet its needs.
- **Story** (`sim/barks.gd`, Valve's rules and Hades' priorities):
  - Combat barks for the companions.
  - A Duck post-mortem when you return to the Workshop; the lines it doesn't use carry over to the next visit.
  - LINT's code-smell arc, which unlocks its Red Squiggle trick.
  - 7 beats per resident, plus chatter and opinions between them.
  - Log entry 17 (`h07f1x`, Hotfix muted the failing tests).
  - More lines for the thin events and every pack.
- **Calmer HUD** (Bar: "this is overwhelming"):
  - One message at a time: a banner holds the toast, and a banner, a spoken line or a toast holds the tip.
  - One row of relics, with a "+N" cell that opens the pause menu.
  - No bag count during a boss fight.

## Consequences
- Tests: `test_arsenal_0_21` (19), `test_relics_0_21` (18), `test_barks` (10), with `test_meta_d9`, `test_packs` and `test_copy` green.
- `test_voice` stays red until the 411 new lines are voiced with `tools/voices.sh`.
- The bark hooks in `world.gd` and `main.gd` are wired in the next commit.
